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
    
    # Create AshPhoenix.Form for scraping parameters with agency and database defaults
    form = Form.for_create(ScrapeRequest, :create, as: "scrape_request", forms: [auto?: false]) 
    |> Form.validate(%{
      "agency" => "hse",
      "database" => "notices", 
      "country" => "All",
      "date_from" => Date.add(Date.utc_today(), -30) |> Date.to_string(),
      "date_to" => Date.utc_today() |> Date.to_string(),
      "action_types" => ["enforcement_notice"]
    })
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
        notices_created_current_page: 0,  # New: track created notices on current page
        notices_updated: 0,               # New: track total updated notices
        notices_updated_current_page: 0,  # New: track updated notices on current page
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
      last_update: System.monotonic_time(:millisecond),
      selected_agency: :hse  # Track selected agency for dynamic UI
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
    # Get selected agency and set appropriate defaults
    selected_agency = case params["agency"] do
      "environment_agency" -> :environment_agency
      "hse" -> :hse
      _ -> :hse  # Default to HSE
    end
    
    # Set agency-specific defaults
    params_with_defaults = case selected_agency do
      :environment_agency ->
        params
        |> Map.put("agency", "environment_agency")
        |> Map.put("action_types", ["enforcement_notice"])
        |> Map.put_new("date_from", Date.add(Date.utc_today(), -30) |> Date.to_string())
        |> Map.put_new("date_to", Date.utc_today() |> Date.to_string())
        |> Map.delete("database")  # EA doesn't use database parameter
        |> Map.delete("country")   # EA doesn't use country parameter
        
      :hse ->
        params
        |> Map.put("agency", "hse")
        |> Map.put("database", "notices")
        |> Map.put_new("country", "All")
        |> Map.delete("action_types")  # HSE doesn't use action_types for notices
        |> Map.delete("date_from")     # HSE doesn't use date range
        |> Map.delete("date_to")
    end
    
    form = Form.validate(socket.assigns.form, params_with_defaults) |> to_form()
    {:noreply, assign(socket, form: form, selected_agency: selected_agency)}
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
      params_with_notices = params
      |> Map.put("database", "notices")
      |> Map.put_new("country", "All")  # Default to All if not provided
      
      # First validate the form with the new params, then submit
      validated_form = Form.validate(socket.assigns.form, params_with_notices)
      case Form.submit(validated_form, params: params_with_notices) do
        {:ok, scrape_request} ->
          # Extract validated parameters from the created resource
          # Note: max_pages field now represents "end page" instead of "number of pages"
          end_page = scrape_request.max_pages
          start_page = scrape_request.start_page
          pages_to_scrape = max(1, end_page - start_page + 1)
          
          validated_params = %{
            start_page: start_page,
            end_page: end_page,
            max_pages: pages_to_scrape,  # Calculated number of pages
            database: "notices",  # Force notices
            country: scrape_request.country || "All"
          }
        
        # Simplified scraping - just create Notices directly (no tracking tables needed)
        scraping_opts = %{
          start_page: validated_params.start_page,
          max_pages: validated_params.max_pages,
          database: "notices",
          country: validated_params.country,
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
            current_page: validated_params.start_page,
            pages_processed: 0,  # Ensure we start from 0 processed pages
            max_pages: validated_params.max_pages  # Store for percentage calculation
          })
        )
        
        # Start simple scraping task
        Logger.info("Starting simple notice scraping: pages #{scraping_opts.start_page}-#{validated_params.end_page}")
        
        # Create ScrapeSession using Ash (pure Ash approach)
        session = EhsEnforcement.Scraping.ScrapeSession
        |> Ash.Changeset.for_create(:create, %{
          session_id: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower),
          start_page: validated_params.start_page,
          max_pages: validated_params.max_pages,
          end_page: validated_params.end_page,
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

  @impl true
  def handle_event("clear_progress", _params, socket) do
    # Reset progress to initial state
    socket = assign(socket, 
      progress: %{
        pages_processed: 0,
        notices_found: 0,
        notices_created: 0,
        notices_created_current_page: 0,
        notices_updated: 0,
        notices_updated_current_page: 0,
        notices_exist_total: 0,
        notices_exist_current_page: 0,
        errors_count: 0,
        current_page: nil,
        status: :idle
      }
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
      
      # Keep all notices from the current scraping session (no arbitrary limit)
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

  # Handle scrape session updates (the key to progress updates)
  @impl true  
  def handle_info(%Phoenix.Socket.Broadcast{topic: "scrape_session:updated", event: "update", payload: %Ash.Notifier.Notification{} = notification}, socket) do
    session_data = notification.data
    handle_scrape_session_update(session_data, socket)
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
    alias EhsEnforcement.Scraping.Hse.NoticeScraper
    
    start_page = opts.start_page
    max_pages = opts.max_pages
    database = opts.database
    actor = opts.actor
    
    results = %{created_count: 0, error_count: 0, existing_count: 0, updated_count: 0}
    
    try do
      # Process each page (with early stopping) - use end_page from session or calculate from max_pages
      end_page = session.end_page || (start_page + max_pages - 1)
      final_results = Enum.reduce_while(start_page..end_page, results, fn page, acc ->
        Logger.info("Scraping notice page #{page}")
        
        # Update session with current page and reset page counters (Ash PubSub will notify UI)
        # pages_processed should be cumulative count, not current page offset
        pages_completed_so_far = page - start_page
        Logger.debug("Scraping page #{page}: updating session with pages_processed=#{pages_completed_so_far}")
        
        session
        |> Ash.Changeset.for_update(:update, %{
          current_page: page,
          pages_processed: pages_completed_so_far,
          cases_exist_current_page: 0,     # Reset page counter
          cases_created_current_page: 0,   # Reset page counter
          cases_updated_current_page: 0    # Reset page counter
        })
        |> Ash.update!(actor: actor)
        
        # HSE website uses separate country filters for England, Scotland, Wales
        # Use selected country or scrape all three for comprehensive UK coverage
        countries_to_scrape = case opts.country do
          "All" -> ["England", "Scotland", "Wales"]
          country -> [country]
        end
        
        all_notices = countries_to_scrape
        |> Enum.flat_map(fn country ->
          case NoticeScraper.get_hse_notices(page_number: page, country: country) do
            notices when is_list(notices) ->
              Logger.info("Found #{length(notices)} notices on page #{page} for #{country}")
              notices
            {:error, reason} ->
              Logger.warning("Failed to get notices for #{country} on page #{page}: #{inspect(reason)}")
              []
          end
        end)
        
        case all_notices do
          basic_notices when is_list(basic_notices) ->
            Logger.info("Found #{length(basic_notices)} total notices on page #{page} (combined from all countries)")
            
            # Filter processable notices upfront for accurate early stopping calculation
            processable_notices = Enum.filter(basic_notices, fn notice ->
              notice.regulator_id && notice.regulator_id != ""
            end)
            Logger.info("Processable notices (with regulator_id): #{length(processable_notices)} of #{length(basic_notices)}")
            
            # Process each notice individually with real-time session updates
            {page_results, page_existing_count, _page_created_count, _page_updated_count} = Enum.reduce(processable_notices, {acc, 0, 0, 0}, fn basic_notice, {notice_acc, page_existing, page_created, page_updated} ->
              # Process the notice (no need for regulator_id check since we pre-filtered)
              prev_existing = notice_acc.existing_count
              prev_created = notice_acc.created_count
              prev_updated = notice_acc.updated_count || 0
              
              updated_acc = process_single_notice_simple(basic_notice, database, actor, notice_acc)
              
              # Calculate what happened with this notice
              notice_was_existing = updated_acc.existing_count > prev_existing
              notice_was_created = updated_acc.created_count > prev_created
              notice_was_updated = (updated_acc.updated_count || 0) > prev_updated
              
              new_page_existing = if notice_was_existing, do: page_existing + 1, else: page_existing
              new_page_created = if notice_was_created, do: page_created + 1, else: page_created
              new_page_updated = if notice_was_updated, do: page_updated + 1, else: page_updated
              
              # Update session immediately after each notice (match Cases pattern exactly)
              total_found = updated_acc.created_count + updated_acc.existing_count
              session
              |> Ash.Changeset.for_update(:update, %{
                cases_found: total_found,
                cases_created: updated_acc.created_count,
                cases_created_current_page: new_page_created,
                cases_updated: updated_acc.updated_count || 0,
                cases_updated_current_page: new_page_updated,
                cases_exist_total: updated_acc.existing_count,
                cases_exist_current_page: new_page_existing,
                errors_count: updated_acc.error_count
              })
              |> Ash.update!(actor: actor)
              
              {updated_acc, new_page_existing, new_page_created, new_page_updated}
            end)
            
            # Update session with completed page count (increment by 1 after page completion)
            pages_completed = page - start_page + 1
            session
            |> Ash.Changeset.for_update(:update, %{
              pages_processed: pages_completed
            })
            |> Ash.update!(actor: actor)
            
            # Check stop rule: if all processable notices on current page exist, stop scraping
            # Compare against processable_notices count, not total basic_notices
            if page_existing_count > 0 && page_existing_count == length(processable_notices) do
              Logger.info("Stopping notice scraping: all #{page_existing_count} processable notices on page #{page} already exist (#{length(basic_notices)} total notices found)")
              {:halt, page_results}
            else
              {:cont, page_results}
            end
            
          {:error, reason} ->
            Logger.error("Failed to scrape notice page #{page}: #{inspect(reason)}")
            updated_acc = %{acc | error_count: acc.error_count + 1}
            
            # Update session with error
            pages_completed = page - start_page + 1
            session
            |> Ash.Changeset.for_update(:update, %{
              errors_count: updated_acc.error_count,
              pages_processed: pages_completed
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
                  %{results | existing_count: results.existing_count + 1, updated_count: results.updated_count + 1}
                {:error, error} ->
                  Logger.warning("Failed to update existing notice: #{inspect(error)}")
                  %{results | existing_count: results.existing_count + 1}
              end
            _ ->
              Logger.warning("Could not find existing notice to update: #{basic_notice.regulator_id}")
              %{results | existing_count: results.existing_count + 1}
          end
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

  defp handle_scrape_session_update(session_data, socket) do
    # Log session update for debugging progress issues
    Logger.debug("Scrape session update: status=#{session_data.status}, current_page=#{session_data.current_page}, pages_processed=#{session_data.pages_processed}, cases_found=#{session_data.cases_found}")
    
    # When status becomes :completed, preserve the best available progress data
    # Don't let session updates reset progress values to 0 after completion
    current_progress = socket.assigns.progress
    
    updated_progress = if session_data.status == :completed do
      # For completed status, preserve the highest values we've seen
      %{
        status: :completed,
        current_page: max(current_progress.current_page || 0, session_data.current_page || 0),
        pages_processed: max(current_progress.pages_processed || 0, session_data.pages_processed || 0),
        notices_found: max(current_progress.notices_found || 0, session_data.cases_found || 0),
        notices_created: max(current_progress.notices_created || 0, session_data.cases_created || 0),
        notices_created_current_page: max(current_progress.notices_created_current_page || 0, session_data.cases_created_current_page || 0),
        notices_updated: max(current_progress.notices_updated || 0, session_data.cases_updated || 0),
        notices_updated_current_page: max(current_progress.notices_updated_current_page || 0, session_data.cases_updated_current_page || 0),
        notices_exist_total: max(current_progress.notices_exist_total || 0, session_data.cases_exist_total || 0),
        notices_exist_current_page: max(current_progress.notices_exist_current_page || 0, session_data.cases_exist_current_page || 0),
        errors_count: max(current_progress.errors_count || 0, session_data.errors_count || 0),
        max_pages: current_progress.max_pages || session_data.max_pages  # Keep max_pages for percentage
      }
    else
      # For non-completed status, use session data as before
      %{
        status: session_data.status,
        current_page: session_data.current_page,
        pages_processed: session_data.pages_processed,
        notices_found: session_data.cases_found || 0,  # Notice: session uses "cases_found" field
        notices_created: session_data.cases_created || 0,  # Notice: session uses "cases_created" field
        notices_created_current_page: session_data.cases_created_current_page || 0,
        notices_updated: session_data.cases_updated || 0,
        notices_updated_current_page: session_data.cases_updated_current_page || 0,
        notices_exist_total: session_data.cases_exist_total || 0,
        notices_exist_current_page: session_data.cases_exist_current_page || 0,
        errors_count: session_data.errors_count || 0,
        max_pages: session_data.max_pages  # Add for percentage calculation
      }
    end
    
    # When session becomes completed, also update scraping_active and clean up session references
    socket = if session_data.status == :completed do
      # Store the final results for later viewing  
      completion_result = %{
        session_id: session_data.session_id,
        completed_at: DateTime.utc_now(),
        pages_processed: updated_progress.pages_processed,
        notices_found: updated_progress.notices_found,
        notices_created: updated_progress.notices_created,
        notices_exist_total: updated_progress.notices_exist_total,
        errors_count: updated_progress.errors_count
      }
      
      assign(socket, 
        progress: updated_progress,
        last_update: System.monotonic_time(:millisecond),
        scraping_active: false,  # Hide Stop button, show Start button 
        current_session: nil,    # Clear session reference
        scraping_task: nil,      # Clear task reference
        session_results: [completion_result | socket.assigns.session_results]  # Add to results history
      )
    else
      assign(socket, 
        progress: updated_progress,
        last_update: System.monotonic_time(:millisecond)
      )
    end
    
    # Also trigger keep_live refresh for active_sessions (matching Cases pattern)
    {:noreply, AshPhoenix.LiveView.handle_live(socket, "scrape_session:updated", [:active_sessions])}
  end
end