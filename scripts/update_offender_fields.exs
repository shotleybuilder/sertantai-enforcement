#!/usr/bin/env elixir

# Update existing PostgreSQL offender records with missing field data from Airtable
# Usage: 
#   mix run scripts/update_offender_fields.exs                    # Full update
#   DRY_RUN=true mix run scripts/update_offender_fields.exs       # Dry run (no database changes)
#
# This script:
# 1. Retrieves all existing cases/notices from PostgreSQL (using regulator_id as unique key)
# 2. Fetches corresponding records from Airtable to get missing offender field data
# 3. Updates PostgreSQL offender records with the missing fields:
#    - address, country, sic_code, industry, business_type
# 4. Uses proper Ash patterns for all database operations

alias EhsEnforcement.Enforcement
alias EhsEnforcement.Integrations.Airtable.ReqClient
require Logger

defmodule OffenderFieldUpdater do
  @batch_size 50
  @airtable_base_id "appq5OQW9bTHC1zO5"
  @airtable_table_id "tbl6NZm9bLU2ijivf"
  
  # Allow dependency injection for testing
  @client Application.compile_env(:ehs_enforcement, :airtable_client, ReqClient)
  
  # Check for dry run mode
  @dry_run System.get_env("DRY_RUN") == "true"
  
  def run do
    Logger.info("🚀 Starting offender field update from Airtable...")
    
    if @dry_run do
      Logger.info("🧪 DRY RUN MODE - No database changes will be made")
    else
      Logger.info("⚠️  PRODUCTION UPDATE - This will modify production database records")
      # Wait a moment to allow cancellation if running interactively
      Process.sleep(2000)
    end
    
    case test_airtable_connection() do
      :ok ->
        Logger.info("✅ Airtable connection successful")
        update_offender_fields()
      {:error, reason} ->
        Logger.error("❌ Failed to connect to Airtable: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp test_airtable_connection do
    path = "/#{@airtable_base_id}/#{@airtable_table_id}"
    
    case @client.get(path, %{maxRecords: 1}) do
      {:ok, _response} -> :ok
      {:error, error} -> {:error, error}
    end
  end
  
  defp update_offender_fields do
    Logger.info("Fetching unique offenders from PostgreSQL...")
    
    # Get all unique offenders with their associated regulator_ids
    {:ok, offender_regulator_map} = build_offender_regulator_map()
    
    total_offenders = map_size(offender_regulator_map)
    Logger.info("Found #{total_offenders} unique offenders to update")
    
    # Get all regulator_ids to lookup in Airtable
    all_regulator_ids = offender_regulator_map |> Map.values() |> List.flatten() |> Enum.uniq()
    Logger.info("Need to lookup #{length(all_regulator_ids)} regulator_ids in Airtable")
    
    # Fetch Airtable data for all regulator_ids
    airtable_data = fetch_airtable_data_by_regulator_ids(all_regulator_ids)
    Logger.info("Retrieved #{map_size(airtable_data)} records from Airtable")
    
    # Process offenders in batches
    offender_regulator_map
    |> Map.keys()
    |> Enum.chunk_every(@batch_size)
    |> Enum.with_index()
    |> Enum.reduce(0, fn {offender_ids, batch_index}, acc ->
      batch_number = batch_index + 1
      estimated_batches = div(total_offenders, @batch_size) + 1
      Logger.info("Processing batch #{batch_number}/#{estimated_batches} (#{length(offender_ids)} offenders)")
      
      updated_count = update_offender_batch(offender_ids, offender_regulator_map, airtable_data)
      new_acc = acc + updated_count
      
      Logger.info("✅ Batch #{batch_number} completed. Updated #{updated_count} offenders. Total: #{new_acc}")
      
      # Progress updates every 5 batches  
      if rem(batch_number, 5) == 0 do
        Logger.info("🚀 Progress: #{new_acc}/#{total_offenders} offenders updated (#{Float.round(new_acc / total_offenders * 100, 1)}%)")
      end
      
      new_acc
    end)
    |> case do
      final_count ->
        Logger.info("🎉 Update completed! Successfully updated #{final_count}/#{total_offenders} offenders")
        {:ok, final_count}
    end
  end
  
  defp build_offender_regulator_map do
    # Get all cases and notices with their regulator_ids and offender_ids
    {:ok, cases} = Enforcement.read(Enforcement.Case, load: [:offender])
    {:ok, notices} = Enforcement.read(Enforcement.Notice, load: [:offender])
    
    # Build map: offender_id => [regulator_ids]
    offender_map = %{}
    
    # Add cases
    offender_map = Enum.reduce(cases, offender_map, fn case_record, acc ->
      if case_record.offender && case_record.regulator_id do
        Map.update(acc, case_record.offender.id, [case_record.regulator_id], fn existing ->
          [case_record.regulator_id | existing]
        end)
      else
        acc
      end
    end)
    
    # Add notices
    offender_map = Enum.reduce(notices, offender_map, fn notice_record, acc ->
      if notice_record.offender && notice_record.regulator_id do
        Map.update(acc, notice_record.offender.id, [notice_record.regulator_id], fn existing ->
          [notice_record.regulator_id | existing]
        end)
      else
        acc
      end
    end)
    
    {:ok, offender_map}
  end
  
  defp fetch_airtable_data_by_regulator_ids(regulator_ids) do
    Logger.info("Fetching Airtable data in batches...")
    
    # Airtable API has a limit on URL length, so we'll fetch all records and filter
    # This is more efficient than making individual requests
    airtable_records = fetch_all_airtable_records()
    
    # Build map: regulator_id => airtable_fields
    Enum.reduce(airtable_records, %{}, fn record, acc ->
      fields = record["fields"] || %{}
      regulator_id = to_string(fields["regulator_id"] || "")
      
      if regulator_id != "" and regulator_id in regulator_ids do
        Map.put(acc, regulator_id, fields)
      else
        acc
      end
    end)
  end
  
  defp fetch_all_airtable_records do
    Logger.info("Fetching all Airtable records...")
    
    fetch_airtable_page(nil, [])
  end
  
  defp fetch_airtable_page(offset, accumulated_records) do
    path = "/#{@airtable_base_id}/#{@airtable_table_id}"
    
    params = case offset do
      nil -> %{maxRecords: 500}  # Fetch larger pages for efficiency
      offset -> %{offset: offset, maxRecords: 500}
    end
    
    case @client.get(path, params) do
      {:ok, %{"records" => records, "offset" => next_offset}} when is_list(records) and is_binary(next_offset) ->
        new_accumulated = accumulated_records ++ records
        Logger.info("Fetched #{length(new_accumulated)} records so far...")
        fetch_airtable_page(next_offset, new_accumulated)
        
      {:ok, %{"records" => records}} when is_list(records) ->
        final_records = accumulated_records ++ records
        Logger.info("Completed fetching #{length(final_records)} Airtable records")
        final_records
        
      {:error, error} ->
        Logger.error("Failed to fetch Airtable records: #{inspect(error)}")
        accumulated_records
    end
  end
  
  defp update_offender_batch(offender_ids, offender_regulator_map, airtable_data) do
    Enum.reduce(offender_ids, 0, fn offender_id, updated_count ->
      case update_single_offender(offender_id, offender_regulator_map, airtable_data) do
        :updated -> updated_count + 1
        :skipped -> updated_count
        :error -> updated_count
      end
    end)
  end
  
  defp update_single_offender(offender_id, offender_regulator_map, airtable_data) do
    # Get the regulator_ids for this offender
    regulator_ids = Map.get(offender_regulator_map, offender_id, [])
    
    if regulator_ids == [] do
      Logger.warning("No regulator_ids found for offender #{offender_id}")
      return :skipped
    end
    
    # Find the first Airtable record that has the additional offender fields we need
    airtable_record = Enum.find_value(regulator_ids, fn regulator_id ->
      case Map.get(airtable_data, regulator_id) do
        nil -> nil
        fields -> fields
      end
    end)
    
    if not airtable_record do
      Logger.warning("No Airtable data found for offender #{offender_id} (regulator_ids: #{inspect(regulator_ids)})")
      return :skipped
    end
    
    # Get current offender
    case Enforcement.get(Enforcement.Offender, offender_id) do
      {:ok, offender} ->
        update_attrs = build_update_attrs(airtable_record, offender)
        
        if update_attrs != %{} do
          if @dry_run do
            Logger.info("DRY RUN: Would update offender #{offender_id} with: #{inspect(update_attrs)}")
            :updated
          else
            case Ash.update(offender, update_attrs) do
              {:ok, _updated_offender} ->
                Logger.debug("Updated offender #{offender_id} with #{map_size(update_attrs)} fields")
                :updated
                
              {:error, error} ->
                Logger.error("Failed to update offender #{offender_id}: #{inspect(error)}")
                :error
            end
          end
        else
          Logger.debug("No updates needed for offender #{offender_id}")
          :skipped
        end
        
      {:error, error} ->
        Logger.error("Failed to fetch offender #{offender_id}: #{inspect(error)}")
        :error
    end
  end
  
  defp build_update_attrs(airtable_fields, current_offender) do
    potential_updates = %{
      address: airtable_fields["offender_address"],
      country: airtable_fields["offender_country"],
      sic_code: airtable_fields["offender_sic"],
      industry: airtable_fields["offender_industry"],
      business_type: normalize_business_type(airtable_fields["offender_business_type"])
    }
    
    # Only include fields that are missing or empty in the current offender
    Enum.reduce(potential_updates, %{}, fn {field, new_value}, acc ->
      current_value = Map.get(current_offender, field)
      
      # Update if current field is nil/empty and new value is not nil/empty
      should_update = (is_nil(current_value) or current_value == "") and 
                      not (is_nil(new_value) or new_value == "")
      
      if should_update do
        Map.put(acc, field, new_value)
      else
        acc
      end
    end)
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
case OffenderFieldUpdater.run() do
  {:ok, count} ->
    IO.puts("Success: Updated #{count} offender records with missing field data")
    System.halt(0)
    
  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
    System.halt(1)
end