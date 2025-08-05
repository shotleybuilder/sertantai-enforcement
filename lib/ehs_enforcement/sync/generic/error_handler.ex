defmodule EhsEnforcement.Sync.Generic.ErrorHandler do
  @moduledoc """
  Generic error handling for sync operations.
  
  This module provides a pluggable error handling system that can classify
  errors, determine recovery strategies, and execute recovery actions.
  It integrates with the existing error handling infrastructure while
  providing a generic interface for the package-ready architecture.
  
  ## Features
  
  - Error classification and categorization
  - Pluggable recovery strategy determination
  - Integration with existing error recovery systems
  - Configurable error handling policies
  - Error aggregation and reporting
  - Circuit breaker integration
  
  ## Configuration
  
      config = %{
        classification_strategy: :intelligent,  # :intelligent | :simple | :custom
        recovery_strategy: :adaptive,           # :adaptive | :aggressive | :conservative
        circuit_breaker: %{
          enabled: true,
          failure_threshold: 5,
          timeout_ms: 30_000
        },
        error_policies: %{
          continue_on_validation_error: true,
          continue_on_transform_error: true,
          continue_on_processing_error: false,
          max_consecutive_errors: 10
        },
        integration: %{
          error_classifier: EhsEnforcement.Sync.ErrorClassifier,
          error_recovery: EhsEnforcement.Sync.ErrorRecovery,
          retry_engine: EhsEnforcement.Sync.RetryEngine
        }
      }
  
  ## Usage
  
      # Initialize error handler
      {:ok, handler} = ErrorHandler.initialize(config)
      
      # Handle a record processing error
      case ErrorHandler.handle_record_error(error, record, config) do
        {:ok, recovery_result} -> 
          # Error was recovered
        {:error, unrecoverable_error} -> 
          # Error could not be recovered
      end
  """
  
  alias EhsEnforcement.Sync.{ErrorClassifier, ErrorRecovery, RetryEngine}
  require Logger

  @type handler_config :: %{
    classification_strategy: atom(),
    recovery_strategy: atom(),
    circuit_breaker: map(),
    error_policies: map(),
    integration: map()
  }

  @type handler_state :: %{
    config: handler_config(),
    error_classifier: module(),
    error_recovery: module(),
    retry_engine: module(),
    circuit_breaker_state: map(),
    error_statistics: map()
  }

  @doc """
  Initialize the generic error handler with configuration.
  
  ## Parameters
  
  * `config` - Error handler configuration map
  
  ## Returns
  
  * `{:ok, handler_state}` - Initialized handler
  * `{:error, reason}` - Initialization failed
  """
  @spec initialize(handler_config()) :: {:ok, handler_state()} | {:error, any()}
  def initialize(config) do
    Logger.debug("🔧 Initializing generic error handler")
    
    # Set defaults and normalize configuration
    normalized_config = normalize_error_handler_config(config)
    
    # Get integration modules
    error_classifier = get_in(normalized_config, [:integration, :error_classifier]) || ErrorClassifier
    error_recovery = get_in(normalized_config, [:integration, :error_recovery]) || ErrorRecovery
    retry_engine = get_in(normalized_config, [:integration, :retry_engine]) || RetryEngine
    
    # Initialize circuit breaker state
    circuit_breaker_state = initialize_circuit_breaker(normalized_config.circuit_breaker)
    
    # Initialize error statistics
    error_statistics = %{
      total_errors: 0,
      recovered_errors: 0,
      unrecoverable_errors: 0,
      consecutive_errors: 0,
      error_types: %{}
    }
    
    handler_state = %{
      config: normalized_config,
      error_classifier: error_classifier,
      error_recovery: error_recovery,
      retry_engine: retry_engine,
      circuit_breaker_state: circuit_breaker_state,
      error_statistics: error_statistics
    }
    
    Logger.debug("✅ Generic error handler initialized successfully")
    {:ok, handler_state}
  end

  @doc """
  Handle a record processing error with recovery attempts.
  
  This is the main entry point for handling errors that occur during
  individual record processing. It classifies the error, determines
  the best recovery strategy, and attempts recovery.
  
  ## Parameters
  
  * `error` - The error that occurred
  * `record` - The record being processed when the error occurred
  * `config` - Processing configuration and context
  
  ## Returns
  
  * `{:ok, recovery_result}` - Error was successfully handled/recovered
  * `{:error, unrecoverable_error}` - Error could not be recovered
  """
  @spec handle_record_error(any(), map(), map()) :: {:ok, any()} | {:error, any()}
  def handle_record_error(error, record, config) do
    Logger.debug("🔧 Handling record processing error")
    
    # Get or initialize handler state from config
    handler_state = get_handler_state_from_config(config)
    
    # Update error statistics
    updated_handler_state = update_error_statistics(handler_state, error)
    
    # Check circuit breaker
    case check_circuit_breaker(updated_handler_state) do
      :closed ->
        # Circuit breaker is closed, proceed with error handling
        handle_error_with_recovery(error, record, config, updated_handler_state)
        
      :open ->
        # Circuit breaker is open, reject immediately
        Logger.warn("⚠️ Circuit breaker is open, rejecting error handling")
        {:error, {:circuit_breaker_open, error}}
        
      :half_open ->
        # Circuit breaker is half-open, try with limited recovery
        Logger.debug("🔄 Circuit breaker is half-open, attempting limited recovery")
        handle_error_with_limited_recovery(error, record, config, updated_handler_state)
    end
  end

  @doc """
  Handle a batch processing error with escalation.
  
  This function handles errors that affect entire batches, such as
  connection failures or resource exhaustion.
  
  ## Parameters
  
  * `error` - The batch error that occurred
  * `batch` - The batch being processed when the error occurred
  * `config` - Processing configuration and context
  
  ## Returns
  
  * `{:ok, recovery_result}` - Error was successfully handled
  * `{:error, escalated_error}` - Error needs escalation
  """
  @spec handle_batch_error(any(), [map()], map()) :: {:ok, any()} | {:error, any()}
  def handle_batch_error(error, batch, config) do
    Logger.debug("🔧 Handling batch processing error")
    
    handler_state = get_handler_state_from_config(config)
    
    # Classify batch error
    operation_context = %{
      operation: :batch_processing,
      batch_size: length(batch),
      error_context: :batch_failure
    }
    
    error_classification = handler_state.error_classifier.classify_sync_error(error, operation_context)
    
    Logger.info("📋 Batch error classified as: #{error_classification.category}/#{error_classification.subcategory}")
    
    # Determine if batch error is recoverable
    case error_classification.retry_strategy.type do
      :no_retry ->
        Logger.error("❌ Batch error is not recoverable")
        {:error, {:unrecoverable_batch_error, error, error_classification}}
        
      _ ->
        # Attempt batch-level recovery
        recovery_options = %{
          error_classification: error_classification,
          batch_context: operation_context,
          recovery_scope: :batch
        }
        
        case handler_state.error_recovery.orchestrate_recovery(error, operation_context, recovery_options) do
          {:ok, recovery_result} ->
            Logger.info("✅ Batch error recovery successful")
            {:ok, recovery_result}
            
          {:error, recovery_error} ->
            Logger.error("❌ Batch error recovery failed: #{inspect(recovery_error)}")
            {:error, {:batch_recovery_failed, error, recovery_error}}
        end
    end
  end

  @doc """
  Get current error handler statistics.
  
  ## Parameters
  
  * `handler_state` - Current handler state
  
  ## Returns
  
  * `error_statistics` - Current error statistics map
  """
  @spec get_error_statistics(handler_state()) :: map()
  def get_error_statistics(handler_state) do
    Map.merge(handler_state.error_statistics, %{
      recovery_rate: calculate_recovery_rate(handler_state.error_statistics),
      circuit_breaker_status: handler_state.circuit_breaker_state.status,
      error_trends: calculate_error_trends(handler_state.error_statistics)
    })
  end

  @doc """
  Reset error handler statistics and circuit breaker.
  
  Useful for clearing error history after resolving systemic issues.
  
  ## Parameters
  
  * `handler_state` - Current handler state
  
  ## Returns
  
  * `updated_handler_state` - Handler state with reset statistics
  """
  @spec reset_error_statistics(handler_state()) :: handler_state()
  def reset_error_statistics(handler_state) do
    Logger.info("🔄 Resetting error handler statistics")
    
    reset_statistics = %{
      total_errors: 0,
      recovered_errors: 0,
      unrecoverable_errors: 0,
      consecutive_errors: 0,
      error_types: %{}
    }
    
    reset_circuit_breaker = initialize_circuit_breaker(handler_state.config.circuit_breaker)
    
    %{
      handler_state | 
      error_statistics: reset_statistics,
      circuit_breaker_state: reset_circuit_breaker
    }
  end

  # Private functions

  defp normalize_error_handler_config(config) do
    %{
      classification_strategy: Map.get(config, :classification_strategy, :intelligent),
      recovery_strategy: Map.get(config, :recovery_strategy, :adaptive),
      circuit_breaker: Map.get(config, :circuit_breaker, %{
        enabled: true,
        failure_threshold: 5,
        timeout_ms: 30_000
      }),
      error_policies: Map.get(config, :error_policies, %{
        continue_on_validation_error: true,
        continue_on_transform_error: true,
        continue_on_processing_error: false,
        max_consecutive_errors: 10
      }),
      integration: Map.get(config, :integration, %{})
    }
  end

  defp initialize_circuit_breaker(circuit_breaker_config) do
    %{
      enabled: Map.get(circuit_breaker_config, :enabled, true),
      status: :closed,
      failure_count: 0,
      failure_threshold: Map.get(circuit_breaker_config, :failure_threshold, 5),
      timeout_ms: Map.get(circuit_breaker_config, :timeout_ms, 30_000),
      last_failure_time: nil,
      half_open_attempts: 0
    }
  end

  defp get_handler_state_from_config(config) do
    # This would typically retrieve or create a handler state from the config
    # For now, create a minimal state
    case initialize(Map.get(config, :error_handling_config, %{})) do
      {:ok, handler_state} -> handler_state
      {:error, _} -> create_default_handler_state()
    end
  end

  defp create_default_handler_state do
    {:ok, state} = initialize(%{})
    state
  end

  defp update_error_statistics(handler_state, error) do
    statistics = handler_state.error_statistics
    error_type = get_error_type(error)
    
    updated_statistics = %{
      statistics |
      total_errors: statistics.total_errors + 1,
      consecutive_errors: statistics.consecutive_errors + 1,
      error_types: Map.update(statistics.error_types, error_type, 1, &(&1 + 1))
    }
    
    %{handler_state | error_statistics: updated_statistics}
  end

  defp get_error_type(error) do
    case error do
      %{__struct__: module} -> module |> Module.split() |> List.last() |> String.to_atom()
      %{type: type} -> type
      {:error, type} -> type
      _ -> :unknown_error
    end
  end

  defp check_circuit_breaker(handler_state) do
    cb_state = handler_state.circuit_breaker_state
    
    if not cb_state.enabled do
      :closed
    else
      case cb_state.status do
        :closed ->
          if cb_state.failure_count >= cb_state.failure_threshold do
            :open
          else
            :closed
          end
          
        :open ->
          if circuit_breaker_timeout_expired?(cb_state) do
            :half_open
          else
            :open
          end
          
        :half_open ->
          :half_open
      end
    end
  end

  defp circuit_breaker_timeout_expired?(cb_state) do
    if cb_state.last_failure_time do
      elapsed = System.monotonic_time(:millisecond) - cb_state.last_failure_time
      elapsed >= cb_state.timeout_ms
    else
      true
    end
  end

  defp handle_error_with_recovery(error, record, config, handler_state) do
    # Classify the error
    operation_context = %{
      operation: :record_processing,
      record: record,
      error_context: :individual_record
    }
    
    error_classification = handler_state.error_classifier.classify_sync_error(error, operation_context)
    
    Logger.debug("📋 Error classified as: #{error_classification.category}/#{error_classification.subcategory}")
    
    # Determine recovery strategy
    case error_classification.retry_strategy.type do
      :no_retry ->
        # Error is not recoverable
        updated_state = record_unrecoverable_error(handler_state, error)
        {:error, {:unrecoverable_error, error, error_classification}}
        
      _ ->
        # Attempt recovery
        recovery_options = %{
          error_classification: error_classification,
          record_context: operation_context,
          recovery_scope: :record
        }
        
        case handler_state.error_recovery.orchestrate_recovery(error, operation_context, recovery_options) do
          {:ok, recovery_result} ->
            # Recovery successful
            updated_state = record_recovered_error(handler_state, error)
            {:ok, recovery_result}
            
          {:error, recovery_error} ->
            # Recovery failed
            updated_state = record_unrecoverable_error(handler_state, error)
            {:error, {:recovery_failed, error, recovery_error}}
        end
    end
  end

  defp handle_error_with_limited_recovery(error, record, config, handler_state) do
    # In half-open circuit breaker state, use limited recovery attempts
    Logger.debug("🔄 Attempting limited error recovery (circuit breaker half-open)")
    
    # Simple retry without full recovery orchestration
    case handler_state.retry_engine.execute_with_retry(:limited_recovery, fn ->
      # Simple retry logic
      {:error, error}  # This would be replaced with actual recovery logic
    end, %{max_attempts: 1, delay_ms: 500}) do
      {:ok, result} ->
        # Success - close circuit breaker
        updated_cb_state = %{handler_state.circuit_breaker_state | status: :closed, failure_count: 0}
        {:ok, result}
        
      {:error, retry_error} ->
        # Failure - open circuit breaker
        updated_cb_state = %{
          handler_state.circuit_breaker_state | 
          status: :open, 
          failure_count: handler_state.circuit_breaker_state.failure_count + 1,
          last_failure_time: System.monotonic_time(:millisecond)
        }
        {:error, {:limited_recovery_failed, error, retry_error}}
    end
  end

  defp record_recovered_error(handler_state, _error) do
    statistics = handler_state.error_statistics
    updated_statistics = %{
      statistics |
      recovered_errors: statistics.recovered_errors + 1,
      consecutive_errors: 0  # Reset consecutive errors on recovery
    }
    
    %{handler_state | error_statistics: updated_statistics}
  end

  defp record_unrecoverable_error(handler_state, _error) do
    statistics = handler_state.error_statistics
    updated_statistics = %{
      statistics |
      unrecoverable_errors: statistics.unrecoverable_errors + 1
    }
    
    # Update circuit breaker failure count
    cb_state = handler_state.circuit_breaker_state
    updated_cb_state = %{
      cb_state |
      failure_count: cb_state.failure_count + 1,
      last_failure_time: System.monotonic_time(:millisecond)
    }
    
    %{
      handler_state |
      error_statistics: updated_statistics,
      circuit_breaker_state: updated_cb_state
    }
  end

  defp calculate_recovery_rate(statistics) do
    total_errors = statistics.total_errors
    
    if total_errors > 0 do
      statistics.recovered_errors / total_errors
    else
      0.0
    end
  end

  defp calculate_error_trends(statistics) do
    # This would calculate error trends over time
    # For now, return basic trend information
    %{
      consecutive_errors: statistics.consecutive_errors,
      most_common_error: find_most_common_error(statistics.error_types),
      error_diversity: map_size(statistics.error_types)
    }
  end

  defp find_most_common_error(error_types) when map_size(error_types) == 0, do: nil
  defp find_most_common_error(error_types) do
    {error_type, _count} = Enum.max_by(error_types, fn {_type, count} -> count end)
    error_type
  end
end