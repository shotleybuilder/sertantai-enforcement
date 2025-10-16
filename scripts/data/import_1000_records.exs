#!/usr/bin/env elixir

# Import 1000 records from Airtable to dev database
# Usage: mix run scripts/import_1000_records.exs
#
# IMPORTANT: Uses corrected classification logic:
# - Cases: offence_action_type = "Court Case" OR "Caution"  
# - Notices: All other offence_action_type values
# - Fixed issue where all records were incorrectly imported as cases

alias EhsEnforcement.Sync.AirtableImporter
alias EhsEnforcement.Integrations.Airtable.ReqClient
require Logger

defmodule Import1000Records do
  @target_records 1000
  @batch_size 100

  def run do
    Logger.info("Starting import of #{@target_records} records from Airtable...")
    
    # Check if we can connect to Airtable
    case test_airtable_connection() do
      :ok ->
        Logger.info("✅ Airtable connection successful")
        import_records()
      {:error, reason} ->
        Logger.error("❌ Failed to connect to Airtable: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp test_airtable_connection do
    path = "/appq5OQW9bTHC1zO5/tbl6NZm9bLU2ijivf"
    
    case ReqClient.get(path, %{maxRecords: 1}) do
      {:ok, _response} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp import_records do
    records_imported = 0
    
    # Use the existing stream function but limit to 1000 records
    AirtableImporter.stream_airtable_records()
    |> Stream.take(@target_records)
    |> Stream.chunk_every(@batch_size)
    |> Stream.with_index()
    |> Enum.reduce_while(0, fn {batch, batch_index}, acc ->
      batch_number = batch_index + 1
      Logger.info("Processing batch #{batch_number}/#{div(@target_records, @batch_size)} (#{length(batch)} records)")
      
      case AirtableImporter.import_batch(batch) do
        :ok ->
          new_acc = acc + length(batch)
          Logger.info("✅ Batch #{batch_number} completed. Total imported: #{new_acc}")
          
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
        Logger.info("🎉 Import completed! Successfully imported #{count} records")
        {:ok, count}
        
      error ->
        Logger.error("💥 Import failed: #{inspect(error)}")
        {:error, error}
    end
  end
end

# Run the import
case Import1000Records.run() do
  {:ok, count} ->
    IO.puts("Success: Imported #{count} records")
    System.stop(0)
    
  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
    System.stop(1)
end