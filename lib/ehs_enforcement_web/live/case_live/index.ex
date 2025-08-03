defmodule EhsEnforcementWeb.CaseLive.Index do
  use EhsEnforcementWeb, :live_view
  
  require Ash.Query

  alias EhsEnforcement.Enforcement
  # alias EhsEnforcementWeb.Components.CaseFilter  # Unused alias removed

  @default_page_size 20
  @max_page_size 100

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to real-time updates from Ash pub_sub
    # Note: Ash pub_sub publishes to topics like "case:created:#{id}"
    # We use a broader subscription for list views
    Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case_updates")

    {:ok,
     socket
     |> assign(:agencies, Enforcement.list_agencies!())
     |> assign(:filters, %{})
     |> assign(:sort_by, :offence_action_date) 
     |> assign(:sort_dir, :desc)
     |> assign(:page, 1)
     |> assign(:page_size, @default_page_size)
     |> assign(:total_cases, 0)
     |> assign(:loading, true)
     |> assign(:search_active, false)
     |> load_cases(), temporary_assigns: [cases: []]}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    
    # Handle filter parameters from dashboard navigation
    filters = case params["filter"] do
      "recent" ->
        thirty_days_ago = Date.add(Date.utc_today(), -30)
        %{date_from: Date.to_iso8601(thirty_days_ago)}
      "search" ->
        # Show advanced search interface activated
        socket.assigns.filters
      _ ->
        socket.assigns.filters
    end
    
    # Handle search activation from dashboard
    search_active = params["filter"] == "search"
    
    {:noreply, 
     socket
     |> assign(:page, max(1, page))
     |> assign(:filters, filters)
     |> assign(:search_active, search_active)
     |> load_cases()}
  end

  @impl true
  def handle_event("filter", %{"filters" => filter_params}, socket) do
    filters = atomize_and_clean_filters(filter_params)
    
    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:page, 1)  # Reset to first page when filtering
     |> load_cases()}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:filters, %{})
     |> assign(:page, 1)
     |> load_cases()}
  end

  @impl true
  def handle_event("sort", %{"field" => field, "direction" => direction}, socket) do
    sort_by = String.to_atom(field)
    sort_dir = String.to_atom(direction)
    
    {:noreply,
     socket
     |> assign(:sort_by, sort_by)
     |> assign(:sort_dir, sort_dir)
     |> assign(:page, 1)  # Reset to first page when sorting
     |> load_cases()}
  end

  @impl true
  def handle_event("paginate", %{"page" => page_str}, socket) do
    case Integer.parse(page_str) do
      {page, _} when page > 0 ->
        total_pages = calculate_total_pages(socket.assigns.total_cases, socket.assigns.page_size)
        valid_page = min(page, total_pages)
        
        {:noreply,
         socket
         |> assign(:page, valid_page)
         |> push_patch(to: ~p"/cases?page=#{valid_page}")
         |> load_cases()}
      
      _ ->
        # Invalid page number, stay on current page
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
         |> assign(:page, 1)  # Reset to first page
         |> push_patch(to: ~p"/cases")
         |> load_cases()}
      
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("export_csv", _params, socket) do
    alias EhsEnforcementWeb.CaseLive.CSVExport
    
    case CSVExport.export_cases(socket.assigns.filters, socket.assigns.sort_by, socket.assigns.sort_dir) do
      {:ok, csv_content} ->
        filename = CSVExport.generate_filename(:filtered)
        
        {:noreply,
         socket
         |> push_event("download", %{
           filename: filename,
           content: csv_content,
           mime_type: "text/csv"
         })}
      
      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to export cases: #{reason}")}
    end
  end

  @impl true
  def handle_event(_event, _params, socket) do
    # Catch-all for unknown events
    {:noreply, socket}
  end

  # Handle real-time updates
  @impl true
  def handle_info({:case_created, _case}, socket) do
    {:noreply, load_cases(socket)}
  end

  @impl true
  def handle_info({:case_updated, _case}, socket) do
    {:noreply, load_cases(socket)}
  end

  @impl true
  def handle_info({:case_deleted, _case}, socket) do
    {:noreply, load_cases(socket)}
  end

  # Private functions

  defp load_cases(socket) do
    %{filters: filters, sort_by: sort_by, sort_dir: sort_dir, page: page, page_size: page_size} = socket.assigns
    
    try do
      # Build query options
      query_opts = build_query_options(filters, sort_by, sort_dir, page, page_size)
      
      # Load cases with associations
      cases = Enforcement.list_cases!(query_opts)
      
      # Get total count for pagination
      count_opts = [filter: build_ash_filter(filters)]
      total_cases = Enforcement.count_cases!(count_opts)
      
      socket
      |> assign(:cases, cases)
      |> assign(:total_cases, total_cases)
      |> assign(:loading, false)
      
    rescue
      error ->
        # Log error and show empty state
        require Logger
        Logger.error("Failed to load cases: #{inspect(error)}")
        
        socket
        |> assign(:cases, [])
        |> assign(:total_cases, 0)
        |> assign(:loading, false)
    end
  end

  defp build_query_options(filters, sort_by, sort_dir, page, page_size) do
    offset = (page - 1) * page_size
    
    [
      filter: build_ash_filter(filters),
      sort: build_sort_options(sort_by, sort_dir),
      page: [limit: page_size, offset: offset],
      load: [:offender, :agency]
    ]
  end

  defp build_ash_filter(filters) do
    Enum.reduce(filters, [], fn
      {:agency_id, id}, acc when is_binary(id) and id != "" ->
        [{:agency_id, id} | acc]
      
      {:date_from, date}, acc when is_binary(date) and date != "" ->
        case Date.from_iso8601(date) do
          {:ok, parsed_date} -> [{:offence_action_date, [greater_than_or_equal_to: parsed_date]} | acc]
          _ -> acc
        end
      
      {:date_to, date}, acc when is_binary(date) and date != "" ->
        case Date.from_iso8601(date) do
          {:ok, parsed_date} -> [{:offence_action_date, [less_than_or_equal_to: parsed_date]} | acc]
          _ -> acc
        end
      
      {:min_fine, amount}, acc when is_binary(amount) and amount != "" ->
        case Decimal.parse(amount) do
          {decimal_amount, _} -> [{:offence_fine, [greater_than_or_equal_to: decimal_amount]} | acc]
          :error -> acc
        end
      
      {:max_fine, amount}, acc when is_binary(amount) and amount != "" ->
        case Decimal.parse(amount) do
          {decimal_amount, _} -> [{:offence_fine, [less_than_or_equal_to: decimal_amount]} | acc]
          :error -> acc
        end
      
      {:search, query}, acc when is_binary(query) and query != "" ->
        # Implement search across multiple fields
        # Search in: offender name, case regulator_id, and offence_breaches
        trimmed_query = String.trim(query)
        
        # Limit search term length to prevent database issues
        limited_query = if String.length(trimmed_query) > 100 do
          String.slice(trimmed_query, 0, 100)
        else
          trimmed_query
        end
        
        search_pattern = "%#{limited_query}%"
        
        # Pass search pattern to Enforcement context
        [{:search, search_pattern} | acc]
      
      _, acc -> acc
    end)
  end

  defp build_sort_options(sort_by, sort_dir) do
    case {sort_by, sort_dir} do
      {:offender_name, dir} ->
        [offender: [name: dir]]
      
      {:agency_name, dir} ->
        [agency: [name: dir]]
      
      {field, dir} when field in [:offence_action_date, :offence_fine, :regulator_id] ->
        [{field, dir}]
      
      _ ->
        [offence_action_date: :desc]  # Default sort
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
  defp calculate_total_pages(total_cases, page_size) do
    ceil(total_cases / page_size)
  end

  defp format_currency(amount) when is_struct(amount, Decimal) do
    # Convert Decimal to float safely
    amount
    |> Decimal.to_float()
    |> :erlang.float_to_binary([{:decimals, 2}])
    |> then(&"£#{format_number(&1)}")
  end

  defp format_currency(_), do: "£0.00"

  defp format_number(number_str) do
    number_str
    |> String.split(".")
    |> case do
      [integer_part, decimal_part] ->
        formatted_integer = integer_part
        |> String.reverse()
        |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
        |> String.reverse()
        
        "#{formatted_integer}.#{decimal_part}"
      
      [integer_part] ->
        integer_part
        |> String.reverse()
        |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
        |> String.reverse()
    end
  end

  defp format_date(date) when is_struct(date, Date) do
    Calendar.strftime(date, "%Y-%m-%d")
  end

  defp format_date(_), do: ""

  defp truncate_text(text, max_length)

  defp truncate_text(text, max_length) when is_binary(text) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "..."
    else
      text
    end
  end

  defp truncate_text(nil, _), do: ""
  defp truncate_text(text, _) when not is_binary(text), do: ""

  defp page_range(current_page, total_pages, delta \\ 2) do
    start_page = max(1, current_page - delta)
    end_page = min(total_pages, current_page + delta)
    
    Enum.to_list(start_page..end_page)
  end
end