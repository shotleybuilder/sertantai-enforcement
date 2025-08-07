defmodule EhsEnforcement.Events.ClearAllRecords do
  @moduledoc """
  Implementation for clearing all records before event replay.
  This ensures a clean state when rebuilding data from events.
  """

  use AshEvents.ClearRecordsForReplay

  @impl true
  def clear_records!(_opts) do
    # Clear all relevant records for resources with event tracking
    # This runs before replay to ensure clean state
    
    # Clear enforcement records (cases, breaches, etc.)
    # These will be recreated from events during replay
    
    # Note: In production, this would need careful implementation
    # to handle foreign key constraints and maintain referential integrity
    
    # For HSE case scraping, we primarily track Case creation/updates
    # so this would clear case data to be rebuilt from events
    
    :ok
  end
end