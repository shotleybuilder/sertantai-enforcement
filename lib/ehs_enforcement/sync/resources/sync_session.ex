defmodule EhsEnforcement.Sync.SyncSession do
  @moduledoc """
  Tracks individual sync sessions for comprehensive monitoring and history.
  Designed with package-ready architecture for future extraction.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "sync_sessions"
    repo EhsEnforcement.Repo
  end

  attributes do
    uuid_primary_key :id
    
    # Generic session identification
    attribute :session_id, :string do
      allow_nil? false
      description "Unique session identifier for tracking across components"
    end
    
    # Sync operation details
    attribute :sync_type, :atom do
      constraints [one_of: [:import_cases, :import_notices, :import_all, :export_cases, :export_notices, :import_cases_enhanced, :import_notices_enhanced, :import_all_enhanced]]
      description "Type of synchronization operation"
    end
    
    attribute :source_type, :string do
      default "airtable"
      description "Source system type (airtable, csv, api, etc.)"
    end
    
    attribute :target_resource, :string do
      description "Target Ash resource module name for package-ready design"
    end
    
    # Session status and progress
    attribute :status, :atom do
      constraints [one_of: [:pending, :running, :completed, :failed, :cancelled]]
      default :pending
    end
    
    attribute :total_records, :integer do
      default 0
      description "Total records to be processed (if known)"
    end
    
    attribute :processed_records, :integer do
      default 0
      description "Records processed so far"
    end
    
    attribute :created_records, :integer do
      default 0
      description "New records created during sync"
    end
    
    attribute :updated_records, :integer do
      default 0
      description "Existing records updated during sync"
    end
    
    attribute :existing_records, :integer do
      default 0
      description "Records that already existed (no changes needed)"
    end
    
    attribute :error_records, :integer do
      default 0
      description "Records that failed to process"
    end
    
    # Configuration
    attribute :config, :map do
      default %{}
      description "Session configuration (batch_size, dry_run, etc.)"
    end
    
    # Timing
    attribute :started_at, :utc_datetime
    attribute :completed_at, :utc_datetime
    attribute :estimated_completion_at, :utc_datetime
    
    # Error handling
    attribute :error_message, :string
    attribute :error_details, :map
    
    # Actor tracking for authorization
    attribute :initiated_by, :string do
      description "User or system that initiated the sync"
    end
    
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :agency, EhsEnforcement.Enforcement.Agency do
      allow_nil? true
      description "Associated agency (optional for generic design)"
    end
    
    has_many :sync_progress_entries, EhsEnforcement.Sync.SyncProgress do
      description "Detailed batch-level progress tracking"
    end
  end

  actions do
    defaults [:read, :update, :destroy]
    
    create :start_session do
      accept [:session_id, :sync_type, :source_type, :target_resource, :config, :initiated_by, :agency_id, :total_records]
      
      change set_attribute(:status, :pending)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end
    
    update :mark_running do
      accept []
      
      change set_attribute(:status, :running)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end
    
    update :update_progress do
      accept [:processed_records, :created_records, :updated_records, :existing_records, :error_records, :total_records]
    end
    
    update :mark_completed do
      accept [:created_records, :updated_records, :existing_records, :error_records]
      
      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
    
    update :mark_failed do
      accept [:error_message, :error_details]
      
      change set_attribute(:status, :failed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
    
    update :mark_cancelled do
      accept []
      
      change set_attribute(:status, :cancelled)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
  end

  calculations do
    calculate :progress_percentage, :decimal do
      calculation fn records, context ->
        processed = Map.get(records, :processed_records, 0)
        total = Map.get(records, :total_records, 0)
        
        if total > 0 do
          Decimal.div(Decimal.new(processed * 100), Decimal.new(total))
        else
          Decimal.new(0)
        end
      end
    end
    
    calculate :duration_seconds, :integer do
      calculation fn records, context ->
        started = Map.get(records, :started_at)
        completed = Map.get(records, :completed_at)
        
        case {started, completed} do
          {%DateTime{} = start_time, %DateTime{} = end_time} ->
            DateTime.diff(end_time, start_time, :second)
          {%DateTime{} = start_time, nil} ->
            DateTime.diff(DateTime.utc_now(), start_time, :second)
          _ ->
            0
        end
      end
    end
  end

  code_interface do
    define :start_session
    define :mark_running
    define :update_progress
    define :mark_completed
    define :mark_failed
    define :mark_cancelled
    define :read
  end
end