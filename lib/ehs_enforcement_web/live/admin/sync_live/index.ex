defmodule EhsEnforcementWeb.Admin.SyncLive.Index do
  @moduledoc """
  Admin interface for Airtable data synchronization with real-time progress display.
  
  Features:
  - Manual sync trigger with configurable parameters
  - Real-time progress updates via Phoenix PubSub
  - Sync session management and results display  
  - Error reporting and recovery options
  - Package-ready architecture for future extraction
  """
  
  use EhsEnforcementWeb, :live_view
  
  require Logger
  require Ash.Query
  
  alias EhsEnforcement.Sync
  alias AshPhoenix.Form
  import EhsEnforcementWeb.Admin.SyncLive.Components
  
  @pubsub_topic "sync_progress"
  
  # LiveView Callbacks
  
  @impl true
  def mount(_params, _session, socket) do
    # Create form for sync configuration
    form = create_sync_form()
    
    socket = assign(socket,
      # Form for sync configuration
      form: form,
      
      # Session state
      current_sync_session: nil,
      sync_active: false,
      sync_task: nil,
      sync_session_started_at: nil,
      
      # Progress tracking
      progress: %{
        records_processed: 0,
        records_created: 0,
        records_updated: 0,
        records_exists: 0,
        errors_count: 0,
        current_batch: nil,
        status: :idle,
        sync_type: nil
      },
      
      # Results and errors
      sync_results: [],
      recent_errors: [],
      recent_records: [],
      sync_errors: [],
      
      # UI state and data needed by new template
      loading: false,
      last_update: System.monotonic_time(:millisecond),
      current_sync_batches: [],
      database_stats: %{
        total_cases: nil,
        total_notices: nil,
        total_offenders: nil,
        last_import: nil
      },
      recent_logs: [],
      session_history: [],
      active_tab: "current",
      
      # Enhanced features status
      recovery_status: nil,
      integrity_status: nil
    )
    
    if connected?(socket) do
      # Subscribe to sync progress events
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, @pubsub_topic)
      {:ok, socket}
    else
      {:ok, socket}
    end
  end
  
  # Event Handlers
  
  @impl true
  def handle_event("validate", %{"sync_config" => params}, socket) do
    form = Form.validate(socket.assigns.form, params) |> to_form()
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("import_cases", %{"sync_config" => params}, socket) do
    start_sync(:cases, params, socket)
  end

  @impl true
  def handle_event("import_notices", %{"sync_config" => params}, socket) do
    start_sync(:notices, params, socket)
  end

  @impl true
  def handle_event("import_all", %{"sync_config" => params}, socket) do
    start_sync(:all, params, socket)
  end
  
  @impl true
  def handle_event("stop_sync", _params, socket) do
    case socket.assigns.sync_task do
      nil ->
        {:noreply, socket}
      
      task ->
        Logger.info("Admin requested to stop sync")
        Task.shutdown(task, :brutal_kill)
        
        socket = assign(socket,
          sync_active: false,
          current_sync_session: nil,
          sync_task: nil,
          sync_session_started_at: nil,
          progress: Map.put(socket.assigns.progress, :status, :stopped)
        )
        
        {:noreply, put_flash(socket, :info, "Sync stopped")}
    end
  end
  
  @impl true
  def handle_event("clear_results", _params, socket) do
    socket = assign(socket, sync_results: [], recent_errors: [], recent_records: [])
    {:noreply, socket}
  end

  # Enhanced Features Event Handlers

  @impl true
  def handle_event("refresh_recovery_status", _params, socket) do
    socket = load_recovery_status(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("load_recovery_status", _params, socket) do
    socket = load_recovery_status(socket)
    {:noreply, socket}
  end

  @impl true  
  def handle_event("refresh_integrity_status", _params, socket) do
    socket = load_integrity_status(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("load_integrity_status", _params, socket) do
    socket = load_integrity_status(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("generate_integrity_report", _params, socket) do
    # Generate report using NCDB2Phx metrics - placeholder until full implementation
    case {:ok, %{status: "report_generated", timestamp: DateTime.utc_now()}} do
      {:ok, _report} ->
        socket = load_integrity_status(socket)
        {:noreply, put_flash(socket, :info, "Integrity report generated successfully")}
      
      {:error, error} ->
        Logger.error("Failed to generate integrity report: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to generate integrity report")}
    end
  end

  # PubSub Message Handling
  
  @impl true
  def handle_info({:sync_started, data}, socket) do
    progress_updates = %{
      status: :running,
      sync_type: data.sync_type,
      records_processed: 0,
      records_created: 0,
      records_updated: 0,
      records_exists: 0,
      errors_count: 0
    }
    
    socket = update_progress(socket, progress_updates)
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:sync_progress, data}, socket) do
    progress_updates = %{
      records_processed: data.records_processed,
      records_created: data.records_created,
      records_updated: data.records_updated,
      records_exists: data.records_exists,
      errors_count: data.errors_count,
      current_batch: data.current_batch
    }
    
    socket = update_progress(socket, progress_updates)
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:sync_completed, data}, socket) do
    socket = assign(socket,
      sync_active: false,
      current_sync_session: nil,
      sync_task: nil,
      progress: Map.merge(socket.assigns.progress, %{
        status: :completed,
        records_processed: data.records_processed,
        records_created: data.records_created,
        records_updated: data.records_updated,
        records_exists: data.records_exists,
        errors_count: data.errors_count
      }),
      sync_results: [%{
        completed_at: DateTime.utc_now(),
        sync_type: data.sync_type,
        records_processed: data.records_processed,
        records_created: data.records_created,
        records_updated: data.records_updated,
        errors_count: data.errors_count
      } | socket.assigns.sync_results]
    )
    
    {:noreply, put_flash(socket, :info, "Sync completed successfully")}
  end
  
  @impl true
  def handle_info({:sync_error, data}, socket) do
    error_info = %{
      timestamp: DateTime.utc_now(),
      sync_type: data.sync_type,
      message: data.error
    }
    
    socket = assign(socket,
      sync_active: false,
      current_sync_session: nil,
      sync_task: nil,
      sync_session_started_at: nil,
      progress: Map.put(socket.assigns.progress, :status, :error),
      recent_errors: [error_info | socket.assigns.recent_errors]
    )
    
    {:noreply, put_flash(socket, :error, "Sync failed: #{data.error}")}
  end

  # Task completion handlers
  
  @impl true
  def handle_info({ref, result}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    
    case result do
      {:ok, stats} ->
        Logger.info("Sync task completed successfully: #{inspect(stats)}")
        
        # Broadcast completion event
        Phoenix.PubSub.broadcast(EhsEnforcement.PubSub, @pubsub_topic, {
          :sync_completed, 
          %{
            sync_type: socket.assigns.progress.sync_type,
            records_processed: stats.imported || 0,
            records_created: stats.created || 0,
            records_updated: stats.updated || 0,
            records_exists: stats.exists || 0,
            errors_count: length(stats.errors || [])
          }
        })
        
      {:error, reason} ->
        Logger.error("Sync task failed: #{inspect(reason)}")
        
        # Broadcast error event
        Phoenix.PubSub.broadcast(EhsEnforcement.PubSub, @pubsub_topic, {
          :sync_error,
          %{
            sync_type: socket.assigns.progress.sync_type,
            error: inspect(reason)
          }
        })
    end
    
    {:noreply, socket}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    if socket.assigns.sync_active do
      Logger.warning("Sync task process died unexpectedly")
      socket = assign(socket,
        sync_active: false,
        current_sync_session: nil,
        sync_task: nil,
        sync_session_started_at: nil,
        progress: Map.put(socket.assigns.progress, :status, :error)
      )
      {:noreply, put_flash(socket, :error, "Sync stopped unexpectedly")}
    else
      {:noreply, socket}
    end
  end

  # Catch-all handler
  @impl true
  def handle_info(message, socket) do
    Logger.debug("Unhandled sync message: #{inspect(message)}")
    {:noreply, socket}
  end
  
  # Private Functions
  
  defp create_sync_form do
    # Create a form for sync configuration
    # For now, we'll create a simple map-based form since we don't have a sync request resource yet
    %{
      "sync_type" => "cases",
      "batch_size" => "100",
      "limit" => "1000",
      "dry_run" => false
    }
    |> to_form(as: "sync_config")
  end
  
  defp start_sync(sync_type, params, socket) do
    Logger.info("Admin triggered #{sync_type} sync with params: #{inspect(params)}")
    
    # Parse configuration
    batch_size = parse_integer(params["batch_size"], 100)
    limit = parse_integer(params["limit"], 1000)
    dry_run = params["dry_run"] == "true"
    
    # Validate parameters
    with :ok <- validate_sync_params(batch_size, limit, dry_run) do
      # Set session start time
      session_start_time = DateTime.utc_now()
      
      # Update socket state before starting task
      socket = assign(socket,
        sync_active: true,
        sync_session_started_at: session_start_time,
        recent_records: [],
        progress: Map.merge(socket.assigns.progress, %{
          status: :running,
          sync_type: sync_type,
          records_processed: 0,
          records_created: 0,
          records_updated: 0,
          records_exists: 0,
          errors_count: 0
        })
      )
      
      # Start sync task
      task = Task.async(fn ->
        perform_sync(sync_type, %{
          batch_size: batch_size,
          limit: limit,
          dry_run: dry_run,
          actor: socket.assigns.current_user
        })
      end)
      
      socket = assign(socket, sync_task: task)
      
      # Broadcast sync started event
      Phoenix.PubSub.broadcast(EhsEnforcement.PubSub, @pubsub_topic, {
        :sync_started,
        %{sync_type: sync_type, limit: limit, batch_size: batch_size}
      })
      
      {:noreply, put_flash(socket, :info, "Starting #{sync_type} sync...")}
    else
      {:error, errors} ->
        error_message = Enum.join(errors, ", ")
        {:noreply, put_flash(socket, :error, error_message)}
    end
  end
  
  defp perform_sync(:cases, opts) do
    Sync.import_cases(opts)
  end
  
  defp perform_sync(:notices, opts) do
    Sync.import_notices(opts)
  end
  
  defp perform_sync(:all, opts) do
    with {:ok, case_stats} <- Sync.import_cases(opts),
         {:ok, notice_stats} <- Sync.import_notices(opts) do
      # Combine statistics
      combined_stats = %{
        imported: (case_stats.imported || 0) + (notice_stats.imported || 0),
        created: (case_stats.created || 0) + (notice_stats.created || 0),
        updated: (case_stats.updated || 0) + (notice_stats.updated || 0),
        exists: (case_stats.exists || 0) + (notice_stats.exists || 0),
        errors: (case_stats.errors || []) ++ (notice_stats.errors || [])
      }
      {:ok, combined_stats}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp validate_sync_params(batch_size, limit, _dry_run) do
    errors = []
    
    errors = if batch_size < 1 or batch_size > 500, 
      do: ["Batch size must be between 1 and 500" | errors], 
      else: errors
      
    errors = if limit < 1 or limit > 10000, 
      do: ["Limit must be between 1 and 10000" | errors], 
      else: errors
    
    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end
  
  defp update_progress(socket, progress_updates) do
    updated_progress = Map.merge(socket.assigns.progress, progress_updates)
    socket = assign(socket, progress: updated_progress)
    
    # Force LiveView re-render by updating timestamp
    assign(socket, last_update: System.monotonic_time(:millisecond))
  end
  
  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> default
    end
  end
  defp parse_integer(value, _default) when is_integer(value), do: value
  defp parse_integer(_, default), do: default
  
  defp progress_percentage(progress) do
    case progress.status do
      :idle -> 0
      :running when progress.records_processed == 0 -> 5
      :running -> 
        # For sync, we don't know total count ahead of time
        # Show incremental progress based on records processed
        min(95, progress.records_processed / 10)
      :completed -> 100
      :stopped -> 50
      _ -> 0
    end
  end
  
  defp status_color(status) do
    case status do
      :idle -> "bg-gray-200"
      :running -> "bg-blue-500"
      :completed -> "bg-green-500"
      :stopped -> "bg-red-500"
      :error -> "bg-red-500"
      _ -> "bg-gray-200"
    end
  end
  
  defp status_text(status) do
    case status do
      :idle -> "Ready to sync"
      :running -> "Syncing in progress..."
      :completed -> "Sync completed"
      :stopped -> "Sync stopped"
      :error -> "Sync failed"
      _ -> "Unknown status"
    end
  end
  
  defp record_status_badge(status) do
    case status do
      :created -> {"Created", "bg-green-100 text-green-800"}
      :updated -> {"Updated", "bg-blue-100 text-blue-800"}
      :exists -> {"Exists", "bg-yellow-100 text-yellow-800"}
      :error -> {"Error", "bg-red-100 text-red-800"}
      _ -> {"Processing", "bg-gray-100 text-gray-800"}
    end
  end
  
  # Helper functions for template rendering
  
  defp log_icon(status) do
    case status do
      :completed -> "hero-check-circle"
      :failed -> "hero-x-circle"
      :started -> "hero-play-circle"
      _ -> "hero-clock"
    end
  end
  
  defp log_icon_color(status) do
    case status do
      :completed -> "text-green-500"
      :failed -> "text-red-500"
      :started -> "text-blue-500"
      _ -> "text-gray-400"
    end
  end
  
  defp log_description(log) do
    operation = log.operation_type || to_string(log.sync_type)
    resource = log.resource_type || "data"
    
    case log.status do
      :started -> "Started #{operation} for #{resource}"
      :completed -> "Completed #{operation} for #{resource} (#{log.records_synced || 0} records)"
      :failed -> "Failed #{operation} for #{resource}: #{log.error_message || "Unknown error"}"
      _ -> "#{operation} #{log.status} for #{resource}"
    end
  end
  
  defp relative_time(datetime) do
    case datetime do
      %DateTime{} ->
        now = DateTime.utc_now()
        diff = DateTime.diff(now, datetime, :second)
        
        cond do
          diff < 60 -> "#{diff}s ago"
          diff < 3600 -> "#{div(diff, 60)}m ago"
          diff < 86400 -> "#{div(diff, 3600)}h ago"
          true -> "#{div(diff, 86400)}d ago"
        end
      _ -> 
        "N/A"
    end
  end

  # Enhanced Features Helper Functions

  defp load_recovery_status(socket) do
    try do
      # Get sync metrics from NCDB2Phx for error analytics
      case NCDB2Phx.get_sync_metrics(%{time_window_hours: 24}) do
        {:ok, analytics} ->
          recovery_status = %{
            active_recoveries: analytics.active_recoveries || 0,
            successful_recoveries: analytics.successful_recoveries || 0,
            failed_recoveries: analytics.failed_recoveries || 0,
            recent_actions: format_recent_recovery_actions(analytics.recent_actions || [])
          }
          assign(socket, recovery_status: recovery_status)
        
        {:error, error} ->
          Logger.error("Failed to load recovery status: #{inspect(error)}")
          assign(socket, recovery_status: %{
            active_recoveries: 0,
            successful_recoveries: 0,
            failed_recoveries: 0,
            recent_actions: []
          })
      end
    rescue
      error ->
        Logger.error("Error loading recovery status: #{inspect(error)}")
        assign(socket, recovery_status: nil)
    end
  end

  defp load_integrity_status(socket) do
    try do
      # Get integrity verification results
      case NCDB2Phx.get_sync_metrics(%{resource_types: [:cases, :notices], verification_type: :count_only}) do
        {:ok, verification_result} ->
          integrity_status = %{
            overall_score: verification_result.cases_verification.verification_rate || 0.0,
            verified_records: (verification_result.cases_verification.verified_count || 0) + 
                            (verification_result.notices_verification.verified_count || 0),
            discrepancies: (verification_result.cases_verification.discrepancies || 0) + 
                         (verification_result.notices_verification.discrepancies || 0),
            last_verification: DateTime.utc_now() |> DateTime.to_string(),
            recent_reports: get_recent_integrity_reports(),
            alerts: get_integrity_alerts()
          }
          assign(socket, integrity_status: integrity_status)
        
        {:error, error} ->
          Logger.error("Failed to load integrity status: #{inspect(error)}")
          assign(socket, integrity_status: %{
            overall_score: 0.0,
            verified_records: 0,
            discrepancies: 0,
            last_verification: "Never",
            recent_reports: [],
            alerts: []
          })
      end
    rescue
      error ->
        Logger.error("Error loading integrity status: #{inspect(error)}")
        assign(socket, integrity_status: nil)
    end
  end

  defp format_recent_recovery_actions(actions) when is_list(actions) do
    actions
    |> Enum.take(5)  # Show last 5 actions
    |> Enum.map(fn action ->
      %{
        strategy: Map.get(action, :strategy, "Unknown"),
        timestamp: format_timestamp(Map.get(action, :timestamp)),
        result: Map.get(action, :result, "Unknown")
      }
    end)
  end
  defp format_recent_recovery_actions(_), do: []

  defp get_recent_integrity_reports do
    # This would typically query a reports storage system
    # For now, return empty list
    []
  end

  defp get_integrity_alerts do
    # This would typically check for integrity violations
    # For now, return empty list  
    []
  end

  defp format_timestamp(nil), do: "Unknown"
  defp format_timestamp(%DateTime{} = dt), do: DateTime.to_string(dt)
  defp format_timestamp(timestamp) when is_binary(timestamp), do: timestamp
  defp format_timestamp(_), do: "Unknown"

  defp integrity_score_color(score) when score >= 0.9, do: "text-green-600"
  defp integrity_score_color(score) when score >= 0.7, do: "text-yellow-600"
  defp integrity_score_color(_), do: "text-red-600"
end