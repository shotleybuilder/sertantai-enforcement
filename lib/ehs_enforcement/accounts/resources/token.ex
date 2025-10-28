defmodule EhsEnforcement.Accounts.Token do
  @moduledoc """
  Token resource for Ash Authentication.
  Stores authentication tokens and session management.
  """

  use Ash.Resource,
    domain: EhsEnforcement.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table("tokens")
    repo(EhsEnforcement.Repo)
  end

  token do
    domain EhsEnforcement.Accounts
  end
end
