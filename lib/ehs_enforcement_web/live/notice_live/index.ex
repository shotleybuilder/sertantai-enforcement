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
    query_opts = build_query_opts(socket)
    
    case Enforcement.list_notices(query_opts) do
      {:ok, %Ash.Page.Offset{results: notices, count: count}} ->
        socket
        |> assign(:notices, notices)
        |> assign(:total_notices, count || length(notices))
        |> assign(:loading, false)
        
      {:ok, notices} when is_list(notices) ->
        total = count_notices(socket)
        
        socket
        |> assign(:notices, notices)
        |> assign(:total_notices, total)
        |> assign(:loading, false)
      
      {:error, _error} ->
        socket
        |> assign(:notices, [])
        |> assign(:total_notices, 0)
        |> assign(:loading, false)
        |> put_flash(:error, "Failed to load notices")
    end
  end

  defp build_query_opts(socket) do
    %{
      filters: socket.assigns.filters,
      search_query: socket.assigns.search_query,
      sort_by: socket.assigns.sort_by,
      sort_order: socket.assigns.sort_order,
      page: socket.assigns.page,
      page_size: socket.assigns.page_size
    }
    |> build_ash_query_opts()
  end

  defp build_ash_query_opts(params) do
    opts = []
    
    # Build filter
    filter = build_filter(params.filters, params.search_query)
    opts = if filter != [], do: [{:filter, filter} | opts], else: opts
    
    # Add sort
    sort = [{params.sort_by, params.sort_order}]
    opts = [{:sort, sort} | opts]
    
    # Add pagination
    offset = (params.page - 1) * params.page_size
    opts = [{:page, [limit: params.page_size, offset: offset]} | opts]
    
    # Load relationships
    [{:load, [:agency, :offender]} | opts]
  end

  defp build_filter(filters, search_query) do
    filter = []
    
    # Add filters
    filter = if filters[:agency_id], do: [{:agency_id, filters[:agency_id]} | filter], else: filter
    filter = if filters[:offence_action_type], do: [{:offence_action_type, filters[:offence_action_type]} | filter], else: filter
    
    # Add date range filters
    filter = if filters[:date_from] do
      case Date.from_iso8601(filters[:date_from]) do
        {:ok, date} -> [{:notice_date, {:>=, date}} | filter]
        {:error, _} -> filter  # Ignore invalid dates
      end
    else
      filter
    end
    
    filter = if filters[:date_to] do
      case Date.from_iso8601(filters[:date_to]) do
        {:ok, date} -> [{:notice_date, {:<=, date}} | filter]
        {:error, _} -> filter  # Ignore invalid dates
      end
    else
      filter
    end
    
    # Add compliance status filter
    filter = if filters[:compliance_status] do
      add_compliance_filter(filter, filters[:compliance_status])
    else
      filter
    end
    
    # Add region filter
    filter = if filters[:region] do
      # This requires a join with offender
      [{:offender, {:local_authority, {:ilike, "%#{filters[:region]}%"}}} | filter]
    else
      filter
    end
    
    # Add search
    if search_query != "" do
      search_filter = [
        or: [
          [regulator_id: [ilike: "%#{search_query}%"]],
          [notice_body: [ilike: "%#{search_query}%"]],
          [offender: [name: [ilike: "%#{search_query}%"]]]
        ]
      ]
      search_filter ++ filter
    else
      filter
    end
  end

  defp add_compliance_filter(filter, status) do
    today = Date.utc_today()
    
    case status do
      "pending" ->
        [{:compliance_date, {:>, today}} | filter]
      
      "overdue" ->
        [{:compliance_date, {:<=, today}} | filter]
      
      _ ->
        filter
    end
  end

  defp count_notices(socket) do
    filter = build_filter(socket.assigns.filters, socket.assigns.search_query)
    query_opts = if filter != [], do: [filter: filter], else: []
    
    # Use code interface for counting
    try do
      Enforcement.count_notices!(query_opts)
    rescue
      _ -> 0
    end
  end

  defp parse_filters(params) do
    %{}
    |> parse_if_present(params, "agency_id")
    |> parse_if_present(params, "offence_action_type")
    |> parse_if_present(params, "date_from")
    |> parse_if_present(params, "date_to")
    |> parse_if_present(params, "compliance_status")
    |> parse_if_present(params, "region")
  end

  defp parse_if_present(filters, params, key) do
    case Map.get(params, key) do
      nil -> filters
      "" -> filters
      value -> Map.put(filters, String.to_atom(key), value)
    end
  end

  defp apply_params(socket, _params) do
    socket
    # TODO: Apply URL params if needed
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

  defp compliance_status(notice) do
    today = Date.utc_today()
    
    cond do
      is_nil(notice.compliance_date) -> "N/A"
      Date.compare(notice.compliance_date, today) == :gt -> "pending"
      true -> "overdue"
    end
  end

  defp compliance_status_class(notice) do
    case compliance_status(notice) do
      "pending" -> "text-yellow-600"
      "overdue" -> "text-red-600"
      _ -> "text-gray-600"
    end
  end

  defp notice_type_class(type) do
    case type do
      "Improvement Notice" -> "bg-yellow-100 text-yellow-800"
      "Prohibition Notice" -> "bg-red-100 text-red-800"
      "Enforcement Notice" -> "bg-blue-100 text-blue-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
end