defmodule EhsEnforcement.Sync.Generic.SyncEngine do
  @moduledoc """
  Generic sync engine with adapter pattern for package-ready architecture.
  
  This module provides a resource-agnostic sync engine that can work with any
  Ash resource and any data source adapter. Designed for future extraction
  as the core of the `airtable_sync_phoenix` hex package.
  
  ## Architecture
  
  - **Source Adapters**: Pluggable adapters for different data sources (Airtable, CSV, API, etc.)
  - **Target Resources**: Generic Ash resource interface that works with any resource
  - **Processing Pipeline**: Configurable processing with error handling and recovery
  - **Progress Tracking**: Real-time progress monitoring via PubSub
  - **Configuration Driven**: All behavior controlled via configuration maps
  
  ## Example Usage
  
      # Configure sync operation
      config = %{
        source_adapter: EhsEnforcement.Sync.Adapters.AirtableAdapter,
        source_config: %{
          api_key: "key123",
          base_id: "app123",
          table_id: "tbl123"
        },
        target_resource: EhsEnforcement.Enforcement.Case,
        target_config: %{
          unique_field: :regulator_id,
          create_action: :create,
          update_action: :update
        },
        processing_config: %{
          batch_size: 100,
          limit: 1000,
          enable_error_recovery: true,
          enable_progress_tracking: true
        },
        pubsub_config: %{
          module: EhsEnforcement.PubSub,
          topic: "sync_progress"
        }
      }
      
      # Execute sync
      SyncEngine.execute_sync(config, opts)
  """
  
  alias EhsEnforcement.Sync.Generic.{
    SourceAdapter,
    TargetProcessor,
    ProgressTracker,
    ErrorHandler,
    ConfigValidator
  }
  require Logger

  @type sync_config :: %{
    source_adapter: module(),
    source_config: map(),
    target_resource: module(),
    target_config: map(),
    processing_config: map(),
    pubsub_config: map(),
    session_config: map()
  }

  @type sync_result :: %{
    status: :success | :failure | :partial,
    stats: %{
      total_processed: non_neg_integer(),
      created: non_neg_integer(),
      updated: non_neg_integer(),
      existing: non_neg_integer(),
      errors: non_neg_integer()
    },
    session_id: String.t(),
    error_details: list(),
    processing_time_ms: non_neg_integer()
  }

  @doc """
  Execute a generic sync operation with the provided configuration.
  
  This is the main entry point for the generic sync engine. It validates
  configuration, initializes adapters, and orchestrates the entire sync process.
  
  ## Options
  
  * `:actor` - The user performing the sync (for authorization)
  * `:dry_run` - If true, validate but don't execute (default: false)
  * `:session_id` - Optional session ID for tracking (auto-generated if not provided)
  
  ## Returns
  
  * `{:ok, sync_result}` - Success with detailed results
  * `{:error, reason}` - Failure with error details
  """
  @spec execute_sync(sync_config(), keyword()) :: {:ok, sync_result()} | {:error, any()}
  def execute_sync(config, opts \\ []) do
    start_time = System.monotonic_time(:millisecond)
    actor = Keyword.get(opts, :actor)
    dry_run = Keyword.get(opts, :dry_run, false)
    session_id = Keyword.get(opts, :session_id, generate_session_id())
    
    Logger.info("🚀 Starting generic sync operation (session: #{session_id})")
    
    with {:ok, validated_config} <- ConfigValidator.validate_sync_config(config),
         {:ok, adapters} <- initialize_adapters(validated_config),
         {:ok, session} <- start_sync_session(validated_config, session_id, opts) do
      
      if dry_run do
        Logger.info("🔍 Dry run mode - validating configuration only")
        {:ok, create_dry_run_result(validated_config, session_id, start_time)}
      else
        execute_sync_operation(validated_config, adapters, session, opts, start_time)
      end
    else
      {:error, reason} ->
        Logger.error("❌ Generic sync failed during initialization: #{inspect(reason)}")
        {:error, {:sync_initialization_failed, reason}}
    end
  end

  @doc """
  Stream records from source and process them through the generic pipeline.
  
  This function provides fine-grained control over the sync process,
  allowing for custom processing logic while still using the generic
  adapter and progress tracking infrastructure.
  """
  @spec stream_and_process(sync_config(), keyword()) :: Stream.t()
  def stream_and_process(config, opts \\ []) do
    with {:ok, validated_config} <- ConfigValidator.validate_sync_config(config),
         {:ok, adapters} <- initialize_adapters(validated_config) do
      
      source_adapter = adapters.source_adapter
      target_processor = adapters.target_processor
      progress_tracker = adapters.progress_tracker
      
      # Create processing stream
      source_adapter.stream_records(validated_config.source_config)
      |> apply_filters(validated_config)
      |> apply_transformations(validated_config)
      |> Stream.chunk_every(get_batch_size(validated_config))
      |> Stream.with_index()
      |> Stream.map(fn {batch, batch_index} ->
        process_batch_with_tracking(
          batch,
          batch_index,
          target_processor,
          progress_tracker,
          validated_config,
          opts
        )
      end)
    else
      {:error, reason} ->
        Logger.error("❌ Stream initialization failed: #{inspect(reason)}")
        Stream.repeatedly(fn -> {:error, reason} end)
    end
  end

  @doc """
  Get sync operation status and progress information.
  
  Provides real-time status information for ongoing sync operations.
  """
  @spec get_sync_status(String.t()) :: {:ok, map()} | {:error, any()}
  def get_sync_status(session_id) do
    ProgressTracker.get_session_status(session_id)
  end

  @doc """
  Cancel an ongoing sync operation.
  
  Gracefully stops a sync operation and cleans up resources.
  """
  @spec cancel_sync(String.t()) :: :ok | {:error, any()}
  def cancel_sync(session_id) do
    Logger.info("🛑 Cancelling sync operation (session: #{session_id})")
    
    with {:ok, _status} <- ProgressTracker.get_session_status(session_id),
         :ok <- ProgressTracker.cancel_session(session_id) do
      Logger.info("✅ Sync operation cancelled successfully")
      :ok
    else
      {:error, :session_not_found} ->
        Logger.warn("⚠️ Sync session not found: #{session_id}")
        {:error, :session_not_found}
        
      {:error, reason} ->
        Logger.error("❌ Failed to cancel sync: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp initialize_adapters(config) do
    Logger.debug("🔧 Initializing generic sync adapters")
    
    with {:ok, source_adapter} <- initialize_source_adapter(config),
         {:ok, target_processor} <- initialize_target_processor(config),
         {:ok, progress_tracker} <- initialize_progress_tracker(config),
         {:ok, error_handler} <- initialize_error_handler(config) do
      
      adapters = %{
        source_adapter: source_adapter,
        target_processor: target_processor,
        progress_tracker: progress_tracker,
        error_handler: error_handler
      }
      
      Logger.debug("✅ All adapters initialized successfully")
      {:ok, adapters}
    else
      {:error, reason} ->
        Logger.error("❌ Adapter initialization failed: #{inspect(reason)}")
        {:error, {:adapter_initialization_failed, reason}}
    end
  end

  defp initialize_source_adapter(config) do
    adapter_module = config.source_adapter
    adapter_config = config.source_config
    
    case adapter_module.initialize(adapter_config) do
      {:ok, adapter} ->
        Logger.debug("✅ Source adapter initialized: #{adapter_module}")
        {:ok, adapter}
        
      {:error, reason} ->
        {:error, {:source_adapter_failed, adapter_module, reason}}
    end
  end

  defp initialize_target_processor(config) do
    resource_module = config.target_resource
    resource_config = config.target_config
    
    case TargetProcessor.initialize(resource_module, resource_config) do
      {:ok, processor} ->
        Logger.debug("✅ Target processor initialized: #{resource_module}")
        {:ok, processor}
        
      {:error, reason} ->
        {:error, {:target_processor_failed, resource_module, reason}}
    end
  end

  defp initialize_progress_tracker(config) do
    pubsub_config = config.pubsub_config
    session_config = config.session_config
    
    case ProgressTracker.initialize(pubsub_config, session_config) do
      {:ok, tracker} ->
        Logger.debug("✅ Progress tracker initialized")
        {:ok, tracker}
        
      {:error, reason} ->
        {:error, {:progress_tracker_failed, reason}}
    end
  end

  defp initialize_error_handler(config) do
    error_config = Map.get(config, :error_handling_config, %{})
    
    case ErrorHandler.initialize(error_config) do
      {:ok, handler} ->
        Logger.debug("✅ Error handler initialized")
        {:ok, handler}
        
      {:error, reason} ->
        {:error, {:error_handler_failed, reason}}
    end
  end

  defp start_sync_session(config, session_id, opts) do
    session_config = config.session_config
    actor = Keyword.get(opts, :actor)
    
    session_data = %{
      session_id: session_id,
      sync_type: Map.get(session_config, :sync_type, :generic_sync),
      target_resource: to_string(config.target_resource),
      source_adapter: to_string(config.source_adapter),
      config: Map.take(config, [:processing_config, :source_config, :target_config]),
      initiated_by: extract_user_identifier(actor),
      estimated_total: Map.get(config.processing_config, :limit, 1000)
    }
    
    case ProgressTracker.start_session(session_data) do
      {:ok, session} ->
        Logger.info("✅ Sync session started: #{session_id}")
        {:ok, session}
        
      {:error, reason} ->
        {:error, {:session_start_failed, reason}}
    end
  end

  defp execute_sync_operation(config, adapters, session, opts, start_time) do
    Logger.info("🔄 Executing generic sync operation")
    
    session_id = session.session_id
    actor = Keyword.get(opts, :actor)
    
    # Mark session as running
    ProgressTracker.mark_session_running(session_id)
    
    # Execute sync with comprehensive error handling
    result = try do
      execute_sync_pipeline(config, adapters, session, actor)
    rescue
      error ->
        Logger.error("💥 Sync operation crashed: #{inspect(error)}")
        {:error, {:sync_crashed, error, __STACKTRACE__}}
    catch
      :exit, reason ->
        Logger.error("🚪 Sync operation exited: #{inspect(reason)}")
        {:error, {:sync_exited, reason}}
    end
    
    # Calculate processing time
    end_time = System.monotonic_time(:millisecond)
    processing_time_ms = end_time - start_time
    
    # Handle result and finalize session
    finalize_sync_session(result, session, adapters, processing_time_ms)
  end

  defp execute_sync_pipeline(config, adapters, session, actor) do
    source_adapter = adapters.source_adapter
    target_processor = adapters.target_processor
    progress_tracker = adapters.progress_tracker
    error_handler = adapters.error_handler
    
    session_id = session.session_id
    processing_config = config.processing_config
    
    # Initialize counters
    stats = %{
      total_processed: 0,
      created: 0,
      updated: 0,
      existing: 0,
      errors: 0
    }
    
    error_details = []
    
    Logger.info("📊 Starting sync pipeline processing")
    
    # Stream and process records
    result = source_adapter.stream_records(config.source_config)
    |> apply_filters(config)
    |> apply_transformations(config)
    |> Stream.take(Map.get(processing_config, :limit, 1000))
    |> Stream.chunk_every(Map.get(processing_config, :batch_size, 100))
    |> Stream.with_index()
    |> Enum.reduce_while({stats, error_details}, fn {batch, batch_index}, {acc_stats, acc_errors} ->
      
      batch_number = batch_index + 1
      Logger.info("📦 Processing batch #{batch_number} (#{length(batch)} records)")
      
      # Start batch tracking
      batch_config = %{
        batch_number: batch_number,
        batch_size: length(batch),
        source_ids: extract_source_ids(batch)
      }
      
      {:ok, batch_progress} = progress_tracker.start_batch(session_id, batch_config)
      
      # Process batch with error handling
      case process_batch_with_error_handling(batch, target_processor, error_handler, config, actor) do
        {:ok, batch_result} ->
          # Update statistics
          new_stats = %{
            total_processed: acc_stats.total_processed + batch_result.processed,
            created: acc_stats.created + batch_result.created,
            updated: acc_stats.updated + batch_result.updated,
            existing: acc_stats.existing + batch_result.existing,
            errors: acc_stats.errors + batch_result.errors
          }
          
          # Update batch progress
          batch_results = %{
            records_processed: batch_result.processed,
            records_created: batch_result.created,
            records_updated: batch_result.updated,
            records_existing: batch_result.existing,
            records_failed: batch_result.errors
          }
          
          progress_tracker.update_batch_progress(batch_progress.id, batch_results)
          progress_tracker.complete_batch(batch_progress.id, batch_results)
          
          Logger.info("✅ Batch #{batch_number} completed: #{inspect(batch_result)}")
          
          # Continue or halt based on limits
          total_processed = new_stats.total_processed
          limit = Map.get(processing_config, :limit, 1000)
          
          if total_processed >= limit do
            {:halt, {new_stats, acc_errors}}
          else
            {:cont, {new_stats, acc_errors}}
          end
          
        {:error, batch_error} ->
          Logger.error("❌ Batch #{batch_number} failed: #{inspect(batch_error)}")
          
          # Handle batch error
          updated_errors = [batch_error | acc_errors]
          
          # Mark batch as failed
          progress_tracker.fail_batch(batch_progress.id, %{
            error: batch_error,
            batch_number: batch_number
          })
          
          # Decide whether to continue based on error handling configuration
          continue_on_error = Map.get(processing_config, :continue_on_batch_error, true)
          
          if continue_on_error do
            Logger.warn("⚠️ Continuing sync despite batch error")
            {:cont, {acc_stats, updated_errors}}
          else
            Logger.error("🛑 Stopping sync due to batch error")
            {:halt, {:error, {:batch_failed, batch_error, acc_stats, updated_errors}}}
          end
      end
    end)
    
    case result do
      {final_stats, final_errors} ->
        Logger.info("🎉 Sync pipeline completed successfully")
        Logger.info("📊 Final stats: #{inspect(final_stats)}")
        
        {:ok, %{
          stats: final_stats,
          error_details: final_errors
        }}
        
      {:error, pipeline_error} ->
        Logger.error("💥 Sync pipeline failed: #{inspect(pipeline_error)}")
        {:error, pipeline_error}
    end
  end

  defp process_batch_with_error_handling(batch, target_processor, error_handler, config, actor) do
    processing_config = config.processing_config
    enable_error_recovery = Map.get(processing_config, :enable_error_recovery, true)
    
    # Process each record in the batch
    results = Enum.map(batch, fn record ->
      case target_processor.process_record(record, config.target_config, actor: actor) do
        {:ok, result} ->
          result
          
        {:error, record_error} when enable_error_recovery ->
          # Attempt error recovery
          case error_handler.handle_record_error(record_error, record, config) do
            {:ok, recovered_result} ->
              Logger.debug("🔧 Record error recovered: #{inspect(record_error)}")
              recovered_result
              
            {:error, unrecoverable_error} ->
              Logger.warn("⚠️ Record error not recoverable: #{inspect(unrecoverable_error)}")
              {:error, unrecoverable_error}
          end
          
        {:error, record_error} ->
          Logger.warn("⚠️ Record processing failed: #{inspect(record_error)}")
          {:error, record_error}
      end
    end)
    
    # Count results by status
    created_count = count_results(results, :created)
    updated_count = count_results(results, :updated)
    existing_count = count_results(results, :existing)
    error_count = count_results(results, :error)
    
    total_processed = created_count + updated_count + existing_count + error_count
    
    {:ok, %{
      processed: total_processed,
      created: created_count,
      updated: updated_count,
      existing: existing_count,
      errors: error_count,
      results: results
    }}
  end

  defp finalize_sync_session(result, session, adapters, processing_time_ms) do
    session_id = session.session_id
    progress_tracker = adapters.progress_tracker
    
    case result do
      {:ok, sync_data} ->
        Logger.info("✅ Finalizing successful sync session")
        
        final_stats = Map.merge(sync_data.stats, %{
          sync_type: session.config.sync_type,
          processing_time_ms: processing_time_ms
        })
        
        progress_tracker.complete_session(session_id, final_stats)
        
        sync_result = %{
          status: :success,
          stats: sync_data.stats,
          session_id: session_id,
          error_details: sync_data.error_details,
          processing_time_ms: processing_time_ms
        }
        
        {:ok, sync_result}
        
      {:error, sync_error} ->
        Logger.error("❌ Finalizing failed sync session")
        
        error_info = %{
          message: "Generic sync operation failed",
          error: sync_error,
          processing_time_ms: processing_time_ms
        }
        
        progress_tracker.fail_session(session_id, error_info)
        
        sync_result = %{
          status: :failure,
          stats: %{total_processed: 0, created: 0, updated: 0, existing: 0, errors: 1},
          session_id: session_id,
          error_details: [sync_error],
          processing_time_ms: processing_time_ms
        }
        
        {:error, sync_result}
    end
  end

  # Utility functions

  defp apply_filters(stream, config) do
    filters = get_in(config, [:processing_config, :filters]) || []
    
    Enum.reduce(filters, stream, fn filter_config, acc_stream ->
      apply_single_filter(acc_stream, filter_config)
    end)
  end

  defp apply_transformations(stream, config) do
    transformations = get_in(config, [:processing_config, :transformations]) || []
    
    Enum.reduce(transformations, stream, fn transform_config, acc_stream ->
      apply_single_transformation(acc_stream, transform_config)
    end)
  end

  defp apply_single_filter(stream, filter_config) do
    case filter_config do
      {:field_equals, field, value} ->
        Stream.filter(stream, fn record ->
          get_record_field(record, field) == value
        end)
        
      {:field_contains, field, substring} ->
        Stream.filter(stream, fn record ->
          field_value = get_record_field(record, field)
          is_binary(field_value) and String.contains?(field_value, substring)
        end)
        
      {:custom_filter, filter_function} when is_function(filter_function, 1) ->
        Stream.filter(stream, filter_function)
        
      _ ->
        Logger.warn("⚠️ Unknown filter configuration: #{inspect(filter_config)}")
        stream
    end
  end

  defp apply_single_transformation(stream, transform_config) do
    case transform_config do
      {:map_field, field, mapping_function} when is_function(mapping_function, 1) ->
        Stream.map(stream, fn record ->
          update_record_field(record, field, mapping_function)
        end)
        
      {:custom_transform, transform_function} when is_function(transform_function, 1) ->
        Stream.map(stream, transform_function)
        
      _ ->
        Logger.warn("⚠️ Unknown transformation configuration: #{inspect(transform_config)}")
        stream
    end
  end

  defp get_record_field(record, field) when is_map(record) do
    case field do
      field when is_atom(field) -> Map.get(record, field)
      field when is_binary(field) -> Map.get(record, field)
      [:fields, subfield] -> get_in(record, ["fields", subfield])
      path when is_list(path) -> get_in(record, path)
      _ -> nil
    end
  end

  defp update_record_field(record, field, mapping_function) when is_map(record) do
    current_value = get_record_field(record, field)
    new_value = mapping_function.(current_value)
    
    case field do
      field when is_atom(field) -> Map.put(record, field, new_value)
      field when is_binary(field) -> Map.put(record, field, new_value)
      [:fields, subfield] -> put_in(record, ["fields", subfield], new_value)
      path when is_list(path) -> put_in(record, path, new_value)
      _ -> record
    end
  end

  defp count_results(results, status) do
    Enum.count(results, fn
      {^status, _} -> true
      {:ok, {^status, _}} -> true
      _ -> false
    end)
  end

  defp extract_source_ids(batch) do
    Enum.map(batch, fn record ->
      case record do
        %{"id" => id} -> id
        %{id: id} -> id
        %{"fields" => %{"regulator_id" => reg_id}} -> reg_id
        %{regulator_id: reg_id} -> reg_id
        _ -> nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp get_batch_size(config) do
    get_in(config, [:processing_config, :batch_size]) || 100
  end

  defp generate_session_id do
    "sync_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  defp extract_user_identifier(nil), do: "system"
  defp extract_user_identifier(actor) when is_map(actor) do
    Map.get(actor, :email, Map.get(actor, :username, Map.get(actor, :id, "unknown_user")))
  end
  defp extract_user_identifier(actor), do: to_string(actor)

  defp create_dry_run_result(config, session_id, start_time) do
    end_time = System.monotonic_time(:millisecond)
    processing_time_ms = end_time - start_time
    
    %{
      status: :dry_run,
      stats: %{
        total_processed: 0,
        created: 0,
        updated: 0,
        existing: 0,
        errors: 0
      },
      session_id: session_id,
      error_details: [],
      processing_time_ms: processing_time_ms,
      validated_config: config
    }
  end

  defp process_batch_with_tracking(batch, batch_index, target_processor, progress_tracker, config, opts) do
    session_id = Map.get(config, :session_id)
    actor = Keyword.get(opts, :actor)
    
    batch_number = batch_index + 1
    
    Logger.debug("📦 Processing tracked batch #{batch_number}")
    
    # Start batch tracking if session exists
    batch_progress = if session_id do
      batch_config = %{
        batch_number: batch_number,
        batch_size: length(batch),
        source_ids: extract_source_ids(batch)
      }
      
      {:ok, progress} = progress_tracker.start_batch(session_id, batch_config)
      progress
    else
      nil
    end
    
    # Process batch
    results = Enum.map(batch, fn record ->
      target_processor.process_record(record, config.target_config, actor: actor)
    end)
    
    # Count results
    created_count = count_results(results, :created)
    updated_count = count_results(results, :updated)
    existing_count = count_results(results, :existing)
    error_count = count_results(results, :error)
    
    batch_result = %{
      batch_number: batch_number,
      processed: length(results),
      created: created_count,
      updated: updated_count,
      existing: existing_count,
      errors: error_count,
      results: results
    }
    
    # Complete batch tracking if session exists
    if batch_progress do
      batch_results = %{
        records_processed: batch_result.processed,
        records_created: batch_result.created,
        records_updated: batch_result.updated,
        records_existing: batch_result.existing,
        records_failed: batch_result.errors
      }
      
      progress_tracker.complete_batch(batch_progress.id, batch_results)
    end
    
    batch_result
  end
end