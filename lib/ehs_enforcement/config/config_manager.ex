defmodule EhsEnforcement.Config.ConfigManager do
  @moduledoc """
  Centralized configuration management system.

  Provides unified access to all configuration, dynamic updates,
  change notifications, and configuration export capabilities.
  """

  use GenServer

  alias EhsEnforcement.Config.{Settings, Validator, FeatureFlags}
  # alias EhsEnforcement.Config.Environment  # Unused alias removed

  # Client API

  @doc """
  Gets a configuration value by path.
  """
  def get_config(section, key, default \\ nil) do
    case GenServer.whereis(__MODULE__) do
      nil -> get_config_direct(section, key, default)
      _pid -> GenServer.call(__MODULE__, {:get_config, section, key, default})
    end
  end

  @doc """
  Sets a configuration value dynamically.
  """
  def set_config(section, key, value) do
    case GenServer.whereis(__MODULE__) do
      # No-op when GenServer not started
      nil -> :ok
      _pid -> GenServer.call(__MODULE__, {:set_config, section, key, value})
    end
  end

  @doc """
  Reloads configuration from environment variables.
  """
  def reload_config do
    case GenServer.whereis(__MODULE__) do
      # No-op when GenServer not started
      nil -> :ok
      _pid -> GenServer.call(__MODULE__, :reload_config)
    end
  end

  @doc """
  Returns the complete configuration tree.
  """
  def get_all_config do
    case GenServer.whereis(__MODULE__) do
      nil -> build_complete_config_direct()
      _pid -> GenServer.call(__MODULE__, :get_all_config)
    end
  end

  @doc """
  Validates all configuration.
  """
  def validate_all_config do
    case GenServer.whereis(__MODULE__) do
      nil -> perform_comprehensive_validation_direct()
      _pid -> GenServer.call(__MODULE__, :validate_all_config)
    end
  end

  @doc """
  Subscribes to configuration change notifications.
  """
  def watch_config_changes(pid) do
    case GenServer.whereis(__MODULE__) do
      # No-op when GenServer not started
      nil -> :ok
      _pid -> GenServer.call(__MODULE__, {:watch_config_changes, pid})
    end
  end

  @doc """
  Returns environment summary.
  """
  def get_environment_summary do
    case GenServer.whereis(__MODULE__) do
      nil -> build_environment_summary_direct()
      _pid -> GenServer.call(__MODULE__, :get_environment_summary)
    end
  end

  @doc """
  Exports configuration in specified format.
  """
  def export_config(format) do
    case GenServer.whereis(__MODULE__) do
      nil ->
        config = build_complete_config_direct()
        export_config_format(config, format)

      _pid ->
        GenServer.call(__MODULE__, {:export_config, format})
    end
  end

  # GenServer implementation

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    state = %{
      runtime_config: %{},
      watchers: [],
      last_reload: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:get_config, section, key, default}, _from, state) do
    value = get_config_value(section, key, state.runtime_config, default)
    {:reply, value, state}
  end

  @impl true
  def handle_call({:set_config, section, key, value}, _from, state) do
    case validate_config_change(section, key, value) do
      :ok ->
        new_config = put_config_value(state.runtime_config, section, key, value)
        new_state = %{state | runtime_config: new_config}

        # Notify watchers
        notify_watchers(state.watchers, section, key, value)

        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:reload_config, _from, state) do
    case validate_environment_config() do
      :ok ->
        new_state = %{state | last_reload: DateTime.utc_now()}
        {:reply, :ok, new_state}

      {:error, _reason} ->
        {:reply, {:error, :configuration_validation_failed}, state}
    end
  end

  @impl true
  def handle_call(:get_all_config, _from, state) do
    config = build_complete_config(state.runtime_config)
    {:reply, config, state}
  end

  @impl true
  def handle_call(:validate_all_config, _from, state) do
    result = perform_comprehensive_validation()
    {:reply, result, state}
  end

  @impl true
  def handle_call({:watch_config_changes, pid}, _from, state) do
    # Monitor the process so we can clean up when it dies
    Process.monitor(pid)
    new_watchers = [pid | state.watchers]
    {:reply, :ok, %{state | watchers: new_watchers}}
  end

  @impl true
  def handle_call(:get_environment_summary, _from, state) do
    summary = build_environment_summary()
    {:reply, summary, state}
  end

  @impl true
  def handle_call({:export_config, format}, _from, state) do
    config = build_complete_config(state.runtime_config)
    exported = export_config_format(config, format)
    {:reply, exported, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove dead watcher
    new_watchers = List.delete(state.watchers, pid)
    {:noreply, %{state | watchers: new_watchers}}
  end

  # Private functions

  defp put_config_value(config, section, key, value) when is_list(section) do
    # Handle nested path like [:agencies, :hse]
    path = section ++ [key]
    deep_put_in(config, path, value)
  end

  defp put_config_value(config, section, key, value) do
    # Handle single section
    deep_put_in(config, [section, key], value)
  end

  defp deep_put_in(config, [head], value) do
    Map.put(config, head, value)
  end

  defp deep_put_in(config, [head | tail], value) do
    current = Map.get(config, head, %{})
    Map.put(config, head, deep_put_in(current, tail, value))
  end

  defp get_config_value(section, key, runtime_config, default) when is_list(section) do
    # Handle nested path like [:agencies, :hse]
    path = section ++ [key]

    case get_in(runtime_config, path) do
      nil -> get_environment_config_value(section, key, default)
      value -> value
    end
  end

  defp get_config_value(section, key, runtime_config, default) do
    # Check runtime overrides first
    case get_in(runtime_config, [section, key]) do
      nil -> get_environment_config_value(section, key, default)
      value -> value
    end
  end

  defp get_environment_config_value(:airtable, key, default) do
    config = Settings.get_airtable_config()
    Map.get(config, key, default)
  end

  defp get_environment_config_value([:agencies, :hse], key, default) do
    config = Settings.get_agency_config(:hse)
    if config, do: Map.get(config, key, default), else: default
  end

  defp get_environment_config_value(:features, key, default) do
    config = Settings.get_feature_flags()
    Map.get(config, key, default)
  end

  defp get_environment_config_value(_, _, default), do: default

  defp validate_config_change(:airtable, :sync_interval_minutes, value)
       when is_integer(value) and value > 0,
       do: :ok

  defp validate_config_change(:airtable, :sync_interval_minutes, _), do: {:error, :invalid_value}
  defp validate_config_change(_, _, _), do: :ok

  defp validate_environment_config do
    Validator.validate_on_startup()
  end

  defp build_complete_config(runtime_config) do
    base_config = %{
      airtable: mask_sensitive_config(Settings.get_airtable_config()),
      agencies: %{
        hse: Settings.get_agency_config(:hse)
      },
      features: Settings.get_feature_flags(),
      database: mask_sensitive_config(Settings.get_database_config())
    }

    # Merge with runtime overrides
    merge_runtime_config(base_config, runtime_config)
  end

  defp mask_sensitive_config(config) when is_map(config) do
    config
    |> Map.update(:api_key, nil, fn
      nil -> nil
      _key -> "***MASKED***"
    end)
    |> Map.update(:url, nil, fn
      nil ->
        nil

      url ->
        if String.contains?(url, "@") do
          "***MASKED***"
        else
          url
        end
    end)
  end

  defp merge_runtime_config(base, runtime) do
    Map.merge(base, runtime, fn
      _key, base_val, runtime_val when is_map(base_val) and is_map(runtime_val) ->
        Map.merge(base_val, runtime_val)

      _key, _base_val, runtime_val ->
        runtime_val
    end)
  end

  defp perform_comprehensive_validation do
    validations = [
      fn -> Validator.validate_on_startup() end,
      fn -> validate_cross_dependencies() end,
      fn -> validate_feature_flag_dependencies() end
    ]

    errors =
      validations
      |> Enum.map(& &1.())
      |> Enum.filter(&(&1 != :ok))
      |> Enum.flat_map(fn
        {:error, errors} when is_list(errors) -> errors
        {:error, error} -> [error]
      end)

    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp validate_cross_dependencies do
    # Check if auto_sync is enabled but Airtable config is missing
    if FeatureFlags.enabled?(:auto_sync) do
      airtable_config = Settings.get_airtable_config()

      if airtable_config.api_key in [nil, ""] do
        {:error, [:auto_sync_requires_airtable_config]}
      else
        :ok
      end
    else
      :ok
    end
  end

  defp validate_feature_flag_dependencies do
    # Add additional feature flag dependency validations here
    :ok
  end

  defp build_environment_summary do
    environment = detect_environment()
    required_vars = ["AT_UK_E_API_KEY", "DATABASE_URL", "SECRET_KEY_BASE"]
    optional_vars = ["SYNC_INTERVAL", "HSE_ENABLED", "AUTO_SYNC_ENABLED"]

    missing_required =
      Enum.filter(required_vars, fn var ->
        System.get_env(var) in [nil, ""]
      end)

    %{
      environment: environment,
      required_env_vars: required_vars,
      optional_env_vars: optional_vars,
      missing_required: missing_required,
      feature_flags: Settings.get_feature_flags()
    }
  end

  defp detect_environment do
    case System.get_env("MIX_ENV") do
      "prod" -> :prod
      "dev" -> :dev
      "test" -> :test
      _ -> :dev
    end
  end

  defp export_config_format(config, :json) do
    Jason.encode!(config)
  end

  defp export_config_format(config, :elixir) do
    """
    config :ehs_enforcement,
      airtable: #{inspect(config.airtable)},
      agencies: #{inspect(config.agencies)},
      features: #{inspect(config.features)}
    """
  end

  defp export_config_format(config, :env) do
    airtable = config.airtable
    features = config.features

    """
    # Airtable Configuration
    AT_UK_E_API_KEY=#{airtable.api_key || "your_api_key_here"}
    AIRTABLE_BASE_ID=#{airtable.base_id}
    SYNC_INTERVAL=#{airtable.sync_interval_minutes}

    # Feature Flags
    AUTO_SYNC_ENABLED=#{features.auto_sync}

    # Database Configuration
    DATABASE_URL=postgresql://user:password@localhost/ehs_enforcement
    SECRET_KEY_BASE=your_secret_key_base_here
    """
  end

  defp notify_watchers(watchers, section, key, value) do
    message = {:config_changed, section, key, value}

    Enum.each(watchers, fn pid ->
      if Process.alive?(pid) do
        send(pid, message)
      end
    end)
  end

  # Direct access functions for when GenServer isn't started

  defp get_config_direct(section, key, default) do
    get_environment_config_value(section, key, default)
  end

  defp build_complete_config_direct do
    build_complete_config(%{})
  end

  defp perform_comprehensive_validation_direct do
    perform_comprehensive_validation()
  end

  defp build_environment_summary_direct do
    build_environment_summary()
  end

  # Fallback for when GenServer isn't started
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
end
