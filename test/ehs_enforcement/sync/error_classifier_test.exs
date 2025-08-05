defmodule EhsEnforcement.Sync.ErrorClassifierTest do
  use ExUnit.Case, async: true
  
  alias EhsEnforcement.Sync.ErrorClassifier
  require Ash.Query
  import Ash.Expr

  describe "classify_sync_error/2" do
    test "classifies network timeout errors correctly" do
      error = %Req.TransportError{reason: :timeout}
      context = %{operation: :import_cases, resource_type: :case}
      
      classification = ErrorClassifier.classify_sync_error(error, context)
      
      assert classification.category == :sync_network_error
      assert classification.subcategory == :airtable_timeout
      assert classification.severity == :medium
      assert classification.recoverable == true
      assert classification.retry_eligible == true
      assert classification.retry_strategy.type == :exponential_backoff
    end
    
    test "classifies database constraint violations correctly" do
      error = %Ecto.ConstraintError{}
      context = %{operation: :create_case, resource_type: :case, batch_size: 50}
      
      classification = ErrorClassifier.classify_sync_error(error, context)
      
      assert classification.category == :sync_data_error
      assert classification.subcategory == :constraint_violation
      assert classification.severity == :critical
      assert classification.recoverable == false
      assert classification.retry_eligible == false
      assert classification.requires_immediate_attention == true
    end
    
    test "classifies validation errors correctly" do
      error = %Ash.Error.Invalid{}
      context = %{operation: :create_case, resource_type: :case}
      
      classification = ErrorClassifier.classify_sync_error(error, context)
      
      assert classification.category == :sync_validation_error
      assert classification.subcategory == :invalid_source_data
      assert classification.severity == :medium
      assert classification.retry_eligible == false
    end
    
    test "generates appropriate recovery actions" do
      error = %Req.TransportError{reason: :connection_refused}
      context = %{operation: :import_notices}
      
      classification = ErrorClassifier.classify_sync_error(error, context)
      
      assert is_list(classification.recovery_actions)
      assert Enum.any?(classification.recovery_actions, &String.contains?(&1, "network"))
      assert Enum.any?(classification.recovery_actions, &String.contains?(&1, "API"))
    end
    
    test "sets appropriate notification channels based on severity" do
      critical_error = %Ecto.ConstraintError{}
      critical_context = %{operation: :create_case}
      
      critical_classification = ErrorClassifier.classify_sync_error(critical_error, critical_context)
      
      assert :email in critical_classification.notification_channels
      assert :slack in critical_classification.notification_channels
      assert :pager in critical_classification.notification_channels
      
      # Test medium severity
      medium_error = %Req.TransportError{reason: :timeout}
      medium_context = %{operation: :import_cases}
      
      medium_classification = ErrorClassifier.classify_sync_error(medium_error, medium_context)
      
      assert :slack in medium_classification.notification_channels
      refute :pager in medium_classification.notification_channels
    end
    
    test "generates error fingerprints consistently" do
      error = %Req.TransportError{reason: :timeout}
      context = %{operation: :import_cases, resource_type: :case}
      
      classification1 = ErrorClassifier.classify_sync_error(error, context)
      classification2 = ErrorClassifier.classify_sync_error(error, context)
      
      assert classification1.error_fingerprint == classification2.error_fingerprint
      assert is_binary(classification1.error_fingerprint)
      assert String.length(classification1.error_fingerprint) == 16
    end
  end
  
  describe "analyze_error_patterns/1" do
    test "analyzes error patterns correctly" do
      error_history = [
        %{category: :sync_network_error, operation: :import_cases, occurred_at: DateTime.utc_now()},
        %{category: :sync_network_error, operation: :import_cases, occurred_at: DateTime.utc_now()},
        %{category: :sync_data_error, operation: :create_case, occurred_at: DateTime.utc_now()},
        %{category: :sync_validation_error, operation: :import_notices, occurred_at: DateTime.utc_now()},
        %{category: :sync_validation_error, operation: :import_notices, occurred_at: DateTime.utc_now()}
      ]
      
      analysis = ErrorClassifier.analyze_error_patterns(error_history)
      
      assert analysis.total_errors == 5
      assert analysis.by_category[:sync_network_error].count == 2
      assert analysis.by_category[:sync_data_error].count == 1
      assert analysis.by_category[:sync_validation_error].count == 2
      
      assert analysis.by_operation[:import_cases].count == 2
      assert analysis.by_operation[:create_case].count == 1
      assert analysis.by_operation[:import_notices].count == 2
      
      assert length(analysis.high_frequency_errors) >= 1
      assert is_list(analysis.recommended_actions)
      assert is_list(analysis.infrastructure_improvements)
    end
    
    test "handles empty error history" do
      error_history = []
      
      analysis = ErrorClassifier.analyze_error_patterns(error_history)
      
      assert analysis.total_errors == 0
      assert analysis.by_category == %{}
      assert analysis.by_operation == %{}
      assert analysis.high_frequency_errors == []
    end
    
    test "identifies problematic operations" do
      error_history = [
        %{category: :sync_network_error, operation: :import_cases, occurred_at: DateTime.utc_now()},
        %{category: :sync_data_error, operation: :import_cases, occurred_at: DateTime.utc_now()},
        %{category: :sync_validation_error, operation: :import_cases, occurred_at: DateTime.utc_now()},
        %{category: :sync_performance_error, operation: :import_cases, occurred_at: DateTime.utc_now()}
      ]
      
      analysis = ErrorClassifier.analyze_error_patterns(error_history)
      
      assert length(analysis.problematic_operations) >= 1
      assert Enum.any?(analysis.problematic_operations, fn {op, _} -> op == :import_cases end)
    end
  end
  
  describe "generate_contextual_messages/2" do
    test "generates appropriate messages for different audiences" do
      error_classification = %{
        category: :sync_network_error,
        subcategory: :airtable_timeout,
        severity: :medium,
        operation: :import_cases,
        error_fingerprint: "abc123def456"
      }
      
      context = %{operation: "case import", affected_records: 150}
      
      messages = ErrorClassifier.generate_contextual_messages(error_classification, context)
      
      # Test user message
      assert is_binary(messages.user_message)
      assert String.contains?(messages.user_message, "case import")
      assert String.contains?(messages.user_message, "network")
      
      # Test admin message  
      assert is_binary(messages.admin_message)
      assert String.contains?(messages.admin_message, "150")
      assert String.contains?(messages.admin_message, "Network error")
      
      # Test technical message
      assert is_binary(messages.technical_message)
      assert String.contains?(messages.technical_message, "sync_network_error")
      assert String.contains?(messages.technical_message, "abc123def456")
      
      # Test monitoring message
      assert is_map(messages.monitoring_message)
      assert messages.monitoring_message.alert_type == "sync_error"
      assert messages.monitoring_message.severity == :medium
      assert messages.monitoring_message.category == :sync_network_error
      
      # Test action recommendations
      assert is_list(messages.user_actions)
      assert is_list(messages.admin_actions)
      assert is_list(messages.technical_actions)
    end
    
    test "customizes messages based on error severity" do
      critical_classification = %{
        category: :sync_data_error,
        subcategory: :constraint_violation,
        severity: :critical,
        operation: :create_case
      }
      
      medium_classification = %{
        category: :sync_network_error,
        subcategory: :timeout,
        severity: :medium,
        operation: :import_cases
      }
      
      critical_messages = ErrorClassifier.generate_contextual_messages(critical_classification)
      medium_messages = ErrorClassifier.generate_contextual_messages(medium_classification)
      
      # Critical errors should have more urgent language
      assert String.contains?(critical_messages.admin_message, "integrity")
      assert length(critical_messages.admin_actions) >= length(medium_messages.admin_actions)
    end
  end
end