defmodule EhsEnforcement.RetryLogic do
  @moduledoc """
  Comprehensive retry logic system with multiple backoff strategies,
  circuit breaker patterns, rate limiting, and performance monitoring.
  """

  require Logger

  # Retry metrics storage
  @retry_metrics_table :retry_logic_metrics
  @circuit_breakers_table :retry_circuit_breakers
  @rate_limiters_table :retry_rate_limiters

  ## Exponential Backoff Retry

  @doc """
  Retries function with exponential backoff strategy.
  """
  def with_exponential_backoff(fun, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, 1000)
    max_delay_ms = Keyword.get(opts, :max_delay_ms, 30_000)
    operation = Keyword.get(opts, :operation, "unknown")
    context = Keyword.get(opts, :context, %{})

    delays =
      calculate_backoff_delays(
        base_delay_ms: base_delay_ms,
        max_delay_ms: max_delay_ms,
        max_attempts: max_attempts,
        jitter: true
      )

    retry_with_delays(fun, delays, operation, context)
  end

  @doc """
  Calculates exponential backoff delay sequence.
  """
  def calculate_backoff_delays(opts \\ []) do
    base_delay_ms = Keyword.get(opts, :base_delay_ms, 1000)
    max_delay_ms = Keyword.get(opts, :max_delay_ms, 30_000)
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    jitter = Keyword.get(opts, :jitter, false)

    1..max_attempts
    |> Enum.map(fn attempt ->
      delay = min(base_delay_ms * :math.pow(2, attempt - 1), max_delay_ms) |> round()

      if jitter do
        jitter_range = div(delay, 2)
        delay + :rand.uniform(jitter_range) - div(jitter_range, 2)
      else
        delay
      end
    end)
  end

  ## Linear Backoff Retry

  @doc """
  Retries function with linear backoff strategy.
  """
  def with_linear_backoff(fun, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    delay_ms = Keyword.get(opts, :delay_ms, 1000)
    operation = Keyword.get(opts, :operation, "unknown")
    context = Keyword.get(opts, :context, %{})

    delays =
      calculate_linear_delays(
        delay_ms: delay_ms,
        max_attempts: max_attempts
      )

    retry_with_delays(fun, delays, operation, context)
  end

  @doc """
  Calculates linear backoff delay sequence.
  """
  def calculate_linear_delays(opts \\ []) do
    delay_ms = Keyword.get(opts, :delay_ms, 1000)
    max_attempts = Keyword.get(opts, :max_attempts, 3)

    List.duplicate(delay_ms, max_attempts)
  end

  ## Fibonacci Backoff Retry

  @doc """
  Retries function with fibonacci backoff strategy.
  """
  def with_fibonacci_backoff(fun, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 5)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, 1000)
    max_delay_ms = Keyword.get(opts, :max_delay_ms, 30_000)
    operation = Keyword.get(opts, :operation, "unknown")
    context = Keyword.get(opts, :context, %{})

    delays =
      calculate_fibonacci_delays(
        base_delay_ms: base_delay_ms,
        max_delay_ms: max_delay_ms,
        max_attempts: max_attempts
      )

    retry_with_delays(fun, delays, operation, context)
  end

  @doc """
  Calculates fibonacci backoff delay sequence.
  """
  def calculate_fibonacci_delays(opts \\ []) do
    base_delay_ms = Keyword.get(opts, :base_delay_ms, 1000)
    max_delay_ms = Keyword.get(opts, :max_delay_ms, 30_000)
    max_attempts = Keyword.get(opts, :max_attempts, 5)

    fibonacci_sequence(max_attempts)
    |> Enum.map(fn fib_num -> min(fib_num * base_delay_ms, max_delay_ms) end)
  end

  ## Conditional Retry Logic

  @doc """
  Retries function only when condition is met.
  """
  def with_conditional_retry(fun, opts \\ []) do
    retry_when = Keyword.get(opts, :retry_when, fn _ -> true end)
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, 1000)
    operation = Keyword.get(opts, :operation, "unknown")

    attempt_with_condition(fun, retry_when, max_attempts, base_delay_ms, operation, 1)
  end

  @doc """
  Context-aware retry with predefined policies.
  """
  def with_context_aware_retry(fun, opts \\ []) do
    context = Keyword.get(opts, :context, %{})
    retry_policy = Keyword.get(opts, :retry_policy, :default)
    max_attempts = Keyword.get(opts, :max_attempts, 3)

    policy = get_retry_policy(retry_policy)

    case policy.backoff_type do
      :exponential ->
        with_exponential_backoff(fun,
          max_attempts: max_attempts,
          base_delay_ms: policy.base_delay_ms,
          max_delay_ms: policy.max_delay_ms,
          operation: context[:operation],
          context: context
        )

      # :linear backoff not currently supported in policies

      :fibonacci ->
        with_fibonacci_backoff(fun,
          max_attempts: max_attempts,
          base_delay_ms: policy.base_delay_ms,
          max_delay_ms: policy.max_delay_ms,
          operation: context[:operation],
          context: context
        )
    end
  end

  ## Circuit Breaker Pattern

  @doc """
  Initializes circuit breaker with configuration.
  """
  def init_circuit_breaker(circuit_name, opts \\ []) do
    ensure_tables_exist()

    config = %{
      failure_threshold: Keyword.get(opts, :failure_threshold, 5),
      timeout_ms: Keyword.get(opts, :timeout_ms, 60_000),
      state: :closed,
      failure_count: 0,
      last_failure_time: nil,
      total_calls: 0,
      successful_calls: 0,
      failed_calls: 0,
      blocked_calls: 0
    }

    :ets.insert(@circuit_breakers_table, {circuit_name, config})
    :ok
  end

  @doc """
  Executes function with circuit breaker protection.
  """
  def call_with_circuit_breaker(circuit_name, fun) do
    ensure_tables_exist()

    case :ets.lookup(@circuit_breakers_table, circuit_name) do
      [{^circuit_name, config}] ->
        case config.state do
          :closed ->
            execute_with_circuit_breaker(circuit_name, config, fun)

          :open ->
            if should_attempt_reset?(config) do
              # Transition to half-open
              new_config = %{config | state: :half_open}
              :ets.insert(@circuit_breakers_table, {circuit_name, new_config})
              execute_with_circuit_breaker(circuit_name, new_config, fun)
            else
              update_blocked_calls(circuit_name, config)
              {:error, :circuit_open}
            end

          :half_open ->
            execute_with_circuit_breaker(circuit_name, config, fun)
        end

      [] ->
        # Initialize circuit breaker if not found
        init_circuit_breaker(circuit_name)
        call_with_circuit_breaker(circuit_name, fun)
    end
  end

  @doc """
  Resets circuit breaker to closed state.
  """
  def reset_circuit_breaker(circuit_name) do
    ensure_tables_exist()

    case :ets.lookup(@circuit_breakers_table, circuit_name) do
      [{^circuit_name, config}] ->
        reset_config = %{config | state: :closed, failure_count: 0, last_failure_time: nil}
        :ets.insert(@circuit_breakers_table, {circuit_name, reset_config})
        :ok

      [] ->
        :ok
    end
  end

  @doc """
  Gets circuit breaker metrics.
  """
  def get_circuit_breaker_metrics(circuit_name) do
    case :ets.lookup(@circuit_breakers_table, circuit_name) do
      [{^circuit_name, config}] ->
        %{
          state: config.state,
          total_calls: config.total_calls,
          successful_calls: config.successful_calls,
          failed_calls: config.failed_calls,
          blocked_calls: config.blocked_calls,
          failure_rate: calculate_failure_rate(config)
        }

      [] ->
        %{error: :circuit_not_found}
    end
  end

  ## Async Retry Operations

  @doc """
  Performs async retry with callbacks.
  """
  def async_retry(fun, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, 1000)
    on_success = Keyword.get(opts, :on_success, fn _ -> :ok end)
    on_failure = Keyword.get(opts, :on_failure, fn _ -> :ok end)

    Task.async(fn ->
      case with_exponential_backoff(fun, max_attempts: max_attempts, base_delay_ms: base_delay_ms) do
        {:ok, result} -> on_success.(result)
        {:error, reason} -> on_failure.(reason)
      end
    end)
  end

  ## Rate Limited Retry

  @doc """
  Initializes rate limiter.
  """
  def init_rate_limiter(limiter_name, opts \\ []) do
    ensure_tables_exist()

    config = %{
      max_requests: Keyword.get(opts, :max_requests, 10),
      window_ms: Keyword.get(opts, :window_ms, 60_000),
      requests: [],
      created_at: System.monotonic_time(:millisecond)
    }

    :ets.insert(@rate_limiters_table, {limiter_name, config})
    :ok
  end

  @doc """
  Executes retry with rate limiting.
  """
  def with_rate_limited_retry(fun, opts \\ []) do
    rate_limiter = Keyword.get(opts, :rate_limiter)
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, 1000)

    case check_rate_limit(rate_limiter) do
      :ok ->
        with_exponential_backoff(fun, max_attempts: max_attempts, base_delay_ms: base_delay_ms)

      :rate_limited ->
        {:error, :rate_limited}
    end
  end

  @doc """
  Cleans up rate limiter.
  """
  def cleanup_rate_limiter(limiter_name) do
    ensure_tables_exist()
    :ets.delete(@rate_limiters_table, limiter_name)
    :ok
  end

  ## Retry Policies

  @doc """
  Gets predefined retry policy configuration.
  """
  def get_retry_policy(:api_operations) do
    %{
      max_attempts: 3,
      backoff_type: :exponential,
      base_delay_ms: 1000,
      max_delay_ms: 30_000,
      jitter: true,
      circuit_breaker: false
    }
  end

  def get_retry_policy(:database_operations) do
    %{
      max_attempts: 5,
      backoff_type: :exponential,
      base_delay_ms: 500,
      max_delay_ms: 10_000,
      jitter: false,
      circuit_breaker: true
    }
  end

  def get_retry_policy(:critical_operations) do
    %{
      max_attempts: 10,
      backoff_type: :fibonacci,
      base_delay_ms: 100,
      max_delay_ms: 60_000,
      jitter: true,
      circuit_breaker: true
    }
  end

  def get_retry_policy(_) do
    %{
      max_attempts: 3,
      backoff_type: :exponential,
      base_delay_ms: 1000,
      max_delay_ms: 10_000,
      jitter: false,
      circuit_breaker: false
    }
  end

  @doc """
  Executes function with custom retry policy.
  """
  def with_custom_policy(fun, policy) do
    case policy.backoff_type do
      :exponential ->
        with_exponential_backoff(fun,
          max_attempts: policy.max_attempts,
          base_delay_ms: policy.base_delay_ms,
          max_delay_ms: policy.max_delay_ms
        )

      :linear ->
        with_linear_backoff(fun,
          max_attempts: policy.max_attempts,
          delay_ms: policy.base_delay_ms
        )

      :fibonacci ->
        with_fibonacci_backoff(fun,
          max_attempts: policy.max_attempts,
          base_delay_ms: policy.base_delay_ms,
          max_delay_ms: policy.max_delay_ms
        )
    end
  end

  ## Retry Monitoring

  @doc """
  Resets retry metrics.
  """
  def reset_metrics do
    ensure_tables_exist()
    :ets.delete_all_objects(@retry_metrics_table)
    :ok
  end

  @doc """
  Gets comprehensive retry metrics.
  """
  def get_retry_metrics do
    ensure_tables_exist()

    metrics_data = :ets.tab2list(@retry_metrics_table)

    total_operations = length(metrics_data)
    successful_operations = Enum.count(metrics_data, fn {_, data} -> data.outcome == :success end)
    failed_operations = total_operations - successful_operations

    total_attempts = Enum.sum(Enum.map(metrics_data, fn {_, data} -> data.attempts end))

    by_operation =
      metrics_data
      |> Enum.group_by(fn {_, data} -> data.operation end)
      |> Enum.into(%{}, fn {operation, operation_data} ->
        operation_total = length(operation_data)

        operation_successful =
          Enum.count(operation_data, fn {_, data} -> data.outcome == :success end)

        {operation, %{total: operation_total, successful: operation_successful}}
      end)

    %{
      total_operations: total_operations,
      successful_operations: successful_operations,
      failed_operations: failed_operations,
      total_attempts: total_attempts,
      by_operation: by_operation
    }
  end

  @doc """
  Generates retry performance report.
  """
  def generate_performance_report do
    metrics = get_retry_metrics()

    overall_success_rate =
      if metrics.total_operations > 0 do
        metrics.successful_operations / metrics.total_operations
      else
        0.0
      end

    average_attempts =
      if metrics.total_operations > 0 do
        metrics.total_attempts / metrics.total_operations
      else
        0.0
      end

    most_retried =
      metrics.by_operation
      |> Enum.sort_by(fn {_, data} -> data.total end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn {operation, _} -> operation end)

    %{
      total_operations: metrics.total_operations,
      overall_success_rate: overall_success_rate,
      average_attempts_per_operation: average_attempts,
      most_retried_operations: most_retried,
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  ## Private Functions

  defp retry_with_delays(fun, delays, operation, _context) do
    record_operation_start(operation)

    case attempt_with_delays(fun, delays, operation, 1) do
      {:ok, result} ->
        record_operation_outcome(operation, :success, length(delays))
        {:ok, result}

      {:error, _reason} ->
        record_operation_outcome(operation, :failure, length(delays))
        {:error, :max_attempts_exceeded}
    end
  end

  defp attempt_with_delays(_fun, [], _operation, _attempt), do: {:error, :max_attempts_exceeded}

  defp attempt_with_delays(fun, [delay | remaining_delays], operation, attempt) do
    log_retry_attempt(operation, attempt)

    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, _reason} when remaining_delays == [] ->
        {:error, :max_attempts_exceeded}

      {:error, _reason} ->
        :timer.sleep(delay)
        attempt_with_delays(fun, remaining_delays, operation, attempt + 1)
    end
  end

  defp attempt_with_condition(fun, retry_when, max_attempts, base_delay_ms, operation, attempt)
       when attempt <= max_attempts do
    log_retry_attempt(operation, attempt)

    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, _reason} = _error when attempt == max_attempts ->
        {:error, :max_attempts_exceeded}

      {:error, _reason} = error ->
        if retry_when.(error) do
          :timer.sleep(base_delay_ms)

          attempt_with_condition(
            fun,
            retry_when,
            max_attempts,
            base_delay_ms,
            operation,
            attempt + 1
          )
        else
          error
        end
    end
  end

  defp attempt_with_condition(
         _fun,
         _retry_when,
         _max_attempts,
         _base_delay_ms,
         _operation,
         _attempt
       ) do
    {:error, :max_attempts_exceeded}
  end

  defp fibonacci_sequence(n) when n <= 0, do: []
  defp fibonacci_sequence(1), do: [1]
  defp fibonacci_sequence(2), do: [1, 1]

  defp fibonacci_sequence(n) do
    fib_list = fibonacci_sequence(n - 1)
    last_two = Enum.take(fib_list, -2)
    fib_list ++ [Enum.sum(last_two)]
  end

  defp execute_with_circuit_breaker(circuit_name, config, fun) do
    updated_config = %{config | total_calls: config.total_calls + 1}

    case fun.() do
      {:ok, result} ->
        success_config = %{
          updated_config
          | successful_calls: config.successful_calls + 1,
            failure_count: 0,
            state: :closed
        }

        :ets.insert(@circuit_breakers_table, {circuit_name, success_config})
        {:ok, result}

      {:error, _reason} = error ->
        new_failure_count = config.failure_count + 1

        new_state =
          if new_failure_count >= config.failure_threshold, do: :open, else: config.state

        failure_config = %{
          updated_config
          | failed_calls: config.failed_calls + 1,
            failure_count: new_failure_count,
            last_failure_time: System.monotonic_time(:millisecond),
            state: new_state
        }

        :ets.insert(@circuit_breakers_table, {circuit_name, failure_config})
        error
    end
  end

  defp should_attempt_reset?(config) do
    current_time = System.monotonic_time(:millisecond)

    config.last_failure_time != nil and
      current_time - config.last_failure_time > config.timeout_ms
  end

  defp update_blocked_calls(circuit_name, config) do
    blocked_config = %{config | blocked_calls: config.blocked_calls + 1}
    :ets.insert(@circuit_breakers_table, {circuit_name, blocked_config})
  end

  defp calculate_failure_rate(config) do
    if config.total_calls > 0 do
      config.failed_calls / config.total_calls
    else
      0.0
    end
  end

  defp check_rate_limit(limiter_name) do
    case :ets.lookup(@rate_limiters_table, limiter_name) do
      [{^limiter_name, config}] ->
        current_time = System.monotonic_time(:millisecond)
        window_start = current_time - config.window_ms

        # Filter requests within current window
        recent_requests =
          Enum.filter(config.requests, fn request_time ->
            request_time > window_start
          end)

        if length(recent_requests) < config.max_requests do
          # Add current request to the list
          updated_requests = [current_time | recent_requests]
          updated_config = %{config | requests: updated_requests}
          :ets.insert(@rate_limiters_table, {limiter_name, updated_config})
          :ok
        else
          :rate_limited
        end

      [] ->
        # No rate limiter configured
        :ok
    end
  end

  defp record_operation_start(_operation) do
    # Record operation start for metrics
    :ok
  end

  defp record_operation_outcome(operation, outcome, attempts) do
    ensure_tables_exist()

    operation_data = %{
      operation: operation,
      outcome: outcome,
      attempts: attempts,
      timestamp: DateTime.utc_now()
    }

    operation_id = :crypto.strong_rand_bytes(8) |> Base.encode16() |> String.downcase()
    :ets.insert(@retry_metrics_table, {operation_id, operation_data})
  end

  defp log_retry_attempt(operation, attempt) do
    Logger.info("Retry attempt #{attempt} for operation: #{operation}",
      operation: operation,
      attempt: attempt,
      retry_event: true
    )
  end

  defp ensure_tables_exist do
    unless :ets.whereis(@retry_metrics_table) != :undefined do
      :ets.new(@retry_metrics_table, [:named_table, :public, :set])
    end

    unless :ets.whereis(@circuit_breakers_table) != :undefined do
      :ets.new(@circuit_breakers_table, [:named_table, :public, :set])
    end

    unless :ets.whereis(@rate_limiters_table) != :undefined do
      :ets.new(@rate_limiters_table, [:named_table, :public, :set])
    end
  end
end
