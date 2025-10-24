defmodule EhsEnforcement.Repo.Migrations.EnablePgStatStatements do
  @moduledoc """
  R7.1: Enable pg_stat_statements extension for query performance monitoring

  The pg_stat_statements extension tracks execution statistics for all SQL statements
  executed by the server. This is essential for:

  1. Identifying slow queries in production
  2. Monitoring query performance trends
  3. Optimizing database performance
  4. Debugging performance issues

  ## Configuration Required

  After enabling this extension, you need to add to postgresql.conf:

      shared_preload_libraries = 'pg_stat_statements'
      pg_stat_statements.max = 10000
      pg_stat_statements.track = all

  Then restart PostgreSQL and run this migration.

  ## Usage

  Query slow statements with:

      SELECT
        query,
        calls,
        total_exec_time,
        mean_exec_time,
        stddev_exec_time,
        rows
      FROM pg_stat_statements
      ORDER BY mean_exec_time DESC
      LIMIT 20;

  Reset statistics with:

      SELECT pg_stat_statements_reset();
  """

  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pg_stat_statements"
  end

  def down do
    execute "DROP EXTENSION IF EXISTS pg_stat_statements"
  end
end
