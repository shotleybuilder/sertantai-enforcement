defmodule EhsEnforcementWeb.Admin.CaseLive.Index do
  @moduledoc """
  Admin case management dashboard with enhanced functionality for case oversight.
  
  Features:
  - Case statistics and overview
  - Quick access to scraping controls
  - Recent case activity monitoring
  - Bulk operations and management tools
  """
  
  use EhsEnforcementWeb, :live_view
  
  require Logger
  require Ash.Query
  
  alias EhsEnforcement.Enforcement
  
  # LiveView Callbacks
  
  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket,
      # Data
      cases: [],
      agencies: [],
      
      # Statistics
      stats: %{
        total_cases: 0,
        recent_cases: 0,
        hse_cases: 0,
        avg_fine: Decimal.new("0.00")
      },
      
      # Filters
      selected_agency: :all,
      date_range: :last_30_days,
      
      # UI state
      loading: true,
      page_size: 25,
      current_page: 1
    )
    
    if connected?(socket) do
      load_dashboard_data(socket)
    else
      {:ok, socket}
    end
  end
  
  @impl true
  def handle_params(params, _url, socket) do
    socket = apply_params(socket, params)
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("filter_by_agency", %{"agency" => agency_code}, socket) do
    agency_atom = if agency_code == "all", do: :all, else: String.to_atom(agency_code)
    socket = assign(socket, selected_agency: agency_atom, loading: true)
    {:noreply, load_filtered_cases(socket)}
  end
  
  @impl true
  def handle_event("filter_by_date", %{"range" => date_range}, socket) do
    date_range_atom = String.to_atom(date_range)
    socket = assign(socket, date_range: date_range_atom, loading: true)
    {:noreply, load_filtered_cases(socket)}
  end
  
  @impl true
  def handle_event("refresh_data", _params, socket) do
    socket = assign(socket, loading: true)
    {:noreply, load_dashboard_data(socket)}
  end
  
  @impl true
  def handle_event("navigate_to_scraping", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/cases/scrape")}
  end
  
  @impl true
  def handle_event("navigate_to_case", %{"case_id" => case_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/cases/#{case_id}")}
  end
  
  # Private Functions
  
  defp apply_params(socket, params) do
    agency = case params["agency"] do
      nil -> :all
      "all" -> :all
      agency_code -> String.to_atom(agency_code)
    end
    
    date_range = case params["date_range"] do
      nil -> :last_30_days
      range -> String.to_atom(range)
    end
    
    assign(socket, selected_agency: agency, date_range: date_range)
  end
  
  defp load_dashboard_data(socket) do
    Task.start_link(fn ->
      try do
        # Load agencies using code interface
        agencies = Enforcement.list_agencies!(actor: socket.assigns.current_user)
        
        # Load cases with filters using code interface
        cases = load_filtered_cases(socket.assigns.selected_agency, socket.assigns.date_range, socket.assigns.current_user)
        
        # Calculate statistics
        stats = calculate_statistics(cases)
        
        send(self(), {:dashboard_data_loaded, %{
          cases: cases,
          agencies: agencies,
          stats: stats
        }})
        
      rescue
        error ->
          Logger.error("Failed to load dashboard data: #{inspect(error)}")
          send(self(), {:dashboard_data_error, error})
      end
    end)
    
    socket
  end
  
  defp load_filtered_cases(socket) do
    Task.start_link(fn ->
      try do
        cases = load_filtered_cases(socket.assigns.selected_agency, socket.assigns.date_range, socket.assigns.current_user)
        
        stats = calculate_statistics(cases)
        
        send(self(), {:filtered_cases_loaded, %{cases: cases, stats: stats}})
        
      rescue
        error ->
          Logger.error("Failed to load filtered cases: #{inspect(error)}")
          send(self(), {:filtered_cases_error, error})
      end
    end)
    
    socket
  end
  
  defp load_filtered_cases(agency_filter, date_range, actor) do
    # Build filter options for the code interface
    filter_opts = build_filter_options(agency_filter, date_range)
    
    # Use the code interface with filtering
    Enforcement.list_cases_with_filters!(
      filter: filter_opts,
      sort: [inserted_at: :desc],
      load: [:agency, :offender],
      limit: 100,
      actor: actor
    )
  end

  defp build_filter_options(agency_filter, date_range) do
    filters = []
    
    # Apply agency filter
    filters = case agency_filter do
      :all -> filters
      agency_code -> [{:agency_code, agency_code} | filters]
    end
    
    # Apply date range filter
    case date_range do
      :last_7_days ->
        cutoff = DateTime.utc_now() |> DateTime.add(-7, :day)
        [{:inserted_at, [{:greater_than_or_equal_to, cutoff}]} | filters]
      :last_30_days ->
        cutoff = DateTime.utc_now() |> DateTime.add(-30, :day)
        [{:inserted_at, [{:greater_than_or_equal_to, cutoff}]} | filters]
      :last_90_days ->
        cutoff = DateTime.utc_now() |> DateTime.add(-90, :day)
        [{:inserted_at, [{:greater_than_or_equal_to, cutoff}]} | filters]
      :all_time ->
        filters
    end
  end
  
  defp calculate_statistics(cases) do
    total_cases = length(cases)
    hse_cases = Enum.count(cases, fn case -> case.agency_code == :hse end)
    
    # Calculate recent cases (last 7 days)
    recent_cutoff = DateTime.utc_now() |> DateTime.add(-7, :day)
    recent_cases = Enum.count(cases, fn case -> 
      case.inserted_at && DateTime.compare(case.inserted_at, recent_cutoff) == :gt
    end)
    
    # Calculate average fine
    fines = cases
    |> Enum.map(& &1.offence_fine)
    |> Enum.reject(&is_nil/1)
    
    avg_fine = case fines do
      [] -> Decimal.new("0.00")
      _ ->
        total = Enum.reduce(fines, Decimal.new("0"), &Decimal.add/2)
        Decimal.div(total, Decimal.new(length(fines)))
        |> Decimal.round(2)
    end
    
    %{
      total_cases: total_cases,
      recent_cases: recent_cases,
      hse_cases: hse_cases,
      avg_fine: avg_fine
    }
  end
  
  defp format_currency(nil), do: "N/A"
  defp format_currency(amount) when is_struct(amount, Decimal) do
    "£" <> Decimal.to_string(amount, :normal)
  end
  
  defp format_date(nil), do: "N/A"
  defp format_date(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d")
  end
  
  defp truncate_text(nil, _length), do: ""
  defp truncate_text(text, length) when byte_size(text) <= length, do: text
  defp truncate_text(text, length) do
    String.slice(text, 0, length) <> "..."
  end
  
  defp agency_name(agency_code) do
    case agency_code do
      :hse -> "Health and Safety Executive"
      :onr -> "Office for Nuclear Regulation"
      :orr -> "Office of Rail and Road"
      :ea -> "Environment Agency"
      _ -> to_string(agency_code)
    end
  end
  
  defp case_status_badge(case) do
    # Simple status based on data completeness
    cond do
      is_nil(case.offence_result) -> {"Draft", "bg-gray-100 text-gray-800"}
      case.offence_result == "Convicted" -> {"Convicted", "bg-red-100 text-red-800"}
      case.offence_result == "Fined" -> {"Fined", "bg-yellow-100 text-yellow-800"}
      true -> {"Complete", "bg-green-100 text-green-800"}
    end
  end
  
  # Handle async data loading
  
  @impl true
  def handle_info({:dashboard_data_loaded, data}, socket) do
    socket = assign(socket,
      cases: data.cases,
      agencies: data.agencies,
      stats: data.stats,
      loading: false
    )
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:dashboard_data_error, _error}, socket) do
    socket = assign(socket, loading: false)
    {:noreply, put_flash(socket, :error, "Failed to load dashboard data")}
  end
  
  @impl true
  def handle_info({:filtered_cases_loaded, data}, socket) do
    socket = assign(socket,
      cases: data.cases,
      stats: data.stats,
      loading: false
    )
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:filtered_cases_error, _error}, socket) do
    socket = assign(socket, loading: false)
    {:noreply, put_flash(socket, :error, "Failed to load filtered cases")}
  end
end