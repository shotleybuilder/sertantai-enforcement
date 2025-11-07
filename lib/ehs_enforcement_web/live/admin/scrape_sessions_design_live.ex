defmodule EhsEnforcementWeb.Admin.ScrapeSessionsDesignLive do
  @moduledoc """
  LiveView for displaying scraping session DESIGN parameters (WHAT was scraped).

  This view focuses on session configuration and parameters, complementing
  the execution-focused scrape_sessions_live.ex view.

  Features:
  - Display session design parameters (dates, action types, page ranges, etc.)
  - Agency-specific parameter rendering (HSE vs EA)
  - Real-time updates via Phoenix PubSub
  - Session filtering by agency and status
  """

  use EhsEnforcementWeb, :live_view

  require Logger
  require Ash.Query

  alias EhsEnforcement.Scraping.ScrapeSession

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        # Page metadata
        page_title: "Session Design Parameters",

        # Loading state
        loading: false,

        # Filter state
        filter_status: "all",
        filter_agency: "all",

        # Sessions data - initialize as empty, will be populated by handle_params
        all_sessions: [],

        # UI state
        last_update: System.monotonic_time(:millisecond)
      )

    if connected?(socket) do
      # Subscribe to scrape session events for real-time updates
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "scrape_session:created")
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "scrape_session:updated")
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    # Only load sessions if WebSocket is connected (current_user is available)
    if connected?(socket) do
      sessions =
        load_sessions(
          socket.assigns.filter_status,
          socket.assigns.filter_agency,
          socket.assigns.current_user
        )

      {:noreply, assign(socket, all_sessions: sessions)}
    else
      # During initial HTTP request, just return the socket
      # Sessions will be loaded after WebSocket connects
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    socket = assign(socket, filter_status: status, loading: true)
    sessions = load_sessions(status, socket.assigns.filter_agency, socket.assigns.current_user)
    socket = assign(socket, all_sessions: sessions, loading: false)
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_agency", %{"agency" => agency}, socket) do
    socket = assign(socket, filter_agency: agency, loading: true)
    sessions = load_sessions(socket.assigns.filter_status, agency, socket.assigns.current_user)
    socket = assign(socket, all_sessions: sessions, loading: false)
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    socket = assign(socket, filter_status: "all", filter_agency: "all", loading: true)
    sessions = load_sessions("all", "all", socket.assigns.current_user)
    socket = assign(socket, all_sessions: sessions, loading: false)
    {:noreply, socket}
  end

  # Handle scrape session updates
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "scrape_session:updated"}, socket) do
    sessions =
      load_sessions(
        socket.assigns.filter_status,
        socket.assigns.filter_agency,
        socket.assigns.current_user
      )

    socket =
      assign(socket, all_sessions: sessions, last_update: System.monotonic_time(:millisecond))

    {:noreply, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "scrape_session:created"}, socket) do
    sessions =
      load_sessions(
        socket.assigns.filter_status,
        socket.assigns.filter_agency,
        socket.assigns.current_user
      )

    socket =
      assign(socket, all_sessions: sessions, last_update: System.monotonic_time(:millisecond))

    {:noreply, socket}
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  # Private Functions

  defp load_sessions(status_filter, agency_filter, actor) do
    base_query =
      ScrapeSession
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(100)

    # Apply status filter
    query_with_status =
      case status_filter do
        "all" -> base_query
        "active" -> Ash.Query.filter(base_query, status in [:pending, :running])
        "completed" -> Ash.Query.filter(base_query, status == :completed)
        "failed" -> Ash.Query.filter(base_query, status in [:failed, :stopped])
        _ -> base_query
      end

    # Apply agency filter
    final_query =
      case agency_filter do
        "all" -> query_with_status
        "hse" -> Ash.Query.filter(query_with_status, agency == :hse)
        "ea" -> Ash.Query.filter(query_with_status, agency == :environment_agency)
        _ -> query_with_status
      end

    Ash.read!(final_query, actor: actor)
  end

  # Detect agency - handles legacy EA sessions that have :hse agency but "ea_enforcement" database
  defp detect_agency(session) do
    cond do
      # Check agency field first (most reliable)
      session.agency == :environment_agency -> :environment_agency
      session.agency == :ea -> :ea
      # Check database field for legacy sessions or when agency not set properly
      session.database in ["ea_enforcement", "Ea_notices", "ea_notices"] -> :environment_agency
      # Default to HSE for all other cases (convictions, notices, appeals)
      true -> :hse
    end
  end

  defp agency_badge_class(agency) do
    case agency do
      :hse -> "bg-blue-100 text-blue-800"
      :environment_agency -> "bg-green-100 text-green-800"
      :ea -> "bg-green-100 text-green-800"
    end
  end

  defp format_agency(agency) do
    case agency do
      :hse -> "HSE"
      :environment_agency -> "EA"
      :ea -> "EA"
    end
  end

  defp format_date_range(nil, nil), do: "N/A"
  defp format_date_range(date_from, nil), do: "From #{format_date(date_from)}"
  defp format_date_range(nil, date_to), do: "Until #{format_date(date_to)}"

  defp format_date_range(date_from, date_to) do
    "#{format_date(date_from)} - #{format_date(date_to)}"
  end

  defp format_date(date) when is_struct(date, Date) do
    Calendar.strftime(date, "%b %Y")
  end

  defp format_date(_), do: "N/A"

  defp format_action_types(nil), do: []

  defp format_action_types(action_types) when is_list(action_types) do
    Enum.map(action_types, &format_action_type/1)
  end

  defp format_action_types(_), do: []

  defp format_action_type(action_type) do
    case action_type do
      :court_case -> "Court Case"
      :caution -> "Caution"
      :enforcement_notice -> "Enforcement Notice"
      _ -> action_type |> to_string() |> String.capitalize()
    end
  end

  defp action_type_badge_class(action_type) do
    case action_type do
      :court_case -> "bg-red-100 text-red-800"
      :caution -> "bg-yellow-100 text-yellow-800"
      :enforcement_notice -> "bg-blue-100 text-blue-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
end
