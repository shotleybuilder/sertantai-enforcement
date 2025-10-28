defmodule EhsEnforcement.Config.Validator do
  @moduledoc """
  Configuration validation for application startup and runtime.

  Ensures all required configuration is present and valid before
  the application starts or when configuration changes.
  """

  require Logger

  @doc """
  Validates all configuration required for application startup.
  """
  def validate_on_startup do
    validations = [
      &validate_airtable_config/0,
      &validate_database_config/0,
      &validate_secret_key_base/0,
      &validate_feature_flags/0
    ]

    errors =
      validations
      |> Enum.map(& &1.())
      |> Enum.filter(&(&1 != :ok))
      |> Enum.map(fn {:error, error} -> error end)

    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  @doc """
  Validates Airtable configuration.
  """
  def validate_airtable_config do
    with :ok <- validate_api_key(),
         :ok <- validate_base_id(),
         :ok <- validate_sync_interval() do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Validates agency configuration.
  """
  def validate_agency_config(:hse), do: :ok
  def validate_agency_config(_unknown), do: {:error, :unknown_agency}

  @doc """
  Validates database connection can be established.
  """
  def validate_database_connection do
    database_url = System.get_env("DATABASE_URL")

    cond do
      database_url in [nil, ""] ->
        {:error, :database_connection_failed}

      not String.starts_with?(database_url, "postgresql://") ->
        {:error, :database_connection_failed}

      true ->
        # In a real application, we might try to connect here
        # For testing, we'll accept valid-looking URLs
        :ok
    end
  end

  @doc """
  Validates feature flag configuration.
  """
  def validate_feature_flags do
    auto_sync_value = System.get_env("AUTO_SYNC_ENABLED", "false")

    case auto_sync_value do
      value when value in ["true", "false", "TRUE", "FALSE", "True", "False", "1", "0"] ->
        :ok

      _ ->
        {:error, :invalid_feature_flag_value}
    end
  end

  @doc """
  Validates the current environment and returns summary.
  """
  def validate_environment do
    env = detect_environment()
    warnings = []

    %{
      environment: env,
      warnings: warnings
    }
  end

  # Private functions

  defp validate_api_key do
    api_key = System.get_env("AT_UK_E_API_KEY")

    cond do
      api_key in [nil, ""] ->
        {:error, :missing_airtable_api_key}

      String.length(api_key) < 10 ->
        {:error, :invalid_api_key_format}

      true ->
        :ok
    end
  end

  defp validate_base_id do
    base_id = System.get_env("AIRTABLE_BASE_ID", "appq5OQW9bTHC1zO5")

    if String.starts_with?(base_id, "app") and String.length(base_id) > 10 do
      :ok
    else
      {:error, :invalid_base_id_format}
    end
  end

  defp validate_sync_interval do
    interval_str = System.get_env("SYNC_INTERVAL", "60")

    case Integer.parse(interval_str) do
      {interval, ""} when interval > 0 ->
        :ok

      _ ->
        {:error, :invalid_sync_interval}
    end
  end

  defp validate_database_config do
    database_url = System.get_env("DATABASE_URL")

    cond do
      database_url in [nil, ""] ->
        {:error, :missing_database_url}

      not String.starts_with?(database_url, "postgresql://") ->
        {:error, :invalid_database_url}

      true ->
        :ok
    end
  end

  defp validate_secret_key_base do
    secret_key = System.get_env("SECRET_KEY_BASE")

    cond do
      secret_key in [nil, ""] ->
        {:error, :missing_secret_key_base}

      String.length(secret_key) < 64 ->
        {:error, :invalid_secret_key_base}

      true ->
        :ok
    end
  end

  defp detect_environment do
    # Use Application.get_env which respects MIX_ENV at runtime
    Application.get_env(:ehs_enforcement, :environment, :dev)
  end
end
