defmodule EhsEnforcement.Sync.SessionManager do
  @moduledoc """
  Manages sync sessions with comprehensive tracking and progress monitoring.
  Designed with package-ready architecture for future extraction.
  
  This module provides session lifecycle management, progress tracking,
  and event broadcasting for any type of synchronization operation.
  """
  
  alias EhsEnforcement.Sync.{SyncSession, SyncProgress, SyncLog, EventBroadcaster, ProgressSupervisor}
  require Logger
  
  @doc """
  Start a new sync session with comprehensive tracking.
  
  ## Parameters
  
  * `session_config` - Map containing session configuration
  
  ## Session Config Options
  
  * `:session_id` - Unique session identifier (auto-generated if not provided)
  * `:sync_type` - Type of sync operation (e.g., :import_cases, :import_notices)
  * `:source_type` - Source system type (default: "airtable")
  * `:target_resource` - Target Ash resource module name
  * `:config` - Operation-specific configuration (batch_size, limits, etc.)
  * `:initiated_by` - User or system that initiated the sync
  * `:agency_id` - Associated agency ID (optional)
  * `:estimated_total` - Estimated total records to process (optional)
  
  ## Examples
  
      # Start a cases import session
      SessionManager.start_session(%{
        sync_type: :import_cases,
        target_resource: "EhsEnforcement.Enforcement.Case",
        config: %{batch_size: 100, limit: 1000},
        initiated_by: "admin@example.com"
      })
      
      # Start a custom sync session
      SessionManager.start_session(%{
        session_id: "custom-sync-123",
        sync_type: :custom_import,
        source_type: "csv",
        target_resource: "MyApp.Records",
        config: %{file_path: "/tmp/import.csv"}
      })
  """
  def start_session(session_config) do
    session_id = Map.get(session_config, :session_id, generate_session_id())
    
    session_attrs = %{
      session_id: session_id,
      sync_type: Map.get(session_config, :sync_type),
      source_type: Map.get(session_config, :source_type, "airtable"),
      target_resource: Map.get(session_config, :target_resource),
      config: Map.get(session_config, :config, %{}),
      initiated_by: Map.get(session_config, :initiated_by),
      agency_id: Map.get(session_config, :agency_id),
      total_records: Map.get(session_config, :estimated_total, 0)
    }
    
    with {:ok, session} <- SyncSession.start_session(session_attrs),
         {:ok, _log} <- create_session_log(session, :started) do
      
      # Broadcast session started event
      EventBroadcaster.broadcast_session_event(session_id, :session_started, %{
        sync_type: session.sync_type,
        target_resource: session.target_resource,
        config: session.config,
        estimated_total: session.total_records
      })
      
      # Start progress streamer for real-time updates
      ProgressSupervisor.start_streamer(session_id, [
        update_interval: 1000,
        auto_complete: true
      ])
      
      Logger.info("Started sync session #{session_id} for #{session.sync_type}")
      {:ok, session}
    else
      {:error, error} ->
        Logger.error("Failed to start sync session: #{inspect(error)}")
        {:error, error}
    end
  end
  
  @doc """
  Mark a session as running and begin progress tracking.
  """
  def mark_session_running(session_id) do
    with {:ok, session} <- get_session(session_id),
         {:ok, updated_session} <- SyncSession.mark_running(session) do
      
      EventBroadcaster.broadcast_session_event(session_id, :session_running, %{
        sync_type: updated_session.sync_type,
        started_at: updated_session.started_at
      })
      
      Logger.info("Session #{session_id} marked as running")
      {:ok, updated_session}
    end
  end
  
  @doc """
  Start tracking a new batch within a session.
  """
  def start_batch(session_id, batch_config) do
    batch_attrs = %{
      sync_session_id: get_session_uuid(session_id),
      batch_number: Map.get(batch_config, :batch_number),
      batch_size: Map.get(batch_config, :batch_size),
      source_ids: Map.get(batch_config, :source_ids, [])
    }
    
    with {:ok, batch} <- SyncProgress.start_batch(batch_attrs) do
      EventBroadcaster.broadcast_session_event(session_id, :batch_started, %{
        batch_number: batch.batch_number,
        batch_size: batch.batch_size,
        source_ids_count: length(batch.source_ids || [])
      })
      
      Logger.debug("Started batch #{batch.batch_number} for session #{session_id}")
      {:ok, batch}
    end
  end
  
  @doc """
  Update batch progress with processing results.
  """
  def update_batch_progress(batch_id, progress_data) do
    progress_attrs = %{
      records_processed: Map.get(progress_data, :records_processed, 0),
      records_created: Map.get(progress_data, :records_created, 0),
      records_updated: Map.get(progress_data, :records_updated, 0),
      records_existing: Map.get(progress_data, :records_existing, 0),
      records_failed: Map.get(progress_data, :records_failed, 0)
    }
    
    with {:ok, batch} <- get_batch(batch_id),
         {:ok, updated_batch} <- SyncProgress.update_batch_progress(batch, progress_attrs) do
      
      # Also update session totals
      session_id = get_session_id_from_batch(updated_batch)
      update_session_progress(session_id, progress_attrs)
      
      # Broadcast progress update
      EventBroadcaster.broadcast_batch_progress(session_id, %{
        batch_number: updated_batch.batch_number,
        batch_size: updated_batch.batch_size,
        records_processed: updated_batch.records_processed,
        records_created: updated_batch.records_created,
        records_updated: updated_batch.records_updated,
        records_existing: updated_batch.records_existing,
        records_failed: updated_batch.records_failed,
        status: :processing
      })
      
      {:ok, updated_batch}
    end
  end
  
  @doc """
  Mark a batch as completed with final results.
  """
  def complete_batch(batch_id, final_results) do
    completion_attrs = %{
      records_created: Map.get(final_results, :records_created, 0),
      records_updated: Map.get(final_results, :records_updated, 0),
      records_existing: Map.get(final_results, :records_existing, 0),
      records_failed: Map.get(final_results, :records_failed, 0),
      failed_ids: Map.get(final_results, :failed_ids, [])
    }
    
    with {:ok, batch} <- get_batch(batch_id),
         {:ok, completed_batch} <- SyncProgress.mark_completed(batch, completion_attrs) do
      
      session_id = get_session_id_from_batch(completed_batch)
      
      EventBroadcaster.broadcast_session_event(session_id, :batch_completed, %{
        batch_number: completed_batch.batch_number,
        records_created: completed_batch.records_created,
        records_updated: completed_batch.records_updated,
        records_existing: completed_batch.records_existing,
        records_failed: completed_batch.records_failed,
        status: :completed
      })
      
      Logger.debug("Completed batch #{completed_batch.batch_number} for session #{session_id}")
      {:ok, completed_batch}
    end
  end
  
  @doc """
  Complete a sync session with final statistics.
  """
  def complete_session(session_id, final_stats \\ %{}) do
    with {:ok, session} <- get_session(session_id),
         {:ok, completed_session} <- SyncSession.mark_completed(session, final_stats),
         {:ok, _log} <- create_session_log(completed_session, :completed) do
      
      EventBroadcaster.broadcast_sync_completion(session_id, Map.merge(final_stats, %{
        sync_type: completed_session.sync_type,
        duration_seconds: calculate_session_duration(completed_session),
        total_processed: completed_session.processed_records
      }))
      
      # Stop progress streamer
      ProgressSupervisor.stop_streamer(session_id)
      
      Logger.info("Completed sync session #{session_id}")
      {:ok, completed_session}
    end
  end
  
  @doc """
  Mark a session as failed with error details.
  """
  def fail_session(session_id, error_info) do
    error_attrs = %{
      error_message: format_error_message(error_info),
      error_details: format_error_details(error_info)
    }
    
    with {:ok, session} <- get_session(session_id),
         {:ok, failed_session} <- SyncSession.mark_failed(session, error_attrs),
         {:ok, _log} <- create_session_log(failed_session, :failed) do
      
      EventBroadcaster.broadcast_sync_error(session_id, Map.merge(error_info, %{
        sync_type: failed_session.sync_type,
        session_id: session_id
      }))
      
      # Stop progress streamer
      ProgressSupervisor.stop_streamer(session_id)
      
      Logger.error("Failed sync session #{session_id}: #{inspect(error_info)}")
      {:ok, failed_session}
    end
  end
  
  @doc """
  Get session by session_id.
  """
  def get_session(session_id) do
    case SyncSession.read() do
      {:ok, sessions} ->
        case Enum.find(sessions, &(&1.session_id == session_id)) do
          nil -> {:error, :session_not_found}
          session -> {:ok, session}
        end
      {:error, error} -> {:error, error}
    end
  end
  
  @doc """
  Get all batches for a session.
  """
  def get_session_batches(session_id) do
    with {:ok, session} <- get_session(session_id) do
      # Note: This would need proper Ash query when relationships are set up
      # For now, return a placeholder
      {:ok, []}
    end
  end
  
  @doc """
  Get session statistics and progress summary.
  """
  def get_session_stats(session_id) do
    with {:ok, session} <- get_session(session_id),
         {:ok, batches} <- get_session_batches(session_id) do
      
      stats = %{
        session_id: session.session_id,
        sync_type: session.sync_type,
        status: session.status,
        total_records: session.total_records,
        processed_records: session.processed_records,
        created_records: session.created_records,
        updated_records: session.updated_records,
        existing_records: session.existing_records,
        error_records: session.error_records,
        started_at: session.started_at,
        completed_at: session.completed_at,
        duration_seconds: calculate_session_duration(session),
        batch_count: length(batches),
        progress_percentage: calculate_progress_percentage(session)
      }
      
      {:ok, stats}
    end
  end
  
  # Private functions
  
  defp generate_session_id do
    "sync_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end
  
  defp get_session_uuid(session_id) do
    case get_session(session_id) do
      {:ok, session} -> session.id
      {:error, _} -> nil
    end
  end
  
  defp get_batch(batch_id) do
    # This would be implemented with proper Ash queries
    # For now, return a placeholder
    {:error, :not_implemented}
  end
  
  defp get_session_id_from_batch(batch) do
    # This would extract session_id from batch relationship
    # For now, return a placeholder
    "unknown_session"
  end
  
  defp update_session_progress(session_id, progress_data) do
    with {:ok, session} <- get_session(session_id) do
      # Accumulate progress data to session totals
      updated_attrs = %{
        processed_records: session.processed_records + Map.get(progress_data, :records_processed, 0),
        created_records: session.created_records + Map.get(progress_data, :records_created, 0),
        updated_records: session.updated_records + Map.get(progress_data, :records_updated, 0),
        existing_records: session.existing_records + Map.get(progress_data, :records_existing, 0),
        error_records: session.error_records + Map.get(progress_data, :records_failed, 0)
      }
      
      SyncSession.update_progress(session, updated_attrs)
    end
  end
  
  defp create_session_log(session, status) do
    log_attrs = %{
      sync_type: session.sync_type,
      operation_type: "import",
      resource_type: session.target_resource,
      status: status,
      session_id: session.session_id,
      agency_id: session.agency_id,
      config_snapshot: session.config,
      records_synced: session.processed_records,
      records_created: session.created_records,
      records_updated: session.updated_records,
      records_existing: session.existing_records,
      records_failed: session.error_records,
      started_at: session.started_at,
      completed_at: session.completed_at
    }
    
    SyncLog.log_sync_start(log_attrs)
  end
  
  defp calculate_session_duration(session) do
    case {session.started_at, session.completed_at} do
      {%DateTime{} = started, %DateTime{} = completed} ->
        DateTime.diff(completed, started, :second)
      {%DateTime{} = started, nil} ->
        DateTime.diff(DateTime.utc_now(), started, :second)
      _ ->
        0
    end
  end
  
  defp calculate_progress_percentage(session) do
    if session.total_records > 0 do
      (session.processed_records * 100.0) / session.total_records
    else
      0.0
    end
  end
  
  defp format_error_message(error_info) when is_map(error_info) do
    Map.get(error_info, :message, "Unknown error")
  end
  defp format_error_message(error) when is_binary(error), do: error
  defp format_error_message(error), do: inspect(error)
  
  defp format_error_details(error_info) when is_map(error_info) do
    Map.drop(error_info, [:message])
  end
  defp format_error_details(error), do: %{raw_error: inspect(error)}
end