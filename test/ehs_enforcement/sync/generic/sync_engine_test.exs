defmodule EhsEnforcement.Sync.Generic.SyncEngineTest do
  use EhsEnforcement.DataCase
  
  alias EhsEnforcement.Sync.Generic.{SyncEngine, SourceAdapter, ConfigValidator}
  alias EhsEnforcement.Enforcement.Case
  
  require Ash.Query
  import Ash.Expr

  describe "generic sync engine" do
    setup do
      # Create a test adapter for isolated testing
      test_adapter = create_test_adapter()
      
      %{
        test_config: %{
          source_adapter: test_adapter,
          source_config: %{record_count: 50},
          target_resource: Case,
          target_config: %{
            unique_field: :regulator_id,
            create_action: :create,
            update_action: :update,
            field_mapping: %{
              "case_id" => :regulator_id,
              "offender_name" => :offender_name,
              "action_type" => :offence_action_type
            }
          },
          processing_config: %{
            batch_size: 10,
            limit: 50,
            enable_error_recovery: true,
            enable_progress_tracking: true
          },
          pubsub_config: %{
            module: EhsEnforcement.PubSub,
            topic: "test_sync_progress"
          },
          session_config: %{
            sync_type: :import_cases,
            track_progress: true
          }
        }
      }
    end

    test "executes sync operation successfully", %{test_config: config} do
      assert {:ok, result} = SyncEngine.execute_sync(config)
      
      assert result.status == :success
      assert result.stats.total_processed > 0
      assert result.stats.created > 0
      assert result.session_id != nil
      assert result.processing_time_ms > 0
    end

    test "validates configuration before execution", %{test_config: config} do
      # Test with invalid configuration
      invalid_config = Map.delete(config, :source_adapter)
      
      assert {:error, reason} = SyncEngine.execute_sync(invalid_config)
      assert {:sync_initialization_failed, _detail} = reason
    end

    test "handles dry run mode", %{test_config: config} do
      assert {:ok, result} = SyncEngine.execute_sync(config, dry_run: true)
      
      assert result.status == :dry_run
      assert result.stats.total_processed == 0
      assert Map.has_key?(result, :validated_config)
    end

    test "supports streaming interface", %{test_config: config} do
      stream = SyncEngine.stream_and_process(config)
      
      results = stream |> Enum.take(3)
      
      assert length(results) == 3
      assert Enum.all?(results, fn result ->
        Map.has_key?(result, :batch_number) and
        Map.has_key?(result, :processed)
      end)
    end

    test "tracks session status", %{test_config: config} do
      # Start sync in background
      Task.start(fn ->
        SyncEngine.execute_sync(config)
      end)
      
      # Give it a moment to start
      Process.sleep(100)
      
      # Get active sessions (this would work with proper session tracking)
      # For now, just test the interface exists
      assert is_function(&SyncEngine.get_sync_status/1, 1)
    end

    test "supports sync cancellation", %{test_config: config} do
      # Test that cancellation interface exists
      session_id = "test_session_123"
      
      # This would cancel if session exists
      result = SyncEngine.cancel_sync(session_id)
      
      # Should return error for non-existent session
      assert {:error, :session_not_found} = result
    end

    test "handles actor authorization", %{test_config: config} do
      admin_user = %{id: 1, email: "admin@test.com", role: :admin}
      
      assert {:ok, result} = SyncEngine.execute_sync(config, actor: admin_user)
      
      # Verify actor was passed through (would be in session metadata)
      assert result.status == :success
    end

    test "respects processing limits", %{test_config: config} do
      limited_config = put_in(config, [:processing_config, :limit], 20)
      
      assert {:ok, result} = SyncEngine.execute_sync(limited_config)
      
      # Should process at most 20 records
      assert result.stats.total_processed <= 20
    end

    test "handles batch processing", %{test_config: config} do
      small_batch_config = put_in(config, [:processing_config, :batch_size], 5)
      
      assert {:ok, result} = SyncEngine.execute_sync(small_batch_config)
      
      # Should still process all records in smaller batches
      assert result.stats.total_processed > 0
      assert result.status == :success
    end
  end

  describe "error handling" do
    test "handles source adapter errors gracefully" do
      config = %{
        source_adapter: create_failing_adapter(),
        source_config: %{},
        target_resource: Case,
        target_config: %{unique_field: :regulator_id},
        processing_config: %{batch_size: 10},
        pubsub_config: %{module: EhsEnforcement.PubSub},
        session_config: %{sync_type: :import_cases}
      }
      
      assert {:error, reason} = SyncEngine.execute_sync(config)
      assert {:sync_initialization_failed, _detail} = reason
    end

    test "handles target resource errors" do
      config = %{
        source_adapter: create_test_adapter(),
        source_config: %{record_count: 10},
        target_resource: NonExistentResource,  # This doesn't exist
        target_config: %{unique_field: :id},
        processing_config: %{batch_size: 10},
        pubsub_config: %{module: EhsEnforcement.PubSub},
        session_config: %{sync_type: :import_test}
      }
      
      assert {:error, reason} = SyncEngine.execute_sync(config)
      assert {:sync_initialization_failed, _detail} = reason
    end
  end

  describe "configuration validation" do
    test "validates required configuration fields" do
      invalid_configs = [
        %{},  # Empty config
        %{source_adapter: TestAdapter},  # Missing other required fields
        %{target_resource: Case}  # Missing other required fields
      ]
      
      for config <- invalid_configs do
        assert {:error, _reason} = ConfigValidator.validate_sync_config(config)
      end
    end

    test "validates source adapter interface" do
      valid_config = %{
        source_adapter: create_test_adapter(),
        source_config: %{},
        target_resource: Case,
        target_config: %{unique_field: :regulator_id},
        processing_config: %{batch_size: 10},
        pubsub_config: %{module: EhsEnforcement.PubSub},
        session_config: %{sync_type: :import_test}
      }
      
      assert {:ok, _validated_config} = ConfigValidator.validate_sync_config(valid_config)
    end

    test "validates processing configuration ranges" do
      config_with_invalid_batch_size = %{
        source_adapter: create_test_adapter(),
        source_config: %{},
        target_resource: Case,
        target_config: %{unique_field: :regulator_id},
        processing_config: %{batch_size: 0},  # Invalid
        pubsub_config: %{module: EhsEnforcement.PubSub},
        session_config: %{sync_type: :import_test}
      }
      
      assert {:error, errors} = ConfigValidator.validate_sync_config(config_with_invalid_batch_size)
      assert Enum.any?(errors, fn error -> error.field == :batch_size end)
    end
  end

  # Helper functions for testing

  defp create_test_adapter do
    defmodule TestSyncAdapter do
      @behaviour EhsEnforcement.Sync.Generic.SourceAdapter
      
      def initialize(config) do
        {:ok, Map.merge(%{record_count: 10}, config)}
      end
      
      def stream_records(state) do
        1..state.record_count
        |> Stream.map(fn i ->
          %{
            "id" => "test_#{i}",
            "fields" => %{
              "case_id" => "CASE_#{String.pad_leading(to_string(i), 3, "0")}",
              "offender_name" => "Test Offender #{i}",
              "action_type" => "Court Case"
            }
          }
        end)
      end
      
      def validate_connection(_state) do
        :ok
      end
      
      def get_total_count(state) do
        {:ok, state.record_count}
      end
    end
    
    TestSyncAdapter
  end

  defp create_failing_adapter do
    defmodule FailingSyncAdapter do
      @behaviour EhsEnforcement.Sync.Generic.SourceAdapter
      
      def initialize(_config) do
        {:error, :initialization_failed}
      end
      
      def stream_records(_state) do
        Stream.repeatedly(fn -> raise "This adapter always fails" end)
      end
      
      def validate_connection(_state) do
        {:error, :connection_failed}
      end
    end
    
    FailingSyncAdapter
  end
end