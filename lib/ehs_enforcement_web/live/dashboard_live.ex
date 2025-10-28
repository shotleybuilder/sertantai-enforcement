defmodule EhsEnforcementWeb.DashboardLive do
  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement
  # alias EhsEnforcement.Enforcement.RecentActivity  # Unused alias removed
  alias Phoenix.PubSub

  require Ash.Query

  import EhsEnforcementWeb.Components.CasesActionCard
  import EhsEnforcementWeb.Components.NoticesActionCard
  import EhsEnforcementWeb.Components.OffendersActionCard
  import EhsEnforcementWeb.Components.ReportsActionCard
  import EhsEnforcementWeb.Components.LegislationActionCard

  @default_recent_activity_page_size 10

  @impl true
  def mount(_params, _session, socket) do
    # Current user will be loaded by the browser pipeline and available in socket.assigns
    # This follows the same pattern as other LiveViews in the application
    # CRITICAL: Assign current_user to nil if not present to prevent undefined errors

    # Subscribe to real-time updates
    PubSub.subscribe(EhsEnforcement.PubSub, "sync:updates")
    PubSub.subscribe(EhsEnforcement.PubSub, "agency:updates")
    PubSub.subscribe(EhsEnforcement.PubSub, "metrics:refreshed")

    # Load initial data
    agencies = Enforcement.list_agencies!()

    {:ok,
     socket
     |> assign_new(:current_user, fn -> nil end)
     |> assign(:agencies, agencies)
     |> assign(:recent_activity, [])
     |> assign(:total_recent_cases, 0)
     |> assign(:recent_activity_page, 1)
     |> assign(:recent_activity_page_size, @default_recent_activity_page_size)
     |> assign(:stats, %{
       active_agencies: 0,
       recent_cases: 0,
       recent_notices: 0,
       total_cases: 0,
       total_notices: 0,
       total_fines: Decimal.new(0),
       agency_stats: [],
       period: "30 days",
       timeframe: "Last 30 Days",
       total_legislation: 0,
       acts_count: 0,
       regulations_count: 0,
       orders_count: 0,
       acops_count: 0
     })
     |> assign(:loading, false)
     |> assign(:sync_status, %{})
     |> assign(:filter_agency, nil)
     |> assign(:recent_activity_filter, :all)
     |> assign(:time_period, "month")
     |> assign(:metrics_missing, false)}
  end

  @impl true
  def terminate(_reason, _socket) do
    # Clean up PubSub subscriptions to prevent accumulation in tests
    PubSub.unsubscribe(EhsEnforcement.PubSub, "sync:updates")
    PubSub.unsubscribe(EhsEnforcement.PubSub, "agency:updates")
    PubSub.unsubscribe(EhsEnforcement.PubSub, "metrics:refreshed")
    :ok
  end

  @impl true
  def handle_params(params, _url, socket) do
    recent_activity_page = String.to_integer(params["recent_activity_page"] || "1")

    # Load metrics for current filter combination
    case load_metrics_for_combination(socket.assigns.time_period, socket.assigns.filter_agency) do
      {:ok, metrics} ->
        # Use materialized recent_activity (top 100 items from metrics)
        filtered_activity =
          filter_recent_activity_by_type(
            metrics.recent_activity,
            socket.assigns.recent_activity_filter
          )

        # Apply client-side pagination (100 items max)
        total_count = length(filtered_activity)
        max_page = calculate_max_page(total_count, socket.assigns.recent_activity_page_size)
        valid_page = max(1, min(recent_activity_page, max_page))

        offset = (valid_page - 1) * socket.assigns.recent_activity_page_size

        paginated_activity =
          filtered_activity
          |> Enum.drop(offset)
          |> Enum.take(socket.assigns.recent_activity_page_size)

        {:noreply,
         socket
         |> assign(:recent_activity_page, valid_page)
         |> assign(:recent_activity, paginated_activity)
         |> assign(:total_recent_cases, total_count)
         |> assign(:stats, format_stats(metrics))
         |> assign(:metrics_missing, false)}

      {:error, :not_found} ->
        # Graceful degradation - metrics not yet calculated
        require Logger

        Logger.warning(
          "No cached metrics found for period=#{socket.assigns.time_period}, agency=#{socket.assigns.filter_agency}"
        )

        {:noreply,
         socket
         |> assign(:recent_activity_page, 1)
         |> assign(:recent_activity, [])
         |> assign(:total_recent_cases, 0)
         |> assign(:metrics_missing, true)}
    end
  end

  @impl true
  def handle_event("filter_by_agency", %{"agency" => agency_id}, socket) do
    filter_agency = if agency_id == "", do: nil, else: agency_id

    {:noreply,
     socket
     |> assign(:filter_agency, filter_agency)
     |> assign(:recent_activity_page, 1)
     |> push_patch(to: ~p"/dashboard")}
  end

  @impl true
  def handle_event("recent_activity_next_page", _params, socket) do
    current_page = socket.assigns.recent_activity_page

    max_page =
      calculate_max_page(
        socket.assigns.total_recent_cases,
        socket.assigns.recent_activity_page_size
      )

    if current_page < max_page do
      next_page = current_page + 1
      {:noreply, push_patch(socket, to: ~p"/dashboard?recent_activity_page=#{next_page}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("recent_activity_prev_page", _params, socket) do
    current_page = socket.assigns.recent_activity_page

    if current_page > 1 do
      prev_page = current_page - 1
      {:noreply, push_patch(socket, to: ~p"/dashboard?recent_activity_page=#{prev_page}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_time_period", %{"period" => period}, socket) do
    {:noreply,
     socket
     |> assign(:time_period, period)
     |> assign(:recent_activity_page, 1)
     |> push_patch(to: ~p"/dashboard")
     |> put_flash(:info, "Time period changed to #{period}")}
  end

  @impl true
  def handle_event("filter_recent_activity", %{"type" => type}, socket) do
    filter_type = String.to_existing_atom(type)

    {:noreply,
     socket
     |> assign(:recent_activity_filter, filter_type)
     |> assign(:recent_activity_page, 1)
     |> push_patch(to: ~p"/dashboard")}
  end

  @impl true
  def handle_event("browse_recent_cases", _params, socket) do
    # Use current time period for filtering
    time_period = Map.get(socket.assigns, :time_period, "month")
    {:noreply, push_navigate(socket, to: "/cases?filter=recent&period=#{time_period}")}
  end

  @impl true
  def handle_event("search_cases", _params, socket) do
    # Navigate to cases page with recent filter based on current time period
    time_period = Map.get(socket.assigns, :time_period, "month")
    {:noreply, push_navigate(socket, to: "/cases?filter=recent&period=#{time_period}")}
  end

  @impl true
  def handle_event("browse_recent_notices", _params, socket) do
    # Use current time period for filtering
    time_period = Map.get(socket.assigns, :time_period, "month")
    {:noreply, push_navigate(socket, to: "/notices?filter=recent&period=#{time_period}")}
  end

  @impl true
  def handle_event("search_notices", _params, socket) do
    {:noreply, push_navigate(socket, to: "/notices?filter=search")}
  end

  @impl true
  def handle_event("navigate_to_new_case", _params, socket) do
    {:noreply, push_navigate(socket, to: "/cases/new")}
  end

  @impl true
  def handle_event("browse_top_offenders", _params, socket) do
    {:noreply, push_navigate(socket, to: "/offenders?filter=top50&page=1")}
  end

  @impl true
  def handle_event("search_offenders", _params, socket) do
    {:noreply, push_navigate(socket, to: "/offenders?filter=search")}
  end

  @impl true
  def handle_event("generate_report", _params, socket) do
    {:noreply, push_navigate(socket, to: "/reports")}
  end

  @impl true
  def handle_event("browse_legislation", _params, socket) do
    {:noreply, push_navigate(socket, to: "/legislation")}
  end

  @impl true
  def handle_event("search_legislation", _params, socket) do
    {:noreply, push_navigate(socket, to: "/legislation?filter=search")}
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
    # Reload data after sync - trigger handle_params via push_patch
    sync_status =
      Map.put(socket.assigns.sync_status, agency_code, %{status: "completed", progress: 100})

    {:noreply,
     socket
     |> assign(:sync_status, sync_status)
     |> push_patch(to: ~p"/dashboard?recent_activity_page=#{socket.assigns.recent_activity_page}")}
  end

  @impl true
  def handle_info({:sync_error, agency_code, error_message}, socket) do
    sync_status =
      Map.put(socket.assigns.sync_status, agency_code, %{status: "error", error: error_message})

    {:noreply, assign(socket, :sync_status, sync_status)}
  end

  @impl true
  def handle_info({:case_created, _case}, socket) do
    # Reload data when a new case is created - trigger handle_params via push_patch
    {:noreply,
     socket
     |> push_patch(to: ~p"/dashboard?recent_activity_page=#{socket.assigns.recent_activity_page}")}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "metrics:refreshed", event: "refresh"}, socket) do
    # Reload data after metrics are refreshed - trigger handle_params via push_patch
    {:noreply,
     socket
     |> push_patch(to: ~p"/dashboard?recent_activity_page=#{socket.assigns.recent_activity_page}")
     |> put_flash(:info, "Dashboard metrics updated successfully!")}
  end

  # Catch-all handler for unmatched PubSub messages to prevent crashes
  @impl true
  def handle_info(message, socket) do
    require Logger
    Logger.debug("Unhandled message in DashboardLive: #{inspect(message)}")
    {:noreply, socket}
  end

  # ==========================================
  # METRICS LOADING FUNCTIONS (Phase 2)
  # ==========================================

  defp load_metrics_for_combination(time_period, filter_agency) do
    alias EhsEnforcement.Enforcement.Metrics

    # Convert string time period to atom
    period_atom = convert_period_to_atom(time_period)

    # Build query for specific filter combination
    query =
      Metrics
      |> Ash.Query.filter(period == ^period_atom)
      |> Ash.Query.filter(is_nil(record_type))
      |> Ash.Query.filter(is_nil(offender_id))
      |> Ash.Query.filter(is_nil(legislation_id))

    # Add agency filter
    query =
      if filter_agency do
        Ash.Query.filter(query, agency_id == ^filter_agency)
      else
        Ash.Query.filter(query, is_nil(agency_id))
      end

    case Ash.read(query) do
      {:ok, [metric]} ->
        {:ok, metric}

      {:ok, []} ->
        {:error, :not_found}

      {:error, error} ->
        require Logger
        Logger.error("Failed to load metrics: #{inspect(error)}")
        {:error, :not_found}
    end
  end

  defp convert_period_to_atom(period) when is_binary(period) do
    case period do
      "week" -> :week
      "month" -> :month
      "year" -> :year
      _ -> :month
    end
  end

  defp convert_period_to_atom(period) when is_atom(period), do: period

  defp filter_recent_activity_by_type(recent_activity, filter) do
    # Parse dates from JSONB strings to Date structs
    parsed_activity = Enum.map(recent_activity, &parse_activity_dates/1)

    case filter do
      :all -> parsed_activity
      :cases -> Enum.filter(parsed_activity, fn a -> a["record_type"] == "case" end)
      :notices -> Enum.filter(parsed_activity, fn a -> a["record_type"] == "notice" end)
    end
  end

  defp parse_activity_dates(activity) when is_map(activity) do
    # Parse date field if it's a string (from JSONB storage)
    date =
      case activity["date"] do
        %Date{} = d ->
          d

        date_string when is_binary(date_string) ->
          case Date.from_iso8601(date_string) do
            {:ok, d} -> d
            _ -> nil
          end

        _ ->
          nil
      end

    Map.put(activity, "date", date)
  end

  defp format_stats(metrics) do
    %{
      recent_cases: metrics.recent_cases_count,
      recent_notices: metrics.recent_notices_count,
      total_cases: metrics.total_cases_count,
      total_notices: metrics.total_notices_count,
      total_fines: metrics.total_fines_amount,
      total_costs: metrics.total_costs_amount,
      active_agencies: metrics.active_agencies_count,
      agency_stats: convert_agency_stats_to_list(metrics.agency_stats),
      period: "#{metrics.days_ago} days",
      timeframe: metrics.period_label,
      # Use legislation breakdown from metrics or provide defaults
      total_legislation: Map.get(metrics.legislation_breakdown, "total", 0),
      acts_count: Map.get(metrics.legislation_breakdown, "acts", 0),
      regulations_count: Map.get(metrics.legislation_breakdown, "regulations", 0),
      orders_count: Map.get(metrics.legislation_breakdown, "orders", 0),
      acops_count: Map.get(metrics.legislation_breakdown, "acops", 0)
    }
  end

  defp convert_agency_stats_to_list(agency_stats_map) when is_map(agency_stats_map) do
    agency_stats_map
    |> Map.values()
    |> Enum.sort_by(& &1["case_count"], :desc)
  end

  defp convert_agency_stats_to_list(_), do: []

  # ==========================================
  # PAGINATION HELPERS (Client-side)
  # ==========================================

  defp calculate_max_page(total_items, _page_size) when total_items <= 0, do: 1

  defp calculate_max_page(total_items, page_size) do
    ceil(total_items / page_size)
  end
end
