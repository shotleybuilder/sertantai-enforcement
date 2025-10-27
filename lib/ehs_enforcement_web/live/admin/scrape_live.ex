defmodule EhsEnforcementWeb.Admin.ScrapeLive do
  @moduledoc """
  Unified admin interface for scraping all agencies and enforcement types.

  This LiveView uses the Strategy Pattern to provide a single interface for:
  - HSE case scraping
  - HSE notice scraping
  - Environment Agency case scraping
  - Environment Agency notice scraping

  The strategy is selected based on URL parameters (:agency and :type),
  and all agency-specific logic is delegated to the appropriate strategy module.

  ## Routes
  - `/admin/scrape/hse/case` - HSE case scraping
  - `/admin/scrape/hse/notice` - HSE notice scraping
  - `/admin/scrape/environment_agency/case` - EA case scraping
  - `/admin/scrape/environment_agency/notice` - EA notice scraping

  ## Features
  - Strategy-based scraping (pluggable agency/type implementations)
  - Real-time progress updates via Phoenix PubSub
  - Strategy-specific parameter forms
  - Unified progress display
  - Error handling and recovery
  """

  use EhsEnforcementWeb, :live_view

  require Logger
  require Ash.Query

  alias EhsEnforcement.Scraping.StrategyRegistry
  alias EhsEnforcement.Scraping.ScrapeCoordinator
  alias EhsEnforcement.Scraping.ScrapeSession
  alias EhsEnforcement.Enforcement.Notice
  alias EhsEnforcement.Enforcement.Case
  alias Phoenix.PubSub
  alias EhsEnforcementWeb.Components.ProgressComponent

  # LiveView Callbacks

  @impl true
  def mount(%{"agency" => agency_str, "type" => type_str}, _session, socket) do
    # Parse URL parameters
    with {:ok, agency_atom} <- parse_agency(agency_str),
         {:ok, type_atom} <- parse_type(type_str),
         {:ok, strategy} <- StrategyRegistry.get_strategy(agency_atom, type_atom) do

      socket =
        socket
        |> assign(:strategy, strategy)
        |> assign(:agency, agency_atom)
        |> assign(:enforcement_type, type_atom)
        |> assign(:strategy_name, strategy.strategy_name())
        |> assign(:current_session, nil)
        |> assign(:scraping_active, false)
        |> assign(:scraping_session_started_at, nil)
        |> assign(:progress, initial_progress())
        |> assign(:form_params, default_form_params(strategy, agency_atom))
        |> assign(:validation_errors, %{})
        |> assign(:loading, false)
        |> assign(:scraped_records, [])

      # Add reactive data loading when connected
      if connected?(socket) do
        # Subscribe to PubSub events for progress tracking
        PubSub.subscribe(EhsEnforcement.PubSub, "scrape_session:created")
        PubSub.subscribe(EhsEnforcement.PubSub, "scrape_session:updated")

        # Subscribe to record creation events based on enforcement type
        case type_atom do
          :notice ->
            PubSub.subscribe(EhsEnforcement.PubSub, "notice:created")
            PubSub.subscribe(EhsEnforcement.PubSub, "notice:updated")
          :case ->
            PubSub.subscribe(EhsEnforcement.PubSub, "case:created")
            PubSub.subscribe(EhsEnforcement.PubSub, "case:updated")
        end

        # Add reactive data loading with keep_live
        socket = add_reactive_data_loading(socket, type_atom)
        {:ok, socket}
      else
        # Initialize empty assigns for disconnected state
        socket =
          socket
          |> assign(:recent_records, [])
          |> assign(:session_results, [])
        {:ok, socket}
      end
    else
      {:error, :invalid_agency} ->
        socket =
          socket
          |> put_flash(:error, "Invalid agency: #{agency_str}")
          |> redirect(to: ~p"/admin")

        {:ok, socket}

      {:error, :invalid_type} ->
        socket =
          socket
          |> put_flash(:error, "Invalid enforcement type: #{type_str}")
          |> redirect(to: ~p"/admin")

        {:ok, socket}

      {:error, :strategy_not_found} ->
        socket =
          socket
          |> put_flash(:error, "No scraping strategy found for #{agency_str}/#{type_str}")
          |> redirect(to: ~p"/admin")

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("start_scraping", params, socket) do
    strategy = socket.assigns.strategy

    # Validate parameters using strategy
    case strategy.validate_params(params) do
      {:ok, validated_params} ->
        # Start scraping session
        opts = [
          agency: socket.assigns.agency,
          enforcement_type: socket.assigns.enforcement_type
        ] ++ Map.to_list(validated_params)

        case ScrapeCoordinator.start_scraping_session(opts) do
          {:ok, session_id} ->
            Logger.info("Scraping session started",
              agency: socket.assigns.agency,
              type: socket.assigns.enforcement_type,
              session_id: session_id
            )

            socket =
              socket
              |> assign(:scraping_active, true)
              |> assign(:scraping_session_started_at, DateTime.utc_now())
              |> assign(:scraped_records, [])
              |> assign(:validation_errors, %{})
              |> put_flash(:info, "Scraping started successfully")

            {:noreply, socket}

          {:error, reason} ->
            Logger.error("Failed to start scraping",
              agency: socket.assigns.agency,
              type: socket.assigns.enforcement_type,
              reason: reason
            )

            socket = put_flash(socket, :error, "Failed to start scraping: #{inspect(reason)}")
            {:noreply, socket}
        end

      {:error, reason} ->
        Logger.warning("Invalid scraping parameters",
          agency: socket.assigns.agency,
          type: socket.assigns.enforcement_type,
          reason: reason
        )

        socket =
          socket
          |> assign(:validation_errors, %{general: reason})
          |> put_flash(:error, "Invalid parameters: #{reason}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("stop_scraping", _params, socket) do
    # TODO: Implement stop scraping functionality
    # For now, just update state
    socket =
      socket
      |> assign(:scraping_active, false)
      |> put_flash(:info, "Scraping stopped")

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_session", _params, socket) do
    socket =
      socket
      |> assign(:current_session, nil)
      |> assign(:scraping_active, false)
      |> assign(:progress, initial_progress())
      |> assign(:validation_errors, %{})
      |> put_flash(:info, "Session cleared")

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_scraped_records", _params, socket) do
    socket =
      socket
      |> assign(:scraped_records, [])
      |> assign(:scraping_session_started_at, nil)
      |> put_flash(:info, "Scraped records cleared")

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_params", params, socket) do
    strategy = socket.assigns.strategy

    case strategy.validate_params(params) do
      {:ok, _validated} ->
        {:noreply, assign(socket, :validation_errors, %{})}

      {:error, reason} ->
        {:noreply, assign(socket, :validation_errors, %{general: reason})}
    end
  end

  # PubSub Event Handlers

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "scrape_session:created",
          event: "create",
          payload: %Ash.Notifier.Notification{data: session_data}
        },
        socket
      ) do
    # Check if this session is for our agency/type
    if session_matches?(session_data, socket.assigns.agency, socket.assigns.enforcement_type) do
      Logger.debug("Scrape session created",
        session_id: session_data.id,
        agency: socket.assigns.agency,
        type: socket.assigns.enforcement_type
      )

      socket =
        socket
        |> assign(:current_session, session_data)
        |> assign(:scraping_active, true)
        |> update_progress_from_session(session_data)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "scrape_session:updated",
          event: "update",
          payload: %Ash.Notifier.Notification{data: session_data}
        },
        socket
      ) do
    # Check if this is our current session
    current_session = socket.assigns.current_session

    if current_session && current_session.id == session_data.id do
      Logger.debug("Scrape session updated",
        session_id: session_data.id,
        status: session_data.status,
        progress: calculate_session_progress(session_data, socket.assigns.strategy)
      )

      socket =
        socket
        |> assign(:current_session, session_data)
        |> assign(:scraping_active, session_data.status == :running)
        |> update_progress_from_session(session_data)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_msg, socket) do
    # Ignore unknown messages
    {:noreply, socket}
  end

  # Template Rendering

  # Handle scrape session updates from PubSub
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "scrape_session:updated", payload: %Ash.Notifier.Notification{} = notification}, socket) do
    session_data = notification.data

    # Only update if this is our active session
    if socket.assigns.scraping_active do
      Logger.debug("Scrape session update: status=#{session_data.status}, pages_processed=#{session_data.pages_processed}, cases_found=#{session_data.cases_found}")

      updated_progress = %{
        status: session_data.status,
        current_page: session_data.current_page,
        pages_processed: session_data.pages_processed,
        cases_found: session_data.cases_found || 0,
        cases_processed: session_data.cases_processed || 0,
        cases_created: session_data.cases_created || 0,
        cases_created_current_page: session_data.cases_created_current_page || 0,
        cases_updated: session_data.cases_updated || 0,
        cases_updated_current_page: session_data.cases_updated_current_page || 0,
        cases_exist_total: session_data.cases_exist_total || 0,
        cases_exist_current_page: session_data.cases_exist_current_page || 0,
        errors_count: session_data.errors_count || 0,
        max_pages: session_data.max_pages
      }

      # When session becomes completed, update scraping_active
      socket = if session_data.status == :completed do
        assign(socket,
          progress: updated_progress,
          scraping_active: false,
          current_session: nil,
          scraping_session_started_at: nil
        )
      else
        assign(socket, progress: updated_progress)
      end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Handle record creation during active scraping - notices
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "notice:created", event: "create", payload: %Ash.Notifier.Notification{} = notification}, socket) do
    # Only add to scraped_records if we have an active session
    socket = if socket.assigns.scraping_session_started_at do
      # Load full notice data with associations
      notice = Notice
      |> Ash.get!(notification.data.id, load: [:agency, :offender], actor: socket.assigns.current_user)

      # Add to the beginning of the list (most recent first)
      updated_scraped_records = [notice | socket.assigns.scraped_records]

      assign(socket, scraped_records: updated_scraped_records)
    else
      socket
    end

    {:noreply, socket}
  end

  # Handle record creation during active scraping - cases
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "case:created", event: "create", payload: %Ash.Notifier.Notification{} = notification}, socket) do
    # Only add to scraped_records if we have an active session
    socket = if socket.assigns.scraping_session_started_at do
      # Load full case data with associations
      case_record = Case
      |> Ash.get!(notification.data.id, load: [:agency, :offender], actor: socket.assigns.current_user)

      # Add to the beginning of the list (most recent first)
      updated_scraped_records = [case_record | socket.assigns.scraped_records]

      assign(socket, scraped_records: updated_scraped_records)
    else
      socket
    end

    {:noreply, socket}
  end

  # Ignore other PubSub events
  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <!-- Page Header -->
      <div class="md:flex md:items-center md:justify-between mb-8">
        <div class="flex-1 min-w-0">
          <h1 class="text-3xl font-bold text-gray-900 dark:text-white">
            {@strategy_name}
          </h1>
          <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
            Manual scraping interface for {agency_display_name(@agency)} {type_display_name(@enforcement_type)}
          </p>
        </div>
        <div class="mt-4 flex md:mt-0 md:ml-4">
          <.link
            navigate={~p"/admin"}
            class="inline-flex items-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700"
          >
            <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to Admin
          </.link>
        </div>
      </div>

      <!-- Flash Messages -->
      <.flash_group flash={@flash} />

      <!-- Scraping Form -->
      <div class="bg-white dark:bg-gray-800 shadow rounded-lg mb-8">
        <div class="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
          <h2 class="text-lg font-medium text-gray-900 dark:text-white">
            Scraping Parameters
          </h2>
        </div>
        <div class="px-6 py-4">
          <.form for={%{}} phx-submit="start_scraping" phx-change="validate_params">
            <%= render_form_fields(assigns) %>

            <div class="mt-6 flex items-center justify-between">
              <div class="text-sm text-gray-500 dark:text-gray-400">
                <%= if @scraping_active do %>
                  <span class="inline-flex items-center">
                    <.icon name="hero-arrow-path" class="animate-spin mr-2 h-4 w-4" />
                    Scraping in progress...
                  </span>
                <% else %>
                  <span>Ready to start scraping</span>
                <% end %>
              </div>

              <div class="flex space-x-3">
                <%= if @scraping_active do %>
                  <button
                    type="button"
                    phx-click="stop_scraping"
                    class="inline-flex items-center px-4 py-2 border border-red-300 dark:border-red-600 rounded-md shadow-sm text-sm font-medium text-red-700 dark:text-red-200 bg-white dark:bg-gray-800 hover:bg-red-50 dark:hover:bg-red-900"
                  >
                    <.icon name="hero-stop" class="mr-2 h-4 w-4" /> Stop Scraping
                  </button>
                <% else %>
                  <button
                    type="submit"
                    disabled={@scraping_active}
                    class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <.icon name="hero-play" class="mr-2 h-4 w-4" /> Start Scraping
                  </button>
                <% end %>
              </div>
            </div>

            <%= if @validation_errors[:general] do %>
              <div class="mt-4 p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-md">
                <p class="text-sm text-red-700 dark:text-red-300">
                  {@validation_errors[:general]}
                </p>
              </div>
            <% end %>
          </.form>
        </div>
      </div>

      <!-- Progress Display - Always visible -->
      <div class="bg-white dark:bg-gray-800 shadow rounded-lg mb-8">
        <div class="px-6 py-4">
          <%= render_progress(assigns) %>
        </div>
      </div>

      <!-- Live Scraped Records (During Active Session) -->
      <%= if @scraping_session_started_at && length(@scraped_records) > 0 do %>
        <div class="bg-white dark:bg-gray-800 shadow rounded-lg mb-8">
          <div class="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
            <div class="flex items-center justify-between">
              <div>
                <h2 class="text-lg font-medium text-gray-900 dark:text-white">
                  Scraped {String.capitalize(to_string(@enforcement_type))}s (This Session)
                </h2>
                <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                  {length(@scraped_records)} {type_display_name(@enforcement_type)}s scraped in current session
                </p>
              </div>
              <button
                type="button"
                phx-click="clear_scraped_records"
                class="text-sm text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
              >
                Clear
              </button>
            </div>
          </div>
          <div class="px-6 py-4">
            <%= render_scraped_records(assigns) %>
          </div>
        </div>
      <% end %>

    </div>
    """
  end

  # Private Helper Functions

  defp add_reactive_data_loading(socket, _enforcement_type) do
    # No reactive data loading needed - we only show current session data
    socket
  end

  defp parse_agency("hse"), do: {:ok, :hse}
  defp parse_agency("ea"), do: {:ok, :ea}
  defp parse_agency("environment_agency"), do: {:ok, :ea}  # Support long form URL
  defp parse_agency(_), do: {:error, :invalid_agency}

  defp parse_type("case"), do: {:ok, :case}
  defp parse_type("notice"), do: {:ok, :notice}
  defp parse_type(_), do: {:error, :invalid_type}

  defp initial_progress do
    %{
      status: :idle,
      current_page: nil,
      pages_processed: 0,
      cases_found: 0,
      cases_processed: 0,
      cases_created: 0,
      cases_created_current_page: 0,
      cases_updated: 0,
      cases_updated_current_page: 0,
      cases_exist_total: 0,
      cases_exist_current_page: 0,
      errors_count: 0,
      max_pages: nil
    }
  end

  defp default_form_params(strategy, agency) do
    case agency do
      :hse ->
        %{
          "start_page" => "1",
          "max_pages" => "10",
          "database" => "convictions"
        }

      :ea ->
        %{
          "date_from" => Date.add(Date.utc_today(), -30) |> Date.to_string(),
          "date_to" => Date.utc_today() |> Date.to_string(),
          "action_types" =>
            if strategy.enforcement_type() == :case do
              ["court_case"]
            else
              ["enforcement_notice"]
            end
        }
    end
  end

  defp session_matches?(session, agency, enforcement_type) do
    session.agency == agency && session.enforcement_type == enforcement_type
  end

  defp update_progress_from_session(socket, session) do
    strategy = socket.assigns.strategy
    progress_display = strategy.format_progress_display(session)

    assign(socket, :progress, progress_display)
  end

  defp calculate_session_progress(session, strategy) do
    strategy.calculate_progress(session)
  end

  defp agency_display_name(:hse), do: "Health & Safety Executive (HSE)"
  defp agency_display_name(:ea), do: "Environment Agency (EA)"
  defp agency_display_name(agency), do: to_string(agency)

  defp type_display_name(:case), do: "Cases"
  defp type_display_name(:notice), do: "Notices"
  defp type_display_name(type), do: to_string(type)

  # Recent Records Rendering

  defp render_recent_records(%{enforcement_type: :notice} = assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead class="bg-gray-50 dark:bg-gray-700/50">
          <tr>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Offender
            </th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Agency
            </th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Notice Type
            </th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Date
            </th>
          </tr>
        </thead>
        <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
          <%= for notice <- @recent_records do %>
            <tr class="hover:bg-gray-50 dark:hover:bg-gray-700/50">
              <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                {notice.offender.name}
              </td>
              <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                {notice.agency.name}
              </td>
              <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                {notice.offence_action_type || "N/A"}
              </td>
              <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                {Calendar.strftime(notice.inserted_at, "%Y-%m-%d")}
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp render_recent_records(%{enforcement_type: :case} = assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead class="bg-gray-50 dark:bg-gray-700/50">
          <tr>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Offender
            </th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Agency
            </th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Offences
            </th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Date
            </th>
          </tr>
        </thead>
        <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
          <%= for case <- @recent_records do %>
            <tr class="hover:bg-gray-50 dark:hover:bg-gray-700/50">
              <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                {case.offender.name}
              </td>
              <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                {case.agency.name}
              </td>
              <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                {length(case.offences)} offences
              </td>
              <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                {Calendar.strftime(case.inserted_at, "%Y-%m-%d")}
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  # Scraped Records Rendering (Live session updates)

  defp render_scraped_records(%{enforcement_type: :notice, scraped_records: records} = assigns) do
    assigns = assign(assigns, :records, records)

    ~H"""
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead class="bg-gray-50 dark:bg-gray-700/50">
          <tr>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">Offender</th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">Agency</th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">Type</th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">Date</th>
          </tr>
        </thead>
        <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
          <%= for notice <- @records do %>
            <tr class="hover:bg-gray-50 dark:hover:bg-gray-700/50">
              <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                {notice.offender.name}
              </td>
              <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                {notice.agency.name}
              </td>
              <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                {notice.offence_action_type || "N/A"}
              </td>
              <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                {Calendar.strftime(notice.inserted_at, "%Y-%m-%d")}
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp render_scraped_records(%{enforcement_type: :case, scraped_records: records} = assigns) do
    assigns = assign(assigns, :records, records)

    ~H"""
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead class="bg-gray-50 dark:bg-gray-700/50">
          <tr>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">Offender</th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">Agency</th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">Date</th>
          </tr>
        </thead>
        <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
          <%= for case <- @records do %>
            <tr class="hover:bg-gray-50 dark:hover:bg-gray-700/50">
              <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                {case.offender.name}
              </td>
              <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                {case.agency.name}
              </td>
              <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                {Calendar.strftime(case.inserted_at, "%Y-%m-%d")}
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp render_session_results(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead class="bg-gray-50 dark:bg-gray-700/50">
          <tr>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Started
            </th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Status
            </th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Records
            </th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Duration
            </th>
          </tr>
        </thead>
        <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
          <%= for session <- @session_results do %>
            <tr class="hover:bg-gray-50 dark:hover:bg-gray-700/50">
              <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                {Calendar.strftime(session.inserted_at, "%Y-%m-%d %H:%M")}
              </td>
              <td class="px-4 py-3 text-sm">
                {render_status_badge(session.status)}
              </td>
              <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                <%= if session.cases_created do %>
                  {session.cases_created} cases
                <% else %>
                  {session.notices_created || 0} notices
                <% end %>
              </td>
              <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                <%= if session.updated_at && session.status == :completed do %>
                  {format_duration(session.inserted_at, session.updated_at)}
                <% else %>
                  In progress...
                <% end %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp format_duration(started_at, completed_at) do
    duration_seconds = DateTime.diff(completed_at, started_at)
    minutes = div(duration_seconds, 60)
    seconds = rem(duration_seconds, 60)

    if minutes > 0 do
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end

  # Form Rendering

  defp render_form_fields(%{agency: :hse} = assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-6 sm:grid-cols-3">
      <div>
        <label for="start_page" class="block text-sm font-medium text-gray-700 dark:text-gray-300">
          Start Page
        </label>
        <input
          type="number"
          name="start_page"
          id="start_page"
          value={@form_params["start_page"]}
          min="1"
          class="mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:text-white sm:text-sm"
          required
        />
      </div>

      <div>
        <label for="max_pages" class="block text-sm font-medium text-gray-700 dark:text-gray-300">
          Max Pages
        </label>
        <input
          type="number"
          name="max_pages"
          id="max_pages"
          value={@form_params["max_pages"]}
          min="1"
          max="100"
          class="mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:text-white sm:text-sm"
          required
        />
      </div>

      <div>
        <label for="database" class="block text-sm font-medium text-gray-700 dark:text-gray-300">
          Database
        </label>
        <select
          name="database"
          id="database"
          class="mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:text-white sm:text-sm"
          required
        >
          <option value="convictions" selected={@form_params["database"] == "convictions"}>
            Convictions
          </option>
          <option value="notices" selected={@form_params["database"] == "notices"}>Notices</option>
          <option value="appeals" selected={@form_params["database"] == "appeals"}>Appeals</option>
        </select>
      </div>
    </div>
    """
  end

  defp render_form_fields(%{agency: :ea} = assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
      <div>
        <label for="date_from" class="block text-sm font-medium text-gray-700 dark:text-gray-300">
          Date From
        </label>
        <input
          type="date"
          name="date_from"
          id="date_from"
          value={@form_params["date_from"]}
          class="mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:text-white sm:text-sm"
          required
        />
      </div>

      <div>
        <label for="date_to" class="block text-sm font-medium text-gray-700 dark:text-gray-300">
          Date To
        </label>
        <input
          type="date"
          name="date_to"
          id="date_to"
          value={@form_params["date_to"]}
          class="mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:text-white sm:text-sm"
          required
        />
      </div>

      <%= if @enforcement_type == :case do %>
        <div class="sm:col-span-2">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Action Types
          </label>
          <div class="space-y-2">
            <div class="flex items-center">
              <input
                type="checkbox"
                name="action_types[]"
                id="action_type_court_case"
                value="court_case"
                checked={Enum.member?(@form_params["action_types"] || [], "court_case")}
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-gray-600 rounded"
              />
              <label
                for="action_type_court_case"
                class="ml-2 block text-sm text-gray-700 dark:text-gray-300"
              >
                Court Cases
              </label>
            </div>
            <div class="flex items-center">
              <input
                type="checkbox"
                name="action_types[]"
                id="action_type_caution"
                value="caution"
                checked={Enum.member?(@form_params["action_types"] || [], "caution")}
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-gray-600 rounded"
              />
              <label
                for="action_type_caution"
                class="ml-2 block text-sm text-gray-700 dark:text-gray-300"
              >
                Cautions
              </label>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Progress Rendering

  defp render_progress(assigns) do
    ~H"""
    <ProgressComponent.unified_progress_component agency={@agency} progress={@progress} />
    """
  end

  defp render_stat_card(label, value, icon) do
    assigns = %{label: label, value: value, icon: icon}

    ~H"""
    <div class="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-4">
      <div class="flex items-center">
        <.icon name={@icon} class="h-5 w-5 text-gray-400 dark:text-gray-500 mr-2" />
        <div>
          <p class="text-xs text-gray-500 dark:text-gray-400">{@label}</p>
          <p class="text-lg font-semibold text-gray-900 dark:text-white">{@value}</p>
        </div>
      </div>
    </div>
    """
  end

  defp render_status_badge(:idle) do
    assigns = %{}

    ~H"""
    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-200">
      Idle
    </span>
    """
  end

  defp render_status_badge(:running) do
    assigns = %{}

    ~H"""
    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200">
      <.icon name="hero-arrow-path" class="animate-spin mr-1 h-3 w-3" /> Running
    </span>
    """
  end

  defp render_status_badge(:completed) do
    assigns = %{}

    ~H"""
    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200">
      <.icon name="hero-check" class="mr-1 h-3 w-3" /> Completed
    </span>
    """
  end

  defp render_status_badge(:failed) do
    assigns = %{}

    ~H"""
    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 dark:bg-red-900 text-red-800 dark:text-red-200">
      <.icon name="hero-x-mark" class="mr-1 h-3 w-3" /> Failed
    </span>
    """
  end

  defp render_status_badge(status) when is_atom(status) do
    assigns = %{status: status}

    ~H"""
    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-200">
      {String.capitalize(to_string(@status))}
    </span>
    """
  end

  defp render_status_badge(_), do: render_status_badge(:idle)
end
