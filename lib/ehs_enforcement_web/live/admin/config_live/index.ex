defmodule EhsEnforcementWeb.Admin.ConfigLive.Index do
  @moduledoc """
  Admin interface for configuration management overview.
  
  Provides navigation to different configuration sections:
  - Scraping configuration
  - Feature flags overview
  - System settings
  """
  
  use EhsEnforcementWeb, :live_view
  
  require Logger
  require Ash.Query
  import Ash.Expr
  
  alias EhsEnforcement.Configuration.ScrapingConfig
  
  # LiveView callbacks
  
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      load_configuration_overview(socket)
    else
      {:ok, assign(socket, loading: true, configs: [], errors: [])}
    end
  end
  
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
    socket = assign(socket, 
      configs: data.configs,
      loading: false,
      errors: []
    )
    {:noreply, socket}
  end
  
  @impl true 
  def handle_info({:config_data_error, error}, socket) do
    Logger.error("Failed to load configuration data: #{inspect(error)}")
    socket = assign(socket,
      loading: false,
      errors: ["Failed to load configuration data"]
    )
    {:noreply, socket}
  end
  
  # Private functions
  
  defp load_configuration_overview(socket) do
    Task.start_link(fn ->
      try do
        # Load all scraping configurations
        {:ok, configs} = Ash.read(ScrapingConfig, actor: socket.assigns.current_user)
        
        send(self(), {:config_data_loaded, %{configs: configs}})
        
      rescue
        error ->
          Logger.error("Failed to load configuration overview: #{inspect(error)}")
          send(self(), {:config_data_error, error})
      end
    end)
    
    {:ok, assign(socket, loading: true, configs: [], errors: [])}
  end
  
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