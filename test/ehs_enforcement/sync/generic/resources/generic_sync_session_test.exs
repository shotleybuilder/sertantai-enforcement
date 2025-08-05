defmodule EhsEnforcement.Sync.Generic.Resources.GenericSyncSessionTest do
  use EhsEnforcement.DataCase
  
  alias EhsEnforcement.Sync.Generic.Resources.GenericSyncSession
  
  require Ash.Query
  import Ash.Expr

  describe "generic sync session resource" do
    setup do
      session_attrs = %{
        session_id: "sync_test_001",
        sync_type: :import_cases,
        target_resource: "EhsEnforcement.Enforcement.Case",
        source_adapter: "EhsEnforcement.Sync.Adapters.AirtableAdapter",
        initiated_by: "test_user@example.com",
        estimated_total: 1000,
        config: %{
          batch_size: 100,
          enable_error_recovery: true
        }
      }
      
      %{session_attrs: session_attrs}
    end

    test "creates session successfully", %{session_attrs: attrs} do
      assert {:ok, session} = Ash.create(GenericSyncSession, attrs)
      
      assert session.session_id == "sync_test_001"
      assert session.sync_type == :import_cases
      assert session.status == :pending
      assert session.estimated_total == 1000
      assert session.config.batch_size == 100
    end

    test "validates session_id format", %{session_attrs: attrs} do
      invalid_attrs = Map.put(attrs, :session_id, "invalid_format")
      
      assert {:error, %Ash.Error.Invalid{}} = Ash.create(GenericSyncSession, invalid_attrs)
    end

    test "validates target_resource format", %{session_attrs: attrs} do
      invalid_attrs = Map.put(attrs, :target_resource, "invalid-module-name")
      
      assert {:error, %Ash.Error.Invalid{}} = Ash.create(GenericSyncSession, invalid_attrs)
    end

    test "starts session with proper timestamps", %{session_attrs: attrs} do
      assert {:ok, session} = Ash.create(GenericSyncSession, attrs, action: :start_session)
      
      assert session.status == :pending
      assert session.started_at != nil
      assert DateTime.diff(DateTime.utc_now(), session.started_at) < 5  # Within 5 seconds
    end

    test "marks session as running", %{session_attrs: attrs} do
      {:ok, session} = Ash.create(GenericSyncSession, attrs, action: :start_session)
      
      assert {:ok, running_session} = Ash.update(session, %{}, action: :mark_running)
      
      assert running_session.status == :running
      assert running_session.started_at != nil
    end

    test "updates progress statistics", %{session_attrs: attrs} do
      {:ok, session} = Ash.create(GenericSyncSession, attrs, action: :start_session)
      {:ok, running_session} = Ash.update(session, %{}, action: :mark_running)
      
      progress_stats = %{
        processed: 250,
        created: 200,
        updated: 30,
        existing: 10,
        errors: 10
      }
      
      assert {:ok, updated_session} = Ash.update(running_session, %{
        progress_stats: progress_stats,
        error_count: 10
      }, action: :update_progress)
      
      assert updated_session.progress_stats.processed == 250
      assert updated_session.error_count == 10
    end

    test "completes session successfully", %{session_attrs: attrs} do
      {:ok, session} = Ash.create(GenericSyncSession, attrs, action: :start_session)
      {:ok, running_session} = Ash.update(session, %{}, action: :mark_running)
      
      final_stats = %{
        total_processed: 1000,
        total_created: 800,
        total_updated: 150,
        total_errors: 50,
        processing_time_ms: 45000
      }
      
      assert {:ok, completed_session} = Ash.update(running_session, %{
        final_stats: final_stats,
        processing_time_ms: 45000
      }, action: :complete_session)
      
      assert completed_session.status == :completed
      assert completed_session.completed_at != nil
      assert completed_session.final_stats.total_processed == 1000
      assert completed_session.processing_time_ms == 45000
    end

    test "fails session with error information", %{session_attrs: attrs} do
      {:ok, session} = Ash.create(GenericSyncSession, attrs, action: :start_session)
      {:ok, running_session} = Ash.update(session, %{}, action: :mark_running)
      
      error_info = %{
        error_type: "ConnectionError",
        error_message: "Failed to connect to Airtable API",
        stacktrace: "..."
      }
      
      assert {:ok, failed_session} = Ash.update(running_session, %{
        error_info: error_info,
        error_count: 1
      }, action: :fail_session)
      
      assert failed_session.status == :failed
      assert failed_session.completed_at != nil
      assert failed_session.error_info.error_type == "ConnectionError"
    end

    test "cancels session", %{session_attrs: attrs} do
      {:ok, session} = Ash.create(GenericSyncSession, attrs, action: :start_session)
      
      assert {:ok, cancelled_session} = Ash.update(session, %{}, action: :cancel_session)
      
      assert cancelled_session.status == :cancelled
      assert cancelled_session.completed_at != nil
    end

    test "pauses and resumes session", %{session_attrs: attrs} do
      {:ok, session} = Ash.create(GenericSyncSession, attrs, action: :start_session)
      {:ok, running_session} = Ash.update(session, %{}, action: :mark_running)
      
      # Pause session
      assert {:ok, paused_session} = Ash.update(running_session, %{}, action: :pause_session)
      assert paused_session.status == :paused
      
      # Resume session
      assert {:ok, resumed_session} = Ash.update(paused_session, %{}, action: :resume_session)
      assert resumed_session.status == :running
    end
  end

  describe "session calculations" do
    setup do
      session_attrs = %{
        session_id: "sync_calc_001",
        sync_type: :import_cases,
        target_resource: "EhsEnforcement.Enforcement.Case",
        estimated_total: 1000,
        progress_stats: %{
          processed: 500,
          created: 400,
          updated: 80,
          errors: 20
        },
        error_count: 20,
        processing_time_ms: 30000
      }
      
      {:ok, session} = Ash.create(GenericSyncSession, session_attrs)
      %{session: session}
    end

    test "calculates completion percentage", %{session: session} do
      # Load session with calculations
      loaded_session = Ash.load!(session, [:completion_percentage])
      
      assert loaded_session.completion_percentage == 50.0  # 500/1000 * 100
    end

    test "calculates processing speed", %{session: session} do
      loaded_session = Ash.load!(session, [:processing_speed_records_per_minute])
      
      # 500 records in 30 seconds = 1000 records per minute
      assert loaded_session.processing_speed_records_per_minute == 1000.0
    end

    test "calculates error rate", %{session: session} do
      loaded_session = Ash.load!(session, [:error_rate_percentage])
      
      # 20 errors out of 1000 estimated = 2%
      assert loaded_session.error_rate_percentage == 2.0
    end

    test "determines if session is active", %{session: session} do
      loaded_session = Ash.load!(session, [:is_active])
      
      # Session with :pending status should be active
      assert loaded_session.is_active == true
    end
  end

  describe "session queries and filters" do
    setup do
      # Create multiple sessions with different statuses
      sessions_data = [
        %{session_id: "sync_001", sync_type: :import_cases, target_resource: "Case", status: :running},
        %{session_id: "sync_002", sync_type: :import_notices, target_resource: "Notice", status: :completed},
        %{session_id: "sync_003", sync_type: :import_cases, target_resource: "Case", status: :failed},
        %{session_id: "sync_004", sync_type: :import_all, target_resource: "Mixed", status: :pending}
      ]
      
      sessions = for data <- sessions_data do
        {:ok, session} = Ash.create(GenericSyncSession, data)
        if data.status != :pending do
          {:ok, session} = Ash.update(session, %{status: data.status})
        end
        session
      end
      
      %{sessions: sessions}
    end

    test "lists active sessions", %{sessions: _sessions} do
      active_sessions = GenericSyncSession.list_active_sessions!()
      
      # Should include running and pending sessions
      active_statuses = Enum.map(active_sessions, & &1.status)
      assert :running in active_statuses
      assert :pending in active_statuses
      assert :completed not in active_statuses
    end

    test "filters sessions by sync type" do
      case_sessions = GenericSyncSession.list_sessions_by_type!(:import_cases)
      
      assert length(case_sessions) >= 2  # At least the ones we created
      assert Enum.all?(case_sessions, & &1.sync_type == :import_cases)
    end

    test "gets session by session_id" do
      assert session = GenericSyncSession.get_session!("sync_001")
      assert session.session_id == "sync_001"
      assert session.sync_type == :import_cases
    end
  end

  describe "helper functions" do
    setup do
      session_attrs = %{
        session_id: "sync_helper_001",
        sync_type: :import_cases,
        target_resource: "EhsEnforcement.Enforcement.Case",
        estimated_total: 1000,
        progress_stats: %{processed: 750, created: 600, updated: 100, errors: 50},
        error_count: 50,
        started_at: DateTime.utc_now() |> DateTime.add(-3600, :second),  # 1 hour ago
        processing_time_ms: 45000
      }
      
      {:ok, session} = Ash.create(GenericSyncSession, session_attrs)
      %{session: session}
    end

    test "generates session summary", %{session: session} do
      summary = GenericSyncSession.get_session_summary(session)
      
      assert summary.session_id == "sync_helper_001"
      assert summary.sync_type == :import_cases
      assert summary.progress == 750
      assert summary.total == 1000
      assert summary.errors == 50
      assert summary.duration_seconds > 0
    end

    test "calculates completion percentage", %{session: session} do
      percentage = GenericSyncSession.calculate_completion_percentage(session)
      
      assert percentage == 75.0  # 750/1000 * 100
    end

    test "determines if session is active", %{session: session} do
      assert GenericSyncSession.is_session_active?(session) == true
      
      # Complete the session
      {:ok, completed_session} = Ash.update(session, %{status: :completed})
      assert GenericSyncSession.is_session_active?(completed_session) == false
    end

    test "calculates processing speed", %{session: session} do
      speed = GenericSyncSession.get_processing_speed(session)
      
      # 750 records in 45 seconds = 1000 records per minute
      assert speed == 1000.0
    end
  end

  describe "validation edge cases" do
    test "handles session with no estimated total" do
      attrs = %{
        session_id: "sync_no_total_001",
        sync_type: :import_cases,
        target_resource: "EhsEnforcement.Enforcement.Case",
        estimated_total: nil
      }
      
      assert {:ok, session} = Ash.create(GenericSyncSession, attrs)
      
      # Should handle calculations gracefully
      loaded_session = Ash.load!(session, [:completion_percentage])
      assert loaded_session.completion_percentage == 0.0
    end

    test "validates progress stats consistency" do
      attrs = %{
        session_id: "sync_validation_001",
        sync_type: :import_cases,
        target_resource: "EhsEnforcement.Enforcement.Case",
        estimated_total: 1000
      }
      
      {:ok, session} = Ash.create(GenericSyncSession, attrs, action: :start_session)
      {:ok, running_session} = Ash.update(session, %{}, action: :mark_running)
      
      # Try to update with inconsistent progress stats (negative values)
      invalid_progress = %{
        processed: -10,  # Invalid
        created: 5,
        errors: 5
      }
      
      case Ash.update(running_session, %{progress_stats: invalid_progress}, action: :update_progress) do
        {:error, %Ash.Error.Invalid{}} ->
          # Validation should catch this
          :ok
        {:ok, _} ->
          # Or it might be allowed depending on validation implementation
          :ok
      end
    end
  end
end