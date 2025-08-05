defmodule EhsEnforcement.Sync.ProgressStreamer do
  @moduledoc """
  Generic progress streaming service for sync operations.
  Provides real-time progress updates for any resource type or sync operation.
  
  Designed with package-ready architecture for future extraction.
  """
  
  use GenServer
  
  alias EhsEnforcement.Sync.{EventBroadcaster, SessionManager}
  require Logger
  
  @default_update_interval 1000  # 1 second
  @progress_topic "sync:progress"
  
  # Client API
  
  @doc """
  Start a progress streamer for a sync session.
  
  ## Options
  
  * `:session_id` - Required. The sync session ID to track
  * `:update_interval` - Update interval in milliseconds (default: 1000)
  * `:auto_complete` - Whether to auto-complete when target reached (default: true)
  * `:progress_callback` - Function to call on each progress update
  * `:completion_callback` - Function to call when streaming completes
  """
  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(session_id))
  end
  
  @doc """
  Update progress for a streaming session.
  """
  def update_progress(session_id, progress_data) do
    case GenServer.whereis(via_tuple(session_id)) do
      nil -> 
        Logger.warning("Progress streamer not found for session #{session_id}")
        {:error, :streamer_not_found}
      pid -> 
        GenServer.cast(pid, {:update_progress, progress_data})
    end
  end
  
  @doc """
  Get current progress for a session.
  """
  def get_progress(session_id) do
    case GenServer.whereis(via_tuple(session_id)) do
      nil -> {:error, :streamer_not_found}
      pid -> GenServer.call(pid, :get_progress)
    end
  end
  
  @doc """
  Stop progress streaming for a session.
  """
  def stop_streaming(session_id) do
    case GenServer.whereis(via_tuple(session_id)) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal)
    end
  end
  
  @doc """
  List all active streaming sessions.
  """
  def list_active_sessions do
    Registry.select(EhsEnforcement.Sync.ProgressRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])
  end
  
  # GenServer Callbacks
  
  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    update_interval = Keyword.get(opts, :update_interval, @default_update_interval)
    auto_complete = Keyword.get(opts, :auto_complete, true)
    progress_callback = Keyword.get(opts, :progress_callback)
    completion_callback = Keyword.get(opts, :completion_callback)
    
    # Schedule first progress update
    schedule_progress_update(update_interval)
    
    state = %{
      session_id: session_id,
      update_interval: update_interval,
      auto_complete: auto_complete,
      progress_callback: progress_callback,
      completion_callback: completion_callback,
      current_progress: %{
        total_records: 0,
        processed_records: 0,
        created_records: 0,
        updated_records: 0,
        existing_records: 0,
        error_records: 0,
        batch_count: 0,
        current_batch: nil,
        status: :pending,
        started_at: DateTime.utc_now(),
        last_update_at: DateTime.utc_now()
      },
      last_broadcast_at: nil,
      update_count: 0
    }
    
    Logger.info("Started progress streamer for session #{session_id}")
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:update_progress, progress_data}, state) do
    updated_progress = Map.merge(state.current_progress, Map.put(progress_data, :last_update_at, DateTime.utc_now()))
    
    new_state = %{state | 
      current_progress: updated_progress,
      update_count: state.update_count + 1
    }
    
    # Call progress callback if provided
    if state.progress_callback do
      state.progress_callback.(updated_progress)
    end
    
    # Check for auto-completion
    if state.auto_complete and should_auto_complete?(updated_progress) do
      handle_completion(new_state)
    else
      {:noreply, new_state}
    end
  end
  
  @impl true
  def handle_call(:get_progress, _from, state) do
    {:reply, {:ok, state.current_progress}, state}
  end
  
  @impl true
  def handle_info(:update_progress, state) do
    # Fetch latest progress from session manager
    case SessionManager.get_session_stats(state.session_id) do
      {:ok, session_stats} ->
        # Convert session stats to progress format
        progress_data = %{
          total_records: session_stats.total_records,
          processed_records: session_stats.processed_records,
          created_records: session_stats.created_records,
          updated_records: session_stats.updated_records,
          existing_records: session_stats.existing_records,
          error_records: session_stats.error_records,
          status: session_stats.status,
          progress_percentage: session_stats.progress_percentage
        }
        
        updated_progress = Map.merge(state.current_progress, progress_data)
        
        # Broadcast progress update
        broadcast_progress_update(state.session_id, updated_progress)
        
        new_state = %{state | 
          current_progress: updated_progress,
          last_broadcast_at: DateTime.utc_now()
        }
        
        # Schedule next update if still running
        if updated_progress.status in [:pending, :running] do
          schedule_progress_update(state.update_interval)
        end
        
        {:noreply, new_state}
        
      {:error, :session_not_found} ->
        Logger.warning("Session #{state.session_id} not found, stopping progress streamer")
        {:stop, :normal, state}
        
      {:error, error} ->
        Logger.error("Failed to get session stats for #{state.session_id}: #{inspect(error)}")
        schedule_progress_update(state.update_interval * 2)  # Retry with longer interval
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info(:complete_streaming, state) do
    handle_completion(state)
  end
  
  @impl true
  def terminate(reason, state) do
    Logger.info("Progress streamer for session #{state.session_id} terminated: #{inspect(reason)}")
    
    # Send final progress update
    final_progress = Map.put(state.current_progress, :status, :completed)
    broadcast_progress_update(state.session_id, final_progress)
    
    :ok
  end
  
  # Private functions
  
  defp via_tuple(session_id) do
    {:via, Registry, {EhsEnforcement.Sync.ProgressRegistry, session_id}}
  end
  
  defp schedule_progress_update(interval) do
    Process.send_after(self(), :update_progress, interval)
  end
  
  defp should_auto_complete?(progress) do
    progress.status in [:completed, :failed, :cancelled] or
    (progress.total_records > 0 and progress.processed_records >= progress.total_records)
  end
  
  defp handle_completion(state) do
    Logger.info("Completing progress streaming for session #{state.session_id}")
    
    # Call completion callback if provided
    if state.completion_callback do
      state.completion_callback.(state.current_progress)
    end
    
    # Send final broadcast
    final_progress = Map.put(state.current_progress, :status, :completed)
    broadcast_progress_update(state.session_id, final_progress)
    
    {:stop, :normal, state}
  end
  
  defp broadcast_progress_update(session_id, progress) do
    # Broadcast via EventBroadcaster
    EventBroadcaster.broadcast_session_event(session_id, :progress_update, progress)
    
    # Also broadcast to the legacy topic for backward compatibility
    EventBroadcaster.broadcast(:sync_progress, progress, topic: @progress_topic)
  end
  
  @doc """
  Calculate streaming statistics for performance monitoring.
  """
  def get_streaming_stats(session_id) do
    case get_progress(session_id) do
      {:ok, progress} ->
        duration = DateTime.diff(DateTime.utc_now(), progress.started_at, :second)
        
        stats = %{
          session_id: session_id,
          duration_seconds: duration,
          total_records: progress.total_records,
          processed_records: progress.processed_records,
          progress_percentage: calculate_progress_percentage(progress),
          processing_rate: calculate_processing_rate(progress, duration),
          estimated_completion: estimate_completion_time(progress, duration),
          last_update_age: DateTime.diff(DateTime.utc_now(), progress.last_update_at, :second)
        }
        
        {:ok, stats}
        
      error -> error
    end
  end
  
  defp calculate_progress_percentage(progress) do
    if progress.total_records > 0 do
      Float.round((progress.processed_records / progress.total_records) * 100, 2)
    else
      0.0
    end
  end
  
  defp calculate_processing_rate(progress, duration) do
    if duration > 0 and progress.processed_records > 0 do
      Float.round(progress.processed_records / duration, 2)
    else
      0.0
    end
  end
  
  defp estimate_completion_time(progress, duration) do
    if progress.total_records > 0 and progress.processed_records > 0 and duration > 0 do
      remaining = progress.total_records - progress.processed_records
      rate = progress.processed_records / duration
      
      if rate > 0 do
        estimated_seconds = Float.round(remaining / rate)
        DateTime.add(DateTime.utc_now(), round(estimated_seconds), :second)
      else
        nil
      end
    else
      nil
    end
  end
end