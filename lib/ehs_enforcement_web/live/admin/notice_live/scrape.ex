defmodule EhsEnforcementWeb.Admin.NoticeLive.Scrape do
  @moduledoc """
  Admin interface for manual HSE notice scraping with real-time progress display.
  
  Features:
  - Manual notice scraping trigger with configurable parameters
  - Real-time progress updates via Phoenix PubSub
  - Notice scraping session management and results display  
  - Error reporting and recovery options
  - Proper Ash integration with actor context
  """
  
  use EhsEnforcementWeb, :live_view
  
  require Logger
  require Ash.Query
  
  alias EhsEnforcement.Scraping.ScrapeCoordinator
  alias EhsEnforcement.Scraping.ScrapeRequest
  alias EhsEnforcement.Scraping.ScrapeSession
  alias AshPhoenix.Form
  alias Phoenix.PubSub
  
  @pubsub_topic "scraping_progress"
  
  # LiveView Callbacks
  
  @impl true
  def mount(_params, _session, socket) do
    # Check if manual scraping is enabled via feature flag
    manual_scraping_enabled = ScrapeCoordinator.scraping_enabled?(type: :manual, actor: socket.assigns[:current_user])
    
    # Create AshPhoenix.Form for scraping parameters with notices database default
    form = Form.for_create(ScrapeRequest, :create, as: "scrape_request", forms: [auto?: false]) 
    |> Form.validate(%{"database" => "notices"})
    |> to_form()
    
    socket = assign(socket,
      # Feature flags
      manual_scraping_enabled: manual_scraping_enabled,
      real_time_progress_enabled: should_enable_real_time_progress?(socket.assigns[:current_user]),
      
      # AshPhoenix.Form for scraping configuration
      form: form,
      
      # Session state
      current_session: nil,
      scraping_active: false,
      scraping_task: nil,
      scraping_session_started_at: nil,  # Track when current scraping session began
      
      # Progress tracking - notice-specific metrics
      progress: %{
        pages_processed: 0,
        notices_found: 0,
        notices_created: 0,
        notices_exist_total: 0,
        notices_exist_current_page: 0,
        errors_count: 0,
        current_page: nil,
        status: :idle
      },
      
      # Results and errors - will load from actual Ash resources
      session_results: [],
      recent_errors: [],
      recent_notices: [],
      # Initialize empty values - will be populated by keep_live
      notice_processing_log: [],
      scraped_notices: [],  # Initial empty state before keep_live takes over
      
      # UI state
      loading: false,
      last_update: System.monotonic_time(:millisecond)
    )
    
    # Load recent notices data using proper AshPhoenix.LiveView reactive patterns
    if connected?(socket) do
      
      # Use AshPhoenix.LiveView.keep_live for automatic reactive notice updates
      socket = AshPhoenix.LiveView.keep_live(socket, :recent_notices, fn socket ->
        EhsEnforcement.Enforcement.Notice
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.limit(100)
        |> Ash.Query.load([:agency, :offender])
        |> Ash.read!(actor: socket.assigns.current_user)
      end,
        subscribe: ["notice:created:*", "notice:updated:*", "notice:bulk_created"],
        results: :keep,
        load_until_connected?: true,
        refetch_window: :timer.seconds(5)
      )
      
      # Use AshPhoenix.LiveView.keep_live for reactive scraping session updates
      socket = AshPhoenix.LiveView.keep_live(socket, :active_sessions, fn _socket ->
        ScrapeSession
        |> Ash.Query.for_read(:active)
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.read!()
      end,
        subscribe: ["scrape_session:created", "scrape_session:updated"],
        results: :keep,
        load_until_connected?: true,
        refetch_window: :timer.seconds(1)
      )
      
      # Manual PubSub subscription for scraped notices - use direct state management
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "notice:scraped:updated")
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "notice:created")
      
      {:ok, socket}
    else
      {:ok, socket}
    end
  end
  
  @impl true 
  def handle_event("validate", %{"scrape_request" => params}, socket) do
    # Ensure database is always "notices" for this interface
    params_with_notices = Map.put(params, "database", "notices")
    form = Form.validate(socket.assigns.form, params_with_notices) |> to_form()
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("submit", %{"scrape_request" => params}, socket) do
    Logger.info("Admin triggered manual notice scraping with params: #{inspect(params)}")
    
    # Check if manual scraping is enabled via feature flag
    unless socket.assigns.manual_scraping_enabled do
      socket = put_flash(socket, :error, "Manual scraping is currently disabled. Please contact an administrator.")
      {:noreply, socket}
    else
      # Force database to "notices" for this interface
      params_with_notices = Map.put(params, "database", "notices")
      
      # First validate the form with the new params, then submit
      validated_form = Form.validate(socket.assigns.form, params_with_notices)
      case Form.submit(validated_form, params: params_with_notices) do
        {:ok, scrape_request} ->
          # Extract validated parameters from the created resource
          validated_params = %{
            start_page: scrape_request.start_page,
            max_pages: scrape_request.max_pages,
            database: "notices"  # Force notices
          }
        
        # Simplified scraping - just create Notices directly (no tracking tables needed)
        scraping_opts = %{
          start_page: validated_params.start_page,
          max_pages: validated_params.max_pages,
          database: "notices",
          actor: socket.assigns.current_user
        }
        
        # Set session start time FIRST, before starting background task
        session_start_time = DateTime.add(DateTime.utc_now(), -5, :second)
        
        # Update socket BEFORE starting background task
        socket = assign(socket,
          scraping_active: true,
          scraping_session_started_at: session_start_time,
          scraped_notices: [],  # Clear previous session's notices
          progress: Map.merge(socket.assigns.progress, %{
            status: :running,
            current_page: validated_params.start_page
          })
        )
        
        # Start simple scraping task
        _liveview_pid = self()
        Logger.info("Starting simple notice scraping: pages #{scraping_opts.start_page}-#{scraping_opts.start_page + scraping_opts.max_pages - 1}")
        
        # Create ScrapeSession using Ash (pure Ash approach)
        session = EhsEnforcement.Scraping.ScrapeSession
        |> Ash.Changeset.for_create(:create, %{
          session_id: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower),
          start_page: validated_params.start_page,
          max_pages: validated_params.max_pages,
          database: "notices",
          status: :running,
          current_page: validated_params.start_page
        })
        |> Ash.create!(actor: socket.assigns.current_user)
        
        task = Task.async(fn ->
          case scrape_notices_with_session(session, scraping_opts) do
            {:ok, results} ->
              Logger.info("Notice scraping completed: #{results.created_count} notices created")
              
            {:error, reason} ->
              Logger.error("Notice scraping failed: #{inspect(reason)}")
          end
        end)
        
        # Final socket update with session and task info
        socket = assign(socket,
          current_session: session,
          scraping_task: task
        )
        
        {:noreply, socket}
        
        {:error, form} ->
          # Form validation failed - assign the form with errors
          {:noreply, assign(socket, form: form |> to_form())}
      end
    end
  end
  
  @impl true
  def handle_event("stop_scraping", _params, socket) do
    case {socket.assigns.current_session, socket.assigns.scraping_task} do
      {%{session_id: session_id}, task} when not is_nil(task) ->
        Logger.info("Admin requested to stop notice scraping session: #{session_id}")
        
        # Actually stop the background task
        Task.shutdown(task, :brutal_kill)
        
        broadcast_scraping_event(:stopped, %{
          session_id: session_id,
          user: socket.assigns.current_user.email
        })
        
        socket = assign(socket,
          scraping_active: false,
          current_session: nil,
          scraping_task: nil,
          scraping_session_started_at: nil,
          progress: Map.put(socket.assigns.progress, :status, :stopped)
        )
        
        {:noreply, socket}
      
      {nil, _} ->
        {:noreply, socket}
        
      {_, nil} ->
        # Still update UI state in case it's out of sync
        socket = assign(socket,
          scraping_active: false,
          current_session: nil,
          scraping_session_started_at: nil,
          progress: Map.put(socket.assigns.progress, :status, :stopped)
        )
        {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("clear_results", _params, socket) do
    socket = assign(socket, session_results: [], recent_errors: [])
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_scraped_notices", _params, socket) do
    # Clear the scraped notices list and session start time
    socket = assign(socket, 
      scraped_notices: [],
      scraping_session_started_at: nil
    )
    {:noreply, socket}
  end
  
  # Catch-all event handler to debug what events we're receiving
  @impl true
  def handle_event(event, params, socket) do
    Logger.warning("Notice UI: Received unhandled event: #{event} with params: #{inspect(params)}")
    {:noreply, socket}
  end
  
  # PubSub Message Handling - adapted for notices
  
  @impl true
  def handle_info({:started, data}, socket) do
    # Only update progress, don't change scraping_active
    progress_updates = %{
      status: :running,
      current_page: data.current_page,
      pages_processed: data.pages_processed,
      notices_found: data.cases_scraped,  # Note: backend still uses "cases_scraped" field
      notices_created: data.cases_created,  # Note: backend still uses "cases_created" field
      notices_exist_total: data.cases_exist_total,
      notices_exist_current_page: data.cases_exist_current_page,
      errors_count: data.errors
    }
    
    socket = update_progress(socket, progress_updates)
    
    # Force push event to ensure re-render
    socket = push_event(socket, "progress_updated", %{
      progress: socket.assigns.progress,
      timestamp: socket.assigns.last_update
    })
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:page_started, data}, socket) do
    socket = update_progress(socket, %{
      current_page: data.current_page,
      pages_processed: data.pages_processed,
      notices_found: data.cases_scraped,
      notices_created: data.cases_created,
      notices_exist_total: data.cases_exist_total,
      notices_exist_current_page: 0,  # Reset counter for new page
      errors_count: data.errors,
      status: :processing_page
    })
    
    {:noreply, socket}
  end

  @impl true
  def handle_info({:page_completed, data}, socket) do
    progress_updates = %{
      pages_processed: data.pages_processed,
      notices_found: data.cases_scraped,
      notices_created: data.cases_created,
      notices_exist_total: data.cases_exist_total,
      notices_exist_current_page: data.cases_exist_current_page,
      errors_count: data.errors,
      current_page: data.current_page,
      status: :processing_page
    }
    
    updated_socket = update_progress(socket, progress_updates)
    
    # Check if scraping should stop due to all notices existing on current page
    final_socket = if Map.get(data, :should_stop_all_exist, false) do
      Logger.info("Notice UI: Scraping stopped - all notices on page #{data.current_page} already exist")
      assign(updated_socket, 
        scraping_active: false,
        progress: Map.put(updated_socket.assigns.progress, :status, :completed)
      )
    else
      updated_socket
    end
    
    # Force push event to ensure re-render
    final_socket = push_event(final_socket, "progress_updated", %{
      progress: final_socket.assigns.progress,
      timestamp: final_socket.assigns.last_update
    })
    
    {:noreply, final_socket}
  end
  
  @impl true
  def handle_info({:completed, data}, socket) do
    socket = complete_scraping_session(socket, data)
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:error, data}, socket) do
    socket = handle_scraping_error(socket, data)
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:scraping_event, _event_type, _data}, socket) do
    {:noreply, socket}
  end
  
  # Ash Notification Handlers for Notice PubSub events
  
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "notice:created", event: "create", payload: %Ash.Notifier.Notification{} = notification}, socket) do
    # Only add to scraped_notices if we have an active session
    socket = if socket.assigns.scraping_session_started_at do
      # Load full notice data with associations
      notice = EhsEnforcement.Enforcement.Notice
      |> Ash.get!(notification.data.id, load: [:agency, :offender], actor: socket.assigns.current_user)
      
      # Add to the beginning of the list (most recent first)
      updated_scraped_notices = [notice | socket.assigns.scraped_notices]
      
      # Keep only the most recent 50 notices
      updated_scraped_notices = Enum.take(updated_scraped_notices, 50)
      
      assign(socket, scraped_notices: updated_scraped_notices)
    else
      socket
    end
    
    {:noreply, socket}
  end

  # Handle keep_live refetch messages
  @impl true
  def handle_info({:refetch, :active_sessions, _opts}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:refetch, :recent_notices, _opts}, socket) do
    {:noreply, socket}
  end

  # Task completion handlers
  @impl true
  def handle_info({:scraping_completed, _session}, socket) do
    Logger.info("Notice UI: Scraping task completed successfully")
    socket = assign(socket,
      scraping_active: false,
      current_session: nil,
      scraping_task: nil,
      progress: Map.put(socket.assigns.progress, :status, :completed)
    )
    {:noreply, socket}
  end

  @impl true
  def handle_info({:scraping_failed, reason}, socket) do
    Logger.error("Notice UI: Scraping task failed: #{inspect(reason)}")
    socket = assign(socket,
      scraping_active: false,
      current_session: nil,
      scraping_task: nil,
      scraping_session_started_at: nil,
      scraped_notices: [],
      progress: Map.put(socket.assigns.progress, :status, :error)
    )
    {:noreply, put_flash(socket, :error, "Notice scraping failed: #{inspect(reason)}")}
  end

  @impl true
  def handle_info({ref, _result}, socket) when is_reference(ref) do
    # Task completion message - just acknowledge it
    Process.demonitor(ref, [:flush])
    {:noreply, socket}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    # Task monitor down message - clean up if needed
    if socket.assigns.scraping_active do
      Logger.warning("Notice UI: Scraping task process died unexpectedly")
      socket = assign(socket,
        scraping_active: false,
        current_session: nil,
        scraping_task: nil,
        scraping_session_started_at: nil,
        scraped_notices: [],
        progress: Map.put(socket.assigns.progress, :status, :error)
      )
      {:noreply, put_flash(socket, :error, "Notice scraping stopped unexpectedly")}
    else
      {:noreply, socket}
    end
  end

  # Catch-all handler for debugging
  @impl true
  def handle_info(message, socket) do
    message_str = inspect(message)
    cond do
      String.contains?(message_str, "scrape_session:updated") -> :noop
      String.contains?(message_str, "scrape_session:created") -> :noop
      String.contains?(message_str, "notice") or String.contains?(message_str, "synced") -> :noop
      true ->
        Logger.warning("Notice UI: Received unhandled message: #{String.slice(message_str, 0, 200)}...")
    end
    {:noreply, socket}
  end

  # Private Functions
  
  defp update_progress(socket, progress_updates) do
    updated_progress = Map.merge(socket.assigns.progress, progress_updates)
    socket = assign(socket, progress: updated_progress)
    
    # Force LiveView re-render by updating a timestamp
    assign(socket, last_update: System.monotonic_time(:millisecond))
  end
  
  defp complete_scraping_session(socket, data) do
    # Update progress with actual results from ScrapeCoordinator
    assign(socket,
      scraping_active: false,
      current_session: nil,
      progress: Map.merge(socket.assigns.progress, %{
        status: :completed,
        pages_processed: data.pages_processed,
        notices_found: data.cases_scraped,
        notices_created: data.cases_created,
        notices_exist_total: data.cases_exist_total,
        errors_count: data.errors
      }),
      session_results: [%{
        session_id: data.session_id,
        completed_at: DateTime.utc_now(),
        pages_processed: data.pages_processed,
        notices_created: data.cases_created,
        errors_count: data.errors
      } | socket.assigns.session_results]
    )
  end
  
  defp handle_scraping_error(socket, error_data) do
    error_info = %{
      timestamp: DateTime.utc_now(),
      page: Map.get(error_data, :current_page, Map.get(error_data, :page, "unknown")),
      message: Map.get(error_data, :reason, Map.get(error_data, :error, "Unknown error"))
    }
    
    assign(socket, recent_errors: [error_info | socket.assigns.recent_errors])
  end
  
  defp broadcast_scraping_event(event_type, data) do
    PubSub.broadcast(EhsEnforcement.PubSub, @pubsub_topic, {:scraping_event, event_type, data})
  end
  
  defp should_enable_real_time_progress?(actor) do
    config = ScrapeCoordinator.load_scraping_config(actor: actor)
    config.real_time_progress_enabled
  end
  
  defp progress_percentage(progress) do
    case progress.status do
      :idle -> 0
      :running when progress.pages_processed == 0 -> 5
      :running -> 
        # Calculate based on pages processed vs max pages
        total_pages = max(1, progress.max_pages || 1)
        processed = progress.pages_processed
        # Ensure we don't exceed 95% until completed
        min(95, (processed / total_pages) * 100)
      :completed -> 100
      :stopped -> 
        min(100, progress.pages_processed * 10)
      _ -> 0
    end
  end
  
  defp status_color(status) do
    case status do
      :idle -> "bg-gray-200"
      :running -> "bg-blue-500"
      :processing_page -> "bg-yellow-500"
      :completed -> "bg-green-500"
      :stopped -> "bg-red-500"
      _ -> "bg-gray-200"
    end
  end
  
  defp status_text(status) do
    case status do
      :idle -> "Ready to scrape notices"
      :running -> "Scraping notices in progress..."
      :processing_page -> "Processing notice page..."
      :completed -> "Notice scraping completed"
      :stopped -> "Notice scraping stopped"
      _ -> "Unknown status"
    end
  end
  

  # Pure Ash scraping function - updates ScrapeSession for progress tracking
  defp scrape_notices_with_session(session, opts) do
    alias EhsEnforcement.Agencies.Hse.NoticeScraper
    
    start_page = opts.start_page
    max_pages = opts.max_pages
    database = opts.database
    actor = opts.actor
    
    results = %{created_count: 0, error_count: 0, existing_count: 0}
    
    try do
      # Process each page (with early stopping)
      final_results = Enum.reduce_while(start_page..(start_page + max_pages - 1), results, fn page, acc ->
        Logger.info("Scraping notice page #{page}")
        
        # Update session with current page and reset page counters (Ash PubSub will notify UI)
        session
        |> Ash.Changeset.for_update(:update, %{
          current_page: page,
          pages_processed: page - start_page,
          cases_exist_current_page: 0  # Reset page counter
        })
        |> Ash.update!(actor: actor)
        
        case NoticeScraper.get_hse_notices(page_number: page, country: "United Kingdom") do
          basic_notices when is_list(basic_notices) ->
            Logger.info("Found #{length(basic_notices)} notices on page #{page}")
            
            # Process each notice individually with real-time session updates
            {page_results, page_existing_count} = Enum.reduce(basic_notices, {acc, 0}, fn basic_notice, {notice_acc, page_existing} ->
              if basic_notice.regulator_id && basic_notice.regulator_id != "" do
                # Process the notice
                prev_existing = notice_acc.existing_count
                updated_acc = process_single_notice_simple(basic_notice, database, actor, notice_acc)
                
                # Calculate if this notice was an existing (duplicate)
                notice_was_existing = updated_acc.existing_count > prev_existing
                new_page_existing = if notice_was_existing, do: page_existing + 1, else: page_existing
                
                # Update session immediately after each notice
                total_found = updated_acc.created_count + updated_acc.existing_count
                session
                |> Ash.Changeset.for_update(:update, %{
                  cases_found: total_found,
                  cases_created: updated_acc.created_count,
                  cases_exist_total: updated_acc.existing_count,
                  cases_exist_current_page: new_page_existing,
                  errors_count: updated_acc.error_count
                })
                |> Ash.update!(actor: actor)
                
                {updated_acc, new_page_existing}
              else
                {notice_acc, page_existing}
              end
            end)
            
            # Update session with completed page count
            session
            |> Ash.Changeset.for_update(:update, %{
              pages_processed: page - start_page + 1
            })
            |> Ash.update!(actor: actor)
            
            # Check stop rule: if all notices on current page exist, stop scraping
            if page_existing_count > 0 && page_existing_count == length(basic_notices) do
              Logger.info("Stopping notice scraping: all #{page_existing_count} notices on page #{page} already exist")
              {:halt, page_results}
            else
              {:cont, page_results}
            end
            
          {:error, reason} ->
            Logger.error("Failed to scrape notice page #{page}: #{inspect(reason)}")
            updated_acc = %{acc | error_count: acc.error_count + 1}
            
            # Update session with error
            session
            |> Ash.Changeset.for_update(:update, %{
              errors_count: updated_acc.error_count,
              pages_processed: page - start_page + 1
            })
            |> Ash.update!(actor: actor)
            
            {:cont, updated_acc}
        end
      end)
      
      # Mark session as completed
      session
      |> Ash.Changeset.for_update(:update, %{status: :completed})
      |> Ash.update!(actor: actor)
      
      {:ok, final_results}
    rescue
      error ->
        Logger.error("Notice scraping failed with error: #{inspect(error)}")
        
        # Mark session as failed
        session
        |> Ash.Changeset.for_update(:update, %{status: :failed})
        |> Ash.update!(actor: actor)
        
        {:error, error}
    end
  end
  
  defp process_single_notice_simple(basic_notice, _database, actor, results) do
    # Use NoticeProcessor for enrichment and creation
    case EhsEnforcement.Scraping.Hse.NoticeProcessor.process_and_create_notice(basic_notice, actor) do
      {:ok, notice_record} ->
        Logger.info("✅ Created notice: #{notice_record.regulator_id}")
        %{results | created_count: results.created_count + 1}
        
      {:error, %Ash.Error.Invalid{errors: errors}} ->
        if duplicate_error?(errors) do
          Logger.info("⏭️ Notice already exists: #{basic_notice.regulator_id}")
          
          # Update existing notice to trigger PubSub
          case EhsEnforcement.Enforcement.Notice
               |> Ash.Query.filter(regulator_id == ^basic_notice.regulator_id)
               |> Ash.read_one(actor: actor) do
            {:ok, existing_notice} when not is_nil(existing_notice) ->
              case Ash.update(existing_notice, %{}, actor: actor) do
                {:ok, _updated_notice} ->
                  Logger.info("✅ Updated existing notice: #{basic_notice.regulator_id}")
                {:error, error} ->
                  Logger.warning("Failed to update existing notice: #{inspect(error)}")
              end
            _ ->
              Logger.warning("Could not find existing notice to update: #{basic_notice.regulator_id}")
          end
          
          %{results | existing_count: results.existing_count + 1}
        else
          Logger.warning("❌ Error creating notice #{basic_notice.regulator_id}: #{inspect(errors)}")
          %{results | error_count: results.error_count + 1}
        end
        
      {:error, reason} ->
        Logger.warning("❌ Error processing notice #{basic_notice.regulator_id}: #{inspect(reason)}")
        %{results | error_count: results.error_count + 1}
    end
  end
  
  
  defp duplicate_error?(errors) when is_list(errors) do
    Enum.any?(errors, fn error ->
      case error do
        %{message: message} -> 
          String.contains?(message, "already exists") or 
          String.contains?(message, "duplicate") or
          String.contains?(message, "has already been taken")
        _ -> false
      end
    end)
  end
  
  defp duplicate_error?(_), do: false
end