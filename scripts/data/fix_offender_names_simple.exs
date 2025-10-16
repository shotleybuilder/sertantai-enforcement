#!/usr/bin/env elixir

# Simple fix for offender names using title case
# Usage: mix run scripts/fix_offender_names_simple.exs

alias EhsEnforcement.Enforcement
require Logger

defmodule SimpleFixOffenderNames do
  def run do
    Logger.info("Starting simple offender name fix...")
    
    # Get all existing offenders
    {:ok, offenders} = Enforcement.list_offenders()
    Logger.info("Found #{length(offenders)} offenders to update")
    
    updated_count = Enum.reduce(offenders, 0, fn offender, count ->
      # Apply proper title case to names that are all lowercase
      if all_lowercase?(offender.name) do
        proper_name = to_title_case(offender.name)
        
        case Enforcement.update_offender(offender, %{name: proper_name}) do
          {:ok, _} ->
            Logger.info("Updated: #{offender.name} -> #{proper_name}")
            count + 1
            
          {:error, error} ->
            Logger.error("Failed to update #{offender.id}: #{inspect(error)}")
            count
        end
      else
        count
      end
    end)
    
    Logger.info("Successfully updated #{updated_count} offender names")
    {:ok, updated_count}
  end
  
  defp all_lowercase?(name) when is_binary(name) do
    name == String.downcase(name) and String.contains?(name, " ")
  end
  
  defp all_lowercase?(_), do: false
  
  defp to_title_case(name) when is_binary(name) do
    name
    |> String.split(" ")
    |> Enum.map(fn word ->
      case String.downcase(word) do
        # Keep common lowercase words as is
        "of" -> "of"
        "and" -> "and"
        "the" -> "the"
        "in" -> "in"
        "for" -> "for"
        "ltd" -> "Ltd"
        "limited" -> "Limited"
        "plc" -> "PLC"
        # Capitalize everything else
        _ -> String.capitalize(word)
      end
    end)
    |> Enum.join(" ")
  end
  
  defp to_title_case(name), do: name
end

# Run the fix
case SimpleFixOffenderNames.run() do
  {:ok, count} ->
    IO.puts("✅ Successfully updated #{count} offender names")
    System.stop(0)
    
  {:error, reason} ->
    IO.puts("❌ Error: #{inspect(reason)}")
    System.stop(1)
end