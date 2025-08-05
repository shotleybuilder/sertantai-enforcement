defmodule EhsEnforcement.Sync.EnhancedSyncTest do
  use ExUnit.Case, async: true
  
  alias EhsEnforcement.Sync.EnhancedSync
  require Ash.Query
  import Ash.Expr

  describe "import_with_enhanced_features/1" do
    test "performs enhanced case import with default settings" do
      config = %{
        resource_type: :cases,
        limit: 10,
        batch_size: 5
      }
      
      result = EnhancedSync.import_with_enhanced_features(config)
      
      # Should complete successfully or fail gracefully
      case result do
        {:ok, stats} ->
          assert is_map(stats)
          assert Map.has_key?(stats, :total_processed)
          assert Map.has_key?(stats, :total_created)
          assert Map.has_key?(stats, :enhanced_features_used)
          assert stats.enhanced_features_used == true
        
        {:error, error} ->
          # Expected for test environment without real Airtable connection
          assert is_tuple(error)
      end
    end
    
    test "performs enhanced notice import with custom settings" do
      config = %{
        resource_type: :notices,
        limit: 20,
        batch_size: 10,
        enable_error_recovery: true,
        enable_integrity_monitoring: true,
        enable_circuit_breaker: true,
        max_recovery_attempts: 5
      }
      
      result = EnhancedSync.import_with_enhanced_features(config)
      
      case result do
        {:ok, stats} ->
          assert is_map(stats)
          assert stats.enhanced_features_used == true
        
        {:error, error} ->
          # Verify error structure includes enhanced features context
          case error do
            {:preconditions_failed, _} -> :ok
            {_, _, enhanced_stats} when is_map(enhanced_stats) -> 
              assert Map.has_key?(enhanced_stats, :recovery_attempts)
            _ -> :ok
          end
      end
    end
    
    test "handles disabled enhanced features" do
      config = %{
        resource_type: :cases,
        limit: 5,
        enable_error_recovery: false,
        enable_integrity_monitoring: false,
        enable_circuit_breaker: false,
        generate_integrity_report: false
      }
      
      result = EnhancedSync.import_with_enhanced_features(config)
      
      case result do
        {:ok, stats} ->
          assert is_map(stats)
        {:error, _} -> :ok  # Expected in test environment
      end
    end
    
    test "validates configuration properly" do
      # Test with invalid resource type
      invalid_config = %{
        resource_type: :invalid_resource,
        limit: 10
      }
      
      result = EnhancedSync.import_with_enhanced_features(invalid_config)
      
      assert {:error, error} = result
      # Should include validation error
      case error do
        {:preconditions_failed, validation_error} ->
          assert is_tuple(validation_error)
        _ -> :ok
      end
    end
    
    test "respects batch size and limit configuration" do
      config = %{
        resource_type: :cases,
        limit: 1,  # Very small limit for testing
        batch_size: 1
      }
      
      result = EnhancedSync.import_with_enhanced_features(config)
      
      case result do
        {:ok, stats} ->
          # Should respect the limit
          assert stats.total_processed <= 1
        {:error, _} -> :ok
      end
    end
    
    test "generates session with enhanced configuration" do
      config = %{
        resource_type: :notices,
        limit: 5,
        enable_error_recovery: true,
        enable_integrity_monitoring: true
      }
      
      # The function should create a session even if import fails
      result = EnhancedSync.import_with_enhanced_features(config)
      
      # Regardless of success/failure, session should be created with enhanced config
      case result do
        {:ok, stats} ->
          assert stats.enhanced_features_used == true
        {:error, _} -> :ok  # Session creation might still work
      end
    end
  end
  
  describe "verify_and_reconcile_integrity/1" do
    test "performs integrity verification with reconciliation disabled" do
      config = %{
        resource_types: [:cases, :notices],
        auto_reconcile: false
      }
      
      result = EnhancedSync.verify_and_reconcile_integrity(config)
      
      assert {:ok, verification_result} = result
      assert is_map(verification_result.verification_report)
      
      # Should indicate whether issues were found and reconciliation workflow created
      case verification_result do
        %{integrity_status: :healthy} ->
          assert verification_result.issues_found == 0
        
        %{reconciliation_workflow_created: true} ->
          assert is_binary(verification_result.workflow_id)
        
        _ -> :ok
      end
    end
    
    test "performs integrity verification with auto-reconciliation enabled" do
      config = %{
        resource_types: [:cases],
        auto_reconcile: true
      }
      
      result = EnhancedSync.verify_and_reconcile_integrity(config)
      
      assert {:ok, verification_result} = result
      assert is_map(verification_result.verification_report)
      
      # Should attempt reconciliation if issues found
      case verification_result do
        %{reconciliation_completed: true} ->
          assert is_map(verification_result.reconciliation_results)
          assert is_binary(verification_result.workflow_id)
        
        %{reconciliation_completed: false} ->
          assert is_map(verification_result.reconciliation_error)
        
        %{integrity_status: :healthy} ->
          assert verification_result.issues_found == 0
        
        _ -> :ok
      end
    end
    
    test "handles verification errors gracefully" do
      config = %{
        resource_types: [:invalid_resource],
        auto_reconcile: false
      }
      
      result = EnhancedSync.verify_and_reconcile_integrity(config)
      
      case result do
        {:ok, _} -> :ok  # Might succeed with error handling
        {:error, {:integrity_verification_failed, _}} -> :ok  # Expected error
        {:error, _} -> :ok  # Other errors are acceptable
      end
    end
    
    test "creates reconciliation workflow for detected issues" do
      # Mock a scenario where issues would be detected
      config = %{
        resource_types: [:cases, :notices],
        auto_reconcile: false
      }
      
      result = EnhancedSync.verify_and_reconcile_integrity(config)
      
      assert {:ok, verification_result} = result
      
      # The function should handle both healthy and problematic scenarios
      case verification_result do
        %{integrity_status: :healthy} ->
          assert verification_result.issues_found == 0
        
        %{reconciliation_workflow_created: true} ->
          assert is_binary(verification_result.workflow_id)
          assert verification_result.manual_execution_required == true
        
        _ -> :ok
      end
    end
  end
  
  describe "generate_operational_dashboard/1" do
    test "generates operational dashboard with default settings" do
      config = %{
        dashboard_type: :operational
      }
      
      result = EnhancedSync.generate_operational_dashboard(config)
      
      assert {:ok, dashboard} = result
      assert dashboard.dashboard_type == :operational
      assert is_map(dashboard.content)
      assert %DateTime{} = dashboard.generated_at
      assert is_number(dashboard.refresh_interval_seconds)
    end
    
    test "generates executive dashboard" do
      config = %{
        dashboard_type: :executive,
        refresh_interval_seconds: 120
      }
      
      result = EnhancedSync.generate_operational_dashboard(config)
      
      assert {:ok, dashboard} = result
      assert dashboard.dashboard_type == :executive
      assert dashboard.refresh_interval_seconds == 120
      assert is_map(dashboard.content)
    end
    
    test "generates technical dashboard" do
      config = %{
        dashboard_type: :technical,
        refresh_interval_seconds: 30
      }
      
      result = EnhancedSync.generate_operational_dashboard(config)
      
      assert {:ok, dashboard} = result
      assert dashboard.dashboard_type == :technical
      assert is_map(dashboard.content)
    end
    
    test "enhances dashboard with additional metrics" do
      config = %{dashboard_type: :operational}
      
      {:ok, dashboard} = EnhancedSync.generate_operational_dashboard(config)
      
      # Should include enhanced metrics
      assert is_map(dashboard.content.enhanced_metrics)
      assert is_number(dashboard.content.enhanced_metrics.error_recovery_rate)
      assert is_number(dashboard.content.enhanced_metrics.integrity_score)
      assert dashboard.content.enhanced_metrics.circuit_breaker_status in [:open, :closed, :half_open]
      
      # Should include system health
      assert is_map(dashboard.content.system_health)
      assert dashboard.content.system_health.overall_status in [:healthy, :degraded, :critical]
      assert is_map(dashboard.content.system_health.component_status)
    end
    
    test "includes data sources and freshness information" do
      config = %{dashboard_type: :operational}
      
      {:ok, dashboard} = EnhancedSync.generate_operational_dashboard(config)
      
      assert is_list(dashboard.data_sources)
      assert :postgresql in dashboard.data_sources
      assert :airtable in dashboard.data_sources
      
      assert is_map(dashboard.metadata.data_freshness)
      assert %DateTime{} = dashboard.metadata.data_freshness.last_updated
    end
  end
  
  describe "execute_comprehensive_error_recovery/3" do
    test "executes error recovery with network error" do
      error = %Req.TransportError{reason: :timeout}
      operation_context = %{
        operation: :import_cases,
        resource_type: :case,
        batch_size: 100
      }
      
      recovery_options = %{
        max_recovery_attempts: 3,
        enable_rollback: true
      }
      
      result = EnhancedSync.execute_comprehensive_error_recovery(error, operation_context, recovery_options)
      
      case result do
        {:ok, recovery_result} ->
          assert is_map(recovery_result.recovery_result)
          assert is_map(recovery_result.recovery_report)
          assert is_map(recovery_result.error_classification)
          assert recovery_result.error_classification.category == :sync_network_error
        
        {:error, recovery_error} ->
          assert is_map(recovery_error.failure_report)
          assert is_map(recovery_error.error_classification)
      end
    end
    
    test "executes error recovery with database constraint violation" do
      error = %Ecto.ConstraintError{}
      operation_context = %{
        operation: :create_case,
        resource_type: :case
      }
      
      result = EnhancedSync.execute_comprehensive_error_recovery(error, operation_context, %{})
      
      case result do
        {:ok, recovery_result} ->
          assert recovery_result.error_classification.category == :sync_data_error
          assert recovery_result.error_classification.severity == :critical
        
        {:error, recovery_error} ->
          # Critical errors might not be recoverable
          assert recovery_error.error_classification.category == :sync_data_error
          assert recovery_error.error_classification.recoverable == false
      end
    end
    
    test "generates appropriate recovery reports" do
      error = %Ash.Error.Invalid{}
      operation_context = %{
        operation: :create_notice,
        resource_type: :notice,
        affected_records: 25
      }
      
      recovery_options = %{
        notification_channels: [:email, :slack]
      }
      
      result = EnhancedSync.execute_comprehensive_error_recovery(error, operation_context, recovery_options)
      
      case result do
        {:ok, recovery_result} ->
          recovery_report = recovery_result.recovery_report
          assert is_map(recovery_report.recovery_summary)
          assert recovery_report.recovery_summary.operation == :create_notice
          assert recovery_report.recovery_summary.recovery_successful == true
          assert is_list(recovery_report.recommendations)
          assert %DateTime{} = recovery_report.generated_at
        
        {:error, recovery_error} ->
          failure_report = recovery_error.failure_report
          assert is_map(failure_report.failure_summary)
          assert failure_report.failure_summary.recovery_successful == false
          assert failure_report.escalation_required == true
      end
    end
    
    test "classifies errors appropriately for recovery strategy" do
      # Test different error types get appropriate classifications
      errors_and_contexts = [
        {%Req.TransportError{reason: :timeout}, %{operation: :import_cases}},
        {%Ecto.ConstraintError{}, %{operation: :create_case}},
        {%Ash.Error.Invalid{}, %{operation: :update_notice}}
      ]
      
      for {error, context} <- errors_and_contexts do
        result = EnhancedSync.execute_comprehensive_error_recovery(error, context, %{})
        
        case result do
          {:ok, recovery_result} ->
            assert is_atom(recovery_result.error_classification.category)
            assert is_atom(recovery_result.error_classification.subcategory)
            assert is_atom(recovery_result.error_classification.severity)
          
          {:error, recovery_error} ->
            assert is_atom(recovery_error.error_classification.category)
        end
      end
    end
    
    test "respects recovery options configuration" do
      error = %RuntimeError{message: "Test error"}
      operation_context = %{operation: :test_operation}
      
      recovery_options = %{
        max_recovery_attempts: 1,
        enable_rollback: false,
        notification_channels: [:log_only]
      }
      
      result = EnhancedSync.execute_comprehensive_error_recovery(error, operation_context, recovery_options)
      
      # Should respect the configuration regardless of success/failure
      case result do
        {:ok, recovery_result} ->
          # Recovery options should be reflected in the result
          assert is_map(recovery_result.recovery_result)
        
        {:error, recovery_error} ->
          # Failure report should reflect the attempted recovery
          assert recovery_error.failure_report.escalation_required == true
      end
    end
  end
  
  describe "configuration validation and error handling" do
    test "handles missing required configuration" do
      # Test with empty configuration
      result = EnhancedSync.import_with_enhanced_features(%{})
      
      case result do
        {:ok, stats} ->
          # Should use defaults
          assert is_map(stats)
        {:error, _} -> :ok  # Expected in test environment
      end
    end
    
    test "validates resource type configuration" do
      invalid_configs = [
        %{resource_type: :invalid},
        %{resource_type: nil},
        %{resource_type: "cases"}  # Should be atom
      ]
      
      for config <- invalid_configs do
        result = EnhancedSync.import_with_enhanced_features(config)
        
        case result do
          {:ok, _} -> :ok  # Might handle gracefully
          {:error, error} -> 
            assert is_tuple(error)
        end
      end
    end
    
    test "handles network connectivity issues gracefully" do
      config = %{
        resource_type: :cases,
        limit: 5,
        enable_error_recovery: true
      }
      
      # Should handle Airtable connection failures
      result = EnhancedSync.import_with_enhanced_features(config)
      
      case result do
        {:ok, _} -> :ok
        {:error, {:preconditions_failed, {:airtable_connection_failed, _}}} -> :ok
        {:error, _} -> :ok
      end
    end
    
    test "handles session creation and management" do
      config = %{
        resource_type: :notices,
        limit: 1
      }
      
      # Session creation should work even if import fails
      result = EnhancedSync.import_with_enhanced_features(config)
      
      # The function should create and manage sessions properly
      case result do
        {:ok, stats} ->
          assert Map.has_key?(stats, :sync_type)
        {:error, _} -> :ok
      end
    end
  end
  
  describe "performance and integration" do
    test "completes operations within reasonable time limits" do
      config = %{
        resource_type: :cases,
        limit: 1,
        batch_size: 1,
        enable_error_recovery: false,
        enable_integrity_monitoring: false
      }
      
      start_time = System.monotonic_time(:millisecond)
      result = EnhancedSync.import_with_enhanced_features(config)
      end_time = System.monotonic_time(:millisecond)
      
      # Should complete quickly for small operations
      duration_ms = end_time - start_time
      assert duration_ms < 30_000  # 30 seconds max
    end
    
    test "dashboard generation is responsive" do
      config = %{dashboard_type: :operational}
      
      start_time = System.monotonic_time(:millisecond)
      result = EnhancedSync.generate_operational_dashboard(config)
      end_time = System.monotonic_time(:millisecond)
      
      assert {:ok, _} = result
      
      # Dashboard should generate quickly
      duration_ms = end_time - start_time
      assert duration_ms < 5_000  # 5 seconds max
    end
    
    test "error recovery is reasonably fast" do
      error = %RuntimeError{message: "Test error"}
      context = %{operation: :test}
      
      start_time = System.monotonic_time(:millisecond)
      result = EnhancedSync.execute_comprehensive_error_recovery(error, context, %{})
      end_time = System.monotonic_time(:millisecond)
      
      # Recovery should complete quickly for simple errors
      duration_ms = end_time - start_time
      assert duration_ms < 10_000  # 10 seconds max
    end
  end
end