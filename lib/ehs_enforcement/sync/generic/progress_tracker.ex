defmodule EhsEnforcement.Sync.Generic.ProgressTracker do
  @moduledoc """
  Generic progress tracking system for sync operations.
  
  This module provides a universal progress tracking interface that works
  with any Phoenix application's PubSub system and any session storage
  mechanism. It's designed to be extracted as part of the `airtable_sync_phoenix`
  package with minimal dependencies on the host application.
  
  ## Features
  
  - Real-time progress broadcasting via PubSub
  - Session lifecycle management (start, update, complete, fail)
  - Batch-level progress tracking with statistics
  - Generic event system that works with any PubSub implementation
  - Configurable progress intervals and aggregation
  - Memory-efficient streaming for large operations
  
  ## Configuration
  
      config = %{
        pubsub_module: MyApp.PubSub,
        progress_topic: "sync_progress",
        session_storage: :memory,  # :memory | :database | :ets
        broadcast_interval_ms: 1000,
        max_session_history: 100
      }
  
  ## Usage
  
      # Initialize tracker
      {:ok, tracker} = ProgressTracker.initialize(pubsub_config, session_config)
      
      # Start session
      session_data = %{
        session_id: "sync_123",
        sync_type: :import_cases,
        estimated_total: 1000
      }
      {:ok, session} = ProgressTracker.start_session(session_data)
      
      # Track batch progress
      {:ok, batch} = ProgressTracker.start_batch(session_id, batch_config)
      ProgressTracker.update_batch_progress(batch.id, results)
      ProgressTracker.complete_batch(batch.id, final_results)
      
      # Complete session
      ProgressTracker.complete_session(session_id, final_stats)
  """
  
  alias EhsEnforcement.Sync.SessionManager
  alias EhsEnforcement.Sync.EventBroadcaster
  require Logger

  @type tracker_state :: %{
    pubsub_config: map(),
    session_config: map(),
    session_storage: atom(),
    active_sessions: map()
  }
  
  @type session_data :: %{
    session_id: String.t(),
    sync_type: atom(),
    target_resource: String.t(),
    estimated_total: non_neg_integer(),
    initiated_by: String.t(),
    config: map()
  }
  
  @type batch_config :: %{
    batch_number: non_neg_integer(),
    batch_size: non_neg_integer(),
    source_ids: [String.t()]
  }

  @doc """
  Initialize the progress tracker with PubSub and session configuration.
  
  ## Parameters
  
  * `pubsub_config` - PubSub configuration map
  * `session_config` - Session tracking configuration map
  
  ## Returns
  
  * `{:ok, tracker_state}` - Initialized tracker
  * `{:error, reason}` - Initialization failed
  """
  @spec initialize(map(), map()) :: {:ok, tracker_state()} | {:error, any()}
  def initialize(pubsub_config, session_config) do
    Logger.debug("🔧 Initializing generic progress tracker")
    
    session_storage = Map.get(session_config, :session_storage, :database)
    
    tracker_state = %{
      pubsub_config: pubsub_config,
      session_config: session_config,
      session_storage: session_storage,
      active_sessions: %{}
    }
    
    # Initialize session storage if needed
    case initialize_session_storage(session_storage) do
      :ok ->
        Logger.debug("✅ Progress tracker initialized successfully")
        {:ok, tracker_state}
        
      {:error, reason} ->
        Logger.error("❌ Progress tracker initialization failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Start a new sync session with progress tracking.
  
  ## Parameters
  
  * `session_data` - Session information and configuration
  
  ## Returns
  
  * `{:ok, session}` - Session started successfully
  * `{:error, reason}` - Session start failed
  """
  @spec start_session(session_data()) :: {:ok, any()} | {:error, any()}
  def start_session(session_data) do
    Logger.debug("🚀 Starting generic progress tracking session: #{session_data.session_id}")
    
    # Delegate to existing SessionManager for compatibility
    case SessionManager.start_session(session_data) do
      {:ok, session} ->
        # Broadcast session start event
        broadcast_progress_event(:session_started, %{
          session_id: session_data.session_id,
          sync_type: session_data.sync_type,
          estimated_total: session_data.estimated_total,
          started_at: DateTime.utc_now()
        })
        
        {:ok, session}
        
      {:error, reason} ->
        Logger.error("❌ Failed to start progress tracking session: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Mark a session as running (active processing).
  """
  @spec mark_session_running(String.t()) :: :ok | {:error, any()}
  def mark_session_running(session_id) do
    Logger.debug("▶️ Marking session as running: #{session_id}")
    
    case SessionManager.mark_session_running(session_id) do
      :ok ->
        broadcast_progress_event(:session_running, %{
          session_id: session_id,
          status: :running,
          updated_at: DateTime.utc_now()
        })
        :ok
        
      {:error, reason} ->
        Logger.error("❌ Failed to mark session as running: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Start tracking a new batch within a session.
  
  ## Parameters
  
  * `session_id` - The session ID
  * `batch_config` - Batch configuration and metadata
  
  ## Returns
  
  * `{:ok, batch_progress}` - Batch tracking started
  * `{:error, reason}` - Batch start failed
  """
  @spec start_batch(String.t(), batch_config()) :: {:ok, any()} | {:error, any()}
  def start_batch(session_id, batch_config) do
    Logger.debug("📦 Starting batch tracking: #{session_id} batch #{batch_config.batch_number}")
    
    case SessionManager.start_batch(session_id, batch_config) do
      {:ok, batch_progress} ->
        # Broadcast batch start event
        broadcast_progress_event(:batch_started, %{
          session_id: session_id,
          batch_number: batch_config.batch_number,
          batch_size: batch_config.batch_size,
          batch_id: batch_progress.id,
          started_at: DateTime.utc_now()
        })
        
        {:ok, batch_progress}
        
      {:error, reason} ->
        Logger.error("❌ Failed to start batch tracking: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Update progress for an active batch.
  
  ## Parameters
  
  * `batch_id` - The batch progress ID
  * `progress_data` - Current progress information
  
  ## Returns
  
  * `:ok` - Progress updated successfully
  * `{:error, reason}` - Update failed
  """
  @spec update_batch_progress(String.t(), map()) :: :ok | {:error, any()}
  def update_batch_progress(batch_id, progress_data) do
    Logger.debug("📊 Updating batch progress: #{batch_id}")
    
    case SessionManager.update_batch_progress(batch_id, progress_data) do
      :ok ->
        # Broadcast progress update
        broadcast_progress_event(:batch_progress_updated, %{
          batch_id: batch_id,
          progress: progress_data,
          updated_at: DateTime.utc_now()
        })
        :ok
        
      {:error, reason} ->
        Logger.error("❌ Failed to update batch progress: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Complete a batch with final results.
  
  ## Parameters
  
  * `batch_id` - The batch progress ID
  * `final_results` - Final batch processing results
  
  ## Returns
  
  * `:ok` - Batch completed successfully
  * `{:error, reason}` - Completion failed
  """
  @spec complete_batch(String.t(), map()) :: :ok | {:error, any()}
  def complete_batch(batch_id, final_results) do
    Logger.debug("✅ Completing batch: #{batch_id}")
    
    case SessionManager.complete_batch(batch_id, final_results) do
      :ok ->
        # Broadcast batch completion
        broadcast_progress_event(:batch_completed, %{
          batch_id: batch_id,
          results: final_results,
          completed_at: DateTime.utc_now()
        })
        :ok
        
      {:error, reason} ->
        Logger.error("❌ Failed to complete batch: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Mark a batch as failed.
  
  ## Parameters
  
  * `batch_id` - The batch progress ID
  * `error_info` - Error information and details
  
  ## Returns
  
  * `:ok` - Batch marked as failed
  * `{:error, reason}` - Failed to mark as failed
  """
  @spec fail_batch(String.t(), map()) :: :ok | {:error, any()}
  def fail_batch(batch_id, error_info) do
    Logger.debug("❌ Marking batch as failed: #{batch_id}")
    
    case SessionManager.fail_batch(batch_id, error_info) do
      :ok ->
        # Broadcast batch failure
        broadcast_progress_event(:batch_failed, %{
          batch_id: batch_id,
          error: error_info,
          failed_at: DateTime.utc_now()
        })
        :ok
        
      {:error, reason} ->
        Logger.error("❌ Failed to mark batch as failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Complete a session with final statistics.
  
  ## Parameters
  
  * `session_id` - The session ID
  * `final_stats` - Final session statistics and results
  
  ## Returns
  
  * `:ok` - Session completed successfully
  * `{:error, reason}` - Completion failed
  """
  @spec complete_session(String.t(), map()) :: :ok | {:error, any()}
  def complete_session(session_id, final_stats) do
    Logger.debug("✅ Completing session: #{session_id}")
    
    case SessionManager.complete_session(session_id, final_stats) do
      :ok ->
        # Broadcast session completion
        broadcast_progress_event(:session_completed, %{
          session_id: session_id,
          final_stats: final_stats,
          completed_at: DateTime.utc_now()
        })
        :ok
        
      {:error, reason} ->
        Logger.error("❌ Failed to complete session: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Mark a session as failed.
  
  ## Parameters
  
  * `session_id` - The session ID
  * `error_info` - Error information and details
  
  ## Returns
  
  * `:ok` - Session marked as failed
  * `{:error, reason}` - Failed to mark as failed
  """
  @spec fail_session(String.t(), map()) :: :ok | {:error, any()}
  def fail_session(session_id, error_info) do
    Logger.debug("❌ Marking session as failed: #{session_id}")
    
    case SessionManager.fail_session(session_id, error_info) do
      :ok ->
        # Broadcast session failure
        broadcast_progress_event(:session_failed, %{
          session_id: session_id,
          error: error_info,
          failed_at: DateTime.utc_now()
        })
        :ok
        
      {:error, reason} ->
        Logger.error("❌ Failed to mark session as failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Cancel an active session.
  
  ## Parameters
  
  * `session_id` - The session ID to cancel
  
  ## Returns
  
  * `:ok` - Session cancelled successfully
  * `{:error, reason}` - Cancellation failed
  """
  @spec cancel_session(String.t()) :: :ok | {:error, any()}
  def cancel_session(session_id) do
    Logger.debug("🛑 Cancelling session: #{session_id}")
    
    case SessionManager.cancel_session(session_id) do
      :ok ->
        # Broadcast session cancellation
        broadcast_progress_event(:session_cancelled, %{
          session_id: session_id,
          cancelled_at: DateTime.utc_now()
        })
        :ok
        
      {:error, reason} ->
        Logger.error("❌ Failed to cancel session: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get current status and progress for a session.
  
  ## Parameters
  
  * `session_id` - The session ID
  
  ## Returns
  
  * `{:ok, session_status}` - Current session status and progress
  * `{:error, reason}` - Status retrieval failed
  """
  @spec get_session_status(String.t()) :: {:ok, map()} | {:error, any()}
  def get_session_status(session_id) do
    Logger.debug("📊 Getting session status: #{session_id}")
    
    case SessionManager.get_session_status(session_id) do
      {:ok, status} ->
        {:ok, status}
        
      {:error, reason} ->
        Logger.debug("⚠️ Failed to get session status: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get progress statistics for all active sessions.
  
  ## Returns
  
  * `{:ok, active_sessions}` - List of active session statuses
  * `{:error, reason}` - Retrieval failed
  """
  @spec get_active_sessions() :: {:ok, [map()]} | {:error, any()}
  def get_active_sessions do
    Logger.debug("📊 Getting all active sessions")
    
    case SessionManager.get_active_sessions() do
      {:ok, sessions} ->
        {:ok, sessions}
        
      {:error, reason} ->
        Logger.debug("⚠️ Failed to get active sessions: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Stream real-time progress events for a session.
  
  This function returns a stream that yields progress events as they occur.
  Useful for building real-time dashboards and monitoring systems.
  
  ## Parameters
  
  * `session_id` - The session ID to monitor
  * `opts` - Streaming options:
    * `:timeout_ms` - Event timeout in milliseconds (default: 30000)
    * `:event_types` - List of event types to include (default: all)
  
  ## Returns
  
  * `Stream.t()` - Stream of progress events
  """
  @spec stream_progress_events(String.t(), keyword()) :: Stream.t()
  def stream_progress_events(session_id, opts \\ []) do
    timeout_ms = Keyword.get(opts, :timeout_ms, 30_000)
    event_types = Keyword.get(opts, :event_types, :all)
    
    Logger.debug("📡 Starting progress event stream for session: #{session_id}")
    
    # Create a stream that subscribes to PubSub events for this session
    Stream.resource(
      fn ->
        # Subscribe to progress events
        topic = "sync_progress:#{session_id}"
        Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, topic)
        
        %{
          session_id: session_id,
          topic: topic,
          event_types: event_types,
          timeout_ms: timeout_ms
        }
      end,
      fn state ->
        # Receive progress events
        receive do
          {:progress_event, event_type, event_data} ->
            if should_include_event?(event_type, state.event_types) do
              event = %{
                session_id: state.session_id,
                event_type: event_type,
                event_data: event_data,
                timestamp: DateTime.utc_now()
              }
              {[event], state}
            else
              {[], state}
            end
            
          {:session_completed, _} ->
            # End stream when session completes
            {:halt, state}
            
          {:session_failed, _} ->
            # End stream when session fails
            {:halt, state}
            
          {:session_cancelled, _} ->
            # End stream when session is cancelled
            {:halt, state}
        after
          state.timeout_ms ->
            # Timeout - end stream
            {:halt, state}
        end
      end,
      fn state ->
        # Cleanup - unsubscribe from PubSub
        Phoenix.PubSub.unsubscribe(EhsEnforcement.PubSub, state.topic)
        :ok
      end
    )
  end

  # Private functions

  defp initialize_session_storage(:memory) do
    # Memory storage is always available
    :ok
  end
  
  defp initialize_session_storage(:database) do
    # Database storage uses existing SessionManager
    :ok
  end
  
  defp initialize_session_storage(:ets) do
    # ETS storage would be initialized here
    # For now, fall back to memory
    :ok
  end
  
  defp initialize_session_storage(unknown_storage) do
    Logger.warn("⚠️ Unknown session storage type: #{unknown_storage}, falling back to memory")
    :ok
  end

  defp broadcast_progress_event(event_type, event_data) do
    # Use existing EventBroadcaster for compatibility
    EventBroadcaster.broadcast(event_type, event_data, topic: "sync_progress")
    
    # Also broadcast on session-specific topic if session_id is present
    if Map.has_key?(event_data, :session_id) do
      session_topic = "sync_progress:#{event_data.session_id}"
      EventBroadcaster.broadcast(event_type, event_data, topic: session_topic)
    end
    
    :ok
  end

  defp should_include_event?(_event_type, :all), do: true
  defp should_include_event?(event_type, event_types) when is_list(event_types) do
    event_type in event_types
  end
  defp should_include_event?(_event_type, _event_types), do: true
end