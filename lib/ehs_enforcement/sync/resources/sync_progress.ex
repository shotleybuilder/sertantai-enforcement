defmodule EhsEnforcement.Sync.SyncProgress do
  @moduledoc """
  Tracks detailed batch-level progress for sync operations.
  Enables granular monitoring and recovery capabilities.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "sync_progress"
    repo EhsEnforcement.Repo
  end

  attributes do
    uuid_primary_key :id
    
    # Batch identification
    attribute :batch_number, :integer do
      allow_nil? false
      description "Sequential batch number within the session"
    end
    
    attribute :batch_size, :integer do
      allow_nil? false
      description "Number of records in this batch"
    end
    
    # Batch status
    attribute :status, :atom do
      constraints [one_of: [:pending, :processing, :completed, :failed, :retrying]]
      default :pending
    end
    
    # Processing results
    attribute :records_processed, :integer do
      default 0
    end
    
    attribute :records_created, :integer do
      default 0
    end
    
    attribute :records_updated, :integer do
      default 0
    end
    
    attribute :records_existing, :integer do
      default 0
    end
    
    attribute :records_failed, :integer do
      default 0
    end
    
    # Timing
    attribute :started_at, :utc_datetime
    attribute :completed_at, :utc_datetime
    
    # Error handling
    attribute :error_message, :string
    attribute :error_details, :map
    attribute :retry_count, :integer, default: 0
    
    # Data tracking
    attribute :source_ids, {:array, :string} do
      description "Source record IDs processed in this batch"
    end
    
    attribute :failed_ids, {:array, :string} do
      description "Source record IDs that failed processing"
    end
    
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :sync_session, EhsEnforcement.Sync.SyncSession do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :update, :destroy]
    
    create :start_batch do
      accept [:sync_session_id, :batch_number, :batch_size, :source_ids]
      
      change set_attribute(:status, :pending)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end
    
    update :mark_processing do
      accept []
      
      change set_attribute(:status, :processing)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end
    
    update :update_batch_progress do
      accept [:records_processed, :records_created, :records_updated, :records_existing, :records_failed]
    end
    
    update :mark_completed do
      accept [:records_created, :records_updated, :records_existing, :records_failed, :failed_ids]
      
      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
    
    update :mark_failed do
      accept [:error_message, :error_details, :failed_ids]
      
      change set_attribute(:status, :failed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
    
    update :increment_retry do
      require_atomic? false
      
      change fn changeset, _context ->
        current_count = Ash.Changeset.get_attribute(changeset, :retry_count) || 0
        Ash.Changeset.change_attribute(changeset, :retry_count, current_count + 1)
        |> Ash.Changeset.change_attribute(:status, :retrying)
      end
    end
  end

  calculations do
    calculate :success_rate, :decimal do
      calculation fn records, context ->
        total = Map.get(records, :batch_size, 0)
        failed = Map.get(records, :records_failed, 0)
        
        if total > 0 do
          successful = total - failed
          Decimal.div(Decimal.new(successful * 100), Decimal.new(total))
        else
          Decimal.new(100)
        end
      end
    end
    
    calculate :processing_duration, :integer do
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
    define :start_batch
    define :mark_processing
    define :update_batch_progress
    define :mark_completed
    define :mark_failed
    define :increment_retry
    define :read
  end
end