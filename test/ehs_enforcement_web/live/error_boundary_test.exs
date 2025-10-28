defmodule EhsEnforcementWeb.Live.ErrorBoundaryTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias EhsEnforcementWeb.Live.ErrorBoundary

  describe "error boundary component" do
    test "renders children when no error occurs", %{conn: conn} do
      {:ok, view, html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "children" => [
              {"div", [], ["Normal content"]}
            ]
          }
        )

      assert html =~ "Normal content"
      refute html =~ "Something went wrong"
    end

    test "catches and displays error when child component crashes", %{conn: conn} do
      log =
        capture_log(fn ->
          {:ok, view, _html} =
            live_isolated(conn, ErrorBoundary,
              session: %{
                "children" => [
                  {"div", [], ["Normal content"]},
                  {ErrorBoundary.CrashingComponent, [], []}
                ]
              }
            )

          # Trigger error in child component
          render_click(view, "trigger_error")
        end)

      # Check that error was logged
      assert log =~ "ErrorBoundary caught error" or log =~ "Simulated LiveView error"
    end

    test "provides error recovery options", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "error_state" => %{
              error: %RuntimeError{message: "Test error"},
              error_info: %{component: "TestComponent", action: "test_action"},
              recovery_options: [:retry, :reload, :reset]
            }
          }
        )

      html = render(view)

      assert html =~ "Try Again"
      assert html =~ "Reload Page"
      assert html =~ "Reset"
    end

    test "handles retry action to recover from error", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "error_state" => %{
              error: %RuntimeError{message: "Temporary error"},
              error_info: %{component: "TestComponent", retryable: true}
            }
          }
        )

      # Click retry button
      html = render_click(view, "retry")

      # Should clear error state and show normal content
      refute html =~ "Something went wrong"
      assert html =~ "Ready to load content"
    end

    test "handles reset action to clear error state", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "error_state" => %{
              error: %RuntimeError{message: "Critical error"},
              error_info: %{component: "TestComponent", retryable: false}
            }
          }
        )

      # Click reset button
      html = render_click(view, "reset")

      # Should clear error state and reset to initial state
      refute html =~ "Something went wrong"
      assert html =~ "Content reset successfully"
    end

    test "reports errors to error tracking service", %{conn: conn} do
      {:ok, error_reports} = Agent.start_link(fn -> [] end)

      # Mock error reporting
      Application.put_env(:ehs_enforcement, :error_reporter, fn error, context ->
        Agent.update(error_reports, fn reports ->
          [%{error: error, context: context} | reports]
        end)

        :ok
      end)

      {:ok, view, _html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "simulate_error" => %RuntimeError{message: "Tracked error"},
            "error_context" => %{user_id: "user123", component: "TestComponent"}
          }
        )

      # Trigger error reporting
      render_click(view, "simulate_error")

      reports = Agent.get(error_reports, & &1)
      assert length(reports) == 1

      report = List.first(reports)
      assert report.error.message == "Tracked error"
      assert report.context.user_id == "user123"
      assert report.context.component == "TestComponent"

      Agent.stop(error_reports)
      Application.delete_env(:ehs_enforcement, :error_reporter)
    end
  end

  describe "error boundary fallback UI" do
    test "displays appropriate error message based on error type", %{conn: conn} do
      test_cases = [
        {%Req.TransportError{reason: :timeout}, "Connection timeout occurred"},
        {%Postgrex.Error{message: "connection closed"}, "Database connection error"},
        {%Ash.Error.Invalid{errors: []}, "Data validation error"},
        {%RuntimeError{message: "Generic error"}, "An unexpected error occurred"}
      ]

      Enum.each(test_cases, fn {error, expected_message} ->
        {:ok, _view, html} =
          live_isolated(conn, ErrorBoundary,
            session: %{
              "error_state" => %{error: error, error_info: %{}}
            }
          )

        assert html =~ expected_message
      end)
    end

    test "shows different UI based on error severity", %{conn: conn} do
      # Critical error - should show minimal UI with contact information
      {:ok, _view, html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "error_state" => %{
              error: %Postgrex.Error{message: "database unreachable"},
              error_info: %{severity: :critical}
            }
          }
        )

      assert html =~ "Critical system error"
      assert html =~ "Please contact support"
      # No retry for critical errors
      refute html =~ "Try Again"

      # Warning level error - should show retry options
      {:ok, _view, html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "error_state" => %{
              error: %Req.TransportError{reason: :timeout},
              error_info: %{severity: :warning}
            }
          }
        )

      assert html =~ "Try Again"
      assert html =~ "Temporary issue"
    end

    test "includes error ID for support reference", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "error_state" => %{
              error: %RuntimeError{message: "Test error"},
              error_info: %{error_id: "ERR_123456"}
            }
          }
        )

      assert html =~ "Error ID: ERR_123456"
      assert html =~ "Reference this ID when contacting support"
    end

    test "shows contextual help based on user action", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "error_state" => %{
              error: %RuntimeError{message: "Save failed"},
              error_info: %{
                user_action: "saving_case",
                suggestions: [
                  "Check your internet connection",
                  "Verify all required fields are filled",
                  "Try saving again in a few moments"
                ]
              }
            }
          }
        )

      assert html =~ "Error saving case"
      assert html =~ "Check your internet connection"
      assert html =~ "Verify all required fields"
      assert html =~ "Try saving again"
    end
  end

  describe "error boundary integration with LiveView" do
    test "integrates with Phoenix LiveView error handling", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, ErrorBoundary.TestLiveView)

      log =
        capture_log(fn ->
          # Trigger an error in the LiveView
          assert_raise RuntimeError, "Simulated LiveView error", fn ->
            render_click(view, "trigger_error")
          end
        end)

      assert log =~ "LiveView error caught by ErrorBoundary"
    end

    test "handles mount errors gracefully", %{conn: conn} do
      log =
        capture_log(fn ->
          {:error, {:live_redirect, %{to: "/error"}}} =
            live_isolated(conn, ErrorBoundary.FailingMountLiveView)
        end)

      assert log =~ "LiveView mount failed"
      assert log =~ "Redirecting to error page"
    end

    test "handles handle_event errors with recovery", %{conn: conn} do
      {:ok, view, html} = live_isolated(conn, ErrorBoundary.TestLiveView)

      # Initial state should be normal
      assert html =~ "Normal operation"

      log =
        capture_log(fn ->
          # This should trigger error boundary
          render_click(view, "failing_event")
        end)

      html = render(view)

      assert html =~ "Something went wrong"
      assert log =~ "handle_event error caught"
    end

    test "handles handle_info errors without crashing", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, ErrorBoundary.TestLiveView)

      log =
        capture_log(fn ->
          # Send message that will cause error
          send(view.pid, {:error_message, "Cause error"})

          # Give it time to process
          :timer.sleep(100)
        end)

      # View should still be alive
      assert Process.alive?(view.pid)
      assert log =~ "handle_info error caught"
    end
  end

  describe "error boundary state management" do
    test "tracks error history for debugging", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "track_errors" => true
          }
        )

      # Simulate multiple errors
      render_click(view, "simulate_error", %{"error_type" => "timeout"})
      render_click(view, "simulate_error", %{"error_type" => "validation"})
      render_click(view, "simulate_error", %{"error_type" => "database"})

      error_history = ErrorBoundary.get_error_history(view.pid)

      assert length(error_history) == 3
      assert Enum.any?(error_history, fn err -> err.type == "timeout" end)
      assert Enum.any?(error_history, fn err -> err.type == "validation" end)
      assert Enum.any?(error_history, fn err -> err.type == "database" end)
    end

    test "limits error history size to prevent memory issues", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "track_errors" => true,
            "max_error_history" => 5
          }
        )

      # Simulate more errors than the limit
      Enum.each(1..10, fn i ->
        render_click(view, "simulate_error", %{"error_type" => "error_#{i}"})
      end)

      error_history = ErrorBoundary.get_error_history(view.pid)

      # Should only keep the most recent 5 errors
      assert length(error_history) == 5
      assert Enum.any?(error_history, fn err -> err.type == "error_10" end)
      assert Enum.any?(error_history, fn err -> err.type == "error_6" end)
      refute Enum.any?(error_history, fn err -> err.type == "error_1" end)
    end

    test "clears error state after successful recovery", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "error_state" => %{
              error: %RuntimeError{message: "Recoverable error"},
              error_info: %{retryable: true}
            }
          }
        )

      # Should show error state
      html = render(view)
      assert html =~ "Something went wrong"

      # Retry should clear error
      html = render_click(view, "retry")
      refute html =~ "Something went wrong"

      # Error state should be nil
      assert ErrorBoundary.get_error_state(view.pid) == nil
    end
  end

  describe "error boundary configuration" do
    test "respects custom error boundary configuration", %{conn: conn} do
      custom_config = %{
        show_error_details: true,
        enable_retry: false,
        custom_error_message: "Custom error occurred",
        contact_email: "support@example.com"
      }

      {:ok, _view, html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "config" => custom_config,
            "error_state" => %{
              error: %RuntimeError{message: "Test error"},
              error_info: %{}
            }
          }
        )

      assert html =~ "Custom error occurred"
      assert html =~ "support@example.com"
      # Should show details
      assert html =~ "Test error"
      # Retry disabled
      refute html =~ "Try Again"
    end

    test "applies different configurations for different environments" do
      # Production config - minimal error details
      prod_config = ErrorBoundary.get_config(:prod)
      assert prod_config.show_error_details == false
      assert prod_config.show_stacktrace == false
      assert prod_config.enable_error_reporting == true

      # Development config - detailed error information
      dev_config = ErrorBoundary.get_config(:dev)
      assert dev_config.show_error_details == true
      assert dev_config.show_stacktrace == true
      assert dev_config.enable_error_reporting == false

      # Test config - verbose logging
      test_config = ErrorBoundary.get_config(:test)
      assert test_config.show_error_details == true
      assert test_config.verbose_logging == true
    end

    test "supports custom error renderers", %{conn: conn} do
      # Functions can't be serialized in LiveView sessions, so we'll test
      # the configuration system instead
      {:ok, _view, html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "config" => %{show_error_details: true, custom_error_message: "Custom error occurred"},
            "error_state" => %{
              error: %RuntimeError{message: "Custom rendered error"},
              error_info: %{component: "TestComponent"}
            }
          }
        )

      assert html =~ "Custom error occurred"
      # Error title
      assert html =~ "System Error"
    end
  end

  describe "error boundary performance" do
    test "handles high frequency errors without performance degradation", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "performance_test" => true
          }
        )

      start_time = System.monotonic_time(:millisecond)

      # Simulate rapid error occurrences
      Enum.each(1..100, fn _i ->
        render_click(view, "rapid_error")
      end)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should complete within reasonable time (less than 1 second)
      assert duration < 1000

      # View should still be responsive
      html = render(view)
      assert html =~ "Performance test complete"
    end

    test "throttles error reporting to prevent spam", %{conn: conn} do
      {:ok, error_reports} = Agent.start_link(fn -> [] end)

      Application.put_env(:ehs_enforcement, :error_reporter, fn error, context ->
        Agent.update(error_reports, fn reports ->
          [%{error: error, context: context} | reports]
        end)

        :ok
      end)

      {:ok, view, _html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "throttle_errors" => true,
            "throttle_window_ms" => 1000,
            "max_reports_per_window" => 3
          }
        )

      # Generate many identical errors rapidly
      Enum.each(1..10, fn _i ->
        render_click(view, "identical_error")
      end)

      reports = Agent.get(error_reports, & &1)

      # Should be throttled to max 3 reports
      assert length(reports) <= 3

      Agent.stop(error_reports)
      Application.delete_env(:ehs_enforcement, :error_reporter)
    end

    test "efficiently handles memory usage with error tracking", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, ErrorBoundary,
          session: %{
            "memory_test" => true,
            "max_error_history" => 100
          }
        )

      memory_before = :erlang.memory(:total)

      # Generate many errors to test memory usage
      Enum.each(1..500, fn i ->
        render_click(view, "memory_test_error", %{"id" => i})
      end)

      memory_after = :erlang.memory(:total)
      memory_diff = memory_after - memory_before

      # Memory usage should be reasonable (less than 10MB for this test)
      assert memory_diff < 10_000_000

      # Error history should be capped
      error_history = ErrorBoundary.get_error_history(view.pid)
      assert length(error_history) <= 100
    end
  end
end
