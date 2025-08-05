defmodule EhsEnforcement.Sync do
  @moduledoc """
  The Sync domain for managing synchronization operations and logs.
  Provides administrative functions for importing and syncing data from external sources.
  """
  
  use Ash.Domain
  
  alias EhsEnforcement.Sync.{AirtableImporter, EventBroadcaster, SessionManager, RecordProcessor}
  alias EhsEnforcement.Integrations.Airtable.ReqClient
  require Logger

  @pubsub_topic "sync_progress"

  resources do
    resource EhsEnforcement.Sync.SyncLog
    resource EhsEnforcement.Sync.SyncSession
    resource EhsEnforcement.Sync.SyncProgress
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
    
    with :ok <- validate_import_preconditions(),
         {:ok, stats} <- do_import_notices(limit, batch_size, actor) do
      Logger.info("✅ Notice import completed successfully")
      {:ok, stats}
    else
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
    
    with :ok <- validate_import_preconditions(),
         {:ok, stats} <- do_import_cases(limit, batch_size, actor) do
      Logger.info("✅ Case import completed successfully")
      {:ok, stats}
    else
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

  defp validate_import_preconditions do
    # Check Airtable connection
    case test_airtable_connection() do
      :ok -> 
        Logger.info("✅ Airtable connection validated")
        :ok
      {:error, reason} -> 
        Logger.error("❌ Airtable connection failed: #{inspect(reason)}")
        {:error, {:airtable_connection_failed, reason}}
    end
  end

  defp test_airtable_connection do
    path = "/appq5OQW9bTHC1zO5/tbl6NZm9bLU2ijivf"
    
    case ReqClient.get(path, %{maxRecords: 1}) do
      {:ok, _response} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp do_import_notices(limit, batch_size, actor) do
    Logger.info("📥 Starting notice import with limit: #{limit}, batch_size: #{batch_size}")
    
    # Start a new sync session using SessionManager
    session_config = %{
      sync_type: :import_notices,
      target_resource: "EhsEnforcement.Enforcement.Notice", 
      config: %{batch_size: batch_size, limit: limit},
      initiated_by: extract_user_identifier(actor),
      estimated_total: limit
    }
    
    {:ok, session} = SessionManager.start_session(session_config)
    SessionManager.mark_session_running(session.session_id)
    
    # Initialize counters for enhanced tracking
    total_created = 0
    total_updated = 0
    total_exists = 0
    total_errors = 0
    
    result = AirtableImporter.stream_airtable_records()
    |> Stream.filter(&is_notice_record?/1)
    |> Stream.take(limit)
    |> Stream.chunk_every(batch_size)
    |> Stream.with_index()
    |> Enum.reduce_while({total_created, total_updated, total_exists, total_errors}, fn {batch, batch_index}, {acc_created, acc_updated, acc_exists, acc_errors} ->
      batch_number = batch_index + 1
      Logger.info("📦 Processing batch #{batch_number} (#{length(batch)} notice records)")
      
      # Start batch tracking
      batch_config = %{
        batch_number: batch_number,
        batch_size: length(batch),
        source_ids: extract_source_ids(batch)
      }
      {:ok, batch_progress} = SessionManager.start_batch(session.session_id, batch_config)
      
      case import_notice_batch(batch, actor, session.session_id) do
        {:ok, batch_stats} ->
          new_created = acc_created + batch_stats.created
          new_updated = acc_updated + batch_stats.updated
          new_exists = acc_exists + batch_stats.exists
          new_errors = acc_errors + batch_stats.errors
          
          # Update batch progress with enhanced statistics
          batch_results = %{
            records_processed: batch_stats.processed,
            records_created: batch_stats.created,
            records_updated: batch_stats.updated,
            records_existing: batch_stats.exists,
            records_failed: batch_stats.errors
          }
          
          SessionManager.update_batch_progress(batch_progress.id, batch_results)
          SessionManager.complete_batch(batch_progress.id, batch_results)
          
          Logger.info("✅ Batch #{batch_number} completed. Created: #{batch_stats.created}, Updated: #{batch_stats.updated}, Exists: #{batch_stats.exists}, Errors: #{batch_stats.errors}")
          
          total_processed = new_created + new_updated + new_exists
          if total_processed >= limit do
            {:halt, {new_created, new_updated, new_exists, new_errors}}
          else
            {:cont, {new_created, new_updated, new_exists, new_errors}}
          end
          
      end
    end)
    
    case result do
      {created, updated, exists, errors} ->
        total_processed = created + updated + exists + errors
        Logger.info("🎉 Notice import completed! Created: #{created}, Updated: #{updated}, Exists: #{exists}, Errors: #{errors}")
        
        # Complete the session with final stats
        final_stats = %{
          total_processed: total_processed,
          total_created: created,
          total_updated: updated,
          total_existing: exists,
          total_failed: errors,
          sync_type: :import_notices
        }
        
        SessionManager.complete_session(session.session_id, final_stats)
        
        {:ok, %{imported: total_processed, created: created, updated: updated, existing: exists, errors: []}}
        
      error ->
        Logger.error("💥 Notice import failed: #{inspect(error)}")
        
        # Mark session as failed
        error_info = %{
          message: "Notice import failed",
          error: inspect(error),
          sync_type: :import_notices
        }
        
        SessionManager.fail_session(session.session_id, error_info)
        
        {:error, error}
    end
  end

  defp do_import_cases(limit, batch_size, actor) do
    Logger.info("📥 Starting case import with limit: #{limit}, batch_size: #{batch_size}")
    
    # Start a new sync session using SessionManager
    session_config = %{
      sync_type: :import_cases,
      target_resource: "EhsEnforcement.Enforcement.Case", 
      config: %{batch_size: batch_size, limit: limit},
      initiated_by: extract_user_identifier(actor),
      estimated_total: limit
    }
    
    {:ok, session} = SessionManager.start_session(session_config)
    SessionManager.mark_session_running(session.session_id)
    
    # Initialize counters for enhanced tracking
    total_created = 0
    total_updated = 0
    total_exists = 0
    total_errors = 0
    
    result = AirtableImporter.stream_airtable_records()
    |> Stream.filter(&is_case_record?/1)
    |> Stream.take(limit)
    |> Stream.chunk_every(batch_size)
    |> Stream.with_index()
    |> Enum.reduce_while({total_created, total_updated, total_exists, total_errors}, fn {batch, batch_index}, {acc_created, acc_updated, acc_exists, acc_errors} ->
      batch_number = batch_index + 1
      Logger.info("📦 Processing batch #{batch_number} (#{length(batch)} case records)")
      
      # Start batch tracking
      batch_config = %{
        batch_number: batch_number,
        batch_size: length(batch),
        source_ids: extract_source_ids(batch)
      }
      {:ok, batch_progress} = SessionManager.start_batch(session.session_id, batch_config)
      
      case import_case_batch(batch, actor, session.session_id) do
        {:ok, batch_stats} ->
          new_created = acc_created + batch_stats.created
          new_updated = acc_updated + batch_stats.updated
          new_exists = acc_exists + batch_stats.exists
          new_errors = acc_errors + batch_stats.errors
          
          # Update batch progress with enhanced statistics
          batch_results = %{
            records_processed: batch_stats.processed,
            records_created: batch_stats.created,
            records_updated: batch_stats.updated,
            records_existing: batch_stats.exists,
            records_failed: batch_stats.errors
          }
          
          SessionManager.update_batch_progress(batch_progress.id, batch_results)
          SessionManager.complete_batch(batch_progress.id, batch_results)
          
          Logger.info("✅ Batch #{batch_number} completed. Created: #{batch_stats.created}, Updated: #{batch_stats.updated}, Exists: #{batch_stats.exists}, Errors: #{batch_stats.errors}")
          
          total_processed = new_created + new_updated + new_exists
          if total_processed >= limit do
            {:halt, {new_created, new_updated, new_exists, new_errors}}
          else
            {:cont, {new_created, new_updated, new_exists, new_errors}}
          end
          
      end
    end)
    
    case result do
      {created, updated, exists, errors} ->
        total_processed = created + updated + exists + errors
        Logger.info("🎉 Case import completed! Created: #{created}, Updated: #{updated}, Exists: #{exists}, Errors: #{errors}")
        
        # Complete the session with final stats
        final_stats = %{
          total_processed: total_processed,
          total_created: created,
          total_updated: updated,
          total_existing: exists,
          total_failed: errors,
          sync_type: :import_cases
        }
        
        SessionManager.complete_session(session.session_id, final_stats)
        
        {:ok, %{imported: total_processed, created: created, updated: updated, existing: exists, errors: []}}
        
      error ->
        Logger.error("💥 Case import failed: #{inspect(error)}")
        
        # Mark session as failed
        error_info = %{
          message: "Case import failed",
          error: inspect(error),
          sync_type: :import_cases
        }
        
        SessionManager.fail_session(session.session_id, error_info)
        
        {:error, error}
    end
  end

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

  defp import_case_batch(records, actor, session_id \\ nil) do
    results = Enum.map(records, fn record ->
      RecordProcessor.process_case_record(record, actor: actor, session_id: session_id)
    end)
    
    # Count results by status
    created_count = Enum.count(results, fn {status, _} -> status == :created end)
    updated_count = Enum.count(results, fn {status, _} -> status == :updated end) 
    exists_count = Enum.count(results, fn {status, _} -> status == :exists end)
    error_count = Enum.count(results, fn {status, _} -> status == :error end)
    
    total_processed = created_count + updated_count + exists_count + error_count
    
    {:ok, %{
      processed: total_processed,
      created: created_count,
      updated: updated_count,
      exists: exists_count,
      errors: error_count
    }}
  end

  defp import_notice_batch(records, actor, session_id \\ nil) do
    results = Enum.map(records, fn record ->
      RecordProcessor.process_notice_record(record, actor: actor, session_id: session_id)
    end)
    
    # Count results by status
    created_count = Enum.count(results, fn {status, _} -> status == :created end)
    updated_count = Enum.count(results, fn {status, _} -> status == :updated end)
    exists_count = Enum.count(results, fn {status, _} -> status == :exists end)
    error_count = Enum.count(results, fn {status, _} -> status == :error end)
    
    total_processed = created_count + updated_count + exists_count + error_count
    
    {:ok, %{
      processed: total_processed,
      created: created_count,
      updated: updated_count,
      exists: exists_count,
      errors: error_count
    }}
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
  
  defp extract_source_ids(batch) do
    Enum.map(batch, fn record ->
      case record do
        %{"id" => id} -> id
        %{"fields" => %{"regulator_id" => reg_id}} -> reg_id
        _ -> nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end
  
  # Legacy PubSub broadcasting function (maintained for backwards compatibility)
  defp broadcast_sync_event(event_type, data) do
    # Use new EventBroadcaster for enhanced functionality
    EventBroadcaster.broadcast(event_type, data, topic: @pubsub_topic)
  end
end