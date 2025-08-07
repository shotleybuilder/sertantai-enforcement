defmodule EhsEnforcement.Sync.EventBroadcaster do
  @moduledoc """
  Event broadcasting service for sync operations.
  
  Provides a simple interface for broadcasting sync-related events via PubSub.
  This module acts as a wrapper around the main EhsEnforcement.PubSub module,
  specifically tailored for sync operation events.
  """


  @doc """
  Broadcasts a sync event to subscribers.
  
  ## Parameters
  
  - `event_type` - The type of sync event (e.g., :record_created, :record_updated, :record_exists)
  - `event_data` - Map containing event details
  - `opts` - Keyword list of options, including:
    - `topic` - The PubSub topic to broadcast to (defaults to "sync_events")
  
  ## Examples
  
      EventBroadcaster.broadcast(:record_created, %{
        resource_type: "Case",
        record_data: case_data,
        session_id: session_id
      }, topic: "sync_records")
      
      EventBroadcaster.broadcast(:record_updated, %{
        resource_type: "Offender", 
        record_data: offender_data
      })
  """
  def broadcast(event_type, event_data, opts \\ []) do
    topic = Keyword.get(opts, :topic, "sync_events")
    
    # Create a message in the expected format
    message = %{
      event: event_type,
      data: event_data,
      timestamp: DateTime.utc_now()
    }
    
    # Use Phoenix.PubSub directly for sync events (simpler than full Ash notification)
    Phoenix.PubSub.broadcast(EhsEnforcement.PubSub, topic, message)
  end
end