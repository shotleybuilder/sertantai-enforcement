defmodule EhsEnforcement.PubSub do
  @moduledoc """
  PubSub wrapper module for Ash notifications.
  
  This module provides the interface that Ash.Notifier.PubSub expects,
  wrapping the Phoenix.PubSub functionality. It handles broadcasting events
  when Ash resources are created, updated, or destroyed.
  
  ## Integration with Ash
  
  Ash resources use this module through the `pub_sub` configuration:
  
      pub_sub do
        module(EhsEnforcement.PubSub)
        prefix("case")
        
        publish(:create, ["created", :id])
        publish(:update, ["updated", :id])
      end
  
  ## Topic Structure
  
  Topics are constructed as: `prefix:event:id` or `prefix:event`
  
  For example:
  - `case:created:123e4567-e89b-12d3-a456-426614174000`
  - `case:updated:123e4567-e89b-12d3-a456-426614174000`
  - `case:scraped:updated` (scraping workflow - broadcast without ID)
  - `case:synced` (Airtable sync - broadcast without ID)
  
  ## Subscribing to Events
  
  In LiveViews or processes:
  
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case:created")
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case:scraped:updated")
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case:synced:specific-id")
  """
  
  @doc """
  Broadcast a message to all subscribers of a topic.
  
  This function is called automatically by Ash.Notifier.PubSub when resources with
  pub_sub configurations are created, updated, or destroyed.
  
  ## Parameters
  
  - `topic` - The full topic string (e.g., "case:created:uuid")
  - `event` - The event name as a string (e.g., "create", "update", "sync")
  - `notification` - An `Ash.Notifier.Notification` struct containing:
    - `:resource` - The Ash resource module
    - `:action` - The action that was performed
    - `:data` - The resource data after the action
    - `:changeset` - The changeset that was applied (if applicable)
    - `:metadata` - Any additional metadata
  
  ## Return Value
  
  Returns `:ok` or `{:error, reason}` from Phoenix.PubSub.broadcast/3
  
  ## Examples
  
      # This is called automatically by Ash, but the equivalent would be:
      notification = %Ash.Notifier.Notification{
        resource: EhsEnforcement.Enforcement.Case,
        action: :create,
        data: %Case{id: "123", regulator_id: "4823792", ...}
      }
      
      broadcast("case:created:123", "create", notification)
  """
  def broadcast(topic, event, notification) do
    # Phoenix.PubSub expects a specific format for the broadcast
    # We wrap the event and notification in a Phoenix.Socket.Broadcast struct
    # This ensures compatibility with Phoenix.LiveView's handle_info callbacks
    message = %Phoenix.Socket.Broadcast{
      topic: topic,
      event: event,
      payload: notification
    }
    
    Phoenix.PubSub.broadcast(EhsEnforcement.PubSub, topic, message)
  end
  
  @doc """
  Subscribe to a PubSub topic.
  
  This is a convenience wrapper around Phoenix.PubSub.subscribe/2.
  
  ## Parameters
  
  - `topic` - The topic to subscribe to (e.g., "case:created", "case:scraped:updated", "case:synced")
  
  ## Examples
  
      # In a LiveView mount callback
      EhsEnforcement.PubSub.subscribe("case:created")
      EhsEnforcement.PubSub.subscribe("case:scraped:updated")
      EhsEnforcement.PubSub.subscribe("case:synced")
  """
  def subscribe(topic) do
    Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, topic)
  end
  
  @doc """
  Unsubscribe from a PubSub topic.
  
  This is a convenience wrapper around Phoenix.PubSub.unsubscribe/2.
  
  ## Parameters
  
  - `topic` - The topic to unsubscribe from
  
  ## Examples
  
      EhsEnforcement.PubSub.unsubscribe("case:created")
  """
  def unsubscribe(topic) do
    Phoenix.PubSub.unsubscribe(EhsEnforcement.PubSub, topic)
  end
end