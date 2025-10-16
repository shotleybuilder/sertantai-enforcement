#!/usr/bin/env elixir

# Clean dev database - delete misclassified case records 
# Usage: mix run scripts/clean_dev_db.exs

alias EhsEnforcement.Repo
import Ecto.Query
require Logger

defmodule CleanDevDB do
  def run do
    Logger.info("🧹 Starting database cleanup...")
    
    # Check current state
    case_count = Repo.aggregate(from(c in "cases"), :count, :id)
    notice_count = Repo.aggregate(from(n in "notices"), :count, :id)
    offender_count = Repo.aggregate(from(o in "offenders"), :count, :id)
    agency_count = Repo.aggregate(from(a in "agencies"), :count, :id)
    
    Logger.info("📊 Current database state:")
    Logger.info("   Cases: #{case_count}")
    Logger.info("   Notices: #{notice_count}")
    Logger.info("   Offenders: #{offender_count}")
    Logger.info("   Agencies: #{agency_count}")
    
    if case_count > 0 do
      Logger.info("🗑️  Deleting #{case_count} case records...")
      
      # Delete all cases but keep offenders and agencies
      {deleted_count, _} = Repo.delete_all(from c in "cases")
      
      Logger.info("✅ Deleted #{deleted_count} case records")
    else
      Logger.info("ℹ️  No case records to delete")
    end
    
    # Final state
    final_case_count = Repo.aggregate(from(c in "cases"), :count, :id)
    final_notice_count = Repo.aggregate(from(n in "notices"), :count, :id)
    final_offender_count = Repo.aggregate(from(o in "offenders"), :count, :id)
    final_agency_count = Repo.aggregate(from(a in "agencies"), :count, :id)
    
    Logger.info("📋 Final database state:")
    Logger.info("   Cases: #{final_case_count}")
    Logger.info("   Notices: #{final_notice_count}")
    Logger.info("   Offenders: #{final_offender_count}")
    Logger.info("   Agencies: #{final_agency_count}")
    
    Logger.info("✅ Database cleanup completed!")
    :ok
  end
end

# Run the cleanup
case CleanDevDB.run() do
  :ok ->
    IO.puts("✅ Success: Database cleaned")
    System.stop(0)
    
  {:error, reason} ->
    IO.puts("❌ Error: #{inspect(reason)}")
    System.stop(1)
end