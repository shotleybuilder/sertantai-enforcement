defmodule EhsEnforcementWeb.Admin.ConfigLive.Scraping do
  @moduledoc """
  Admin interface for scraping configuration management.
  
  Features:
  - Edit active scraping configuration
  - Create new configuration profiles
  - Activate/deactivate configurations
  - Real-time validation and preview
  - Feature flag management
  """
  
  use EhsEnforcementWeb, :live_view
  
  require Logger
  require Ash.Query
  
  alias EhsEnforcement.Configuration.ScrapingConfig
  alias AshPhoenix.Form
  
  # LiveView callbacks
  
  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket,
      # Configuration state
      active_config: nil,
      all_configs: [],
      
      # Form state
      form: nil,
      editing: false,
      creating: false,
      
      # UI state
      loading: true,
      errors: [],
      success_message: nil,
      
      # Preview state
      preview_enabled: false,
      preview_data: %{}
    )
    
    if connected?(socket) do
      load_scraping_configurations(socket)
    else
      {:ok, socket}
    end
  end
  
  @impl true
  def handle_params(params, _uri, socket) do
    case params do
      %{"action" => "new"} ->
        socket = start_creating_config(socket)
        {:noreply, socket}
        
      %{"action" => "edit"} ->
        socket = start_editing_config(socket)  
        {:noreply, socket}
        
      _ ->
        {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("start_editing", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/config/scraping?action=edit")}
  end
  
  @impl true
  def handle_event("start_creating", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/config/scraping/new")}
  end
  
  @impl true
  def handle_event("cancel_editing", _params, socket) do
    socket = 
      socket
      |> assign(editing: false, creating: false, form: nil)
      |> push_patch(to: ~p"/admin/config/scraping")
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("validate", %{"scraping_config" => config_params}, socket) do
    form = Form.validate(socket.assigns.form, config_params, errors: true)
    
    # Generate preview data for immediate feedback
    preview_data = generate_preview_data(config_params)
    
    socket = assign(socket, 
      form: form,
      preview_data: preview_data,
      preview_enabled: true
    )
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("save", %{"scraping_config" => config_params}, socket) do
    form = Form.validate(socket.assigns.form, config_params)
    
    case Form.submit(form, params: config_params) do
      {:ok, config} ->
        Logger.info("Scraping configuration saved", config_id: config.id, name: config.name)
        
        socket = 
          socket
          |> put_flash(:info, "Configuration saved successfully: #{config.name}")
          |> assign(editing: false, creating: false, form: nil)
          |> push_patch(to: ~p"/admin/config/scraping")
          |> refresh_configurations()
        
        {:noreply, socket}
      
      {:error, form} ->
        Logger.warning("Failed to save scraping configuration", errors: form.errors)
        socket = assign(socket, form: form)
        {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("activate_config", %{"config_id" => config_id}, socket) do
    config = Enum.find(socket.assigns.all_configs, &(&1.id == config_id))
    
    case Ash.update(config, %{}, action: :activate, actor: socket.assigns.current_user) do
      {:ok, updated_config} ->
        Logger.info("Activated scraping configuration", config_id: config_id, name: updated_config.name)
        
        socket = 
          socket
          |> put_flash(:info, "Configuration activated: #{updated_config.name}")
          |> refresh_configurations()
        
        {:noreply, socket}
      
      {:error, error} ->
        Logger.error("Failed to activate configuration: #{inspect(error)}")
        socket = put_flash(socket, :error, "Failed to activate configuration")
        {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("delete_config", %{"config_id" => config_id}, socket) do
    config = Enum.find(socket.assigns.all_configs, &(&1.id == config_id))
    
    if config && config.is_active do
      socket = put_flash(socket, :error, "Cannot delete active configuration")
      {:noreply, socket}
    else
      case Ash.destroy(config, actor: socket.assigns.current_user) do
        :ok ->
          Logger.info("Deleted scraping configuration", config_id: config_id)
          
          socket = 
            socket
            |> put_flash(:info, "Configuration deleted successfully")
            |> refresh_configurations()
          
          {:noreply, socket}
        
        {:error, error} ->
          Logger.error("Failed to delete configuration: #{inspect(error)}")
          socket = put_flash(socket, :error, "Failed to delete configuration")
          {:noreply, socket}
      end
    end
  end
  
  @impl true
  def handle_event("toggle_preview", _params, socket) do
    socket = assign(socket, preview_enabled: !socket.assigns.preview_enabled)
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:config_data_loaded, data}, socket) do
    socket = assign(socket,
      active_config: data.active_config,
      all_configs: data.all_configs,
      loading: false,
      errors: []
    )
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:config_data_error, error}, socket) do
    Logger.error("Failed to load scraping configurations: #{inspect(error)}")
    socket = assign(socket,
      loading: false,
      errors: ["Failed to load configuration data"]
    )
    {:noreply, socket}
  end
  
  # Private functions
  
  defp load_scraping_configurations(socket) do
    Task.start_link(fn ->
      try do
        # Load all configurations
        {:ok, all_configs} = Ash.read(ScrapingConfig, actor: socket.assigns.current_user)
        
        # Find active configuration
        active_config = Enum.find(all_configs, & &1.is_active)
        
        send(self(), {:config_data_loaded, %{
          active_config: active_config,
          all_configs: all_configs
        }})
        
      rescue
        error ->
          Logger.error("Failed to load scraping configurations: #{inspect(error)}")
          send(self(), {:config_data_error, error})
      end
    end)
    
    socket
  end
  
  defp start_editing_config(socket) do
    case socket.assigns.active_config do
      nil ->
        socket
        |> put_flash(:error, "No active configuration found to edit")
        |> push_patch(to: ~p"/admin/config/scraping")
      
      config ->
        form = Form.for_update(config, :update, as: "scraping_config", forms: [auto?: false])
        assign(socket, editing: true, creating: false, form: form)
    end
  end
  
  defp start_creating_config(socket) do
    form = Form.for_create(ScrapingConfig, :create, as: "scraping_config", forms: [auto?: false])
    assign(socket, editing: false, creating: true, form: form)
  end
  
  defp refresh_configurations(socket) do
    load_scraping_configurations(socket)
    socket
  end
  
  defp generate_preview_data(config_params) do
    %{
      rate_limit_delay: calculate_rate_limit_delay(config_params),
      requests_per_hour: calculate_requests_per_hour(config_params),
      estimated_pages_per_hour: calculate_pages_per_hour(config_params),
      feature_flags_summary: summarize_feature_flags(config_params)
    }
  end
  
  defp calculate_rate_limit_delay(params) do
    requests_per_minute = parse_integer(params["requests_per_minute"], 10)
    if requests_per_minute > 0 do
      delay_ms = trunc(60_000 / requests_per_minute)
      "#{delay_ms}ms between requests"
    else
      "Invalid rate limit"
    end
  end
  
  defp calculate_requests_per_hour(params) do
    requests_per_minute = parse_integer(params["requests_per_minute"], 10)
    requests_per_minute * 60
  end
  
  defp calculate_pages_per_hour(params) do
    requests_per_minute = parse_integer(params["requests_per_minute"], 10)
    pause_between_pages = parse_integer(params["pause_between_pages_ms"], 3000)
    
    if requests_per_minute > 0 do
      # Rough estimate: 1 request per page + pause time
      total_delay_per_page = (60_000 / requests_per_minute) + pause_between_pages
      pages_per_hour = trunc(3_600_000 / total_delay_per_page)
      "~#{pages_per_hour} pages/hour"
    else
      "Unable to calculate"
    end
  end
  
  defp summarize_feature_flags(params) do
    flags = [
      parse_boolean(params["manual_scraping_enabled"]),
      parse_boolean(params["scheduled_scraping_enabled"]),
      parse_boolean(params["real_time_progress_enabled"]),
      parse_boolean(params["admin_notifications_enabled"])
    ]
    
    enabled_count = Enum.count(flags, & &1)
    "#{enabled_count}/4 features enabled"
  end
  
  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> default
    end
  end
  defp parse_integer(value, _default) when is_integer(value), do: value
  defp parse_integer(_, default), do: default
  
  defp parse_boolean("true"), do: true
  defp parse_boolean(true), do: true
  defp parse_boolean(_), do: false
  
  defp config_status_badge(%ScrapingConfig{is_active: true}), do: "bg-green-100 text-green-800 border-green-200"
  defp config_status_badge(%ScrapingConfig{is_active: false}), do: "bg-gray-100 text-gray-800 border-gray-200"
  
  defp config_status_text(%ScrapingConfig{is_active: true}), do: "Active"
  defp config_status_text(%ScrapingConfig{is_active: false}), do: "Inactive"
  
  defp feature_flag_status(true), do: {"✅", "text-green-600"}
  defp feature_flag_status(false), do: {"❌", "text-red-600"}
end