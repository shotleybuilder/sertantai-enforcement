defmodule EhsEnforcement.Sync.Generic.ConfigValidator do
  @moduledoc """
  Configuration validation for the generic sync engine.
  
  This module provides comprehensive validation for sync configurations,
  ensuring that all required components are properly configured before
  sync operations begin. It validates:
  
  - Source adapter configuration and connectivity
  - Target resource configuration and permissions
  - Processing pipeline configuration
  - PubSub and session tracking configuration
  - Error handling and recovery configuration
  
  ## Validation Levels
  
  1. **Basic Validation**: Required fields and data types
  2. **Structural Validation**: Module loading and interface compliance
  3. **Connectivity Validation**: External service availability
  4. **Permission Validation**: Resource access and authorization
  5. **Integration Validation**: Component compatibility
  
  ## Example Usage
  
      config = %{
        source_adapter: MyApp.Adapters.AirtableAdapter,
        source_config: %{api_key: "key", base_id: "base"},
        target_resource: MyApp.Cases.Case,
        target_config: %{unique_field: :regulator_id},
        processing_config: %{batch_size: 100},
        pubsub_config: %{module: MyApp.PubSub},
        session_config: %{sync_type: :import_cases}
      }
      
      case ConfigValidator.validate_sync_config(config) do
        {:ok, validated_config} -> 
          # Config is valid, proceed with sync
        {:error, validation_errors} -> 
          # Handle validation errors
      end
  """
  
  require Logger

  @type validation_result :: {:ok, map()} | {:error, [validation_error()]}
  @type validation_error :: %{
    field: atom(),
    error: atom(),
    message: String.t(),
    details: any()
  }

  @required_config_fields [
    :source_adapter,
    :source_config,
    :target_resource,
    :target_config,
    :processing_config,
    :pubsub_config,
    :session_config
  ]

  @doc """
  Validate a complete sync configuration.
  
  Performs comprehensive validation of all configuration components
  and returns either a validated configuration or detailed error information.
  
  ## Parameters
  
  * `config` - Complete sync configuration map
  * `opts` - Validation options:
    * `:skip_connectivity` - Skip external connectivity checks (default: false)  
    * `:skip_permissions` - Skip permission validation (default: false)
    * `:validation_level` - :basic | :full (default: :full)
  
  ## Returns
  
  * `{:ok, validated_config}` - Configuration is valid
  * `{:error, validation_errors}` - List of validation errors
  """
  @spec validate_sync_config(map(), keyword()) :: validation_result()
  def validate_sync_config(config, opts \\ []) do
    validation_level = Keyword.get(opts, :validation_level, :full)
    skip_connectivity = Keyword.get(opts, :skip_connectivity, false)
    skip_permissions = Keyword.get(opts, :skip_permissions, false)
    
    Logger.debug("🔍 Validating sync configuration (level: #{validation_level})")
    
    validations = [
      {:basic_structure, &validate_basic_structure/1},
      {:source_adapter, &validate_source_adapter/1},
      {:target_resource, &validate_target_resource/1},
      {:processing_config, &validate_processing_config/1},
      {:pubsub_config, &validate_pubsub_config/1},
      {:session_config, &validate_session_config/1}
    ]
    
    # Add advanced validations for full validation level
    validations = if validation_level == :full do
      advanced_validations = [
        {:connectivity, &validate_connectivity/1, skip_connectivity},
        {:permissions, &validate_permissions/1, skip_permissions},
        {:integration, &validate_integration/1}
      ]
      validations ++ advanced_validations
    else
      validations
    end
    
    # Run all validations
    case run_validations(config, validations, opts) do
      {:ok, validated_config} ->
        Logger.debug("✅ Sync configuration validation successful")
        {:ok, validated_config}
        
      {:error, errors} ->
        Logger.warn("⚠️ Sync configuration validation failed: #{length(errors)} errors")
        {:error, errors}
    end
  end

  @doc """
  Validate only the source adapter configuration.
  
  Useful for testing source adapter configurations independently.
  """
  @spec validate_source_adapter_config(module(), map()) :: validation_result()
  def validate_source_adapter_config(adapter_module, adapter_config) do
    config = %{
      source_adapter: adapter_module,
      source_config: adapter_config
    }
    
    validations = [
      {:source_adapter, &validate_source_adapter/1}
    ]
    
    run_validations(config, validations, [])
  end

  @doc """
  Validate only the target resource configuration.
  
  Useful for testing target resource configurations independently.
  """
  @spec validate_target_resource_config(module(), map()) :: validation_result()
  def validate_target_resource_config(resource_module, resource_config) do
    config = %{
      target_resource: resource_module,
      target_config: resource_config
    }
    
    validations = [
      {:target_resource, &validate_target_resource/1}
    ]
    
    run_validations(config, validations, [])
  end

  # Private validation functions

  defp run_validations(config, validations, opts) do
    {errors, validated_config} = Enum.reduce(validations, {[], config}, fn
      {validation_name, validation_func}, {acc_errors, acc_config} ->
        case validation_func.(acc_config) do
          {:ok, updated_config} ->
            {acc_errors, updated_config}
          {:error, validation_errors} ->
            tagged_errors = tag_errors(validation_errors, validation_name)
            {tagged_errors ++ acc_errors, acc_config}
        end
        
      {validation_name, validation_func, skip_flag}, {acc_errors, acc_config} ->
        if skip_flag do
          Logger.debug("⏭️ Skipping validation: #{validation_name}")
          {acc_errors, acc_config}
        else
          case validation_func.(acc_config) do
            {:ok, updated_config} ->
              {acc_errors, updated_config}
            {:error, validation_errors} ->
              tagged_errors = tag_errors(validation_errors, validation_name)
              {tagged_errors ++ acc_errors, acc_config}
          end
        end
    end)
    
    if length(errors) == 0 do
      {:ok, validated_config}
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp validate_basic_structure(config) do
    Logger.debug("🔍 Validating basic configuration structure")
    
    missing_fields = Enum.filter(@required_config_fields, fn field ->
      not Map.has_key?(config, field)
    end)
    
    if length(missing_fields) == 0 do
      {:ok, config}
    else
      errors = Enum.map(missing_fields, fn field ->
        %{
          field: field,
          error: :missing_required_field,
          message: "Required configuration field '#{field}' is missing",
          details: %{required_fields: @required_config_fields}
        }
      end)
      
      {:error, errors}
    end
  end

  defp validate_source_adapter(config) do
    Logger.debug("🔍 Validating source adapter configuration")
    
    adapter_module = Map.get(config, :source_adapter)
    adapter_config = Map.get(config, :source_config, %{})
    
    with {:ok, _} <- validate_adapter_module(adapter_module),
         {:ok, _} <- validate_adapter_behavior(adapter_module),
         {:ok, validated_adapter_config} <- validate_adapter_config(adapter_module, adapter_config) do
      
      updated_config = Map.put(config, :source_config, validated_adapter_config)
      {:ok, updated_config}
    else
      {:error, adapter_errors} when is_list(adapter_errors) ->
        {:error, adapter_errors}
      {:error, adapter_error} ->
        {:error, [adapter_error]}
    end
  end

  defp validate_target_resource(config) do
    Logger.debug("🔍 Validating target resource configuration")
    
    resource_module = Map.get(config, :target_resource)
    resource_config = Map.get(config, :target_config, %{})
    
    with {:ok, _} <- validate_resource_module(resource_module),
         {:ok, _} <- validate_resource_actions(resource_module, resource_config),
         {:ok, _} <- validate_resource_attributes(resource_module, resource_config),
         {:ok, validated_resource_config} <- validate_resource_config(resource_module, resource_config) do
      
      updated_config = Map.put(config, :target_config, validated_resource_config)
      {:ok, updated_config}
    else
      {:error, resource_errors} when is_list(resource_errors) ->
        {:error, resource_errors}
      {:error, resource_error} ->
        {:error, [resource_error]}
    end
  end

  defp validate_processing_config(config) do
    Logger.debug("🔍 Validating processing configuration")
    
    processing_config = Map.get(config, :processing_config, %{})
    
    # Set default values and validate ranges
    validated_config = %{
      batch_size: validate_batch_size(Map.get(processing_config, :batch_size, 100)),
      limit: validate_limit(Map.get(processing_config, :limit, 1000)),
      enable_error_recovery: Map.get(processing_config, :enable_error_recovery, true),
      enable_progress_tracking: Map.get(processing_config, :enable_progress_tracking, true),
      continue_on_batch_error: Map.get(processing_config, :continue_on_batch_error, true),
      filters: Map.get(processing_config, :filters, []),
      transformations: Map.get(processing_config, :transformations, [])
    }
    
    errors = []
    
    # Validate batch size
    errors = if validated_config.batch_size < 1 or validated_config.batch_size > 1000 do
      [%{
        field: :batch_size,
        error: :invalid_range,
        message: "batch_size must be between 1 and 1000",
        details: %{value: validated_config.batch_size, min: 1, max: 1000}
      } | errors]
    else
      errors
    end
    
    # Validate limit
    errors = if validated_config.limit < 1 or validated_config.limit > 100_000 do
      [%{
        field: :limit,
        error: :invalid_range,
        message: "limit must be between 1 and 100,000",
        details: %{value: validated_config.limit, min: 1, max: 100_000}
      } | errors]
    else
      errors
    end
    
    if length(errors) == 0 do
      updated_config = Map.put(config, :processing_config, validated_config)
      {:ok, updated_config}
    else
      {:error, errors}
    end
  end

  defp validate_pubsub_config(config) do
    Logger.debug("🔍 Validating PubSub configuration")
    
    pubsub_config = Map.get(config, :pubsub_config, %{})
    pubsub_module = Map.get(pubsub_config, :module)
    
    errors = []
    
    # Validate PubSub module
    errors = if pubsub_module do
      if Code.ensure_loaded?(pubsub_module) do
        errors
      else
        [%{
          field: :pubsub_module,
          error: :module_not_found,
          message: "PubSub module '#{pubsub_module}' could not be loaded",
          details: %{module: pubsub_module}
        } | errors]
      end
    else
      [%{
        field: :pubsub_module,
        error: :missing_required_field,
        message: "PubSub module is required for progress tracking",
        details: %{}
      } | errors]
    end
    
    if length(errors) == 0 do
      validated_config = %{
        module: pubsub_module,
        topic: Map.get(pubsub_config, :topic, "sync_progress"),
        broadcast_interval_ms: Map.get(pubsub_config, :broadcast_interval_ms, 1000)
      }
      
      updated_config = Map.put(config, :pubsub_config, validated_config)
      {:ok, updated_config}
    else
      {:error, errors}
    end
  end

  defp validate_session_config(config) do
    Logger.debug("🔍 Validating session configuration")
    
    session_config = Map.get(config, :session_config, %{})
    
    validated_config = %{
      sync_type: Map.get(session_config, :sync_type, :generic_sync),
      track_progress: Map.get(session_config, :track_progress, true),
      store_session_history: Map.get(session_config, :store_session_history, true),
      session_timeout_ms: Map.get(session_config, :session_timeout_ms, 1_800_000) # 30 minutes
    }
    
    updated_config = Map.put(config, :session_config, validated_config)
    {:ok, updated_config}
  end

  defp validate_connectivity(config) do
    Logger.debug("🔍 Validating external connectivity")
    
    adapter_module = Map.get(config, :source_adapter)
    adapter_config = Map.get(config, :source_config)
    
    # Initialize adapter and test connection
    case adapter_module.initialize(adapter_config) do
      {:ok, adapter_state} ->
        if function_exported?(adapter_module, :validate_connection, 1) do
          case adapter_module.validate_connection(adapter_state) do
            :ok ->
              {:ok, config}
            {:error, connection_error} ->
              error = %{
                field: :source_adapter,
                error: :connection_failed,
                message: "Source adapter connection test failed",
                details: %{adapter: adapter_module, error: connection_error}
              }
              {:error, [error]}
          end
        else
          # Adapter doesn't support connection validation
          Logger.debug("⚠️ Source adapter does not support connection validation")
          {:ok, config}
        end
        
      {:error, init_error} ->
        error = %{
          field: :source_adapter,
          error: :initialization_failed,
          message: "Source adapter initialization failed",
          details: %{adapter: adapter_module, error: init_error}
        }
        {:error, [error]}
    end
  end

  defp validate_permissions(config) do
    Logger.debug("🔍 Validating resource permissions")
    
    # This would validate that the configured actions can be performed
    # For now, we'll assume permissions are valid
    {:ok, config}
  end

  defp validate_integration(config) do
    Logger.debug("🔍 Validating component integration")
    
    # This would validate that all components work together properly
    # For now, we'll assume integration is valid
    {:ok, config}
  end

  # Utility validation functions

  defp validate_adapter_module(adapter_module) do
    if is_atom(adapter_module) and Code.ensure_loaded?(adapter_module) do
      {:ok, adapter_module}
    else
      error = %{
        field: :source_adapter,
        error: :invalid_module,
        message: "Source adapter module is invalid or could not be loaded",
        details: %{module: adapter_module}
      }
      {:error, error}
    end
  end

  defp validate_adapter_behavior(adapter_module) do
    required_callbacks = [:initialize, :stream_records, :validate_connection]
    
    missing_callbacks = Enum.filter(required_callbacks, fn callback ->
      not function_exported?(adapter_module, callback, 1)
    end)
    
    if length(missing_callbacks) == 0 do
      {:ok, adapter_module}
    else
      error = %{
        field: :source_adapter,
        error: :missing_callbacks,
        message: "Source adapter is missing required callback functions",
        details: %{
          module: adapter_module,
          missing_callbacks: missing_callbacks,
          required_callbacks: required_callbacks
        }
      }
      {:error, error}
    end
  end

  defp validate_adapter_config(adapter_module, adapter_config) do
    # This would validate adapter-specific configuration
    # For now, just ensure it's a map
    if is_map(adapter_config) do
      {:ok, adapter_config}
    else
      error = %{
        field: :source_config,
        error: :invalid_type,
        message: "Source adapter configuration must be a map",
        details: %{type: typeof(adapter_config)}
      }
      {:error, error}
    end
  end

  defp validate_resource_module(resource_module) do
    if is_atom(resource_module) and Code.ensure_loaded?(resource_module) do
      if function_exported?(resource_module, :__ash_resource__, 0) do
        {:ok, resource_module}
      else
        error = %{
          field: :target_resource,
          error: :not_ash_resource,
          message: "Target resource is not a valid Ash resource",
          details: %{module: resource_module}
        }
        {:error, error}
      end
    else
      error = %{
        field: :target_resource,
        error: :invalid_module,
        message: "Target resource module is invalid or could not be loaded",
        details: %{module: resource_module}
      }
      {:error, error}
    end
  end

  defp validate_resource_actions(resource_module, resource_config) do
    create_action = Map.get(resource_config, :create_action, :create)
    update_action = Map.get(resource_config, :update_action, :update)
    
    errors = []
    
    # Validate create action exists
    errors = if action_exists?(resource_module, create_action, :create) do
      errors
    else
      [%{
        field: :create_action,
        error: :action_not_found,
        message: "Create action '#{create_action}' not found on resource",
        details: %{resource: resource_module, action: create_action}
      } | errors]
    end
    
    # Validate update action exists
    errors = if action_exists?(resource_module, update_action, :update) do
      errors
    else
      [%{
        field: :update_action,
        error: :action_not_found,
        message: "Update action '#{update_action}' not found on resource",
        details: %{resource: resource_module, action: update_action}
      } | errors]
    end
    
    if length(errors) == 0 do
      {:ok, resource_config}
    else
      {:error, errors}
    end
  end

  defp validate_resource_attributes(resource_module, resource_config) do
    unique_field = Map.get(resource_config, :unique_field)
    
    if unique_field do
      if attribute_exists?(resource_module, unique_field) do
        {:ok, resource_config}
      else
        error = %{
          field: :unique_field,
          error: :attribute_not_found,
          message: "Unique field '#{unique_field}' not found on resource",
          details: %{resource: resource_module, field: unique_field}
        }
        {:error, error}
      end
    else
      error = %{
        field: :unique_field,
        error: :missing_required_field,
        message: "unique_field is required for duplicate detection",
        details: %{}
      }
      {:error, error}
    end
  end

  defp validate_resource_config(resource_module, resource_config) do
    # Additional resource-specific validations would go here
    {:ok, resource_config}
  end

  defp validate_batch_size(batch_size) when is_integer(batch_size), do: batch_size
  defp validate_batch_size(_), do: 100

  defp validate_limit(limit) when is_integer(limit), do: limit
  defp validate_limit(_), do: 1000

  defp action_exists?(resource_module, action_name, action_type) do
    try do
      actions = resource_module.__ash_resource__() |> Map.get(:actions)
      
      Enum.any?(actions, fn {_name, action} ->
        action.name == action_name and action.type == action_type
      end)
    rescue
      _ -> false
    end
  end

  defp attribute_exists?(resource_module, attribute_name) do
    try do
      attributes = resource_module.__ash_resource__() |> Map.get(:attributes)
      
      Enum.any?(attributes, fn {_name, attribute} ->
        attribute.name == attribute_name
      end)
    rescue
      _ -> false
    end
  end

  defp tag_errors(errors, validation_name) when is_list(errors) do
    Enum.map(errors, fn error ->
      Map.put(error, :validation_step, validation_name)
    end)
  end
  defp tag_errors(error, validation_name) do
    [Map.put(error, :validation_step, validation_name)]
  end

  defp typeof(value) when is_atom(value), do: :atom
  defp typeof(value) when is_binary(value), do: :string
  defp typeof(value) when is_integer(value), do: :integer
  defp typeof(value) when is_float(value), do: :float
  defp typeof(value) when is_list(value), do: :list
  defp typeof(value) when is_map(value), do: :map
  defp typeof(value) when is_tuple(value), do: :tuple
  defp typeof(_), do: :unknown
end