defmodule EhsEnforcement.Repo.Migrations.AddUpdatedAtToTokens do
  @moduledoc """
  Adds the missing updated_at column to the tokens table.

  ## Background

  The initial authentication migration (20250730053829) created the tokens table
  with `timestamps(updated_at: false)`, omitting the updated_at column.

  Later that same day, Ash codegen generated migration 20250730182857 which would
  create the table WITH updated_at, but used `create_if_not_exists`. This meant:
  - In dev: Table was dropped/recreated correctly with updated_at
  - In production: Existing table was left unchanged, missing updated_at

  This migration fixes production by adding the missing column.

  ## Impact

  Without this column, token revocation during logout fails in production,
  causing internal server errors.
  """

  use Ecto.Migration

  def up do
    # Add updated_at column to tokens table if it doesn't exist
    alter table(:tokens) do
      add_if_not_exists :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    # Also ensure created_at exists (should already exist, but being thorough)
    alter table(:tokens) do
      add_if_not_exists :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end
  end

  def down do
    # In down migration, we could remove the columns, but since they're
    # expected by the Ash resource, we keep them (no-op down migration)
    :ok
  end
end
