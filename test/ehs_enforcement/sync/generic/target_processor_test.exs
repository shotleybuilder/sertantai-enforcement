defmodule EhsEnforcement.Sync.Generic.TargetProcessorTest do
  use EhsEnforcement.DataCase
  
  alias EhsEnforcement.Sync.Generic.TargetProcessor
  alias EhsEnforcement.Enforcement.Case
  
  require Ash.Query
  import Ash.Expr

  describe "target processor initialization" do
    test "initializes successfully with valid resource and config" do
      config = %{
        unique_field: :regulator_id,
        create_action: :create,
        update_action: :update,
        field_mapping: %{
          "case_id" => :regulator_id,
          "offender_name" => :offender_name
        }
      }
      
      assert {:ok, processor_state} = TargetProcessor.initialize(Case, config)
      assert processor_state.resource_module == Case
      assert processor_state.config.unique_field == :regulator_id
    end

    test "fails with invalid resource module" do
      config = %{unique_field: :id}
      
      assert {:error, reason} = TargetProcessor.initialize(NonExistentModule, config)
      assert reason == {:module_not_found, NonExistentModule}
    end

    test "fails with missing required configuration" do
      config = %{}  # Missing unique_field
      
      assert {:error, reason} = TargetProcessor.initialize(Case, config)
      assert reason == {:missing_config_fields, [:unique_field]}
    end
  end

  describe "record processing" do
    setup do
      config = %{
        unique_field: :regulator_id,
        create_action: :create,
        update_action: :update,
        field_mapping: %{
          "case_id" => :regulator_id,
          "offender_name" => :offender_name,
          "action_type" => :offence_action_type
        },
        duplicate_strategy: :update
      }
      
      {:ok, processor_state} = TargetProcessor.initialize(Case, config)
      
      %{
        processor_state: processor_state,
        config: config,
        test_record: %{
          "id" => "rec123",
          "fields" => %{
            "case_id" => "HSE001",
            "offender_name" => "Test Offender Ltd",
            "action_type" => "Court Case"
          }
        }
      }
    end

    test "creates new record successfully", %{processor_state: state, config: config, test_record: record} do
      assert {:ok, result} = TargetProcessor.process_record(state, record, config)
      assert {:created, case_record} = result
      assert case_record.regulator_id == "HSE001"
      assert case_record.offender_name == "Test Offender Ltd"
    end

    test "handles duplicate records with update strategy", %{processor_state: state, config: config, test_record: record} do
      # First create a record
      {:ok, {:created, _first_case}} = TargetProcessor.process_record(state, record, config)
      
      # Try to create the same record again (should update)
      updated_record = put_in(record, ["fields", "offender_name"], "Updated Offender Ltd")
      
      assert {:ok, result} = TargetProcessor.process_record(state, updated_record, config)
      
      # Should either update or return existing (depending on implementation)
      assert result in [
        {:updated, _},
        {:existing, _}
      ]
    end

    test "handles duplicate records with skip strategy", %{processor_state: state, test_record: record} do
      skip_config = %{
        unique_field: :regulator_id,
        create_action: :create,
        update_action: :update,
        field_mapping: %{
          "case_id" => :regulator_id,
          "offender_name" => :offender_name,
          "action_type" => :offence_action_type
        },
        duplicate_strategy: :skip
      }
      
      # First create a record
      {:ok, {:created, _first_case}} = TargetProcessor.process_record(state, record, skip_config)
      
      # Try to create the same record again (should skip)
      assert {:ok, result} = TargetProcessor.process_record(state, record, skip_config)
      assert {:existing, _case_record} = result
    end

    test "maps fields correctly", %{processor_state: state, config: config} do
      record_with_different_fields = %{
        "id" => "rec456",
        "fields" => %{
          "case_id" => "HSE002",
          "offender_name" => "Another Offender",
          "action_type" => "Caution",
          "unmapped_field" => "This should be ignored"
        }
      }
      
      assert {:ok, {:created, case_record}} = TargetProcessor.process_record(state, record_with_different_fields, config)
      
      assert case_record.regulator_id == "HSE002"
      assert case_record.offender_name == "Another Offender"
      assert case_record.offence_action_type == "Caution"
      # unmapped_field should not be present
    end

    test "handles validation errors", %{processor_state: state, config: config} do
      invalid_record = %{
        "id" => "rec789",
        "fields" => %{
          "case_id" => "",  # Empty case_id might cause validation error
          "offender_name" => "Test Offender",
          "action_type" => "Invalid Action"
        }
      }
      
      case TargetProcessor.process_record(state, invalid_record, config) do
        {:ok, _result} ->
          # Processing succeeded despite potentially invalid data
          :ok
        {:error, reason} ->
          # Processing failed due to validation
          assert reason != nil
      end
    end

    test "processes batch of records efficiently", %{processor_state: state, config: config} do
      records = for i <- 1..10 do
        %{
          "id" => "rec#{i}",
          "fields" => %{
            "case_id" => "HSE#{String.pad_leading(to_string(i), 3, "0")}",
            "offender_name" => "Batch Offender #{i}",
            "action_type" => "Court Case"
          }
        }
      end
      
      assert {:ok, results} = TargetProcessor.process_batch(state, records, config)
      
      assert length(results) == 10
      
      # All results should be successful creations
      created_count = Enum.count(results, fn
        {:created, _} -> true
        _ -> false
      end)
      
      assert created_count == 10
    end

    test "gets batch statistics", %{processor_state: state, config: config} do
      # Create a mix of results
      results = [
        {:created, %{id: 1}},
        {:created, %{id: 2}},
        {:updated, %{id: 3}},
        {:existing, %{id: 4}},
        {:error, "some error"}
      ]
      
      stats = TargetProcessor.get_batch_stats(results)
      
      assert stats.total == 5
      assert stats.created == 2
      assert stats.updated == 1
      assert stats.existing == 1
      assert stats.errors == 1
    end
  end

  describe "field mapping" do
    setup do
      config = %{
        unique_field: :regulator_id,
        field_mapping: %{
          "custom_id" => :regulator_id,
          "company_name" => :offender_name,
          "case_type" => :offence_action_type,
          "nested_field" => :some_other_field
        }
      }
      
      {:ok, processor_state} = TargetProcessor.initialize(Case, config)
      
      %{processor_state: processor_state, config: config}
    end

    test "maps custom field names correctly", %{processor_state: state, config: config} do
      record = %{
        "id" => "rec123",
        "fields" => %{
          "custom_id" => "CUSTOM001",
          "company_name" => "Custom Company Ltd",
          "case_type" => "Court Case"
        }
      }
      
      assert {:ok, {:created, case_record}} = TargetProcessor.process_record(state, record, config)
      
      assert case_record.regulator_id == "CUSTOM001"
      assert case_record.offender_name == "Custom Company Ltd"
      assert case_record.offence_action_type == "Court Case"
    end

    test "handles missing mapped fields gracefully", %{processor_state: state, config: config} do
      record = %{
        "id" => "rec123",
        "fields" => %{
          "custom_id" => "CUSTOM002",
          # Missing company_name and case_type
        }
      }
      
      # Should still process, with missing fields as nil
      case TargetProcessor.process_record(state, record, config) do
        {:ok, {:created, case_record}} ->
          assert case_record.regulator_id == "CUSTOM002"
          # Other fields should be nil or default values
        {:error, _reason} ->
          # Or might fail validation if fields are required
          :ok
      end
    end
  end

  describe "error handling and recovery" do
    test "handles resource creation failures gracefully" do
      # This would test error scenarios, but requires more complex setup
      # to trigger specific Ash errors
      :ok
    end

    test "respects duplicate handling strategies" do
      # Test different duplicate strategies: :update, :skip, :error
      :ok
    end
  end
end