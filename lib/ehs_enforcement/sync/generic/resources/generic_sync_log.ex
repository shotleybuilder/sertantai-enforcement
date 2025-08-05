defmodule EhsEnforcement.Sync.Generic.Resources.GenericSyncLog do
  @moduledoc """
  Generic Ash resource for logging sync operations and events.
  
  This resource provides comprehensive logging capabilities for sync operations,
  capturing events, errors, and operational details. It's designed to be
  domain-agnostic and work with any sync system.
  
  ## Features
  
  - Structured event logging with consistent format
  - Multiple log levels (debug, info, warn, error)
  - Automatic timestamp and session correlation
  - Error details capture and categorization  
  - Performance metrics and timing information
  - Searchable and filterable log entries
  - Retention policy support
  
  ## Usage
  
      # Log a sync event
      {:ok, log_entry} = Ash.create(GenericSyncLog, %{
        session_id: "sync_abc123",
        level: :info,
        event_type: :batch_started,
        message: "Started processing batch 1 with 100 records",
        data: %{batch_number: 1, batch_size: 100}
      })
      
      # Log an error
      {:ok, error_log} = Ash.create(GenericSyncLog, %{
        session_id: "sync_abc123", 
        level: :error,
        event_type: :processing_error,
        message: "Failed to process record",
        data: %{record_id: "rec123", error: "Validation failed"},
        error_details: %{
          error_type: "ValidationError",
          error_message: "Required field 'name' is missing",
          stacktrace: "..."
        }
      })
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Sync.Generic,
    data_layer: AshPostgres.DataLayer
    
  require Ash.Query
  import Ash.Expr

  postgres do
    table "generic_sync_logs"
    repo EhsEnforcement.Repo
    
    custom_indexes do
      index [:session_id]
      index [:level]
      index [:event_type]
      index [:logged_at]
      index [:session_id, :logged_at]
      index [:level, :logged_at]
      index [:event_type, :logged_at]
      
      # Full-text search on message  
      index [:message], using: "gin"
    end
  end

  attributes do
    uuid_primary_key :id
    
    # Session correlation
    attribute :session_id, :string do
      allow_nil? true
      constraints max_length: 255
      description "Session ID this log entry belongs to (null for system-wide events)"
    end
    
    attribute :batch_id, :uuid do
      allow_nil? true
      description "Batch ID this log entry belongs to (if applicable)"
    end
    
    # Log entry details
    attribute :level, :atom do
      allow_nil? false
      default :info
      constraints one_of: [:debug, :info, :warn, :error, :fatal]
      description "Log level indicating severity"
    end
    
    attribute :event_type, :atom do
      allow_nil? false
      constraints one_of: [
        # Session events
        :session_started, :session_completed, :session_failed, :session_cancelled,
        
        # Batch events  
        :batch_started, :batch_completed, :batch_failed, :batch_retried,
        
        # Processing events
        :record_processed, :record_created, :record_updated, :record_failed,
        
        # Error events
        :processing_error, :validation_error, :connection_error, :timeout_error,
        
        # Recovery events
        :error_recovery_started, :error_recovery_completed, :error_recovery_failed,
        
        # System events
        :system_event, :performance_metric, :integrity_check, :cleanup_event,
        
        # Custom events
        :custom_event, :user_action, :configuration_change, :alert_triggered
      ]
      description "Type of event being logged"
    end
    
    attribute :message, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 2000
      description "Human-readable log message"
    end
    
    # Data and context
    attribute :data, :map do
      allow_nil? true
      default %{}
      description "Structured data associated with the log entry"
    end
    
    attribute :context, :map do
      allow_nil? true
      default %{}
      description "Additional context information (user, environment, etc.)"
    end
    
    # Error information (for error-level logs)
    attribute :error_details, :map do
      allow_nil? true
      description "Detailed error information including type, message, and stacktrace"
    end
    
    attribute :error_category, :string do
      allow_nil? true
      constraints max_length: 100
      description "Error category for classification and filtering"
    end
    
    # Performance and timing
    attribute :duration_ms, :integer do
      allow_nil? true
      constraints min: 0
      description "Duration of the operation in milliseconds (if applicable)"
    end
    
    attribute :performance_metrics, :map do
      allow_nil? true
      description "Performance metrics (memory usage, CPU time, etc.)"
    end
    
    # Source information
    attribute :source_module, :string do
      allow_nil? true
      constraints max_length: 500
      description "Module that generated this log entry"
    end
    
    attribute :source_function, :string do
      allow_nil? true
      constraints max_length: 200  
      description "Function that generated this log entry"
    end
    
    attribute :source_line, :integer do
      allow_nil? true
      constraints min: 1
      description "Line number where the log entry was generated"
    end
    
    # Correlation and tracing
    attribute :correlation_id, :string do
      allow_nil? true
      constraints max_length: 255
      description "Correlation ID for tracing related operations"
    end
    
    attribute :trace_id, :string do
      allow_nil? true
      constraints max_length: 255
      description "Distributed tracing ID"
    end
    
    # Environment information
    attribute :node_name, :string do
      allow_nil? true
      constraints max_length: 255
      description "Elixir node name where the event occurred"
    end
    
    attribute :process_pid, :string do
      allow_nil? true
      constraints max_length: 100
      description "Process PID that generated the log entry"
    end
    
    # Timestamp (separate from created_at for precision)
    attribute :logged_at, :utc_datetime_usec do
      allow_nil? false
      default &DateTime.utc_now/0
      description "Precise timestamp when the event occurred"
    end
    
    # Audit trail
    timestamps()
  end

  actions do
    defaults [:read, :destroy]
    
    create :create do
      accept [
        :session_id, :batch_id, :level, :event_type, :message, :data, :context,
        :error_details, :error_category, :duration_ms, :performance_metrics,
        :source_module, :source_function, :source_line, :correlation_id, :trace_id,
        :node_name, :process_pid
      ]
      
      change set_attribute(:logged_at, &DateTime.utc_now/0)
      change set_attribute(:node_name, to_string(Node.self()))
    end
    
    create :log_event do
      accept [
        :session_id, :level, :event_type, :message, :data, :context
      ]
      
      change set_attribute(:logged_at, &DateTime.utc_now/0)
      change set_attribute(:node_name, to_string(Node.self()))
    end
    
    create :log_error do
      accept [
        :session_id, :batch_id, :event_type, :message, :data, :context,
        :error_details, :error_category, :source_module, :source_function, :source_line
      ]
      
      change set_attribute(:level, :error)
      change set_attribute(:logged_at, &DateTime.utc_now/0)
      change set_attribute(:node_name, to_string(Node.self()))
    end
    
    create :log_performance do
      accept [
        :session_id, :batch_id, :event_type, :message, :data,
        :duration_ms, :performance_metrics
      ]
      
      change set_attribute(:level, :info)
      change set_attribute(:event_type, :performance_metric)
      change set_attribute(:logged_at, &DateTime.utc_now/0)
      change set_attribute(:node_name, to_string(Node.self()))
    end
    
    # Batch operations for performance
    create :bulk_create do
      accept [
        :session_id, :batch_id, :level, :event_type, :message, :data, :context,
        :error_details, :error_category, :duration_ms, :performance_metrics,
        :source_module, :source_function, :source_line, :correlation_id, :trace_id
      ]
      
      change set_attribute(:logged_at, &DateTime.utc_now/0)
      change set_attribute(:node_name, to_string(Node.self()))
    end
  end

  relationships do
    belongs_to :sync_session, EhsEnforcement.Sync.Generic.Resources.GenericSyncSession do
      source_attribute :session_id
      destination_attribute :session_id
      attribute_type :string
    end
    
    belongs_to :sync_batch, EhsEnforcement.Sync.Generic.Resources.GenericSyncBatch do
      source_attribute :batch_id
      destination_attribute :id
    end
  end

  validations do
    validate present([:level, :event_type, :message])
  end

  preparations do
    prepare build(sort: [logged_at: :desc])  # Default to newest first
  end

  calculations do
    calculate :age_minutes, :integer, expr(
      datetime_diff(now(), logged_at, :minute)
    )
    
    calculate :is_recent, :boolean, expr(
      datetime_diff(now(), logged_at, :minute) <= 60
    )
    
    calculate :is_error, :boolean, expr(level in [:error, :fatal])
    
    calculate :has_performance_data, :boolean, expr(
      not is_nil(duration_ms) or not is_nil(performance_metrics)
    )
    
    calculate :formatted_duration, :string, expr(
      cond do
        is_nil(duration_ms) -> "N/A"
        duration_ms < 1000 -> fragment("? || 'ms'", duration_ms)
        duration_ms < 60000 -> fragment("ROUND(? / 1000.0, 2) || 's'", duration_ms)
        true -> fragment("ROUND(? / 60000.0, 2) || 'm'", duration_ms)
      end
    )
  end

  # aggregates do
  #   # Session-level log aggregates  
  #   count :total_log_entries, [:sync_logs]
  #   count :error_log_count, [:sync_logs], filter: expr(level == :error)
  #   count :warning_log_count, [:sync_logs], filter: expr(level == :warn)
  #   
  #   # Performance aggregates
  #   avg :average_operation_duration, [:sync_logs], field: :duration_ms,
  #       filter: expr(not is_nil(duration_ms))
  #   max :max_operation_duration, [:sync_logs], field: :duration_ms
  # end

  code_interface do
    define :create_log, action: :create
    define :log_event, action: :log_event
    define :log_error, action: :log_error
    define :log_performance, action: :log_performance
    define :bulk_create_logs, action: :bulk_create
    
    define :list_session_logs, action: :read, args: [:session_id]
    define :list_logs, action: :read
  end

  # Helper functions for structured logging

  def log_sync_event(session_id, event_type, message, data \\ %{}, opts \\ []) do
    level = Keyword.get(opts, :level, :info)
    context = Keyword.get(opts, :context, %{})
    
    attrs = %{
      session_id: session_id,
      level: level,
      event_type: event_type,
      message: message,
      data: data,
      context: context
    }
    
    # Add source information if available
    attrs = if Keyword.has_key?(opts, :source) do
      source = Keyword.get(opts, :source)
      Map.merge(attrs, %{
        source_module: source[:module],
        source_function: source[:function],
        source_line: source[:line]
      })
    else
      attrs
    end
    
    Ash.create(__MODULE__, attrs, action: :log_event)
  end

  def log_sync_error(session_id, event_type, message, error, opts \\ []) do
    batch_id = Keyword.get(opts, :batch_id)
    context = Keyword.get(opts, :context, %{})
    
    error_details = format_error_details(error)
    error_category = determine_error_category(error)
    
    attrs = %{
      session_id: session_id,
      batch_id: batch_id,
      event_type: event_type,
      message: message,
      data: Map.get(opts, :data, %{}),
      context: context,
      error_details: error_details,
      error_category: error_category
    }
    
    # Add source information if available
    attrs = if Keyword.has_key?(opts, :source) do
      source = Keyword.get(opts, :source)
      Map.merge(attrs, %{
        source_module: source[:module],
        source_function: source[:function],
        source_line: source[:line]
      })
    else
      attrs
    end
    
    Ash.create(__MODULE__, attrs, action: :log_error)
  end

  def log_performance_metric(session_id, operation, duration_ms, metrics \\ %{}, opts \\ []) do
    batch_id = Keyword.get(opts, :batch_id)
    
    attrs = %{
      session_id: session_id,
      batch_id: batch_id,
      event_type: :performance_metric,
      message: "Performance metric for #{operation}",
      data: %{operation: operation},
      duration_ms: duration_ms,
      performance_metrics: metrics
    }
    
    Ash.create(__MODULE__, attrs, action: :log_performance)
  end

  def get_session_log_summary(session_id) do
    query = __MODULE__
    |> Ash.Query.filter(session_id == ^session_id)
    
    case Ash.read(query) do
      {:ok, logs} ->
        %{
          total_entries: length(logs),
          error_count: Enum.count(logs, &(&1.level == :error)),
          warning_count: Enum.count(logs, &(&1.level == :warn)),
          recent_errors: get_recent_errors(logs),
          first_log_at: get_first_log_time(logs),
          last_log_at: get_last_log_time(logs)
        }
        
      {:error, _} ->
        %{total_entries: 0, error_count: 0, warning_count: 0}
    end
  end

  # Private helper functions

  defp format_error_details(error) when is_exception(error) do
    %{
      error_type: error.__struct__ |> Module.split() |> List.last(),
      error_message: Exception.message(error),
      stacktrace: Exception.format_stacktrace(Process.info(self(), :current_stacktrace) |> elem(1))
    }
  end
  defp format_error_details(%{__struct__: _} = error) do
    %{
      error_type: error.__struct__ |> Module.split() |> List.last(),
      error_message: inspect(error),
      raw_error: error
    }
  end
  defp format_error_details(error) when is_binary(error) do
    %{
      error_type: "String",
      error_message: error
    }
  end
  defp format_error_details(error) do
    %{
      error_type: "Unknown", 
      error_message: inspect(error),
      raw_error: error
    }
  end

  defp determine_error_category(error) when is_exception(error) do
    case error do
      %Ecto.NoResultsError{} -> "database"
      %Ecto.ConstraintError{} -> "validation"
      %Jason.DecodeError{} -> "data_format"
      %Tesla.Error{} -> "network"
      %Ash.Error.Invalid{} -> "validation"
      _ -> "unknown"
    end
  end
  defp determine_error_category(_error), do: "unknown"

  defp get_recent_errors(logs) do
    logs
    |> Enum.filter(&(&1.level == :error))
    |> Enum.sort_by(&(&1.logged_at), {:desc, DateTime})
    |> Enum.take(5)
    |> Enum.map(&%{
      message: &1.message,
      event_type: &1.event_type,
      logged_at: &1.logged_at,
      error_category: &1.error_category
    })
  end

  defp get_first_log_time([]), do: nil
  defp get_first_log_time(logs) do
    logs
    |> Enum.min_by(&(&1.logged_at), DateTime)
    |> Map.get(:logged_at)
  end

  defp get_last_log_time([]), do: nil
  defp get_last_log_time(logs) do
    logs
    |> Enum.max_by(&(&1.logged_at), DateTime)
    |> Map.get(:logged_at)
  end
end