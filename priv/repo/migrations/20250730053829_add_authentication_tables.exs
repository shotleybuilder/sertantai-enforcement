defmodule EhsEnforcement.Repo.Migrations.AddAuthenticationTables do
  use Ecto.Migration

  def change do
    # Create users table for authentication
    create table("users", primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :github_id, :text
      add :github_login, :text
      add :name, :text
      add :avatar_url, :text
      add :github_url, :text
      add :is_admin, :boolean, default: false, null: false
      add :admin_checked_at, :utc_datetime_usec
      add :last_login_at, :utc_datetime_usec
      add :primary_provider, :text, default: "github", null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index("users", [:email])
    create index("users", [:github_id])
    create index("users", [:github_login])
    create index("users", [:is_admin])

    # Create tokens table for session management
    create table("tokens", primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :extra_data, :map
      add :purpose, :text, null: false
      add :expires_at, :utc_datetime
      add :subject, :text, null: false
      add :jti, :text, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index("tokens", [:jti])
    create index("tokens", [:purpose])
    create index("tokens", [:expires_at])

    # Create user_identities table for OAuth providers
    create table("user_identities", primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references("users", type: :binary_id, on_delete: :delete_all), null: false
      add :uid, :text, null: false
      add :strategy, :text, null: false
      add :access_token, :text
      add :refresh_token, :text
      add :user_info, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index("user_identities", [:uid, :strategy])
    create index("user_identities", [:user_id])
    create index("user_identities", [:strategy])
  end
end
