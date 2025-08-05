defmodule EhsEnforcement.Sync.Generic.Resources.GenericSyncBatch do
  @moduledoc """
  Generic Ash resource for tracking batch processing within sync sessions.
  
  This resource provides batch-level tracking for sync operations, allowing
  detailed monitoring of progress within individual batches. It's designed
  to be domain-agnostic and work with any sync operation.
  
  ## Features
  
  - Batch-level progress tracking
  - Per-batch statistics and timing
  - Error tracking and recovery status
  - Source record identification
  - Flexible batch metadata storage
  - Performance metrics calculation
  
  ## Usage
  
      # Start a new batch
      {:ok, batch} = Ash.create(GenericSyncBatch, %{
        session_id: "sync_abc123",
        batch_number: 1,
        batch_size: 100,
        source_ids: ["rec1", "rec2", "rec3"],
        started_at: DateTime.utc_now()
      })
      
      # Update batch progress
      {:ok, updated_batch} = Ash.update(batch, %{
        records_processed: 50,
        records_created: 30,
        records_updated: 15,
        records_failed: 5
      })
      
      # Complete batch
      {:ok, completed_batch} = Ash.update(batch, %{
        status: :completed,
        completed_at: DateTime.utc_now(),
        processing_time_ms: 5000
      }, action: :complete_batch)
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Sync.Generic,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "generic_sync_batches"
    repo EhsEnforcement.Repo
    
    custom_indexes do
      index [:session_id]
      index [:session_id, :batch_number], unique: true
      index [:status]
      index [:started_at]
      index [:completed_at]
      index [:session_id, :status]
    end
  end

  attributes do
    uuid_primary_key :id
    
    # Session relationship
    attribute :session_id, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 255
    end
    
    # Batch identification
    attribute :batch_number, :integer do
      allow_nil? false
      constraints min: 1
      description "Sequential batch number within the session (1, 2, 3, ...)"
    end
    
    attribute :batch_size, :integer do
      allow_nil? false
      constraints min: 1
      description "Number of records in this batch"
    end
    
    # Batch status
    attribute :status, :atom do
      allow_nil? false
      default :pending
      constraints one_of: [:pending, :processing, :completed, :failed, :cancelled, :retrying]
    end
    
    # Source record tracking
    attribute :source_ids, {:array, :string} do
      allow_nil? true
      default []
      description "Array of source record IDs in this batch"
    end
    
    # Progress statistics
    attribute :records_processed, :integer do
      allow_nil? false
      default 0
      constraints min: 0
      description "Total number of records processed in this batch"
    end
    
    attribute :records_created, :integer do
      allow_nil? false
      default 0
      constraints min: 0
      description "Number of new records created"
    end
    
    attribute :records_updated, :integer do
      allow_nil? false
      default 0
      constraints min: 0
      description "Number of existing records updated"
    end
    
    attribute :records_existing, :integer do
      allow_nil? false
      default 0
      constraints min: 0
      description "Number of records that already existed (skipped)"
    end
    
    attribute :records_failed, :integer do
      allow_nil? false
      default 0
      constraints min: 0
      description "Number of records that failed to process"
    end
    
    # Error and recovery information
    attribute :error_details, :map do
      allow_nil? true
      description "Detailed error information for failed records"
    end
    
    attribute :retry_count, :integer do
      allow_nil? false
      default 0
      constraints min: 0
      description "Number of times this batch has been retried"
    end
    
    attribute :recovery_attempted, :boolean do
      allow_nil? false
      default false
      description "Whether error recovery was attempted for this batch"
    end
    
    attribute :recovery_successful, :boolean do
      allow_nil? true
      description "Whether error recovery was successful (null if not attempted)"
    end
    
    # Timing information
    attribute :started_at, :utc_datetime_usec do
      allow_nil? true
      description "When batch processing started"
    end
    
    attribute :completed_at, :utc_datetime_usec do
      allow_nil? true
      description "When batch processing completed"
    end
    
    attribute :processing_time_ms, :integer do
      allow_nil? true
      constraints min: 0
      description "Time taken to process this batch in milliseconds"
    end
    
    # Additional metadata
    attribute :metadata, :map do
      allow_nil? true
      default %{}
      description "Additional batch-specific metadata"
    end
    
    # Audit trail
    timestamps()
  end

  actions do
    defaults [:read, :update, :destroy]
    
    create :create do
      accept [
        :session_id, :batch_number, :batch_size, :source_ids, :metadata
      ]
      
      validate attribute_equals(:status, :pending)
    end
    
    create :start_batch do
      accept [
        :session_id, :batch_number, :batch_size, :source_ids, :metadata
      ]
      
      change set_attribute(:status, :pending)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end
    
    update :mark_processing do
      accept []
      
      validate attribute_equals(:status, :pending)
      change set_attribute(:status, :processing)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end
    
    update :update_progress do
      accept [
        :records_processed, :records_created, :records_updated, 
        :records_existing, :records_failed
      ]
      
      validate attribute_in(:status, [:processing, :retrying])
    end
    
    update :complete_batch do
      accept [
        :records_processed, :records_created, :records_updated,
        :records_existing, :records_failed, :processing_time_ms, :metadata
      ]
      
      validate attribute_in(:status, [:processing, :retrying])
      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
    
    update :fail_batch do
      accept [:error_details, :processing_time_ms, :metadata]
      
      validate attribute_in(:status, [:processing, :retrying])
      change set_attribute(:status, :failed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
    
    update :cancel_batch do
      accept [:metadata]
      
      validate attribute_in(:status, [:pending, :processing])
      change set_attribute(:status, :cancelled)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
    
    update :retry_batch do
      accept [:metadata]
      
      validate attribute_equals(:status, :failed)
      change set_attribute(:status, :retrying)
      change set_attribute(:started_at, &DateTime.utc_now/0)
      change increment(:retry_count)
    end
    
    update :mark_recovery_attempted do
      accept [:recovery_successful, :metadata]
      
      change set_attribute(:recovery_attempted, true)
    end
  end

  relationships do
    belongs_to :sync_session, EhsEnforcement.Sync.Generic.Resources.GenericSyncSession do
      source_attribute :session_id
      destination_attribute :session_id
      attribute_type :string
    end
  end

  validations do
    validate present([:session_id, :batch_number, :batch_size])
  end

  calculations do
    calculate :completion_percentage, :float, expr(
      cond do
        batch_size == 0 -> 100.0
        true -> records_processed / batch_size * 100.0
      end
    )
    
    calculate :success_rate_percentage, :float, expr(
      cond do
        records_processed == 0 -> 0.0
        true -> (records_created + records_updated + records_existing) / records_processed * 100.0
      end
    )
    
    calculate :error_rate_percentage, :float, expr(
      cond do
        records_processed == 0 -> 0.0
        true -> records_failed / records_processed * 100.0
      end
    )
    
    calculate :processing_speed_records_per_second, :float, expr(
      cond do
        is_nil(processing_time_ms) or processing_time_ms == 0 -> 0.0
        true -> records_processed / (processing_time_ms / 1000.0)
      end
    )
    
    calculate :is_active, :boolean, expr(status in [:pending, :processing, :retrying])
    
    calculate :duration_seconds, :integer, expr(
      cond do
        is_nil(started_at) -> 0
        is_nil(completed_at) -> datetime_diff(now(), started_at, :second)
        true -> datetime_diff(completed_at, started_at, :second)
      end
    )
    
    calculate :has_errors, :boolean, expr(records_failed > 0)
    
    calculate :needs_retry, :boolean, expr(status == :failed and retry_count < 3)
  end

  # aggregates do
  #   # Aggregates for session-level statistics
  #   count :total_batches, [:batch_progress_records]
  #   
  #   sum :total_records_processed, [:batch_progress_records], field: :records_processed
  #   sum :total_records_created, [:batch_progress_records], field: :records_created
  #   sum :total_records_updated, [:batch_progress_records], field: :records_updated
  #   sum :total_records_failed, [:batch_progress_records], field: :records_failed
  #   
  #   avg :average_batch_processing_time, [:batch_progress_records], field: :processing_time_ms
  # end

  code_interface do
    define :create_batch, action: :create
    define :start_batch, action: :start_batch
    define :mark_processing, action: :mark_processing
    define :update_progress, action: :update_progress
    define :complete_batch, action: :complete_batch
    define :fail_batch, action: :fail_batch
    define :cancel_batch, action: :cancel_batch
    define :retry_batch, action: :retry_batch
    define :mark_recovery_attempted, action: :mark_recovery_attempted
    
    define :get_batch, action: :read, get_by: [:session_id, :batch_number]
    define :list_session_batches, action: :read, args: [:session_id]
    define :list_batches, action: :read
  end

  # Helper functions for batch management

  def get_batch_summary(batch) do
    %{
      batch_number: batch.batch_number,
      status: batch.status,
      processed: batch.records_processed,
      batch_size: batch.batch_size,
      created: batch.records_created,
      updated: batch.records_updated,
      existing: batch.records_existing,
      failed: batch.records_failed,
      processing_time_ms: batch.processing_time_ms,
      completion_percentage: calculate_completion_percentage(batch),
      success_rate: calculate_success_rate(batch)
    }
  end

  def calculate_completion_percentage(batch) do
    if batch.batch_size > 0 do
      Float.round(batch.records_processed / batch.batch_size * 100.0, 2)
    else
      100.0
    end
  end

  def calculate_success_rate(batch) do
    if batch.records_processed > 0 do
      successful = batch.records_created + batch.records_updated + batch.records_existing
      Float.round(successful / batch.records_processed * 100.0, 2)
    else
      0.0
    end
  end

  def is_batch_complete?(batch) do
    batch.status in [:completed, :failed, :cancelled]
  end

  def needs_retry?(batch) do
    batch.status == :failed and batch.retry_count < 3
  end

  def get_processing_speed(batch) do
    case {batch.records_processed, batch.processing_time_ms} do
      {0, _} -> 0.0
      {_, nil} -> 0.0
      {_, 0} -> 0.0
      {processed, time_ms} ->
        Float.round(processed / (time_ms / 1000.0), 2)
    end
  end

  def validate_statistics_consistency(batch) do
    expected_total = batch.records_created + batch.records_updated + 
                    batch.records_existing + batch.records_failed
    
    batch.records_processed == expected_total
  end
end