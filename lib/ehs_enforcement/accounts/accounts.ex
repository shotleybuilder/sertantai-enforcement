defmodule EhsEnforcement.Accounts do
  @moduledoc """
  The Accounts domain handles user authentication and authorization.
  """

  use Ash.Domain

  resources do
    resource(EhsEnforcement.Accounts.User)
    resource(EhsEnforcement.Accounts.Token)
    resource(EhsEnforcement.Accounts.UserIdentity)
  end
end
