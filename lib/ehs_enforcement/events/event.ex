defmodule EhsEnforcement.Events.Event do
  @moduledoc """
  Centralized event log resource for tracking all enforcement data changes.
  Provides automatic audit trail and replay functionality for HSE case scraping operations.
  """

  use Ash.Resource,
    domain: EhsEnforcement.Events,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventLog]

  postgres do
    table("events")
    repo(EhsEnforcement.Repo)
  end

  event_log do
    # Required: Module that implements clear_records! callback for replay functionality
    clear_records_for_replay(EhsEnforcement.Events.ClearAllRecords)

    # Use regular UUID for now - can upgrade to UUIDv7 later when extension is available
    # primary_key_type Ash.Type.UUIDv7
  end
end
