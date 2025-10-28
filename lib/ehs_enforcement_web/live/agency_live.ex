defmodule EhsEnforcementWeb.AgencyLive do
  @moduledoc """
  LiveView for managing and viewing agency information and statistics.

  Displays comprehensive agency overview, statistics, and management capabilities.
  """

  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement
  alias Phoenix.PubSub

  import EhsEnforcementWeb.Components.AgencyCard

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to real-time updates
    PubSub.subscribe(EhsEnforcement.PubSub, "sync:updates")
    PubSub.subscribe(EhsEnforcement.PubSub, "agency:updates")

    # Load agency data
    agencies = Enforcement.list_agencies!()

    {:ok,
     socket
     |> assign(:agencies, agencies)
     |> assign(:stats, %{})
     |> assign(:sync_status, %{})
     |> assign(:loading, false)
     |> assign(:time_period, "month")
     |> assign(:page_title, "Agencies")}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    # Calculate agency statistics
    stats = calculate_agency_stats(socket.assigns.agencies, socket.assigns.time_period)

    {:noreply, assign(socket, :stats, stats)}
  end

  @impl true
  def handle_event("change_time_period", %{"period" => period}, socket) do
    stats = calculate_agency_stats(socket.assigns.agencies, period)

    {:noreply,
     socket
     |> assign(:time_period, period)
     |> assign(:stats, stats)}
  end

  @impl true
  def handle_info({:sync_progress, agency_code, progress}, socket) do
    sync_status =
      Map.update(
        socket.assigns.sync_status,
        agency_code,
        %{status: "syncing", progress: progress},
        fn status -> %{status | progress: progress} end
      )

    {:noreply, assign(socket, :sync_status, sync_status)}
  end

  @impl true
  def handle_info({:sync_complete, agency_code, _timestamp}, socket) do
    # Handle sync completion with timestamp
    handle_info({:sync_complete, agency_code}, socket)
  end

  @impl true
  def handle_info({:sync_complete, agency_code}, socket) do
    # Reload agency data after sync
    agencies = Enforcement.list_agencies!()
    stats = calculate_agency_stats(agencies, socket.assigns.time_period)

    sync_status =
      Map.put(socket.assigns.sync_status, agency_code, %{status: "completed", progress: 100})

    {:noreply,
     socket
     |> assign(:agencies, agencies)
     |> assign(:stats, stats)
     |> assign(:sync_status, sync_status)}
  end

  @impl true
  def handle_info({:sync_error, agency_code, error_message}, socket) do
    sync_status =
      Map.put(socket.assigns.sync_status, agency_code, %{status: "error", error: error_message})

    {:noreply, assign(socket, :sync_status, sync_status)}
  end

  # Private helper functions

  defp calculate_agency_stats(agencies, period) do
    # Calculate date range based on selected period
    {days_ago, timeframe_label} =
      case period do
        "week" -> {7, "Last 7 Days"}
        "month" -> {30, "Last 30 Days"}
        "year" -> {365, "Last 365 Days"}
        # default fallback
        _ -> {30, "Last 30 Days"}
      end

    cutoff_date = Date.add(Date.utc_today(), -days_ago)

    try do
      # Get all cases for comprehensive stats
      all_cases = Enforcement.list_cases_with_filters!([])

      # Filter for recent cases (based on selected period)
      recent_cases =
        Enum.filter(all_cases, fn case_record ->
          case_record.offence_action_date &&
            Date.compare(case_record.offence_action_date, cutoff_date) != :lt
        end)

      recent_cases_count = length(recent_cases)

      # Get agency-specific stats for recent cases
      agency_stats =
        Enum.map(agencies, fn agency ->
          agency_recent_cases = Enum.count(recent_cases, &(&1.agency_id == agency.id))

          %{
            agency_id: agency.id,
            agency_code: agency.code,
            agency_name: agency.name,
            case_count: agency_recent_cases,
            percentage:
              if(recent_cases_count > 0,
                do: Float.round(agency_recent_cases / recent_cases_count * 100, 1),
                else: 0
              )
          }
        end)

      %{
        total_cases: length(all_cases),
        recent_cases: recent_cases_count,
        active_agencies: Enum.count(agencies, & &1.enabled),
        agency_stats: agency_stats,
        timeframe: timeframe_label
      }
    rescue
      error ->
        require Logger
        Logger.error("Failed to calculate agency statistics: #{inspect(error)}")

        %{
          total_cases: 0,
          recent_cases: 0,
          active_agencies: 0,
          agency_stats: [],
          timeframe: timeframe_label
        }
    end
  end
end
