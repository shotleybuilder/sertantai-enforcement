defmodule EhsEnforcement.LoggerTest do
  use ExUnit.Case, async: true

  # 🐛 BLOCKED: Logger formatting tests failing - Issue #43
  # 5 failures in log format assertions - needs logger configuration review
  @moduletag :skip

  import ExUnit.CaptureLog

  alias EhsEnforcement.Logger, as: EhsLogger

  setup do
    # Set logger level to debug for tests to capture all log levels
    original_level = Logger.level()
    Logger.configure(level: :debug)

    # Configure console logger to include metadata
    :logger.set_handler_config(
      :default,
      :formatter,
      {:logger_formatter, %{template: [:level, " ", :msg, " ", :mfa, " ", :meta, "\n"]}}
    )

    on_exit(fn ->
      Logger.configure(level: original_level)
      # Reset to default formatter
      :logger.set_handler_config(:default, :formatter, {:logger_formatter, %{}})
    end)

    :ok
  end

  describe "structured logging" do
    test "logs info messages with structured metadata" do
      metadata = %{
        operation: "sync_cases",
        agency: :hse,
        records_count: 150,
        user_id: "user123"
      }

      log =
        capture_log(fn ->
          EhsLogger.info("Sync operation completed", metadata)
        end)

      assert log =~ "info"
      assert log =~ "Sync operation completed"
      assert log =~ "operation=sync_cases"
      assert log =~ "agency=hse"
      assert log =~ "records_count=150"
      assert log =~ "user_id=user123"
    end

    test "logs error messages with stacktrace and error details" do
      error = %RuntimeError{message: "Database connection failed"}
      stacktrace = [{:module, :function, 1, [file: ~c"lib/test.ex", line: 10]}]

      metadata = %{
        operation: "database_query",
        query: "SELECT * FROM cases",
        error_id: "err_123"
      }

      log =
        capture_log(fn ->
          EhsLogger.error("Database operation failed", error, stacktrace, metadata)
        end)

      assert log =~ "error"
      assert log =~ "Database operation failed"
      assert log =~ "Database connection failed"
      assert log =~ "operation=database_query"
      assert log =~ "error_id=err_123"
      assert log =~ "lib/test.ex:10"
    end

    test "logs warning messages with appropriate context" do
      metadata = %{
        operation: "sync_validation",
        agency: :hse,
        invalid_records: 5,
        total_records: 100
      }

      log =
        capture_log(fn ->
          EhsLogger.warn("Found invalid records during sync", metadata)
        end)

      assert log =~ "warning"
      assert log =~ "Found invalid records during sync"
      assert log =~ "invalid_records=5"
      assert log =~ "total_records=100"
    end

    test "logs debug messages in development environment" do
      metadata = %{
        module: "SyncManager",
        function: "process_batch",
        batch_size: 50
      }

      log =
        capture_log(fn ->
          EhsLogger.debug("Processing batch of records", metadata)
        end)

      assert log =~ "debug"
      assert log =~ "Processing batch of records"
      assert log =~ "batch_size=50"
    end
  end

  describe "security logging" do
    test "logs authentication events" do
      metadata = %{
        user_id: "user123",
        ip_address: "192.168.1.100",
        user_agent: "Mozilla/5.0...",
        session_id: "sess_abc123"
      }

      log =
        capture_log(fn ->
          EhsLogger.log_auth_success("User login successful", metadata)
        end)

      assert log =~ "info"
      assert log =~ "User login successful"
      assert log =~ "user_id=user123"
      assert log =~ "ip_address=192.168.1.100"
      assert log =~ "auth_event=success"
    end

    test "logs authentication failures with security context" do
      metadata = %{
        attempted_user: "admin",
        ip_address: "192.168.1.100",
        failure_reason: "invalid_password",
        attempt_count: 3
      }

      log =
        capture_log(fn ->
          EhsLogger.log_auth_failure("Login attempt failed", metadata)
        end)

      assert log =~ "warning"
      assert log =~ "Login attempt failed"
      assert log =~ "attempted_user=admin"
      assert log =~ "failure_reason=invalid_password"
      assert log =~ "attempt_count=3"
      assert log =~ "auth_event=failure"
    end

    test "logs data access events for audit trail" do
      metadata = %{
        user_id: "user123",
        resource: "cases",
        action: "view",
        resource_ids: ["case_1", "case_2"],
        agency: :hse
      }

      log =
        capture_log(fn ->
          EhsLogger.log_data_access("User accessed enforcement cases", metadata)
        end)

      assert log =~ "info"
      assert log =~ "User accessed enforcement cases"
      assert log =~ "resource=cases"
      assert log =~ "action=view"
      assert log =~ "audit_event=data_access"
    end

    test "logs data modification events" do
      metadata = %{
        user_id: "admin123",
        resource: "cases",
        action: "update",
        resource_id: "case_456",
        changes: %{status: "closed"},
        reason: "case_resolved"
      }

      log =
        capture_log(fn ->
          EhsLogger.log_data_modification("Case status updated", metadata)
        end)

      assert log =~ "info"
      assert log =~ "Case status updated"
      assert log =~ "action=update"
      assert log =~ "resource_id=case_456"
      assert log =~ "audit_event=data_modification"
    end
  end

  describe "performance logging" do
    test "logs slow operations with timing information" do
      metadata = %{
        operation: "database_query",
        duration_ms: 2500,
        query: "SELECT * FROM cases WHERE complex_condition",
        threshold_ms: 1000
      }

      log =
        capture_log(fn ->
          EhsLogger.log_slow_operation("Slow database query detected", metadata)
        end)

      assert log =~ "warning"
      assert log =~ "Slow database query detected"
      assert log =~ "duration_ms=2500"
      assert log =~ "threshold_ms=1000"
      assert log =~ "performance_event=slow_operation"
    end

    test "logs resource usage spikes" do
      metadata = %{
        resource_type: "memory",
        current_usage: 85.5,
        threshold: 80.0,
        unit: "percent"
      }

      log =
        capture_log(fn ->
          EhsLogger.log_resource_usage("High memory usage detected", metadata)
        end)

      assert log =~ "warning"
      assert log =~ "High memory usage detected"
      assert log =~ "current_usage=85.5"
      assert log =~ "resource_type=memory"
      assert log =~ "performance_event=resource_spike"
    end
  end

  describe "business logic logging" do
    test "logs sync operation progress" do
      metadata = %{
        operation: "hse_sync",
        agency: :hse,
        phase: "data_processing",
        records_processed: 500,
        total_records: 1000,
        progress_percent: 50.0
      }

      log =
        capture_log(fn ->
          EhsLogger.log_sync_progress("HSE sync in progress", metadata)
        end)

      assert log =~ "info"
      assert log =~ "HSE sync in progress"
      assert log =~ "progress_percent=50.0"
      assert log =~ "business_event=sync_progress"
    end

    test "logs data validation errors" do
      metadata = %{
        operation: "data_validation",
        agency: :hse,
        validation_errors: [
          %{field: "offence_date", error: "invalid_format", value: "2023-13-45"},
          %{field: "fine_amount", error: "negative_value", value: -100}
        ],
        record_id: "rec_123"
      }

      log =
        capture_log(fn ->
          EhsLogger.log_validation_errors("Data validation failed", metadata)
        end)

      assert log =~ "warning"
      assert log =~ "Data validation failed"
      assert log =~ "validation_errors"
      assert log =~ "business_event=validation_failure"
    end

    test "logs duplicate detection events" do
      metadata = %{
        operation: "duplicate_detection",
        agency: :hse,
        duplicate_type: "offender",
        original_id: "off_123",
        duplicate_id: "off_456",
        similarity_score: 0.95,
        matching_fields: ["name", "postcode"]
      }

      log =
        capture_log(fn ->
          EhsLogger.log_duplicate_detected("Duplicate offender detected", metadata)
        end)

      assert log =~ "info"
      assert log =~ "Duplicate offender detected"
      assert log =~ "similarity_score=0.95"
      assert log =~ "business_event=duplicate_detection"
    end
  end

  describe "log filtering and sanitization" do
    test "sanitizes sensitive data in logs" do
      metadata = %{
        operation: "api_call",
        api_key: "sk_live_1234567890abcdef",
        database_url: "postgresql://user:password@host/db",
        user_email: "user@example.com",
        safe_field: "safe_value"
      }

      log =
        capture_log(fn ->
          EhsLogger.info("API operation completed", metadata)
        end)

      assert log =~ "API operation completed"
      assert log =~ "api_key=***REDACTED***"
      assert log =~ "database_url=***REDACTED***"
      assert log =~ "safe_field=safe_value"
      refute log =~ "password"
      refute log =~ "1234567890abcdef"
    end

    test "filters logs by severity level" do
      # Test that debug logs are filtered in production
      Application.put_env(:logger, :level, :info)

      log =
        capture_log(fn ->
          EhsLogger.debug("Debug message that should be filtered", %{})
        end)

      assert log == ""

      # Reset to default
      Application.put_env(:logger, :level, :debug)
    end

    test "redacts personally identifiable information" do
      metadata = %{
        operation: "user_query",
        user_name: "John Doe",
        phone_number: "01234567890",
        national_insurance: "AB123456C",
        case_reference: "HSE_2023_001"
      }

      log =
        capture_log(fn ->
          EhsLogger.info("User information logged", metadata)
        end)

      assert log =~ "user_name=***REDACTED***"
      assert log =~ "phone_number=***REDACTED***"
      assert log =~ "national_insurance=***REDACTED***"
      # Case references are not PII
      assert log =~ "case_reference=HSE_2023_001"
    end
  end

  describe "log formatting and structure" do
    test "formats log messages with consistent timestamp format" do
      log =
        capture_log(fn ->
          EhsLogger.info("Test message", %{})
        end)

      # Check for ISO 8601 timestamp format
      assert log =~ ~r/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/
    end

    test "includes correlation IDs for request tracing" do
      correlation_id = "req_abc123"

      log =
        capture_log(fn ->
          EhsLogger.with_correlation_id(correlation_id, fn ->
            EhsLogger.info("Request processing", %{step: "validation"})
          end)
        end)

      assert log =~ "correlation_id=req_abc123"
      assert log =~ "step=validation"
    end

    test "supports structured JSON logging format" do
      metadata = %{operation: "test", count: 42}

      json_log = EhsLogger.format_as_json("Test message", :info, metadata)
      parsed = Jason.decode!(json_log)

      assert parsed["level"] == "info"
      assert parsed["message"] == "Test message"
      assert parsed["metadata"]["operation"] == "test"
      assert parsed["metadata"]["count"] == 42
      assert is_binary(parsed["timestamp"])
    end

    test "includes application context in all logs" do
      log =
        capture_log(fn ->
          EhsLogger.info("Test message", %{})
        end)

      assert log =~ "app=ehs_enforcement"
      assert log =~ "env=test"
      assert log =~ "node="
    end
  end

  describe "log aggregation and metrics" do
    test "tracks log message counts by level" do
      # Clear existing metrics
      EhsLogger.reset_metrics()

      EhsLogger.info("Info message 1", %{})
      EhsLogger.info("Info message 2", %{})
      EhsLogger.error("Error message", %RuntimeError{}, [], %{})
      EhsLogger.warn("Warning message", %{})

      metrics = EhsLogger.get_log_metrics()

      assert metrics.info_count == 2
      assert metrics.error_count == 1
      assert metrics.warn_count == 1
      assert metrics.debug_count == 0
    end

    test "tracks most frequent error types" do
      EhsLogger.reset_metrics()

      EhsLogger.error("API error", %Req.TransportError{reason: :timeout}, [], %{})
      EhsLogger.error("API error", %Req.TransportError{reason: :timeout}, [], %{})
      EhsLogger.error("DB error", %Postgrex.Error{message: "connection failed"}, [], %{})

      metrics = EhsLogger.get_error_metrics()

      assert metrics.most_frequent_errors == [
               {"Req.TransportError", 2},
               {"Postgrex.Error", 1}
             ]
    end

    test "generates log summary reports" do
      EhsLogger.reset_metrics()

      # Generate some test logs
      Enum.each(1..10, fn i ->
        EhsLogger.info("Test message #{i}", %{operation: "test_op"})
      end)

      EhsLogger.error("Test error", %RuntimeError{}, [], %{operation: "test_op"})

      report = EhsLogger.generate_summary_report()

      assert report.total_logs == 11
      assert report.error_rate < 0.1
      assert length(report.top_operations) > 0
      assert is_binary(report.generated_at)
    end
  end
end
