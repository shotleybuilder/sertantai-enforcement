defmodule EhsEnforcement.Sync.SimpleSyncSession do
  @moduledoc """
  Simplified sync session resource for Phase 1 compatibility.
  
  This resource provides basic session tracking functionality
  that works with our existing repo without complex foreign keys.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "simple_sync_sessions"
    repo EhsEnforcement.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :session_id, :string do
      allow_nil? false
      constraints max_length: 100
    end
    
    attribute :sync_type, :atom do
      allow_nil? false
      constraints one_of: [:import_cases, :import_notices, :custom_sync]
    end
    
    attribute :status, :atom do
      allow_nil? false
      default :pending
      constraints one_of: [:pending, :running, :completed, :failed, :cancelled]
    end
    
    attribute :target_resource, :string do
      constraints max_length: 255
    end
    
    attribute :progress_stats, :map do
      default %{}
    end
    
    attribute :started_at, :utc_datetime_usec
    attribute :completed_at, :utc_datetime_usec
    attribute :duration_ms, :integer
    
    attribute :config, :map do
      default %{}
    end
    
    attribute :initiated_by, :string do
      constraints max_length: 255
    end
    
    attribute :estimated_total, :integer
    attribute :actual_total, :integer
    attribute :error_count, :integer, default: 0
    attribute :last_error, :string, constraints: [max_length: 500]
    
    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :start do
      accept [:session_id, :sync_type, :target_resource, :initiated_by, :estimated_total]
      change set_attribute(:status, :running)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end
    
    update :complete do
      require_atomic? false
      argument :final_stats, :map, allow_nil?: false
      
      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
      change fn changeset, _context ->
        final_stats = Ash.Changeset.get_argument(changeset, :final_stats) || %{}
        changeset
        |> Ash.Changeset.change_attribute(:progress_stats, final_stats)
        |> Ash.Changeset.change_attribute(:actual_total, Map.get(final_stats, :processed, 0))
        |> calculate_duration()
      end
    end
    
    update :fail do
      require_atomic? false
      argument :error_message, :string, allow_nil?: false
      
      change set_attribute(:status, :failed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
      change fn changeset, _context ->
        error_message = Ash.Changeset.get_argument(changeset, :error_message)
        changeset
        |> Ash.Changeset.change_attribute(:last_error, error_message)
        |> calculate_duration()
      end
    end
  end

  defp calculate_duration(changeset) do
    started_at = Ash.Changeset.get_attribute(changeset, :started_at)
    completed_at = Ash.Changeset.get_attribute(changeset, :completed_at)
    
    case {started_at, completed_at} do
      {%DateTime{} = start, %DateTime{} = finish} ->
        duration_ms = DateTime.diff(finish, start, :millisecond)
        Ash.Changeset.change_attribute(changeset, :duration_ms, duration_ms)
      _ ->
        changeset
    end
  end
end