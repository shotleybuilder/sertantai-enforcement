defmodule EhsEnforcementWeb.ReportsLive.Offenders do
  @moduledoc """
  Offender Analytics Report LiveView providing detailed insights into enforcement patterns.

  Provides:
  - Industry analysis with offender counts and fine totals
  - Top offenders by total fines
  - Repeat offender statistics and trends
  - Export functionality for analytics data
  """

  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement

  @impl true
  def mount(_params, _session, socket) do
    # Load offender analytics
    industry_stats = calculate_industry_stats()
    top_offenders = get_top_offenders()
    repeat_percentage = calculate_repeat_offender_percentage()

    {:ok,
     socket
     |> assign(:page_title, "Offender Analytics Report")
     |> assign(:industry_stats, industry_stats)
     |> assign(:top_offenders, top_offenders)
     |> assign(:repeat_offender_percentage, repeat_percentage)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("back_to_reports", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/reports")}
  end

  @impl true
  def handle_event("export_analytics", _params, socket) do
    csv_data = generate_analytics_csv(socket.assigns)

    socket =
      socket
      |> push_event("download_csv", %{
        data: csv_data,
        filename: "offender_analytics_#{Date.utc_today()}.csv"
      })

    {:noreply, socket}
  end

  # Analytics calculation functions (moved from OffenderLive.Index)

  defp calculate_industry_stats do
    try do
      offenders = Enforcement.list_offenders!()

      offenders
      |> Enum.group_by(& &1.industry)
      |> Enum.map(fn {industry, group} ->
        total_fines =
          Enum.reduce(group, Decimal.new(0), fn offender, acc ->
            Decimal.add(acc, offender.total_fines || Decimal.new(0))
          end)

        {industry || "Unknown",
         %{
           count: length(group),
           total_fines: total_fines,
           avg_fines: Decimal.div(total_fines, Decimal.new(length(group)))
         }}
      end)
      |> Enum.into(%{})
    rescue
      _ -> %{}
    end
  end

  defp get_top_offenders do
    try do
      Enforcement.list_offenders!(
        sort: [total_fines: :desc],
        limit: 10
      )
    rescue
      _ -> []
    end
  end

  defp calculate_repeat_offender_percentage do
    try do
      all_offenders = Enforcement.list_offenders!()
      total_count = length(all_offenders)

      if total_count > 0 do
        repeat_count =
          all_offenders
          |> Enum.count(fn offender ->
            total_enforcement = (offender.total_cases || 0) + (offender.total_notices || 0)
            total_enforcement > 2
          end)

        round(repeat_count / total_count * 100)
      else
        0
      end
    rescue
      _ -> 0
    end
  end

  defp format_currency(nil), do: "£0"

  defp format_currency(amount) when is_binary(amount) do
    case Decimal.parse(amount) do
      {decimal, _} -> format_currency(decimal)
      :error -> "£0"
    end
  end

  defp format_currency(%Decimal{} = amount) do
    "£#{Decimal.to_string(amount, :normal)}"
  end

  defp format_currency(amount) when is_integer(amount) do
    "£#{amount}"
  end

  defp generate_analytics_csv(assigns) do
    # Industry stats CSV
    industry_header = "Industry,Offender Count,Total Fines,Average Fines"

    industry_rows =
      Enum.map(assigns.industry_stats, fn {industry, stats} ->
        "\"#{industry}\",#{stats.count},#{Decimal.to_string(stats.total_fines)},#{Decimal.to_string(stats.avg_fines)}"
      end)

    # Top offenders CSV  
    top_offenders_header = "Top Offender Name,Total Fines,Total Cases,Total Notices,Industry"

    top_offender_rows =
      Enum.map(assigns.top_offenders, fn offender ->
        "\"#{offender.name || ""}\",#{Decimal.to_string(offender.total_fines || Decimal.new(0))},#{offender.total_cases || 0},#{offender.total_notices || 0},\"#{offender.industry || ""}\""
      end)

    # Combine sections
    ([
       "# Offender Analytics Report - #{Date.utc_today()}",
       "",
       "## Industry Analysis",
       industry_header
     ] ++
       industry_rows ++
       [
         "",
         "## Top Offenders",
         top_offenders_header
       ] ++
       top_offender_rows ++
       [
         "",
         "## Summary Statistics",
         "Repeat Offender Percentage,#{assigns.repeat_offender_percentage}%"
       ])
    |> Enum.join("\n")
  end
end
