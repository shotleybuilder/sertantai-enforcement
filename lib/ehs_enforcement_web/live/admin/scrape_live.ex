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

  alias EhsEnforcement.Scraping.StrategyRegistry
  alias EhsEnforcement.Scraping.ScrapeCoordinator
  alias EhsEnforcement.Scraping.ScrapeSession
  alias Phoenix.PubSub

  # LiveView Callbacks

  @impl true
  def mount(%{"agency" => agency_str, "type" => type_str}, _session, socket) do
    # Parse URL parameters
    with {:ok, agency_atom} <- parse_agency(agency_str),
         {:ok, type_atom} <- parse_type(type_str),
         {:ok, strategy} <- StrategyRegistry.get_strategy(agency_atom, type_atom) do
      # Subscribe to PubSub events for progress tracking
      if connected?(socket) do
        PubSub.subscribe(EhsEnforcement.PubSub, "scrape_session:created")
        PubSub.subscribe(EhsEnforcement.PubSub, "scrape_session:updated")
      end

      socket =
        socket
        |> assign(:strategy, strategy)
        |> assign(:agency, agency_atom)
        |> assign(:enforcement_type, type_atom)
        |> assign(:strategy_name, strategy.strategy_name())
        |> assign(:current_session, nil)
        |> assign(:scraping_active, false)
        |> assign(:progress, initial_progress())
        |> assign(:form_params, default_form_params(strategy, agency_atom))
        |> assign(:validation_errors, %{})
        |> assign(:recent_records, [])
        |> assign(:loading, false)

      {:ok, socket}
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

      <!-- Progress Display -->
      <%= if @current_session do %>
        <div class="bg-white dark:bg-gray-800 shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
            <h2 class="text-lg font-medium text-gray-900 dark:text-white">
              Scraping Progress
            </h2>
          </div>
          <div class="px-6 py-4">
            <%= render_progress(assigns) %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Private Helper Functions

  defp parse_agency("hse"), do: {:ok, :hse}
  defp parse_agency("environment_agency"), do: {:ok, :environment_agency}
  defp parse_agency(_), do: {:error, :invalid_agency}

  defp parse_type("case"), do: {:ok, :case}
  defp parse_type("notice"), do: {:ok, :notice}
  defp parse_type(_), do: {:error, :invalid_type}

  defp initial_progress do
    %{
      percentage: 0.0,
      status: :idle,
      records_found: 0,
      records_processed: 0,
      records_created: 0,
      records_exist: 0
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

      :environment_agency ->
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
  defp agency_display_name(:environment_agency), do: "Environment Agency (EA)"
  defp agency_display_name(agency), do: to_string(agency)

  defp type_display_name(:case), do: "Cases"
  defp type_display_name(:notice), do: "Notices"
  defp type_display_name(type), do: to_string(type)

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

  defp render_form_fields(%{agency: :environment_agency} = assigns) do
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
    <div class="space-y-6">
      <!-- Progress Bar -->
      <div>
        <div class="flex items-center justify-between mb-2">
          <span class="text-sm font-medium text-gray-700 dark:text-gray-300">Progress</span>
          <span class="text-sm text-gray-600 dark:text-gray-400">
            {Float.round(@progress[:percentage] || 0.0, 1)}%
          </span>
        </div>
        <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
          <div
            class="bg-blue-600 h-2 rounded-full transition-all duration-500"
            style={"width: #{@progress[:percentage] || 0.0}%"}
          >
          </div>
        </div>
      </div>

      <!-- Progress Stats -->
      <div class="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <%= render_stat_card(
          "Found",
          @progress[:cases_found] || @progress[:notices_found] || 0,
          "hero-document-text"
        ) %>
        <%= render_stat_card(
          "Processed",
          @progress[:cases_processed] || @progress[:notices_processed] || 0,
          "hero-cog"
        ) %>
        <%= render_stat_card(
          "Created",
          @progress[:cases_created] || @progress[:notices_created] || 0,
          "hero-plus-circle"
        ) %>
        <%= render_stat_card(
          "Existing",
          @progress[:cases_exist_total] || @progress[:notices_exist_total] || 0,
          "hero-check-circle"
        ) %>
      </div>

      <!-- Status Badge -->
      <div class="flex items-center justify-between pt-4 border-t border-gray-200 dark:border-gray-700">
        <span class="text-sm font-medium text-gray-700 dark:text-gray-300">Status:</span>
        {render_status_badge(@progress[:status] || @current_session.status)}
      </div>
    </div>
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
