defmodule EhsEnforcementWeb.NoticeLive.Index do
  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement
  alias Phoenix.PubSub

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(EhsEnforcement.PubSub, "notice:created")
      PubSub.subscribe(EhsEnforcement.PubSub, "notice:updated")
    end

    {:ok,
     socket
     |> assign(:page_title, "Notice Management")
     |> assign(:notices, [])
     |> assign(:loading, true)
     |> assign(:filters, %{})
     |> assign(:search_query, "")
     |> assign(:sort_by, :notice_date)
     |> assign(:sort_order, :desc)
     |> assign(:page, 1)
     |> assign(:page_size, 20)
     |> assign(:total_notices, 0)
     |> assign(:view_mode, :table)
     |> assign(:search_active, false)
     |> assign(:agencies, load_agencies())
     |> load_notices()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_params(socket, params)}
  end

  @impl true
  def handle_event("filter", %{"filters" => filter_params}, socket) do
    filters = parse_filters(filter_params)
    
    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:page, 1)
     |> load_notices()}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:filters, %{})
     |> assign(:search_query, "")
     |> assign(:page, 1)
     |> load_notices()}
  end

  @impl true
  def handle_event("search", %{"search" => search_query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, search_query)
     |> assign(:page, 1)
     |> load_notices()}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:page, 1)
     |> load_notices()}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    field_atom = String.to_atom(field)
    
    {sort_by, sort_order} =
      if socket.assigns.sort_by == field_atom do
        # Toggle order if same field
        {field_atom, if(socket.assigns.sort_order == :desc, do: :asc, else: :desc)}
      else
        # Default to descending for new field
        {field_atom, :desc}
      end
    
    {:noreply,
     socket
     |> assign(:sort_by, sort_by)
     |> assign(:sort_order, sort_order)
     |> load_notices()}
  end

  @impl true
  def handle_event("change_view", %{"view" => view}, socket) do
    view_mode = String.to_atom(view)
    
    {:noreply,
     socket
     |> assign(:view_mode, view_mode)}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page_num = String.to_integer(page)
    
    {:noreply,
     socket
     |> assign(:page, page_num)
     |> load_notices()}
  end

  @impl true
  def handle_event("change_page_size", %{"page_size" => page_size}, socket) do
    size = String.to_integer(page_size)
    
    {:noreply,
     socket
     |> assign(:page_size, size)
     |> assign(:page, 1)
     |> load_notices()}
  end

  @impl true
  def handle_event("export", %{"format" => _format}, socket) do
    # TODO: Implement export functionality
    {:noreply, put_flash(socket, :info, "Export functionality coming soon")}
  end

  @impl true
  def handle_info({:notice_created, _notice}, socket) do
    {:noreply, load_notices(socket)}
  end

  @impl true
  def handle_info({:notice_updated, _notice}, socket) do
    {:noreply, load_notices(socket)}
  end

  @impl true
  def handle_info(_msg, socket) do
    # Catch-all for any other messages
    {:noreply, socket}
  end

  # Private functions

  defp load_notices(socket) do
    query_opts = build_optimized_query_opts(socket)
    
    try do
      # Use optimized filtering function that leverages composite indexes
      notices = Enforcement.list_notices_with_filters!(query_opts)
      
      # Get total count using same optimized filter
      filter = build_optimized_notice_filter(socket)
      total = Enforcement.count_notices!([filter: filter])
      
      socket
      |> assign(:notices, notices)
      |> assign(:total_notices, total)
      |> assign(:loading, false)
    rescue
      error ->
        socket
        |> assign(:notices, [])
        |> assign(:total_notices, 0)
        |> assign(:loading, false)
        |> put_flash(:error, "Failed to load notices: #{inspect(error)}")
    end
  end

  defp build_optimized_query_opts(socket) do
    %{sort_by: sort_by, sort_order: sort_order, 
      page: page, page_size: page_size} = socket.assigns
    
    offset = (page - 1) * page_size
    
    [
      filter: build_optimized_notice_filter(socket),
      sort: [{sort_by, sort_order}],
      limit: page_size,
      offset: offset,
      load: [:agency, :offender]
    ]
  end

  defp build_optimized_notice_filter(socket) do
    filters = socket.assigns.filters
    search_query = socket.assigns.search_query
    
    %{}
    |> add_notice_filter_if_present(filters, :agency_id)
    |> add_notice_filter_if_present(filters, :offence_action_type)
    |> add_notice_date_filters(filters)
    |> add_notice_search_filter(search_query)
  end
  
  defp add_notice_filter_if_present(acc, filters, key) do
    case filters[key] do
      value when is_binary(value) and value != "" -> Map.put(acc, key, value)
      _ -> acc
    end
  end
  
  defp add_notice_date_filters(acc, filters) do
    acc
    |> add_date_from_filter(filters)
    |> add_date_to_filter(filters)
  end
  
  defp add_date_from_filter(acc, filters) do
    case filters[:date_from] do
      date when is_binary(date) and date != "" ->
        case Date.from_iso8601(date) do
          {:ok, parsed_date} -> Map.put(acc, :date_from, parsed_date)
          _ -> acc
        end
      _ -> acc
    end
  end
  
  defp add_date_to_filter(acc, filters) do
    case filters[:date_to] do
      date when is_binary(date) and date != "" ->
        case Date.from_iso8601(date) do
          {:ok, parsed_date} -> Map.put(acc, :date_to, parsed_date)
          _ -> acc
        end
      _ -> acc
    end
  end
  
  defp add_notice_search_filter(acc, search_query) do
    if search_query != "" do
      Map.put(acc, :search, "%#{search_query}%")
    else
      acc
    end
  end



  defp parse_filters(params) do
    %{}
    |> parse_if_present(params, "agency_id")
    |> parse_if_present(params, "offence_action_type")
    |> parse_if_present(params, "date_from")
    |> parse_if_present(params, "date_to")
    |> parse_if_present(params, "region")
  end

  defp parse_if_present(filters, params, key) do
    case Map.get(params, key) do
      nil -> filters
      "" -> filters
      value -> Map.put(filters, String.to_atom(key), value)
    end
  end

  defp apply_params(socket, params) do
    page = String.to_integer(params["page"] || "1")
    
    # Handle filter parameters from dashboard navigation
    filters = case params["filter"] do
      "recent" ->
        # Calculate date based on period parameter from dashboard
        days_ago = case params["period"] do
          "week" -> 7
          "month" -> 30
          "year" -> 365
          _ -> 30  # default to month
        end
        date_from = Date.add(Date.utc_today(), -days_ago)
        %{date_from: Date.to_iso8601(date_from)}
      "search" ->
        # Show advanced search interface activated
        socket.assigns.filters
      _ ->
        socket.assigns.filters
    end
    
    # Handle search activation from dashboard
    search_active = params["filter"] == "search"
    
    socket
    |> assign(:page, max(1, page))
    |> assign(:filters, filters)
    |> assign(:search_active, search_active || socket.assigns[:search_active] || false)
    |> load_notices()
  end

  defp load_agencies do
    Enforcement.list_agencies!()
  end

  defp total_pages(total, page_size) do
    ceil(total / page_size)
  end

  defp get_sort_icon(assigns, field) do
    field_atom = String.to_atom(field)
    
    if assigns.sort_by == field_atom do
      if assigns.sort_order == :asc do
        "▲"
      else
        "▼"
      end
    else
      ""
    end
  end

  defp format_date(nil), do: ""
  defp format_date(date), do: Calendar.strftime(date, "%d %B %Y")

  defp notice_type_class(type) do
    case type do
      "Improvement Notice" -> "bg-yellow-100 text-yellow-800"
      "Prohibition Notice" -> "bg-red-100 text-red-800"
      "Enforcement Notice" -> "bg-blue-100 text-blue-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
end