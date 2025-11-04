defmodule EhsEnforcement.Enforcement.Metrics do
  @moduledoc """
  Cached dashboard metrics for performance optimization.

  Stores pre-computed statistics to avoid real-time calculations on dashboard page loads.
  Metrics are refreshed manually via admin interface or scheduled after scraping operations.
  """

  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table("metrics")
    repo(EhsEnforcement.Repo)

    custom_indexes do
      # R2.1: Missing foreign key indexes for JOIN performance
      # These indexes dramatically improve query performance when joining metrics
      # with agencies, offenders, and legislation tables
      index([:agency_id], name: "metrics_agency_id_idx")
      index([:offender_id], name: "metrics_offender_id_idx")
      index([:legislation_id], name: "metrics_legislation_id_idx")
    end
  end

  pub_sub do
    module(EhsEnforcement.PubSub)
    prefix("metrics")

    # Broadcast when metrics are refreshed
    publish(:refresh, ["refreshed"])
  end

  attributes do
    # Primary key and timestamps
    uuid_primary_key(:id)
    timestamps()

    # Time periods for the metrics
    attribute :period, :atom do
      allow_nil?(false)
      constraints(one_of: [:week, :month, :year])
      description "Time period for the metrics (week, month, or year)"
    end

    attribute :period_label, :string do
      allow_nil?(false)
      description "Human readable period label (e.g., 'Last 30 Days')"
    end

    attribute :days_ago, :integer do
      allow_nil?(false)
      description "Number of days back from today for the period"
    end

    # Core counts
    attribute :recent_cases_count, :integer do
      allow_nil?(false)
      default(0)
      description "Number of cases within the time period"
    end

    attribute :recent_notices_count, :integer do
      allow_nil?(false)
      default(0)
      description "Number of notices within the time period"
    end

    attribute :total_cases_count, :integer do
      allow_nil?(false)
      default(0)
      description "Total number of cases (all time)"
    end

    attribute :total_notices_count, :integer do
      allow_nil?(false)
      default(0)
      description "Total number of notices (all time)"
    end

    # Financial metrics
    attribute :total_fines_amount, :decimal do
      allow_nil?(false)
      default(Decimal.new(0))
      description "Total fines from cases within the time period"
    end

    # Agency metrics
    attribute :active_agencies_count, :integer do
      allow_nil?(false)
      default(0)
      description "Number of enabled agencies"
    end

    # Agency statistics as JSON
    attribute :agency_stats, :map do
      allow_nil?(false)
      default(%{})
      description "Per-agency statistics with enhanced breakdown for dashboard dropdown filtering"
    end

    # Filter dimensions for multi-dimensional metrics
    attribute :agency_id, :uuid do
      allow_nil?(true)
      description "Agency filter (NULL = all agencies combined)"
    end

    attribute :record_type, :atom do
      allow_nil?(true)
      constraints(one_of: [:case, :notice])
      description "Record type filter (NULL = combined cases + notices)"
    end

    # Future filter dimensions
    attribute :offender_id, :uuid do
      allow_nil?(true)
      description "Offender filter for future offender-specific metrics (currently unused)"
    end

    attribute :legislation_id, :uuid do
      allow_nil?(true)
      description "Legislation filter for future legislation-specific metrics (currently unused)"
    end

    # Additional aggregate statistics
    attribute :total_offences_count, :integer do
      allow_nil?(false)
      default(0)
      description "Total number of offences within the time period"
    end

    attribute :total_costs_amount, :decimal do
      allow_nil?(false)
      default(Decimal.new(0))
      description "Total costs awarded in cases within the time period"
    end

    # Breakdown statistics (JSONB)
    attribute :offender_breakdown, :map do
      allow_nil?(false)
      default(%{})
      description "Top offenders with statistics (offender_id => %{name, cases, fines, ...})"
    end

    attribute :legislation_breakdown, :map do
      allow_nil?(false)
      default(%{})

      description "Top breached legislation with counts (legislation_id => %{title, breach_count, ...})"
    end

    # Recent activity materialization
    attribute :recent_activity, {:array, :map} do
      allow_nil?(false)
      default([])

      description "Top 100 recent cases/notices matching this filter combination for instant display"
    end

    # Metadata
    attribute :calculated_at, :utc_datetime_usec do
      allow_nil?(false)
      description "When these metrics were calculated"
    end

    attribute :calculated_by, :atom do
      allow_nil?(false)
      constraints(one_of: [:admin, :automation])
      description "Whether metrics were calculated manually by admin or via automation"
    end

    attribute :cutoff_date, :date do
      allow_nil?(false)
      description "The cutoff date used for recent data filtering"
    end
  end

  identities do
    identity(
      :unique_filter_combination,
      [
        :period,
        :agency_id,
        :record_type,
        :offender_id,
        :legislation_id
      ],
      description: "Ensure each combination of filter parameters is unique"
    )
  end

  actions do
    defaults([:read, :destroy])

    read :get_current do
      description "Get the most recent metrics for each time period"

      prepare(fn query, _context ->
        # Get the latest metrics for each period
        query
        |> Ash.Query.sort(calculated_at: :desc)
      end)
    end

    create :refresh do
      description "Refresh metrics for a specific filter combination"

      # Accept all attributes for manual creation during refresh
      accept([
        # Time period configuration
        :period,
        :period_label,
        :days_ago,
        :cutoff_date,

        # Filter dimensions
        :agency_id,
        :record_type,
        :offender_id,
        :legislation_id,

        # Aggregate counts
        :recent_cases_count,
        :recent_notices_count,
        :total_cases_count,
        :total_notices_count,
        :total_offences_count,

        # Financial aggregates
        :total_fines_amount,
        :total_costs_amount,

        # Agency and breakdown data
        :active_agencies_count,
        :agency_stats,
        :offender_breakdown,
        :legislation_breakdown,

        # Recent activity materialization
        :recent_activity,

        # Metadata
        :calculated_at,
        :calculated_by
      ])
    end

    create :scheduled_refresh do
      description "Scheduled refresh of dashboard metrics after weekly scraping completion"

      change(fn changeset, context ->
        case __MODULE__.refresh_all_metrics(:automation) do
          {:ok, results} ->
            # Success - return changeset with success message
            Ash.Changeset.add_error(changeset,
              field: :refresh_result,
              message:
                "Scheduled metric refresh completed successfully: #{length(results)} periods refreshed"
            )

          {:error, error} ->
            # Error during refresh
            Ash.Changeset.add_error(changeset,
              field: :refresh_error,
              message: "Scheduled metric refresh failed: #{inspect(error)}"
            )
        end
      end)
    end
  end

  oban do
    triggers do
      trigger :weekly_metrics_refresh do
        action :scheduled_refresh

        # Weekly on Sunday at 4 AM (after the weekly deep scrape at 3 AM)
        scheduler_cron "0 4 * * 0"
        max_attempts 3
        queue :metrics
        worker_module_name EhsEnforcement.Enforcement.Metrics.AshOban.Worker.WeeklyMetricsRefresh

        scheduler_module_name EhsEnforcement.Enforcement.Metrics.AshOban.Scheduler.WeeklyMetricsRefresh
      end
    end
  end

  code_interface do
    define(:get_current_metrics, action: :get_current)
    define(:refresh_metrics, action: :refresh)
    define(:scheduled_refresh_metrics, action: :scheduled_refresh)
  end

  @doc """
  Refresh all dashboard metrics by recalculating from current data.

  This function generates multi-dimensional metrics:
  - Tier 1: 3 rows (all agencies combined, one per time period)
  - Tier 2: N × 3 rows (per-agency, one per time period × number of agencies)

  ## Implementation
  1. Clears existing metrics
  2. Generates Tier 1 combinations (period × all agencies)
  3. Generates Tier 2 combinations (period × agency_id)
  4. Broadcasts refresh notification via PubSub

  ## Parameters
  - `calculated_by` (optional): :admin or :automation (defaults to :admin)

  ## Examples
      iex> EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:admin)
      {:ok, [%Metrics{}, ...]}  # 9 rows with 2 agencies (3 Tier 1 + 6 Tier 2)
  """
  def refresh_all_metrics(calculated_by \\ :admin) do
    require Logger
    Logger.info("Starting metrics refresh (calculated_by: #{calculated_by})")

    # Delete existing metrics to avoid duplicates
    __MODULE__
    |> Ash.Query.for_read(:read)
    |> Ash.read!()
    |> Enum.each(&Ash.destroy!(&1))

    Logger.info("Cleared existing metrics")

    # Tier 1: All agencies combined (3 rows - one per time period)
    tier1_results =
      for period <- [:week, :month, :year] do
        Logger.info("Generating Tier 1 metrics: period=#{period}, agency_id=nil")

        refresh_metric_combination(
          period: period,
          agency_id: nil,
          record_type: nil,
          calculated_by: calculated_by
        )
      end

    # Tier 2: Per-agency (N × 3 rows for N agencies)
    agencies = EhsEnforcement.Enforcement.list_agencies!()
    Logger.info("Found #{length(agencies)} agencies for Tier 2")

    tier2_results =
      for period <- [:week, :month, :year],
          agency <- agencies do
        Logger.info("Generating Tier 2 metrics: period=#{period}, agency_id=#{agency.id}")

        refresh_metric_combination(
          period: period,
          agency_id: agency.id,
          record_type: nil,
          calculated_by: calculated_by
        )
      end

    total_generated = length(tier1_results) + length(tier2_results)
    Logger.info("Metrics refresh complete: #{total_generated} combinations generated")

    # Broadcast refresh event via Phoenix PubSub
    Phoenix.PubSub.broadcast(
      EhsEnforcement.PubSub,
      "metrics:refreshed",
      {:metrics_refreshed, total_generated}
    )

    {:ok, tier1_results ++ tier2_results}
  end

  # NEW: Refresh a single metric combination using SQL aggregations (zero record loading)
  defp refresh_metric_combination(opts) do
    require Logger

    period = opts[:period]
    agency_id = opts[:agency_id]
    # Convert string UUID to binary for SQL queries
    agency_id_binary =
      if agency_id && is_binary(agency_id) && byte_size(agency_id) > 16 do
        Ecto.UUID.dump!(agency_id)
      else
        agency_id
      end

    record_type = opts[:record_type]
    calculated_by = opts[:calculated_by] || :admin

    # Calculate period metadata
    {days_ago, period_label} =
      case period do
        :week -> {7, "Last 7 Days"}
        :month -> {30, "Last 30 Days"}
        :year -> {365, "Last 365 Days"}
      end

    cutoff_date = Date.add(Date.utc_today(), -days_ago)
    calculated_at = DateTime.utc_now()

    Logger.debug(
      "Refreshing metric: period=#{period}, agency_id=#{inspect(agency_id)}, record_type=#{inspect(record_type)}"
    )

    # SQL aggregation for recent counts and financial totals
    stats = get_recent_stats(cutoff_date, agency_id_binary, record_type)

    # Total counts (all time)
    total_cases_count = get_total_count(:cases, agency_id_binary)
    total_notices_count = get_total_count(:notices, agency_id_binary)
    total_offences_count = get_total_count(:offences, agency_id_binary, cutoff_date)

    # Agency breakdown (only when agency_id is NULL - Tier 1 only)
    agency_stats =
      if is_nil(agency_id) do
        calculate_agency_breakdown(cutoff_date, record_type)
      else
        %{}
      end

    # Recent activity (top 100 items materialized as JSONB)
    recent_activity =
      fetch_recent_activity_json(cutoff_date, agency_id_binary, record_type, limit: 100)

    # Create metrics record
    attrs = %{
      period: period,
      period_label: period_label,
      days_ago: days_ago,
      cutoff_date: cutoff_date,
      agency_id: agency_id,
      record_type: record_type,
      # Future use
      offender_id: nil,
      # Future use
      legislation_id: nil,
      recent_cases_count: stats.recent_cases_count,
      recent_notices_count: stats.recent_notices_count,
      total_cases_count: total_cases_count,
      total_notices_count: total_notices_count,
      total_offences_count: total_offences_count,
      total_fines_amount: stats.total_fines || Decimal.new(0),
      total_costs_amount: stats.total_costs || Decimal.new(0),
      active_agencies_count: get_active_agencies_count(),
      agency_stats: agency_stats,
      # TODO: Implement in future phase
      offender_breakdown: %{},
      # TODO: Implement in future phase
      legislation_breakdown: %{},
      recent_activity: recent_activity,
      calculated_at: calculated_at,
      calculated_by: calculated_by
    }

    Logger.debug("Creating metrics record with #{length(recent_activity)} recent activities")

    __MODULE__
    |> Ash.Changeset.for_create(:refresh, attrs)
    |> Ash.create!()
  end

  # Helper: Get recent stats using SQL aggregation (zero record loading)
  defp get_recent_stats(cutoff_date, agency_id, record_type) do
    # Build dynamic SQL based on filters
    agency_filter = if agency_id, do: "AND agency_id = $2", else: ""

    record_type_filter =
      case record_type do
        :case -> "AND type = 'case'"
        :notice -> "AND type = 'notice'"
        _ -> ""
      end

    query = """
    SELECT
      COUNT(CASE WHEN type = 'case' THEN 1 END)::bigint as recent_cases_count,
      COUNT(CASE WHEN type = 'notice' THEN 1 END)::bigint as recent_notices_count,
      COALESCE(SUM(offence_fine), 0) as total_fines,
      COALESCE(SUM(offence_costs), 0) as total_costs
    FROM (
      SELECT 'case' as type, offence_fine, offence_costs, agency_id
      FROM cases WHERE offence_action_date >= $1
      UNION ALL
      SELECT 'notice' as type, NULL::decimal as offence_fine, NULL::decimal as offence_costs, agency_id
      FROM notices WHERE offence_action_date >= $1
    ) combined
    WHERE 1=1
      #{agency_filter}
      #{record_type_filter}
    """

    params = if agency_id, do: [cutoff_date, agency_id], else: [cutoff_date]

    result =
      Ecto.Adapters.SQL.query!(
        EhsEnforcement.Repo,
        query,
        params
      )

    [recent_cases_count, recent_notices_count, total_fines, total_costs] =
      result.rows |> List.first()

    %{
      recent_cases_count: recent_cases_count || 0,
      recent_notices_count: recent_notices_count || 0,
      total_fines: total_fines,
      total_costs: total_costs
    }
  end

  # Helper: Get total count for a table with optional agency filter
  defp get_total_count(:cases, agency_id) do
    query =
      if agency_id do
        "SELECT COUNT(*)::bigint FROM cases WHERE agency_id = $1"
      else
        "SELECT COUNT(*)::bigint FROM cases"
      end

    params = if agency_id, do: [agency_id], else: []

    result =
      Ecto.Adapters.SQL.query!(
        EhsEnforcement.Repo,
        query,
        params
      )

    result.rows |> List.first() |> List.first()
  end

  defp get_total_count(:notices, agency_id) do
    query =
      if agency_id do
        "SELECT COUNT(*)::bigint FROM notices WHERE agency_id = $1"
      else
        "SELECT COUNT(*)::bigint FROM notices"
      end

    params = if agency_id, do: [agency_id], else: []

    result =
      Ecto.Adapters.SQL.query!(
        EhsEnforcement.Repo,
        query,
        params
      )

    result.rows |> List.first() |> List.first()
  end

  defp get_total_count(:offences, agency_id, cutoff_date) do
    query =
      if agency_id do
        "SELECT COUNT(*)::bigint FROM offences WHERE case_id IN (SELECT id FROM cases WHERE agency_id = $1 AND offence_action_date >= $2)"
      else
        "SELECT COUNT(*)::bigint FROM offences WHERE case_id IN (SELECT id FROM cases WHERE offence_action_date >= $1)"
      end

    params = if agency_id, do: [agency_id, cutoff_date], else: [cutoff_date]

    result =
      Ecto.Adapters.SQL.query!(
        EhsEnforcement.Repo,
        query,
        params
      )

    result.rows |> List.first() |> List.first()
  end

  # Helper: Calculate per-agency breakdown (GROUP BY agency_id)
  defp calculate_agency_breakdown(cutoff_date, record_type) do
    # First, get all agencies
    all_agencies = EhsEnforcement.Enforcement.list_agencies!()

    # Build SQL for agency stats
    record_type_filter =
      case record_type do
        :case -> "AND type = 'case'"
        :notice -> "AND type = 'notice'"
        _ -> ""
      end

    query = """
    SELECT
      agency_id,
      COUNT(CASE WHEN type = 'case' THEN 1 END)::bigint as case_count,
      COUNT(CASE WHEN type = 'notice' THEN 1 END)::bigint as notice_count,
      COALESCE(SUM(offence_fine), 0) as total_fines
    FROM (
      SELECT agency_id, 'case' as type, offence_fine
      FROM cases WHERE offence_action_date >= $1
      UNION ALL
      SELECT agency_id, 'notice' as type, NULL::decimal as offence_fine
      FROM notices WHERE offence_action_date >= $1
    ) combined
    WHERE 1=1
      #{record_type_filter}
    GROUP BY agency_id
    """

    result = Ecto.Adapters.SQL.query!(EhsEnforcement.Repo, query, [cutoff_date])

    # Convert to map keyed by agency_id
    stats_by_agency_id =
      result.rows
      |> Enum.map(fn [agency_id, case_count, notice_count, total_fines] ->
        {agency_id,
         %{
           case_count: case_count || 0,
           notice_count: notice_count || 0,
           total_fines: total_fines || Decimal.new(0)
         }}
      end)
      |> Enum.into(%{})

    # Calculate totals for percentages
    total_cases = stats_by_agency_id |> Map.values() |> Enum.map(& &1.case_count) |> Enum.sum()

    total_notices =
      stats_by_agency_id |> Map.values() |> Enum.map(& &1.notice_count) |> Enum.sum()

    total_actions = total_cases + total_notices

    # Merge with agency details and calculate percentages
    agency_stats =
      all_agencies
      |> Enum.map(fn agency ->
        stats =
          Map.get(stats_by_agency_id, agency.id, %{
            case_count: 0,
            notice_count: 0,
            total_fines: Decimal.new(0)
          })

        case_count = stats.case_count
        notice_count = stats.notice_count
        action_count = case_count + notice_count

        %{
          agency_id: agency.id,
          agency_code: agency.code,
          agency_name: agency.name,
          enabled: agency.enabled,
          case_count: case_count,
          notice_count: notice_count,
          total_actions: action_count,
          total_fines: stats.total_fines,
          case_percentage:
            if(total_cases > 0, do: Float.round(case_count / total_cases * 100, 1), else: 0.0),
          action_percentage:
            if(total_actions > 0,
              do: Float.round(action_count / total_actions * 100, 1),
              else: 0.0
            )
        }
      end)
      |> Enum.into(%{}, fn stat -> {stat.agency_id, stat} end)

    agency_stats
  end

  # Helper: Fetch recent activity as JSONB (top N items specified by opts)
  defp fetch_recent_activity_json(cutoff_date, agency_id, record_type, opts) do
    limit = Keyword.get(opts, :limit, 100)

    # Build filters
    agency_filter = if agency_id, do: "AND combined.agency_id = $2", else: ""

    record_type_filter =
      case record_type do
        :case -> "AND combined.record_type = 'case'"
        :notice -> "AND combined.record_type = 'notice'"
        _ -> ""
      end

    query = """
    SELECT
      combined.id::text,
      combined.record_type,
      combined.display_type,
      combined.regulator_id,
      combined.offence_action_date,
      combined.agency_id::text,
      combined.offender_id::text,
      combined.offence_fine as fine_amount,
      combined.offence_costs as costs_amount,
      COALESCE(off.name, 'Unknown Organization') as organization,
      combined.description,
      combined.url
    FROM (
      SELECT
        c.id,
        'case' as record_type,
        COALESCE(c.offence_action_type, 'Court Case') as display_type,
        c.regulator_id,
        c.offence_action_date,
        c.agency_id,
        c.offender_id,
        c.offence_fine,
        c.offence_costs,
        COALESCE(c.offence_breaches, 'Court case proceeding') as description,
        c.url
      FROM cases c
      WHERE c.offence_action_date >= $1
      UNION ALL
      SELECT
        n.id,
        'notice' as record_type,
        COALESCE(n.offence_action_type, 'Improvement Notice') as display_type,
        n.regulator_id,
        n.offence_action_date,
        n.agency_id,
        n.offender_id,
        NULL::decimal as offence_fine,
        NULL::decimal as offence_costs,
        COALESCE(n.offence_breaches, 'Enforcement notice issued') as description,
        n.url
      FROM notices n
      WHERE n.offence_action_date >= $1
    ) combined
    LEFT JOIN offenders off ON combined.offender_id = off.id
    WHERE 1=1
      #{agency_filter}
      #{record_type_filter}
    ORDER BY combined.offence_action_date DESC
    LIMIT $#{if agency_id, do: "3", else: "2"}
    """

    params =
      if agency_id do
        [cutoff_date, agency_id, limit]
      else
        [cutoff_date, limit]
      end

    result = Ecto.Adapters.SQL.query!(EhsEnforcement.Repo, query, params)

    # Convert rows to maps with all required fields
    result.rows
    |> Enum.map(fn [
                     id,
                     record_type,
                     display_type,
                     regulator_id,
                     action_date,
                     agency_id,
                     offender_id,
                     fine_amount,
                     costs_amount,
                     organization,
                     description,
                     url
                   ] ->
      # Parse date string to Date struct for Calendar.strftime compatibility
      parsed_date =
        case action_date do
          %Date{} = date -> date
          date_string when is_binary(date_string) -> Date.from_iso8601!(date_string)
          _ -> nil
        end

      %{
        "id" => id,
        "record_type" => record_type,
        "type" => display_type,
        "regulator_id" => regulator_id,
        "is_case" => record_type == "case",
        "date" => parsed_date,
        "action_date" => parsed_date,
        "agency_id" => agency_id,
        "offender_id" => offender_id,
        "fine_amount" => fine_amount,
        "costs_amount" => costs_amount,
        "organization" => organization,
        "description" => description,
        "agency_link" => url
      }
    end)
  end

  # Helper: Get count of active agencies
  defp get_active_agencies_count do
    query = "SELECT COUNT(*)::bigint FROM agencies WHERE enabled = true"
    result = Ecto.Adapters.SQL.query!(EhsEnforcement.Repo, query, [])
    result.rows |> List.first() |> List.first()
  end
end
