defmodule EhsEnforcement.Sync.Generic do
  @moduledoc """
  EHS Enforcement wrapper for the NCDB2Phx package.
  
  This module provides backward compatibility by delegating all operations
  to the extracted `NCDB2Phx` package. This allows existing EHS
  code to continue working while using the packageified sync engine.
  
  ## Migration Notes
  
  This module is now a compatibility wrapper around the `NCDB2Phx`
  package. All functionality has been moved to the package and this module
  simply delegates calls to maintain API compatibility.
  
  For new code, consider using `NCDB2Phx` directly:
  
      # Old way (still works)
      EhsEnforcement.Sync.Generic.execute_sync(config)
      
      # New way (recommended)
      NCDB2Phx.execute_sync(config)
  
  ## Package Vision Achieved
  
  The sync system has been successfully extracted into the `ncdb_2_phx`
  hex package, providing:
  
  - Generic sync engine with pluggable adapters
  - Universal progress tracking and monitoring
  - Real-time LiveView components  
  - Comprehensive error handling and recovery
  - Domain-agnostic Ash resources
  - Event-driven architecture with PubSub
  """
  
  # Delegate all operations to the package
  
  # Session operations
  defdelegate create_sync_session(attrs, opts \\ []), to: NCDB2Phx
  defdelegate start_sync_session(attrs, opts \\ []), to: NCDB2Phx
  defdelegate get_sync_session(session_id, opts \\ []), to: NCDB2Phx
  defdelegate list_active_sessions(opts \\ []), to: NCDB2Phx

  # Batch operations
  defdelegate create_sync_batch(attrs, opts \\ []), to: NCDB2Phx

  # Logging operations
  defdelegate log_sync_event(attrs, opts \\ []), to: NCDB2Phx
  defdelegate log_sync_error(attrs, opts \\ []), to: NCDB2Phx

  # High-level sync operations
  defdelegate execute_sync(config, opts \\ []), to: NCDB2Phx
  defdelegate stream_sync_records(config, opts \\ []), to: NCDB2Phx
  defdelegate get_sync_status(session_id), to: NCDB2Phx
  defdelegate cancel_sync(session_id), to: NCDB2Phx

  # Event system operations
  defdelegate broadcast_sync_event(event_type, event_data, opts \\ []), to: NCDB2Phx
  defdelegate subscribe_to_sync_events(topic), to: NCDB2Phx
  defdelegate stream_sync_events(topic, opts \\ []), to: NCDB2Phx

  # Utility functions
  defdelegate create_test_adapter(opts \\ []), to: NCDB2Phx
  defdelegate validate_sync_config(config, opts \\ []), to: NCDB2Phx
  defdelegate get_sync_metrics(session_id_or_filter, opts \\ []), to: NCDB2Phx

  # Package information
  def package_info do
    %{
      name: "ncdb_2_phx",
      version: "1.0.0", 
      description: "No-code database to Phoenix import engine with Ash Framework",
      status: "extracted",
      compatibility_wrapper: true,
      recommendation: "Use NCDB2Phx directly for new code"
    }
  end

  # For backwards compatibility, provide access to old resource references
  # These should be migrated to use package resources directly
  def __deprecated_resource_aliases__ do
    %{
      "EhsEnforcement.Sync.Generic.Resources.GenericSyncSession" => "NCDB2Phx.Resources.SyncSession",
      "EhsEnforcement.Sync.Generic.Resources.GenericSyncBatch" => "NCDB2Phx.Resources.SyncBatch", 
      "EhsEnforcement.Sync.Generic.Resources.GenericSyncLog" => "NCDB2Phx.Resources.SyncLog"
    }
  end
end