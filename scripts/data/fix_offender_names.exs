#!/usr/bin/env elixir

# Fix offender names by reimporting from Airtable with proper capitalization
# Usage: mix run scripts/fix_offender_names.exs

alias EhsEnforcement.Integrations.Airtable.ReqClient
alias EhsEnforcement.Enforcement
require Logger

defmodule FixOffenderNames do
  @airtable_base_id "appq5OQW9bTHC1zO5"
  @airtable_table_id "tbl6NZm9bLU2ijivf"
  
  def run do
    Logger.info("Starting offender name fix from Airtable...")
    
    # Get all existing offenders
    {:ok, offenders} = Enforcement.list_offenders()
    Logger.info("Found #{length(offenders)} offenders to update")
    
    # Fetch records from Airtable to get original names
    updated_count = fetch_and_update_names()
    
    Logger.info("Successfully updated #{updated_count} offender names")
    {:ok, updated_count}
  end
  
  defp fetch_and_update_names do
    path = "/#{@airtable_base_id}/#{@airtable_table_id}"
    
    # Fetch all records from Airtable
    case ReqClient.get_all_records(path, %{}) do
      {:ok, %{"records" => records}} ->
        process_airtable_records(records)
        
      {:error, error} ->
        Logger.error("Failed to fetch from Airtable: #{inspect(error)}")
        0
    end
  end
  
  defp process_airtable_records(records) do
    # Create a map of normalized names to original names
    name_map = records
    |> Enum.reduce(%{}, fn record, acc ->
      case record["fields"]["offender_name"] do
        nil -> acc
        original_name ->
          normalized = EhsEnforcement.Sync.OffenderMatcher.normalize_company_name(original_name)
          Map.put(acc, normalized, original_name)
      end
    end)
    
    Logger.info("Built name map with #{map_size(name_map)} unique names")
    
    # Update each offender with the correct capitalization
    {:ok, offenders} = Enforcement.list_offenders()
    
    Enum.reduce(offenders, 0, fn offender, count ->
      case Map.get(name_map, offender.normalized_name || offender.name) do
        nil -> 
          count
          
        original_name when original_name != offender.name ->
          case Enforcement.update_offender(offender, %{name: original_name}) do
            {:ok, _} ->
              Logger.info("Updated: #{offender.name} -> #{original_name}")
              count + 1
              
            {:error, error} ->
              Logger.error("Failed to update #{offender.id}: #{inspect(error)}")
              count
          end
          
        _ ->
          # Name already correct
          count
      end
    end)
  end
end

# Run the fix
case FixOffenderNames.run() do
  {:ok, count} ->
    IO.puts("✅ Successfully updated #{count} offender names")
    System.stop(0)
    
  {:error, reason} ->
    IO.puts("❌ Error: #{inspect(reason)}")
    System.stop(1)
end