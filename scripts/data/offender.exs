#!/usr/bin/env elixir

# Update existing PostgreSQL offender records with missing field data from Airtable
# Usage: Code.eval_file("/app/scripts/offender.exs")
#
# This script:
# 1. Streams records from Airtable (like import.exs)
# 2. For each record, checks if corresponding offender exists and needs updating
# 3. Updates PostgreSQL offender records with missing fields:
#    - address, country, sic_code, industry, business_type
# 4. Uses proper Ash patterns for all database operations

alias EhsEnforcement.Sync.AirtableImporter
alias EhsEnforcement.Integrations.Airtable.ReqClient
alias EhsEnforcement.Enforcement
require Logger
require Ash.Query
import Ash.Expr

defmodule OffenderUpdater do
  @batch_size 100

  def run do
    Logger.info("🚀 Starting offender field update from Airtable...")
    
    # Check if we can connect to Airtable
    case test_airtable_connection() do
      :ok ->
        Logger.info("✅ Airtable connection successful")
        update_offender_records()
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

  defp update_offender_records do
    # Use the existing stream function from AirtableImporter
    AirtableImporter.stream_airtable_records()
    |> Stream.chunk_every(@batch_size)
    |> Stream.with_index()
    |> Enum.reduce_while(0, fn {batch, batch_index}, acc ->
      batch_number = batch_index + 1
      Logger.info("Processing batch #{batch_number} (#{length(batch)} records)")
      
      case update_batch(batch) do
        {:ok, updated_count} ->
          new_acc = acc + updated_count
          Logger.info("✅ Batch #{batch_number} completed. Updated #{updated_count} offenders. Total: #{new_acc}")
          
          # Progress updates every 10 batches
          if rem(batch_number, 10) == 0 do
            Logger.info("🚀 Progress: #{new_acc} offender records updated so far")
          end
          
          {:cont, new_acc}
          
        {:error, error} ->
          Logger.error("❌ Batch #{batch_number} failed: #{inspect(error)}")
          Logger.info("Continuing with next batch...")
          {:cont, acc}
      end
    end)
    |> case do
      count when is_integer(count) ->
        Logger.info("🎉 Update completed! Successfully updated #{count} offender records")
        {:ok, count}
        
      error ->
        Logger.error("💥 Update failed: #{inspect(error)}")
        {:error, error}
    end
  end

  defp update_batch(airtable_records) do
    updated_count = Enum.reduce(airtable_records, 0, fn record, acc ->
      case update_single_record(record) do
        :updated -> acc + 1
        :skipped -> acc
        :error -> acc
      end
    end)
    
    {:ok, updated_count}
  end

  defp update_single_record(airtable_record) do
    fields = airtable_record["fields"] || %{}
    regulator_id = to_string(fields["regulator_id"] || "")
    
    if is_nil(regulator_id) or regulator_id == "" do
      :skipped
    else
      # Find existing case or notice with this regulator_id
      case find_offender_by_regulator_id(regulator_id) do
        {:ok, offender} when not is_nil(offender) ->
          update_attrs = build_update_attrs(fields, offender)
          
          if map_size(update_attrs) > 0 do
            case Ash.update(offender, update_attrs) do
              {:ok, _updated_offender} ->
                Logger.info("Updated offender for regulator_id #{regulator_id} with #{map_size(update_attrs)} fields")
                :updated
                
              {:error, error} ->
                Logger.error("Failed to update offender for regulator_id #{regulator_id}: #{inspect(error)}")
                :error
            end
          else
            :skipped
          end
          
        _ ->
          :skipped
      end
    end
  end

  defp find_offender_by_regulator_id(regulator_id) do
    # First try to find a case with this regulator_id
    query = Ash.Query.filter(Enforcement.Case, regulator_id == ^regulator_id)
    case Ash.read(query, load: [:offender]) do
      {:ok, [case_record | _]} when not is_nil(case_record.offender) ->
        {:ok, case_record.offender}
      {:ok, []} ->
        # If no case found, try notices
        query = Ash.Query.filter(Enforcement.Notice, regulator_id == ^regulator_id)
        case Ash.read(query, load: [:offender]) do
          {:ok, [notice_record | _]} when not is_nil(notice_record.offender) ->
            {:ok, notice_record.offender}
          _ ->
            {:ok, nil}
        end
      _ ->
        {:ok, nil}
    end
  end

  defp build_update_attrs(airtable_fields, _current_offender) do
    # Build update attributes for all available offender fields from Airtable
    # Airtable only sends fields that have data, so no need to filter nil/empty
    %{
      address: airtable_fields["offender_address"],
      country: airtable_fields["offender_country"], 
      sic_code: airtable_fields["offender_sic"],
      industry: airtable_fields["offender_industry"],
      business_type: normalize_business_type(airtable_fields["offender_business_type"])
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp normalize_business_type(business_type_string) do
    case business_type_string do
      "LTD" -> :limited_company
      "PLC" -> :plc  
      "LLP" -> :partnership
      "LLC" -> :limited_company
      "INC" -> :limited_company
      "CORP" -> :limited_company
      "SOLE" -> :individual
      nil -> nil
      "" -> nil
      _ -> :other
    end
  end
end

# Run the update
case OffenderUpdater.run() do
  {:ok, count} ->
    IO.puts("Success: Updated #{count} offender records with missing field data")
    
  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end