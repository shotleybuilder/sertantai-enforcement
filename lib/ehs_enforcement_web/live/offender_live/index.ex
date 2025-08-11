defmodule EhsEnforcementWeb.OffenderLive.Index do
  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement

  require Ash.Query

  @per_page 20

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to real-time updates
    Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "offender:updates")
    Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case_created")
    Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "notice_created")

    socket =
      socket
      |> assign(:page_title, "Offender Management")
      |> assign(:loading, true)
      |> assign(:offenders, [])
      |> assign(:total_count, 0)
      |> assign(:current_page, 1)
      |> assign(:per_page, @per_page)
      |> assign(:filters, %{})
      |> assign(:search_query, "")
      |> assign(:sort_by, "total_fines")
      |> assign(:sort_order, "desc")
      |> assign(:industry_stats, %{})
      |> assign(:top_offenders, [])
      |> assign(:repeat_offender_percentage, 0)
      |> load_offenders()

    {:ok, socket, temporary_assigns: [offenders: []]}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = apply_params(socket, params)
    {:noreply, load_offenders(socket)}
  end

  @impl true
  def handle_event("filter_change", %{"filters" => filter_params}, socket) do
    filters = parse_filters(filter_params)
    require Logger
    Logger.info("Filter change: #{inspect(filter_params)} -> #{inspect(filters)}")
    
    socket =
      socket
      |> assign(:filters, filters)
      |> assign(:current_page, 1)
      |> assign(:loading, true)
      |> load_offenders()

    {:noreply, socket}
  end

  # Handle form change event (default form behavior)
  @impl true
  def handle_event("validate", %{"filters" => filter_params}, socket) do
    handle_event("filter_change", %{"filters" => filter_params}, socket)
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:current_page, 1)
      |> assign(:loading, true)
      |> push_patch(to: build_path(socket, socket.assigns.filters, query, 1))

    {:noreply, socket}
  end

  @impl true  
  def handle_event("sort", params, socket) do
    {sort_by, sort_order} = case params do
      %{"sort_by" => sort_by, "sort_order" => sort_order} -> {sort_by, sort_order}
      %{"sort_by" => sort_by} -> {sort_by, socket.assigns.sort_order}
      %{"sort_order" => sort_order} -> {socket.assigns.sort_by, sort_order}
      _ -> {socket.assigns.sort_by, socket.assigns.sort_order}
    end

    socket =
      socket
      |> assign(:sort_by, sort_by)
      |> assign(:sort_order, sort_order)
      |> assign(:loading, true)

    {:noreply, load_offenders(socket)}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    next_page = socket.assigns.current_page + 1
    max_page = max_pages(socket.assigns.total_count, socket.assigns.per_page)
    
    if next_page <= max_page do
      socket =
        socket
        |> assign(:current_page, next_page)
        |> assign(:loading, true)
        |> push_patch(to: build_path(socket, socket.assigns.filters, socket.assigns.search_query, next_page))
      
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    prev_page = max(socket.assigns.current_page - 1, 1)
    
    socket =
      socket
      |> assign(:current_page, prev_page)
      |> assign(:loading, true)
      |> push_patch(to: build_path(socket, socket.assigns.filters, socket.assigns.search_query, prev_page))
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("export_csv", _params, socket) do
    csv_data = generate_csv(socket.assigns.offenders)
    
    socket =
      socket
      |> push_event("download_csv", %{
        data: csv_data,
        filename: "offenders_#{Date.utc_today()}.csv"
      })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:case_created, _case_record}, socket) do
    {:noreply, refresh_offender_stats(socket)}
  end

  @impl true
  def handle_info({:notice_created, _notice_record}, socket) do
    {:noreply, refresh_offender_stats(socket)}
  end

  @impl true
  def handle_info({:offender_updated, _offender}, socket) do
    {:noreply, refresh_offender_stats(socket)}
  end

  # Private functions

  defp apply_params(socket, params) do
    filters = parse_filters(params["filters"] || %{})
    search_query = params["search"] || ""
    page = String.to_integer(params["page"] || "1")
    sort_by = params["sort_by"] || "total_fines"
    sort_order = params["sort_order"] || "desc"

    socket
    |> assign(:filters, filters)
    |> assign(:search_query, search_query)
    |> assign(:current_page, page)
    |> assign(:sort_by, sort_by)
    |> assign(:sort_order, sort_order)
  end

  defp parse_filters(filter_params) do
    %{}
    |> maybe_add_filter(:industry, filter_params["industry"])
    |> maybe_add_filter(:local_authority, filter_params["local_authority"])
    |> maybe_add_filter(:business_type, filter_params["business_type"])
    |> maybe_add_filter(:repeat_only, filter_params["repeat_only"])
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value) when key == :repeat_only do
    case value do
      "true" -> Map.put(filters, key, true)
      true -> Map.put(filters, key, true)
      _ -> filters
    end
  end
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp load_offenders(socket) do
    offset = (socket.assigns.current_page - 1) * socket.assigns.per_page
    
    # Build simpler query for testing
    base_query = EhsEnforcement.Enforcement.Offender
    |> Ash.Query.sort([{String.to_atom(socket.assigns.sort_by), String.to_atom(socket.assigns.sort_order)}])
    |> Ash.Query.limit(socket.assigns.per_page)
    |> Ash.Query.offset(offset)
    
    # Apply filters one by one
    query = base_query
    |> apply_industry_filter(socket.assigns.filters[:industry])
    |> apply_authority_filter(socket.assigns.filters[:local_authority])
    |> apply_business_type_filter(socket.assigns.filters[:business_type])
    |> apply_repeat_filter(socket.assigns.filters[:repeat_only])
    |> apply_search_filter(socket.assigns.search_query)

    try do
      # Use direct Ash.read with the built query
      offenders = case Ash.read(query) do
        {:ok, offenders} -> offenders
        {:error, _} -> []
      end
      
      # Get total count using code interface
      total_count = case socket.assigns.filters do
        filters when map_size(filters) == 0 ->
          Enforcement.count_offenders!()
        _ ->
          length(offenders) # Simplified for now
      end
      
      # Calculate analytics
      industry_stats = calculate_industry_stats()
      top_offenders = get_top_offenders()
      repeat_percentage = calculate_repeat_offender_percentage()

      socket
      |> assign(:offenders, offenders)
      |> assign(:total_count, total_count)
      |> assign(:industry_stats, industry_stats)
      |> assign(:top_offenders, top_offenders)
      |> assign(:repeat_offender_percentage, repeat_percentage)
      |> assign(:loading, false)
    rescue
      error ->
        require Logger
        Logger.error("Failed to load offenders: #{inspect(error)}")
        
        socket
        |> assign(:offenders, [])
        |> assign(:total_count, 0)
        |> assign(:loading, false)
        |> put_flash(:error, "Failed to load offenders: #{Exception.message(error)}")
    end
  end

  # Individual filter functions that work with Ash.Query
  defp apply_industry_filter(query, nil), do: query
  defp apply_industry_filter(query, ""), do: query
  defp apply_industry_filter(query, industry_name) do
    require Logger
    Logger.info("Applying industry filter: #{industry_name}")
    query |> Ash.Query.filter(industry == ^industry_name)
  end

  defp apply_authority_filter(query, nil), do: query
  defp apply_authority_filter(query, ""), do: query
  defp apply_authority_filter(query, authority_name) do
    query |> Ash.Query.filter(local_authority == ^authority_name)
  end

  defp apply_business_type_filter(query, nil), do: query
  defp apply_business_type_filter(query, ""), do: query
  defp apply_business_type_filter(query, business_type) do
    type_atom = String.to_atom(business_type)
    query |> Ash.Query.filter(business_type == ^type_atom)
  end

  defp apply_repeat_filter(query, nil), do: query
  defp apply_repeat_filter(query, false), do: query
  defp apply_repeat_filter(query, true) do
    # Repeat offenders have more than 2 total cases + notices
    query |> Ash.Query.filter(total_cases + total_notices > 2)
  end

  defp apply_search_filter(query, nil), do: query
  defp apply_search_filter(query, ""), do: query
  defp apply_search_filter(query, search_query) do
    query |> Ash.Query.filter(
      name |> ilike("%#{^search_query}%") or
      postcode |> ilike("%#{^search_query}%") or 
      main_activity |> ilike("%#{^search_query}%")
    )
  end


  defp calculate_industry_stats do
    try do
      offenders = Enforcement.list_offenders!()
      
      offenders
      |> Enum.group_by(& &1.industry)
      |> Enum.map(fn {industry, group} ->
        total_fines = Enum.reduce(group, Decimal.new(0), fn offender, acc ->
          Decimal.add(acc, offender.total_fines || Decimal.new(0))
        end)
        
        {industry || "Unknown", %{
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
      Enforcement.list_offenders!([
        sort: [total_fines: :desc],
        limit: 10
      ])
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

  defp build_path(socket, filters, search_query, page) do
    params = %{}
    
    params = if filters != %{}, do: Map.put(params, "filters", filters), else: params
    params = if search_query != "", do: Map.put(params, "search", search_query), else: params
    params = if page != 1, do: Map.put(params, "page", page), else: params
    params = Map.put(params, "sort_by", socket.assigns.sort_by)
    params = Map.put(params, "sort_order", socket.assigns.sort_order)

    ~p"/offenders?#{params}"
  end

  defp max_pages(total_count, per_page) do
    ceil(total_count / per_page)
  end

  defp refresh_offender_stats(socket) do
    # Reload current page data
    load_offenders(socket)
  end

  defp is_repeat_offender?(offender) do
    total_enforcement = (offender.total_cases || 0) + (offender.total_notices || 0)
    total_enforcement > 2
  end

  defp format_currency(nil), do: "£0"
  defp format_currency(amount) when is_binary(amount) do
    case Decimal.parse(amount) do
      {decimal, _} -> format_currency(decimal)
      :error -> "£0"
    end
  end
  defp format_currency(%Decimal{} = amount) do
    "£#{Decimal.to_string(amount)}"
  end
  defp format_currency(amount) when is_integer(amount) do
    "£#{amount}"
  end

  defp generate_csv(offenders) do
    headers = "Name,Local Authority,Industry,Total Cases,Total Notices,Total Fines,First Seen,Last Seen"
    
    rows = Enum.map(offenders, fn offender ->
      [
        offender.name || "",
        offender.local_authority || "",
        offender.industry || "",
        to_string(offender.total_cases || 0),
        to_string(offender.total_notices || 0),
        Decimal.to_string(offender.total_fines || Decimal.new(0)),
        format_date(offender.first_seen_date),
        format_date(offender.last_seen_date)
      ]
      |> Enum.join(",")
    end)
    
    [headers | rows]
    |> Enum.join("\n")
  end

  defp format_date(nil), do: ""
  defp format_date(date), do: Date.to_string(date)
end