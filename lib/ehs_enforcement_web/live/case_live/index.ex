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
    :ok = Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case_updates")

    {:ok,
     socket
     |> assign(:agencies, Enforcement.list_agencies!())
     |> assign(:filters, %{})
     |> assign(:search_query, "")
     |> assign(:sort_by, :offence_action_date)
     |> assign(:sort_dir, :desc)
     |> assign(:page, 1)
     |> assign(:page_size, @default_page_size)
     |> assign(:total_cases, 0)
     |> assign(:loading, true)
     |> assign(:search_active, false)
     |> assign(:fuzzy_search, false)
     |> assign(:sort_requested, false)
     |> assign(:filter_count, 0)
     |> assign(:counting_filters, false)
     |> assign(:filters_applied, false)
     |> assign(:search_task_ref, nil)
     |> assign(:count_task_ref, nil)
     |> load_cases(), temporary_assigns: [cases: []]}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")

    # Handle filter parameters from dashboard navigation
    filters =
      case params["filter"] do
        "recent" ->
          # Calculate date based on period parameter from dashboard
          days_ago =
            case params["period"] do
              "week" -> 7
              "month" -> 30
              "year" -> 365
              # default to month
              _ -> 30
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

    # Count records that match the filters in real-time
    socket_with_filters = assign(socket, :filters, filters)

    {:noreply,
     socket_with_filters
     |> assign(:page, 1)
     # Reset applied state
     |> assign(:filters_applied, false)
     |> count_filtered_cases()}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:filters, %{})
     |> assign(:search_query, "")
     |> assign(:page, 1)
     # Reset sort flag when clearing
     |> assign(:sort_requested, false)
     |> assign(:filters_applied, false)
     |> assign(:filter_count, 0)
     |> load_cases()}
  end

  @impl true
  def handle_event("search", %{"search" => search_query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, search_query)
     |> assign(:page, 1)
     # Reset applied state
     |> assign(:filters_applied, false)
     |> count_filtered_cases()}
  end

  @impl true
  def handle_event("search", %{"_target" => ["search"], "search" => search_query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, search_query)
     |> assign(:page, 1)
     # Reset applied state
     |> assign(:filters_applied, false)
     |> count_filtered_cases()}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:page, 1)
     |> load_cases()}
  end

  @impl true
  def handle_event("apply_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:filters_applied, true)
     |> async_load_cases()}
  end

  @impl true
  def handle_event("toggle_fuzzy_search", _params, socket) do
    fuzzy_search = !socket.assigns.fuzzy_search

    {:noreply,
     socket
     |> assign(:fuzzy_search, fuzzy_search)
     # Reset to first page when changing search mode
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
     # Reset to first page when sorting
     |> assign(:page, 1)
     # Flag to indicate sorting was requested
     |> assign(:sort_requested, true)
     |> async_load_cases()}
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
         |> async_load_cases()}

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
         # Reset to first page
         |> assign(:page, 1)
         |> push_patch(to: ~p"/cases")
         |> load_cases()}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("export_csv", _params, socket) do
    alias EhsEnforcementWeb.CaseLive.CSVExport

    case CSVExport.export_cases(
           socket.assigns.filters,
           socket.assigns.sort_by,
           socket.assigns.sort_dir
         ) do
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
  def handle_event("delete_case", %{"case_id" => case_id}, socket) do
    case Ash.get(Enforcement.Case, case_id, actor: socket.assigns.current_user) do
      {:ok, case_record} ->
        case Ash.destroy(case_record, actor: socket.assigns.current_user) do
          :ok ->
            {:noreply,
             socket
             |> put_flash(:info, "Case deleted successfully")
             |> load_cases()}

          {:error, error} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to delete case: #{inspect(error)}")}
        end

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Case not found")}
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

  # Handle async search completion
  @impl true
  def handle_info({:search_complete, task_ref, {cases, total_cases}}, socket) do
    # Only process if this is the current search task
    if socket.assigns.search_task_ref == task_ref do
      {:noreply,
       socket
       |> assign(:cases, cases)
       |> assign(:total_cases, total_cases)
       |> assign(:loading, false)
       |> assign(:search_task_ref, nil)}
    else
      # Ignore results from cancelled/old searches
      {:noreply, socket}
    end
  end

  # Handle async search timeout
  @impl true
  def handle_info({:search_timeout, task_ref}, socket) do
    if socket.assigns.search_task_ref == task_ref do
      require Logger
      Logger.warning("Search query timed out after 10 seconds")

      {:noreply,
       socket
       |> assign(:loading, false)
       |> assign(:search_task_ref, nil)
       |> put_flash(:error, "Search timed out. Please try refining your search criteria.")}
    else
      {:noreply, socket}
    end
  end

  # Handle async search error
  @impl true
  def handle_info({:search_error, task_ref, error}, socket) do
    if socket.assigns.search_task_ref == task_ref do
      require Logger
      Logger.error("Search query failed: #{inspect(error)}")

      {:noreply,
       socket
       |> assign(:cases, [])
       |> assign(:total_cases, 0)
       |> assign(:loading, false)
       |> assign(:search_task_ref, nil)
       |> put_flash(:error, "Search failed. Please try again.")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:count_complete, task_ref, count}, socket) do
    # Only process if this is the current count task
    if socket.assigns.count_task_ref == task_ref do
      {:noreply,
       socket
       |> assign(:filter_count, count)
       |> assign(:counting_filters, false)
       |> assign(:count_task_ref, nil)}
    else
      # Ignore results from cancelled/old count tasks
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:count_timeout, task_ref}, socket) do
    if socket.assigns.count_task_ref == task_ref do
      require Logger
      Logger.warning("Filter count query timed out after 5 seconds")

      {:noreply,
       socket
       |> assign(:filter_count, 0)
       |> assign(:counting_filters, false)
       |> assign(:count_task_ref, nil)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:count_error, task_ref, error}, socket) do
    if socket.assigns.count_task_ref == task_ref do
      require Logger
      Logger.error("Filter count query failed: #{inspect(error)}")

      {:noreply,
       socket
       |> assign(:filter_count, 0)
       |> assign(:counting_filters, false)
       |> assign(:count_task_ref, nil)}
    else
      {:noreply, socket}
    end
  end

  # Private functions

  defp load_cases(socket) do
    %{
      filters: filters,
      search_query: search_query,
      fuzzy_search: fuzzy_search,
      sort_by: sort_by,
      sort_dir: sort_dir,
      page: page,
      page_size: page_size,
      sort_requested: sort_requested,
      filters_applied: filters_applied
    } = socket.assigns

    try do
      # Don't load any cases unless filters have been explicitly applied or sort was requested
      has_filters = map_size(filters) > 0
      has_search = is_binary(search_query) && String.trim(search_query) != ""

      if (!has_filters && !has_search && !sort_requested) || (!filters_applied && !sort_requested) do
        socket
        |> assign(:cases, [])
        |> assign(:total_cases, 0)
        |> assign(:loading, false)
      else
        # Check if fuzzy search is enabled and we have a search query
        # Use search_query from assigns or search filter
        actual_search = if has_search, do: search_query, else: filters[:search]
        use_fuzzy = fuzzy_search && is_binary(actual_search) && String.trim(actual_search) != ""

        {cases, total_cases} =
          if use_fuzzy do
            # Use fuzzy search with pg_trgm
            trimmed_query = String.trim(actual_search)

            limited_query =
              if String.length(trimmed_query) > 100 do
                String.slice(trimmed_query, 0, 100)
              else
                trimmed_query
              end

            offset = (page - 1) * page_size

            fuzzy_opts = [
              limit: page_size,
              offset: offset,
              load: [:offender, :agency, :computed_breaches_summary]
            ]

            {:ok, fuzzy_results} = Enforcement.fuzzy_search_cases(limited_query, fuzzy_opts)

            # For fuzzy search, we can't easily get total count, so we estimate
            # by checking if we got a full page of results
            estimated_total =
              if length(fuzzy_results) == page_size do
                # Estimate there's at least one more page
                page * page_size + 1
              else
                # We've reached the end
                offset + length(fuzzy_results)
              end

            {fuzzy_results, estimated_total}
          else
            # Use regular filtering with optimized indexes
            query_opts =
              build_optimized_query_options(filters, sort_by, sort_dir, page, page_size)

            regular_results = Enforcement.list_cases_with_filters!(query_opts)

            # Get total count using same optimized filter
            count_opts = [filter: build_optimized_filter(filters)]
            regular_total = Enforcement.count_cases!(count_opts)

            {regular_results, regular_total}
          end

        socket
        |> assign(:cases, cases)
        |> assign(:total_cases, total_cases)
        |> assign(:loading, false)
        # Reset the flag after loading
        |> assign(:sort_requested, false)
      end
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

  # Async version of load_cases for non-blocking database queries
  defp async_load_cases(socket) do
    # Cancel any previous search task
    socket = cancel_previous_search(socket)

    # Generate unique reference for this search
    task_ref = make_ref()

    # Capture the current assigns needed for the search
    search_params = %{
      filters: socket.assigns.filters,
      search_query: socket.assigns.search_query,
      fuzzy_search: socket.assigns.fuzzy_search,
      sort_by: socket.assigns.sort_by,
      sort_dir: socket.assigns.sort_dir,
      page: socket.assigns.page,
      page_size: socket.assigns.page_size,
      sort_requested: socket.assigns.sort_requested,
      filters_applied: socket.assigns.filters_applied
    }

    # Get the parent LiveView PID
    parent_pid = self()

    # Spawn async task for database query
    {:ok, _pid} =
      Task.start(fn ->
        # Set timeout for the query (10 seconds)
        timeout_ref = Process.send_after(parent_pid, {:search_timeout, task_ref}, 10_000)

        try do
          # Execute the search query
          result = execute_search_query(search_params)

          # Cancel timeout if we completed successfully
          _ = Process.cancel_timer(timeout_ref)

          # Send results back to LiveView
          send(parent_pid, {:search_complete, task_ref, result})
        rescue
          error ->
            # Cancel timeout and send error
            _ = Process.cancel_timer(timeout_ref)
            send(parent_pid, {:search_error, task_ref, error})
        end
      end)

    # Return socket with loading state and task reference
    socket
    |> assign(:loading, true)
    |> assign(:search_task_ref, task_ref)
  end

  # Execute the actual search query (extracted from load_cases for reuse)
  defp execute_search_query(params) do
    %{
      filters: filters,
      search_query: search_query,
      fuzzy_search: fuzzy_search,
      sort_by: sort_by,
      sort_dir: sort_dir,
      page: page,
      page_size: page_size,
      sort_requested: sort_requested,
      filters_applied: filters_applied
    } = params

    # Don't load any cases unless filters have been explicitly applied or sort was requested
    has_filters = map_size(filters) > 0
    has_search = is_binary(search_query) && String.trim(search_query) != ""

    if (!has_filters && !has_search && !sort_requested) || (!filters_applied && !sort_requested) do
      {[], 0}
    else
      # Check if fuzzy search is enabled and we have a search query
      actual_search = if has_search, do: search_query, else: filters[:search]
      use_fuzzy = fuzzy_search && is_binary(actual_search) && String.trim(actual_search) != ""

      if use_fuzzy do
        # Use fuzzy search with pg_trgm
        trimmed_query = String.trim(actual_search)

        limited_query =
          if String.length(trimmed_query) > 100 do
            String.slice(trimmed_query, 0, 100)
          else
            trimmed_query
          end

        offset = (page - 1) * page_size

        fuzzy_opts = [
          limit: page_size,
          offset: offset,
          load: [:offender, :agency, :computed_breaches_summary]
        ]

        {:ok, fuzzy_results} = Enforcement.fuzzy_search_cases(limited_query, fuzzy_opts)

        # For fuzzy search, estimate total count
        estimated_total =
          if length(fuzzy_results) == page_size do
            page * page_size + 1
          else
            offset + length(fuzzy_results)
          end

        {fuzzy_results, estimated_total}
      else
        # Use regular filtering with optimized indexes
        query_opts = build_optimized_query_options(filters, sort_by, sort_dir, page, page_size)
        regular_results = Enforcement.list_cases_with_filters!(query_opts)

        # Get total count using same optimized filter
        count_opts = [filter: build_optimized_filter(filters)]
        regular_total = Enforcement.count_cases!(count_opts)

        {regular_results, regular_total}
      end
    end
  end

  # Cancel any previous search task to prevent race conditions
  defp cancel_previous_search(socket) do
    case socket.assigns.search_task_ref do
      nil ->
        socket

      _task_ref ->
        # Note: We don't actually kill the task (it's not supervised)
        # Instead, we just ignore its results in handle_info
        # The task will complete and its message will be discarded
        socket
        |> assign(:search_task_ref, nil)
    end
  end

  defp build_optimized_query_options(filters, sort_by, sort_dir, page, page_size) do
    offset = (page - 1) * page_size

    [
      filter: build_optimized_filter(filters),
      sort: build_sort_options(sort_by, sort_dir),
      limit: page_size,
      offset: offset,
      load: [:offender, :agency, :computed_breaches_summary]
    ]
  end

  # Optimized filter building that formats data for the Enforcement context
  # The Enforcement context now handles composite index optimization internally
  defp build_optimized_filter(filters) do
    %{}
    |> add_filter_if_present(filters, :agency_id)
    |> add_date_range_filters(filters)
    |> add_fine_range_filters(filters)
    |> add_search_filter(filters)
    |> add_filter_if_present(filters, :regulator_id)
  end

  defp add_filter_if_present(acc, filters, key) do
    case filters[key] do
      value when is_binary(value) and value != "" -> Map.put(acc, key, value)
      _ -> acc
    end
  end

  defp add_date_range_filters(acc, filters) do
    date_conditions = []

    date_conditions =
      case filters[:date_from] do
        date when is_binary(date) and date != "" ->
          case Date.from_iso8601(date) do
            {:ok, parsed_date} -> [{:greater_than_or_equal_to, parsed_date} | date_conditions]
            _ -> date_conditions
          end

        _ ->
          date_conditions
      end

    date_conditions =
      case filters[:date_to] do
        date when is_binary(date) and date != "" ->
          case Date.from_iso8601(date) do
            {:ok, parsed_date} -> [{:less_than_or_equal_to, parsed_date} | date_conditions]
            _ -> date_conditions
          end

        _ ->
          date_conditions
      end

    if date_conditions != [] do
      Map.put(acc, :offence_action_date, date_conditions)
    else
      acc
    end
  end

  defp add_fine_range_filters(acc, filters) do
    fine_conditions = []

    fine_conditions =
      case filters[:min_fine] do
        amount when is_binary(amount) and amount != "" ->
          case Decimal.parse(amount) do
            {decimal_amount, _} -> [{:greater_than_or_equal_to, decimal_amount} | fine_conditions]
            :error -> fine_conditions
          end

        _ ->
          fine_conditions
      end

    fine_conditions =
      case filters[:max_fine] do
        amount when is_binary(amount) and amount != "" ->
          case Decimal.parse(amount) do
            {decimal_amount, _} -> [{:less_than_or_equal_to, decimal_amount} | fine_conditions]
            :error -> fine_conditions
          end

        _ ->
          fine_conditions
      end

    if fine_conditions != [] do
      Map.put(acc, :offence_fine, fine_conditions)
    else
      acc
    end
  end

  defp add_search_filter(acc, filters) do
    case filters[:search] do
      query when is_binary(query) and query != "" ->
        trimmed_query = String.trim(query)

        # Limit search term length to prevent database issues
        limited_query =
          if String.length(trimmed_query) > 100 do
            String.slice(trimmed_query, 0, 100)
          else
            trimmed_query
          end

        search_pattern = "%#{limited_query}%"
        Map.put(acc, :search, search_pattern)

      _ ->
        acc
    end
  end

  defp build_sort_options(sort_by, sort_dir) do
    case {sort_by, sort_dir} do
      # TODO: Re-enable offender sorting when Ash 3.5.x belongs_to relationship
      # sorting bug is fixed (KeyError: key :constraints not found)
      # {:offender_name, dir} ->
      #   [offender: [name: dir]]

      # Agency sorting removed - not supported
      {:agency_name, _dir} ->
        # Fallback to default sort
        [offence_action_date: :desc]

      {:offender_name, _dir} ->
        # Fallback to default sort - sorting disabled
        [offence_action_date: :desc]

      {field, dir} when field in [:offence_action_date, :offence_fine, :regulator_id] ->
        [{field, dir}]

      _ ->
        # Default sort
        [offence_action_date: :desc]
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

      _, acc ->
        acc
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
        formatted_integer =
          integer_part
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

  defp count_filtered_cases(socket) do
    %{filters: filters, search_query: search_query} = socket.assigns

    has_filters = map_size(filters) > 0
    has_search = is_binary(search_query) && String.trim(search_query) != ""

    if !has_filters && !has_search do
      socket
      |> assign(:filter_count, 0)
      |> assign(:counting_filters, false)
      |> assign(:count_task_ref, nil)
    else
      # Cancel any previous count task
      socket = cancel_previous_count(socket)

      # Generate unique reference for this count task
      task_ref = make_ref()

      # Capture filter parameters
      count_params = %{
        filters: filters,
        search_query: search_query
      }

      # Get the parent LiveView PID
      parent_pid = self()

      # Spawn async task for count query
      {:ok, _pid} =
        Task.start(fn ->
          # Set timeout for the count query (5 seconds - shorter than search)
          timeout_ref = Process.send_after(parent_pid, {:count_timeout, task_ref}, 5_000)

          try do
            # Execute the count query
            count = execute_count_query(count_params)

            # Cancel timeout if we completed successfully
            _ = Process.cancel_timer(timeout_ref)

            # Send result back to LiveView
            send(parent_pid, {:count_complete, task_ref, count})
          rescue
            error ->
              # Cancel timeout and send error
              _ = Process.cancel_timer(timeout_ref)
              send(parent_pid, {:count_error, task_ref, error})
          end
        end)

      # Return socket with counting state and task reference
      socket
      |> assign(:counting_filters, true)
      |> assign(:count_task_ref, task_ref)
    end
  end

  defp execute_count_query(count_params) do
    %{filters: filters, search_query: search_query} = count_params

    has_search = is_binary(search_query) && String.trim(search_query) != ""

    # Build filter including search_query if present
    search_aware_filters =
      if has_search do
        Map.put(filters, :search, "%#{String.trim(search_query)}%")
      else
        filters
      end

    filter = build_optimized_filter(search_aware_filters)
    Enforcement.count_cases!(filter: filter)
  end

  defp cancel_previous_count(socket) do
    case socket.assigns.count_task_ref do
      nil ->
        socket

      _task_ref ->
        # Note: We don't actually kill the task (it's not supervised)
        # Instead, we just ignore its results in handle_info
        # The task will complete and its message will be discarded
        socket
        |> assign(:count_task_ref, nil)
    end
  end
end
