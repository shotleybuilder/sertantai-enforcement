#!/usr/bin/env elixir

# Import 1000 notice records from Airtable to dev database
# Usage: mix run scripts/import_1000_notices.exs
#
# Uses Airtable formula to filter for records where offence_action_type contains "Notice"

alias EhsEnforcement.Sync.AirtableImporter
alias EhsEnforcement.Integrations.Airtable.ReqClient
alias EhsEnforcement.Repo
import Ecto.Query
require Logger

defmodule Import1000Notices do
  @target_records 1000
  @batch_size 100

  def run do
    Logger.info("🔍 Starting import of #{@target_records} notice records from Airtable...")
    
    with :ok <- test_airtable_connection(),
         {:ok, count} <- import_notices() do
      Logger.info("✅ Process completed successfully! Imported #{count} notices")
      verify_import()
      {:ok, count}
    else
      {:error, reason} ->
        Logger.error("❌ Process failed: #{inspect(reason)}")
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

  defp import_notices do
    Logger.info("📥 Starting import with Airtable formula filter...")
    
    # Stream records with filter for Notice types
    stream_notice_records()
    |> Stream.take(@target_records)
    |> Stream.chunk_every(@batch_size)
    |> Stream.with_index()
    |> Enum.reduce_while(0, fn {batch, batch_index}, acc ->
      batch_number = batch_index + 1
      Logger.info("📦 Processing batch #{batch_number} (#{length(batch)} notice records)")
      
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

  defp stream_notice_records do
    path = "/appq5OQW9bTHC1zO5/tbl6NZm9bLU2ijivf"
    
    # Airtable formula to filter for records where offence_action_type contains "Notice"
    filter_formula = "FIND('Notice', {offence_action_type}) > 0"
    
    Logger.info("🔍 Using Airtable filter: #{filter_formula}")
    
    Stream.resource(
      fn -> nil end,
      fn offset ->
        params = %{
          maxRecords: @batch_size,
          filterByFormula: filter_formula
        }
        
        params = case offset do
          nil -> params
          offset -> Map.put(params, :offset, offset)
        end
        
        case ReqClient.get(path, params) do
          {:ok, %{"records" => records, "offset" => next_offset}} ->
            {records, next_offset}
            
          {:ok, %{"records" => records}} ->
            # No more pages
            {records, :done}
            
          {:error, error} ->
            Logger.error("Failed to fetch notice records: #{inspect(error)}")
            {[], :done}
            
          _ ->
            {[], :done}
        end
      end,
      fn _ -> :ok end
    )
    |> Stream.take_while(fn
      [] -> false
      records when is_list(records) -> length(records) > 0
      _record -> true  # Individual record
    end)
    |> Stream.flat_map(fn
      records when is_list(records) -> records
      record -> [record]  # Wrap single record in list
    end)
  end

  defp verify_import do
    Logger.info("🔍 Verifying import results...")
    
    # Check final counts
    case_count = Repo.aggregate(from(c in "cases"), :count, :id)
    notice_count = Repo.aggregate(from(n in "notices"), :count, :id)
    offender_count = Repo.aggregate(from(o in "offenders"), :count, :id)
    agency_count = Repo.aggregate(from(a in "agencies"), :count, :id)
    
    Logger.info("📊 Final database counts:")
    Logger.info("   Cases: #{case_count}")
    Logger.info("   Notices: #{notice_count}")
    Logger.info("   Offenders: #{offender_count}")
    Logger.info("   Agencies: #{agency_count}")
    Logger.info("   Total enforcement records: #{case_count + notice_count}")
    
    if notice_count > 0 do
      Logger.info("✅ SUCCESS: #{notice_count} notice records imported!")
      
      # Sample a few notice records to verify they're correct
      sample_notices = Repo.all(from n in "notices", 
        select: %{
          regulator_id: n.regulator_id,
          offence_action_type: n.offence_action_type,
          notice_date: n.notice_date
        }, 
        limit: 3
      )
      
      Logger.info("📋 Sample notice records:")
      Enum.each(sample_notices, fn notice ->
        Logger.info("   #{notice.regulator_id}: #{notice.offence_action_type} (#{notice.notice_date})")
      end)
    else
      Logger.error("❌ No notice records found - check Airtable filter")
    end
    
    :ok
  end
end

# Run the import
case Import1000Notices.run() do
  {:ok, count} ->
    IO.puts("✅ Success: Imported #{count} notice records")
    System.stop(0)
    
  {:error, reason} ->
    IO.puts("❌ Error: #{inspect(reason)}")
    System.stop(1)
end