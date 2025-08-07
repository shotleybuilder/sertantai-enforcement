defmodule EhsEnforcement.Sync do
  @moduledoc """
  The Sync domain for managing synchronization operations and logs.
  Provides administrative functions for importing and syncing data from external sources.
  """
  
  use Ash.Domain
  
  alias EhsEnforcement.Sync.RecordProcessor
  require Logger

  @pubsub_topic "sync_progress"

  resources do
    # Use package resources directly - they should inherit our repo in production
    resource NCDB2Phx.Resources.SyncSession
    resource NCDB2Phx.Resources.SyncBatch  
    resource NCDB2Phx.Resources.SyncLog
    
    # Local extended resources
    resource EhsEnforcement.Sync.ExtendedSyncSession
    resource EhsEnforcement.Sync.ExtendedSyncBatch
    resource EhsEnforcement.Sync.ExtendedSyncLog
    resource EhsEnforcement.Sync.SimpleSyncSession
  end

  @doc """
  Import notice records from Airtable.
  
  This function streams records from Airtable, filters for notice types
  (records where offence_action_type contains "Notice"), and imports them
  into the notices table with proper relationships.
  
  ## Options
  
  * `:limit` - Maximum number of records to import (default: 1000)
  * `:batch_size` - Number of records to process per batch (default: 100)
  * `:actor` - The user performing the import (for authorization)
  
  ## Examples
  
      # Import 1000 notice records
      EhsEnforcement.Sync.import_notices()
      
      # Import 500 notice records
      EhsEnforcement.Sync.import_notices(limit: 500)
      
      # Import with specific actor for authorization
      EhsEnforcement.Sync.import_notices(actor: admin_user)
  
  ## Returns
  
  * `{:ok, %{imported: count, errors: errors}}` - Success with statistics
  * `{:error, reason}` - Failure with error details
  """
  def import_notices(opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)
    batch_size = Keyword.get(opts, :batch_size, 100)
    actor = Keyword.get(opts, :actor)
    
    Logger.info("🔍 Starting import of up to #{limit} notice records from Airtable...")
    
    # Phase 2: Use NCDB2Phx.execute_sync instead of custom logic
    config = build_sync_config(:notices, limit, batch_size, actor)
    
    case NCDB2Phx.execute_sync(config, actor: actor) do
      {:ok, result} ->
        Logger.info("✅ Notice import completed successfully")
        # Transform result to match legacy API
        {:ok, transform_sync_result_to_legacy_format(result)}
        
      {:error, reason} ->
        Logger.error("❌ Notice import failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Import case records from Airtable.
  
  This function streams records from Airtable, filters for case types
  (records where offence_action_type is "Court Case" or "Caution"), and imports them
  into the cases table with proper relationships.
  
  ## Options
  
  * `:limit` - Maximum number of records to import (default: 1000)
  * `:batch_size` - Number of records to process per batch (default: 100)
  * `:actor` - The user performing the import (for authorization)
  
  ## Examples
  
      # Import 1000 case records
      EhsEnforcement.Sync.import_cases()
      
      # Import 500 case records
      EhsEnforcement.Sync.import_cases(limit: 500)
      
      # Import with specific actor for authorization
      EhsEnforcement.Sync.import_cases(actor: admin_user)
  
  ## Returns
  
  * `{:ok, %{imported: count, errors: errors}}` - Success with statistics
  * `{:error, reason}` - Failure with error details
  """
  def import_cases(opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)
    batch_size = Keyword.get(opts, :batch_size, 100)
    actor = Keyword.get(opts, :actor)
    
    Logger.info("🔍 Starting import of up to #{limit} case records from Airtable...")
    
    # Phase 2: Use NCDB2Phx.execute_sync instead of custom logic
    config = build_sync_config(:cases, limit, batch_size, actor)
    
    case NCDB2Phx.execute_sync(config, actor: actor) do
      {:ok, result} ->
        Logger.info("✅ Case import completed successfully")
        # Transform result to match legacy API
        {:ok, transform_sync_result_to_legacy_format(result)}
        
      {:error, reason} ->
        Logger.error("❌ Case import failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get import statistics for notices.
  
  Returns counts of total notices, recent imports, and error rates.
  """
  def get_notice_import_stats do
    with {:ok, total_notices} <- count_notices(),
         {:ok, recent_imports} <- count_recent_notice_imports(),
         {:ok, error_rate} <- calculate_import_error_rate() do
      {:ok, %{
        total_notices: total_notices,
        recent_imports: recent_imports,
        error_rate: error_rate
      }}
    end
  end

  @doc """
  Get import statistics for cases.
  
  Returns counts of total cases, recent imports, and error rates.
  """
  def get_case_import_stats do
    with {:ok, total_cases} <- count_cases(),
         {:ok, recent_imports} <- count_recent_case_imports(),
         {:ok, error_rate} <- calculate_import_error_rate() do
      {:ok, %{
        total_cases: total_cases,
        recent_imports: recent_imports,
        error_rate: error_rate
      }}
    end
  end

  @doc """
  Clean up orphaned offenders that have no associated cases or notices.
  
  This function identifies and removes offender records that are no longer
  referenced by any cases or notices. This can happen when cases/notices
  are deleted but the database foreign keys don't cascade delete.
  
  ## Options
  
  * `:dry_run` - If true, only count orphaned offenders without deleting (default: false)
  * `:actor` - The user performing the cleanup (for authorization)
  
  ## Examples
  
      # Count orphaned offenders without deleting
      EhsEnforcement.Sync.cleanup_orphaned_offenders(dry_run: true)
      
      # Actually delete orphaned offenders
      EhsEnforcement.Sync.cleanup_orphaned_offenders()
  
  ## Returns
  
  * `{:ok, %{orphaned_count: count, deleted_count: deleted}}` - Success with counts
  * `{:error, reason}` - Failure with error details
  """
  def cleanup_orphaned_offenders(opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    actor = Keyword.get(opts, :actor)
    
    Logger.info("🧹 Starting orphaned offender cleanup (dry_run: #{dry_run})...")
    
    with {:ok, orphaned_count} <- count_orphaned_offenders(),
         {:ok, deleted_count} <- do_cleanup_orphaned_offenders(dry_run, actor) do
      
      if dry_run do
        Logger.info("🔍 Found #{orphaned_count} orphaned offenders (dry run - no deletion)")
        {:ok, %{orphaned_count: orphaned_count, deleted_count: 0}}
      else
        Logger.info("✅ Cleanup completed. Found: #{orphaned_count}, Deleted: #{deleted_count}")
        {:ok, %{orphaned_count: orphaned_count, deleted_count: deleted_count}}
      end
    else
      {:error, reason} ->
        Logger.error("❌ Orphaned offender cleanup failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions




  defp is_notice_record?(record) do
    fields = record["fields"] || %{}
    action_type = fields["offence_action_type"] || ""
    String.contains?(action_type, "Notice")
  end

  defp is_case_record?(record) do
    fields = record["fields"] || %{}
    action_type = fields["offence_action_type"] || ""
    action_type in ["Court Case", "Caution"]
  end



  defp count_notices do
    case EhsEnforcement.Enforcement.list_notices() do
      {:ok, notices} -> {:ok, length(notices)}
      {:error, error} -> {:error, error}
    end
  end

  defp count_cases do
    case EhsEnforcement.Enforcement.list_cases() do
      {:ok, cases} -> {:ok, length(cases)}
      {:error, error} -> {:error, error}
    end
  end

  defp count_recent_notice_imports do
    # This would query sync logs for recent notice imports
    # For now, return a placeholder
    {:ok, 0}
  end

  defp count_recent_case_imports do
    # This would query sync logs for recent case imports
    # For now, return a placeholder
    {:ok, 0}
  end

  defp calculate_import_error_rate do
    # This would calculate error rate from sync logs
    # For now, return a placeholder
    {:ok, 0.0}
  end

  defp count_orphaned_offenders do
    orphaned_query = """
      SELECT COUNT(*) as orphaned_count
      FROM offenders o
      WHERE NOT EXISTS (
        SELECT 1 FROM cases c WHERE c.offender_id = o.id
      ) AND NOT EXISTS (
        SELECT 1 FROM notices n WHERE n.offender_id = o.id
      )
    """
    
    case EhsEnforcement.Repo.query(orphaned_query) do
      {:ok, %{rows: [[count]]}} -> {:ok, count}
      {:error, error} -> {:error, error}
    end
  end

  defp do_cleanup_orphaned_offenders(true, _actor) do
    # Dry run - don't actually delete
    {:ok, 0}
  end

  defp do_cleanup_orphaned_offenders(false, _actor) do
    # Delete orphaned offenders using direct SQL for efficiency
    delete_query = """
      DELETE FROM offenders o
      WHERE NOT EXISTS (
        SELECT 1 FROM cases c WHERE c.offender_id = o.id
      ) AND NOT EXISTS (
        SELECT 1 FROM notices n WHERE n.offender_id = o.id
      )
    """
    
    case EhsEnforcement.Repo.query(delete_query) do
      {:ok, %{num_rows: deleted_count}} ->
        Logger.info("🗑️ Deleted #{deleted_count} orphaned offenders")
        {:ok, deleted_count}
        
      {:error, error} ->
        {:error, error}
    end
  end

  # Helper functions for enhanced sync functionality
  
  defp extract_user_identifier(nil), do: "system"
  defp extract_user_identifier(actor) when is_map(actor) do
    Map.get(actor, :email, Map.get(actor, :username, Map.get(actor, :id, "unknown_user")))
  end
  defp extract_user_identifier(actor), do: to_string(actor)
  
  
  # Phase 2: New functions for NCDB2Phx integration
  
  defp build_sync_config(sync_type, limit, batch_size, actor) do
    base_config = %{
      source_adapter: EhsEnforcement.Sync.Adapters.AirtableAdapter,
      source_config: airtable_source_config(),
      processing_config: %{
        batch_size: batch_size,
        limit: limit,
        enable_error_recovery: true,
        enable_progress_tracking: true,
        continue_on_error: true
      },
      pubsub_config: %{
        module: EhsEnforcementWeb.PubSub,
        topic: @pubsub_topic
      },
      session_config: %{
        sync_type: sync_type,
        description: "Import #{sync_type} records from Airtable",
        initiated_by: extract_user_identifier(actor)
      }
    }
    
    case sync_type do
      :cases ->
        Map.merge(base_config, %{
          target_resource: EhsEnforcement.Enforcement.Case,
          target_config: %{
            unique_field: :regulator_id,
            create_action: :create,
            update_action: :update,
            transform_fn: &RecordProcessor.process_case_record/1,
            filter_fn: &is_case_record?/1
          }
        })
        
      :notices ->
        Map.merge(base_config, %{
          target_resource: EhsEnforcement.Enforcement.Notice,
          target_config: %{
            unique_field: :notice_id,
            create_action: :create,
            update_action: :update,
            transform_fn: &RecordProcessor.process_notice_record/1,
            filter_fn: &is_notice_record?/1
          }
        })
    end
  end
  
  defp airtable_source_config do
    api_key = System.get_env("AT_UK_E_API_KEY")
    
    unless api_key do
      raise "Missing AT_UK_E_API_KEY environment variable"
    end
    
    %{
      api_key: api_key,
      base_id: "appq5OQW9bTHC1zO5",
      table_id: "tbl6NZm9bLU2ijivf",
      page_size: 100,
      rate_limit_delay_ms: 200,
      timeout_ms: 30_000,
      retry_attempts: 3,
      retry_delay_ms: 1000
    }
  end
  
  defp transform_sync_result_to_legacy_format(ncdb_result) do
    stats = Map.get(ncdb_result, :stats, %{})
    
    %{
      imported: Map.get(stats, :total_processed, 0),
      created: Map.get(stats, :created, 0),
      updated: Map.get(stats, :updated, 0),
      existing: Map.get(stats, :existing, 0),
      errors: []  # Legacy API returned empty array for errors
    }
  end
end