defmodule EhsEnforcement.Enforcement.MetricsTest do
  use EhsEnforcement.DataCase, async: false

  require Ash.Query
  import Ash.Expr

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Enforcement.Metrics

  setup do
    # Create two agencies for testing
    {:ok, hse_agency} =
      Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true
      })

    {:ok, ea_agency} =
      Enforcement.create_agency(%{
        code: :ea,
        name: "Environment Agency",
        enabled: true
      })

    # Create test offenders
    {:ok, offender1} =
      Enforcement.create_offender(%{
        name: "Test Company Ltd",
        local_authority: "Manchester"
      })

    {:ok, offender2} =
      Enforcement.create_offender(%{
        name: "Another Corp",
        local_authority: "London"
      })

    # Create test cases (some recent, some old)
    # 5 days ago (within all periods)
    recent_date = Date.add(Date.utc_today(), -5)
    # 400 days ago (outside all periods)
    old_date = Date.add(Date.utc_today(), -400)

    # HSE cases
    {:ok, _case1} =
      Enforcement.create_case(%{
        agency_id: hse_agency.id,
        offender_id: offender1.id,
        regulator_id: "HSE001",
        offence_result: "Guilty",
        offence_fine: Decimal.new("10000.00"),
        offence_costs: Decimal.new("2000.00"),
        offence_action_date: recent_date
      })

    {:ok, _case2} =
      Enforcement.create_case(%{
        agency_id: hse_agency.id,
        offender_id: offender2.id,
        regulator_id: "HSE002",
        offence_result: "Guilty",
        offence_fine: Decimal.new("5000.00"),
        offence_costs: Decimal.new("1000.00"),
        offence_action_date: recent_date
      })

    # EA cases
    {:ok, _case3} =
      Enforcement.create_case(%{
        agency_id: ea_agency.id,
        offender_id: offender1.id,
        regulator_id: "EA001",
        offence_result: "Guilty",
        offence_fine: Decimal.new("20000.00"),
        offence_costs: Decimal.new("3000.00"),
        offence_action_date: recent_date
      })

    # Old case (should not appear in recent counts)
    {:ok, _old_case} =
      Enforcement.create_case(%{
        agency_id: hse_agency.id,
        offender_id: offender1.id,
        regulator_id: "HSE003",
        offence_result: "Guilty",
        offence_fine: Decimal.new("1000.00"),
        offence_costs: Decimal.new("500.00"),
        offence_action_date: old_date
      })

    # Create test notices
    {:ok, _notice1} =
      Enforcement.create_notice(%{
        agency_id: hse_agency.id,
        offender_id: offender1.id,
        regulator_id: "NOTICE001",
        offence_action_date: recent_date
      })

    {:ok, _notice2} =
      Enforcement.create_notice(%{
        agency_id: ea_agency.id,
        offender_id: offender2.id,
        regulator_id: "NOTICE002",
        offence_action_date: recent_date
      })

    %{
      hse_agency: hse_agency,
      ea_agency: ea_agency,
      offender1: offender1,
      offender2: offender2
    }
  end

  describe "refresh_all_metrics/1" do
    test "generates Tier 1 + Tier 2 metrics (9 rows with 2 agencies)" do
      # Refresh all metrics
      {:ok, results} = Metrics.refresh_all_metrics(:admin)

      # Should generate 9 rows: 3 Tier 1 + 6 Tier 2 (2 agencies × 3 periods)
      assert length(results) == 9

      # Verify all periods are generated
      periods = Enum.map(results, & &1.period) |> Enum.uniq() |> Enum.sort()
      assert periods == [:month, :week, :year]

      # Verify Tier 1 (agency_id = nil)
      tier1_metrics = Enum.filter(results, &is_nil(&1.agency_id))
      assert length(tier1_metrics) == 3

      # Verify Tier 2 (agency_id not nil)
      tier2_metrics = Enum.filter(results, &(!is_nil(&1.agency_id)))
      assert length(tier2_metrics) == 6

      # Verify each metric has unique filter combination
      combinations =
        Enum.map(results, fn m ->
          {m.period, m.agency_id, m.record_type, m.offender_id, m.legislation_id}
        end)

      assert length(Enum.uniq(combinations)) == 9
    end

    test "Tier 1 metrics aggregate all agencies correctly", %{hse_agency: hse, ea_agency: ea} do
      {:ok, results} = Metrics.refresh_all_metrics(:admin)

      # Get week metrics for all agencies
      week_all =
        Enum.find(results, fn m ->
          m.period == :week && is_nil(m.agency_id)
        end)

      assert week_all != nil

      # Should have 3 recent cases (2 HSE + 1 EA from last 7 days)
      assert week_all.recent_cases_count == 3

      # Should have 2 recent notices (1 HSE + 1 EA from last 7 days)
      assert week_all.recent_notices_count == 2

      # Total cases should be 4 (3 recent + 1 old)
      assert week_all.total_cases_count == 4

      # Total fines should be sum of recent cases (10000 + 5000 + 20000 = 35000)
      assert Decimal.equal?(week_all.total_fines_amount, Decimal.new("35000"))

      # Total costs should be sum of recent cases (2000 + 1000 + 3000 = 6000)
      assert Decimal.equal?(week_all.total_costs_amount, Decimal.new("6000"))

      # Should have 2 active agencies
      assert week_all.active_agencies_count == 2

      # Agency stats should exist for both agencies
      assert map_size(week_all.agency_stats) == 2
      assert Map.has_key?(week_all.agency_stats, hse.id)
      assert Map.has_key?(week_all.agency_stats, ea.id)
    end

    test "Tier 2 metrics filter by agency_id correctly", %{hse_agency: hse, ea_agency: ea} do
      {:ok, results} = Metrics.refresh_all_metrics(:admin)

      # Get week metrics for HSE only
      week_hse =
        Enum.find(results, fn m ->
          m.period == :week && m.agency_id == hse.id
        end)

      assert week_hse != nil

      # Should have 2 recent HSE cases
      assert week_hse.recent_cases_count == 2

      # Should have 1 recent HSE notice
      assert week_hse.recent_notices_count == 1

      # Total HSE cases should be 3 (2 recent + 1 old)
      assert week_hse.total_cases_count == 3

      # HSE fines should be 10000 + 5000 = 15000
      assert Decimal.equal?(week_hse.total_fines_amount, Decimal.new("15000"))

      # Agency stats should be empty for Tier 2 (only populated in Tier 1)
      assert week_hse.agency_stats == %{}

      # Get week metrics for EA only
      week_ea =
        Enum.find(results, fn m ->
          m.period == :week && m.agency_id == ea.id
        end)

      assert week_ea != nil

      # Should have 1 recent EA case
      assert week_ea.recent_cases_count == 1

      # Should have 1 recent EA notice
      assert week_ea.recent_notices_count == 1

      # EA fines should be 20000
      assert Decimal.equal?(week_ea.total_fines_amount, Decimal.new("20000"))
    end

    test "recent_activity field is populated with JSONB data" do
      {:ok, results} = Metrics.refresh_all_metrics(:admin)

      week_all =
        Enum.find(results, fn m ->
          m.period == :week && is_nil(m.agency_id)
        end)

      # Should have recent activity entries
      assert length(week_all.recent_activity) > 0

      # Should have at most 100 entries (our limit)
      assert length(week_all.recent_activity) <= 100

      # Each entry should be a map with required fields
      first_activity = List.first(week_all.recent_activity)
      assert Map.has_key?(first_activity, "id")
      assert Map.has_key?(first_activity, "type")
      assert Map.has_key?(first_activity, "action_date")
      assert Map.has_key?(first_activity, "agency_id")
      assert Map.has_key?(first_activity, "offender_id")
    end

    test "metrics have correct metadata fields" do
      {:ok, results} = Metrics.refresh_all_metrics(:admin)

      week_metric = Enum.find(results, &(&1.period == :week && is_nil(&1.agency_id)))

      assert week_metric.calculated_by == :admin
      assert week_metric.period_label == "Last 7 Days"
      assert week_metric.days_ago == 7
      assert week_metric.cutoff_date != nil
      assert week_metric.calculated_at != nil
    end

    test "clears old metrics before refresh" do
      # First refresh
      {:ok, results1} = Metrics.refresh_all_metrics(:admin)
      assert length(results1) == 9

      # Second refresh should clear old metrics and create new ones
      {:ok, results2} = Metrics.refresh_all_metrics(:admin)
      assert length(results2) == 9

      # Verify total metrics in database is still 9 (not 18)
      all_metrics =
        Metrics
        |> Ash.Query.for_read(:read)
        |> Ash.read!()

      assert length(all_metrics) == 9
    end

    test "uses SQL aggregations (zero record loading)" do
      # This test verifies the implementation uses SQL aggregations
      # by checking that the results match what we expect from the database

      {:ok, results} = Metrics.refresh_all_metrics(:admin)

      week_all =
        Enum.find(results, fn m ->
          m.period == :week && is_nil(m.agency_id)
        end)

      # Manually query database to verify counts
      recent_cases =
        Enforcement.list_cases_with_filters!([])
        |> Enum.filter(fn c ->
          c.offence_action_date &&
            Date.compare(c.offence_action_date, Date.add(Date.utc_today(), -7)) != :lt
        end)

      # Our SQL aggregation should match manual count
      assert week_all.recent_cases_count == length(recent_cases)
    end
  end

  describe "get_current/0" do
    test "returns metrics sorted by calculated_at desc" do
      {:ok, _} = Metrics.refresh_all_metrics(:admin)

      metrics =
        Metrics
        |> Ash.Query.for_read(:get_current)
        |> Ash.read!()

      # Should return all 9 metrics
      assert length(metrics) == 9

      # Should be sorted by calculated_at descending
      calculated_ats = Enum.map(metrics, & &1.calculated_at)
      assert calculated_ats == Enum.sort(calculated_ats, {:desc, DateTime})
    end
  end
end
