defmodule EhsEnforcement.Repo.Migrations.AddRlsTenantContext do
  @moduledoc """
  Adds PostgreSQL function for setting tenant context in database sessions.

  This migration creates the set_current_org_id() function which is used
  by the JWT authentication plug to set the organization context for
  Row-Level Security (RLS) policies.

  ## Usage

  The JwtAuth plug calls this function after verifying the JWT:
  ```sql
  SELECT set_current_org_id('550e8400-e29b-41d4-a716-446655440000'::uuid);
  ```

  ## RLS Configuration (Future)

  Future migrations will add RLS policies for user-specific features:
  - user_bookmarks
  - user_annotations
  - user_alerts
  - user_reports

  ## Public Data Tables

  The core enforcement tables (cases, notices, offenders, legislation, agencies)
  are PUBLIC and do NOT have RLS enabled. All authenticated users can read this data.
  """

  use Ecto.Migration

  def up do
    # Create function to set organization ID in session variable
    # This is used by RLS policies to filter data
    execute """
    CREATE OR REPLACE FUNCTION set_current_org_id(org_id uuid)
    RETURNS void AS $$
    BEGIN
      -- Set the current organization ID in the session
      -- Use 'false' as third parameter to persist for the entire transaction
      PERFORM set_config('app.current_org_id', org_id::text, false);
    END;
    $$ LANGUAGE plpgsql;
    """

    # Create function to get current organization ID from session
    # Useful for debugging and verification
    execute """
    CREATE OR REPLACE FUNCTION get_current_org_id()
    RETURNS uuid AS $$
    BEGIN
      -- Get the current organization ID from session
      -- Returns NULL if not set
      RETURN current_setting('app.current_org_id', true)::uuid;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Create helper function to check if RLS context is set
    execute """
    CREATE OR REPLACE FUNCTION has_org_context()
    RETURNS boolean AS $$
    BEGIN
      RETURN current_setting('app.current_org_id', true) IS NOT NULL;
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  def down do
    execute "DROP FUNCTION IF EXISTS has_org_context();"
    execute "DROP FUNCTION IF EXISTS get_current_org_id();"
    execute "DROP FUNCTION IF EXISTS set_current_org_id(uuid);"
  end
end
