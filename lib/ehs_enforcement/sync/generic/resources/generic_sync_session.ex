defmodule EhsEnforcement.Sync.Generic.Resources.GenericSyncSession do
  @moduledoc """
  Generic Ash resource for tracking sync sessions across any application.
  
  This resource provides a domain-agnostic way to track sync operations
  that can work with any Ash-based application. It's designed to be extracted
  as part of the `airtable_sync_phoenix` package with minimal coupling to
  the host application.
  
  ## Features
  
  - Generic sync session tracking for any resource type
  - Configurable sync types and statuses
  - Progress tracking with statistics
  - Error information storage
  - Flexible metadata storage
  - Time-based queries and filtering
  - Audit trail capabilities
  
  ## Resource Configuration
  
  Host applications can customize this resource by:
  
  1. **Extending sync types**: Add application-specific sync types
  2. **Custom validations**: Add domain-specific validation rules
  3. **Additional fields**: Extend with application-specific metadata
  4. **Custom actions**: Add specialized actions for the domain
  5. **Policies**: Configure authorization policies
  
  ## Example Usage
  
      # Create a new sync session
      {:ok, session} = Ash.create(GenericSyncSession, %{
        session_id: "sync_abc123",
        sync_type: :import_users,
        target_resource: "MyApp.Accounts.User",
        source_adapter: "MyApp.Sync.Adapters.CsvAdapter",
        initiated_by: "admin@example.com",
        estimated_total: 1000,
        config: %{
          batch_size: 100,
          enable_error_recovery: true
        }
      })
      
      # Update session progress
      {:ok, updated_session} = Ash.update(session, %{
        status: :running,
        progress_stats: %{
          processed: 150,
          created: 120,
          updated: 25,
          errors: 5
        }
      })
      
      # Complete session
      {:ok, completed_session} = Ash.create(GenericSyncSession, %{
        status: :completed,
        completed_at: DateTime.utc_now(),
        final_stats: %{
          total_processed: 1000,
          total_created: 800,
          total_updated: 180,
          total_errors: 20,
          processing_time_ms: 45000
        }
      }, action: :complete_session)
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Sync.Generic,
    data_layer: AshPostgres.DataLayer

  require Logger

  postgres do
    table "generic_sync_sessions"
    repo EhsEnforcement.Repo
    
    # Indexes for performance
    custom_indexes do
      index [:session_id], unique: true
      index [:status]
      index [:sync_type]
      index [:target_resource]
      index [:initiated_by]
      index [:started_at]
      index [:completed_at]
      index [:status, :started_at]
      index [:sync_type, :status]
    end
  end

  attributes do
    uuid_primary_key :id
    
    # Session identification
    attribute :session_id, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 255
    end
    
    # Sync operation details
    attribute :sync_type, :atom do
      allow_nil? false
      constraints one_of: [
        # Generic sync types
        :import,
        :export,
        :sync,
        :migrate,
        :transform,
        :validate,
        :cleanup,
        
        # Import variants
        :import_users,
        :import_orders,
        :import_products,
        :import_cases,
        :import_notices,
        :import_all,
        
        # Enhanced variants (from Phase 2)
        :import_enhanced,
        :import_users_enhanced,
        :import_orders_enhanced,
        :import_cases_enhanced,
        :import_notices_enhanced,
        :import_all_enhanced,
        
        # Export variants
        :export_users,
        :export_orders,
        :export_reports,
        
        # Custom sync types (extensible)
        :custom_sync,
        :batch_process,
        :data_migration,
        :integrity_check
      ]
    end
    
    attribute :target_resource, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 500
      description "The target Ash resource module name (e.g., 'MyApp.Accounts.User')"
    end
    
    attribute :source_adapter, :string do
      allow_nil? true
      constraints max_length: 500
      description "The source adapter module name (e.g., 'MyApp.Adapters.CsvAdapter')"
    end
    
    # Session status tracking
    attribute :status, :atom do
      allow_nil? false
      default :pending
      constraints one_of: [:pending, :running, :completed, :failed, :cancelled, :paused]
    end
    
    # User and context information
    attribute :initiated_by, :string do
      allow_nil? true
      constraints max_length: 255
      description "User identifier who initiated the sync (email, username, or user ID)"
    end
    
    attribute :correlation_id, :string do
      allow_nil? true
      constraints max_length: 255
      description "Correlation ID for tracking related operations"
    end
    
    # Progress and statistics
    attribute :estimated_total, :integer do
      allow_nil? true
      constraints min: 0
      description "Estimated total number of records to process"
    end
    
    attribute :progress_stats, :map do
      allow_nil? true
      default %{}
      description "Current progress statistics (processed, created, updated, errors, etc.)"
    end
    
    attribute :final_stats, :map do
      allow_nil? true
      description "Final statistics after session completion"
    end
    
    # Configuration and metadata
    attribute :config, :map do
      allow_nil? true
      default %{}
      description "Sync configuration parameters (batch_size, limits, options, etc.)"
    end
    
    attribute :metadata, :map do
      allow_nil? true
      default %{}
      description "Additional metadata and context information"
    end
    
    # Error information
    attribute :error_info, :map do
      allow_nil? true
      description "Error details if the session failed"
    end
    
    attribute :error_count, :integer do
      allow_nil? false
      default 0
      constraints min: 0
      description "Total number of errors encountered during the session"
    end
    
    # Timing information
    attribute :started_at, :utc_datetime_usec do
      allow_nil? true
      description "When the sync session started processing"
    end
    
    attribute :completed_at, :utc_datetime_usec do
      allow_nil? true
      description "When the sync session completed (successfully or with failure)"
    end
    
    attribute :processing_time_ms, :integer do
      allow_nil? true
      constraints min: 0
      description "Total processing time in milliseconds"
    end
    
    # Audit fields
    timestamps()
  end

  actions do
    defaults [:read, :update, :destroy]
    
    create :create do
      accept [
        :session_id, :sync_type, :target_resource, :source_adapter,
        :initiated_by, :correlation_id, :estimated_total, :config, :metadata
      ]
      
      validate attribute_equals(:status, :pending)
    end
    
    create :start_session do
      accept [
        :session_id, :sync_type, :target_resource, :source_adapter,
        :initiated_by, :correlation_id, :estimated_total, :config, :metadata
      ]
      
      change set_attribute(:status, :pending)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end
    
    update :mark_running do
      accept []
      
      validate attribute_equals(:status, :pending)
      change set_attribute(:status, :running)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end
    
    update :update_progress do
      accept [:progress_stats, :error_count]
      
      validate attribute_in(:status, [:running, :paused])
    end
    
    update :complete_session do
      accept [:final_stats, :processing_time_ms, :metadata]
      
      validate attribute_equals(:status, :running)
      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
    
    update :fail_session do
      accept [:error_info, :error_count, :final_stats, :processing_time_ms]
      
      validate attribute_in(:status, [:pending, :running, :paused])
      change set_attribute(:status, :failed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
    
    update :cancel_session do
      accept [:metadata]
      
      validate attribute_in(:status, [:pending, :running, :paused])
      change set_attribute(:status, :cancelled)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
    
    update :pause_session do
      accept [:metadata]
      
      validate attribute_equals(:status, :running)
      change set_attribute(:status, :paused)
    end
    
    update :resume_session do
      accept [:metadata]
      
      validate attribute_equals(:status, :paused)
      change set_attribute(:status, :running)
    end
  end

  relationships do
    has_many :batch_progress_records, EhsEnforcement.Sync.Generic.Resources.GenericSyncBatch do
      source_attribute :session_id
      destination_attribute :session_id
    end
    
    has_many :sync_logs, EhsEnforcement.Sync.Generic.Resources.GenericSyncLog do
      source_attribute :session_id
      destination_attribute :session_id
    end
  end

  validations do
    validate present([:session_id, :sync_type, :target_resource])
  end

  preparations do
    prepare build(load: [:batch_progress_records, :sync_logs])
  end

  calculations do
    calculate :completion_percentage, :float, expr(
      cond do
        is_nil(estimated_total) or estimated_total == 0 -> 0.0
        true -> 
          processed = get_path(progress_stats, [:processed]) || 0
          processed / estimated_total * 100.0
      end
    )
    
    calculate :processing_speed_records_per_minute, :float, expr(
      cond do
        is_nil(processing_time_ms) or processing_time_ms == 0 -> 0.0
        true ->
          processed = get_path(progress_stats, [:processed]) || 0
          minutes = processing_time_ms / 60000.0
          processed / minutes
      end
    )
    
    calculate :error_rate_percentage, :float, expr(
      cond do
        is_nil(estimated_total) or estimated_total == 0 -> 0.0
        true -> error_count / estimated_total * 100.0
      end
    )
    
    calculate :is_active, :boolean, expr(status in [:pending, :running, :paused])
    
    calculate :duration_seconds, :integer, expr(
      cond do
        is_nil(started_at) -> 0
        is_nil(completed_at) -> datetime_diff(now(), started_at, :second)
        true -> datetime_diff(completed_at, started_at, :second)
      end
    )
  end

  code_interface do
    define :create_session, action: :create
    define :start_session, action: :start_session
    define :mark_running, action: :mark_running
    define :update_progress, action: :update_progress
    define :complete_session, action: :complete_session
    define :fail_session, action: :fail_session
    define :cancel_session, action: :cancel_session
    define :pause_session, action: :pause_session
    define :resume_session, action: :resume_session
    
    define :get_session, action: :read, get_by: [:session_id]
    define :list_sessions, action: :read
  end

  # Custom helper functions that can be used by host applications

  def get_session_summary(session) do
    %{
      session_id: session.session_id,
      sync_type: session.sync_type,
      status: session.status,
      progress: Map.get(session.progress_stats, :processed, 0),
      total: session.estimated_total,
      errors: session.error_count,
      started_at: session.started_at,
      completed_at: session.completed_at,
      duration_seconds: calculate_duration_seconds(session)
    }
  end

  def calculate_completion_percentage(session) do
    case {Map.get(session.progress_stats, :processed, 0), session.estimated_total} do
      {_, nil} -> 0.0
      {_, 0} -> 0.0
      {processed, total} -> Float.round(processed / total * 100.0, 2)
    end
  end

  def is_session_active?(session) do
    session.status in [:pending, :running, :paused]
  end

  def get_processing_speed(session) do
    case {Map.get(session.progress_stats, :processed, 0), session.processing_time_ms} do
      {_, nil} -> 0.0
      {_, 0} -> 0.0
      {processed, time_ms} ->
        minutes = time_ms / 60_000.0
        Float.round(processed / minutes, 2)
    end
  end

  defp calculate_duration_seconds(session) do
    case {session.started_at, session.completed_at} do
      {nil, _} -> 0
      {started, nil} -> DateTime.diff(DateTime.utc_now(), started)
      {started, completed} -> DateTime.diff(completed, started)
    end
  end
end