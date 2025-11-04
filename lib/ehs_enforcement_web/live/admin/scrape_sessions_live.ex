defmodule EhsEnforcementWeb.Admin.ScrapeSessionsLive do
  @moduledoc """
  Unified LiveView for displaying scraping session history with real-time updates.

  Features:
  - Real-time session monitoring via Phoenix PubSub
  - Session filtering and sorting (status and database type)
  - Session details and metrics
  - Proper Ash integration with actor context
  - Supports both case and notice scraping sessions
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
        page_title: "Scraping Sessions",

        # Loading state
        loading: false,

        # Filter state
        filter_status: "all",
        filter_database: "all",

        # Sessions data - initialize as empty, will be populated by handle_params
        all_sessions: [],

        # UI state
        last_update: System.monotonic_time(:millisecond)
      )

    # Load initial sessions data and set up PubSub subscriptions
    sessions =
      load_sessions(
        socket.assigns.filter_status,
        socket.assigns.filter_database,
        socket.assigns.current_user
      )

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
    socket =
      assign(socket,
        filter_status: "all",
        filter_database: "all",
        loading: true
      )

    # Reload sessions with cleared filters
    sessions = load_sessions("all", "all", socket.assigns.current_user)
    socket = assign(socket, all_sessions: sessions, loading: false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("kill_session", %{"session_id" => session_id}, socket) do
    case Ash.get(ScrapeSession, session_id, actor: socket.assigns.current_user) do
      {:ok, session} ->
        case Ash.update(session, %{}, action: :mark_stopped, actor: socket.assigns.current_user) do
          {:ok, _updated_session} ->
            # Reload sessions to reflect the change
            sessions =
              load_sessions(
                socket.assigns.filter_status,
                socket.assigns.filter_database,
                socket.assigns.current_user
              )

            socket =
              socket
              |> put_flash(:info, "Session #{String.slice(session_id, 0..7)} has been stopped")
              |> assign(all_sessions: sessions, last_update: System.monotonic_time(:millisecond))

            {:noreply, socket}

          {:error, error} ->
            Logger.error("Failed to stop session #{session_id}: #{inspect(error)}")

            socket =
              put_flash(
                socket,
                :error,
                "Failed to stop session: #{inspect(error)}"
              )

            {:noreply, socket}
        end

      {:error, error} ->
        Logger.error("Failed to find session #{session_id}: #{inspect(error)}")

        socket =
          put_flash(
            socket,
            :error,
            "Session not found: #{inspect(error)}"
          )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("kill_all_running", _params, socket) do
    # Query all active sessions (pending or running)
    active_query =
      ScrapeSession
      |> Ash.Query.filter(status in [:pending, :running])

    case Ash.read(active_query, actor: socket.assigns.current_user) do
      {:ok, active_sessions} ->
        # Stop each active session
        results =
          Enum.map(active_sessions, fn session ->
            Ash.update(session, %{}, action: :mark_stopped, actor: socket.assigns.current_user)
          end)

        # Count successes
        success_count = Enum.count(results, fn result -> match?({:ok, _}, result) end)
        error_count = Enum.count(results, fn result -> match?({:error, _}, result) end)

        # Reload sessions to reflect the changes
        sessions =
          load_sessions(
            socket.assigns.filter_status,
            socket.assigns.filter_database,
            socket.assigns.current_user
          )

        socket =
          socket
          |> put_flash(
            :info,
            "Stopped #{success_count} session(s)#{if error_count > 0, do: " (#{error_count} failed)", else: ""}"
          )
          |> assign(all_sessions: sessions, last_update: System.monotonic_time(:millisecond))

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to query active sessions: #{inspect(error)}")

        socket =
          put_flash(
            socket,
            :error,
            "Failed to query active sessions: #{inspect(error)}"
          )

        {:noreply, socket}
    end
  end

  # Handle scrape session updates
  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "scrape_session:updated",
          event: "update",
          payload: %Ash.Notifier.Notification{}
        },
        socket
      ) do
    # Reload sessions to reflect updates
    sessions =
      load_sessions(
        socket.assigns.filter_status,
        socket.assigns.filter_database,
        socket.assigns.current_user
      )

    socket =
      assign(socket, all_sessions: sessions, last_update: System.monotonic_time(:millisecond))

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "scrape_session:created",
          event: "create",
          payload: %Ash.Notifier.Notification{}
        },
        socket
      ) do
    # Reload sessions to include new session
    sessions =
      load_sessions(
        socket.assigns.filter_status,
        socket.assigns.filter_database,
        socket.assigns.current_user
      )

    socket =
      assign(socket, all_sessions: sessions, last_update: System.monotonic_time(:millisecond))

    {:noreply, socket}
  end

  # Catch-all handler for debugging
  @impl true
  def handle_info(message, socket) do
    Logger.debug(
      "ScrapeSessionsLive: Received unhandled message: #{inspect(message, limit: :infinity) |> String.slice(0, 200)}..."
    )

    {:noreply, socket}
  end

  # Private Functions

  defp load_sessions(status_filter, database_filter, actor) do
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

    # Apply database filter
    final_query =
      case database_filter do
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
      {max_pages, processed}
      when is_integer(max_pages) and max_pages > 0 and is_integer(processed) ->
        min(100, processed / max_pages * 100)

      _ ->
        0
    end
  end

  defp database_type_badge_class(database) do
    case database do
      "convictions" -> "bg-red-100 text-red-800"
      "notices" -> "bg-yellow-100 text-yellow-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp format_database_type(database) do
    case database do
      "convictions" -> "Cases"
      "notices" -> "Notices"
      _ -> String.capitalize(database || "Unknown")
    end
  end
end
