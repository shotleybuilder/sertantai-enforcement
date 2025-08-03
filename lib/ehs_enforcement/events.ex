defmodule EhsEnforcement.Events do
  @moduledoc """
  Domain for event tracking and audit trail functionality.
  Handles automatic logging of enforcement data changes for compliance and debugging.
  """

  use Ash.Domain,
    validate_config_inclusion?: false

  resources do
    resource EhsEnforcement.Events.Event
  end
end