#!/usr/bin/env elixir

# Verify the results of the corrected import
# Usage: mix run scripts/verify_import.exs
#
# This script checks:
# 1. Record counts in each table (cases, notices, offenders, agencies)
# 2. Verifies proper classification between cases and notices
# 3. Samples records to confirm classification logic
# 4. Checks distribution of offence_action_type values

alias EhsEnforcement.Enforcement
require Logger

defmodule VerifyImport do
  def run do
    Logger.info("🔍 Verifying import results...")
    
    print_header("DATABASE RECORD COUNTS")
    check_record_counts()
    
    print_header("CASE vs NOTICE CLASSIFICATION")
    check_classification()
    
    print_header("OFFENCE ACTION TYPE DISTRIBUTION")
    check_action_type_distribution()
    
    print_header("SAMPLE RECORDS")
    sample_records()
    
    Logger.info("✅ Verification complete!")
  end

  defp print_header(title) do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("#{title}")
    IO.puts(String.duplicate("=", 60))
  end

  defp check_record_counts do
    IO.puts("Counting records in each table...")
    
    # Count agencies
    agency_count = Enforcement.list_agencies!() |> length()
    IO.puts("  📊 Agencies: #{agency_count}")
    
    # Count offenders
    offender_count = Enforcement.count_offenders!()
    IO.puts("  👥 Offenders: #{offender_count}")
    
    # Count cases
    case_count = Enforcement.count_cases!()
    IO.puts("  ⚖️  Cases: #{case_count}")
    
    # Count notices
    {:ok, notices} = Enforcement.list_notices()
    notice_count = length(notices)
    IO.puts("  📋 Notices: #{notice_count}")
    
    total_enforcement = case_count + notice_count
    IO.puts("  📈 Total Enforcement Records: #{total_enforcement}")
    
    if total_enforcement > 0 do
      case_percentage = Float.round(case_count / total_enforcement * 100, 1)
      notice_percentage = Float.round(notice_count / total_enforcement * 100, 1)
      IO.puts("  📊 Cases: #{case_percentage}% | Notices: #{notice_percentage}%")
    end
  end

  defp check_classification do
    IO.puts("Checking classification logic...")
    
    # Check cases - should only have "Court Case" or "Caution"
    {:ok, cases} = Enforcement.list_cases()
    
    case_action_types = cases 
    |> Enum.map(& &1.offence_action_type) 
    |> Enum.frequencies()
    
    IO.puts("  ⚖️  Case action types:")
    Enum.each(case_action_types, fn {type, count} ->
      IO.puts("     #{type}: #{count}")
    end)
    
    # Check notices - should have all other types
    {:ok, notices} = Enforcement.list_notices()
    
    notice_action_types = notices 
    |> Enum.map(& &1.offence_action_type) 
    |> Enum.frequencies()
    
    IO.puts("  📋 Notice action types:")
    Enum.each(notice_action_types, fn {type, count} ->
      IO.puts("     #{type}: #{count}")
    end)
    
    # Verify classification correctness
    invalid_cases = cases |> Enum.filter(fn case_record ->
      case_record.offence_action_type not in ["Court Case", "Caution"]
    end)
    
    invalid_notices = notices |> Enum.filter(fn notice ->
      notice.offence_action_type in ["Court Case", "Caution"]
    end)
    
    if length(invalid_cases) == 0 and length(invalid_notices) == 0 do
      IO.puts("  ✅ Classification is CORRECT!")
    else
      IO.puts("  ❌ Classification issues found:")
      IO.puts("     Invalid cases (should be notices): #{length(invalid_cases)}")
      IO.puts("     Invalid notices (should be cases): #{length(invalid_notices)}")
    end
  end

  defp check_action_type_distribution do
    IO.puts("Checking overall action type distribution...")
    
    # Get all action types from both cases and notices
    {:ok, cases} = Enforcement.list_cases()
    {:ok, notices} = Enforcement.list_notices()
    
    all_action_types = (cases ++ notices)
    |> Enum.map(& &1.offence_action_type)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_type, count} -> count end, :desc)
    
    IO.puts("  📊 All action types (sorted by frequency):")
    Enum.each(all_action_types, fn {type, count} ->
      classification = if type in ["Court Case", "Caution"], do: "CASE", else: "NOTICE"
      IO.puts("     #{type}: #{count} (#{classification})")
    end)
  end

  defp sample_records do
    IO.puts("Sampling records for verification...")
    
    # Sample a few cases
    {:ok, cases} = Enforcement.list_cases(limit: 3)
    IO.puts("  ⚖️  Sample Cases:")
    Enum.each(cases, fn case_record ->
      IO.puts("     ID: #{case_record.id}")
      IO.puts("     Action Type: #{case_record.offence_action_type}")
      IO.puts("     Offender: #{case_record.offender_name}")
      if case_record.offence_fine do
        IO.puts("     Fine: £#{case_record.offence_fine}")
      end
      IO.puts("     ---")
    end)
    
    # Sample a few notices
    {:ok, notices} = Enforcement.list_notices(limit: 3)
    IO.puts("  📋 Sample Notices:")
    Enum.each(notices, fn notice ->
      IO.puts("     ID: #{notice.id}")
      IO.puts("     Action Type: #{notice.offence_action_type}")
      IO.puts("     Offender: #{notice.offender_name}")
      IO.puts("     ---")
    end)
  end
end

# Run the verification
VerifyImport.run()