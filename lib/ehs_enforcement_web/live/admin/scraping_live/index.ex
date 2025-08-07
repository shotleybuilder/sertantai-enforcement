defmodule EhsEnforcementWeb.Admin.ScrapingLive.Index do
  @moduledoc """
  Scraping management and history interface for administrators.
  
  Features:
  - View scraping history and session details
  - Monitor system performance and metrics
  - Schedule management interface preparation
  - Performance analytics and reporting
  """
  
  use EhsEnforcementWeb, :live_view
  
  require Logger
  
  alias Phoenix.PubSub
  
  @pubsub_topic "scraping_progress"
  
  require Logger
  require Ash.Query
  
  alias EhsEnforcement.Enforcement.Case
  
  # LiveView Callbacks
  
  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to scraping events for real-time updates
    if connected?(socket) do
      PubSub.subscribe(EhsEnforcement.PubSub, @pubsub_topic)
    end
    
    socket = assign(socket,
      # Data - will be loaded from Ash resources
      recent_cases: [],
      case_stats: %{
        total_cases: 0,
        recent_cases_count: 0,
        hse_cases_count: 0,
        avg_cases_per_day: 0
      },
      
      # Filters
      date_range: :last_7_days,
      
      # UI state
      loading: true,
      selected_case: nil,
      show_case_details: false
    )
    
    if connected?(socket) do
      socket = load_scraping_data(socket)
      {:ok, socket}
    else
      {:ok, socket}
    end
  end
  
  @impl true
  def handle_event("filter_by_agency", %{"agency" => agency_code}, socket) do
    # Filter cases by agency instead of scraping sessions
    socket = assign(socket, loading: true)
    {:noreply, load_filtered_cases(socket, agency_code)}
  end
  
  @impl true
  def handle_event("filter_by_date", %{"range" => date_range}, socket) do
    date_range_atom = String.to_atom(date_range)
    socket = assign(socket, date_range: date_range_atom, loading: true)
    {:noreply, load_scraping_data(socket)}
  end
  
  @impl true
  def handle_event("view_case_details", %{"case_id" => case_id}, socket) do
    case = Enum.find(socket.assigns.recent_cases, &(&1.id == case_id))
    socket = assign(socket, selected_case: case, show_case_details: true)
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("close_case_details", _params, socket) do
    socket = assign(socket, selected_case: nil, show_case_details: false)
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("refresh_data", _params, socket) do
    socket = assign(socket, loading: true)
    {:noreply, load_scraping_data(socket)}
  end
  
  @impl true
  def handle_event("navigate_to_scraping", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/cases/scrape")}
  end
  
  # PubSub Event Handling
  
  @impl true  
  def handle_info({:scraping_event, event_type, data}, socket) do
    # Handle scraping events for real-time updates
    Logger.debug("Received scraping event: #{event_type} - #{inspect(data)}")
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:scraping_data_loaded, data}, socket) do
    # Handle both sessions and cases data loading
    socket = socket
    |> assign(loading: false)
    |> then(fn socket ->
      if Map.has_key?(data, :sessions) do
        assign(socket,
          scraping_sessions: data.sessions,
          system_metrics: data.metrics
        )
      else
        socket
      end
    end)
    |> then(fn socket ->
      if Map.has_key?(data, :recent_cases) do
        assign(socket,
          recent_cases: data.recent_cases,
          case_stats: data.case_stats
        )
      else
        socket
      end
    end)
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:scraping_data_error, _error}, socket) do
    socket = assign(socket, loading: false)
    {:noreply, put_flash(socket, :error, "Failed to load scraping data")}
  end
  
  @impl true
  def handle_info({:filtered_sessions_loaded, data}, socket) do
    socket = assign(socket,
      scraping_sessions: data.sessions,
      loading: false
    )
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:filtered_cases_loaded, data}, socket) do
    socket = assign(socket,
      recent_cases: data.recent_cases,
      case_stats: data.case_stats,
      loading: false
    )
    
    {:noreply, socket}
  end
  
  # Private Functions
  
  defp load_scraping_data(socket) do
    Task.start_link(fn ->
      try do
        # Load recent cases using proper Ash query syntax
        recent_cases = Case
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.limit(20)
        |> Ash.Query.load([:agency, :offender])
        |> Ash.read!(actor: socket.assigns.current_user)
        
        # Calculate statistics from actual case data
        stats = calculate_case_statistics(recent_cases, socket.assigns.date_range)
        
        send(self(), {:scraping_data_loaded, %{
          recent_cases: recent_cases,
          case_stats: stats
        }})
        
      rescue
        error ->
          Logger.error("Failed to load scraping data: #{inspect(error)}")
          send(self(), {:scraping_data_error, error})
      end
    end)
    
    socket
  end
  
  defp load_filtered_cases(socket, agency_filter) do
    Task.start_link(fn ->
      try do
        # Build query with agency filter
        cases_query = Case
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.limit(50)
        |> Ash.Query.load([:agency, :offender])
        
        # Apply agency filter if not "all"
        cases_query = if agency_filter != "all" do
          agency_atom = String.to_atom(agency_filter)
          Ash.Query.filter(cases_query, agency.code == ^agency_atom)
        else
          cases_query
        end
        
        # Apply date range filter
        cases_query = apply_date_filter(cases_query, socket.assigns.date_range)
        
        filtered_cases = Ash.read!(cases_query, actor: socket.assigns.current_user)
        stats = calculate_case_statistics(filtered_cases, socket.assigns.date_range)
        
        send(self(), {:filtered_cases_loaded, %{
          recent_cases: filtered_cases,
          case_stats: stats
        }})
        
      rescue
        error ->
          Logger.error("Failed to load filtered cases: #{inspect(error)}")
          send(self(), {:scraping_data_error, error})
      end
    end)
    
    socket
  end
  
  defp apply_date_filter(query, date_range) do
    case date_range do
      :last_24_hours ->
        cutoff = DateTime.utc_now() |> DateTime.add(-1, :day)
        Ash.Query.filter(query, inserted_at >= ^cutoff)
      
      :last_7_days ->
        cutoff = DateTime.utc_now() |> DateTime.add(-7, :day)
        Ash.Query.filter(query, inserted_at >= ^cutoff)
      
      :last_30_days ->
        cutoff = DateTime.utc_now() |> DateTime.add(-30, :day)
        Ash.Query.filter(query, inserted_at >= ^cutoff)
      
      :all_time ->
        query
    end
  end
  
  defp calculate_case_statistics(cases, date_range) do
    total_cases = length(cases)
    
    # Count cases by agency
    hse_cases_count = Enum.count(cases, fn case -> case.agency.code == :hse end)
    
    # Calculate recent activity based on date range
    recent_cases_count = case date_range do
      :last_24_hours -> total_cases
      :last_7_days -> total_cases
      :last_30_days -> total_cases
      :all_time ->
        # For all_time, count only last 7 days as "recent"
        recent_cutoff = DateTime.utc_now() |> DateTime.add(-7, :day)
        Enum.count(cases, fn case ->
          case.inserted_at && DateTime.compare(case.inserted_at, recent_cutoff) == :gt
        end)
    end
    
    # Calculate average cases per day
    days_in_range = case date_range do
      :last_24_hours -> 1
      :last_7_days -> 7
      :last_30_days -> 30
      :all_time -> 30  # Use last 30 days for calculation
    end
    
    avg_cases_per_day = if total_cases > 0, do: total_cases / days_in_range, else: 0
    
    %{
      total_cases: total_cases,
      recent_cases_count: recent_cases_count,
      hse_cases_count: hse_cases_count,
      avg_cases_per_day: Float.round(avg_cases_per_day, 1)
    }
  end
  
  # Update message handlers for proper Ash data loading
  
  
  
  defp format_datetime(nil), do: "N/A"
  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
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
end