defmodule EhsEnforcement.TelemetryTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias EhsEnforcement.Telemetry

  setup do
    # Set logger level to debug for tests to capture all log levels
    original_level = Logger.level()
    Logger.configure(level: :debug)

    on_exit(fn ->
      Logger.configure(level: original_level)
    end)

    :ok
  end

  describe "telemetry event handling" do
    test "handles sync start events with proper logging" do
      measurements = %{system_time: System.system_time()}
      metadata = %{agency: :hse, operation: "cases"}

      log =
        capture_log(fn ->
          Telemetry.handle_event([:sync, :start], measurements, metadata, %{})
        end)

      assert log =~ "Starting sync for hse"
      assert log =~ "operation=cases"
    end

    test "handles sync stop events with duration calculation" do
      # 5 seconds in nanoseconds
      measurements = %{duration: 5_000_000_000}
      metadata = %{agency: :hse, operation: "cases", records_processed: 150}

      log =
        capture_log(fn ->
          Telemetry.handle_event([:sync, :stop], measurements, metadata, %{})
        end)

      assert log =~ "Sync completed for hse"
      assert log =~ "5000ms"
      assert log =~ "records_processed=150"
    end

    test "handles sync exception events with error details" do
      measurements = %{}
      error = %Req.TransportError{reason: :timeout}
      metadata = %{agency: :hse, operation: "cases", error: error, stacktrace: []}

      log =
        capture_log(fn ->
          Telemetry.handle_event([:sync, :exception], measurements, metadata, %{})
        end)

      assert log =~ "Sync failed for hse"
      assert log =~ "timeout"
      assert log =~ "error"
    end

    test "handles database query events for performance monitoring" do
      # 150ms in nanoseconds
      measurements = %{duration: 150_000_000}
      metadata = %{query: "SELECT * FROM cases", params: [], result: {:ok, []}}

      log =
        capture_log(fn ->
          Telemetry.handle_event([:repo, :query], measurements, metadata, %{})
        end)

      assert log =~ "Database query completed"
      assert log =~ "150ms"
      assert log =~ "SELECT * FROM cases"
    end

    test "handles slow database query events with warnings" do
      # 2 seconds in nanoseconds
      measurements = %{duration: 2_000_000_000}
      metadata = %{query: "SELECT * FROM cases WHERE complex_condition", params: []}

      log =
        capture_log(fn ->
          Telemetry.handle_event([:repo, :query], measurements, metadata, %{})
        end)

      assert log =~ "warning"
      assert log =~ "Slow database query"
      assert log =~ "2000ms"
    end

    test "handles LiveView mount events for user analytics" do
      measurements = %{system_time: System.system_time()}

      metadata = %{
        socket: %{view: EhsEnforcementWeb.DashboardLive},
        params: %{},
        session: %{user_id: "user123"}
      }

      log =
        capture_log(fn ->
          Telemetry.handle_event(
            [:phoenix, :live_view, :mount, :start],
            measurements,
            metadata,
            %{}
          )
        end)

      assert log =~ "LiveView mount started"
      assert log =~ "DashboardLive"
      assert log =~ "user_id=user123"
    end

    test "handles LiveView crash events with error tracking" do
      measurements = %{}
      error = %RuntimeError{message: "View crashed"}

      metadata = %{
        socket: %{view: EhsEnforcementWeb.CaseLive.Index},
        kind: :error,
        reason: error,
        stacktrace: []
      }

      log =
        capture_log(fn ->
          Telemetry.handle_event(
            [:phoenix, :live_view, :mount, :exception],
            measurements,
            metadata,
            %{}
          )
        end)

      assert log =~ "error"
      assert log =~ "LiveView mount failed"
      assert log =~ "CaseLive.Index"
      assert log =~ "View crashed"
    end

    test "handles HTTP request events for API monitoring" do
      # 250ms
      measurements = %{duration: 250_000_000}

      metadata = %{
        method: "GET",
        path: "/api/cases",
        status: 200,
        user_agent: "EhsEnforcement/1.0"
      }

      log =
        capture_log(fn ->
          Telemetry.handle_event([:phoenix, :endpoint, :stop], measurements, metadata, %{})
        end)

      assert log =~ "HTTP request completed"
      assert log =~ "GET /api/cases"
      assert log =~ "status=200"
      assert log =~ "250ms"
    end

    test "handles HTTP error events with appropriate logging level" do
      measurements = %{duration: 100_000_000}

      metadata = %{
        method: "POST",
        path: "/api/sync",
        status: 500,
        user_agent: "EhsEnforcement/1.0"
      }

      log =
        capture_log(fn ->
          Telemetry.handle_event([:phoenix, :endpoint, :stop], measurements, metadata, %{})
        end)

      assert log =~ "warning"
      assert log =~ "HTTP request failed"
      assert log =~ "POST /api/sync"
      assert log =~ "status=500"
    end
  end

  describe "telemetry configuration" do
    test "returns proper event list for attachment" do
      events = Telemetry.events()

      assert [:sync, :start] in events
      assert [:sync, :stop] in events
      assert [:sync, :exception] in events
      assert [:repo, :query] in events
      assert [:phoenix, :live_view, :mount, :start] in events
      assert [:phoenix, :live_view, :mount, :exception] in events
      assert [:phoenix, :endpoint, :stop] in events
    end

    test "validates telemetry handler registration" do
      assert Telemetry.attach_handlers() == :ok
    end

    test "validates telemetry handler detachment" do
      Telemetry.attach_handlers()
      assert Telemetry.detach_handlers() == :ok
    end
  end

  describe "metric collection" do
    test "emits custom sync metrics" do
      # Test that we can emit metrics and they're captured
      metadata = %{agency: :hse, operation: "cases", records: 100}

      assert :ok = Telemetry.emit_sync_start(metadata)
      assert :ok = Telemetry.emit_sync_complete(metadata, 5000)
      assert :ok = Telemetry.emit_sync_error(metadata, %RuntimeError{message: "test"})
    end

    test "emits database performance metrics" do
      metadata = %{query: "SELECT COUNT(*) FROM cases", source: "dashboard"}

      assert :ok = Telemetry.emit_db_query_start(metadata)
      assert :ok = Telemetry.emit_db_query_complete(metadata, 150)
    end

    test "emits user interaction metrics" do
      metadata = %{view: "DashboardLive", action: "filter_cases", user_id: "user123"}

      assert :ok = Telemetry.emit_user_action(metadata)
    end

    test "emits system health metrics" do
      metadata = %{component: "sync_manager", status: :healthy}

      assert :ok = Telemetry.emit_health_check(metadata)
    end
  end

  describe "error categorization" do
    test "categorizes sync errors by type" do
      api_error = %Req.TransportError{reason: :timeout}
      db_error = %Postgrex.Error{message: "connection closed"}
      validation_error = %Ash.Error.Invalid{errors: []}

      assert Telemetry.categorize_error(api_error) == :api_error
      assert Telemetry.categorize_error(db_error) == :database_error
      assert Telemetry.categorize_error(validation_error) == :validation_error
      assert Telemetry.categorize_error(%RuntimeError{}) == :application_error
    end

    test "extracts error context for logging" do
      error = %Req.TransportError{reason: :timeout}
      context = %{agency: :hse, operation: "fetch_cases"}

      result = Telemetry.extract_error_context(error, context)

      assert result.error_type == :api_error
      assert result.error_reason == :timeout
      assert result.agency == :hse
      assert result.operation == "fetch_cases"
      assert is_binary(result.error_id)
    end
  end

  describe "performance monitoring" do
    test "tracks operation duration metrics" do
      operation_id = Telemetry.start_operation("sync_cases", %{agency: :hse})

      # Simulate some work
      :timer.sleep(10)

      result = Telemetry.complete_operation(operation_id, %{records_processed: 50})

      assert result.duration_ms > 0
      assert result.records_processed == 50
      assert result.operation == "sync_cases"
    end

    test "tracks memory usage during operations" do
      metadata = %{operation: "import_large_dataset"}

      memory_before = Telemetry.get_memory_usage()

      # Simulate memory-intensive operation
      _data = Enum.map(1..1000, fn i -> %{id: i, data: String.duplicate("x", 100)} end)

      memory_after = Telemetry.get_memory_usage()

      assert memory_after.total >= memory_before.total
      assert is_integer(memory_after.processes)
      assert is_integer(memory_after.system)
    end

    test "generates performance report" do
      # Emit some test events
      Telemetry.emit_sync_complete(%{agency: :hse}, 1000)
      Telemetry.emit_sync_complete(%{agency: :hse}, 1500)
      Telemetry.emit_db_query_complete(%{query: "SELECT * FROM cases"}, 200)

      report = Telemetry.generate_performance_report()

      assert is_map(report.sync_metrics)
      assert is_map(report.database_metrics)
      assert is_list(report.slow_operations)
      assert is_integer(report.total_operations)
    end
  end
end
