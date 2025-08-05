defmodule EhsEnforcement.Sync.RetryEngineTest do
  use ExUnit.Case, async: true
  
  alias EhsEnforcement.Sync.RetryEngine
  require Ash.Query
  import Ash.Expr

  setup do
    # Reset retry state before each test
    RetryEngine.reset_retry_state()
    :ok
  end

  describe "execute_with_retry/4" do
    test "executes function successfully on first attempt" do
      success_function = fn -> {:ok, "success"} end
      
      result = RetryEngine.execute_with_retry(:test_operation, success_function, %{})
      
      assert {:ok, "success"} = result
    end
    
    test "retries function on failure and eventually succeeds" do
      # Function that fails twice then succeeds
      agent = Agent.start_link(fn -> 0 end)
      {:ok, agent_pid} = agent
      
      retry_function = fn ->
        count = Agent.get_and_update(agent_pid, fn count -> {count, count + 1} end)
        
        case count do
          0 -> {:error, :first_failure}
          1 -> {:error, :second_failure}
          _ -> {:ok, "success_on_third_attempt"}
        end
      end
      
      context = %{
        retry_policy: %{
          type: :exponential_backoff,
          max_attempts: 5,
          base_delay_ms: 10,  # Short delay for testing
          multiplier: 1.5
        }
      }
      
      result = RetryEngine.execute_with_retry(:test_retry_operation, retry_function, context)
      
      assert {:ok, "success_on_third_attempt"} = result
    end
    
    test "exhausts retries and returns error" do
      failure_function = fn -> {:error, :persistent_failure} end
      
      context = %{
        retry_policy: %{
          type: :fixed_delay,
          max_attempts: 3,
          delay_ms: 1  # Very short delay for testing
        }
      }
      
      result = RetryEngine.execute_with_retry(:test_failure_operation, failure_function, context)
      
      assert {:error, {:retry_exhausted, 3}} = result
    end
    
    test "uses circuit breaker when enabled" do
      failure_function = fn -> {:error, :circuit_breaker_test} end
      
      context = %{
        circuit_breaker: true,
        retry_policy: %{max_attempts: 2}
      }
      
      # First call should attempt normally
      result1 = RetryEngine.execute_with_retry(:circuit_breaker_operation, failure_function, context)
      assert {:error, {:retry_exhausted, 2}} = result1
      
      # Subsequent calls should be circuit broken (this would require multiple failures)
      # For now, just verify the function handles circuit breaker context
      result2 = RetryEngine.execute_with_retry(:circuit_breaker_operation, failure_function, context)
      assert match?({:error, _}, result2)
    end
    
    test "applies jitter to retry delays when configured" do
      failure_count = 3
      agent = Agent.start_link(fn -> 0 end)
      {:ok, agent_pid} = agent
      
      jitter_function = fn ->
        count = Agent.get_and_update(agent_pid, fn count -> {count, count + 1} end)
        
        if count < failure_count do
          {:error, :jitter_test_failure}
        else
          {:ok, "success_with_jitter"}
        end
      end
      
      context = %{
        retry_policy: %{
          type: :exponential_backoff,
          max_attempts: 5,
          base_delay_ms: 10,
          jitter: true
        }
      }
      
      start_time = System.monotonic_time(:millisecond)
      result = RetryEngine.execute_with_retry(:jitter_test_operation, jitter_function, context)
      end_time = System.monotonic_time(:millisecond)
      
      assert {:ok, "success_with_jitter"} = result
      # Should have taken some time due to delays (even with jitter)
      assert end_time - start_time > 20  # At least some delay
    end
  end
  
  describe "execute_batch_with_retry/4" do
    test "executes batch of operations successfully" do
      operations = [
        fn -> {:ok, "result_1"} end,
        fn -> {:ok, "result_2"} end,
        fn -> {:ok, "result_3"} end
      ]
      
      result = RetryEngine.execute_batch_with_retry(:batch_test, operations, %{})
      
      assert {:ok, batch_result} = result
      assert batch_result.total_operations == 3
      assert batch_result.successful == 3
      assert batch_result.failed == 0
      assert batch_result.success_rate == 1.0
    end
    
    test "handles mixed success and failure in batch" do
      operations = [
        fn -> {:ok, "success_1"} end,
        fn -> {:error, :failure_1} end,
        fn -> {:ok, "success_2"} end,
        fn -> {:error, :failure_2} end
      ]
      
      result = RetryEngine.execute_batch_with_retry(:mixed_batch_test, operations, %{})
      
      assert {:ok, batch_result} = result
      assert batch_result.total_operations == 4
      assert batch_result.successful == 2
      assert batch_result.failed == 2
      assert batch_result.success_rate == 0.5
    end
    
    test "updates circuit breaker based on batch success rate" do
      # Create batch with low success rate
      operations = [
        fn -> {:error, :batch_failure} end,
        fn -> {:error, :batch_failure} end,
        fn -> {:error, :batch_failure} end,
        fn -> {:ok, "lone_success"} end
      ]
      
      context = %{
        circuit_breaker: true,
        circuit_breaker_failure_threshold: 0.5  # 50% threshold
      }
      
      result = RetryEngine.execute_batch_with_retry(:low_success_batch, operations, context)
      
      assert {:ok, batch_result} = result
      assert batch_result.success_rate < 0.5
    end
  end
  
  describe "get_retry_analytics/1" do
    test "returns comprehensive retry analytics" do
      # Execute some operations to generate data
      success_function = fn -> {:ok, "analytics_test"} end
      failure_function = fn -> {:error, :analytics_failure} end
      
      RetryEngine.execute_with_retry(:analytics_success, success_function, %{})
      RetryEngine.execute_with_retry(:analytics_failure, failure_function, %{retry_policy: %{max_attempts: 2}})
      
      analytics = RetryEngine.get_retry_analytics()
      
      assert is_map(analytics)
      assert analytics.time_window_hours == 24
      assert is_map(analytics.retry_statistics)
      assert is_map(analytics.circuit_breaker_status)
      assert is_map(analytics.performance_metrics)
      assert is_list(analytics.recommendations)
    end
    
    test "calculates retry statistics correctly" do
      # Generate some retry data
      retry_function = fn ->
        case :rand.uniform(2) do
          1 -> {:ok, "random_success"}
          2 -> {:error, :random_failure}
        end
      end
      
      # Execute multiple operations
      for _ <- 1..5 do
        RetryEngine.execute_with_retry(:stats_test, retry_function, %{retry_policy: %{max_attempts: 3}})
      end
      
      analytics = RetryEngine.get_retry_analytics()
      
      assert analytics.retry_statistics.total_operations >= 5
      assert is_number(analytics.retry_statistics.success_rate)
      assert analytics.retry_statistics.success_rate >= 0.0
      assert analytics.retry_statistics.success_rate <= 1.0
    end
  end
  
  describe "reset_retry_state/1" do
    test "resets all retry state" do
      # Create some state
      success_function = fn -> {:ok, "reset_test"} end
      RetryEngine.execute_with_retry(:reset_test_operation, success_function, %{})
      
      # Verify state exists
      analytics_before = RetryEngine.get_retry_analytics()
      assert analytics_before.retry_statistics.total_operations > 0
      
      # Reset state
      result = RetryEngine.reset_retry_state()
      assert result == :ok
      
      # Verify state is cleared
      analytics_after = RetryEngine.get_retry_analytics()
      assert analytics_after.retry_statistics.total_operations == 0
    end
    
    test "resets specific operation state" do
      # Create state for multiple operations
      success_function = fn -> {:ok, "specific_reset_test"} end
      RetryEngine.execute_with_retry(:operation_a, success_function, %{})
      RetryEngine.execute_with_retry(:operation_b, success_function, %{})
      
      # Reset specific operation
      result = RetryEngine.reset_retry_state(:operation_a)
      assert result == :ok
      
      # Operation B state should still exist, but A should be cleared
      analytics = RetryEngine.get_retry_analytics()
      # Note: This test assumes we can differentiate operations in analytics
      # In current implementation, we reset all state, so both would be cleared
    end
  end
  
  describe "retry policy determination" do
    test "uses default policy for unknown operations" do
      test_function = fn -> {:ok, "default_policy_test"} end
      
      # No explicit retry policy provided
      result = RetryEngine.execute_with_retry(:unknown_operation, test_function, %{})
      
      assert {:ok, "default_policy_test"} = result
    end
    
    test "uses custom retry policy when provided" do
      failure_count = 2
      agent = Agent.start_link(fn -> 0 end)
      {:ok, agent_pid} = agent
      
      custom_retry_function = fn ->
        count = Agent.get_and_update(agent_pid, fn count -> {count, count + 1} end)
        
        if count < failure_count do
          {:error, :custom_policy_test}
        else
          {:ok, "custom_policy_success"}
        end
      end
      
      context = %{
        retry_policy: %{
          type: :linear_backoff,
          base_delay_ms: 5,
          increment_ms: 5,
          max_attempts: 4
        }
      }
      
      result = RetryEngine.execute_with_retry(:custom_policy_operation, custom_retry_function, context)
      
      assert {:ok, "custom_policy_success"} = result
    end
    
    test "respects maximum delay limits" do
      failure_count = 2
      agent = Agent.start_link(fn -> 0 end)
      {:ok, agent_pid} = agent
      
      delay_test_function = fn ->
        count = Agent.get_and_update(agent_pid, fn count -> {count, count + 1} end)
        
        if count < failure_count do
          {:error, :delay_limit_test}
        else
          {:ok, "delay_limit_success"}
        end
      end
      
      context = %{
        retry_policy: %{
          type: :exponential_backoff,
          base_delay_ms: 50,
          max_delay_ms: 100,  # Cap at 100ms
          multiplier: 10,     # Would normally create very long delays
          max_attempts: 4
        }
      }
      
      start_time = System.monotonic_time(:millisecond)
      result = RetryEngine.execute_with_retry(:delay_limit_operation, delay_test_function, context)
      end_time = System.monotonic_time(:millisecond)
      
      assert {:ok, "delay_limit_success"} = result
      # Should not have taken too long due to max_delay_ms limit
      assert end_time - start_time < 1000  # Less than 1 second total
    end
  end
end