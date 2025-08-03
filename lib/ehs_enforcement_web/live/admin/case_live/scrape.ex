defmodule EhsEnforcementWeb.Admin.CaseLive.Scrape do
  @moduledoc """
  Admin interface for manual HSE case scraping with real-time progress display.
  
  Features:
  - Manual scraping trigger with configurable parameters
  - Real-time progress updates via Phoenix PubSub
  - Scraping session management and results display  
  - Error reporting and recovery options
  - Proper Ash integration with actor context
  """
  
  use EhsEnforcementWeb, :live_view
  
  require Logger
  require Ash.Query
  import Ash.Expr
  
  alias EhsEnforcement.Scraping.ScrapeCoordinator
  alias EhsEnforcement.Scraping.ScrapeRequest
  alias EhsEnforcement.Scraping.ScrapeSession
  alias EhsEnforcement.Scraping.CaseProcessingLog
  alias EhsEnforcement.Scraping.ScrapedCase
  alias EhsEnforcement.Enforcement
  alias AshPhoenix.Form
  alias Phoenix.PubSub
  
  @pubsub_topic "scraping_progress"
  
  # LiveView Callbacks
  
  @impl true
  def mount(_params, _session, socket) do
    # Check if manual scraping is enabled via feature flag
    manual_scraping_enabled = ScrapeCoordinator.scraping_enabled?(type: :manual, actor: socket.assigns[:current_user])
    
    # Ash PubSub handles scraping progress updates automatically via keep_live
    
    # Create AshPhoenix.Form for scraping parameters with convictions database default
    form = Form.for_create(ScrapeRequest, :create, as: "scrape_request", forms: [auto?: false]) 
    |> Form.validate(%{"database" => "convictions"})
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
      
      # Progress tracking
      progress: %{
        pages_processed: 0,
        cases_found: 0,
        cases_created: 0,
        cases_exist_total: 0,
        cases_exist_current_page: 0,
        errors_count: 0,
        current_page: nil,
        status: :idle
      },
      
      # Results and errors - will load from actual Ash resources
      session_results: [],
      recent_errors: [],
      recent_cases: [],
      # Initialize empty values - will be populated by keep_live
      case_processing_log: [],
      scraped_cases: [],  # Initial empty state before keep_live takes over
      
      # UI state
      loading: false,
      last_update: System.monotonic_time(:millisecond)
    )
    
    # Load recent cases data using proper AshPhoenix.LiveView reactive patterns
    if connected?(socket) do
      
      # Note: Removed manual subscription - using keep_live subscriptions only
      
      # Use pure Ash patterns for reactivity
      
      # Use AshPhoenix.LiveView.keep_live for automatic reactive case updates
      socket = AshPhoenix.LiveView.keep_live(socket, :recent_cases, fn socket ->
        EhsEnforcement.Enforcement.Case
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.limit(100)
        |> Ash.Query.load([:agency, :offender])
        |> Ash.read!(actor: socket.assigns.current_user)
      end,
        subscribe: ["case:created:*", "case:updated:*", "case:bulk_created"],
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
      
      # Use AshPhoenix.LiveView.keep_live for reactive case processing log updates
      socket = AshPhoenix.LiveView.keep_live(socket, :case_processing_log, fn _socket ->
        CaseProcessingLog
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.limit(50)
        |> Ash.read!()
      end,
        subscribe: ["case_processing_log:created"],
        results: :keep,
        load_until_connected?: true,
        refetch_window: :timer.seconds(1)
      )
      
      # Manual PubSub subscription for scraped cases - use direct state management
      # instead of keep_live to avoid timing issues with session-specific data
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case:scraped:updated")
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case:created")
      
      {:ok, socket}
    else
      {:ok, socket}
    end
  end
  
  @impl true 
  def handle_event("validate", %{"scrape_request" => params}, socket) do
    # Ensure database is always "convictions" for this interface
    params_with_convictions = Map.put(params, "database", "convictions")
    form = Form.validate(socket.assigns.form, params_with_convictions) |> to_form()
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("submit", %{"scrape_request" => params}, socket) do
    Logger.info("Admin triggered manual scraping with params: #{inspect(params)}")
    
    # Check if manual scraping is enabled via feature flag
    unless socket.assigns.manual_scraping_enabled do
      socket = put_flash(socket, :error, "Manual scraping is currently disabled. Please contact an administrator.")
      {:noreply, socket}
    else
      # First validate the form with the new params, then submit
      validated_form = Form.validate(socket.assigns.form, params)
      case Form.submit(validated_form, params: params) do
        {:ok, scrape_request} ->
          # Extract validated parameters from the created resource
          validated_params = %{
            start_page: scrape_request.start_page,
            max_pages: scrape_request.max_pages,
            database: scrape_request.database
          }
        # Simplified scraping - just create Cases directly (no tracking tables needed)
        scraping_opts = %{
          start_page: validated_params.start_page,
          max_pages: validated_params.max_pages,
          database: "convictions",
          actor: socket.assigns.current_user
        }
        
        # Set session start time FIRST, before starting background task
        # This ensures PubSub events from the task are captured
        session_start_time = DateTime.add(DateTime.utc_now(), -5, :second)
        
        # Update socket BEFORE starting background task
        socket = assign(socket,
          scraping_active: true,
          scraping_session_started_at: session_start_time,  # Set BEFORE task starts
          scraped_cases: [],  # Clear previous session's cases
          progress: Map.merge(socket.assigns.progress, %{
            status: :running,
            current_page: validated_params.start_page
          })
        )
        
        # Start simple scraping task
        _liveview_pid = self()
        Logger.info("Starting simple case scraping: pages #{scraping_opts.start_page}-#{scraping_opts.start_page + scraping_opts.max_pages - 1}")
        
        # Create ScrapeSession using Ash (pure Ash approach)
        session = EhsEnforcement.Scraping.ScrapeSession
        |> Ash.Changeset.for_create(:create, %{
          session_id: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower),
          start_page: validated_params.start_page,
          max_pages: validated_params.max_pages,
          database: "convictions",
          status: :running,
          current_page: validated_params.start_page
        })
        |> Ash.create!(actor: socket.assigns.current_user)
        
        task = Task.async(fn ->
          case scrape_cases_with_session(session, scraping_opts) do
            {:ok, results} ->
              Logger.info("Scraping completed: #{results.created_count} cases created")
              
            {:error, reason} ->
              Logger.error("Scraping failed: #{inspect(reason)}")
          end
        end)
        
        # Create a temporary session for UI state (the real session runs in background)
        _temp_session = %{
          session_id: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower),
          current_page: validated_params.start_page
        }
        
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
        Logger.info("Admin requested to stop scraping session: #{session_id}")
        
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
          scraping_session_started_at: nil,  # Clear session start time
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
          scraping_session_started_at: nil,  # Clear session start time
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
  def handle_event("clear_scraped_cases", _params, socket) do
    # Clear the scraped cases list and session start time
    socket = assign(socket, 
      scraped_cases: [],
      scraping_session_started_at: nil
    )
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("clear_processing_log", _params, socket) do
    # Clear processing logs via Ash (use bulk destroy)
    case Ash.bulk_destroy(CaseProcessingLog, :destroy, %{}) do
      %Ash.BulkResult{} -> Logger.info("Cleared all case processing logs")
      {:error, reason} -> Logger.warning("Failed to clear processing logs: #{inspect(reason)}")
    end
    {:noreply, socket}
  end
  
  # Catch-all event handler to debug what events we're receiving
  @impl true
  def handle_event(event, params, socket) do
    Logger.warning("UI: Received unhandled event: #{event} with params: #{inspect(params)}")
    {:noreply, socket}
  end
  
  # PubSub Message Handling
  
  @impl true
  def handle_info({:started, data}, socket) do
    
    # Only update progress, don't change scraping_active
    # scraping_active should only be set when user explicitly starts/stops scraping
    progress_updates = %{
      status: :running,
      current_page: data.current_page,
      pages_processed: data.pages_processed,
      cases_found: data.cases_scraped,
      cases_created: data.cases_created,
      cases_exist_total: data.cases_exist_total,
      cases_exist_current_page: data.cases_exist_current_page,
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
    
    # Add a placeholder entry showing page is being processed
    _placeholder_case = %{
      regulator_id: "PAGE #{data.current_page}",
      offender_name: "Scraping in progress...",
      offence_action_date: nil,
      offence_fine: nil,
      offence_result: nil,
      
      # Two-phase status system
      processing_status: :scraping,
      database_status: nil,
      
      # Meta data for display
      scraped_at: DateTime.utc_now(),
      page: data.current_page,
      
      # Generate a unique ID for frontend tracking
      temp_id: "page_#{data.current_page}_placeholder"
    }
    
    # Note: scraped_cases will be updated automatically via keep_live when cases are created/updated
    # No manual assignment needed here
    
    socket = update_progress(socket, %{
      current_page: data.current_page,
      pages_processed: data.pages_processed,
      cases_found: data.cases_scraped,
      cases_created: data.cases_created,
      cases_exist_total: data.cases_exist_total,
      cases_exist_current_page: 0,  # Reset counter for new page
      errors_count: data.errors,
      status: :processing_page
    })
    
    {:noreply, socket}
  end

  @impl true
  def handle_info({:page_completed, data}, socket) do
    
    # Extract case details for display
    case_details = build_case_details(data)
    
    progress_updates = %{
      pages_processed: data.pages_processed,
      cases_found: data.cases_scraped,
      cases_created: data.cases_created,
      cases_exist_total: data.cases_exist_total,
      cases_exist_current_page: data.cases_exist_current_page,
      errors_count: data.errors,  # Use errors instead of cases_skipped
      current_page: data.current_page,
      status: :processing_page
    }
    
    updated_socket = update_progress(socket, progress_updates)
    
    # Add detailed case information to the UI
    socket_with_details = add_case_processing_details(updated_socket, case_details)
    
    # Note: scraped_cases will be updated automatically via keep_live - no manual updates needed
    
    # Check if scraping should stop due to all cases existing on current page
    final_socket = if Map.get(data, :should_stop_all_exist, false) do
      Logger.info("UI: Scraping stopped - all cases on page #{data.current_page} already exist")
      assign(socket_with_details, 
        scraping_active: false,
        progress: Map.put(socket_with_details.assigns.progress, :status, :completed)
      )
    else
      socket_with_details
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
  
  @impl true
  def handle_info({:recent_data_loaded, data}, socket) do
    socket = assign(socket, 
      recent_cases: data.recent_cases,
      loading: false
    )
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:recent_data_error, _error}, socket) do
    socket = assign(socket, loading: false)
    {:noreply, put_flash(socket, :error, "Failed to load recent data")}
  end

  # Remove manual PubSub handlers - using pure Ash patterns only

  # Handle Ash ScrapeSession notifications
  @impl true
  def handle_info({"create", %Ash.Notifier.Notification{resource: EhsEnforcement.Scraping.ScrapeSession, data: _session_data}}, socket) do
    # Legacy handler format - keeping for compatibility
    {:noreply, AshPhoenix.LiveView.handle_live(socket, "scrape_session:created", [:active_sessions])}
  end
  
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "scrape_session:created", event: "create", payload: %Ash.Notifier.Notification{} = _notification}, socket) do
    {:noreply, AshPhoenix.LiveView.handle_live(socket, "scrape_session:created", [:active_sessions])}
  end

  @impl true
  def handle_info({"update", %Ash.Notifier.Notification{resource: EhsEnforcement.Scraping.ScrapeSession, data: session_data}}, socket) do
    # Legacy handler format - keeping for compatibility
    handle_scrape_session_update(session_data, socket)
  end
  
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "scrape_session:updated", event: "update", payload: %Ash.Notifier.Notification{} = notification}, socket) do
    session_data = notification.data
    handle_scrape_session_update(session_data, socket)
  end
  

  # Ash Notification Handlers for keep_live (Phoenix.Socket.Broadcast format)
  
  @impl true
  # Catch-all handler to debug what events are actually being fired
  def handle_info(%Phoenix.Socket.Broadcast{topic: "case:scraped:updated"} = broadcast, socket) do
    
    # Handle the actual event regardless of event name
    socket = case broadcast.payload do
      %Ash.Notifier.Notification{} = notification ->
        
        # Only add to scraped_cases if we have an active session
        # Since we're receiving this PubSub event during scraping, the case was just processed
        if socket.assigns.scraping_session_started_at do
          
          # Load full case data with associations
          case = EhsEnforcement.Enforcement.Case
          |> Ash.get!(notification.data.id, load: [:agency, :offender], actor: socket.assigns.current_user)
          
          
          # Remove any existing entry for this case (deduplicate by regulator_id)
          existing_cases = Enum.reject(socket.assigns.scraped_cases, fn existing -> 
            existing.regulator_id == case.regulator_id 
          end)
          
          # Add to the beginning of the list (most recent first)
          updated_scraped_cases = [case | existing_cases]
          
          # Keep only the most recent 50 cases
          updated_scraped_cases = Enum.take(updated_scraped_cases, 50)
          
          assign(socket, scraped_cases: updated_scraped_cases)
        else
          socket
        end
        
      _ ->
        socket
    end
    
    {:noreply, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "case:created", event: "create", payload: %Ash.Notifier.Notification{} = notification}, socket) do
    
    # Only add to scraped_cases if we have an active session
    socket = if socket.assigns.scraping_session_started_at do
      # Load full case data with associations
      case = EhsEnforcement.Enforcement.Case
      |> Ash.get!(notification.data.id, load: [:agency, :offender], actor: socket.assigns.current_user)
      
      
      # Add to the beginning of the list (most recent first)
      updated_scraped_cases = [case | socket.assigns.scraped_cases]
      
      # Keep only the most recent 50 cases
      updated_scraped_cases = Enum.take(updated_scraped_cases, 50)
      
      assign(socket, scraped_cases: updated_scraped_cases)
    else
      socket
    end
    
    {:noreply, socket}
  end



  @impl true
  def handle_info({:refetch, :active_sessions, _opts}, socket) do
    # This message is from AshPhoenix.LiveView telling us to refetch active scraping sessions
    # The keep_live query should run automatically
    {:noreply, socket}
  end

  @impl true
  def handle_info({:refetch, :recent_cases, _opts}, socket) do
    # This message is from AshPhoenix.LiveView telling us to refetch recent cases
    # The keep_live query should run automatically
    {:noreply, socket}
  end

  @impl true
  def handle_info({:refetch, :case_processing_log, _opts}, socket) do
    # This message is from AshPhoenix.LiveView telling us to refetch case processing logs
    # The keep_live query should run automatically
    {:noreply, socket}
  end

  # Note: Manual PubSub handlers removed - now using Ash notifications via keep_live

  # Task completion handlers
  
  @impl true
  def handle_info({:scraping_completed, _session}, socket) do
    Logger.info("UI: Scraping task completed successfully")
    socket = assign(socket,
      scraping_active: false,
      current_session: nil,
      scraping_task: nil,
      # Don't clear scraping_session_started_at here - keep showing results after completion
      progress: Map.put(socket.assigns.progress, :status, :completed)
      # Keep scraped_cases after completion so user can see results
    )
    {:noreply, socket}
  end

  @impl true
  def handle_info({:scraping_failed, reason}, socket) do
    Logger.error("UI: Scraping task failed: #{inspect(reason)}")
    socket = assign(socket,
      scraping_active: false,
      current_session: nil,
      scraping_task: nil,
      scraping_session_started_at: nil,  # Clear session start time on failure
      scraped_cases: [],  # Clear scraped cases on failure
      progress: Map.put(socket.assigns.progress, :status, :error)
    )
    {:noreply, put_flash(socket, :error, "Scraping failed: #{inspect(reason)}")}
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
      Logger.warning("UI: Scraping task process died unexpectedly")
      socket = assign(socket,
        scraping_active: false,
        current_session: nil,
        scraping_task: nil,
        scraping_session_started_at: nil,  # Clear session start time on unexpected death
        scraped_cases: [],  # Clear scraped cases on unexpected death
        progress: Map.put(socket.assigns.progress, :status, :error)
      )
      {:noreply, put_flash(socket, :error, "Scraping stopped unexpectedly")}
    else
      {:noreply, socket}
    end
  end

  # Catch-all handler to debug what messages we're actually receiving
  @impl true
  def handle_info(message, socket) do
    # Only log truly unhandled messages to avoid spam
    message_str = inspect(message)
    cond do
      # Skip logging for messages we know about but don't need specific handlers for
      String.contains?(message_str, "scrape_session:updated") ->
        :noop
        
      String.contains?(message_str, "scrape_session:created") ->
        :noop
        
      # Log other case/synced messages for debugging
      String.contains?(message_str, "case") or String.contains?(message_str, "synced") ->
        :noop
      # Log truly unhandled messages
      true ->
        Logger.warning("UI: Received unhandled message: #{String.slice(message_str, 0, 200)}...")
    end
    {:noreply, socket}
  end

  
  # Private Functions
  
  defp validate_scraping_params(params) do
    errors = []
    
    start_page = parse_integer(params["start_page"], 1)
    max_pages = parse_integer(params["max_pages"], 10)
    database = params["database"] || "convictions"
    
    errors = if start_page < 1, do: ["Start page must be greater than 0" | errors], else: errors
    errors = if max_pages < 1, do: ["Max pages must be greater than 0" | errors], else: errors
    errors = if max_pages > 100, do: ["Max pages cannot exceed 100" | errors], else: errors
    errors = if database not in ["convictions", "notices"], do: ["Invalid database selection" | errors], else: errors
    
    case errors do
      [] -> {:ok, %{start_page: start_page, max_pages: max_pages, database: database}}
      _ -> {:error, errors}
    end
  end
  
  # load_recent_data/1 function removed - now handled by keep_live/4 automatically
  
  
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
        cases_found: data.cases_scraped,
        cases_created: data.cases_created,
        cases_exist_total: data.cases_exist_total,
        errors_count: data.errors
      }),
      session_results: [%{
        session_id: data.session_id,
        completed_at: DateTime.utc_now(),
        pages_processed: data.pages_processed,
        cases_created: data.cases_created,
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
  
  # defp broadcast_progress(event_type, data) do
  #   PubSub.broadcast(EhsEnforcement.PubSub, @pubsub_topic, {:scraping_progress, event_type, data})
  # end
  # Removed: function not used in this module
  
  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> default
    end
  end
  defp parse_integer(value, _default) when is_integer(value), do: value
  defp parse_integer(_, default), do: default
  
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
        # Better estimate based on processed pages
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
      :idle -> "Ready to scrape"
      :running -> "Scraping in progress..."
      :processing_page -> "Processing page..."
      :completed -> "Scraping completed"
      :stopped -> "Scraping stopped"
      _ -> "Unknown status"
    end
  end
  
  defp build_case_details(data) do
    %{
      page: data.current_page,
      timestamp: DateTime.utc_now(),
      cases_scraped: length(data[:scraped_cases] || []),
      cases_created: Map.get(data, :cases_created, 0),
      cases_skipped: Map.get(data, :cases_skipped, 0),
      existing_count: Map.get(data, :existing_count, 0),
      scraped_cases: extract_case_summary(data[:scraped_cases] || []),
      creation_errors: extract_creation_errors(data[:creation_results])
    }
  end
  
  defp extract_case_summary(scraped_cases) do
    Enum.map(scraped_cases, fn case_data ->
      %{
        regulator_id: case_data.regulator_id,
        offender_name: case_data.offender_name,
        case_date: case_data.offence_action_date,
        fine_amount: case_data.offence_fine
      }
    end)
  end
  
  defp extract_creation_errors(creation_results) do
    case creation_results do
      %{errors: errors} when is_list(errors) ->
        Enum.map(errors, fn error ->
          case error do
            {case_id, error_msg} -> %{case_id: case_id, error: error_msg}
            _ -> %{error: inspect(error)}
          end
        end)
      _ -> []
    end
  end
  
  defp add_case_processing_details(socket, case_details) do
    updated_log = [case_details | socket.assigns.case_processing_log]
    |> Enum.take(50)  # Keep last 50 processing events
    
    assign(socket, case_processing_log: updated_log)
  end
  
  
  defp replace_placeholder_with_real_cases(socket, page_data) do
    # Remove placeholder for this page and replace with real scraped cases
    scraped_cases_from_page = page_data[:scraped_cases] || []
    creation_results = page_data[:creation_results] || %{}
    current_page = page_data.current_page
    
    # Remove placeholder for this page
    scraped_cases_without_placeholder = Enum.reject(socket.assigns.scraped_cases, fn case_item ->
      case_item.temp_id == "page_#{current_page}_placeholder"
    end)
    
    # Add real cases with two-phase status
    real_cases = Enum.map(scraped_cases_from_page, fn case_data ->
      save_status = determine_case_save_status(case_data, creation_results)
      
      %{
        # Core case data from scraping
        regulator_id: case_data.regulator_id,
        offender_name: case_data.offender_name,
        offence_action_date: case_data.offence_action_date,
        offence_fine: case_data.offence_fine,
        offence_result: case_data.offence_result,
        
        # Two-phase status system - these cases went: scraping -> scraped -> ready_for_db
        processing_status: :ready_for_db,
        database_status: save_status,
        
        # Meta data for display
        scraped_at: DateTime.utc_now(),
        page: page_data.current_page,
        
        # Generate a unique ID for frontend tracking
        temp_id: "#{case_data.regulator_id}_#{page_data.current_page}_#{System.unique_integer()}"
      }
    end)
    
    # Combine real cases with existing cases (placeholder removed)
    final_scraped_cases = (real_cases ++ scraped_cases_without_placeholder)
    |> Enum.take(200)  # Keep last 200 scraped cases for performance
    
    
    assign(socket, scraped_cases: final_scraped_cases)
  end
  
  defp update_scraped_cases_with_database_status(socket, page_data) do
    # Update existing cases with database save results when page_completed
    scraped_cases_from_page = page_data[:scraped_cases] || []
    creation_results = page_data[:creation_results] || %{}
    current_page = page_data.current_page
    
    # Update existing scraped_cases that match this page
    updated_scraped_cases = Enum.map(socket.assigns.scraped_cases, fn case_item ->
      if case_item.page == current_page and case_item.processing_status != nil do
        # Find matching case data from scraping results
        matching_scraped = Enum.find(scraped_cases_from_page, fn scraped ->
          scraped.regulator_id == case_item.regulator_id
        end)
        
        if matching_scraped do
          # Update with complete scraped data and database status
          save_status = determine_case_save_status(matching_scraped, creation_results)
          
          %{case_item |
            # Update with complete case data
            offender_name: matching_scraped.offender_name,
            offence_action_date: matching_scraped.offence_action_date,
            offence_fine: matching_scraped.offence_fine,
            offence_result: matching_scraped.offence_result,
            
            # Update status progression
            processing_status: :ready_for_db,
            database_status: save_status,
            
            # Update metadata
            scraped_at: DateTime.utc_now()
          }
        else
          # Case wasn't in the completed results, mark as error
          %{case_item |
            processing_status: :error,
            database_status: :error
          }
        end
      else
        # Case is from different page or already processed, leave unchanged
        case_item
      end
    end)
    
    # Also add any new cases that weren't in the processing list
    new_cases = Enum.reject(scraped_cases_from_page, fn scraped ->
      Enum.any?(socket.assigns.scraped_cases, fn existing ->
        existing.regulator_id == scraped.regulator_id and existing.page == current_page
      end)
    end)
    
    # Add new cases that appeared in completed results but weren't in processing
    additional_cases = Enum.map(new_cases, fn case_data ->
      save_status = determine_case_save_status(case_data, creation_results)
      
      %{
        # Core case data from scraping
        regulator_id: case_data.regulator_id,
        offender_name: case_data.offender_name,
        offence_action_date: case_data.offence_action_date,
        offence_fine: case_data.offence_fine,
        offence_result: case_data.offence_result,
        
        # Two-phase status system - these cases completed quickly
        processing_status: :ready_for_db,
        database_status: save_status,
        
        # Meta data for display
        scraped_at: DateTime.utc_now(),
        page: page_data.current_page,
        
        # Generate a unique ID for frontend tracking
        temp_id: "#{case_data.regulator_id}_#{page_data.current_page}_#{System.unique_integer()}"
      }
    end)
    
    # Combine updated cases with any additional cases
    final_scraped_cases = (additional_cases ++ updated_scraped_cases)
    |> Enum.take(200)  # Keep last 200 scraped cases for performance
    
    
    assign(socket, scraped_cases: final_scraped_cases)
  end
  
  defp determine_case_save_status(case_data, creation_results) do
    case creation_results do
      %{created: created_list} when is_list(created_list) ->
        if Enum.any?(created_list, fn created -> created.regulator_id == case_data.regulator_id end) do
          :created
        else
          check_other_statuses(case_data, creation_results)
        end
      
      %{updated: updated_list} when is_list(updated_list) ->
        if Enum.any?(updated_list, fn updated -> updated.regulator_id == case_data.regulator_id end) do
          :updated
        else
          check_other_statuses(case_data, creation_results)
        end
      
      _ ->
        check_other_statuses(case_data, creation_results)
    end
  end
  
  defp check_other_statuses(case_data, creation_results) do
    cond do
      # Check if case was in existing/duplicate list
      Map.get(creation_results, :existing_count, 0) > 0 ->
        :existing
      
      # Check if there were errors for this case
      case Map.get(creation_results, :errors, []) do
        errors when is_list(errors) ->
          has_error = Enum.any?(errors, fn
            {regulator_id, _error} -> regulator_id == case_data.regulator_id
            _ -> false
          end)
          if has_error, do: :error, else: :unknown
        
        _ -> :unknown
      end
    end
  end

  defp case_status_badge(case) do
    # Determine status based on data completeness and processing state
    {status_text, status_class} = cond do
      # Check if this case was just created (very recent)
      case.inserted_at && DateTime.diff(DateTime.utc_now(), case.inserted_at, :second) < 60 ->
        {"Created", "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"}
      
      # Check if case has minimal data (likely existing/duplicate)
      is_nil(case.offence_result) and is_nil(case.offence_fine) ->
        {"Exists", "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800"}
      
      # Case has conviction result
      case.offence_result == "Convicted" ->
        {"Convicted", "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800"}
      
      # Case has fine
      case.offence_result == "Fined" or (case.offence_fine && Decimal.positive?(case.offence_fine)) ->
        {"Fined", "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800"}
      
      # Default complete status
      true ->
        {"Complete", "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"}
    end
    
    {status_text, status_class}
  end
  
  defp processing_status_badge(processing_status) do
    # Show processing status (before database operations)
    {status_text, status_class} = case processing_status do
      :scraping ->
        {"Scraping", "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800"}
      
      :scraped ->
        {"Scraped", "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800"}
      
      :ready_for_db ->
        {"Ready for DB", "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800"}
      
      :error ->
        {"Error", "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800"}
      
      _ ->
        {"Processing", "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"}
    end
    
    {status_text, status_class}
  end

  defp database_status_badge(database_status) do
    # Show database save status (after database operations)
    case database_status do
      :created ->
        {"Created", "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"}
      
      :updated ->
        {"Updated", "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800"}
      
      :exists ->
        {"Exists", "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"}
      
      :error ->
        {"Error", "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800"}
      
      nil ->
        {"Pending", "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-50 text-gray-500"}
      
      _ ->
        {"Unknown", "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-600"}
    end
  end
  
  defp scraped_case_status_badge(scraped_case) do
    # Legacy function for backward compatibility - use database status if available
    case Map.get(scraped_case, :database_status) do
      nil ->
        # Old format - use save_status
        legacy_status = Map.get(scraped_case, :save_status, :processing)
        database_status_badge(legacy_status)
      
      status ->
        # New format - use database_status
        database_status_badge(status)
    end
  end

  # Pure Ash scraping function - updates ScrapeSession for progress tracking
  defp scrape_cases_with_session(session, opts) do
    alias EhsEnforcement.Scraping.Hse.CaseScraper
    alias EhsEnforcement.Scraping.Hse.CaseProcessor
    
    start_page = opts.start_page
    max_pages = opts.max_pages
    database = opts.database
    actor = opts.actor
    
    results = %{created_count: 0, error_count: 0, existing_count: 0}
    
    try do
      # Process each page (with early stopping)
      final_results = Enum.reduce_while(start_page..(start_page + max_pages - 1), results, fn page, acc ->
        Logger.info("Scraping page #{page}")
        
        # Update session with current page and reset page counters (Ash PubSub will notify UI)
        session
        |> Ash.Changeset.for_update(:update, %{
          current_page: page,
          pages_processed: page - start_page,  # Pages completed so far (0 when starting page 1)
          cases_exist_current_page: 0  # Reset page counter
        })
        |> Ash.update!(actor: actor)
        
        case CaseScraper.scrape_page_basic(page, database: database) do
          {:ok, basic_cases} ->
            Logger.info("Found #{length(basic_cases)} cases on page #{page}")
            
            # Process each case individually with real-time session updates
            {page_results, page_existing_count} = Enum.reduce(basic_cases, {acc, 0}, fn basic_case, {case_acc, page_existing} ->
              if basic_case.regulator_id && basic_case.regulator_id != "" do
                # Process the case
                prev_existing = case_acc.existing_count
                updated_acc = process_single_case_simple(basic_case, database, actor, case_acc)
                
                # Calculate if this case was an existing (duplicate)
                case_was_existing = updated_acc.existing_count > prev_existing
                new_page_existing = if case_was_existing, do: page_existing + 1, else: page_existing
                
                # Update session immediately after each case
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
                {case_acc, page_existing}
              end
            end)
            
            # Update session with completed page count (increment pages_processed)
            session
            |> Ash.Changeset.for_update(:update, %{
              pages_processed: page - start_page + 1  # Now increment since page is complete
            })
            |> Ash.update!(actor: actor)
            
            # Check stop rule: if all cases on current page exist, stop scraping
            if page_existing_count > 0 && page_existing_count == length(basic_cases) do
              Logger.info("Stopping scraping: all #{page_existing_count} cases on page #{page} already exist")
              {:halt, page_results}  # Stop processing more pages
            else
              {:cont, page_results}  # Continue to next page
            end
            
          {:error, reason} ->
            Logger.error("Failed to scrape page #{page}: #{inspect(reason)}")
            updated_acc = %{acc | error_count: acc.error_count + 1}
            
            # Update session with error and increment pages_processed since page is complete (even if failed)
            session
            |> Ash.Changeset.for_update(:update, %{
              errors_count: updated_acc.error_count,
              pages_processed: page - start_page + 1  # Increment since page is complete (failed)
            })
            |> Ash.update!(actor: actor)
            
            {:cont, updated_acc}  # Continue to next page despite error
        end
      end)
      
      # Mark session as completed
      session
      |> Ash.Changeset.for_update(:update, %{status: :completed})
      |> Ash.update!(actor: actor)
      
      {:ok, final_results}
    rescue
      error ->
        Logger.error("Scraping failed with error: #{inspect(error)}")
        
        # Mark session as failed
        session
        |> Ash.Changeset.for_update(:update, %{status: :failed})
        |> Ash.update!(actor: actor)
        
        {:error, error}
    end
  end
  
  defp process_single_case_simple(basic_case, database, actor, results) do
    # Get case details (legacy pattern)
    enriched_case = case EhsEnforcement.Scraping.Hse.CaseScraper.scrape_case_details(basic_case.regulator_id, database) do
      {:ok, details} -> Map.merge(basic_case, details)
      {:error, _} -> basic_case  # Use basic case if details fail
    end
    
    # Create Case directly (no tracking tables)
    case EhsEnforcement.Scraping.Hse.CaseProcessor.process_and_create_case(enriched_case, actor) do
      {:ok, case_record} ->
        Logger.info("✅ Created case: #{case_record.regulator_id}")
        %{results | created_count: results.created_count + 1}
        
      {:error, %Ash.Error.Invalid{errors: errors}} ->
        if duplicate_error?(errors) do
          Logger.info("⏭️ Case already exists: #{enriched_case.regulator_id}")
          
          # Update existing case to trigger PubSub and make it appear in UI
          case EhsEnforcement.Enforcement.Case
               |> Ash.Query.filter(regulator_id == ^enriched_case.regulator_id)
               |> Ash.read_one(actor: actor) do
            {:ok, existing_case} when not is_nil(existing_case) ->
              case Ash.update(existing_case, %{}, action: :update_from_scraping, actor: actor) do
                {:ok, _updated_case} ->
                  Logger.info("✅ Updated existing case via :update_from_scraping action (scraping workflow): #{enriched_case.regulator_id}")
                {:error, error} ->
                  Logger.warning("Failed to update existing case: #{inspect(error)}")
              end
            _ ->
              Logger.warning("Could not find existing case to update: #{enriched_case.regulator_id}")
          end
          
          %{results | existing_count: results.existing_count + 1}
        else
          Logger.warning("❌ Error creating case #{enriched_case.regulator_id}: #{inspect(errors)}")
          %{results | error_count: results.error_count + 1}
        end
        
      {:error, reason} ->
        Logger.warning("❌ Error processing case #{enriched_case.regulator_id}: #{inspect(reason)}")
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

  # Private helper to handle ScrapeSession updates from either format
  defp handle_scrape_session_update(session_data, socket) do
    
    # Update progress display with latest session data
    updated_progress = %{
      status: session_data.status,
      current_page: session_data.current_page,
      pages_processed: session_data.pages_processed,
      cases_found: session_data.cases_found,
      cases_created: session_data.cases_created,
      cases_exist_total: session_data.cases_exist_total,
      errors_count: session_data.errors_count,
      cases_exist_current_page: session_data.cases_exist_current_page || 0,  # Page-level existing count
      max_pages: session_data.max_pages  # Add for percentage calculation
    }
    
    socket = assign(socket, 
      progress: updated_progress,
      last_update: System.monotonic_time(:millisecond)
    )
    
    # Also trigger keep_live refresh for active_sessions
    {:noreply, AshPhoenix.LiveView.handle_live(socket, "scrape_session:updated", [:active_sessions])}
  end
end