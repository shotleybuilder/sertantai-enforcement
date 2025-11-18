defmodule EhsEnforcementWeb.Api.AdminController do
  @moduledoc """
  API controller for admin dashboard data.

  Provides endpoints for:
  - Dashboard statistics
  - Agency status
  - System metrics
  """

  use EhsEnforcementWeb, :controller

  require Logger
  alias EhsEnforcement.Enforcement

  @doc """
  Get admin dashboard statistics.

  GET /api/admin/stats?period=month

  Query parameters:
  - period: "week" | "month" | "year" (defaults to "month")

  Returns:
  {
    "success": true,
    "data": {
      "recent_cases": 42,
      "recent_notices": 15,
      "total_cases": 1250,
      "total_notices": 350,
      "total_fines": "125000.00",
      "active_agencies": 3,
      "agency_stats": [...],
      "period": "30 days",
      "timeframe": "Last Month",
      "sync_errors": 0,
      "data_quality_score": 85.0
    }
  }
  """
  def stats(conn, params) do
    time_period = params["period"] || "month"

    stats = load_admin_stats(time_period)
    agencies = Enforcement.list_agencies!()

    conn
    |> json(%{
      success: true,
      data: %{
        stats: stats,
        agencies: serialize_agencies(agencies)
      }
    })
  rescue
    error ->
      Logger.error("Failed to load admin stats: #{inspect(error)}")

      conn
      |> put_status(:internal_server_error)
      |> json(%{
        success: false,
        error: "Failed to load admin statistics",
        details: inspect(error)
      })
  end

  # ============================================================================
  # Private Helpers (copied from DashboardLive for consistency)
  # ============================================================================

  defp load_admin_stats(time_period) do
    # Convert string time period to atom for matching
    period_atom =
      case time_period do
        "week" -> :week
        "month" -> :month
        "year" -> :year
        _ -> :month
      end

    try do
      # Load cached metrics for the admin dashboard
      case Enforcement.get_current_metrics() do
        {:ok, metrics} ->
          case Enum.find(metrics, fn metric -> metric.period == period_atom end) do
            %EhsEnforcement.Enforcement.Metrics{} = metric ->
              %{
                recent_cases: metric.recent_cases_count,
                recent_notices: metric.recent_notices_count,
                total_cases: metric.total_cases_count,
                total_notices: metric.total_notices_count,
                total_fines: Decimal.to_string(metric.total_fines_amount, :normal),
                active_agencies: metric.active_agencies_count,
                agency_stats: convert_agency_stats_to_list(metric.agency_stats),
                period: "#{metric.days_ago} days",
                timeframe: metric.period_label,
                # Admin-specific metrics
                sync_errors: get_recent_sync_errors(period_atom),
                data_quality_score: calculate_data_quality_score()
              }

            nil ->
              fallback_calculate_admin_stats(time_period)
          end

        {:error, _error} ->
          fallback_calculate_admin_stats(time_period)
      end
    rescue
      error ->
        Logger.error("Failed to load admin metrics: #{inspect(error)}")
        fallback_calculate_admin_stats(time_period)
    end
  end

  defp convert_agency_stats_to_list(agency_stats_map) when is_map(agency_stats_map) do
    agency_stats_map
    |> Map.values()
    |> Enum.sort_by(& &1["case_count"], :desc)
  end

  defp convert_agency_stats_to_list(_), do: []

  defp fallback_calculate_admin_stats(_time_period) do
    agencies = Enforcement.list_agencies!()

    %{
      recent_cases: 0,
      recent_notices: 0,
      total_cases: 0,
      total_notices: 0,
      total_fines: "0.00",
      active_agencies: Enum.count(agencies, & &1.enabled),
      agency_stats: [],
      period: "30 days",
      timeframe: "Last Month",
      sync_errors: 0,
      data_quality_score: 85.0
    }
  end

  defp get_recent_sync_errors(_period) do
    # In a real implementation, count recent sync errors
    0
  end

  defp calculate_data_quality_score do
    # In a real implementation, calculate data quality metrics
    85.0
  end

  defp serialize_agencies(agencies) do
    Enum.map(agencies, fn agency ->
      %{
        id: agency.id,
        code: agency.code,
        name: agency.name,
        base_url: agency.base_url,
        enabled: agency.enabled,
        inserted_at: agency.inserted_at,
        updated_at: agency.updated_at
      }
    end)
  end
end
