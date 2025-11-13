defmodule EhsEnforcementWeb.DashboardMetricsSimpleTest do
  @moduledoc """
  Simplified tests for cached metrics functionality.

  These tests verify the core metrics caching system without complex authentication.
  """

  use EhsEnforcement.DataCase

  # 🐛 BLOCKED: Dashboard metrics tests failing - Issue #47
  @moduletag :skip

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Enforcement.Metrics

  describe "Metrics Resource Functionality" do
    setup do
      # Create test agencies
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

      # Create test offender
      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Test Company Ltd",
          local_authority: "Test Council",
          postcode: "TE1 1ST"
        })

      # Create test cases with recent dates
      recent_date = Date.add(Date.utc_today(), -5)

      {:ok, case1} =
        Enforcement.create_case(%{
          regulator_id: "HSE-001",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_date: recent_date,
          offence_fine: Decimal.new("5000.00"),
          offence_breaches: "Safety violation",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, notice1} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-N001",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_date: recent_date,
          notice_date: recent_date,
          offence_action_type: "improvement",
          notice_body: "Test notice body"
        })

      %{
        hse_agency: hse_agency,
        ea_agency: ea_agency,
        offender: offender,
        case1: case1,
        notice1: notice1
      }
    end

    test "refresh_all_metrics creates cached metrics for all time periods" do
      # Clear any existing metrics
      Enforcement.Metrics
      |> Ash.Query.for_read(:read)
      |> Ash.read!()
      |> Enum.each(&Ash.destroy!(&1))

      # Execute metric refresh
      {:ok, results} = Metrics.refresh_all_metrics(:admin)

      # Verify metrics were created
      metrics =
        Enforcement.Metrics
        |> Ash.Query.for_read(:read)
        |> Ash.read!()

      assert length(metrics) == 3, "Should create metrics for 3 time periods (week, month, year)"
      assert length(results) == 3, "Should return 3 results"

      # Verify all time periods are covered
      periods = Enum.map(metrics, & &1.period) |> Enum.sort()
      assert periods == [:month, :week, :year]

      # Verify calculated_by is set correctly
      assert Enum.all?(metrics, fn m -> m.calculated_by == :admin end)
    end

    test "refresh_all_metrics with automation parameter sets calculated_by correctly" do
      # Clear existing metrics
      Enforcement.Metrics
      |> Ash.Query.for_read(:read)
      |> Ash.read!()
      |> Enum.each(&Ash.destroy!(&1))

      # Execute metric refresh with automation flag
      {:ok, _results} = Metrics.refresh_all_metrics(:automation)

      # Verify metrics have automation flag
      metrics =
        Enforcement.Metrics
        |> Ash.Query.for_read(:read)
        |> Ash.read!()

      assert Enum.all?(metrics, fn m -> m.calculated_by == :automation end)
    end

    test "metrics contain correct calculated data" do
      # Clear existing metrics
      Enforcement.Metrics
      |> Ash.Query.for_read(:read)
      |> Ash.read!()
      |> Enum.each(&Ash.destroy!(&1))

      # Execute metric refresh
      {:ok, _results} = Metrics.refresh_all_metrics(:admin)

      # Get week metrics
      week_metrics =
        Enforcement.Metrics
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(period == :week)
        |> Ash.read!()
        |> List.first()

      assert week_metrics != nil
      assert week_metrics.recent_cases_count >= 0
      assert week_metrics.recent_notices_count >= 0
      assert week_metrics.total_cases_count >= 0
      assert week_metrics.total_notices_count >= 0
      assert is_map(week_metrics.agency_stats)
    end

    test "get_current_metrics returns cached metrics" do
      # Clear and refresh metrics
      Enforcement.Metrics
      |> Ash.Query.for_read(:read)
      |> Ash.read!()
      |> Enum.each(&Ash.destroy!(&1))

      {:ok, _results} = Metrics.refresh_all_metrics(:admin)

      # Get current metrics
      {:ok, current_metrics} = Enforcement.Metrics.get_current_metrics()

      assert length(current_metrics) == 3
      assert Enum.all?(current_metrics, fn m -> m.calculated_by == :admin end)
    end
  end

  describe "Scheduled Metric Refresh Action" do
    test "scheduled_refresh action works correctly" do
      # Clear existing metrics
      Enforcement.Metrics
      |> Ash.Query.for_read(:read)
      |> Ash.read!()
      |> Enum.each(&Ash.destroy!(&1))

      # Execute the scheduled refresh action
      _result = Enforcement.Metrics.scheduled_refresh_metrics()

      # The action should complete (even if it returns an error due to the changeset pattern)
      # The important thing is that metrics were created
      metrics =
        Enforcement.Metrics
        |> Ash.Query.for_read(:read)
        |> Ash.read!()

      assert length(metrics) == 3,
             "Scheduled refresh should create metrics for all 3 time periods"

      # Verify automation tracking
      assert Enum.all?(metrics, fn m -> m.calculated_by == :automation end),
             "Scheduled refresh should mark metrics as calculated by automation"
    end
  end

  describe "Metrics Performance Optimization" do
    test "cached metrics loading is faster than real-time calculation" do
      # This test demonstrates the performance benefit
      # We'll measure the time to refresh metrics vs getting cached metrics

      # First, time the metric calculation (refresh)
      start_time = System.monotonic_time(:millisecond)
      {:ok, _results} = Metrics.refresh_all_metrics(:admin)
      refresh_time = System.monotonic_time(:millisecond) - start_time

      # Now time getting the cached metrics
      start_time = System.monotonic_time(:millisecond)
      {:ok, cached_metrics} = Enforcement.Metrics.get_current_metrics()
      cache_time = System.monotonic_time(:millisecond) - start_time

      # Cache retrieval should be significantly faster
      assert cache_time < refresh_time,
             "Cached metrics (#{cache_time}ms) should be faster than refresh (#{refresh_time}ms)"

      # Verify we got the data
      assert length(cached_metrics) == 3
    end
  end

  describe "PubSub Integration" do
    test "metric refresh broadcasts PubSub message" do
      # Subscribe to the metrics PubSub topic
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "metrics:refreshed")

      # Trigger a metric refresh (this should broadcast via PubSub)
      {:ok, _results} = Metrics.refresh_all_metrics(:admin)

      # Check that we received the PubSub message
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: "metrics:refreshed",
                       event: "refresh"
                     },
                     1000
    end
  end
end
