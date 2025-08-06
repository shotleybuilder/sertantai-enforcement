defmodule EhsEnforcement.Sync.ExtendedSyncLog do
  @moduledoc """
  Extended sync log resource that uses EhsEnforcement.Repo
  for Phase 1 compatibility.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "ehs_sync_logs"
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
    
    attribute :sync_batch_id, :uuid
    
    attribute :level, :atom do
      allow_nil? false
      constraints one_of: [:debug, :info, :warning, :error, :critical]
    end
    
    attribute :event_type, :string do
      allow_nil? false
      constraints max_length: 100
    end
    
    attribute :message, :string do
      allow_nil? false
      constraints max_length: 5000
    end
    
    attribute :event_data, :map do
      default %{}
    end
    
    attribute :source_record_id, :string do
      constraints max_length: 255
    end
    
    attribute :error_details, :map do
      default %{}
    end
    
    attribute :duration_ms, :integer
    attribute :occurred_at, :utc_datetime_usec
    
    timestamps()
  end

  relationships do
    belongs_to :sync_session, EhsEnforcement.Sync.ExtendedSyncSession do
      source_attribute :sync_session_id
      destination_attribute :id
      attribute_writable? true
    end
    
    belongs_to :sync_batch, EhsEnforcement.Sync.ExtendedSyncBatch do
      source_attribute :sync_batch_id
      destination_attribute :id
      attribute_writable? true
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end