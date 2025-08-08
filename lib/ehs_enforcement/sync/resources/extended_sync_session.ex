defmodule EhsEnforcement.Sync.ExtendedSyncSession do
  @moduledoc """
  Extended sync session resource that uses EhsEnforcement.Repo
  instead of NCDB2Phx.Repo for Phase 1 compatibility.
  
  This resource extends the generic NCDB2Phx.Resources.SyncSession
  to work with our application's repo and domain while maintaining
  all the functionality.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Sync,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPhoenix.Form]

  require Ash.Query
  import Ash.Expr

  postgres do
    table "ehs_sync_sessions"
    repo EhsEnforcement.Repo
  end

  # Inherit all attributes from the base resource
  attributes do
    uuid_primary_key :id
    
    # Core session identification
    attribute :session_id, :string do
      allow_nil? false
      constraints max_length: 100
      description "Unique identifier for the sync session"
    end
    
    # Sync operation metadata
    attribute :sync_type, :atom do
      allow_nil? false
      constraints one_of: [
        :import_cases,
        :import_notices,
        :import_airtable,
        :export_airtable,
        :bidirectional_sync,
        :import_csv,
        :import_api,
        :import_database,
        :custom_sync
      ]
      description "Type of sync operation being performed"
    end
    
    attribute :target_resource, :string do
      allow_nil? false
      constraints max_length: 255
      description "Full module name of the target Ash resource"
    end
    
    attribute :source_adapter, :string do
      allow_nil? false
      constraints max_length: 255
      description "Full module name of the source adapter"
    end
    
    # Session status and progress
    attribute :status, :atom do
      allow_nil? false
      default :pending
      constraints one_of: [
        :pending,
        :initializing,
        :running,
        :paused,
        :completed,
        :failed,
        :cancelled
      ]
      description "Current status of the sync session"
    end
    
    attribute :progress_stats, :map do
      default %{}
      description "Statistics about sync progress (processed, created, updated, etc.)"
    end
    
    # Timing information
    attribute :started_at, :utc_datetime_usec do
      description "When the sync session was started"
    end
    
    attribute :completed_at, :utc_datetime_usec do
      description "When the sync session completed (success or failure)"
    end
    
    attribute :duration_ms, :integer do
      description "Total duration of the sync session in milliseconds"
    end
    
    # Configuration and metadata
    attribute :config, :map do
      default %{}
      description "Configuration parameters used for the sync"
    end
    
    attribute :metadata, :map do
      default %{}
      description "Additional metadata about the sync session"
    end
    
    # User tracking
    attribute :initiated_by, :string do
      constraints max_length: 255
      description "Identifier of the user or system that initiated the sync"
    end
    
    # Progress tracking
    attribute :estimated_total, :integer do
      description "Estimated total number of records to process"
    end
    
    attribute :actual_total, :integer do
      description "Actual total number of records processed"
    end
    
    # Error tracking
    attribute :error_count, :integer do
      default 0
      description "Total number of errors encountered during sync"
    end
    
    attribute :error_details, :map do
      default %{}
      description "Detailed error information"
    end
    
    attribute :last_error, :string do
      constraints max_length: 500
      description "Last error message encountered"
    end
    
    # Timestamps
    timestamps()
  end

  relationships do
    has_many :sync_batches, EhsEnforcement.Sync.ExtendedSyncBatch do
      destination_attribute :sync_session_id
      source_attribute :id
    end
    
    has_many :sync_logs, EhsEnforcement.Sync.ExtendedSyncLog do
      destination_attribute :sync_session_id
      source_attribute :id
    end
  end

  calculations do
    calculate :processing_speed, :float, expr(
      if actual_total > 0 and duration_ms > 0 do
        actual_total * 1000.0 / duration_ms
      else
        0.0
      end
    ) do
      description "Records processed per second"
    end
    
    calculate :progress_percentage, :float, expr(
      if estimated_total > 0 do
        get_path(progress_stats, [:processed]) * 100.0 / estimated_total
      else
        0.0
      end
    ) do
      description "Completion percentage based on estimated total"
    end
    
    calculate :error_rate, :float, expr(
      if actual_total > 0 do
        error_count * 100.0 / actual_total
      else
        0.0
      end
    ) do
      description "Error rate as percentage of total processed"
    end
    
    calculate :is_active, :boolean, expr(status in [:pending, :initializing, :running, :paused]) do
      description "Whether the sync session is currently active"
    end
  end

  actions do
    defaults [:read, :destroy]
    
    read :get_session do
      argument :session_id, :string, allow_nil?: false
      filter expr(session_id == ^arg(:session_id))
    end
    
    create :create do
      accept [
        :session_id,
        :sync_type,
        :target_resource,
        :source_adapter,
        :config,
        :metadata,
        :initiated_by,
        :estimated_total
      ]
      
      change set_attribute(:status, :pending)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end
    
    update :mark_running do
      change set_attribute(:status, :running)
    end
    
    update :mark_completed do
      argument :final_stats, :map, allow_nil?: false
      require_atomic? false
      
      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
      change fn changeset, _context ->
        final_stats = Ash.Changeset.get_argument(changeset, :final_stats)
        changeset
        |> Ash.Changeset.change_attribute(:progress_stats, final_stats)
        |> Ash.Changeset.change_attribute(:actual_total, Map.get(final_stats, :total_processed, 0))
        |> calculate_duration()
      end
    end
    
    update :mark_failed do
      argument :error_info, :map, allow_nil?: false
      require_atomic? false
      
      change set_attribute(:status, :failed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
      change fn changeset, _context ->
        error_info = Ash.Changeset.get_argument(changeset, :error_info)
        changeset
        |> Ash.Changeset.change_attribute(:error_details, error_info)
        |> Ash.Changeset.change_attribute(:last_error, Map.get(error_info, :message, "Unknown error"))
        |> calculate_duration()
      end
    end
    
    update :update_progress do
      argument :progress_update, :map, allow_nil?: false
      require_atomic? false
      
      change fn changeset, _context ->
        progress_update = Ash.Changeset.get_argument(changeset, :progress_update)
        current_stats = Ash.Changeset.get_attribute(changeset, :progress_stats) || %{}
        updated_stats = Map.merge(current_stats, progress_update)
        
        Ash.Changeset.change_attribute(changeset, :progress_stats, updated_stats)
      end
    end
  end

  # Helper functions
  defp calculate_duration(changeset) do
    started_at = Ash.Changeset.get_attribute(changeset, :started_at)
    completed_at = Ash.Changeset.get_attribute(changeset, :completed_at)
    
    if started_at and completed_at do
      duration_ms = DateTime.diff(completed_at, started_at, :millisecond)
      Ash.Changeset.change_attribute(changeset, :duration_ms, duration_ms)
    else
      changeset
    end
  end
end