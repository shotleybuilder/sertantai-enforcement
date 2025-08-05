defmodule EhsEnforcement.Sync.IntegrityVerifierTest do
  use ExUnit.Case, async: true
  
  alias EhsEnforcement.Sync.IntegrityVerifier
  require Ash.Query
  import Ash.Expr

  describe "verify_data_integrity/2" do
    test "performs count-only verification successfully" do
      options = %{
        resource_types: [:cases, :notices],
        verification_scope: :all
      }
      
      result = IntegrityVerifier.verify_data_integrity(:count_only, options)
      
      assert {:ok, verification_report} = result
      assert verification_report.verification_summary.verification_type == :count_only
      assert is_map(verification_report.detailed_results)
      assert Map.has_key?(verification_report.detailed_results, :cases)
      assert Map.has_key?(verification_report.detailed_results, :notices)
      assert is_number(verification_report.integrity_score)
    end
    
    test "performs full integrity verification" do
      options = %{
        resource_types: [:cases],
        detailed_field_comparison: true
      }
      
      result = IntegrityVerifier.verify_data_integrity(:full, options)
      
      assert {:ok, verification_report} = result
      assert verification_report.verification_summary.verification_type == :full
      assert is_list(verification_report.count_discrepancies)
      assert is_list(verification_report.missing_records)
      assert is_list(verification_report.field_mismatches)
      
      # Should include recommendations
      assert is_list(verification_report.recommendations)
    end
    
    test "performs sample verification with specified sample size" do
      options = %{
        resource_types: [:notices],
        sample_size: 50
      }
      
      result = IntegrityVerifier.verify_data_integrity(:sample, options)
      
      assert {:ok, verification_report} = result
      assert verification_report.verification_summary.verification_type == :sample
      
      # Sample verification should have sample-specific results
      case verification_report.detailed_results[:notices] do
        {:ok, sample_results} ->
          assert is_number(sample_results.sample_size)
          assert sample_results.sample_size <= 50
          assert is_number(sample_results.verification_rate)
        
        _ ->
          # Sample results structure may vary
          assert is_map(verification_report.detailed_results[:notices])
      end
    end
    
    test "handles verification errors gracefully" do
      # Test with invalid resource type
      options = %{
        resource_types: [:invalid_resource]
      }
      
      result = IntegrityVerifier.verify_data_integrity(:count_only, options)
      
      # Should handle error gracefully
      case result do
        {:ok, _} -> :ok  # If it succeeds despite invalid resource, that's fine
        {:error, error} -> assert is_tuple(error)
      end
    end
    
    test "generates appropriate integrity scores" do
      options = %{resource_types: [:cases, :notices]}
      
      {:ok, verification_report} = IntegrityVerifier.verify_data_integrity(:count_only, options)
      
      assert is_number(verification_report.integrity_score)
      assert verification_report.integrity_score >= 0
      assert verification_report.integrity_score <= 100
      
      # Overall status should be determined based on integrity score
      assert verification_report.verification_summary.overall_status in [
        :excellent, :good, :acceptable, :concerning, :critical
      ]
    end
    
    test "includes metadata in verification report" do
      options = %{resource_types: [:cases]}
      
      {:ok, verification_report} = IntegrityVerifier.verify_data_integrity(:count_only, options)
      
      assert is_map(verification_report.metadata)
      assert %DateTime{} = verification_report.metadata.generated_at
      assert verification_report.metadata.verification_type == :count_only
      assert verification_report.metadata.options_used == options
    end
  end
  
  describe "monitor_sync_integrity/2" do
    test "starts integrity monitoring successfully" do
      session_id = "test_session_#{:rand.uniform(1000)}"
      monitoring_options = %{
        check_interval_seconds: 1,  # Very frequent for testing
        alert_threshold_percentage: 10.0
      }
      
      result = IntegrityVerifier.monitor_sync_integrity(session_id, monitoring_options)
      
      assert {:ok, monitoring_info} = result
      assert is_pid(monitoring_info.monitoring_pid)
      assert monitoring_info.config.check_interval_seconds == 1
      assert monitoring_info.config.alert_threshold_percentage == 10.0
    end
    
    test "monitoring configuration is properly set" do
      session_id = "test_session_#{:rand.uniform(1000)}"
      monitoring_options = %{
        check_interval_seconds: 30,
        alert_threshold_percentage: 5.0,
        auto_correction: true,
        detailed_logging: false
      }
      
      {:ok, monitoring_info} = IntegrityVerifier.monitor_sync_integrity(session_id, monitoring_options)
      
      assert monitoring_info.config.check_interval_seconds == 30
      assert monitoring_info.config.alert_threshold_percentage == 5.0
      assert monitoring_info.config.auto_correction == true
      assert monitoring_info.config.detailed_logging == false
    end
    
    test "uses default monitoring configuration when options not provided" do
      session_id = "test_session_#{:rand.uniform(1000)}"
      
      {:ok, monitoring_info} = IntegrityVerifier.monitor_sync_integrity(session_id, %{})
      
      # Should use default values
      assert monitoring_info.config.check_interval_seconds == 30
      assert monitoring_info.config.alert_threshold_percentage == 5.0
      assert monitoring_info.config.auto_correction == false
    end
  end
  
  describe "reconcile_integrity_issues/2" do
    test "reconciles count discrepancies" do
      integrity_report = %{
        count_discrepancies: [
          {:cases, %{postgresql_count: 100, airtable_count: 105, count_discrepancy: 5}}
        ],
        missing_records: [],
        field_mismatches: []
      }
      
      reconciliation_options = %{
        auto_fix: false,
        dry_run: true
      }
      
      result = IntegrityVerifier.reconcile_integrity_issues(integrity_report, reconciliation_options)
      
      assert {:ok, reconciliation_summary} = result
      assert reconciliation_summary.total_issues == 1
      assert reconciliation_summary.dry_run == true
      assert is_map(reconciliation_summary.reconciliation_results)
      assert %DateTime{} = reconciliation_summary.reconciled_at
    end
    
    test "reconciles missing records" do
      integrity_report = %{
        count_discrepancies: [],
        missing_records: [
          "case_123", "case_456", "notice_789"
        ],
        field_mismatches: []
      }
      
      reconciliation_options = %{
        auto_fix: true,
        dry_run: false
      }
      
      result = IntegrityVerifier.reconcile_integrity_issues(integrity_report, reconciliation_options)
      
      assert {:ok, reconciliation_summary} = result
      assert reconciliation_summary.total_issues == 3
      assert reconciliation_summary.dry_run == false
      assert is_number(reconciliation_summary.resolution_rate)
    end
    
    test "handles multiple types of integrity issues" do
      integrity_report = %{
        count_discrepancies: [
          {:cases, %{count_discrepancy: 2}}
        ],
        missing_records: ["record_1", "record_2"],
        field_mismatches: [
          %{record_id: "case_1", field: "status", expected: "active", actual: "pending"}
        ]
      }
      
      result = IntegrityVerifier.reconcile_integrity_issues(integrity_report, %{})
      
      assert {:ok, reconciliation_summary} = result
      assert reconciliation_summary.total_issues == 4  # 1 + 2 + 1
      assert is_map(reconciliation_summary.reconciliation_results.count_reconciliation)
      assert is_map(reconciliation_summary.reconciliation_results.missing_record_reconciliation)
      assert is_map(reconciliation_summary.reconciliation_results.field_reconciliation)
    end
    
    test "calculates resolution rate correctly" do
      integrity_report = %{
        count_discrepancies: [],
        missing_records: [],
        field_mismatches: []
      }
      
      result = IntegrityVerifier.reconcile_integrity_issues(integrity_report, %{})
      
      assert {:ok, reconciliation_summary} = result
      assert reconciliation_summary.total_issues == 0
      assert reconciliation_summary.resolution_rate == 1.0  # 100% when no issues
    end
  end
  
  describe "analyze_integrity_trends/1" do
    test "analyzes integrity trends over specified time window" do
      time_window_hours = 48
      
      result = IntegrityVerifier.analyze_integrity_trends(time_window_hours)
      
      assert {:ok, trend_analysis} = result
      assert trend_analysis.time_window.duration_hours == 48
      assert %DateTime{} = trend_analysis.time_window.start_time
      assert %DateTime{} = trend_analysis.time_window.end_time
      
      assert is_map(trend_analysis.count_accuracy_trends)
      assert is_map(trend_analysis.missing_record_patterns)
      assert is_map(trend_analysis.field_consistency_trends)
      assert is_map(trend_analysis.integrity_score_over_time)
      assert is_list(trend_analysis.most_problematic_resources)
      assert is_list(trend_analysis.improvement_recommendations)
      assert is_map(trend_analysis.system_health_indicators)
    end
    
    test "uses default time window when not specified" do
      result = IntegrityVerifier.analyze_integrity_trends()
      
      assert {:ok, trend_analysis} = result
      assert trend_analysis.time_window.duration_hours == 168  # Default: 1 week
    end
    
    test "provides system health indicators" do
      {:ok, trend_analysis} = IntegrityVerifier.analyze_integrity_trends(24)
      
      health_indicators = trend_analysis.system_health_indicators
      
      assert health_indicators.overall_health in [:good, :fair, :poor]
      assert is_number(health_indicators.data_consistency)
      assert health_indicators.data_consistency >= 0.0
      assert health_indicators.data_consistency <= 1.0
      assert is_number(health_indicators.sync_reliability)
    end
    
    test "generates improvement recommendations" do
      {:ok, trend_analysis} = IntegrityVerifier.analyze_integrity_trends(24)
      
      recommendations = trend_analysis.improvement_recommendations
      
      assert is_list(recommendations)
      assert length(recommendations) > 0
      assert Enum.all?(recommendations, &is_binary/1)
    end
    
    test "identifies alert triggers" do
      {:ok, trend_analysis} = IntegrityVerifier.analyze_integrity_trends(72)
      
      alert_triggers = trend_analysis.alert_triggers
      
      assert is_list(alert_triggers)
      # Alert triggers may be empty if no issues found
    end
  end
  
  describe "error handling and edge cases" do
    test "handles empty resource types list" do
      options = %{resource_types: []}
      
      result = IntegrityVerifier.verify_data_integrity(:count_only, options)
      
      # Should handle gracefully
      case result do
        {:ok, report} -> assert is_map(report)
        {:error, _} -> :ok  # Error is acceptable for empty resource list
      end
    end
    
    test "handles invalid verification type" do
      options = %{resource_types: [:cases]}
      
      result = IntegrityVerifier.verify_data_integrity(:invalid_type, options)
      
      # Should return error for invalid verification type
      assert {:error, _} = result
    end
    
    test "handles missing session ID gracefully" do
      # Monitor without session_id should still work
      result = IntegrityVerifier.monitor_sync_integrity(nil, %{})
      
      assert {:ok, monitoring_info} = result
      assert is_pid(monitoring_info.monitoring_pid)
    end
    
    test "handles reconciliation with empty integrity report" do
      empty_report = %{
        count_discrepancies: [],
        missing_records: [],
        field_mismatches: []
      }
      
      result = IntegrityVerifier.reconcile_integrity_issues(empty_report, %{})
      
      assert {:ok, reconciliation_summary} = result
      assert reconciliation_summary.total_issues == 0
      assert reconciliation_summary.resolved_issues == 0
      assert reconciliation_summary.resolution_rate == 1.0
    end
  end
  
  describe "performance and timing" do
    test "verification completes within reasonable time" do
      options = %{resource_types: [:cases, :notices]}
      
      start_time = System.monotonic_time(:millisecond)
      result = IntegrityVerifier.verify_data_integrity(:count_only, options)
      end_time = System.monotonic_time(:millisecond)
      
      assert {:ok, _} = result
      
      # Should complete within 30 seconds (generous for testing)
      duration_ms = end_time - start_time
      assert duration_ms < 30_000
    end
    
    test "trend analysis completes within reasonable time" do
      start_time = System.monotonic_time(:millisecond)
      result = IntegrityVerifier.analyze_integrity_trends(24)
      end_time = System.monotonic_time(:millisecond)
      
      assert {:ok, _} = result
      
      # Should complete within 15 seconds
      duration_ms = end_time - start_time
      assert duration_ms < 15_000
    end
    
    test "monitoring setup is fast" do
      session_id = "perf_test_session"
      
      start_time = System.monotonic_time(:millisecond)
      result = IntegrityVerifier.monitor_sync_integrity(session_id, %{})
      end_time = System.monotonic_time(:millisecond)
      
      assert {:ok, _} = result
      
      # Should setup monitoring quickly (within 1 second)
      duration_ms = end_time - start_time
      assert duration_ms < 1_000
    end
  end
end