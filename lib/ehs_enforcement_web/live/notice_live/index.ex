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
     |> assign(:page_title, "Notices")
     |> assign(:notices, [])
     |> assign(:loading, true)
     |> assign(:filters, %{})
     |> assign(:search_query, "")
     |> assign(:sort_by, :notice_date)
     |> assign(:sort_order, :desc)
     |> assign(:page, 1)
     |> assign(:page_size, 20)
     |> assign(:total_notices, 0)
     |> assign(:search_active, false)
     |> assign(:fuzzy_search, false)
     |> assign(:sort_requested, false)
     |> assign(:filter_count, 0)
     |> assign(:counting_filters, false)
     |> assign(:filters_applied, false)
     |> assign(:search_task_ref, nil)
     |> assign(:count_task_ref, nil)
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

    # Count records that match the filters in real-time
    socket_with_filters = assign(socket, :filters, filters)

    {:noreply,
     socket_with_filters
     |> assign(:page, 1)
     # Reset applied state
     |> assign(:filters_applied, false)
     |> count_filtered_notices()}
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
     |> load_notices()}
  end

  @impl true
  def handle_event("search", %{"search" => search_query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, search_query)
     |> assign(:page, 1)
     # Reset applied state
     |> assign(:filters_applied, false)
     |> count_filtered_notices()}
  end

  @impl true
  def handle_event("search", %{"_target" => ["search"], "search" => search_query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, search_query)
     |> assign(:page, 1)
     # Reset applied state
     |> assign(:filters_applied, false)
     |> count_filtered_notices()}
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
     # Flag to indicate sorting was requested
     |> assign(:sort_requested, true)
     |> async_load_notices()}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page_num = String.to_integer(page)

    {:noreply,
     socket
     |> assign(:page, page_num)
     |> async_load_notices()}
  end

  @impl true
  def handle_event("toggle_fuzzy_search", _params, socket) do
    fuzzy_search = !socket.assigns.fuzzy_search

    {:noreply,
     socket
     |> assign(:fuzzy_search, fuzzy_search)
     # Reset to first page when changing search mode
     |> assign(:page, 1)
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
  def handle_event("apply_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:filters_applied, true)
     |> async_load_notices()}
  end

  @impl true
  def handle_event("delete_notice", %{"notice_id" => notice_id}, socket) do
    case Ash.get(Enforcement.Notice, notice_id, actor: socket.assigns.current_user) do
      {:ok, notice_record} ->
        case Ash.destroy(notice_record, actor: socket.assigns.current_user) do
          :ok ->
            {:noreply,
             socket
             |> put_flash(:info, "Notice deleted successfully")
             |> load_notices()}

          {:error, error} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to delete notice: #{inspect(error)}")}
        end

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Notice not found")}
    end
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
  def handle_info({:search_complete, task_ref, {notices, total_notices}}, socket) do
    # Only process if this is the current search task
    if socket.assigns.search_task_ref == task_ref do
      {:noreply,
       socket
       |> assign(:notices, notices)
       |> assign(:total_notices, total_notices)
       |> assign(:loading, false)
       |> assign(:search_task_ref, nil)}
    else
      # Ignore results from cancelled/old searches
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:search_timeout, task_ref}, socket) do
    if socket.assigns.search_task_ref == task_ref do
      require Logger
      Logger.warning("Notice search query timed out after 10 seconds")

      {:noreply,
       socket
       |> assign(:loading, false)
       |> assign(:search_task_ref, nil)
       |> put_flash(:error, "Search timed out. Please try refining your search criteria.")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:search_error, task_ref, error}, socket) do
    if socket.assigns.search_task_ref == task_ref do
      require Logger
      Logger.error("Notice search query failed: #{inspect(error)}")

      {:noreply,
       socket
       |> assign(:notices, [])
       |> assign(:total_notices, 0)
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
      Logger.warning("Notice filter count query timed out after 5 seconds")

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
      Logger.error("Notice filter count query failed: #{inspect(error)}")

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
  def handle_info(_msg, socket) do
    # Catch-all for any other messages
    {:noreply, socket}
  end

  # Private functions

  defp load_notices(socket) do
    %{
      filters: filters,
      search_query: search_query,
      fuzzy_search: fuzzy_search,
      page: page,
      page_size: page_size,
      sort_requested: sort_requested,
      filters_applied: filters_applied
    } = socket.assigns

    try do
      # Don't load any notices unless filters have been explicitly applied or sort was requested
      has_filters = map_size(filters) > 0
      has_search = is_binary(search_query) && String.trim(search_query) != ""

      if (!has_filters && !has_search && !sort_requested) || (!filters_applied && !sort_requested) do
        socket
        |> assign(:notices, [])
        |> assign(:total_notices, 0)
        |> assign(:loading, false)
      else
        # Check if fuzzy search is enabled and we have a search query
        use_fuzzy = fuzzy_search && has_search

        {notices, total_notices} =
          if use_fuzzy do
            # Use fuzzy search with pg_trgm
            trimmed_query = String.trim(search_query)

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
              load: [:agency, :offender]
            ]

            {:ok, fuzzy_results} = Enforcement.fuzzy_search_notices(limited_query, fuzzy_opts)

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
            query_opts = build_optimized_query_opts(socket)
            regular_results = Enforcement.list_notices_with_filters!(query_opts)

            # Get total count using same optimized filter
            filter = build_optimized_notice_filter(socket)
            regular_total = Enforcement.count_notices!(filter: filter)

            {regular_results, regular_total}
          end

        socket
        |> assign(:notices, notices)
        |> assign(:total_notices, total_notices)
        |> assign(:loading, false)
        # Reset the flag after loading
        |> assign(:sort_requested, false)
      end
    rescue
      error ->
        socket
        |> assign(:notices, [])
        |> assign(:total_notices, 0)
        |> assign(:loading, false)
        # Reset flag on error too
        |> assign(:sort_requested, false)
        |> put_flash(:error, "Failed to load notices: #{inspect(error)}")
    end
  end

  defp build_optimized_query_opts(socket) do
    %{sort_by: sort_by, sort_order: sort_order, page: page, page_size: page_size} = socket.assigns

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

      _ ->
        acc
    end
  end

  defp add_date_to_filter(acc, filters) do
    case filters[:date_to] do
      date when is_binary(date) and date != "" ->
        case Date.from_iso8601(date) do
          {:ok, parsed_date} -> Map.put(acc, :date_to, parsed_date)
          _ -> acc
        end

      _ ->
        acc
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

  defp count_filtered_notices(socket) do
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
      Task.start(fn ->
        # Set timeout for the count query (5 seconds)
        timeout_ref = Process.send_after(parent_pid, {:count_timeout, task_ref}, 5_000)

        try do
          # Execute the count query
          count = execute_count_query(count_params)

          # Cancel timeout if we completed successfully
          Process.cancel_timer(timeout_ref)

          # Send result back to LiveView
          send(parent_pid, {:count_complete, task_ref, count})
        rescue
          error ->
            # Cancel timeout and send error
            Process.cancel_timer(timeout_ref)
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

    # Build filter using socket.assigns approach (need to reconstruct socket-like structure)
    socket_like = %{assigns: %{filters: filters, search_query: search_query}}
    filter = build_optimized_notice_filter(socket_like)
    Enforcement.count_notices!(filter: filter)
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

  defp async_load_notices(socket) do
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
      sort_order: socket.assigns.sort_order,
      page: socket.assigns.page,
      page_size: socket.assigns.page_size,
      sort_requested: socket.assigns.sort_requested,
      filters_applied: socket.assigns.filters_applied
    }

    # Get the parent LiveView PID
    parent_pid = self()

    # Spawn async task for database query
    Task.start(fn ->
      # Set timeout for the query (10 seconds)
      timeout_ref = Process.send_after(parent_pid, {:search_timeout, task_ref}, 10_000)

      try do
        # Execute the search query
        result = execute_search_query(search_params)

        # Cancel timeout if we completed successfully
        Process.cancel_timer(timeout_ref)

        # Send results back to LiveView
        send(parent_pid, {:search_complete, task_ref, result})
      rescue
        error ->
          # Cancel timeout and send error
          Process.cancel_timer(timeout_ref)
          send(parent_pid, {:search_error, task_ref, error})
      end
    end)

    # Return socket with loading state and task reference
    socket
    |> assign(:loading, true)
    |> assign(:search_task_ref, task_ref)
  end

  defp execute_search_query(search_params) do
    %{
      filters: filters,
      search_query: search_query,
      fuzzy_search: fuzzy_search,
      sort_by: sort_by,
      sort_order: sort_order,
      page: page,
      page_size: page_size,
      sort_requested: sort_requested,
      filters_applied: filters_applied
    } = search_params

    # Don't load any notices unless filters have been explicitly applied or sort was requested
    has_filters = map_size(filters) > 0
    has_search = is_binary(search_query) && String.trim(search_query) != ""

    if (!has_filters && !has_search && !sort_requested) || (!filters_applied && !sort_requested) do
      {[], 0}
    else
      # Check if fuzzy search is enabled and we have a search query
      use_fuzzy = fuzzy_search && has_search

      if use_fuzzy do
        # Use fuzzy search with pg_trgm
        trimmed_query = String.trim(search_query)

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
          load: [:agency, :offender]
        ]

        {:ok, fuzzy_results} = Enforcement.fuzzy_search_notices(limited_query, fuzzy_opts)

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
        filter_map = build_notice_filter_from_params(search_params)

        query_opts = [
          filter: filter_map,
          sort: [{sort_by, sort_order}],
          limit: page_size,
          offset: (page - 1) * page_size,
          load: [:agency, :offender]
        ]

        regular_results = Enforcement.list_notices_with_filters!(query_opts)

        # Get total count using same optimized filter
        regular_total = Enforcement.count_notices!(filter: filter_map)

        {regular_results, regular_total}
      end
    end
  end

  defp build_notice_filter_from_params(search_params) do
    filters = search_params.filters
    search_query = search_params.search_query

    %{}
    |> add_notice_filter_if_present(filters, :agency_id)
    |> add_notice_filter_if_present(filters, :offence_action_type)
    |> add_notice_date_filters(filters)
    |> add_notice_search_filter(search_query)
  end

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
end
