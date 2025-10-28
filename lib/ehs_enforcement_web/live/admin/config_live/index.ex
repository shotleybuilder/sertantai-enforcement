defmodule EhsEnforcementWeb.Admin.ConfigLive.Index do
  @moduledoc """
  Admin configuration management overview page.

  Displays all scraping configurations with their current status and provides
  navigation to detailed configuration management. Administrators can:

  - View all scraping configurations and their active status
  - Navigate to scraping configuration editor
  - Create default configurations if none exist
  - See feature flag summaries for each configuration

  ## Routes

  - `GET /admin/config` - Configuration overview page

  ## Authentication

  Requires admin authentication. Uses `current_user` from socket assigns
  for authorization of configuration access.
  """

  use EhsEnforcementWeb, :live_view

  require Logger
  require Ash.Query

  alias EhsEnforcement.Configuration.ScrapingConfig

  # LiveView callbacks

  @doc """
  Mounts the configuration overview page.

  Loads all scraping configurations synchronously and displays their status.
  Handles cases where current_user might be nil by falling back to
  unauthenticated reads.

  ## Returns

  - `{:ok, socket}` with loaded configurations and loading state cleared
  - Sets `errors` if configuration loading fails
  """
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Load configurations synchronously - it's a simple read operation
      try do
        actor = socket.assigns[:current_user]

        {:ok, configs} =
          if actor do
            Ash.read(ScrapingConfig, actor: actor)
          else
            Ash.read(ScrapingConfig)
          end

        {:ok, assign(socket, loading: false, configs: configs, errors: [])}
      rescue
        error ->
          Logger.error("Failed to load configuration overview: #{inspect(error)}")

          {:ok,
           assign(socket, loading: false, configs: [], errors: ["Failed to load configurations"])}
      end
    else
      {:ok, assign(socket, loading: true, configs: [], errors: [])}
    end
  end

  @doc """
  Navigates to the scraping configuration editor.

  Uses `push_navigate/2` for client-side navigation without page reload.
  """
  @impl true
  def handle_event("navigate_to_scraping", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/config/scraping")}
  end

  @impl true
  def handle_event("create_default_config", _params, socket) do
    case ScrapingConfig.create_default_config(actor: socket.assigns.current_user) do
      {:ok, config} ->
        Logger.info("Created default scraping configuration", config_id: config.id)

        socket =
          socket
          |> put_flash(:info, "Default scraping configuration created successfully")
          |> push_navigate(to: ~p"/admin/config/scraping")

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to create default configuration: #{inspect(error)}")
        socket = put_flash(socket, :error, "Failed to create default configuration")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:config_data_loaded, data}, socket) do
    socket =
      assign(socket,
        configs: data.configs,
        loading: false,
        errors: []
      )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:config_data_error, error}, socket) do
    Logger.error("Failed to load configuration data: #{inspect(error)}")

    socket =
      assign(socket,
        loading: false,
        errors: ["Failed to load configuration data"]
      )

    {:noreply, socket}
  end

  # Private functions

  defp config_status_badge(%ScrapingConfig{is_active: true}), do: "bg-green-100 text-green-800"
  defp config_status_badge(%ScrapingConfig{is_active: false}), do: "bg-gray-100 text-gray-800"

  defp config_status_text(%ScrapingConfig{is_active: true}), do: "Active"
  defp config_status_text(%ScrapingConfig{is_active: false}), do: "Inactive"

  defp feature_flags_summary(config) do
    flags = [
      {"Manual Scraping", config.manual_scraping_enabled},
      {"Scheduled Scraping", config.scheduled_scraping_enabled},
      {"Real-time Progress", config.real_time_progress_enabled},
      {"Admin Notifications", config.admin_notifications_enabled}
    ]

    enabled_count = Enum.count(flags, fn {_name, enabled} -> enabled end)
    total_count = length(flags)

    "#{enabled_count}/#{total_count} enabled"
  end
end
