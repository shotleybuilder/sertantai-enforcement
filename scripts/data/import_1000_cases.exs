#!/usr/bin/env elixir

# Import 1000 case records using the new Sync domain function
# Usage: mix run scripts/import_1000_cases.exs

alias EhsEnforcement.Repo
alias EhsEnforcement.Sync
import Ecto.Query
require Logger

defmodule Import1000Cases do
  def run do
    Logger.info("🚀 Starting import of 1000 case records from Airtable...")
    
    with :ok <- show_initial_state(),
         {:ok, stats} <- import_cases() do
      Logger.info("✅ Import process completed successfully!")
      verify_results(stats)
      {:ok, stats}
    else
      {:error, reason} ->
        Logger.error("❌ Import process failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp show_initial_state do
    Logger.info("📊 Initial database state:")
    
    case_count = Repo.aggregate(from(c in "cases"), :count, :id)
    notice_count = Repo.aggregate(from(n in "notices"), :count, :id)
    offender_count = Repo.aggregate(from(o in "offenders"), :count, :id)
    agency_count = Repo.aggregate(from(a in "agencies"), :count, :id)
    
    Logger.info("   Cases: #{case_count}")
    Logger.info("   Notices: #{notice_count}")
    Logger.info("   Offenders: #{offender_count}")
    Logger.info("   Agencies: #{agency_count}")
    Logger.info("   Total enforcement records: #{case_count + notice_count}")
    
    :ok
  end

  defp import_cases do
    Logger.info("📥 Starting import of 1000 case records using EhsEnforcement.Sync...")
    
    # Use our new Sync domain function with optimized batch size for cases
    case Sync.import_cases(limit: 1000, batch_size: 50) do
      {:ok, stats} ->
        Logger.info("🎉 Case import successful!")
        Logger.info("📊 Import statistics: #{inspect(stats)}")
        {:ok, stats}
        
      {:error, reason} ->
        Logger.error("❌ Case import failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp verify_results(stats) do
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
    
    # Sample some case records to verify data quality
    if case_count > 0 do
      sample_cases = Repo.all(from c in "cases", 
        select: %{
          regulator_id: c.regulator_id,
          offence_action_type: c.offence_action_type,
          offence_action_date: c.offence_action_date,
          offence_fine: c.offence_fine,
          offence_costs: c.offence_costs,
          offence_result: c.offence_result
        }, 
        order_by: [desc: c.inserted_at],
        limit: 5
      )
      
      Logger.info("📋 Sample case records (most recent):")
      Enum.each(sample_cases, fn case_record ->
        fine_amount = if case_record.offence_fine, do: "£#{case_record.offence_fine}", else: "N/A"
        costs_amount = if case_record.offence_costs, do: "£#{case_record.offence_costs}", else: "N/A"
        Logger.info("   #{case_record.regulator_id}: #{case_record.offence_action_type} (#{case_record.offence_action_date})")
        Logger.info("     Result: #{case_record.offence_result || "N/A"}")
        Logger.info("     Fine: #{fine_amount}, Costs: #{costs_amount}")
      end)
      
      Logger.info("✅ SUCCESS: #{case_count} case records in database!")
    else
      Logger.warn("⚠️  No case records found after import")
    end
    
    # Verify import stats match expectations
    if stats.imported > 0 do
      Logger.info("✅ Import statistics: #{stats.imported} imported, #{stats.errors} errors")
      
      # Calculate success rate
      total_processed = stats.imported + stats.errors
      success_rate = if total_processed > 0, do: (stats.imported / total_processed * 100) |> Float.round(1), else: 0.0
      Logger.info("📈 Success rate: #{success_rate}%")
      
      if stats.errors > 0 do
        Logger.warn("⚠️  #{stats.errors} records failed to import - check logs for details")
      end
    else
      Logger.warn("ℹ️  No new case records were imported")
    end
    
    # Test case import statistics function
    case Sync.get_case_import_stats() do
      {:ok, import_stats} ->
        Logger.info("📊 Case import statistics: #{inspect(import_stats)}")
        
      {:error, reason} ->
        Logger.warn("⚠️  Could not retrieve case import statistics: #{inspect(reason)}")
    end
    
    # Check for any orphaned offenders (should be minimal with proper matching)
    orphaned_query = """
      SELECT COUNT(*) as orphaned_count
      FROM offenders o
      WHERE NOT EXISTS (
        SELECT 1 FROM cases c WHERE c.offender_id = o.id
      ) AND NOT EXISTS (
        SELECT 1 FROM notices n WHERE n.offender_id = o.id
      )
    """
    
    result = Repo.query!(orphaned_query)
    [[orphaned_count]] = result.rows
    
    if orphaned_count > 0 do
      Logger.info("ℹ️  Found #{orphaned_count} orphaned offenders (could be cleaned up with Sync.cleanup_orphaned_offenders/0)")
    else
      Logger.info("✅ No orphaned offenders found")
    end
    
    :ok
  end
end

# Run the import
case Import1000Cases.run() do
  {:ok, stats} ->
    IO.puts("✅ Success: Imported #{stats.imported} case records with #{stats.errors} errors")
    
    if stats.errors > 0 do
      IO.puts("⚠️  Some records failed to import - check the logs above for details")
      System.stop(0)  # Still exit successfully as partial import may be acceptable
    else
      IO.puts("🎉 Perfect! All records imported successfully")
      System.stop(0)
    end
    
  {:error, reason} ->
    IO.puts("❌ Error: #{inspect(reason)}")
    System.stop(1)
end