defmodule EhsEnforcement.Telemetry do
  @moduledoc """
  Telemetry event handling and monitoring for the EHS Enforcement application.

  Provides comprehensive monitoring, metrics collection, and performance tracking
  for all application operations including sync, database, and user interactions.
  """

  require Logger
  alias EhsEnforcement.Logger, as: EhsLogger

  # List of telemetry events this module handles
  @events [
    [:sync, :start],
    [:sync, :stop],
    [:sync, :exception],
    [:repo, :query],
    [:phoenix, :live_view, :mount, :start],
    [:phoenix, :live_view, :mount, :exception],
    [:phoenix, :endpoint, :stop]
  ]

  # Operation tracking storage
  @operations_table :telemetry_operations
  @metrics_table :telemetry_metrics

  ## Public API

  @doc """
  Returns list of telemetry events this module handles.
  """
  def events, do: @events

  @doc """
  Attaches telemetry event handlers.
  """
  def attach_handlers do
    :telemetry.attach_many(
      "ehs-enforcement-telemetry",
      @events,
      &__MODULE__.handle_event/4,
      %{}
    )
  end

  @doc """
  Detaches telemetry event handlers.
  """
  def detach_handlers do
    :telemetry.detach("ehs-enforcement-telemetry")
  end

  ## Event Handlers

  @doc """
  Main telemetry event handler that routes events to specific handlers.
  """
  def handle_event([:sync, :start], measurements, metadata, _config) do
    EhsLogger.info("Starting sync for #{metadata.agency}", %{
      operation: metadata[:operation],
      agency: metadata.agency,
      system_time: measurements[:system_time]
    })
  end

  def handle_event([:sync, :stop], measurements, metadata, _config) do
    duration = System.convert_time_unit(measurements.duration, :native, :millisecond)

    EhsLogger.info("Sync completed for #{metadata.agency} in #{duration}ms", %{
      operation: metadata[:operation],
      agency: metadata.agency,
      duration_ms: duration,
      records_processed: metadata[:records_processed]
    })
  end

  def handle_event([:sync, :exception], _measurements, metadata, _config) do
    _error_info = inspect(metadata.error)

    EhsLogger.error(
      "Sync failed for #{metadata.agency}",
      metadata.error,
      metadata[:stacktrace] || [],
      %{
        operation: metadata[:operation],
        agency: metadata.agency
      }
    )
  end

  def handle_event([:repo, :query], measurements, metadata, _config) do
    duration = System.convert_time_unit(measurements.duration, :native, :millisecond)

    if duration > 1000 do
      EhsLogger.warn("Slow database query detected", %{
        duration_ms: duration,
        query: metadata.query,
        params: length(metadata[:params] || [])
      })
    end

    # Always log query completion
    EhsLogger.info("Database query completed", %{
      duration_ms: duration,
      query: metadata.query
    })
  end

  def handle_event([:phoenix, :live_view, :mount, :start], measurements, metadata, _config) do
    view_name =
      metadata.socket.view |> to_string() |> String.split(".") |> Enum.take(-2) |> Enum.join(".")

    EhsLogger.info("LiveView mount started", %{
      view: view_name,
      user_id: metadata.session[:user_id],
      system_time: measurements[:system_time]
    })
  end

  def handle_event([:phoenix, :live_view, :mount, :exception], _measurements, metadata, _config) do
    view_name =
      metadata.socket.view |> to_string() |> String.split(".") |> Enum.take(-2) |> Enum.join(".")

    EhsLogger.error("LiveView mount failed", metadata.reason, metadata[:stacktrace] || [], %{
      view: view_name,
      kind: metadata.kind
    })
  end

  def handle_event([:phoenix, :endpoint, :stop], measurements, metadata, _config) do
    duration = System.convert_time_unit(measurements.duration, :native, :millisecond)

    log_metadata = %{
      method: metadata.method,
      path: metadata.path,
      status: metadata.status,
      duration_ms: duration,
      user_agent: metadata[:user_agent]
    }

    if metadata.status >= 500 do
      EhsLogger.warn("HTTP request failed", log_metadata)
    else
      EhsLogger.info("HTTP request completed", log_metadata)
    end
  end

  ## Error Categorization

  @doc """
  Categorizes errors by type for consistent handling.
  """
  def categorize_error(%Req.TransportError{}), do: :api_error
  def categorize_error(%Postgrex.Error{}), do: :database_error
  def categorize_error(%Ash.Error.Invalid{}), do: :validation_error
  def categorize_error(%RuntimeError{}), do: :application_error
  def categorize_error(_), do: :unknown_error

  @doc """
  Extracts comprehensive error context for logging and monitoring.
  """
  def extract_error_context(error, context) do
    error_type = categorize_error(error)
    error_reason = extract_error_reason(error)
    error_id = generate_error_id()

    %{
      error_type: error_type,
      error_reason: error_reason,
      error_id: error_id,
      agency: context[:agency],
      operation: context[:operation],
      user_id: context[:user_id],
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  ## Metric Emission Functions

  @doc """
  Emits sync start event.
  """
  def emit_sync_start(metadata) do
    :telemetry.execute([:sync, :start], %{system_time: System.system_time()}, metadata)
    :ok
  end

  @doc """
  Emits sync completion event.
  """
  def emit_sync_complete(metadata, duration_ms) do
    :telemetry.execute([:sync, :stop], %{duration: duration_ms * 1_000_000}, metadata)
    :ok
  end

  @doc """
  Emits sync error event.
  """
  def emit_sync_error(metadata, error) do
    :telemetry.execute([:sync, :exception], %{}, Map.put(metadata, :error, error))
    :ok
  end

  @doc """
  Emits database query start event.
  """
  def emit_db_query_start(metadata) do
    :telemetry.execute([:repo, :query, :start], %{system_time: System.system_time()}, metadata)
    :ok
  end

  @doc """
  Emits database query completion event.
  """
  def emit_db_query_complete(metadata, duration_ms) do
    :telemetry.execute([:repo, :query], %{duration: duration_ms * 1_000_000}, metadata)
    :ok
  end

  @doc """
  Emits user interaction event.
  """
  def emit_user_action(metadata) do
    :telemetry.execute([:user, :action], %{system_time: System.system_time()}, metadata)
    :ok
  end

  @doc """
  Emits system health check event.
  """
  def emit_health_check(metadata) do
    :telemetry.execute([:system, :health], %{system_time: System.system_time()}, metadata)
    :ok
  end

  ## Performance Monitoring

  @doc """
  Starts tracking an operation and returns operation ID.
  """
  def start_operation(operation_name, metadata) do
    ensure_tables_exist()
    operation_id = generate_operation_id()
    start_time = System.monotonic_time(:millisecond)

    operation_data = %{
      id: operation_id,
      operation: operation_name,
      metadata: metadata,
      start_time: start_time
    }

    true = :ets.insert(@operations_table, {operation_id, operation_data})
    operation_id
  end

  @doc """
  Completes operation tracking and returns performance data.
  """
  def complete_operation(operation_id, completion_metadata \\ %{}) do
    case :ets.lookup(@operations_table, operation_id) do
      [{^operation_id, operation_data}] ->
        end_time = System.monotonic_time(:millisecond)
        duration_ms = end_time - operation_data.start_time

        result =
          Map.merge(
            %{
              operation: operation_data.operation,
              duration_ms: duration_ms,
              start_metadata: operation_data.metadata,
              completion_metadata: completion_metadata
            },
            completion_metadata
          )

        :ets.delete(@operations_table, operation_id)
        result

      [] ->
        %{error: :operation_not_found}
    end
  end

  @doc """
  Gets current memory usage statistics.
  """
  def get_memory_usage do
    memory_info = :erlang.memory()

    %{
      total: memory_info[:total],
      processes: memory_info[:processes],
      system: memory_info[:system],
      atom: memory_info[:atom],
      binary: memory_info[:binary],
      ets: memory_info[:ets]
    }
  end

  @doc """
  Generates comprehensive performance report.
  """
  def generate_performance_report do
    _ = ensure_tables_exist()

    # Get metrics from ETS table
    sync_metrics = get_metrics_by_type(:sync)
    database_metrics = get_metrics_by_type(:database)
    slow_operations = get_slow_operations()

    %{
      sync_metrics: sync_metrics,
      database_metrics: database_metrics,
      slow_operations: slow_operations,
      total_operations: count_total_operations(),
      memory_usage: get_memory_usage(),
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  ## Private Functions

  defp extract_error_reason(%Req.TransportError{reason: reason}), do: reason
  defp extract_error_reason(%Postgrex.Error{message: message}), do: message

  defp extract_error_reason(%Ash.Error.Invalid{errors: errors}),
    do: {:validation_errors, length(errors)}

  defp extract_error_reason(%RuntimeError{message: message}), do: message
  defp extract_error_reason(_), do: :unknown

  defp generate_error_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16() |> String.downcase()
  end

  defp generate_operation_id do
    :crypto.strong_rand_bytes(12) |> Base.encode16() |> String.downcase()
  end

  defp ensure_tables_exist do
    _ =
      if :ets.whereis(@operations_table) == :undefined do
        :ets.new(@operations_table, [:named_table, :public, :set])
      end

    _ =
      if :ets.whereis(@metrics_table) == :undefined do
        :ets.new(@metrics_table, [:named_table, :public, :bag])
      end

    :ok
  end

  defp get_metrics_by_type(type) do
    case :ets.whereis(@metrics_table) do
      :undefined ->
        %{}

      _tid ->
        @metrics_table
        |> :ets.tab2list()
        |> Enum.filter(fn {key, _value} ->
          String.starts_with?(to_string(key), to_string(type))
        end)
        |> Map.new()
    end
  end

  defp get_slow_operations do
    case :ets.whereis(@operations_table) do
      :undefined ->
        []

      _tid ->
        @operations_table
        |> :ets.tab2list()
        |> Enum.map(fn {_id, data} -> data end)
        |> Enum.filter(fn data ->
          current_time = System.monotonic_time(:millisecond)
          # Operations running > 5 seconds
          current_time - data.start_time > 5000
        end)
    end
  end

  defp count_total_operations do
    case :ets.whereis(@operations_table) do
      :undefined -> 0
      _tid -> :ets.info(@operations_table, :size)
    end
  end
end
