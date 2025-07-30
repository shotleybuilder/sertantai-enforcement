defmodule EhsEnforcementWeb.DashboardLive do
  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement
  # alias EhsEnforcement.Enforcement.RecentActivity  # Unused alias removed
  alias EhsEnforcement.Sync.SyncManager
  alias Phoenix.PubSub
  
  import EhsEnforcementWeb.Components.CasesActionCard
  import EhsEnforcementWeb.Components.NoticesActionCard
  import EhsEnforcementWeb.Components.OffendersActionCard
  import EhsEnforcementWeb.Components.ReportsActionCard

  @default_recent_activity_page_size 10

  @impl true
  def mount(_params, _session, socket) do
    # Current user will be loaded by the browser pipeline and available in socket.assigns
    # This follows the same pattern as other LiveViews in the application
    
    # Subscribe to real-time updates
    PubSub.subscribe(EhsEnforcement.PubSub, "sync:updates")
    PubSub.subscribe(EhsEnforcement.PubSub, "agency:updates")
    
    # Load initial data
    agencies = Enforcement.list_agencies!()
    
    {:ok,
     socket
     |> assign(:agencies, agencies)
     |> assign(:recent_cases, [])
     |> assign(:recent_activity, [])
     |> assign(:total_recent_cases, 0)
     |> assign(:recent_activity_page, 1)
     |> assign(:recent_activity_page_size, @default_recent_activity_page_size)
     |> assign(:stats, %{})
     |> assign(:loading, false)
     |> assign(:sync_status, %{})
     |> assign(:filter_agency, nil)
     |> assign(:recent_activity_filter, :all)
     |> assign(:time_period, "week")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    recent_activity_page = String.to_integer(params["recent_activity_page"] || "1")
    
    # Load data first to get total count
    {recent_cases, total_recent_cases} = load_recent_cases_paginated(socket.assigns.filter_agency, recent_activity_page, socket.assigns.recent_activity_page_size)
    
    # Convert cases to recent activity format for the table
    _recent_activity = format_cases_as_recent_activity(recent_cases)
    
    # Calculate stats
    stats = calculate_stats(socket.assigns.agencies, recent_cases, socket.assigns.time_period)
    
    # Ensure page is within valid range (recalculate if needed)
    max_page = calculate_max_page(total_recent_cases, socket.assigns.recent_activity_page_size)
    valid_page = max(1, min(recent_activity_page, max_page))
    
    # If page was out of range, reload with valid page
    final_data = if valid_page != recent_activity_page do
      load_recent_cases_paginated(socket.assigns.filter_agency, valid_page, socket.assigns.recent_activity_page_size)
    else
      {recent_cases, total_recent_cases}
    end
    
    {final_recent_cases, final_total_recent_cases} = final_data
    final_recent_activity = format_cases_as_recent_activity(final_recent_cases)
    
    {:noreply,
     socket
     |> assign(:recent_activity_page, valid_page)
     |> assign(:recent_cases, final_recent_cases)
     |> assign(:total_recent_cases, final_total_recent_cases)
     |> assign(:recent_activity, final_recent_activity)
     |> assign(:stats, stats)}
  end

  @impl true
  def handle_event("sync_agency", %{"agency" => agency_code}, socket) do
    agency_code = String.to_existing_atom(agency_code)
    
    # Start sync process
    Task.start(fn ->
      SyncManager.sync_agency(agency_code, :cases)
    end)
    
    # Update UI to show sync in progress
    sync_status = Map.put(socket.assigns.sync_status, agency_code, %{status: "syncing", progress: 0})
    
    {:noreply, assign(socket, :sync_status, sync_status)}
  end

  @impl true
  def handle_event("filter_by_agency", %{"agency" => agency_id}, socket) do
    filter_agency = if agency_id == "", do: nil, else: agency_id
    {recent_cases, total_recent_cases} = load_recent_cases_paginated(filter_agency, 1, socket.assigns.recent_activity_page_size)
    recent_activity = format_cases_as_recent_activity(recent_cases)
    
    {:noreply,
     socket
     |> assign(:filter_agency, filter_agency)
     |> assign(:recent_cases, recent_cases)
     |> assign(:total_recent_cases, total_recent_cases)
     |> assign(:recent_activity, recent_activity)
     |> assign(:recent_activity_page, 1)
     |> push_patch(to: ~p"/dashboard")}
  end

  @impl true
  def handle_event("recent_activity_next_page", _params, socket) do
    current_page = socket.assigns.recent_activity_page
    max_page = calculate_max_page(socket.assigns.total_recent_cases, socket.assigns.recent_activity_page_size)
    
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
    agencies = socket.assigns.agencies
    {recent_cases, total_recent_cases} = load_recent_cases_paginated(socket.assigns.filter_agency, socket.assigns.recent_activity_page, socket.assigns.recent_activity_page_size)
    recent_activity = format_cases_as_recent_activity(recent_cases)
    stats = calculate_stats(agencies, recent_cases, period)
    
    {:noreply,
     socket
     |> assign(:time_period, period)
     |> assign(:recent_cases, recent_cases)
     |> assign(:total_recent_cases, total_recent_cases)
     |> assign(:recent_activity, recent_activity)
     |> assign(:stats, stats)}
  end

  @impl true
  def handle_event("filter_recent_activity", %{"type" => type}, socket) do
    filter_type = String.to_existing_atom(type)
    
    # Load recent activity based on filter type
    {filtered_activity, total_filtered_count} = case filter_type do
      :all -> 
        load_recent_cases_paginated(socket.assigns.filter_agency, 1, socket.assigns.recent_activity_page_size)
      :cases ->
        # Load only cases
        filter = if socket.assigns.filter_agency, do: [agency_id: socket.assigns.filter_agency], else: []
        cases = EhsEnforcement.Enforcement.list_cases!(
          filter: filter,
          sort: [offence_action_date: :desc],
          load: [:offender, :agency]
        )
        paginated_cases = Enum.take(cases, socket.assigns.recent_activity_page_size)
        {paginated_cases, length(cases)}
      :notices ->
        # Load only notices
        filter = if socket.assigns.filter_agency, do: [agency_id: socket.assigns.filter_agency], else: []
        notices = EhsEnforcement.Enforcement.list_notices!(
          filter: filter,
          sort: [offence_action_date: :desc],
          load: [:offender, :agency]
        )
        paginated_notices = Enum.take(notices, socket.assigns.recent_activity_page_size)
        {paginated_notices, length(notices)}
    end
    
    recent_activity = format_cases_as_recent_activity(filtered_activity)
    
    {:noreply,
     socket
     |> assign(:recent_activity_filter, filter_type)
     |> assign(:recent_activity, recent_activity)
     |> assign(:recent_cases, filtered_activity)
     |> assign(:total_recent_cases, total_filtered_count)
     |> assign(:recent_activity_page, 1)}
  end

  @impl true
  def handle_event("export_data", %{"format" => format}, socket) do
    # In a real implementation, this would generate and download the file
    # For now, we'll just send a flash message
    {:noreply, put_flash(socket, :info, "Export to #{format} started")}
  end

  @impl true
  def handle_event("browse_recent_cases", _params, socket) do
    {:noreply, push_navigate(socket, to: "/cases?filter=recent&page=1")}
  end

  @impl true
  def handle_event("search_cases", _params, socket) do
    {:noreply, push_navigate(socket, to: "/cases?filter=search")}  
  end

  @impl true
  def handle_event("add_new_case", _params, socket) do
    current_user = socket.assigns[:current_user]
    
    # Check admin privileges
    case current_user do
      %{is_admin: true} ->
        {:noreply, push_navigate(socket, to: "/cases/new")}
      _ ->
        {:noreply, put_flash(socket, :error, "Admin privileges required to create new cases")}
    end
  end

  @impl true
  def handle_event("browse_active_notices", _params, socket) do
    {:noreply, push_navigate(socket, to: "/notices?filter=active&page=1")}
  end

  @impl true
  def handle_event("search_notices", _params, socket) do
    {:noreply, push_navigate(socket, to: "/notices?filter=search")}  
  end

  @impl true
  def handle_event("add_new_notice", _params, socket) do
    current_user = socket.assigns[:current_user]
    
    # Check admin privileges
    case current_user do
      %{is_admin: true} ->
        {:noreply, push_navigate(socket, to: "/notices/new")}
      _ ->
        {:noreply, put_flash(socket, :error, "Admin privileges required to create new notices")}
    end
  end

  @impl true
  def handle_event("navigate_to_new_case", _params, socket) do
    {:noreply, push_navigate(socket, to: "/cases/new")}
  end

  @impl true
  def handle_event("navigate_to_new_notice", _params, socket) do
    {:noreply, push_navigate(socket, to: "/notices/new")}
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
  def handle_event("export_data", _params, socket) do
    {:noreply, push_navigate(socket, to: "/reports")}
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
    # Handle sync completion with timestamp
    handle_info({:sync_complete, agency_code}, socket)
  end

  @impl true
  def handle_info({:sync_complete, agency_code}, socket) do
    # Reload data after sync
    agencies = Enforcement.list_agencies!()
    {recent_cases, total_recent_cases} = load_recent_cases_paginated(socket.assigns.filter_agency, socket.assigns.recent_activity_page, socket.assigns.recent_activity_page_size)
    recent_activity = format_cases_as_recent_activity(recent_cases)
    stats = calculate_stats(agencies, recent_cases, socket.assigns.time_period)
    
    sync_status = Map.put(socket.assigns.sync_status, agency_code, %{status: "completed", progress: 100})
    
    {:noreply,
     socket
     |> assign(:agencies, agencies)
     |> assign(:recent_cases, recent_cases)
     |> assign(:total_recent_cases, total_recent_cases)
     |> assign(:recent_activity, recent_activity)
     |> assign(:stats, stats)
     |> assign(:sync_status, sync_status)}
  end

  @impl true
  def handle_info({:sync_error, agency_code, error_message}, socket) do
    sync_status = Map.put(socket.assigns.sync_status, agency_code, %{status: "error", error: error_message})
    
    {:noreply, assign(socket, :sync_status, sync_status)}
  end

  @impl true
  def handle_info({:case_created, _case}, socket) do
    # Reload recent cases when a new case is created
    {recent_cases, total_recent_cases} = load_recent_cases_paginated(socket.assigns.filter_agency, socket.assigns.recent_activity_page, socket.assigns.recent_activity_page_size)
    recent_activity = format_cases_as_recent_activity(recent_cases)
    stats = calculate_stats(socket.assigns.agencies, recent_cases, socket.assigns.time_period)
    
    {:noreply,
     socket
     |> assign(:recent_cases, recent_cases)
     |> assign(:total_recent_cases, total_recent_cases)
     |> assign(:recent_activity, recent_activity)
     |> assign(:stats, stats)}
  end

  # Unused function commented out:
  # defp load_recent_cases(filter_agency \\ nil) do
  #   filter = if filter_agency, do: [agency_id: filter_agency], else: []
  #   Enforcement.list_cases!(
  #     filter: filter,
  #     sort: [offence_action_date: :desc],
  #     limit: 10,
  #     load: [:offender, :agency]
  #   )
  # end

  defp load_recent_cases_paginated(filter_agency, page, page_size) do
    filter = if filter_agency, do: [agency_id: filter_agency], else: []
    offset = (page - 1) * page_size
    
    try do
      # Load cases
      cases_query_opts = [
        filter: filter,
        sort: [offence_action_date: :desc],
        load: [:offender, :agency]
      ]
      cases = Enforcement.list_cases!(cases_query_opts)
      
      # Load notices  
      notices_query_opts = [
        filter: filter,
        sort: [offence_action_date: :desc],
        load: [:offender, :agency]
      ]
      notices = Enforcement.list_notices!(notices_query_opts)
      
      # Combine and sort by date, filtering out nil dates
      all_activity = (cases ++ notices)
      |> Enum.filter(fn record -> record.offence_action_date != nil end)
      |> Enum.sort_by(& &1.offence_action_date, {:desc, Date})
      
      # Calculate total count
      total_count = length(all_activity)
      
      # Apply pagination
      paginated_activity = all_activity
      |> Enum.drop(offset)
      |> Enum.take(page_size)
      
      {paginated_activity, total_count}
    rescue
      error ->
        require Logger
        Logger.error("Failed to load paginated recent activity: #{inspect(error)}")
        {[], 0}
    end
  end

  defp calculate_max_page(total_items, _page_size) when total_items <= 0, do: 1
  defp calculate_max_page(total_items, page_size) do
    ceil(total_items / page_size)
  end

  defp calculate_stats(agencies, _recent_cases, _period) do
    # Calculate date range (last 30 days)
    thirty_days_ago = Date.add(Date.utc_today(), -30)
    
    # Get all cases and notices (for comprehensive stats)
    all_cases = EhsEnforcement.Enforcement.list_cases!()
    all_notices = EhsEnforcement.Enforcement.list_notices!()
    
    # Filter for recent items (last 30 days)
    recent_cases_list = Enum.filter(all_cases, fn case_record ->
      case_record.offence_action_date && Date.compare(case_record.offence_action_date, thirty_days_ago) != :lt
    end)
    
    recent_notices_list = Enum.filter(all_notices, fn notice_record ->
      notice_record.offence_action_date && Date.compare(notice_record.offence_action_date, thirty_days_ago) != :lt
    end)
    
    recent_cases_count = length(recent_cases_list)
    recent_notices_count = length(recent_notices_list)
    
    # Calculate total fines from recent cases only
    recent_total_fines = recent_cases_list
    |> Enum.map(& &1.offence_fine || Decimal.new(0))
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
    
    # Get agency-specific stats for recent cases (last 30 days)
    agency_stats = Enum.map(agencies, fn agency ->
      agency_recent_cases = Enum.count(recent_cases_list, & &1.agency_id == agency.id)
      
      %{
        agency_id: agency.id,
        agency_code: agency.code,
        agency_name: agency.name,
        case_count: agency_recent_cases,
        percentage: if(recent_cases_count > 0, do: Float.round(agency_recent_cases / recent_cases_count * 100, 1), else: 0)
      }
    end)
    
    %{
      recent_cases: recent_cases_count,
      recent_notices: recent_notices_count,
      total_cases: length(all_cases),
      total_notices: length(all_notices),
      total_fines: recent_total_fines,
      active_agencies: Enum.count(agencies, & &1.enabled),
      agency_stats: agency_stats,
      period: "30 days", 
      timeframe: "Last 30 Days"
    }
  end

  defp format_cases_as_recent_activity(activity_records) do
    Enum.map(activity_records, fn record ->
      # Detect if this is a case or notice based on struct type
      is_case = match?(%EhsEnforcement.Enforcement.Case{}, record)
      
      # Safely access offender name from loaded association
      organization_name = case record.offender do
        %{name: name} when is_binary(name) -> name
        _ -> "Unknown Organization"
      end
      
      %{
        id: record.id,
        type: record.offence_action_type || if(is_case, do: "Court Case", else: "Enforcement Notice"),
        date: record.offence_action_date,
        organization: organization_name,
        description: record.offence_breaches || if(is_case, do: "Court case proceeding", else: "Enforcement notice issued"),
        fine_amount: if(is_case, do: Map.get(record, :offence_fine, nil), else: nil),
        agency_link: record.url,
        is_case: is_case
      }
    end)
  end
end