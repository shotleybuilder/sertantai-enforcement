defmodule EhsEnforcement.Repo.Migrations.RemoveInsertedAtFromTokens do
  @moduledoc """
  Removes the inserted_at column from tokens table.

  ## Background

  The original migration created tokens with timestamps(updated_at: false),
  which creates only inserted_at. Ash TokenResource expects created_at instead.

  Production has:
  - inserted_at (from original migration - NOT NULL, no default)
  - created_at (from our fix migration - NOT NULL with default)
  - updated_at (from our fix migration - NOT NULL with default)

  Ash only uses created_at and updated_at, so inserted_at must be removed.

  Token revocation fails with "null value in column inserted_at" because
  Ash doesn't populate this column.
  """

  use Ecto.Migration

  def up do
    # Remove inserted_at column if it exists
    alter table(:tokens) do
      remove_if_exists :inserted_at, :utc_datetime_usec
    end
  end

  def down do
    # One-way migration - don't recreate inserted_at
    :ok
  end
end
