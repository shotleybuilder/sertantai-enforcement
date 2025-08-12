defmodule Mix.Tasks.PopulateOffenderAgencies do
  @shortdoc "Populate the agencies array field for existing offenders"
  @moduledoc """
  Populates the agencies array field for existing offenders based on their cases and notices.
  
  This task uses proper Ash queries and is safe to run in production.
  
  Usage:
    mix populate_offender_agencies
    
  Options:
    --dry-run    Show what would be updated without making changes
    --limit N    Only process first N offenders (for testing)
  """
  
  use Mix.Task
  require Logger
  
  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    
    {opts, _args} = OptionParser.parse!(args, 
      strict: [dry_run: :boolean, limit: :integer],
      aliases: [d: :dry_run, l: :limit]
    )
    
    dry_run = Keyword.get(opts, :dry_run, false)
    limit = Keyword.get(opts, :limit, nil)
    
    if dry_run do
      Logger.info("🔍 DRY RUN MODE - No changes will be made")
    end
    
    populate_agencies(dry_run: dry_run, limit: limit)
  end
  
  defp populate_agencies(opts) do
    dry_run = Keyword.get(opts, :dry_run, false)
    limit = Keyword.get(opts, :limit, nil)
    
    Logger.info("🚀 Starting offender agencies population...")
    
    # Get all offenders (we'll filter empty agencies in the task)
    offenders_query = EhsEnforcement.Enforcement.Offender
      |> Ash.Query.new()
      |> then(fn query ->
        if limit do
          Ash.Query.limit(query, limit)
        else
          query
        end
      end)
    
    case Ash.read(offenders_query) do
      {:ok, offenders} ->
        total_count = length(offenders)
        # Filter for offenders with empty agencies
        empty_agencies_offenders = Enum.filter(offenders, &(length(&1.agencies) == 0))
        empty_count = length(empty_agencies_offenders)
        
        Logger.info("📊 Found #{empty_count} offenders with empty agencies (out of #{total_count} total)")
        
        if empty_count == 0 do
          Logger.info("✅ All offenders already have agencies populated!")
          :ok
        else
        
          updated_count = process_offenders(empty_agencies_offenders, dry_run)
        
          Logger.info("✅ Population complete!")
          Logger.info("   Updated: #{updated_count}/#{empty_count} offenders")
          
          if not dry_run do
            verify_results()
          end
        end
        
      {:error, error} ->
        Logger.error("❌ Failed to fetch offenders: #{inspect(error)}")
    end
  end
  
  defp process_offenders(offenders, dry_run) do
    offenders
    |> Enum.with_index(1)
    |> Enum.reduce(0, fn {offender, index}, updated_count ->
      agencies = get_offender_agencies(offender.id)
      
      if length(agencies) > 0 do
        if dry_run do
          Logger.info("#{index}. #{offender.name} would get agencies: #{inspect(agencies)}")
        else
          case update_offender_agencies(offender, agencies) do
            {:ok, _updated_offender} ->
              Logger.info("#{index}. ✅ #{offender.name} -> #{inspect(agencies)}")
              updated_count + 1
              
            {:error, error} ->
              Logger.warning("#{index}. ❌ Failed to update #{offender.name}: #{inspect(error)}")
              updated_count
          end
        end
      else
        Logger.debug("#{index}. #{offender.name} (no agencies found)")
        updated_count
      end
    end)
  end
  
  defp get_offender_agencies(offender_id) do
    # Get agencies from cases
    case_agencies = case Ash.read(EhsEnforcement.Enforcement.Case) do
      {:ok, cases} ->
        cases
        |> Enum.filter(&(&1.offender_id == offender_id))
        |> Enum.map(fn case_record ->
          case Ash.load(case_record, :agency) do
            {:ok, loaded_case} -> loaded_case.agency.name
            _ -> nil
          end
        end)
        |> Enum.filter(&(&1 != nil))
        
      _ -> []
    end
    
    # Get agencies from notices  
    notice_agencies = case Ash.read(EhsEnforcement.Enforcement.Notice) do
      {:ok, notices} ->
        notices
        |> Enum.filter(&(&1.offender_id == offender_id))
        |> Enum.map(fn notice ->
          case Ash.load(notice, :agency) do
            {:ok, loaded_notice} -> loaded_notice.agency.name
            _ -> nil
          end
        end)
        |> Enum.filter(&(&1 != nil))
        
      _ -> []
    end
    
    # Combine and deduplicate
    (case_agencies ++ notice_agencies)
    |> Enum.uniq()
    |> Enum.sort()
  end
  
  defp update_offender_agencies(offender, agencies) do
    Ash.update(offender, %{agencies: agencies})
  end
  
  defp verify_results do
    Logger.info("🔍 Verifying results...")
    
    case Ash.read(EhsEnforcement.Enforcement.Offender) do
      {:ok, all_offenders} ->
        with_agencies = Enum.count(all_offenders, &(length(&1.agencies) > 0))
        total = length(all_offenders)
        percentage = Float.round(with_agencies / total * 100, 1)
        
        Logger.info("📈 Final stats: #{with_agencies}/#{total} offenders (#{percentage}%) have agencies")
        
        # Show some examples
        examples = all_offenders
          |> Enum.filter(&(length(&1.agencies) > 0))
          |> Enum.take(3)
        
        if length(examples) > 0 do
          Logger.info("📋 Examples:")
          for offender <- examples do
            Logger.info("   • #{offender.name}: #{inspect(offender.agencies)}")
          end
        end
        
      {:error, error} ->
        Logger.error("❌ Verification failed: #{inspect(error)}")
    end
  end
end