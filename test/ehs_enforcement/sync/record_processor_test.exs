defmodule EhsEnforcement.Sync.RecordProcessorTest do
  use EhsEnforcement.DataCase, async: true
  
  alias EhsEnforcement.Sync.RecordProcessor
  alias EhsEnforcement.Enforcement

  setup do
    # Create HSE agency for testing
    {:ok, _hse_agency} = Enforcement.create_agency(%{
      name: "Health and Safety Executive",
      code: :hse,
      base_url: "https://www.hse.gov.uk",
      enabled: true
    })
    
    :ok
  end

  describe "process_case_record/2" do
    test "creates new case when none exists" do
      # Create sample Airtable record
      record = %{
        "fields" => %{
          "regulator_id" => "TEST-CASE-NEW-001",
          "agency_code" => "hse",
          "offender_name" => "Test Company Ltd",
          "offender_postcode" => "SW1A 1AA",
          "offence_action_type" => "Court Case",
          "offence_action_date" => "2023-01-15",
          "offence_result" => "Fine",
          "offence_fine" => "5000",
          "offence_costs" => "1500",
          "offence_breaches" => "Health and Safety at Work etc. Act 1974"
        }
      }
      
      # Process the record
      result = RecordProcessor.process_case_record(record, actor: nil)
      
      # Should create new case
      assert {:created, case_record} = result
      assert case_record.regulator_id == "TEST-CASE-NEW-001"
      assert case_record.offence_result == "Fine"
    end
    
    test "detects existing case and returns exists status when no update needed" do
      # First create a case
      {:ok, existing_case} = Enforcement.create_case(%{
        agency_code: :hse,
        regulator_id: "TEST-CASE-EXISTS-001",
        offender_attrs: %{
          name: "Existing Company Ltd",
          postcode: "SW1A 1AA"
        },
        offence_action_type: "Court Case",
        offence_result: "Fine"
      })
      
      # Create identical Airtable record
      record = %{
        "fields" => %{
          "regulator_id" => "TEST-CASE-EXISTS-001",
          "agency_code" => "hse",
          "offender_name" => "Existing Company Ltd",
          "offender_postcode" => "SW1A 1AA",
          "offence_action_type" => "Court Case",
          "offence_result" => "Fine"
        }
      }
      
      # Process the record
      result = RecordProcessor.process_case_record(record, actor: nil)
      
      # Should detect existing case
      assert {:exists, case_record} = result
      assert case_record.id == existing_case.id
    end
    
    test "detects existing case and updates when data differs" do
      # First create a case
      {:ok, existing_case} = Enforcement.create_case(%{
        agency_code: :hse,
        regulator_id: "TEST-CASE-UPDATE-001",
        offender_attrs: %{
          name: "Update Company Ltd",
          postcode: "SW1A 1AA"
        },
        offence_action_type: "Court Case",
        offence_result: "Pending"
      })
      
      # Create Airtable record with updated data
      record = %{
        "fields" => %{
          "regulator_id" => "TEST-CASE-UPDATE-001",
          "agency_code" => "hse",
          "offender_name" => "Update Company Ltd",
          "offender_postcode" => "SW1A 1AA",
          "offence_action_type" => "Court Case",
          "offence_result" => "Fine",  # This is different
          "offence_fine" => "10000"   # This is new
        }
      }
      
      # Process the record
      result = RecordProcessor.process_case_record(record, actor: nil)
      
      # Should update existing case
      assert {:updated, case_record} = result
      assert case_record.id == existing_case.id
      assert case_record.offence_result == "Fine"
    end
  end

  describe "process_notice_record/2" do
    test "creates new notice when none exists" do
      # Create sample Airtable record
      record = %{
        "fields" => %{
          "regulator_id" => "TEST-NOTICE-NEW-001",
          "agency_code" => "hse",
          "offender_name" => "Test Notice Company Ltd",
          "offender_postcode" => "SW1A 1AA",
          "offence_action_type" => "Improvement Notice",
          "offence_action_date" => "2023-01-15",
          "notice_date" => "2023-01-20",
          "notice_body" => "Test notice body",
          "offence_breaches" => "Health and Safety at Work etc. Act 1974"
        }
      }
      
      # Process the record
      result = RecordProcessor.process_notice_record(record, actor: nil)
      
      # Should create new notice
      assert {:created, notice_record} = result
      assert notice_record.regulator_id == "TEST-NOTICE-NEW-001"
      assert notice_record.notice_body == "Test notice body"
    end
  end
end