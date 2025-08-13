defmodule EhsEnforcementWeb.Admin.DashboardLive do
  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement
  alias Phoenix.PubSub
  
  require Ash.Query
  

  @impl true
  def mount(_params, _session, socket) do
    # Ensure user is admin (additional check beyond router)
    current_user = socket.assigns[:current_user]
    
    unless current_user && current_user.is_admin do
      {:ok, socket |> put_flash(:error, "Admin access required") |> redirect(to: "/")}
    else
      # Subscribe to admin-relevant updates
      PubSub.subscribe(EhsEnforcement.PubSub, "sync:updates")
      PubSub.subscribe(EhsEnforcement.PubSub, "metrics:refreshed")
      PubSub.subscribe(EhsEnforcement.PubSub, "admin:updates")
      
      # Load initial admin data
      agencies = Enforcement.list_agencies!()
      
      {:ok,
       socket
       |> assign(:agencies, agencies)
       |> assign(:stats, %{})
       |> assign(:loading, false)
       |> assign(:sync_status, %{})
       |> assign(:time_period, "month")
       |> assign(:page_title, "Admin Dashboard")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    # Load admin-specific metrics and data
    stats = load_admin_stats(socket.assigns.time_period)
    sync_status = get_sync_status()
    
    {:noreply,
     socket
     |> assign(:stats, stats)
     |> assign(:sync_status, sync_status)}
  end

  @impl true
  def handle_event("change_time_period", %{"period" => period}, socket) do
    stats = load_admin_stats(period)
    
    {:noreply,
     socket
     |> assign(:time_period, period)
     |> assign(:stats, stats)
     |> put_flash(:info, "Time period changed to #{period}")}
  end

  @impl true
  def handle_event("export_data", %{"format" => format}, socket) do
    # In a real implementation, this would generate and download the file
    {:noreply, put_flash(socket, :info, "Export to #{String.upcase(format)} started")}
  end

  @impl true
  def handle_event("refresh_metrics", _params, socket) do
    # Refresh metrics in the background
    Task.start(fn ->
      EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:admin)
    end)
    
    {:noreply, put_flash(socket, :info, "Metrics refresh started. Dashboard will update automatically when complete.")}
  end

  @impl true
  def handle_event("navigate_to_scraping", %{"type" => type}, socket) do
    path = case type do
      "cases" -> "/admin/cases/scrape"
      "notices" -> "/admin/notices/scrape"
      _ -> "/admin/scrape-sessions/monitor"
    end
    
    {:noreply, push_navigate(socket, to: path)}
  end

  @impl true
  def handle_event("navigate_to_config", _params, socket) do
    {:noreply, push_navigate(socket, to: "/admin/config")}
  end

  @impl true
  def handle_info({:sync_progress, agency_code, progress}, socket) do
    sync_status = Map.update(
      socket.assigns.sync_status,
      agency_code,
      %{status: "syncing", progress: progress},
      fn status -> %{status | progress: progress} end
    )
    
    {:noreply, assign(socket, :sync_status, sync_status)}
  end

  @impl true
  def handle_info({:sync_complete, agency_code, _timestamp}, socket) do
    # Reload data after sync
    agencies = Enforcement.list_agencies!()
    stats = load_admin_stats(socket.assigns.time_period)
    
    sync_status = Map.put(socket.assigns.sync_status, agency_code, %{status: "completed", progress: 100})
    
    {:noreply,
     socket
     |> assign(:agencies, agencies)
     |> assign(:stats, stats)
     |> assign(:sync_status, sync_status)}
  end

  @impl true
  def handle_info({:sync_error, agency_code, error_message}, socket) do
    sync_status = Map.put(socket.assigns.sync_status, agency_code, %{status: "error", error: error_message})
    
    {:noreply, assign(socket, :sync_status, sync_status)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "metrics:refreshed", event: "refresh"}, socket) do
    # Reload data after metrics are refreshed
    agencies = Enforcement.list_agencies!()
    stats = load_admin_stats(socket.assigns.time_period)
    
    {:noreply,
     socket
     |> assign(:agencies, agencies)
     |> assign(:stats, stats)
     |> put_flash(:info, "Admin dashboard metrics updated successfully!")}
  end

  # Catch-all handler for unmatched PubSub messages
  @impl true
  def handle_info(message, socket) do
    require Logger
    Logger.debug("Unhandled message in Admin.DashboardLive: #{inspect(message)}")
    {:noreply, socket}
  end

  # Private helper functions

  defp load_admin_stats(time_period) do
    # Convert string time period to atom for matching
    period_atom = case time_period do
      "week" -> :week
      "month" -> :month
      "year" -> :year
      _ -> :month
    end

    try do
      # Load cached metrics for the admin dashboard
      case EhsEnforcement.Enforcement.get_current_metrics() do
        {:ok, metrics} ->
          case Enum.find(metrics, fn metric -> metric.period == period_atom end) do
            %EhsEnforcement.Enforcement.Metrics{} = metric ->
              %{
                recent_cases: metric.recent_cases_count,
                recent_notices: metric.recent_notices_count,
                total_cases: metric.total_cases_count,
                total_notices: metric.total_notices_count,
                total_fines: metric.total_fines_amount,
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
        require Logger
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
      total_fines: Decimal.new(0),
      active_agencies: Enum.count(agencies, & &1.enabled),
      agency_stats: [],
      period: "30 days",
      timeframe: "Last Month",
      sync_errors: 0,
      data_quality_score: 85.0
    }
  end

  defp get_sync_status do
    # In a real implementation, this would check actual sync status
    # For now, return empty status
    %{}
  end

  defp get_recent_sync_errors(_period) do
    # In a real implementation, count recent sync errors
    0
  end

  defp calculate_data_quality_score do
    # In a real implementation, calculate data quality metrics
    85.0
  end
end