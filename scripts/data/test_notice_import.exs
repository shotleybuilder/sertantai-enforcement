#!/usr/bin/env elixir

# Test import of 1 Improvement Notice record to verify classification logic
# Usage: mix run scripts/test_notice_import.exs

alias EhsEnforcement.Sync.AirtableImporter
alias EhsEnforcement.Integrations.Airtable.ReqClient
alias EhsEnforcement.Repo
import Ecto.Query
require Logger

defmodule TestNoticeImport do
  def run do
    Logger.info("🔍 Testing import of 1 Improvement Notice record...")
    
    with :ok <- test_airtable_connection(),
         {:ok, record} <- find_improvement_notice_record(),
         :ok <- import_single_record(record),
         :ok <- verify_import() do
      Logger.info("✅ Test completed successfully!")
      :ok
    else
      {:error, reason} ->
        Logger.error("❌ Test failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp test_airtable_connection do
    Logger.info("🔌 Testing Airtable connection...")
    path = "/appq5OQW9bTHC1zO5/tbl6NZm9bLU2ijivf"
    
    case ReqClient.get(path, %{maxRecords: 1}) do
      {:ok, _response} -> 
        Logger.info("✅ Airtable connection successful")
        :ok
      {:error, error} -> 
        Logger.error("❌ Failed to connect to Airtable: #{inspect(error)}")
        {:error, error}
    end
  end

  defp find_improvement_notice_record do
    Logger.info("🔍 Searching for Improvement Notice record...")
    
    # Stream through records looking for an Improvement Notice
    AirtableImporter.stream_airtable_records()
    |> Stream.take(500) # Look through first 500 records
    |> Enum.find(fn record ->
      fields = record["fields"] || %{}
      fields["offence_action_type"] == "Improvement Notice"
    end)
    |> case do
      nil ->
        Logger.error("❌ No Improvement Notice record found in first 500 records")
        {:error, :no_improvement_notice_found}
        
      record ->
        fields = record["fields"] || %{}
        Logger.info("✅ Found Improvement Notice record:")
        Logger.info("   Regulator ID: #{fields["regulator_id"]}")
        Logger.info("   Offender: #{fields["offender_name"]}")
        Logger.info("   Action Type: #{fields["offence_action_type"]}")
        Logger.info("   Date: #{fields["offence_action_date"]}")
        {:ok, record}
    end
  end

  defp import_single_record(record) do
    Logger.info("📥 Importing single record...")
    
    case AirtableImporter.import_batch([record]) do
      :ok ->
        Logger.info("✅ Record imported successfully")
        :ok
      {:error, error} ->
        Logger.error("❌ Import failed: #{inspect(error)}")
        {:error, error}
    end
  end

  defp verify_import do
    Logger.info("🔍 Verifying import results...")
    
    # Check final counts
    case_count = Repo.aggregate(from(c in "cases"), :count, :id)
    notice_count = Repo.aggregate(from(n in "notices"), :count, :id)
    offender_count = Repo.aggregate(from(o in "offenders"), :count, :id)
    
    Logger.info("📊 Database counts after import:")
    Logger.info("   Cases: #{case_count}")
    Logger.info("   Notices: #{notice_count}")
    Logger.info("   Offenders: #{offender_count}")
    
    if notice_count == 1 and case_count == 0 do
      Logger.info("✅ SUCCESS: Record correctly imported as notice!")
      
      # Get the notice details
      notice = Repo.one(from n in "notices", select: %{
        id: n.id,
        regulator_id: n.regulator_id,
        offence_action_type: n.offence_action_type,
        notice_date: n.notice_date,
        offender_id: n.offender_id,
        agency_id: n.agency_id
      })
      
      if notice do
        Logger.info("📋 Notice details:")
        Logger.info("   ID: #{notice.id}")
        Logger.info("   Regulator ID: #{notice.regulator_id}")
        Logger.info("   Action Type: #{notice.offence_action_type}")
        Logger.info("   Date: #{notice.notice_date}")
        Logger.info("   Offender ID: #{notice.offender_id}")
        Logger.info("   Agency ID: #{notice.agency_id}")
        
        # Verify relationships
        if notice.offender_id && notice.agency_id do
          Logger.info("✅ Relationships properly linked!")
        else
          Logger.warn("⚠️  Missing relationship links")
        end
      end
      
      :ok
    else
      Logger.error("❌ FAILED: Expected 1 notice and 0 cases, got #{notice_count} notices and #{case_count} cases")
      {:error, :incorrect_classification}
    end
  end
end

# Run the test
case TestNoticeImport.run() do
  :ok ->
    IO.puts("✅ Success: Improvement Notice imported and verified")
    System.stop(0)
    
  {:error, reason} ->
    IO.puts("❌ Error: #{inspect(reason)}")
    System.stop(1)
end