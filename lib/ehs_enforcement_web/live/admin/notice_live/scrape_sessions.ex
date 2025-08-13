defmodule EhsEnforcementWeb.Admin.NoticeLive.ScrapeSessions do
  @moduledoc """
  LiveView for displaying notice scraping session history with real-time updates.
  
  Features:
  - Real-time session monitoring via Phoenix PubSub
  - Session filtering and sorting
  - Session details and metrics
  - Proper Ash integration with actor context
  """
  
  use EhsEnforcementWeb, :live_view
  
  require Logger
  require Ash.Query
  
  alias EhsEnforcement.Scraping.ScrapeSession
  
  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket,
      # Page metadata
      page_title: "Notice Scraping Sessions",
      
      # Loading state
      loading: false,
      
      # Filter state
      filter_status: "all",
      filter_database: "notices",
      
      # Sessions data - initialize as empty, will be populated by keep_live
      all_sessions: [],
      
      # UI state
      last_update: System.monotonic_time(:millisecond)
    )
    
    # Load initial sessions data and set up PubSub subscriptions
    sessions = load_sessions(socket.assigns.filter_status, socket.assigns.filter_database, socket.assigns.current_user)
    socket = assign(socket, all_sessions: sessions)
    
    if connected?(socket) do
      # Subscribe to scrape session events for real-time updates
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "scrape_session:created")
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "scrape_session:updated")
      {:ok, socket}
    else
      {:ok, socket}
    end
  end
  
  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    socket = assign(socket, filter_status: status, loading: true)
    
    # Reload sessions with new filter
    sessions = load_sessions(status, socket.assigns.filter_database, socket.assigns.current_user)
    socket = assign(socket, all_sessions: sessions, loading: false)
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("filter_database", %{"database" => database}, socket) do
    socket = assign(socket, filter_database: database, loading: true)
    
    # Reload sessions with new filter
    sessions = load_sessions(socket.assigns.filter_status, database, socket.assigns.current_user)
    socket = assign(socket, all_sessions: sessions, loading: false)
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("clear_filters", _params, socket) do
    socket = assign(socket, 
      filter_status: "all", 
      filter_database: "notices",
      loading: true
    )
    
    # Reload sessions with cleared filters
    sessions = load_sessions("all", "notices", socket.assigns.current_user)
    socket = assign(socket, all_sessions: sessions, loading: false)
    
    {:noreply, socket}
  end
  
  # Handle scrape session updates
  @impl true  
  def handle_info(%Phoenix.Socket.Broadcast{topic: "scrape_session:updated", event: "update", payload: %Ash.Notifier.Notification{}}, socket) do
    # Reload sessions to reflect updates
    sessions = load_sessions(socket.assigns.filter_status, socket.assigns.filter_database, socket.assigns.current_user)
    socket = assign(socket, all_sessions: sessions, last_update: System.monotonic_time(:millisecond))
    {:noreply, socket}
  end
  
  @impl true  
  def handle_info(%Phoenix.Socket.Broadcast{topic: "scrape_session:created", event: "create", payload: %Ash.Notifier.Notification{}}, socket) do
    # Reload sessions to include new session
    sessions = load_sessions(socket.assigns.filter_status, socket.assigns.filter_database, socket.assigns.current_user)
    socket = assign(socket, all_sessions: sessions, last_update: System.monotonic_time(:millisecond))
    {:noreply, socket}
  end
  
  # Catch-all handler for debugging
  @impl true
  def handle_info(message, socket) do
    Logger.debug("ScrapeSessions: Received unhandled message: #{inspect(message, limit: :infinity) |> String.slice(0, 200)}...")
    {:noreply, socket}
  end
  
  # Private Functions
  
  defp load_sessions(status_filter, database_filter, actor) do
    base_query = ScrapeSession
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(100)
    
    # Apply status filter
    query_with_status = case status_filter do
      "all" -> base_query
      "active" -> Ash.Query.filter(base_query, status in [:pending, :running])
      "completed" -> Ash.Query.filter(base_query, status == :completed)
      "failed" -> Ash.Query.filter(base_query, status in [:failed, :stopped])
      _ -> base_query
    end
    
    # Apply database filter
    final_query = case database_filter do
      "all" -> query_with_status
      db -> Ash.Query.filter(query_with_status, database == ^db)
    end
    
    Ash.read!(final_query, actor: actor)
  end
  
  defp status_badge_class(status) do
    case status do
      :pending -> "bg-yellow-100 text-yellow-800"
      :running -> "bg-blue-100 text-blue-800"
      :completed -> "bg-green-100 text-green-800"
      :failed -> "bg-red-100 text-red-800"
      :stopped -> "bg-gray-100 text-gray-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
  
  defp format_status(status) do
    case status do
      :pending -> "Pending"
      :running -> "Running"
      :completed -> "Completed"
      :failed -> "Failed"
      :stopped -> "Stopped"
      _ -> "Unknown"
    end
  end
  
  defp session_duration(session) do
    case session.status do
      status when status in [:completed, :failed, :stopped] ->
        # Calculate duration from inserted_at to updated_at
        duration_seconds = DateTime.diff(session.updated_at, session.inserted_at, :second)
        format_duration(duration_seconds)
      
      status when status in [:running, :pending] ->
        # Calculate duration from inserted_at to now
        duration_seconds = DateTime.diff(DateTime.utc_now(), session.inserted_at, :second)
        "#{format_duration(duration_seconds)} (ongoing)"
      
      _ ->
        "N/A"
    end
  end
  
  defp format_duration(seconds) when seconds < 60 do
    "#{seconds}s"
  end
  
  defp format_duration(seconds) when seconds < 3600 do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}m #{remaining_seconds}s"
  end
  
  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    remaining_seconds = rem(seconds, 3600)
    minutes = div(remaining_seconds, 60)
    seconds = rem(remaining_seconds, 60)
    "#{hours}h #{minutes}m #{seconds}s"
  end
  
  defp progress_percentage(session) do
    case {session.max_pages, session.pages_processed} do
      {max_pages, processed} when is_integer(max_pages) and max_pages > 0 and is_integer(processed) ->
        min(100, (processed / max_pages) * 100)
      
      _ -> 
        0
    end
  end
end