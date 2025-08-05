defmodule EhsEnforcement.Sync.EventBroadcaster do
  @moduledoc """
  Universal PubSub event broadcasting system for sync operations.
  Designed with package-ready architecture for future extraction.
  
  This module provides a generic event broadcasting system that can work
  with any resource type and any Phoenix application using PubSub.
  """
  
  alias Phoenix.PubSub
  require Logger

  @default_pubsub_module EhsEnforcement.PubSub
  @default_topic_prefix "sync"
  
  @doc """
  Broadcast a sync event to the appropriate topic.
  
  ## Parameters
  
  * `event_type` - Atom representing the type of event
  * `data` - Map containing event data
  * `opts` - Options for customizing broadcast behavior
  
  ## Options
  
  * `:topic` - Custom topic (overrides default topic generation)
  * `:topic_prefix` - Prefix for topic generation (default: "sync")
  * `:pubsub_module` - PubSub module to use (default: EhsEnforcement.PubSub)
  * `:session_id` - Session ID for scoped broadcasting
  * `:resource_module` - Resource module for resource-specific topics
  * `:include_metadata` - Whether to include broadcast metadata (default: true)
  
  ## Examples
  
      # Basic sync event
      EventBroadcaster.broadcast(:sync_started, %{sync_type: :cases})
      
      # Session-specific event
      EventBroadcaster.broadcast(:sync_progress, %{processed: 100}, session_id: "session-123")
      
      # Resource-specific event
      EventBroadcaster.broadcast(:record_created, %{id: "abc"}, resource_module: MyApp.Cases)
      
      # Custom topic
      EventBroadcaster.broadcast(:custom_event, %{data: "test"}, topic: "custom:topic")
  """
  def broadcast(event_type, data, opts \\ []) do
    topic = determine_topic(event_type, data, opts)
    pubsub_module = Keyword.get(opts, :pubsub_module, @default_pubsub_module)
    include_metadata = Keyword.get(opts, :include_metadata, true)
    
    event_data = if include_metadata do
      data
      |> Map.put(:event_type, event_type)
      |> Map.put(:timestamp, DateTime.utc_now())
      |> Map.put(:topic, topic)
    else
      data
    end
    
    Logger.debug("Broadcasting #{event_type} to topic: #{topic}")
    
    case PubSub.broadcast(pubsub_module, topic, {event_type, event_data}) do
      :ok -> 
        {:ok, %{topic: topic, event_type: event_type, data: event_data}}
      {:error, reason} -> 
        Logger.error("Failed to broadcast #{event_type} to #{topic}: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Broadcast a session-specific sync event.
  Convenience function for session-scoped events.
  """
  def broadcast_session_event(session_id, event_type, data, opts \\ []) do
    opts = Keyword.put(opts, :session_id, session_id)
    broadcast(event_type, Map.put(data, :session_id, session_id), opts)
  end
  
  @doc """
  Broadcast a resource-specific sync event.
  Convenience function for resource-scoped events.
  """
  def broadcast_resource_event(resource_module, event_type, data, opts \\ []) do
    opts = Keyword.put(opts, :resource_module, resource_module)
    broadcast(event_type, Map.put(data, :resource_module, resource_module), opts)
  end
  
  @doc """
  Broadcast a batch progress event with standardized structure.
  """
  def broadcast_batch_progress(session_id, batch_data, opts \\ []) do
    standardized_data = %{
      session_id: session_id,
      batch_number: Map.get(batch_data, :batch_number),
      batch_size: Map.get(batch_data, :batch_size),
      records_processed: Map.get(batch_data, :records_processed, 0),
      records_created: Map.get(batch_data, :records_created, 0),
      records_updated: Map.get(batch_data, :records_updated, 0),
      records_existing: Map.get(batch_data, :records_existing, 0),
      records_failed: Map.get(batch_data, :records_failed, 0),
      status: Map.get(batch_data, :status, :processing)
    }
    
    broadcast_session_event(session_id, :batch_progress, standardized_data, opts)
  end
  
  @doc """
  Broadcast a sync completion event with final statistics.
  """
  def broadcast_sync_completion(session_id, final_stats, opts \\ []) do
    standardized_data = %{
      session_id: session_id,
      status: :completed,
      total_processed: Map.get(final_stats, :total_processed, 0),
      total_created: Map.get(final_stats, :total_created, 0),
      total_updated: Map.get(final_stats, :total_updated, 0),
      total_existing: Map.get(final_stats, :total_existing, 0),
      total_failed: Map.get(final_stats, :total_failed, 0),
      duration_seconds: Map.get(final_stats, :duration_seconds),
      records_per_second: Map.get(final_stats, :records_per_second),
      sync_type: Map.get(final_stats, :sync_type)
    }
    
    broadcast_session_event(session_id, :sync_completed, standardized_data, opts)
  end
  
  @doc """
  Broadcast a sync error event with error details.
  """
  def broadcast_sync_error(session_id, error_info, opts \\ []) do
    error_data = %{
      session_id: session_id,
      status: :failed,
      error_message: format_error_message(error_info),
      error_details: format_error_details(error_info),
      sync_type: Map.get(error_info, :sync_type)
    }
    
    broadcast_session_event(session_id, :sync_error, error_data, opts)
  end
  
  @doc """
  Subscribe to sync events for a specific topic pattern.
  
  ## Examples
  
      # Subscribe to all sync events
      EventBroadcaster.subscribe("sync:*")
      
      # Subscribe to session-specific events
      EventBroadcaster.subscribe("sync:session:session-123")
      
      # Subscribe to resource-specific events  
      EventBroadcaster.subscribe("sync:resource:MyApp.Cases")
  """
  def subscribe(topic_pattern, opts \\ []) do
    pubsub_module = Keyword.get(opts, :pubsub_module, @default_pubsub_module)
    
    case PubSub.subscribe(pubsub_module, topic_pattern) do
      :ok -> 
        Logger.debug("Subscribed to topic pattern: #{topic_pattern}")
        {:ok, topic_pattern}
      {:error, reason} -> 
        Logger.error("Failed to subscribe to #{topic_pattern}: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Unsubscribe from sync events for a specific topic pattern.
  """
  def unsubscribe(topic_pattern, opts \\ []) do
    pubsub_module = Keyword.get(opts, :pubsub_module, @default_pubsub_module)
    
    case PubSub.unsubscribe(pubsub_module, topic_pattern) do
      :ok -> 
        Logger.debug("Unsubscribed from topic pattern: #{topic_pattern}")
        {:ok, topic_pattern}
      {:error, reason} -> 
        Logger.error("Failed to unsubscribe from #{topic_pattern}: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Private functions
  
  defp determine_topic(event_type, data, opts) do
    case Keyword.get(opts, :topic) do
      nil -> generate_topic(event_type, data, opts)
      custom_topic -> custom_topic
    end
  end
  
  defp generate_topic(event_type, data, opts) do
    topic_prefix = Keyword.get(opts, :topic_prefix, @default_topic_prefix)
    
    cond do
      session_id = Keyword.get(opts, :session_id) ->
        "#{topic_prefix}:session:#{session_id}"
        
      resource_module = Keyword.get(opts, :resource_module) ->
        resource_name = resource_module |> Module.split() |> List.last() |> Macro.underscore()
        "#{topic_prefix}:resource:#{resource_name}"
        
      sync_type = Map.get(data, :sync_type) ->
        "#{topic_prefix}:type:#{sync_type}"
        
      true ->
        "#{topic_prefix}:global"
    end
  end
  
  defp format_error_message(error_info) when is_map(error_info) do
    case error_info do
      %{message: message} -> message
      %{error: error} when is_binary(error) -> error
      %{error: error} -> inspect(error)
      _ -> "Unknown sync error"
    end
  end
  defp format_error_message(error) when is_binary(error), do: error
  defp format_error_message(error), do: inspect(error)
  
  defp format_error_details(error_info) when is_map(error_info) do
    error_info
    |> Map.drop([:message, :error])
    |> Map.put(:error_type, determine_error_type(error_info))
  end
  defp format_error_details(error), do: %{raw_error: inspect(error)}
  
  defp determine_error_type(error_info) do
    cond do
      Map.has_key?(error_info, :validation_errors) -> :validation_error
      Map.has_key?(error_info, :network_error) -> :network_error
      Map.has_key?(error_info, :database_error) -> :database_error
      Map.has_key?(error_info, :api_error) -> :api_error
      true -> :unknown_error
    end
  end
end