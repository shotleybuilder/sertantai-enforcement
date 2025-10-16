#!/usr/bin/env elixir

# Clean Notice table and import 1000 notice records using the new Sync domain function
# Usage: mix run scripts/clean_and_import_notices.exs

alias EhsEnforcement.Repo
alias EhsEnforcement.Sync
import Ecto.Query
require Logger

defmodule CleanAndImportNotices do
  def run do
    Logger.info("🧹 Starting Notice table cleanup and import process...")
    
    with :ok <- clean_notice_table(),
         {:ok, stats} <- import_notices() do
      Logger.info("✅ Process completed successfully!")
      verify_results(stats)
      {:ok, stats}
    else
      {:error, reason} ->
        Logger.error("❌ Process failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp clean_notice_table do
    Logger.info("🗑️  Cleaning Notice table...")
    
    notice_count = Repo.aggregate(from(n in "notices"), :count, :id)
    Logger.info("Found #{notice_count} notice records to delete")
    
    if notice_count > 0 do
      {deleted_count, _} = Repo.delete_all(from n in "notices")
      Logger.info("✅ Deleted #{deleted_count} notice records")
    else
      Logger.info("ℹ️  Notice table already empty")
    end
    
    :ok
  end

  defp import_notices do
    Logger.info("📥 Starting import of 1000 notice records using EhsEnforcement.Sync...")
    
    # Use our new Sync domain function
    case Sync.import_notices(limit: 1000, batch_size: 100) do
      {:ok, stats} ->
        Logger.info("🎉 Import successful!")
        Logger.info("📊 Import statistics: #{inspect(stats)}")
        {:ok, stats}
        
      {:error, reason} ->
        Logger.error("❌ Import failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp verify_results(stats) do
    Logger.info("🔍 Verifying final database state...")
    
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
    
    # Sample some notice records
    if notice_count > 0 do
      sample_notices = Repo.all(from n in "notices", 
        select: %{
          regulator_id: n.regulator_id,
          offence_action_type: n.offence_action_type,
          notice_date: n.notice_date,
          offence_action_date: n.offence_action_date
        }, 
        limit: 5
      )
      
      Logger.info("📋 Sample notice records:")
      Enum.each(sample_notices, fn notice ->
        Logger.info("   #{notice.regulator_id}: #{notice.offence_action_type} (#{notice.notice_date || notice.offence_action_date})")
      end)
      
      Logger.info("✅ SUCCESS: #{notice_count} notice records imported!")
    else
      Logger.warn("⚠️  No notice records found after import")
    end
    
    # Verify import stats match database counts
    if stats.imported == notice_count do
      Logger.info("✅ Import statistics match database counts")
    else
      Logger.warn("⚠️  Mismatch: imported #{stats.imported}, found #{notice_count} in database")
    end
    
    :ok
  end
end

# Run the cleanup and import
case CleanAndImportNotices.run() do
  {:ok, stats} ->
    IO.puts("✅ Success: Imported #{stats.imported} notice records with #{stats.errors} errors")
    System.stop(0)
    
  {:error, reason} ->
    IO.puts("❌ Error: #{inspect(reason)}")
    System.stop(1)
end