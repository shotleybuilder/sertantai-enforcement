defmodule EhsEnforcement.Sync.Generic.TargetProcessor do
  @moduledoc """
  Generic target processor for handling record processing to any Ash resource.
  
  This module provides a resource-agnostic interface for processing records
  into Ash resources. It handles the create/update/exists logic generically
  while allowing for resource-specific configuration.
  
  ## Configuration
  
  The target processor is configured with a map containing:
  
      %{
        unique_field: :regulator_id,           # Field used for duplicate detection
        create_action: :create,                # Ash action for creating records
        update_action: :update,                # Ash action for updating records
        field_mapping: %{                      # Map source fields to resource attributes
          "source_field" => :target_attribute
        },
        transformations: [                     # Record transformations before processing
          {:normalize_dates, [:created_at, :updated_at]},
          {:custom_transform, &my_transform_function/1}
        ],
        duplicate_strategy: :update,           # :update, :skip, :error
        validation_rules: [                    # Custom validation rules
          {:required_fields, [:name, :type]},
          {:custom_validation, &my_validation_function/1}
        ]
      }
  
  ## Processing Flow
  
  1. Record validation against rules
  2. Field mapping and transformations
  3. Duplicate detection using unique_field
  4. Create/update/skip based on duplicate_strategy
  5. Result classification and error handling
  
  ## Example Usage
  
      # Initialize processor for Case resource
      config = %{
        unique_field: :regulator_id,
        create_action: :create,
        update_action: :update,
        field_mapping: %{
          "case_id" => :regulator_id,
          "offender_name" => :offender_name,
          "action_type" => :offence_action_type
        }
      }
      
      {:ok, processor} = TargetProcessor.initialize(MyApp.Cases.Case, config)
      
      # Process a record
      record = %{
        "id" => "rec123",
        "fields" => %{
          "case_id" => "HSE001",
          "offender_name" => "Acme Corp",
          "action_type" => "Court Case"
        }
      }
      
      {:ok, result} = TargetProcessor.process_record(processor, record, config, actor: admin_user)
      # result is {:created, case_record} | {:updated, case_record} | {:existing, case_record}
  """
  
  alias EhsEnforcement.Sync.Generic.RecordTransformer
  alias EhsEnforcement.Sync.Generic.RecordValidator
  require Logger
  require Ash.Query
  import Ash.Expr

  @type processor_state :: %{
    resource_module: module(),
    config: map()
  }
  
  @type processing_result :: 
    {:created, any()} | 
    {:updated, any()} | 
    {:existing, any()} | 
    {:error, any()}

  @doc """
  Initialize the target processor for a specific Ash resource.
  
  ## Parameters
  
  * `resource_module` - The Ash resource module to process records into
  * `config` - Configuration map with processing options
  
  ## Returns
  
  * `{:ok, processor_state}` - Success with initialized processor
  * `{:error, reason}` - Initialization failed
  """
  @spec initialize(module(), map()) :: {:ok, processor_state()} | {:error, any()}
  def initialize(resource_module, config) do
    Logger.debug("🔧 Initializing target processor for #{resource_module}")
    
    with :ok <- validate_resource_module(resource_module),
         :ok <- validate_processor_config(config),
         {:ok, normalized_config} <- normalize_processor_config(config) do
      
      processor_state = %{
        resource_module: resource_module,
        config: normalized_config
      }
      
      Logger.debug("✅ Target processor initialized successfully")
      {:ok, processor_state}
    else
      {:error, reason} ->
        Logger.error("❌ Target processor initialization failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Process a single record into the target resource.
  
  This is the main processing function that handles the complete flow
  from record validation through create/update operations.
  
  ## Parameters
  
  * `processor_state` - Processor state from initialize/2
  * `record` - Source record to process
  * `config` - Processing configuration (can override processor config)
  * `opts` - Processing options including :actor
  
  ## Returns
  
  * `{:ok, processing_result}` - Success with operation result
  * `{:error, reason}` - Processing failed
  """
  @spec process_record(processor_state(), map(), map(), keyword()) :: 
    {:ok, processing_result()} | {:error, any()}
  def process_record(processor_state, record, config \\ %{}, opts \\ []) do
    resource_module = processor_state.resource_module
    merged_config = Map.merge(processor_state.config, config)
    actor = Keyword.get(opts, :actor)
    
    Logger.debug("🔄 Processing record for #{resource_module}")
    
    with {:ok, validated_record} <- validate_record(record, merged_config),
         {:ok, transformed_record} <- transform_record(validated_record, merged_config),
         {:ok, mapped_attrs} <- map_record_fields(transformed_record, merged_config),
         {:ok, processing_result} <- process_with_duplicate_handling(
           resource_module, 
           mapped_attrs, 
           merged_config, 
           actor
         ) do
      
      Logger.debug("✅ Record processed successfully: #{elem(processing_result, 0)}")
      {:ok, processing_result}
    else
      {:error, reason} ->
        Logger.debug("❌ Record processing failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Process multiple records in batch with optimized performance.
  
  This function processes multiple records efficiently, with options
  for parallel processing and batch optimizations.
  """
  @spec process_batch(processor_state(), [map()], map(), keyword()) :: 
    {:ok, [processing_result()]} | {:error, any()}
  def process_batch(processor_state, records, config \\ %{}, opts \\ []) do
    parallel = Keyword.get(opts, :parallel, false)
    max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())
    
    Logger.debug("📦 Processing batch of #{length(records)} records")
    
    processing_function = fn record ->
      process_record(processor_state, record, config, opts)
    end
    
    results = if parallel and length(records) > 10 do
      Logger.debug("🚀 Using parallel processing with max_concurrency: #{max_concurrency}")
      
      records
      |> Task.async_stream(processing_function, 
           max_concurrency: max_concurrency,
           timeout: 30_000,
           on_timeout: :kill_task
         )
      |> Enum.map(fn
        {:ok, {:ok, result}} -> result
        {:ok, {:error, error}} -> {:error, error}
        {:exit, reason} -> {:error, {:task_exit, reason}}
      end)
    else
      Logger.debug("🔄 Using sequential processing")
      
      Enum.map(records, fn record ->
        case processing_function.(record) do
          {:ok, result} -> result
          {:error, error} -> {:error, error}
        end
      end)
    end
    
    Logger.debug("✅ Batch processing completed")
    {:ok, results}
  end

  @doc """
  Get processing statistics for a batch of results.
  
  Analyzes batch processing results and returns statistics.
  """
  @spec get_batch_stats([processing_result()]) :: map()
  def get_batch_stats(results) do
    %{
      total: length(results),
      created: count_results(results, :created),
      updated: count_results(results, :updated),
      existing: count_results(results, :existing),
      errors: count_results(results, :error)
    }
  end

  # Private functions

  defp validate_resource_module(resource_module) do
    if Code.ensure_loaded?(resource_module) do
      if function_exported?(resource_module, :__ash_resource__, 0) do
        :ok
      else
        {:error, {:not_ash_resource, resource_module}}
      end
    else
      {:error, {:module_not_found, resource_module}}
    end
  end

  defp validate_processor_config(config) do
    required_fields = [:unique_field]
    
    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(config, field)
    end)
    
    if length(missing_fields) == 0 do
      :ok
    else
      {:error, {:missing_config_fields, missing_fields}}
    end
  end

  defp normalize_processor_config(config) do
    normalized = %{
      unique_field: Map.get(config, :unique_field),
      create_action: Map.get(config, :create_action, :create),
      update_action: Map.get(config, :update_action, :update),
      field_mapping: Map.get(config, :field_mapping, %{}),
      transformations: Map.get(config, :transformations, []),
      duplicate_strategy: Map.get(config, :duplicate_strategy, :update),
      validation_rules: Map.get(config, :validation_rules, []),
      error_handling: Map.get(config, :error_handling, %{
        continue_on_validation_error: true,
        log_errors: true
      })
    }
    
    {:ok, normalized}
  end

  defp validate_record(record, config) do
    validation_rules = Map.get(config, :validation_rules, [])
    
    case RecordValidator.validate_record(record, validation_rules) do
      :ok ->
        {:ok, record}
      {:error, validation_errors} ->
        if get_in(config, [:error_handling, :continue_on_validation_error]) do
          Logger.warn("⚠️ Record validation failed but continuing: #{inspect(validation_errors)}")
          {:ok, record}
        else
          {:error, {:validation_failed, validation_errors}}
        end
    end
  end

  defp transform_record(record, config) do
    transformations = Map.get(config, :transformations, [])
    
    case RecordTransformer.apply_transformations(record, transformations) do
      {:ok, transformed_record} ->
        {:ok, transformed_record}
      {:error, transform_error} ->
        {:error, {:transformation_failed, transform_error}}
    end
  end

  defp map_record_fields(record, config) do
    field_mapping = Map.get(config, :field_mapping, %{})
    
    # Extract fields from record
    source_fields = case record do
      %{"fields" => fields} when is_map(fields) -> fields
      %{fields: fields} when is_map(fields) -> fields
      fields when is_map(fields) -> fields
      _ -> %{}
    end
    
    # Apply field mapping
    mapped_attrs = if map_size(field_mapping) > 0 do
      Enum.reduce(field_mapping, %{}, fn {source_field, target_attr}, acc ->
        case Map.get(source_fields, source_field) do
          nil -> acc
          value -> Map.put(acc, target_attr, value)
        end
      end)
    else
      # No mapping - convert string keys to atoms if possible
      Enum.reduce(source_fields, %{}, fn {key, value}, acc ->
        atom_key = try do
          String.to_existing_atom(key)
        rescue
          ArgumentError -> key
        end
        Map.put(acc, atom_key, value)
      end)
    end
    
    # Add record ID if not mapped
    record_id = Map.get(record, "id") || Map.get(record, :id)
    if record_id && not Map.has_key?(mapped_attrs, :source_id) do
      mapped_attrs = Map.put(mapped_attrs, :source_id, record_id)
    end
    
    {:ok, mapped_attrs}
  end

  defp process_with_duplicate_handling(resource_module, attrs, config, actor) do
    unique_field = Map.get(config, :unique_field)
    create_action = Map.get(config, :create_action, :create)
    update_action = Map.get(config, :update_action, :update)
    duplicate_strategy = Map.get(config, :duplicate_strategy, :update)
    
    # Attempt to create record first
    case Ash.create(resource_module, attrs, action: create_action, actor: actor) do
      {:ok, created_record} ->
        {:created, created_record}
        
      {:error, %Ash.Error.Invalid{errors: errors}} ->
        # Check if error is due to duplicate
        if is_duplicate_error?(errors, unique_field) do
          handle_duplicate_record(
            resource_module, 
            attrs, 
            config, 
            actor, 
            duplicate_strategy
          )
        else
          {:error, {:validation_errors, errors}}
        end
        
      {:error, error} ->
        {:error, {:create_failed, error}}
    end
  end

  defp handle_duplicate_record(resource_module, attrs, config, actor, strategy) do
    unique_field = Map.get(config, :unique_field)
    update_action = Map.get(config, :update_action, :update)
    
    case strategy do
      :update ->
        # Find existing record and update it
        case find_existing_record(resource_module, attrs, unique_field, actor) do
          {:ok, existing_record} ->
            case Ash.update(existing_record, attrs, action: update_action, actor: actor) do
              {:ok, updated_record} ->
                {:updated, updated_record}
              {:error, update_error} ->
                # If update fails, return existing record as-is
                Logger.warn("⚠️ Update failed, returning existing record: #{inspect(update_error)}")
                {:existing, existing_record}
            end
            
          {:error, _find_error} ->
            # Could not find existing record, return error
            {:error, {:duplicate_but_not_found, unique_field}}
        end
        
      :skip ->
        # Find existing record and return it unchanged
        case find_existing_record(resource_module, attrs, unique_field, actor) do
          {:ok, existing_record} ->
            {:existing, existing_record}
          {:error, find_error} ->
            {:error, {:skip_failed, find_error}}
        end
        
      :error ->
        # Treat duplicate as an error
        {:error, {:duplicate_record, unique_field}}
        
      _ ->
        {:error, {:unknown_duplicate_strategy, strategy}}
    end
  end

  defp find_existing_record(resource_module, attrs, unique_field, actor) do
    unique_value = Map.get(attrs, unique_field)
    
    if unique_value do
      query = resource_module
      |> Ash.Query.filter(^ref(unique_field) == ^unique_value)
      
      case Ash.read_one(query, actor: actor) do
        {:ok, record} when not is_nil(record) ->
          {:ok, record}
        {:ok, nil} ->
          {:error, :record_not_found}
        {:error, error} ->
          {:error, error}
      end
    else
      {:error, {:missing_unique_value, unique_field}}
    end
  end

  defp is_duplicate_error?(errors, unique_field) do
    Enum.any?(errors, fn error ->
      case error do
        %{field: field, message: message} ->
          (field == unique_field or field == to_string(unique_field)) and
          (String.contains?(message, "already") or 
           String.contains?(message, "unique") or
           String.contains?(message, "duplicate"))
           
        %{constraint_name: constraint_name} ->
          String.contains?(constraint_name, to_string(unique_field))
          
        _ ->
          false
      end
    end)
  end

  defp count_results(results, status) do
    Enum.count(results, fn
      {^status, _} -> true
      {:error, _} when status == :error -> true
      _ -> false
    end)
  end
end