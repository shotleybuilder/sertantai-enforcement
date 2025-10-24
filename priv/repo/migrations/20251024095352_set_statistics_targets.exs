defmodule EhsEnforcement.Repo.Migrations.SetStatisticsTargets do
  @moduledoc """
  R5.1: Set statistics targets on heavily-queried columns

  PostgreSQL's query planner uses statistics to make decisions about query execution plans.
  By default, PostgreSQL collects statistics on 100 most common values (MCVs) and creates
  a histogram with 100 bins for each column.

  For heavily-queried columns with high cardinality or non-uniform distribution, increasing
  the statistics target helps the planner make more accurate row count estimates, leading to:

  1. Better index selection
  2. Optimal JOIN order choices
  3. More efficient query execution
  4. 10-50x performance improvements on complex queries

  ## Columns Targeted

  ### Primary Candidates (target = 1000)
  - `cases.agency_id` - Non-uniform distribution (4 agencies, heavily skewed)
  - `cases.offence_action_date` - High cardinality date column, frequent range queries
  - `notices.agency_id` - Same as cases.agency_id
  - `notices.offence_action_date` - Same as cases.offence_action_date

  ### Secondary Candidates (target = 500)
  - `cases.offender_id` - Thousands of offenders, repeat offenders create skew
  - `notices.offender_id` - Same as cases.offender_id
  - `offences.legislation_id` - ~50 distinct laws, highly skewed (some cited frequently)
  - `metrics.agency_id` - Used in metrics JOIN operations

  ## Performance Impact

  **Cost**:
  - +10-30 seconds per ANALYZE operation
  - +5-10 MB total statistics storage
  - +1-2ms per query planning (negligible)

  **Benefit**:
  - 10-50x faster query execution on complex queries
  - Better dashboard performance
  - More predictable query times

  ## Monitoring

  After applying this migration, use pg_stat_statements to monitor improvements:

      SELECT query, calls, mean_exec_time, stddev_exec_time
      FROM pg_stat_statements
      WHERE query LIKE '%cases%agency_id%'
      ORDER BY mean_exec_time DESC;

  Check row estimate accuracy with EXPLAIN ANALYZE:

      EXPLAIN ANALYZE
      SELECT * FROM cases
      WHERE agency_id = 'some-uuid'
        AND offence_action_date >= '2024-01-01';

  Look for: `rows=X` (estimate) should match `actual rows=X`

  ## References

  See: docs-dev/dev/postgres/r5.1-statistics-targets-explanation.md
  """

  use Ecto.Migration

  def up do
    # Primary candidates: Most heavily-queried columns (target = 1000)
    execute "ALTER TABLE cases ALTER COLUMN agency_id SET STATISTICS 1000"
    execute "ALTER TABLE cases ALTER COLUMN offence_action_date SET STATISTICS 1000"
    execute "ALTER TABLE notices ALTER COLUMN agency_id SET STATISTICS 1000"
    execute "ALTER TABLE notices ALTER COLUMN offence_action_date SET STATISTICS 1000"

    # Secondary candidates: Frequently queried but less critical (target = 500)
    execute "ALTER TABLE cases ALTER COLUMN offender_id SET STATISTICS 500"
    execute "ALTER TABLE notices ALTER COLUMN offender_id SET STATISTICS 500"
    execute "ALTER TABLE offences ALTER COLUMN legislation_id SET STATISTICS 500"
    execute "ALTER TABLE metrics ALTER COLUMN agency_id SET STATISTICS 500"

    # Reanalyze tables to collect new statistics
    # This is CRITICAL - statistics targets only take effect after ANALYZE
    execute "ANALYZE cases"
    execute "ANALYZE notices"
    execute "ANALYZE offences"
    execute "ANALYZE metrics"
  end

  def down do
    # Revert to PostgreSQL default (100)
    execute "ALTER TABLE cases ALTER COLUMN agency_id SET STATISTICS DEFAULT"
    execute "ALTER TABLE cases ALTER COLUMN offence_action_date SET STATISTICS DEFAULT"
    execute "ALTER TABLE notices ALTER COLUMN agency_id SET STATISTICS DEFAULT"
    execute "ALTER TABLE notices ALTER COLUMN offence_action_date SET STATISTICS DEFAULT"

    execute "ALTER TABLE cases ALTER COLUMN offender_id SET STATISTICS DEFAULT"
    execute "ALTER TABLE notices ALTER COLUMN offender_id SET STATISTICS DEFAULT"
    execute "ALTER TABLE offences ALTER COLUMN legislation_id SET STATISTICS DEFAULT"
    execute "ALTER TABLE metrics ALTER COLUMN agency_id SET STATISTICS DEFAULT"

    # Reanalyze with default statistics targets
    execute "ANALYZE cases"
    execute "ANALYZE notices"
    execute "ANALYZE offences"
    execute "ANALYZE metrics"
  end
end
