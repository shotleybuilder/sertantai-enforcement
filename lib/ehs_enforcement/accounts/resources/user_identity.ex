defmodule EhsEnforcement.Accounts.UserIdentity do
  @moduledoc """
  UserIdentity resource for OAuth provider identities using Ash Authentication.
  """

  use Ash.Resource,
    domain: EhsEnforcement.Accounts,
    extensions: [AshAuthentication.UserIdentity],
    data_layer: AshPostgres.DataLayer

  postgres do
    table("user_identities")
    repo(EhsEnforcement.Repo)
  end

  user_identity do
    domain EhsEnforcement.Accounts
    user_resource(EhsEnforcement.Accounts.User)
  end
end
