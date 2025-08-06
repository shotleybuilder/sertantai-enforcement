defmodule EhsEnforcement.Sync.ExtendedSyncBatch do
  @moduledoc """
  Extended sync batch resource that uses EhsEnforcement.Repo
  for Phase 1 compatibility.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "ehs_sync_batches"
    repo EhsEnforcement.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :sync_session_id, :uuid do
      allow_nil? false
    end
    
    attribute :session_id, :string do
      allow_nil? false
      constraints max_length: 255
    end
    
    attribute :batch_number, :integer do
      allow_nil? false
      constraints min: 1
    end
    
    attribute :batch_size, :integer do
      allow_nil? false
      constraints min: 1
    end
    
    attribute :status, :atom do
      allow_nil? false
      default :pending
      constraints one_of: [:pending, :processing, :completed, :failed, :cancelled, :retrying]
    end
    
    attribute :source_ids, {:array, :string} do
      default []
    end
    
    attribute :records_processed, :integer do
      default 0
      constraints min: 0
    end
    
    attribute :records_created, :integer do
      default 0
      constraints min: 0
    end
    
    attribute :records_updated, :integer do
      default 0
      constraints min: 0
    end
    
    attribute :records_failed, :integer do
      default 0
      constraints min: 0
    end
    
    attribute :records_skipped, :integer do
      default 0
      constraints min: 0
    end
    
    attribute :started_at, :utc_datetime_usec
    attribute :completed_at, :utc_datetime_usec
    attribute :processing_time_ms, :integer
    
    attribute :error_details, :map do
      default %{}
    end
    
    attribute :batch_metadata, :map do
      default %{}
    end
    
    timestamps()
  end

  relationships do
    belongs_to :sync_session, EhsEnforcement.Sync.ExtendedSyncSession do
      source_attribute :sync_session_id
      destination_attribute :id
      attribute_writable? true
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end