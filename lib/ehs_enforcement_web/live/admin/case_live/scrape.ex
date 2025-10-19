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
  
  alias EhsEnforcement.Scraping.ScrapeCoordinator
  alias EhsEnforcement.Scraping.ScrapeRequest
  alias EhsEnforcement.Scraping.ScrapeSession
  alias EhsEnforcement.Scraping.ProcessingLog
  alias EhsEnforcementWeb.Components.ProgressComponent
  alias AshPhoenix.Form
  alias Phoenix.PubSub
  
  @pubsub_topic "scraping_progress"
  
  # LiveView Callbacks
  
  @impl true
  def mount(_params, _session, socket) do
    # Check if manual scraping is enabled via feature flag
    manual_scraping_enabled = ScrapeCoordinator.scraping_enabled?(type: :manual, actor: socket.assigns[:current_user])
    
    # Ash PubSub handles scraping progress updates automatically via keep_live
    
    # Create AshPhoenix.Form for scraping parameters with defaults
    form = Form.for_create(ScrapeRequest, :create, as: "scrape_request", forms: [auto?: false]) 
    |> Form.validate(%{
      "agency" => "hse",
      "database" => "convictions",
      "date_from" => Date.add(Date.utc_today(), -30) |> Date.to_string(),
      "date_to" => Date.utc_today() |> Date.to_string()
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
      
      # Progress tracking
      progress: %{
        pages_processed: 0,
        cases_found: 0,
        cases_processed: 0,
        cases_created: 0,
        cases_created_current_page: 0,
        cases_updated: 0,
        cases_updated_current_page: 0,
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
      # Initialize empty values - will be populated by event-driven updates
      active_sessions: [],
      case_processing_log: [],
      scraped_cases: [],  # All scraped cases (both HSE and EA) - unified list
      
      # UI state
      loading: false,
      last_update: System.monotonic_time(:millisecond)
    )
    
    # Load recent cases data using proper AshPhoenix.LiveView reactive patterns
    if connected?(socket) do
      
      # Note: Removed manual subscription - using keep_live subscriptions only
      
      # Use pure Ash patterns for reactivity
      
      # Use AshPhoenix.LiveView.keep_live for reactive case updates (reduced frequency)
      socket = AshPhoenix.LiveView.keep_live(socket, :recent_cases, fn socket ->
        EhsEnforcement.Enforcement.Case
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.limit(50)  # Reduced from 100 to 50
        |> Ash.Query.load([:agency, :offender])
        |> Ash.read!(actor: socket.assigns.current_user)
      end,
        subscribe: ["case:created", "case:updated", "case:bulk_created"],
        results: :keep,
        load_until_connected?: false,  # Prevent eager loading
        refetch_window: :timer.seconds(30)  # Increased from 5s to 30s
      )
      
      # Use event-driven updates for scraping sessions instead of polling
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "scrape_session:created")
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "scrape_session:updated")
      
      # Use event-driven updates for case processing logs instead of polling  
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "processing_log:created")
      
      # Manual PubSub subscription for scraped cases - use direct state management
      # instead of keep_live to avoid timing issues with session-specific data
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case:scraped:updated")
      
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
          # Route to appropriate scraper based on agency
          case scrape_request.agency do
            :hse -> 
              start_hse_scraping(socket, scrape_request)
            :ea ->
              start_ea_scraping(socket, scrape_request)
            _ ->
              socket = put_flash(socket, :error, "Unknown agency selected")
              {:noreply, socket}
          end
        
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
        # HSE scraping with session
        Logger.info("Admin requested to stop HSE scraping session: #{session_id}")
        
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
      
      {nil, task} when not is_nil(task) ->
        # EA scraping without session
        Logger.info("Admin requested to stop EA scraping task")
        
        Task.shutdown(task, :brutal_kill)
        
        # No session to broadcast about, just update UI
        socket = assign(socket,
          scraping_active: false,
          current_session: nil,
          scraping_task: nil,
          scraping_session_started_at: nil,
          progress: Map.put(socket.assigns.progress, :status, :stopped)
        )
        
        {:noreply, socket}
      
      {nil, nil} ->
        # No scraping running
        {:noreply, socket}
        
      {_, nil} ->
        # Session exists but no task (shouldn't happen, but handle gracefully)
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
  def handle_event("clear_scraped_cases", _params, socket) do
    # Clear scraped cases list and session start time
    socket = assign(socket, 
      scraped_cases: [],
      scraping_session_started_at: nil
    )
    {:noreply, socket}
  end
  
  
  @impl true
  def handle_event("clear_processing_log", _params, socket) do
    # Clear unified processing logs via Ash (use bulk destroy)
    case Ash.bulk_destroy(ProcessingLog, :destroy, %{}) do
      %Ash.BulkResult{} -> Logger.info("Cleared all processing logs")
      {:error, reason} -> Logger.warning("Failed to clear processing logs: #{inspect(reason)}")
    end
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_progress", _params, socket) do
    # Reset progress counters to clear the display
    cleared_progress = %{
      pages_processed: 0,
      cases_found: 0,
      cases_processed: 0,
      cases_created: 0,
      cases_created_current_page: 0,
      cases_updated: 0,
      cases_updated_current_page: 0,
      cases_exist_total: 0,
      cases_exist_current_page: 0,
      errors_count: 0,
      current_page: nil,
      status: :idle
    }
    
    socket = assign(socket, progress: cleared_progress)
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
      current_page: Map.get(data, :current_page, 1),
      pages_processed: Map.get(data, :pages_processed, 0),
      cases_found: Map.get(data, :cases_scraped, 0),
      cases_created: Map.get(data, :cases_created, 0),
      cases_exist_total: Map.get(data, :cases_exist_total, 0),
      cases_exist_current_page: Map.get(data, :cases_exist_current_page, 0),
      errors_count: Map.get(data, :errors, Map.get(data, :cases_skipped, 0))
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
      current_page: Map.get(data, :current_page, 1),
      pages_processed: Map.get(data, :pages_processed, 0),
      cases_found: Map.get(data, :cases_scraped, 0),
      cases_created: Map.get(data, :cases_created, 0),
      cases_exist_total: Map.get(data, :cases_exist_total, 0),
      cases_exist_current_page: 0,  # Reset counter for new page
      errors_count: Map.get(data, :errors, Map.get(data, :cases_skipped, 0)),
      status: :running  # Use :running for consistent progress calculation
    })
    
    {:noreply, socket}
  end

  @impl true
  def handle_info({:page_completed, data}, socket) do
    
    # Extract case details for display
    case_details = build_case_details(data)
    
    # Get current form values to include in progress for percentage calculation
    form_params = socket.assigns.form.params || %{}
    form_start_page = Map.get(form_params, "start_page", "1") |> String.to_integer()
    form_end_page = Map.get(form_params, "end_page", "10") |> String.to_integer()
    
    progress_updates = %{
      pages_processed: Map.get(data, :pages_processed, 0),
      cases_found: Map.get(data, :cases_scraped, 0),
      cases_created: Map.get(data, :cases_created, 0),
      cases_exist_total: Map.get(data, :cases_exist_total, 0),
      cases_exist_current_page: Map.get(data, :cases_exist_current_page, 0),
      errors_count: Map.get(data, :errors, Map.get(data, :cases_skipped, 0)),
      current_page: Map.get(data, :current_page, 1),
      start_page: form_start_page,  # Include for percentage calculation
      end_page: form_end_page,      # Include for percentage calculation
      status: :running  # Use :running so progress_percentage calculates correctly
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
    # Just trigger manual refresh for active sessions
    sessions = ScrapeSession
    |> Ash.Query.for_read(:active)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(actor: socket.assigns.current_user)
    
    {:noreply, assign(socket, active_sessions: sessions)}
  end
  
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "scrape_session:created", event: "create", payload: %Ash.Notifier.Notification{} = _notification}, socket) do
    # Just trigger manual refresh for active sessions
    sessions = ScrapeSession
    |> Ash.Query.for_read(:active)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(actor: socket.assigns.current_user)
    
    {:noreply, assign(socket, active_sessions: sessions)}
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
          
          # Get actual processing status from notification metadata or fall back to :updated
          processing_status = case notification.metadata[:processing_status] do
            status when status in [:created, :updated, :existing] -> status
            _ -> :updated  # Default for scraped:updated events without metadata
          end
          
          # Add processing status to case for template use
          case_with_status = Map.put(case, :processing_status, processing_status)
          
          # Remove any existing entry for this case (deduplicate by regulator_id)
          existing_cases = Enum.reject(socket.assigns.scraped_cases, fn existing -> 
            existing.regulator_id == case.regulator_id 
          end)
          
          # Add to the beginning of the list (most recent first)
          updated_scraped_cases = [case_with_status | existing_cases]
          
          # Keep only the most recent 100 cases (increased to handle large EA batches)
          updated_scraped_cases = Enum.take(updated_scraped_cases, 100)
          
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
    
    # Only add cases if we have an active session
    socket = if socket.assigns.scraping_session_started_at do
      # Load full case data with associations
      case = EhsEnforcement.Enforcement.Case
      |> Ash.get!(notification.data.id, load: [:agency, :offender], actor: socket.assigns.current_user)
      
      # Add processing status - for case:created events, it's always :created
      case_with_status = Map.put(case, :processing_status, :created)
      
      # All cases (HSE and EA) go to the same unified scraped_cases list
      existing_cases = Enum.reject(socket.assigns.scraped_cases, fn existing -> 
        existing.regulator_id == case.regulator_id 
      end)
      updated_scraped_cases = [case_with_status | existing_cases]
      updated_scraped_cases = Enum.take(updated_scraped_cases, 100)
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

  # PubSub handlers for optimized event-driven updates
  
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "scrape_session:created"}, socket) do
    # Load active sessions when a new session is created
    sessions = ScrapeSession
    |> Ash.Query.for_read(:active)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(actor: socket.assigns.current_user)
    
    {:noreply, assign(socket, active_sessions: sessions)}
  end
  
  @impl true  
  def handle_info(%Phoenix.Socket.Broadcast{topic: "scrape_session:updated", payload: %Ash.Notifier.Notification{data: session_data}}, socket) do
    Logger.debug("UI: Received session update - scraping_active: #{socket.assigns.scraping_active}, session_id: #{session_data.session_id}")
    Logger.debug("UI: Session update data - status: #{session_data.status}, cases_found: #{session_data.cases_found}, cases_created: #{session_data.cases_created}, cases_exist_total: #{session_data.cases_exist_total}")
    
    # Update progress ONLY when actively scraping
    # Do NOT update progress after completion to preserve final results
    socket = if socket.assigns.scraping_active do
      # If scraping is active, update the progress with session data
      progress = extract_progress_from_session(session_data)
      Logger.debug("UI: Updating progress during scraping - cases_found: #{progress.cases_found}, cases_created: #{progress.cases_created}, cases_exist_total: #{progress.cases_exist_total}")
      assign(socket, progress: progress, current_session: session_data)
    else
      # If not actively scraping, DO NOT update progress - preserve completion results
      Logger.debug("UI: Ignoring session update after completion to preserve progress")
      socket
    end
    
    socket = update(socket, :active_sessions, fn sessions ->
      # Update the session in the list
      Enum.map(sessions, fn s -> 
        if s.id == session_data.id, do: session_data, else: s 
      end)
    end)
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "processing_log:created", payload: %Ash.Notifier.Notification{data: log_data}}, socket) do
    # Add new processing log entry (supports both HSE and EA)
    socket = update(socket, :case_processing_log, fn logs ->
      [log_data | logs] |> Enum.take(50)  # Keep latest 50 entries
    end)
    
    {:noreply, socket}
  end

  # Task completion handlers
  
  @impl true
  def handle_info({:scraping_completed, session_result}, socket) do
    Logger.info("UI: Scraping task completed successfully - session_result: #{inspect(session_result)}")
    
    # Preserve current progress and only update status to completed
    # Don't reset progress counters - user should see final results
    final_progress = socket.assigns.progress
    |> Map.put(:status, :completed)
    
    # If session result has higher counts, use those instead
    final_progress = if session_result do
      Logger.info("UI: Merging session results with current progress")
      session_progress = extract_progress_from_session(session_result)
      
      # Take the maximum of current progress and session results to avoid reset
      %{
        status: :completed,
        pages_processed: max(final_progress.pages_processed || 0, session_progress.pages_processed || 0),
        cases_found: max(final_progress.cases_found || 0, session_progress.cases_found || 0),
        cases_processed: max(final_progress.cases_processed || 0, session_progress.cases_processed || 0),
        cases_created: max(final_progress.cases_created || 0, session_progress.cases_created || 0),
        cases_created_current_page: final_progress.cases_created_current_page || 0,
        cases_updated: max(final_progress.cases_updated || 0, session_progress.cases_updated || 0),
        cases_updated_current_page: final_progress.cases_updated_current_page || 0,
        cases_exist_total: max(final_progress.cases_exist_total || 0, session_progress.cases_exist_total || 0),
        cases_exist_current_page: final_progress.cases_exist_current_page || 0,
        errors_count: max(final_progress.errors_count || 0, session_progress.errors_count || 0),
        current_page: session_progress.current_page || final_progress.current_page
      }
    else
      Logger.info("UI: No session result, preserving current progress")
      final_progress
    end
    
    Logger.info("UI: Final progress: #{inspect(final_progress)}")
    
    socket = assign(socket,
      scraping_active: false,
      current_session: session_result,  # Store completed session for reference
      scraping_task: nil,
      # Don't clear scraping_session_started_at here - keep showing results after completion
      progress: final_progress
      # Keep scraped_cases after completion so user can see results
    )
    
    Logger.info("UI: Scraping completion handled - scraping_active: #{socket.assigns.scraping_active}, final_progress: #{inspect(final_progress)}")

    # Trigger metrics refresh in background after scraping completes
    Task.start(fn ->
      Logger.info("Triggering metrics refresh after case scraping completion")
      EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:automation)

      # Broadcast to all dashboards that metrics are refreshed
      Phoenix.PubSub.broadcast(
        EhsEnforcement.PubSub,
        "metrics:refreshed",
        %Phoenix.Socket.Broadcast{
          topic: "metrics:refreshed",
          event: "refresh",
          payload: %{triggered_by: :scraping_cases}
        }
      )
    end)

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
  
  
  # load_recent_data/1 function removed - now handled by keep_live/4 automatically
  
  
  defp extract_progress_from_session(session_data) do
    %{
      pages_processed: session_data.pages_processed || 0,
      cases_found: session_data.cases_found || 0,
      cases_processed: Map.get(session_data, :cases_processed, 0),
      cases_created: session_data.cases_created || 0,
      cases_created_current_page: session_data.cases_created_current_page || 0,
      cases_updated: session_data.cases_updated || 0,
      cases_updated_current_page: session_data.cases_updated_current_page || 0,
      cases_exist_total: session_data.cases_exist_total || 0,
      cases_exist_current_page: session_data.cases_exist_current_page || 0,
      errors_count: session_data.errors_count || 0,
      current_page: session_data.current_page,
      status: session_data.status || :idle
    }
  end

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
        pages_processed: Map.get(data, :pages_processed, Map.get(data, :result, %{}) |> Map.get(:pages_processed, 0)),
        cases_found: Map.get(data, :cases_scraped, Map.get(data, :result, %{}) |> Map.get(:cases_created, 0)),
        cases_created: Map.get(data, :cases_created, Map.get(data, :result, %{}) |> Map.get(:cases_created, 0)),
        cases_exist_total: Map.get(data, :cases_exist_total, 0),
        errors_count: Map.get(data, :errors, Map.get(data, :result, %{}) |> Map.get(:errors, []) |> length())
      }),
      session_results: [%{
        session_id: Map.get(data, :session_id, "unknown"),
        completed_at: DateTime.utc_now(),
        pages_processed: Map.get(data, :pages_processed, Map.get(data, :result, %{}) |> Map.get(:pages_processed, 0)),
        cases_created: Map.get(data, :cases_created, Map.get(data, :result, %{}) |> Map.get(:cases_created, 0)),
        errors_count: Map.get(data, :errors, Map.get(data, :result, %{}) |> Map.get(:errors, []) |> length())
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
  
  # Handle sync call for test synchronization
  @impl true
  def handle_call(:sync, _from, socket) do
    {:reply, :ok, socket}
  end
  
  defp broadcast_scraping_event(event_type, data) do
    PubSub.broadcast(EhsEnforcement.PubSub, @pubsub_topic, {:scraping_event, event_type, data})
  end
  
  # defp broadcast_progress(event_type, data) do
  #   PubSub.broadcast(EhsEnforcement.PubSub, @pubsub_topic, {:scraping_progress, event_type, data})
  # end
  # Removed: function not used in this module
  
  
  defp should_enable_real_time_progress?(actor) do
    config = ScrapeCoordinator.load_scraping_config(actor: actor)
    config.real_time_progress_enabled
  end
  
  # Progress percentage calculation moved to ProgressComponent module

  # Progress helper functions moved to ProgressComponent module
  
  defp build_case_details(data) do
    %{
      agency: Map.get(data, :agency, :hse),  # Default to HSE for backward compatibility
      batch_or_page: data.current_page,  # Unified field name for template
      page: data.current_page,  # Keep for backward compatibility
      timestamp: DateTime.utc_now(),
      
      # Unified field names for new template
      items_found: length(data[:scraped_cases] || []),
      items_created: Map.get(data, :cases_created, 0),
      items_existing: Map.get(data, :existing_count, 0),
      items_failed: Map.get(data, :cases_skipped, 0),
      
      # Legacy field names for backward compatibility
      cases_scraped: length(data[:scraped_cases] || []),
      cases_created: Map.get(data, :cases_created, 0),
      cases_skipped: Map.get(data, :cases_skipped, 0),
      existing_count: Map.get(data, :existing_count, 0),
      
      scraped_items: extract_case_summary(data[:scraped_cases] || []),  # Unified field name
      scraped_cases: extract_case_summary(data[:scraped_cases] || []),  # Legacy field name
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
  
  
  # Agency-specific scraping helper functions
  
  defp start_hse_scraping(socket, scrape_request) do
    # Extract validated parameters from the created resource
    validated_params = %{
      start_page: scrape_request.start_page,
      end_page: scrape_request.end_page,
      database: scrape_request.database
    }
    
    # Calculate number of pages to scrape: (end_page - start_page) + 1
    pages_to_scrape = (validated_params.end_page - validated_params.start_page) + 1
    
    # Simplified scraping - just create Cases directly (no tracking tables needed)
    scraping_opts = %{
      start_page: validated_params.start_page,
      max_pages: pages_to_scrape,  # Calculated number of pages
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
    Logger.info("Starting HSE case scraping: pages #{scraping_opts.start_page}-#{scraping_opts.start_page + scraping_opts.max_pages - 1}")
    
    # Create ScrapeSession using Ash (pure Ash approach)
    session = EhsEnforcement.Scraping.ScrapeSession
    |> Ash.Changeset.for_create(:create, %{
      session_id: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower),
      start_page: validated_params.start_page,
      max_pages: pages_to_scrape,
      database: "convictions",
      status: :running,
      current_page: validated_params.start_page
    })
    |> Ash.create!(actor: socket.assigns.current_user)
    
    task = Task.async(fn ->
      case scrape_cases_with_session(session, scraping_opts) do
        {:ok, results} ->
          Logger.info("HSE Scraping completed: #{results.created_count} cases created")
          
        {:error, reason} ->
          Logger.error("HSE Scraping failed: #{inspect(reason)}")
      end
    end)
    
    # Final socket update with session and task info
    socket = assign(socket,
      current_session: session,
      scraping_task: task
    )
    
    {:noreply, socket}
  end
  
  defp start_ea_scraping(socket, scrape_request) do
    # Extract validated EA parameters - only court cases for now
    ea_params = %{
      date_from: scrape_request.date_from,
      date_to: scrape_request.date_to,
      action_types: [:court_case]  # Only court cases - cautions need schema review
    }
    
    # Set session start time
    session_start_time = DateTime.add(DateTime.utc_now(), -5, :second)
    
    # Update socket for EA scraping (no pagination)
    socket = assign(socket,
      scraping_active: true,
      scraping_session_started_at: session_start_time,
      scraped_cases: [],  # Clear any existing cases
      progress: Map.merge(socket.assigns.progress, %{
        status: :running,
        current_page: nil  # EA doesn't use pagination
      })
    )
    
    Logger.info("Starting EA case scraping: #{ea_params.date_from} to #{ea_params.date_to}, action_types: #{inspect(ea_params.action_types)}")
    
    # Capture parent PID to send completion message
    parent_pid = self()
    
    task = Task.async(fn ->
      # Use the EA scraping behavior - pass parameters as keyword list
      case EhsEnforcement.Scraping.Agencies.Ea.validate_params([
          date_from: ea_params.date_from,
          date_to: ea_params.date_to,
          action_types: ea_params.action_types,
          actor: socket.assigns.current_user,
          scrape_type: :manual,
          start_page: 1,
          max_pages: 1
        ]) do
        {:ok, validated_params} ->
          # Now start the actual scraping with validated parameters
          EhsEnforcement.Scraping.Agencies.Ea.start_scraping(validated_params, nil)
          
        {:error, reason} ->
          Logger.error("EA parameter validation failed: #{inspect(reason)}")
          {:error, reason}
      end |> case do
        {:ok, session_result} ->
          Logger.info("EA scraping completed successfully")
          # Send completion message to LiveView with session data
          send(parent_pid, {:scraping_completed, session_result})
          session_result
          
        {:error, reason} ->
          Logger.error("EA scraping failed: #{inspect(reason)}")
          # Send failure message to LiveView
          send(parent_pid, {:scraping_failed, reason})
          {:error, reason}
      end
    end)
    
    # For EA, store the task (session will be created by EA scraping behavior)
    socket = assign(socket, scraping_task: task)
    
    {:noreply, socket}
  end

  # Pure Ash scraping function - updates ScrapeSession for progress tracking (HSE only)
  defp scrape_cases_with_session(session, opts) do
    alias EhsEnforcement.Scraping.Hse.CaseScraper
    
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

  # Helper functions for template to handle mixed atom/string keys in scraped_items

  defp get_case_field(case_info, field) when is_map(case_info) do
    # Try atom key first, then string key
    case_info[field] || case_info[to_string(field)]
  end

  defp get_case_field(_, _), do: nil

  defp parse_case_date(nil), do: nil
  defp parse_case_date(%Date{} = date), do: date
  defp parse_case_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end
  defp parse_case_date(_), do: nil

  defp parse_fine_amount(nil), do: nil
  defp parse_fine_amount(%Decimal{} = amount), do: amount
  defp parse_fine_amount(amount_string) when is_binary(amount_string) do
    case Decimal.parse(amount_string) do
      {amount, _} -> amount
      :error -> nil
    end
  end
  defp parse_fine_amount(_), do: nil

  # Private helper to handle ScrapeSession updates from either format
  defp handle_scrape_session_update(session_data, socket) do
    
    # Update progress display with latest session data
    updated_progress = %{
      status: session_data.status,
      current_page: session_data.current_page,
      pages_processed: session_data.pages_processed,
      cases_found: session_data.cases_found,
      cases_processed: Map.get(session_data, :cases_processed, 0),
      cases_created: session_data.cases_created,
      cases_created_current_page: session_data.cases_created_current_page || 0,
      cases_updated: session_data.cases_updated || 0,
      cases_updated_current_page: session_data.cases_updated_current_page || 0,
      cases_exist_total: session_data.cases_exist_total,
      errors_count: session_data.errors_count,
      cases_exist_current_page: session_data.cases_exist_current_page || 0,  # Page-level existing count
      max_pages: session_data.max_pages  # Add for percentage calculation
    }
    
    socket = assign(socket, 
      progress: updated_progress,
      last_update: System.monotonic_time(:millisecond)
    )
    
    # Also refresh active_sessions manually
    sessions = ScrapeSession
    |> Ash.Query.for_read(:active)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(actor: socket.assigns.current_user)
    
    socket = assign(socket, active_sessions: sessions)
    {:noreply, socket}
  end

  # Progress Components moved to ProgressComponent module

  # Old HSE and EA progress components have been replaced by unified component
  # See: EhsEnforcementWeb.Components.ProgressComponent.unified_progress_component/1
end
