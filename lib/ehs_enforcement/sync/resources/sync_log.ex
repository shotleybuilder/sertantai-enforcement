defmodule EhsEnforcement.Sync.SyncLog do
  @moduledoc """
  Tracks synchronization operations and their results.
  Enhanced for package-ready architecture with generic logging capabilities.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "sync_logs"
    repo EhsEnforcement.Repo
  end

  attributes do
    uuid_primary_key :id
    
    # Enhanced sync type support for package-ready design
    attribute :sync_type, :atom do
      constraints [one_of: [:cases, :notices, :import_cases, :import_notices, :import_all, :export_cases, :export_notices, :custom]]
      description "Type of sync operation for backwards compatibility and future expansion"
    end
    
    attribute :operation_type, :string do
      description "Generic operation type for package-ready design (import, export, transform, etc.)"
    end
    
    attribute :resource_type, :string do
      description "Target resource type for generic logging"
    end
    
    attribute :status, :atom do
      constraints [one_of: [:started, :completed, :failed, :cancelled, :retrying]]
    end
    
    # Enhanced statistics
    attribute :records_synced, :integer, default: 0
    attribute :records_created, :integer, default: 0
    attribute :records_updated, :integer, default: 0
    attribute :records_existing, :integer, default: 0
    attribute :records_failed, :integer, default: 0
    
    # Enhanced error tracking
    attribute :error_message, :string
    attribute :error_details, :map
    attribute :error_count, :integer, default: 0
    
    # Timing
    attribute :started_at, :utc_datetime
    attribute :completed_at, :utc_datetime
    
    # Session tracking for correlation
    attribute :session_id, :string do
      description "Links to sync session for comprehensive tracking"
    end
    
    # Configuration context
    attribute :config_snapshot, :map do
      description "Configuration used for this sync operation"
    end
    
    # Performance metrics
    attribute :processing_time_seconds, :integer
    attribute :records_per_second, :decimal
    
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :agency, EhsEnforcement.Enforcement.Agency do
      allow_nil? true  # Made optional for generic design
      description "Associated agency (optional for package-ready design)"
    end
    
    belongs_to :sync_session, EhsEnforcement.Sync.SyncSession do
      allow_nil? true
      description "Associated sync session for detailed tracking"
    end
  end

  actions do
    defaults [:read, :update, :destroy]
    
    create :log_sync_start do
      accept [:sync_type, :operation_type, :resource_type, :session_id, :agency_id, :config_snapshot]
      
      change set_attribute(:status, :started)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end
    
    create :create do
      accept [:sync_type, :operation_type, :resource_type, :status, :records_synced, :records_created, 
              :records_updated, :records_existing, :records_failed, :error_message, :error_details, 
              :error_count, :started_at, :completed_at, :session_id, :agency_id, :config_snapshot,
              :processing_time_seconds, :records_per_second]
    end
    
    update :complete_sync do
      accept [:records_synced, :records_created, :records_updated, :records_existing, :records_failed]
      require_atomic? false
      
      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
      
      # Calculate performance metrics
      change fn changeset, _context ->
        case Ash.Changeset.get_data(changeset) do
          %{started_at: %DateTime{} = started} ->
            completed = DateTime.utc_now()
            duration = DateTime.diff(completed, started, :second)
            
            total_records = Ash.Changeset.get_attribute(changeset, :records_synced) || 0
            rate = if duration > 0 and total_records > 0 do
              Decimal.div(Decimal.new(total_records), Decimal.new(duration))
            else
              Decimal.new(0)
            end
            
            changeset
            |> Ash.Changeset.change_attribute(:processing_time_seconds, duration)
            |> Ash.Changeset.change_attribute(:records_per_second, rate)
            
          _ -> changeset
        end
      end
    end
    
    update :fail_sync do
      accept [:error_message, :error_details, :error_count, :records_synced, :records_failed]
      
      change set_attribute(:status, :failed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
  end

  calculations do
    calculate :success_rate, :decimal do
      calculation fn records, context ->
        synced = Map.get(records, :records_synced, 0)
        failed = Map.get(records, :records_failed, 0)
        total = synced + failed
        
        if total > 0 do
          Decimal.div(Decimal.new(synced * 100), Decimal.new(total))
        else
          Decimal.new(100)
        end
      end
    end
  end

  code_interface do
    define :create
    define :log_sync_start
    define :complete_sync
    define :fail_sync
    define :read
  end
end