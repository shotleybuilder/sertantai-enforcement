defmodule EhsEnforcement.Repo.Migrations.FixTokensPrimaryKey do
  @moduledoc """
  Fixes the tokens table primary key to match Ash resource expectations.

  ## Background

  Migration 20250730053829 created tokens table with:
  - Primary key: id (binary_id)
  - jti: unique indexed column

  Migration 20250730182857 (Ash codegen) expected:
  - Primary key: jti (text)
  - No id column

  In dev, the table was recreated correctly. In production, it kept the old
  structure with id as primary key. This causes token revocation to fail
  because Ash tries to insert records without an id.

  This migration converts production to match dev/Ash expectations.
  """

  use Ecto.Migration

  def up do
    # Check if id column exists (production) vs jti primary key (dev)
    # Only run changes if we're in the "old" schema state

    # Drop the old primary key constraint on id (if it exists)
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'tokens_pkey'
        AND conrelid = 'tokens'::regclass
        AND conkey = ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid = 'tokens'::regclass AND attname = 'id')]
      ) THEN
        ALTER TABLE tokens DROP CONSTRAINT tokens_pkey;
      END IF;
    END
    $$;
    """

    # Drop the id column if it exists
    alter table(:tokens) do
      remove_if_exists :id, :binary_id
    end

    # Drop the unique index on jti if it exists (we'll replace with primary key)
    drop_if_exists unique_index(:tokens, [:jti])

    # Make jti the primary key
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'tokens_pkey'
        AND conrelid = 'tokens'::regclass
      ) THEN
        ALTER TABLE tokens ADD PRIMARY KEY (jti);
      END IF;
    END
    $$;
    """
  end

  def down do
    # This is a one-way migration - reverting would break Ash resource
    # If you need to revert, you should recreate the tokens table from scratch
    :ok
  end
end
