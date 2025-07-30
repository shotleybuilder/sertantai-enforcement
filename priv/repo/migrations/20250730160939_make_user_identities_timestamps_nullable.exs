defmodule EhsEnforcement.Repo.Migrations.MakeUserIdentitiesTimestampsNullable do
  use Ecto.Migration

  def change do
    alter table("user_identities") do
      modify :inserted_at, :utc_datetime_usec, null: true
      modify :updated_at, :utc_datetime_usec, null: true
    end
  end
end
