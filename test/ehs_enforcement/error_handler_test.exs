defmodule EhsEnforcement.ErrorHandlerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias EhsEnforcement.ErrorHandler

  describe "error categorization" do
    test "categorizes API errors correctly" do
      api_timeout = %Req.TransportError{reason: :timeout}
      api_connect = %Req.TransportError{reason: :econnrefused}
      api_ssl = %Req.TransportError{reason: :ssl_closed}

      assert ErrorHandler.categorize_error(api_timeout) == {:api_error, :timeout}
      assert ErrorHandler.categorize_error(api_connect) == {:api_error, :connection_refused}
      assert ErrorHandler.categorize_error(api_ssl) == {:api_error, :ssl_error}
    end

    test "categorizes database errors correctly" do
      db_connection = %Postgrex.Error{message: "connection closed"}
      db_timeout = %DBConnection.ConnectionError{message: "timeout"}
      db_constraint = %Ecto.ConstraintError{constraint: "unique_constraint"}

      assert ErrorHandler.categorize_error(db_connection) == {:database_error, :connection_closed}
      assert ErrorHandler.categorize_error(db_timeout) == {:database_error, :timeout}

      assert ErrorHandler.categorize_error(db_constraint) ==
               {:database_error, :constraint_violation}
    end

    test "categorizes validation errors correctly" do
      ash_invalid = %Ash.Error.Invalid{errors: [%{field: :name, message: "is required"}]}
      changeset_error = %Ecto.Changeset{valid?: false, errors: [name: {"can't be blank", []}]}

      assert ErrorHandler.categorize_error(ash_invalid) == {:validation_error, :ash_validation}

      assert ErrorHandler.categorize_error(changeset_error) ==
               {:validation_error, :changeset_validation}
    end

    test "categorizes business logic errors correctly" do
      duplicate_error = %EhsEnforcement.ErrorHandler.DuplicateError{entity: :offender, id: "123"}
      sync_error = %EhsEnforcement.ErrorHandler.SyncError{agency: :hse, operation: :fetch_cases}

      assert ErrorHandler.categorize_error(duplicate_error) ==
               {:business_error, :duplicate_entity}

      assert ErrorHandler.categorize_error(sync_error) == {:business_error, :sync_failure}
    end

    test "categorizes generic application errors" do
      runtime_error = %RuntimeError{message: "Something went wrong"}
      argument_error = %ArgumentError{message: "Invalid argument"}

      assert ErrorHandler.categorize_error(runtime_error) == {:application_error, :runtime_error}

      assert ErrorHandler.categorize_error(argument_error) ==
               {:application_error, :argument_error}
    end
  end

  describe "error handling strategies" do
    test "handles retriable errors with exponential backoff" do
      error = %Req.TransportError{reason: :timeout}
      context = %{operation: "fetch_cases", agency: :hse, attempt: 1}

      strategy = ErrorHandler.determine_strategy(error, context)

      assert strategy.action == :retry
      assert strategy.max_attempts == 3
      assert strategy.backoff_ms == 1000
      assert strategy.exponential == true
    end

    test "handles non-retriable errors with immediate failure" do
      error = %Ecto.ConstraintError{constraint: "unique_constraint"}
      context = %{operation: "create_case", agency: :hse}

      strategy = ErrorHandler.determine_strategy(error, context)

      assert strategy.action == :fail
      assert strategy.reason == :constraint_violation
      assert strategy.recoverable == false
    end

    test "handles circuit breaker pattern for repeated failures" do
      error = %Req.TransportError{reason: :timeout}
      context = %{operation: "fetch_cases", agency: :hse, consecutive_failures: 5}

      strategy = ErrorHandler.determine_strategy(error, context)

      assert strategy.action == :circuit_break
      assert strategy.cooldown_ms == 60_000
      assert strategy.threshold == 5
    end

    test "handles graceful degradation for non-critical operations" do
      error = %Req.TransportError{reason: :timeout}
      context = %{operation: "update_statistics", agency: :hse, critical: false}

      strategy = ErrorHandler.determine_strategy(error, context)

      assert strategy.action == :degrade
      assert strategy.fallback_action == :skip_operation
      assert strategy.notify_admin == false
    end

    test "handles critical system errors with immediate escalation" do
      error = %Postgrex.Error{message: "database connection lost"}
      context = %{operation: "save_case", agency: :hse, critical: true}

      strategy = ErrorHandler.determine_strategy(error, context)

      assert strategy.action == :escalate
      assert strategy.notify_admin == true
      assert strategy.severity == :critical
    end
  end

  describe "error context extraction" do
    test "extracts comprehensive context from errors" do
      error = %Req.TransportError{reason: :timeout}

      stacktrace = [
        {EhsEnforcement.HSE.Client, :fetch_cases, 1, [file: ~c"lib/client.ex", line: 45]}
      ]

      metadata = %{agency: :hse, operation: "fetch_cases", user_id: "user123"}

      context = ErrorHandler.extract_error_context(error, stacktrace, metadata)

      assert context.error_type == :api_error
      assert context.error_subtype == :timeout
      assert context.operation == "fetch_cases"
      assert context.agency == :hse
      assert context.user_id == "user123"
      assert context.source_file == "lib/client.ex"
      assert context.source_line == 45
      assert is_binary(context.error_id)
      assert is_binary(context.timestamp)
    end

    test "extracts error fingerprint for deduplication" do
      error1 = %Req.TransportError{reason: :timeout}
      error2 = %Req.TransportError{reason: :timeout}
      error3 = %Req.TransportError{reason: :econnrefused}

      metadata = %{operation: "fetch_cases", agency: :hse}
      stacktrace = [{EhsEnforcement.HSE.Client, :fetch_cases, 1, []}]

      fingerprint1 = ErrorHandler.generate_fingerprint(error1, stacktrace, metadata)
      fingerprint2 = ErrorHandler.generate_fingerprint(error2, stacktrace, metadata)
      fingerprint3 = ErrorHandler.generate_fingerprint(error3, stacktrace, metadata)

      # Same error type should have same fingerprint
      assert fingerprint1 == fingerprint2
      # Different errors should have different fingerprints
      assert fingerprint1 != fingerprint3
    end

    test "extracts user impact assessment" do
      error = %Postgrex.Error{message: "connection timeout"}

      context = %{
        operation: "dashboard_load",
        user_id: "user123",
        affected_users: 1,
        business_impact: :medium
      }

      impact = ErrorHandler.assess_user_impact(error, context)

      assert impact.affected_users == 1
      assert impact.business_impact == :medium
      assert impact.user_facing == true
      assert impact.data_loss_risk == :low
      assert is_list(impact.mitigation_steps)
    end
  end

  describe "error recovery" do
    test "implements automatic recovery for transient errors" do
      error = %Req.TransportError{reason: :timeout}
      context = %{operation: "fetch_cases", agency: :hse}

      recovery_result = ErrorHandler.attempt_recovery(error, context)

      assert recovery_result.strategy == :retry_with_backoff
      assert recovery_result.estimated_recovery_time_ms > 0
      assert recovery_result.success_probability > 0.0
      assert is_function(recovery_result.recovery_function, 0)
    end

    test "implements fallback data sources for API failures" do
      error = %Req.TransportError{reason: :timeout}
      context = %{operation: "fetch_cases", agency: :hse, has_cache: true}

      recovery_result = ErrorHandler.attempt_recovery(error, context)

      assert recovery_result.strategy == :use_fallback
      assert recovery_result.fallback_source == :cache
      assert recovery_result.data_freshness == :stale
    end

    test "implements manual intervention for unrecoverable errors" do
      error = %Ecto.ConstraintError{constraint: "foreign_key_constraint"}
      context = %{operation: "create_case", agency: :hse}

      recovery_result = ErrorHandler.attempt_recovery(error, context)

      assert recovery_result.strategy == :manual_intervention
      assert recovery_result.intervention_type == :data_correction
      assert is_binary(recovery_result.admin_notification)
      assert is_list(recovery_result.suggested_actions)
    end
  end

  describe "error notifications" do
    test "sends appropriate notifications based on error severity" do
      high_severity_error = %Postgrex.Error{message: "database unreachable"}
      context = %{operation: "save_critical_data", severity: :critical}

      notifications = ErrorHandler.generate_notifications(high_severity_error, context)

      assert Enum.any?(notifications, &(&1.channel == :email))
      assert Enum.any?(notifications, &(&1.channel == :slack))
      assert Enum.any?(notifications, &(&1.urgency == :immediate))
    end

    test "batches low severity notifications to avoid spam" do
      low_severity_error = %Req.TransportError{reason: :timeout}
      context = %{operation: "update_stats", severity: :low}

      notifications = ErrorHandler.generate_notifications(low_severity_error, context)

      assert Enum.all?(notifications, &(&1.batched == true))
      assert Enum.all?(notifications, &(&1.urgency == :low))
      assert Enum.any?(notifications, &(&1.batch_window_minutes > 0))
    end

    test "includes relevant context in notifications" do
      error = %RuntimeError{message: "Sync failed"}

      context = %{
        operation: "hse_sync",
        agency: :hse,
        affected_records: 150,
        user_id: "admin123"
      }

      notification = ErrorHandler.format_notification(error, context)

      assert notification.title =~ "HSE Sync Failed"
      assert notification.body =~ "150 records"
      assert notification.body =~ "admin123"
      assert notification.severity == :medium
      assert is_list(notification.action_buttons)
    end
  end

  describe "error metrics and monitoring" do
    test "tracks error frequency by type and operation" do
      ErrorHandler.reset_metrics()

      # Simulate various errors
      ErrorHandler.record_error(%Req.TransportError{reason: :timeout}, %{operation: "fetch_cases"})

      ErrorHandler.record_error(%Req.TransportError{reason: :timeout}, %{operation: "fetch_cases"})

      ErrorHandler.record_error(%Postgrex.Error{message: "timeout"}, %{operation: "save_case"})

      metrics = ErrorHandler.get_error_metrics()

      assert metrics.total_errors == 3
      assert metrics.by_type.api_error == 2
      assert metrics.by_type.database_error == 1
      assert metrics.by_operation["fetch_cases"] == 2
      assert metrics.by_operation["save_case"] == 1
    end

    test "tracks error resolution success rates" do
      ErrorHandler.reset_metrics()

      error_id =
        ErrorHandler.record_error(%Req.TransportError{reason: :timeout}, %{
          operation: "fetch_cases"
        })

      ErrorHandler.record_resolution(error_id, :success, %{strategy: :retry})

      error_id2 =
        ErrorHandler.record_error(%Postgrex.Error{message: "timeout"}, %{operation: "save_case"})

      ErrorHandler.record_resolution(error_id2, :failure, %{strategy: :retry})

      metrics = ErrorHandler.get_resolution_metrics()

      assert metrics.total_resolutions == 2
      assert metrics.success_rate == 0.5
      assert metrics.by_strategy.retry.total == 2
      assert metrics.by_strategy.retry.success_rate == 0.5
    end

    test "generates error trend analysis" do
      ErrorHandler.reset_metrics()

      # Simulate error trend over time
      base_time = DateTime.utc_now()

      Enum.each(0..23, fn hour ->
        timestamp = DateTime.add(base_time, hour * 3600, :second)

        # More errors during "business hours" (9-17)
        error_count = if hour >= 9 and hour <= 17, do: 5, else: 1

        Enum.each(1..error_count, fn _ ->
          ErrorHandler.record_error_with_timestamp(
            %Req.TransportError{reason: :timeout},
            %{operation: "fetch_cases"},
            timestamp
          )
        end)
      end)

      trends = ErrorHandler.analyze_error_trends()

      assert trends.peak_hours == [9, 10, 11, 12, 13, 14, 15, 16, 17]
      # 1 error * 15 off-hours + 5 errors * 9 business hours
      assert trends.total_errors == 24 + 5 * 9
      assert trends.hourly_average > 1.0
      assert is_list(trends.common_patterns)
    end
  end

  describe "error boundaries and isolation" do
    test "isolates errors to prevent cascading failures" do
      error = %RuntimeError{message: "Subsystem failure"}
      context = %{subsystem: :sync_manager, isolation_level: :component}

      isolation_result = ErrorHandler.isolate_error(error, context)

      assert isolation_result.isolated == true
      assert isolation_result.affected_components == [:sync_manager]
      assert isolation_result.healthy_components == [:web_ui, :database, :config_manager]
      assert is_list(isolation_result.isolation_actions)
    end

    test "implements bulkhead pattern for resource protection" do
      error = %Req.TransportError{reason: :timeout}

      context = %{
        operation: "api_sync",
        resource_pool: :api_connections,
        pool_size: 10,
        active_connections: 8
      }

      bulkhead_result = ErrorHandler.apply_bulkhead_pattern(error, context)

      assert bulkhead_result.action == :limit_connections
      assert bulkhead_result.new_pool_limit == 5
      assert bulkhead_result.cooldown_period_ms > 0
      assert bulkhead_result.monitoring_enabled == true
    end

    test "implements timeout patterns for hanging operations" do
      start_time = System.monotonic_time(:millisecond)

      result =
        ErrorHandler.with_timeout(5000, fn ->
          # Simulate long-running operation
          :timer.sleep(100)
          {:ok, "completed"}
        end)

      end_time = System.monotonic_time(:millisecond)

      assert result == {:ok, "completed"}
      assert end_time - start_time < 5000
    end

    test "handles timeout errors gracefully" do
      result =
        ErrorHandler.with_timeout(100, fn ->
          # Simulate operation that exceeds timeout
          :timer.sleep(200)
          {:ok, "should_not_complete"}
        end)

      assert result == {:error, :timeout}
    end
  end
end
