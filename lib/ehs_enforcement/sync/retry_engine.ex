defmodule EhsEnforcement.Sync.RetryEngine do
  @moduledoc """
  Advanced retry engine with configurable retry policies and exponential backoff.
  
  This module provides intelligent retry mechanisms for sync operations,
  including adaptive backoff strategies, circuit breaker patterns,
  and comprehensive retry analytics.
  
  Package-ready architecture for future extraction as `airtable_sync_phoenix`.
  """
  
  alias EhsEnforcement.Sync.{ErrorClassifier, EventBroadcaster}
  require Logger

  @doc """
  Execute a function with intelligent retry logic.
  
  This is the main entry point for retry operations. It uses error classification
  to determine the appropriate retry strategy and executes the function with
  comprehensive error handling and monitoring.
  
  ## Parameters
  
  * `operation_name` - Atom describing the operation for logging and monitoring
  * `function` - Function to execute (should return {:ok, result} or {:error, reason})
  * `context` - Map containing operation context and configuration
  * `opts` - Additional options for retry behavior
  
  ## Context Options
  
  * `:retry_policy` - Override default retry policy
  * `:max_attempts` - Maximum number of retry attempts
  * `:circuit_breaker` - Enable circuit breaker protection
  * `:session_id` - Session ID for event broadcasting
  * `:resource_type` - Resource type for classification
  * `:batch_info` - Information about current batch being processed
  
  ## Examples
  
      # Basic retry with default policy
      RetryEngine.execute_with_retry(:import_case, fn ->
        RecordProcessor.process_case_record(record, opts)
      end, %{resource_type: :case})
      
      # Custom retry policy
      RetryEngine.execute_with_retry(:api_call, fn ->
        AirtableClient.fetch_records()
      end, %{
        retry_policy: %{
          type: :exponential_backoff,
          max_attempts: 5,
          base_delay_ms: 2000
        }
      })
      
      # With circuit breaker protection
      RetryEngine.execute_with_retry(:database_operation, fn ->
        DatabaseModule.complex_query()
      end, %{circuit_breaker: true, operation: :complex_query})
  """
  def execute_with_retry(operation_name, function, context \\ %{}, opts \\ []) do
    session_id = Map.get(context, :session_id)
    resource_type = Map.get(context, :resource_type, :unknown)
    
    # Check circuit breaker status if enabled
    if Map.get(context, :circuit_breaker, false) do
      case check_circuit_breaker(operation_name, context) do
        :open ->
          Logger.warn("Circuit breaker OPEN for #{operation_name} - failing fast")
          return_circuit_breaker_failure(operation_name, session_id)
          
        :half_open ->
          Logger.info("Circuit breaker HALF-OPEN for #{operation_name} - attempting test call")
          attempt_execution_with_circuit_breaker(operation_name, function, context, opts)
          
        :closed ->
          Logger.debug("Circuit breaker CLOSED for #{operation_name} - proceeding normally")
          do_execute_with_retry(operation_name, function, context, opts, 1)
      end
    else
      do_execute_with_retry(operation_name, function, context, opts, 1)
    end
  end
  
  @doc """
  Execute a batch of operations with coordinated retry logic.
  
  This function executes multiple operations with intelligent coordination,
  including batch-level circuit breaking and adaptive retry strategies
  based on batch success rates.
  """
  def execute_batch_with_retry(operation_name, operations, context \\ %{}, opts \\ []) do
    batch_size = length(operations)
    session_id = Map.get(context, :session_id)
    
    Logger.info("🔄 Starting batch execution: #{operation_name} (#{batch_size} operations)")
    
    # Broadcast batch start event
    if session_id do
      EventBroadcaster.broadcast_session_event(session_id, :batch_retry_started, %{
        operation_name: operation_name,
        batch_size: batch_size,
        retry_policy: determine_retry_policy(context)
      })
    end
    
    # Execute operations with individual retry logic
    results = operations
    |> Enum.with_index()
    |> Enum.map(fn {operation_func, index} ->
      operation_context = Map.merge(context, %{
        batch_index: index,
        batch_size: batch_size
      })
      
      case execute_with_retry(operation_name, operation_func, operation_context, opts) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> {:error, reason}
      end
    end)
    
    # Analyze batch results
    success_count = Enum.count(results, fn {status, _} -> status == :ok end)
    failure_count = Enum.count(results, fn {status, _} -> status == :error end)
    success_rate = success_count / batch_size
    
    batch_result = %{
      total_operations: batch_size,
      successful: success_count,
      failed: failure_count,
      success_rate: success_rate,
      results: results
    }
    
    # Update circuit breaker based on batch success rate
    if Map.get(context, :circuit_breaker, false) do
      update_circuit_breaker_batch_result(operation_name, success_rate, context)
    end
    
    # Broadcast batch completion event
    if session_id do
      EventBroadcaster.broadcast_session_event(session_id, :batch_retry_completed, %{
        operation_name: operation_name,
        batch_result: batch_result
      })
    end
    
    Logger.info("✅ Batch execution completed: #{success_count}/#{batch_size} successful (#{Float.round(success_rate * 100, 2)}%)")
    
    {:ok, batch_result}
  end
  
  @doc """
  Get comprehensive retry analytics for monitoring and optimization.
  
  Returns detailed analytics about retry patterns, success rates,
  and circuit breaker status across all operations.
  """
  def get_retry_analytics(time_window_hours \\ 24) do
    %{
      time_window_hours: time_window_hours,
      retry_statistics: get_retry_statistics(time_window_hours),
      circuit_breaker_status: get_all_circuit_breaker_status(),
      performance_metrics: get_retry_performance_metrics(time_window_hours),
      recommendations: generate_retry_recommendations()
    }
  end
  
  @doc """
  Reset retry state for a specific operation or all operations.
  
  Useful for clearing circuit breaker state and retry counters
  after resolving underlying issues.
  """
  def reset_retry_state(operation_name \\ :all) do
    case operation_name do
      :all ->
        clear_all_retry_state()
        Logger.info("🔄 Reset retry state for all operations")
        
      operation ->
        clear_operation_retry_state(operation)
        Logger.info("🔄 Reset retry state for operation: #{operation}")
    end
    
    :ok
  end
  
  # Private functions for retry execution
  
  defp do_execute_with_retry(operation_name, function, context, opts, attempt_number) do
    max_attempts = get_max_attempts(context)
    session_id = Map.get(context, :session_id)
    
    if attempt_number > max_attempts do
      Logger.error("❌ #{operation_name} failed after #{max_attempts} attempts")
      
      if session_id do
        EventBroadcaster.broadcast_session_event(session_id, :retry_exhausted, %{
          operation_name: operation_name,
          max_attempts: max_attempts,
          final_attempt: attempt_number - 1
        })
      end
      
      {:error, {:retry_exhausted, max_attempts}}
    else
      # Log attempt
      if attempt_number > 1 do
        Logger.info("🔄 #{operation_name} attempt #{attempt_number}/#{max_attempts}")
      end
      
      # Execute function
      start_time = System.monotonic_time(:millisecond)
      
      case function.() do
        {:ok, result} ->
          execution_time = System.monotonic_time(:millisecond) - start_time
          
          # Record successful execution
          record_retry_success(operation_name, attempt_number, execution_time, context)
          
          if attempt_number > 1 do
            Logger.info("✅ #{operation_name} succeeded on attempt #{attempt_number}")
            
            if session_id do
              EventBroadcaster.broadcast_session_event(session_id, :retry_succeeded, %{
                operation_name: operation_name,
                attempt_number: attempt_number,
                execution_time_ms: execution_time
              })
            end
          end
          
          {:ok, result}
          
        {:error, error} ->
          execution_time = System.monotonic_time(:millisecond) - start_time
          
          # Classify error to determine retry strategy
          context_with_operation = Map.put(context, :operation, operation_name)
          error_classification = ErrorClassifier.classify_sync_error(error, context_with_operation)
          
          # Record failed execution
          record_retry_failure(operation_name, attempt_number, execution_time, error_classification, context)
          
          if error_classification.retry_eligible do
            # Use context retry policy if provided, otherwise use ErrorClassifier's suggestion
            retry_strategy = case Map.get(context, :retry_policy) do
              nil -> error_classification.retry_strategy
              custom_policy -> custom_policy
            end
            
            # Calculate delay before next attempt
            delay_ms = calculate_retry_delay(retry_strategy, attempt_number, context)
            
            Logger.warn("⚠️ #{operation_name} failed on attempt #{attempt_number}, retrying in #{delay_ms}ms: #{inspect(error)}")
            
            if session_id do
              EventBroadcaster.broadcast_session_event(session_id, :retry_scheduled, %{
                operation_name: operation_name,
                attempt_number: attempt_number,
                next_attempt_in_ms: delay_ms,
                error_category: error_classification.category
              })
            end
            
            # Wait before retry
            if delay_ms > 0 do
              :timer.sleep(delay_ms)
            end
            
            # Recursive retry
            do_execute_with_retry(operation_name, function, context, opts, attempt_number + 1)
          else
            Logger.error("❌ #{operation_name} failed with non-retryable error: #{inspect(error)}")
            
            if session_id do
              EventBroadcaster.broadcast_session_event(session_id, :retry_aborted, %{
                operation_name: operation_name,
                attempt_number: attempt_number,
                reason: "Non-retryable error",
                error_category: error_classification.category
              })
            end
            
            {:error, error}
          end
      end
    end
  end
  
  # Retry policy determination
  
  defp determine_retry_policy(context) do
    case Map.get(context, :retry_policy) do
      nil ->
        # Default policy based on operation type
        default_retry_policy(Map.get(context, :operation, :unknown))
        
      custom_policy when is_map(custom_policy) ->
        custom_policy
        
      policy_name when is_atom(policy_name) ->
        predefined_retry_policy(policy_name)
    end
  end
  
  defp default_retry_policy(operation) do
    case operation do
      operation when operation in [:import_cases, :import_notices] ->
        %{
          type: :exponential_backoff,
          base_delay_ms: 1000,
          max_delay_ms: 30_000,
          multiplier: 2.0,
          max_attempts: 5,
          jitter: true
        }
      
      operation when operation in [:create_case, :create_notice, :update_case, :update_notice] ->
        %{
          type: :linear_backoff,
          base_delay_ms: 500,
          max_delay_ms: 10_000,
          increment_ms: 1000,
          max_attempts: 3,
          jitter: false
        }
      
      _ ->
        %{
          type: :fixed_delay,
          delay_ms: 2000,
          max_attempts: 3,
          jitter: false
        }
    end
  end
  
  defp predefined_retry_policy(policy_name) do
    case policy_name do
      :aggressive ->
        %{
          type: :exponential_backoff,
          base_delay_ms: 500,
          max_delay_ms: 60_000,
          multiplier: 2.5,
          max_attempts: 10,
          jitter: true
        }
      
      :conservative ->
        %{
          type: :linear_backoff,
          base_delay_ms: 5000,
          max_delay_ms: 30_000,
          increment_ms: 5000,
          max_attempts: 3,
          jitter: false
        }
      
      :fast ->
        %{
          type: :fixed_delay,
          delay_ms: 1000,
          max_attempts: 5,
          jitter: true
        }
      
      _ ->
        default_retry_policy(:unknown)
    end
  end
  
  defp get_max_attempts(context) do
    retry_policy = determine_retry_policy(context)
    Map.get(retry_policy, :max_attempts, 3)
  end
  
  defp calculate_retry_delay(retry_strategy, attempt_number, context) do
    base_delay = case retry_strategy do
      %{type: :exponential_backoff, base_delay_ms: base, multiplier: multiplier} ->
        base * :math.pow(multiplier, attempt_number - 1)
      
      %{type: :linear_backoff, base_delay_ms: base, increment_ms: increment} ->
        base + (increment * (attempt_number - 1))
      
      %{type: :fixed_delay, delay_ms: delay} ->
        delay
      
      _ ->
        1000  # Default 1 second
    end
    
    # Apply maximum delay limit
    max_delay = Map.get(retry_strategy, :max_delay_ms, 30_000)
    capped_delay = min(base_delay, max_delay)
    
    # Apply jitter if enabled
    final_delay = if Map.get(retry_strategy, :jitter, false) do
      jitter_factor = :rand.uniform() * 0.1  # ±10% jitter
      jitter_multiplier = 1.0 + (jitter_factor - 0.05)
      round(capped_delay * jitter_multiplier)
    else
      round(capped_delay)
    end
    
    max(final_delay, 0)
  end
  
  # Circuit breaker implementation
  
  defp check_circuit_breaker(operation_name, context) do
    circuit_breaker_state = get_circuit_breaker_state(operation_name)
    
    case circuit_breaker_state do
      %{status: :open, opened_at: opened_at} ->
        cooldown_period_ms = Map.get(context, :circuit_breaker_cooldown_ms, 60_000)
        
        if DateTime.diff(DateTime.utc_now(), opened_at, :millisecond) > cooldown_period_ms do
          # Transition to half-open
          set_circuit_breaker_state(operation_name, :half_open)
          :half_open
        else
          :open
        end
      
      %{status: status} ->
        status
      
      nil ->
        # Initialize circuit breaker
        set_circuit_breaker_state(operation_name, :closed)
        :closed
    end
  end
  
  defp attempt_execution_with_circuit_breaker(operation_name, function, context, opts) do
    case do_execute_with_retry(operation_name, function, context, opts, 1) do
      {:ok, result} ->
        # Success - close circuit breaker
        set_circuit_breaker_state(operation_name, :closed)
        Logger.info("✅ Circuit breaker for #{operation_name} closed after successful test")
        {:ok, result}
      
      {:error, error} ->
        # Failure - reopen circuit breaker
        set_circuit_breaker_state(operation_name, :open)
        Logger.warn("❌ Circuit breaker for #{operation_name} reopened after failed test")
        {:error, error}
    end
  end
  
  defp return_circuit_breaker_failure(operation_name, session_id) do
    if session_id do
      EventBroadcaster.broadcast_session_event(session_id, :circuit_breaker_open, %{
        operation_name: operation_name,
        reason: "Circuit breaker is open - failing fast"
      })
    end
    
    {:error, {:circuit_breaker_open, operation_name}}
  end
  
  defp update_circuit_breaker_batch_result(operation_name, success_rate, context) do
    failure_threshold = Map.get(context, :circuit_breaker_failure_threshold, 0.5)
    
    if success_rate < failure_threshold do
      set_circuit_breaker_state(operation_name, :open)
      Logger.warn("🔴 Circuit breaker opened for #{operation_name} due to low batch success rate: #{Float.round(success_rate * 100, 2)}%")
    end
  end
  
  # State management (using ETS for in-memory state)
  
  defp get_circuit_breaker_state(operation_name) do
    case :ets.lookup(:retry_engine_circuit_breakers, operation_name) do
      [{^operation_name, state}] -> state
      [] -> nil
    end
  end
  
  defp set_circuit_breaker_state(operation_name, status) do
    ensure_ets_tables()
    
    state = %{
      status: status,
      updated_at: DateTime.utc_now(),
      opened_at: if(status == :open, do: DateTime.utc_now(), else: nil)
    }
    
    :ets.insert(:retry_engine_circuit_breakers, {operation_name, state})
  end
  
  defp record_retry_success(operation_name, attempt_number, execution_time_ms, context) do
    ensure_ets_tables()
    
    record = %{
      operation_name: operation_name,
      attempt_number: attempt_number,
      execution_time_ms: execution_time_ms,
      result: :success,
      timestamp: DateTime.utc_now(),
      context: context
    }
    
    record_id = generate_record_id()
    :ets.insert(:retry_engine_metrics, {record_id, record})
  end
  
  defp record_retry_failure(operation_name, attempt_number, execution_time_ms, error_classification, context) do
    ensure_ets_tables()
    
    record = %{
      operation_name: operation_name,
      attempt_number: attempt_number,
      execution_time_ms: execution_time_ms,
      result: :failure,
      error_category: error_classification.category,
      error_severity: error_classification.severity,
      retry_eligible: error_classification.retry_eligible,
      timestamp: DateTime.utc_now(),
      context: context
    }
    
    record_id = generate_record_id()
    :ets.insert(:retry_engine_metrics, {record_id, record})
  end
  
  # Analytics and monitoring functions
  
  defp get_retry_statistics(time_window_hours) do
    ensure_ets_tables()
    
    cutoff_time = DateTime.add(DateTime.utc_now(), -time_window_hours, :hour)
    
    all_records = :ets.tab2list(:retry_engine_metrics)
    recent_records = Enum.filter(all_records, fn {_id, record} ->
      DateTime.compare(record.timestamp, cutoff_time) != :lt
    end)
    
    total_operations = length(recent_records)
    successful_operations = Enum.count(recent_records, fn {_id, record} -> record.result == :success end)
    failed_operations = total_operations - successful_operations
    
    retry_attempts = Enum.filter(recent_records, fn {_id, record} -> record.attempt_number > 1 end)
    operations_requiring_retry = Enum.uniq_by(retry_attempts, fn {_id, record} -> 
      {record.operation_name, record.context[:batch_index]} 
    end) |> length()
    
    %{
      total_operations: total_operations,
      successful_operations: successful_operations,
      failed_operations: failed_operations,
      success_rate: if(total_operations > 0, do: successful_operations / total_operations, else: 0.0),
      operations_requiring_retry: operations_requiring_retry,
      average_attempts: calculate_average_attempts(recent_records),
      by_operation: group_statistics_by_operation(recent_records),
      by_error_category: group_statistics_by_error_category(recent_records)
    }
  end
  
  defp get_all_circuit_breaker_status do
    ensure_ets_tables()
    
    :ets.tab2list(:retry_engine_circuit_breakers)
    |> Enum.map(fn {operation_name, state} -> {operation_name, state} end)
    |> Enum.into(%{})
  end
  
  defp get_retry_performance_metrics(time_window_hours) do
    ensure_ets_tables()
    
    cutoff_time = DateTime.add(DateTime.utc_now(), -time_window_hours, :hour)
    
    all_records = :ets.tab2list(:retry_engine_metrics)
    recent_records = Enum.filter(all_records, fn {_id, record} ->
      DateTime.compare(record.timestamp, cutoff_time) != :lt
    end)
    
    execution_times = Enum.map(recent_records, fn {_id, record} -> record.execution_time_ms end)
    
    %{
      average_execution_time_ms: if(length(execution_times) > 0, do: Enum.sum(execution_times) / length(execution_times), else: 0),
      median_execution_time_ms: calculate_median(execution_times),
      max_execution_time_ms: if(length(execution_times) > 0, do: Enum.max(execution_times), else: 0),
      min_execution_time_ms: if(length(execution_times) > 0, do: Enum.min(execution_times), else: 0)
    }
  end
  
  defp generate_retry_recommendations do
    statistics = get_retry_statistics(24)  # Last 24 hours
    circuit_breaker_status = get_all_circuit_breaker_status()
    
    recommendations = []
    
    # High failure rate recommendation
    recommendations = if statistics.success_rate < 0.8 do
      ["Consider reviewing and optimizing operations with high failure rates" | recommendations]
    else
      recommendations
    end
    
    # High retry rate recommendation  
    retry_rate = if statistics.total_operations > 0 do
      statistics.operations_requiring_retry / statistics.total_operations
    else
      0.0
    end
    
    recommendations = if retry_rate > 0.3 do
      ["High retry rate detected - investigate underlying causes of failures" | recommendations]
    else
      recommendations
    end
    
    # Circuit breaker recommendations
    open_circuit_breakers = Enum.filter(circuit_breaker_status, fn {_op, state} -> state.status == :open end)
    
    recommendations = if length(open_circuit_breakers) > 0 do
      ["Circuit breakers are open for some operations - check system health" | recommendations]
    else
      recommendations
    end
    
    if length(recommendations) == 0 do
      ["Retry system is operating normally"]
    else
      recommendations
    end
  end
  
  # Utility functions
  
  defp ensure_ets_tables do
    unless :ets.whereis(:retry_engine_circuit_breakers) != :undefined do
      :ets.new(:retry_engine_circuit_breakers, [:named_table, :public, :set])
    end
    
    unless :ets.whereis(:retry_engine_metrics) != :undefined do
      :ets.new(:retry_engine_metrics, [:named_table, :public, :set])
    end
  end
  
  defp generate_record_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
  
  defp clear_all_retry_state do
    ensure_ets_tables()
    :ets.delete_all_objects(:retry_engine_circuit_breakers)
    :ets.delete_all_objects(:retry_engine_metrics)
  end
  
  defp clear_operation_retry_state(operation_name) do
    ensure_ets_tables()
    :ets.delete(:retry_engine_circuit_breakers, operation_name)
    
    # Remove metrics for this operation (more complex with ETS bag)
    all_metrics = :ets.tab2list(:retry_engine_metrics)
    operation_metrics = Enum.filter(all_metrics, fn {_id, record} -> 
      record.operation_name == operation_name 
    end)
    
    Enum.each(operation_metrics, fn {id, _record} ->
      :ets.delete(:retry_engine_metrics, id)
    end)
  end
  
  defp calculate_average_attempts(records) do
    if length(records) > 0 do
      total_attempts = Enum.sum(Enum.map(records, fn {_id, record} -> record.attempt_number end))
      total_attempts / length(records)
    else
      0.0
    end
  end
  
  defp group_statistics_by_operation(records) do
    records
    |> Enum.group_by(fn {_id, record} -> record.operation_name end)
    |> Enum.map(fn {operation, operation_records} ->
      successful = Enum.count(operation_records, fn {_id, record} -> record.result == :success end)
      total = length(operation_records)
      
      {operation, %{
        total: total,
        successful: successful,
        failed: total - successful,
        success_rate: if(total > 0, do: successful / total, else: 0.0)
      }}
    end)
    |> Enum.into(%{})
  end
  
  defp group_statistics_by_error_category(records) do
    failed_records = Enum.filter(records, fn {_id, record} -> record.result == :failure end)
    
    failed_records
    |> Enum.group_by(fn {_id, record} -> Map.get(record, :error_category, :unknown) end)
    |> Enum.map(fn {category, category_records} ->
      {category, %{
        count: length(category_records),
        average_attempts: calculate_average_attempts(category_records)
      }}
    end)
    |> Enum.into(%{})
  end
  
  defp calculate_median([]), do: 0
  defp calculate_median(list) do
    sorted = Enum.sort(list)
    length = length(sorted)
    
    if rem(length, 2) == 0 do
      # Even number of elements
      middle1 = Enum.at(sorted, div(length, 2) - 1)
      middle2 = Enum.at(sorted, div(length, 2))
      (middle1 + middle2) / 2
    else
      # Odd number of elements
      Enum.at(sorted, div(length, 2))
    end
  end
end