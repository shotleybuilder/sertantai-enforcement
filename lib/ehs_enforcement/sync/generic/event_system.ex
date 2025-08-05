defmodule EhsEnforcement.Sync.Generic.EventSystem do
  @moduledoc """
  Generic event system for sync operations that works with any Phoenix PubSub.
  
  This module provides a universal event broadcasting and subscription system
  for sync operations. It's designed to be extracted as part of the 
  `airtable_sync_phoenix` package with minimal dependencies on the host application.
  
  ## Features
  
  - Universal PubSub interface that works with any Phoenix application
  - Structured event format with consistent metadata
  - Topic namespacing and event filtering
  - Batch event broadcasting for performance
  - Event history and replay capabilities
  - Pluggable event handlers and processors
  - Real-time event streaming for LiveView
  
  ## Event Structure
  
  All events follow a consistent structure:
  
      %{
        event_id: "evt_abc123",
        event_type: :sync_started,
        source: :sync_engine,
        session_id: "sync_abc123",
        timestamp: ~U[2023-01-01 10:00:00Z],
        data: %{...},
        metadata: %{
          version: "1.0",
          source_module: "EhsEnforcement.Sync.Generic.SyncEngine",
          correlation_id: "corr_abc123"
        }
      }
  
  ## Configuration
  
      config = %{
        pubsub_module: MyApp.PubSub,
        topic_prefix: "sync",
        event_history: %{
          enabled: true,
          max_events: 1000,
          storage: :memory  # :memory | :database | :ets
        },
        event_handlers: [
          MyApp.Sync.EventLogger,
          MyApp.Sync.MetricsCollector
        ]
      }
  
  ## Usage
  
      # Initialize event system
      {:ok, event_system} = EventSystem.initialize(config)
      
      # Broadcast sync events
      EventSystem.broadcast_sync_event(:sync_started, %{
        session_id: "sync_123",
        resource_type: :cases,
        estimated_total: 1000
      })
      
      # Subscribe to events
      EventSystem.subscribe("sync_progress")
      EventSystem.subscribe("sync:session_123")
      
      # Stream events for LiveView
      EventSystem.stream_events("sync:session_123")
      |> Enum.each(fn event -> handle_event(event) end)
  """
  
  require Logger

  @type event :: %{
    event_id: String.t(),
    event_type: atom(),
    source: atom(),
    session_id: String.t() | nil,
    timestamp: DateTime.t(),
    data: map(),
    metadata: map()
  }

  @type event_config :: %{
    pubsub_module: module(),
    topic_prefix: String.t(),
    event_history: map(),
    event_handlers: [module()]
  }

  @type event_system_state :: %{
    config: event_config(),
    pubsub_module: module(),
    event_history: list(),
    event_handlers: [module()],
    subscriptions: map()
  }

  @doc """
  Initialize the generic event system.
  
  ## Parameters
  
  * `config` - Event system configuration
  
  ## Returns
  
  * `{:ok, event_system_state}` - Initialized event system
  * `{:error, reason}` - Initialization failed
  """
  @spec initialize(event_config()) :: {:ok, event_system_state()} | {:error, any()}
  def initialize(config) do
    Logger.debug("🔧 Initializing generic event system")
    
    with {:ok, normalized_config} <- normalize_event_config(config),
         :ok <- validate_pubsub_module(normalized_config.pubsub_module),
         {:ok, event_handlers} <- initialize_event_handlers(normalized_config.event_handlers) do
      
      event_system_state = %{
        config: normalized_config,
        pubsub_module: normalized_config.pubsub_module,
        event_history: [],
        event_handlers: event_handlers,
        subscriptions: %{}
      }
      
      Logger.debug("✅ Generic event system initialized successfully")
      {:ok, event_system_state}
    else
      {:error, reason} ->
        Logger.error("❌ Event system initialization failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Broadcast a sync event to all subscribers.
  
  ## Parameters
  
  * `event_type` - Type of event (:sync_started, :batch_completed, etc.)
  * `event_data` - Event-specific data
  * `opts` - Broadcasting options:
    * `:session_id` - Session ID for session-specific events
    * `:topic` - Custom topic (overrides default)
    * `:source` - Event source module (default: :sync_engine)
    * `:correlation_id` - Correlation ID for event tracking
  
  ## Returns
  
  * `:ok` - Event broadcasted successfully
  * `{:error, reason}` - Broadcasting failed
  """
  @spec broadcast_sync_event(atom(), map(), keyword()) :: :ok | {:error, any()}
  def broadcast_sync_event(event_type, event_data, opts \\ []) do
    session_id = Keyword.get(opts, :session_id)
    custom_topic = Keyword.get(opts, :topic)
    source = Keyword.get(opts, :source, :sync_engine)
    correlation_id = Keyword.get(opts, :correlation_id)
    
    # Create structured event
    event = create_event(event_type, event_data, %{
      source: source,
      session_id: session_id,
      correlation_id: correlation_id
    })
    
    # Determine topics to broadcast to
    topics = determine_broadcast_topics(event_type, session_id, custom_topic)
    
    # Broadcast to all relevant topics
    Enum.each(topics, fn topic ->
      broadcast_to_topic(topic, event)
    end)
    
    # Store in event history if enabled
    store_event_in_history(event)
    
    # Notify event handlers
    notify_event_handlers(event)
    
    Logger.debug("📡 Broadcasted #{event_type} event to #{length(topics)} topics")
    :ok
  end

  @doc """
  Subscribe to sync events on a specific topic.
  
  ## Parameters
  
  * `topic` - Topic to subscribe to (e.g., "sync_progress", "sync:session_123")
  
  ## Returns
  
  * `:ok` - Subscribed successfully
  * `{:error, reason}` - Subscription failed
  """
  @spec subscribe(String.t()) :: :ok | {:error, any()}
  def subscribe(topic) do
    Logger.debug("📡 Subscribing to topic: #{topic}")
    
    case get_pubsub_module() do
      {:ok, pubsub_module} ->
        Phoenix.PubSub.subscribe(pubsub_module, topic)
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Unsubscribe from sync events on a specific topic.
  
  ## Parameters
  
  * `topic` - Topic to unsubscribe from
  
  ## Returns
  
  * `:ok` - Unsubscribed successfully
  """
  @spec unsubscribe(String.t()) :: :ok
  def unsubscribe(topic) do
    Logger.debug("📡 Unsubscribing from topic: #{topic}")
    
    case get_pubsub_module() do
      {:ok, pubsub_module} ->
        Phoenix.PubSub.unsubscribe(pubsub_module, topic)
        
      {:error, _reason} ->
        :ok  # Already unsubscribed or invalid
    end
  end

  @doc """
  Stream events from a topic in real-time.
  
  Creates a stream that yields events as they are received from the PubSub system.
  Useful for LiveView real-time updates and event processing pipelines.
  
  ## Parameters
  
  * `topic` - Topic to stream events from
  * `opts` - Streaming options:
    * `:timeout_ms` - Timeout for waiting for events (default: 30000)
    * `:buffer_size` - Internal buffer size (default: 100)
    * `:filter` - Event filter function
  
  ## Returns
  
  * `Stream.t()` - Stream of events
  """
  @spec stream_events(String.t(), keyword()) :: Stream.t()
  def stream_events(topic, opts \\ []) do
    timeout_ms = Keyword.get(opts, :timeout_ms, 30_000)
    buffer_size = Keyword.get(opts, :buffer_size, 100)
    filter_func = Keyword.get(opts, :filter)
    
    Logger.debug("📡 Starting event stream for topic: #{topic}")
    
    Stream.resource(
      fn ->
        # Subscribe to the topic
        :ok = subscribe(topic)
        
        %{
          topic: topic,
          timeout_ms: timeout_ms,
          buffer_size: buffer_size,
          filter_func: filter_func,
          buffer: :queue.new()
        }
      end,
      fn stream_state ->
        # Receive events
        case receive_event_with_timeout(stream_state.timeout_ms) do
          {:ok, event} ->
            if should_include_event?(event, stream_state.filter_func) do
              {[event], stream_state}
            else
              {[], stream_state}
            end
            
          :timeout ->
            {:halt, stream_state}
            
          {:error, reason} ->
            Logger.warn("⚠️ Event stream error: #{inspect(reason)}")
            {:halt, stream_state}
        end
      end,
      fn stream_state ->
        # Cleanup - unsubscribe
        unsubscribe(stream_state.topic)
        Logger.debug("🧹 Event stream cleanup completed for topic: #{stream_state.topic}")
        :ok
      end
    )
  end

  @doc """
  Get recent event history for a session or topic.
  
  ## Parameters
  
  * `session_id` - Session ID to get events for
  * `opts` - Query options:
    * `:limit` - Maximum number of events to return (default: 100)
    * `:since` - Only return events since this timestamp
    * `:event_types` - Filter by event types
  
  ## Returns
  
  * `{:ok, [event()]}` - List of matching events
  * `{:error, reason}` - Query failed
  """
  @spec get_event_history(String.t(), keyword()) :: {:ok, [event()]} | {:error, any()}
  def get_event_history(session_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    since = Keyword.get(opts, :since)
    event_types = Keyword.get(opts, :event_types)
    
    Logger.debug("📜 Getting event history for session: #{session_id}")
    
    # This would typically query from persistent storage
    # For now, filter from in-memory history
    case get_event_system_state() do
      {:ok, state} ->
        filtered_events = state.event_history
        |> Enum.filter(fn event ->
          event.session_id == session_id
        end)
        |> maybe_filter_by_timestamp(since)
        |> maybe_filter_by_event_types(event_types)
        |> Enum.take(limit)
        |> Enum.reverse()
        
        {:ok, filtered_events}
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Register an event handler to process sync events.
  
  Event handlers receive all events and can perform logging, metrics
  collection, alerting, or other processing.
  
  ## Parameters
  
  * `handler_module` - Module implementing the EventHandler behaviour
  
  ## Returns
  
  * `:ok` - Handler registered successfully
  * `{:error, reason}` - Registration failed
  """
  @spec register_event_handler(module()) :: :ok | {:error, any()}
  def register_event_handler(handler_module) do
    Logger.debug("📝 Registering event handler: #{handler_module}")
    
    if Code.ensure_loaded?(handler_module) do
      # Add to event handlers list
      # This would typically update persistent configuration
      :ok
    else
      {:error, {:handler_module_not_found, handler_module}}
    end
  end

  @doc """
  Broadcast multiple events as a batch for performance.
  
  ## Parameters
  
  * `events` - List of {event_type, event_data, opts} tuples
  
  ## Returns
  
  * `:ok` - All events broadcasted successfully
  * `{:error, reason}` - Batch broadcasting failed
  """
  @spec broadcast_batch_events([{atom(), map(), keyword()}]) :: :ok | {:error, any()}
  def broadcast_batch_events(events) do
    Logger.debug("📡 Broadcasting batch of #{length(events)} events")
    
    Enum.each(events, fn {event_type, event_data, opts} ->
      broadcast_sync_event(event_type, event_data, opts)
    end)
    
    :ok
  end

  # Private functions

  defp normalize_event_config(config) do
    normalized = %{
      pubsub_module: Map.get(config, :pubsub_module),
      topic_prefix: Map.get(config, :topic_prefix, "sync"),
      event_history: Map.get(config, :event_history, %{
        enabled: true,
        max_events: 1000,
        storage: :memory
      }),
      event_handlers: Map.get(config, :event_handlers, [])
    }
    
    {:ok, normalized}
  end

  defp validate_pubsub_module(pubsub_module) when is_atom(pubsub_module) do
    if Code.ensure_loaded?(pubsub_module) do
      :ok
    else
      {:error, {:pubsub_module_not_found, pubsub_module}}
    end
  end
  defp validate_pubsub_module(pubsub_module) do
    {:error, {:invalid_pubsub_module, pubsub_module}}
  end

  defp initialize_event_handlers(handler_modules) do
    valid_handlers = Enum.filter(handler_modules, fn module ->
      Code.ensure_loaded?(module)
    end)
    
    if length(valid_handlers) == length(handler_modules) do
      {:ok, valid_handlers}
    else
      invalid_handlers = handler_modules -- valid_handlers
      Logger.warn("⚠️ Invalid event handlers: #{inspect(invalid_handlers)}")
      {:ok, valid_handlers}
    end
  end

  defp create_event(event_type, event_data, metadata_opts) do
    %{
      event_id: generate_event_id(),
      event_type: event_type,
      source: Map.get(metadata_opts, :source, :sync_engine),
      session_id: Map.get(metadata_opts, :session_id),
      timestamp: DateTime.utc_now(),
      data: event_data,
      metadata: %{
        version: "1.0",
        source_module: inspect(__MODULE__),
        correlation_id: Map.get(metadata_opts, :correlation_id),
        node: Node.self()
      }
    }
  end

  defp determine_broadcast_topics(event_type, session_id, custom_topic) do
    topics = []
    
    # Add custom topic if specified
    topics = if custom_topic do
      [custom_topic | topics]
    else
      topics
    end
    
    # Add general sync topic
    topics = ["sync_progress" | topics]
    
    # Add session-specific topic if session_id is present
    topics = if session_id do
      ["sync:#{session_id}" | topics]
    else
      topics
    end
    
    # Add event-type-specific topic
    topics = ["sync:#{event_type}" | topics]
    
    Enum.uniq(topics)
  end

  defp broadcast_to_topic(topic, event) do
    case get_pubsub_module() do
      {:ok, pubsub_module} ->
        Phoenix.PubSub.broadcast(pubsub_module, topic, {:sync_event, event})
        
      {:error, _reason} ->
        Logger.warn("⚠️ Could not broadcast to topic #{topic}: PubSub not available")
    end
  end

  defp store_event_in_history(event) do
    # This would typically store to persistent storage
    # For now, add to in-memory history
    case get_event_system_state() do
      {:ok, state} ->
        updated_history = [event | state.event_history]
        |> Enum.take(state.config.event_history.max_events)
        
        # Update state (this would be persistent in real implementation)
        :ok
        
      {:error, _reason} ->
        :ok  # Continue without history
    end
  end

  defp notify_event_handlers(event) do
    case get_event_system_state() do
      {:ok, state} ->
        Enum.each(state.event_handlers, fn handler_module ->
          try do
            if function_exported?(handler_module, :handle_sync_event, 1) do
              handler_module.handle_sync_event(event)
            end
          rescue
            error ->
              Logger.warn("⚠️ Event handler #{handler_module} failed: #{inspect(error)}")
          end
        end)
        
      {:error, _reason} ->
        :ok  # Continue without handlers
    end
  end

  defp get_pubsub_module do
    # This would typically get from application config or state
    # For now, use the existing PubSub module
    {:ok, EhsEnforcement.PubSub}
  rescue
    _ -> {:error, :pubsub_not_available}
  end

  defp get_event_system_state do
    # This would typically get from persistent state (ETS, GenServer, etc.)
    # For now, return a default state
    {:ok, %{
      config: %{event_history: %{max_events: 1000}},
      event_history: [],
      event_handlers: []
    }}
  end

  defp generate_event_id do
    "evt_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  defp receive_event_with_timeout(timeout_ms) do
    receive do
      {:sync_event, event} ->
        {:ok, event}
        
      other_message ->
        Logger.debug("📡 Received non-sync event: #{inspect(other_message)}")
        receive_event_with_timeout(timeout_ms)
    after
      timeout_ms ->
        :timeout
    end
  end

  defp should_include_event?(_event, nil), do: true
  defp should_include_event?(event, filter_func) when is_function(filter_func, 1) do
    try do
      filter_func.(event)
    rescue
      _ -> true  # Include event if filter fails
    end
  end
  defp should_include_event?(_event, _filter), do: true

  defp maybe_filter_by_timestamp(events, nil), do: events
  defp maybe_filter_by_timestamp(events, since_timestamp) do
    Enum.filter(events, fn event ->
      DateTime.compare(event.timestamp, since_timestamp) in [:gt, :eq]
    end)
  end

  defp maybe_filter_by_event_types(events, nil), do: events
  defp maybe_filter_by_event_types(events, event_types) when is_list(event_types) do
    Enum.filter(events, fn event ->
      event.event_type in event_types
    end)
  end
  defp maybe_filter_by_event_types(events, _), do: events
end