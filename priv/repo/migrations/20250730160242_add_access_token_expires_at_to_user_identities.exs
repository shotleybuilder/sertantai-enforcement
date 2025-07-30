defmodule EhsEnforcement.Repo.Migrations.AddAccessTokenExpiresAtToUserIdentities do
  use Ecto.Migration

  def change do
    alter table("user_identities") do
      add :access_token_expires_at, :utc_datetime
    end
  end
end
