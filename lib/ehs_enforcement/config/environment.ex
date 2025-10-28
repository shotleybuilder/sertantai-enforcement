defmodule EhsEnforcement.Config.Environment do
  @moduledoc """
  Environment variable management and documentation.

  Handles loading, validation, and documentation of all environment
  variables used by the EHS Enforcement application.
  """

  @doc """
  Returns list of all required environment variables with descriptions.
  """
  def get_required_vars do
    [
      %{
        name: "AT_UK_E_API_KEY",
        description: "Airtable API key for accessing UK enforcement data",
        example: "keyAbc123DefGhi789",
        validation: "Minimum 10 characters"
      },
      %{
        name: "DATABASE_URL",
        description: "PostgreSQL database connection URL",
        example: "postgresql://username:password@localhost/ehs_enforcement",
        validation: "Must be valid PostgreSQL URL"
      },
      %{
        name: "SECRET_KEY_BASE",
        description: "Phoenix secret key base for session encryption",
        example: "a very long random string of 64+ characters...",
        validation: "Minimum 64 characters"
      }
    ]
  end

  @doc """
  Returns list of all optional environment variables with defaults.
  """
  def get_optional_vars do
    [
      %{
        name: "SYNC_INTERVAL",
        description: "Sync interval in minutes",
        default: "60",
        example: "120",
        validation: "Positive integer"
      },
      %{
        name: "HSE_ENABLED",
        description: "Enable HSE agency data collection",
        default: "true",
        example: "false",
        validation: "true/false"
      },
      %{
        name: "AUTO_SYNC_ENABLED",
        description: "Enable automatic data synchronization",
        default: "false",
        example: "true",
        validation: "true/false"
      },
      %{
        name: "AIRTABLE_BASE_ID",
        description: "Airtable base ID for UK enforcement data",
        default: "appq5OQW9bTHC1zO5",
        example: "appAbc123DefGhi789",
        validation: "Must start with 'app'"
      },
      %{
        name: "DATABASE_POOL_SIZE",
        description: "Database connection pool size",
        default: "10",
        example: "20",
        validation: "Positive integer"
      },
      %{
        name: "PHX_HOST",
        description: "Phoenix host for production deployment",
        default: nil,
        example: "your-app.com",
        validation: "Valid hostname (required in production)"
      }
    ]
  end

  @doc """
  Validates an environment variable value.
  """
  def validate_var("AT_UK_E_API_KEY", value) do
    cond do
      value == "" -> {:error, :invalid_format}
      String.length(value) < 10 -> {:error, :too_short}
      true -> :ok
    end
  end

  def validate_var("DATABASE_URL", value) do
    if String.starts_with?(value, "postgresql://") and String.length(value) > 15 do
      :ok
    else
      {:error, :invalid_format}
    end
  end

  def validate_var("SECRET_KEY_BASE", value) do
    if String.length(value) >= 64 do
      :ok
    else
      {:error, :too_short}
    end
  end

  def validate_var("SYNC_INTERVAL", value) do
    case Integer.parse(value) do
      {interval, ""} when interval > 0 -> :ok
      {0, ""} -> {:error, :not_positive}
      {interval, ""} when interval < 0 -> {:error, :not_positive}
      _ -> {:error, :not_integer}
    end
  end

  def validate_var(var_name, value) when var_name in ["HSE_ENABLED", "AUTO_SYNC_ENABLED"] do
    if value in ["true", "false", "TRUE", "FALSE", "True", "False"] do
      :ok
    else
      {:error, :not_boolean}
    end
  end

  def validate_var("PHX_HOST", value) do
    cond do
      value == "localhost" -> {:error, :invalid_host}
      value == "" -> {:error, :invalid_host}
      String.contains?(value, ".") -> :ok
      true -> {:error, :invalid_host}
    end
  end

  def validate_var(_var_name, _value), do: :ok

  @doc """
  Checks for missing required environment variables.
  """
  def check_missing_required do
    required_vars = get_required_vars()

    Enum.flat_map(required_vars, fn var ->
      var_name = var.name
      value = System.get_env(var_name)

      cond do
        value in [nil, ""] ->
          [var_name]

        validate_var(var_name, value) != :ok ->
          # Include invalid variables as "missing"
          [var_name]

        true ->
          []
      end
    end)
  end

  @doc """
  Generates comprehensive documentation for all environment variables.
  """
  def get_environment_documentation do
    required_docs = generate_required_var_docs()
    optional_docs = generate_optional_var_docs()

    """
    # Environment Variables

    This document describes all environment variables used by the EHS Enforcement application.

    ## Required Variables

    #{required_docs}

    ## Optional Variables

    #{optional_docs}

    ## Examples

    ### Development .env file:
    ```
    AT_UK_E_API_KEY=your_airtable_api_key_here
    DATABASE_URL=postgresql://postgres:postgres@localhost/ehs_enforcement_dev
    SECRET_KEY_BASE=#{String.duplicate("a", 64)}
    SYNC_INTERVAL=120
    HSE_ENABLED=true
    AUTO_SYNC_ENABLED=false
    ```

    ### Production environment:
    ```
    AT_UK_E_API_KEY=your_production_api_key
    DATABASE_URL=postgresql://user:pass@production-db/ehs_enforcement
    SECRET_KEY_BASE=your_long_random_production_secret
    PHX_HOST=your-app.herokuapp.com
    ```
    """
  end

  @doc """
  Loads environment variables from a .env file.
  """
  def load_from_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        parse_and_load_env_content(content)

      {:error, :enoent} ->
        {:error, :file_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Exports environment variable template in specified format.
  """
  def export_template(:env) do
    required_vars = get_required_vars()
    optional_vars = get_optional_vars()

    required_section =
      Enum.map_join(required_vars, "\n", fn var ->
        "# Required: #{var.description}\n#{var.name}="
      end)

    optional_section =
      Enum.map_join(optional_vars, "\n", fn var ->
        default_comment = if var.default, do: "\n# Default: #{var.default}", else: ""
        "# Optional: #{var.description}#{default_comment}\n#{var.name}=#{var.default || ""}"
      end)

    """
    # EHS Enforcement Application Environment Variables

    #{required_section}

    #{optional_section}
    """
  end

  def export_template(:docker_compose) do
    all_vars = get_required_vars() ++ get_optional_vars()

    env_lines =
      Enum.map_join(all_vars, "\n      ", fn var ->
        "- #{var.name}=${#{var.name}}"
      end)

    """
    # Docker Compose environment section
    environment:
      #{env_lines}
    """
  end

  def export_template(:kubernetes) do
    optional_vars = get_optional_vars()

    config_data =
      Enum.map_join(optional_vars, "\n  ", fn var ->
        value = var.default || "changeme"
        "#{var.name}: \"#{value}\""
      end)

    """
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: ehs-enforcement-config
    data:
      #{config_data}
    """
  end

  @doc """
  Detects the current environment.
  """
  def detect_environment do
    case System.get_env("MIX_ENV") do
      "prod" -> :prod
      "dev" -> :dev
      "test" -> :test
      # Default for our current context
      _ -> :test
    end
  end

  @doc """
  Returns validation rules for the specified environment.
  """
  def get_validation_rules(:test) do
    %{
      "AT_UK_E_API_KEY" => %{required: false, min_length: 5},
      "DATABASE_URL" => %{required: false},
      "SECRET_KEY_BASE" => %{required: false, min_length: 32},
      "PHX_HOST" => %{required: false}
    }
  end

  def get_validation_rules(:prod) do
    %{
      "AT_UK_E_API_KEY" => %{required: true, min_length: 10},
      "DATABASE_URL" => %{required: true},
      "SECRET_KEY_BASE" => %{required: true, min_length: 64},
      "PHX_HOST" => %{required: true}
    }
  end

  def get_validation_rules(_env) do
    get_validation_rules(:prod)
  end

  # Private functions

  defp generate_required_var_docs do
    get_required_vars()
    |> Enum.map_join("\n\n", fn var ->
      """
      ### #{var.name}
      **Description**: #{var.description}
      **Example**: `#{var.example}`
      **Validation**: #{var.validation}
      """
    end)
  end

  defp generate_optional_var_docs do
    get_optional_vars()
    |> Enum.map_join("\n\n", fn var ->
      default_text = if var.default, do: "\n**Default**: `#{var.default}`", else: ""

      """
      ### #{var.name}
      **Description**: #{var.description}#{default_text}
      **Example**: `#{var.example}`
      **Validation**: #{var.validation}
      """
    end)
  end

  defp parse_and_load_env_content(content) do
    lines = String.split(content, "\n")

    env_vars =
      lines
      |> Enum.filter(fn line ->
        trimmed = String.trim(line)
        trimmed != "" and not String.starts_with?(trimmed, "#")
      end)
      |> Enum.map(&parse_env_line/1)
      |> Enum.filter(& &1)

    # Validate all variables before setting them
    validation_errors = validate_env_vars(env_vars)

    case validation_errors do
      [] ->
        # Set all environment variables
        Enum.each(env_vars, fn {key, value} ->
          System.put_env(key, value)
        end)

        :ok

      errors ->
        {:error, errors}
    end
  end

  defp parse_env_line(line) do
    case String.split(line, "=", parts: 2) do
      [key, value] ->
        {String.trim(key), String.trim(value)}

      _ ->
        nil
    end
  end

  defp validate_env_vars(env_vars) do
    Enum.flat_map(env_vars, fn {key, value} ->
      case validate_var(key, value) do
        :ok -> []
        {:error, _reason} -> [key]
      end
    end)
  end
end
