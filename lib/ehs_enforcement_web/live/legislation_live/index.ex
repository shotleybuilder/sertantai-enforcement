defmodule EhsEnforcementWeb.LegislationLive.Index do
  use EhsEnforcementWeb, :live_view
  
  require Ash.Query
  import Ash.Expr

  alias EhsEnforcement.Enforcement

  @default_page_size 20
  @max_page_size 100

  @impl true
  def mount(_params, _session, socket) do
    Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "legislation_updates")

    {:ok,
     socket
     |> assign(:filters, %{})
     |> assign(:sort_by, :legislation_year) 
     |> assign(:sort_dir, :desc)
     |> assign(:page, 1)
     |> assign(:page_size, @default_page_size)
     |> assign(:total_legislation, 0)
     |> assign(:loading, true)
     |> assign(:search_active, false)
     |> assign(:fuzzy_search, false)
     |> assign(:sort_requested, false)
     |> load_legislation(), temporary_assigns: [legislation: []]}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    
    filters = case params["filter"] do
      "search" ->
        socket.assigns.filters
      _ ->
        socket.assigns.filters
    end
    
    search_active = params["filter"] == "search"
    
    {:noreply, 
     socket
     |> assign(:page, max(1, page))
     |> assign(:filters, filters)
     |> assign(:search_active, search_active)
     |> load_legislation()}
  end

  @impl true
  def handle_event("filter", %{"filters" => filter_params}, socket) do
    filters = atomize_and_clean_filters(filter_params)
    
    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:page, 1)
     |> load_legislation()}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:filters, %{})
     |> assign(:page, 1)
     |> assign(:sort_requested, false)
     |> load_legislation()}
  end

  @impl true
  def handle_event("toggle_fuzzy_search", _params, socket) do
    fuzzy_search = !socket.assigns.fuzzy_search
    
    {:noreply,
     socket
     |> assign(:fuzzy_search, fuzzy_search)
     |> assign(:page, 1)
     |> load_legislation()}
  end

  @impl true
  def handle_event("sort", %{"field" => field, "direction" => direction}, socket) do
    sort_by = String.to_atom(field)
    sort_dir = String.to_atom(direction)
    
    {:noreply,
     socket
     |> assign(:sort_by, sort_by)
     |> assign(:sort_dir, sort_dir)
     |> assign(:page, 1)
     |> assign(:sort_requested, true)
     |> load_legislation()}
  end

  @impl true
  def handle_event("paginate", %{"page" => page_str}, socket) do
    case Integer.parse(page_str) do
      {page, _} when page > 0 ->
        total_pages = calculate_total_pages(socket.assigns.total_legislation, socket.assigns.page_size)
        valid_page = min(page, total_pages)
        
        {:noreply,
         socket
         |> assign(:page, valid_page)
         |> push_patch(to: ~p"/legislation?page=#{valid_page}")
         |> load_legislation()}
      
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_page_size", %{"page_size" => size_str}, socket) do
    case Integer.parse(size_str) do
      {size, _} when size > 0 and size <= @max_page_size ->
        {:noreply,
         socket
         |> assign(:page_size, size)
         |> assign(:page, 1)
         |> push_patch(to: ~p"/legislation")
         |> load_legislation()}
      
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_legislation", %{"legislation_id" => legislation_id}, socket) do
    case Ash.get(Enforcement.Legislation, legislation_id, actor: socket.assigns.current_user) do
      {:ok, legislation_record} ->
        case Ash.destroy(legislation_record, actor: socket.assigns.current_user) do
          :ok ->
            {:noreply,
             socket
             |> put_flash(:info, "Legislation deleted successfully")
             |> load_legislation()}
          
          {:error, error} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to delete legislation: #{inspect(error)}")}
        end
      
      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Legislation not found")}
    end
  end

  @impl true
  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:legislation_created, _legislation}, socket) do
    {:noreply, load_legislation(socket)}
  end

  @impl true
  def handle_info({:legislation_updated, _legislation}, socket) do
    {:noreply, load_legislation(socket)}
  end

  @impl true
  def handle_info({:legislation_deleted, _legislation}, socket) do
    {:noreply, load_legislation(socket)}
  end

  defp load_legislation(socket) do
    %{filters: filters, sort_by: sort_by, sort_dir: sort_dir, page: page, page_size: page_size, fuzzy_search: fuzzy_search, sort_requested: sort_requested} = socket.assigns
    
    try do
      if map_size(filters) == 0 && !sort_requested do
        socket
        |> assign(:legislation, [])
        |> assign(:total_legislation, 0)
        |> assign(:loading, false)
      else
        search_query = filters[:search]
        use_fuzzy = fuzzy_search && is_binary(search_query) && String.trim(search_query) != ""
        
        {legislation, total_legislation} = if use_fuzzy do
          trimmed_query = String.trim(search_query)
          limited_query = if String.length(trimmed_query) > 100 do
            String.slice(trimmed_query, 0, 100)
          else
            trimmed_query
          end
          
          offset = (page - 1) * page_size
          fuzzy_opts = [
            limit: page_size,
            offset: offset
          ]
          
          {:ok, fuzzy_results} = Enforcement.search_legislation_title(limited_query, fuzzy_opts)
          
          estimated_total = if length(fuzzy_results) == page_size do
            (page * page_size) + 1
          else
            offset + length(fuzzy_results)
          end
          
          {fuzzy_results, estimated_total}
        else
          query_opts = build_query_options(filters, sort_by, sort_dir, page, page_size)
          regular_results = Enforcement.list_legislation(query_opts)
          
          count_opts = [filter: build_filter(filters)]
          regular_total = case Ash.count(Enforcement.Legislation, count_opts) do
            {:ok, count} -> count
            {:error, _} -> 0
          end
          
          case regular_results do
            {:ok, results} -> {results, regular_total}
            {:error, _} -> {[], 0}
          end
        end
        
        socket
        |> assign(:legislation, legislation)
        |> assign(:total_legislation, total_legislation)
        |> assign(:loading, false)
        |> assign(:sort_requested, false)
      end
      
    rescue
      error ->
        require Logger
        Logger.error("Failed to load legislation: #{inspect(error)}")
        
        socket
        |> assign(:legislation, [])
        |> assign(:total_legislation, 0)
        |> assign(:loading, false)
    end
  end

  defp build_query_options(filters, sort_by, sort_dir, page, page_size) do
    offset = (page - 1) * page_size
    
    [
      filter: build_filter(filters),
      sort: build_sort_options(sort_by, sort_dir),
      limit: page_size,
      offset: offset
    ]
  end

  defp build_filter(filters) do
    %{}
    |> add_filter_if_present(filters, :legislation_type)
    |> add_year_range_filters(filters)
    |> add_search_filter(filters)
  end
  
  defp add_filter_if_present(acc, filters, key) do
    case filters[key] do
      value when is_binary(value) and value != "" -> 
        atom_value = if key == :legislation_type, do: String.to_atom(value), else: value
        Map.put(acc, key, atom_value)
      _ -> acc
    end
  end
  
  defp add_year_range_filters(acc, filters) do
    year_conditions = []
    
    year_conditions = case filters[:year_from] do
      year when is_binary(year) and year != "" ->
        case Integer.parse(year) do
          {parsed_year, _} -> [{:greater_than_or_equal_to, parsed_year} | year_conditions]
          _ -> year_conditions
        end
      _ -> year_conditions
    end
    
    year_conditions = case filters[:year_to] do
      year when is_binary(year) and year != "" ->
        case Integer.parse(year) do
          {parsed_year, _} -> [{:less_than_or_equal_to, parsed_year} | year_conditions]
          _ -> year_conditions
        end
      _ -> year_conditions
    end
    
    if year_conditions != [] do
      Map.put(acc, :legislation_year, year_conditions)
    else
      acc
    end
  end
  
  defp add_search_filter(acc, filters) do
    case filters[:search] do
      query when is_binary(query) and query != "" ->
        trimmed_query = String.trim(query)
        
        limited_query = if String.length(trimmed_query) > 100 do
          String.slice(trimmed_query, 0, 100)
        else
          trimmed_query
        end
        
        search_pattern = "%#{limited_query}%"
        Map.put(acc, :search, search_pattern)
      _ -> acc
    end
  end

  defp build_sort_options(sort_by, sort_dir) do
    case {sort_by, sort_dir} do
      {field, dir} when field in [:legislation_title, :legislation_year, :legislation_type] ->
        [{field, dir}]
      
      _ ->
        [legislation_year: :desc]
    end
  end

  defp atomize_and_clean_filters(filter_params) do
    filter_params
    |> Enum.reduce(%{}, fn
      {key, value}, acc when is_binary(value) ->
        atom_key = String.to_atom(key)
        cleaned_value = String.trim(value)
        
        if cleaned_value != "" do
          Map.put(acc, atom_key, cleaned_value)
        else
          acc
        end
      
      _, acc -> acc
    end)
  end

  defp calculate_total_pages(0, _page_size), do: 1
  defp calculate_total_pages(total_legislation, page_size) do
    ceil(total_legislation / page_size)
  end

  defp format_legislation_type(:act), do: "Act"
  defp format_legislation_type(:regulation), do: "Regulation"
  defp format_legislation_type(:order), do: "Order"
  defp format_legislation_type(:acop), do: "ACOP"
  defp format_legislation_type(type) when is_atom(type), do: String.capitalize(to_string(type))
  defp format_legislation_type(_), do: "Unknown"

  defp page_range(current_page, total_pages, delta \\ 2) do
    start_page = max(1, current_page - delta)
    end_page = min(total_pages, current_page + delta)
    
    Enum.to_list(start_page..end_page)
  end
end