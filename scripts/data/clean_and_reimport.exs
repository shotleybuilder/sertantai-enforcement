#!/usr/bin/env elixir

# Clean dev database and re-import with corrected classification logic
# Usage: mix run scripts/clean_and_reimport.exs

alias EhsEnforcement.Repo
alias EhsEnforcement.Sync.AirtableImporter
alias EhsEnforcement.Integrations.Airtable.ReqClient
import Ecto.Query
require Logger

defmodule CleanAndReimport do
  @target_records 1000
  @batch_size 100

  def run do
    Logger.info("🧹 Starting database cleanup and re-import process...")
    
    with :ok <- clean_database(),
         :ok <- test_airtable_connection(),
         {:ok, count} <- import_records() do
      Logger.info("✅ Process completed successfully! Imported #{count} records")
      verify_import()
      {:ok, count}
    else
      {:error, reason} ->
        Logger.error("❌ Process failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp clean_database do
    Logger.info("🗑️  Deleting all enforcement records from development database...")
    
    case_count = Repo.aggregate(from(c in "cases"), :count, :id)
    notice_count = Repo.aggregate(from(n in "notices"), :count, :id)
    Logger.info("Found #{case_count} case records and #{notice_count} notice records to delete")
    
    # Delete all cases and notices but keep offenders and agencies
    {deleted_cases, _} = Repo.delete_all(from c in "cases")
    {deleted_notices, _} = Repo.delete_all(from n in "notices")
    
    Logger.info("✅ Deleted #{deleted_cases} case records and #{deleted_notices} notice records")
    Logger.info("📋 Keeping #{Repo.aggregate(from(o in "offenders"), :count, :id)} offenders")
    Logger.info("🏢 Keeping #{Repo.aggregate(from(a in "agencies"), :count, :id)} agencies")
    
    :ok
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

  defp import_records do
    Logger.info("📥 Starting import of #{@target_records} records with corrected classification...")
    
    # Use the corrected stream function
    AirtableImporter.stream_airtable_records()
    |> Stream.take(@target_records)
    |> Stream.chunk_every(@batch_size)
    |> Stream.with_index()
    |> Enum.reduce_while(0, fn {batch, batch_index}, acc ->
      batch_number = batch_index + 1
      Logger.info("📦 Processing batch #{batch_number}/#{div(@target_records, @batch_size)} (#{length(batch)} records)")
      
      case AirtableImporter.import_batch(batch) do
        :ok ->
          new_acc = acc + length(batch)
          Logger.info("✅ Batch #{batch_number} completed. Total processed: #{new_acc}")
          
          if new_acc >= @target_records do
            {:halt, new_acc}
          else
            {:cont, new_acc}
          end
          
        {:error, error} ->
          Logger.error("❌ Batch #{batch_number} failed: #{inspect(error)}")
          {:halt, acc}
      end
    end)
    |> case do
      count when is_integer(count) ->
        Logger.info("🎉 Import completed! Successfully processed #{count} records")
        {:ok, count}
        
      error ->
        Logger.error("💥 Import failed: #{inspect(error)}")
        {:error, error}
    end
  end

  defp verify_import do
    Logger.info("🔍 Verifying import results...")
    
    case_count = Repo.aggregate(from(c in "cases"), :count, :id)
    notice_count = Repo.aggregate(from(n in "notices"), :count, :id)
    offender_count = Repo.aggregate(from(o in "offenders"), :count, :id)
    
    Logger.info("📊 Final counts:")
    Logger.info("   Cases: #{case_count}")
    Logger.info("   Notices: #{notice_count}")
    Logger.info("   Offenders: #{offender_count}")
    Logger.info("   Total records: #{case_count + notice_count}")
    
    if case_count + notice_count > 0 do
      case_percentage = Float.round(case_count / (case_count + notice_count) * 100, 1)
      notice_percentage = Float.round(notice_count / (case_count + notice_count) * 100, 1)
      
      Logger.info("📈 Distribution:")
      Logger.info("   Cases: #{case_percentage}%")
      Logger.info("   Notices: #{notice_percentage}%")
    end
    
    :ok
  end
end

# Run the cleanup and re-import
case CleanAndReimport.run() do
  {:ok, count} ->
    IO.puts("✅ Success: Processed #{count} records with correct classification")
    System.stop(0)
    
  {:error, reason} ->
    IO.puts("❌ Error: #{inspect(reason)}")
    System.stop(1)
end