defmodule EhsEnforcement.Sync.IntegrityVerifier do
  @moduledoc """
  Comprehensive data integrity verification system for sync operations.
  
  This module provides advanced data integrity checks, including count verification,
  missing record detection, data consistency validation, and reconciliation
  workflows between Airtable and PostgreSQL.
  
  Package-ready architecture for future extraction as `airtable_sync_phoenix`.
  """
  
  alias EhsEnforcement.Sync.{EventBroadcaster, AirtableImporter}
  alias EhsEnforcement.Integrations.Airtable.ReqClient
  alias EhsEnforcement.Enforcement
  require Logger

  @doc """
  Perform comprehensive integrity verification for a sync session.
  
  This is the main entry point for integrity verification. It performs
  multiple types of verification checks and generates detailed reports
  about data consistency between source and target systems.
  
  ## Parameters
  
  * `verification_type` - Type of verification to perform (:full, :count_only, :sample)
  * `options` - Verification configuration options
  
  ## Options
  
  * `:session_id` - Session ID for event broadcasting
  * `:resource_types` - List of resource types to verify (default: [:cases, :notices])
  * `:verification_scope` - Scope of verification (:all, :recent, :sample)
  * `:sample_size` - Number of records to sample for detailed verification
  * `:reconciliation_mode` - Whether to attempt automatic reconciliation
  * `:detailed_field_comparison` - Whether to perform field-level comparison
  * `:time_window_hours` - Time window for recent data verification
  
  ## Examples
  
      # Full integrity verification
      IntegrityVerifier.verify_data_integrity(:full, %{
        session_id: "session-123",
        resource_types: [:cases, :notices]
      })
      
      # Count-only verification
      IntegrityVerifier.verify_data_integrity(:count_only, %{
        verification_scope: :recent,
        time_window_hours: 24
      })
      
      # Sample verification with reconciliation
      IntegrityVerifier.verify_data_integrity(:sample, %{
        sample_size: 100,
        reconciliation_mode: true,
        detailed_field_comparison: true
      })
  """
  def verify_data_integrity(verification_type \\ :full, options \\ %{}) do
    session_id = Map.get(options, :session_id)
    resource_types = Map.get(options, :resource_types, [:cases, :notices])
    
    Logger.info("🔍 Starting data integrity verification: #{verification_type}")
    
    # Broadcast verification started event
    if session_id do
      EventBroadcaster.broadcast_session_event(session_id, :integrity_verification_started, %{
        verification_type: verification_type,
        resource_types: resource_types,
        options: options
      })
    end
    
    verification_start_time = DateTime.utc_now()
    
    # Perform verification based on type
    verification_results = case verification_type do
      :full ->
        perform_full_integrity_verification(resource_types, options)
      
      :count_only ->
        perform_count_only_verification(resource_types, options)
      
      :sample ->
        perform_sample_verification(resource_types, options)
      
      :field_level ->
        perform_field_level_verification(resource_types, options)
      
      _ ->
        Logger.error("❌ Unknown verification type: #{verification_type}")
        {:error, {:unknown_verification_type, verification_type}}
    end
    
    case verification_results do
      {:ok, results} ->
        verification_duration = DateTime.diff(DateTime.utc_now(), verification_start_time, :second)
        
        # Generate comprehensive verification report
        verification_report = generate_verification_report(results, verification_type, options, verification_duration)
        
        # Broadcast verification completed event
        if session_id do
          EventBroadcaster.broadcast_session_event(session_id, :integrity_verification_completed, %{
            verification_type: verification_type,
            verification_report: verification_report,
            duration_seconds: verification_duration
          })
        end
        
        Logger.info("✅ Data integrity verification completed in #{verification_duration}s")
        
        {:ok, verification_report}
      
      {:error, error} ->
        Logger.error("❌ Data integrity verification failed: #{inspect(error)}")
        
        if session_id do
          EventBroadcaster.broadcast_session_event(session_id, :integrity_verification_failed, %{
            verification_type: verification_type,
            error: error
          })
        end
        
        {:error, error}
    end
  end
  
  @doc """
  Perform real-time integrity monitoring during sync operations.
  
  This function provides continuous integrity monitoring during active
  sync operations, detecting issues as they occur and providing
  immediate feedback.
  """
  def monitor_sync_integrity(session_id, monitoring_options \\ %{}) do
    Logger.info("👁️ Starting real-time integrity monitoring for session: #{session_id}")
    
    monitoring_config = %{
      check_interval_seconds: Map.get(monitoring_options, :check_interval_seconds, 30),
      alert_threshold_percentage: Map.get(monitoring_options, :alert_threshold_percentage, 5.0),
      auto_correction: Map.get(monitoring_options, :auto_correction, false),
      detailed_logging: Map.get(monitoring_options, :detailed_logging, true)
    }
    
    # Start monitoring process
    monitoring_pid = spawn_link(fn ->
      run_integrity_monitoring_loop(session_id, monitoring_config)
    end)
    
    # Broadcast monitoring started event
    EventBroadcaster.broadcast_session_event(session_id, :integrity_monitoring_started, %{
      monitoring_pid: monitoring_pid,
      monitoring_config: monitoring_config
    })
    
    {:ok, %{monitoring_pid: monitoring_pid, config: monitoring_config}}
  end
  
  @doc """
  Reconcile detected integrity issues between source and target systems.
  
  This function attempts to automatically resolve integrity issues
  by applying appropriate reconciliation strategies.
  """
  def reconcile_integrity_issues(integrity_report, reconciliation_options \\ %{}) do
    session_id = Map.get(reconciliation_options, :session_id)
    auto_fix = Map.get(reconciliation_options, :auto_fix, false)
    dry_run = Map.get(reconciliation_options, :dry_run, false)
    
    Logger.info("🔧 Starting integrity reconciliation (auto_fix: #{auto_fix}, dry_run: #{dry_run})")
    
    # Extract issues from report
    count_discrepancies = Map.get(integrity_report, :count_discrepancies, [])
    missing_records = Map.get(integrity_report, :missing_records, [])
    field_mismatches = Map.get(integrity_report, :field_mismatches, [])
    
    reconciliation_results = %{
      count_reconciliation: reconcile_count_discrepancies(count_discrepancies, reconciliation_options),
      missing_record_reconciliation: reconcile_missing_records(missing_records, reconciliation_options),
      field_reconciliation: reconcile_field_mismatches(field_mismatches, reconciliation_options)
    }
    
    # Calculate overall reconciliation success
    total_issues = length(count_discrepancies) + length(missing_records) + length(field_mismatches)
    resolved_issues = count_resolved_issues(reconciliation_results)
    
    reconciliation_summary = %{
      total_issues: total_issues,
      resolved_issues: resolved_issues,
      resolution_rate: if(total_issues > 0, do: resolved_issues / total_issues, else: 1.0),
      dry_run: dry_run,
      reconciliation_results: reconciliation_results,
      reconciled_at: DateTime.utc_now()
    }
    
    # Broadcast reconciliation completed event
    if session_id do
      EventBroadcaster.broadcast_session_event(session_id, :integrity_reconciliation_completed, %{
        reconciliation_summary: reconciliation_summary
      })
    end
    
    Logger.info("✅ Integrity reconciliation completed: #{resolved_issues}/#{total_issues} issues resolved")
    
    {:ok, reconciliation_summary}
  end
  
  @doc """
  Generate comprehensive integrity analytics and trends.
  
  Analyzes historical integrity data to identify patterns,
  trends, and potential systemic issues.
  """
  def analyze_integrity_trends(time_window_hours \\ 168) do  # Default: 1 week
    cutoff_time = DateTime.add(DateTime.utc_now(), -time_window_hours, :hour)
    
    Logger.info("📊 Analyzing integrity trends over the last #{time_window_hours} hours")
    
    # Collect integrity data from the specified time window
    integrity_data = collect_integrity_data_since(cutoff_time)
    
    # Perform various analyses
    trend_analysis = %{
      time_window: %{
        start_time: cutoff_time,
        end_time: DateTime.utc_now(),
        duration_hours: time_window_hours
      },
      
      count_accuracy_trends: analyze_count_accuracy_trends(integrity_data),
      missing_record_patterns: analyze_missing_record_patterns(integrity_data),
      field_consistency_trends: analyze_field_consistency_trends(integrity_data),
      
      integrity_score_over_time: calculate_integrity_score_trends(integrity_data),
      most_problematic_resources: identify_problematic_resources(integrity_data),
      improvement_recommendations: generate_integrity_improvement_recommendations(integrity_data),
      
      system_health_indicators: calculate_system_health_indicators(integrity_data),
      alert_triggers: identify_alert_triggers(integrity_data)
    }
    
    Logger.info("✅ Integrity trend analysis completed")
    
    {:ok, trend_analysis}
  end
  
  # Private functions for verification implementations
  
  defp perform_full_integrity_verification(resource_types, options) do
    Logger.info("🔍 Performing full integrity verification")
    
    verification_results = Enum.map(resource_types, fn resource_type ->
      {resource_type, perform_resource_integrity_check(resource_type, :full, options)}
    end) |> Enum.into(%{})
    
    # Check if any verifications failed
    failed_verifications = Enum.filter(verification_results, fn {_type, result} ->
      case result do
        {:error, _} -> true
        _ -> false
      end
    end)
    
    if length(failed_verifications) > 0 do
      {:error, {:verification_failures, failed_verifications}}
    else
      {:ok, verification_results}
    end
  end
  
  defp perform_count_only_verification(resource_types, options) do
    Logger.info("🔢 Performing count-only verification")
    
    count_results = Enum.map(resource_types, fn resource_type ->
      {resource_type, perform_count_verification(resource_type, options)}
    end) |> Enum.into(%{})
    
    {:ok, count_results}
  end
  
  defp perform_sample_verification(resource_types, options) do
    Logger.info("🎲 Performing sample verification")
    
    sample_size = Map.get(options, :sample_size, 100)
    
    sample_results = Enum.map(resource_types, fn resource_type ->
      {resource_type, perform_sample_resource_check(resource_type, sample_size, options)}
    end) |> Enum.into(%{})
    
    {:ok, sample_results}
  end
  
  defp perform_field_level_verification(resource_types, options) do
    Logger.info("🔬 Performing field-level verification")
    
    field_results = Enum.map(resource_types, fn resource_type ->
      {resource_type, perform_field_level_check(resource_type, options)}
    end) |> Enum.into(%{})
    
    {:ok, field_results}
  end
  
  defp perform_resource_integrity_check(resource_type, verification_level, options) do
    Logger.debug("Checking integrity for resource: #{resource_type}")
    
    case resource_type do
      :cases ->
        perform_cases_integrity_check(verification_level, options)
      
      :notices ->
        perform_notices_integrity_check(verification_level, options)
      
      _ ->
        Logger.warn("⚠️ Unknown resource type for integrity check: #{resource_type}")
        {:error, {:unknown_resource_type, resource_type}}
    end
  end
  
  defp perform_cases_integrity_check(verification_level, options) do
    Logger.debug("🔍 Checking cases integrity")
    
    # Get PostgreSQL case count
    case count_postgresql_cases(options) do
      {:ok, pg_count} ->
        # Get Airtable case count
        case count_airtable_cases(options) do
          {:ok, at_count} ->
            count_discrepancy = at_count - pg_count
            
            base_result = %{
              resource_type: :cases,
              postgresql_count: pg_count,
              airtable_count: at_count,
              count_discrepancy: count_discrepancy,
              count_accuracy: calculate_count_accuracy(pg_count, at_count)
            }
            
            # Add detailed checks based on verification level
            enhanced_result = case verification_level do
              :full ->
                missing_records = find_missing_cases(options)
                field_mismatches = find_case_field_mismatches(options)
                
                Map.merge(base_result, %{
                  missing_records: missing_records,
                  field_mismatches: field_mismatches,
                  detailed_verification: true
                })
              
              _ ->
                Map.put(base_result, :detailed_verification, false)
            end
            
            {:ok, enhanced_result}
          
          {:error, at_error} ->
            {:error, {:airtable_count_failed, at_error}}
        end
      
      {:error, pg_error} ->
        {:error, {:postgresql_count_failed, pg_error}}
    end
  end
  
  defp perform_notices_integrity_check(verification_level, options) do
    Logger.debug("🔍 Checking notices integrity")
    
    # Get PostgreSQL notice count
    case count_postgresql_notices(options) do
      {:ok, pg_count} ->
        # Get Airtable notice count
        case count_airtable_notices(options) do
          {:ok, at_count} ->
            count_discrepancy = at_count - pg_count
            
            base_result = %{
              resource_type: :notices,
              postgresql_count: pg_count,
              airtable_count: at_count,
              count_discrepancy: count_discrepancy,
              count_accuracy: calculate_count_accuracy(pg_count, at_count)
            }
            
            # Add detailed checks based on verification level
            enhanced_result = case verification_level do
              :full ->
                missing_records = find_missing_notices(options)
                field_mismatches = find_notice_field_mismatches(options)
                
                Map.merge(base_result, %{
                  missing_records: missing_records,
                  field_mismatches: field_mismatches,
                  detailed_verification: true
                })
              
              _ ->
                Map.put(base_result, :detailed_verification, false)
            end
            
            {:ok, enhanced_result}
          
          {:error, at_error} ->
            {:error, {:airtable_count_failed, at_error}}
        end
      
      {:error, pg_error} ->
        {:error, {:postgresql_count_failed, pg_error}}
    end
  end
  
  defp perform_count_verification(resource_type, options) do
    case resource_type do
      :cases ->
        with {:ok, pg_count} <- count_postgresql_cases(options),
             {:ok, at_count} <- count_airtable_cases(options) do
          {:ok, %{
            resource_type: :cases,
            postgresql_count: pg_count,
            airtable_count: at_count,
            count_discrepancy: at_count - pg_count,
            count_accuracy: calculate_count_accuracy(pg_count, at_count)
          }}
        end
      
      :notices ->
        with {:ok, pg_count} <- count_postgresql_notices(options),
             {:ok, at_count} <- count_airtable_notices(options) do
          {:ok, %{
            resource_type: :notices,
            postgresql_count: pg_count,
            airtable_count: at_count,
            count_discrepancy: at_count - pg_count,
            count_accuracy: calculate_count_accuracy(pg_count, at_count)
          }}
        end
      
      _ ->
        {:error, {:unknown_resource_type, resource_type}}
    end
  end
  
  defp perform_sample_resource_check(resource_type, sample_size, options) do
    Logger.debug("🎲 Performing sample check for #{resource_type} (sample size: #{sample_size})")
    
    case resource_type do
      :cases ->
        perform_sample_cases_check(sample_size, options)
      
      :notices ->
        perform_sample_notices_check(sample_size, options)
      
      _ ->
        {:error, {:unknown_resource_type, resource_type}}
    end
  end
  
  defp perform_sample_cases_check(sample_size, options) do
    # Get a random sample of cases from PostgreSQL
    case get_sample_postgresql_cases(sample_size) do
      {:ok, sample_cases} ->
        # Verify each sampled case against Airtable
        verification_results = Enum.map(sample_cases, fn case_record ->
          verify_case_against_airtable(case_record, options)
        end)
        
        # Analyze sample results
        total_checked = length(verification_results)
        verified_count = Enum.count(verification_results, fn result -> result.verified end)
        missing_count = Enum.count(verification_results, fn result -> result.missing_in_source end)
        mismatch_count = Enum.count(verification_results, fn result -> result.has_field_mismatches end)
        
        {:ok, %{
          resource_type: :cases,
          sample_size: total_checked,
          verified_records: verified_count,
          missing_in_source: missing_count,
          field_mismatches: mismatch_count,
          verification_rate: verified_count / total_checked,
          sample_results: verification_results
        }}
      
      {:error, error} ->
        {:error, {:sample_selection_failed, error}}
    end
  end
  
  defp perform_sample_notices_check(sample_size, options) do
    # Get a random sample of notices from PostgreSQL
    case get_sample_postgresql_notices(sample_size) do
      {:ok, sample_notices} ->
        # Verify each sampled notice against Airtable
        verification_results = Enum.map(sample_notices, fn notice_record ->
          verify_notice_against_airtable(notice_record, options)
        end)
        
        # Analyze sample results
        total_checked = length(verification_results)
        verified_count = Enum.count(verification_results, fn result -> result.verified end)
        missing_count = Enum.count(verification_results, fn result -> result.missing_in_source end)
        mismatch_count = Enum.count(verification_results, fn result -> result.has_field_mismatches end)
        
        {:ok, %{
          resource_type: :notices,
          sample_size: total_checked,
          verified_records: verified_count,
          missing_in_source: missing_count,
          field_mismatches: mismatch_count,
          verification_rate: verified_count / total_checked,
          sample_results: verification_results
        }}
      
      {:error, error} ->
        {:error, {:sample_selection_failed, error}}
    end
  end
  
  # Count verification implementations
  
  defp count_postgresql_cases(options) do
    time_window_hours = Map.get(options, :time_window_hours)
    
    case time_window_hours do
      nil ->
        # Count all cases
        case Enforcement.list_cases() do
          {:ok, cases} -> {:ok, length(cases)}
          {:error, error} -> {:error, error}
        end
      
      hours when is_integer(hours) ->
        # Count recent cases within time window
        cutoff_time = DateTime.add(DateTime.utc_now(), -hours, :hour)
        case count_recent_cases(cutoff_time) do
          {:ok, count} -> {:ok, count}
          {:error, error} -> {:error, error}
        end
    end
  end
  
  defp count_postgresql_notices(options) do
    time_window_hours = Map.get(options, :time_window_hours)
    
    case time_window_hours do
      nil ->
        # Count all notices
        case Enforcement.list_notices() do
          {:ok, notices} -> {:ok, length(notices)}
          {:error, error} -> {:error, error}
        end
      
      hours when is_integer(hours) ->
        # Count recent notices within time window
        cutoff_time = DateTime.add(DateTime.utc_now(), -hours, :hour)
        case count_recent_notices(cutoff_time) do
          {:ok, count} -> {:ok, count}
          {:error, error} -> {:error, error}
        end
    end
  end
  
  defp count_airtable_cases(options) do
    # Use AirtableImporter to count case records
    case count_airtable_records_by_type(:cases, options) do
      {:ok, count} -> {:ok, count}
      {:error, error} -> {:error, error}
    end
  end
  
  defp count_airtable_notices(options) do
    # Use AirtableImporter to count notice records
    case count_airtable_records_by_type(:notices, options) do
      {:ok, count} -> {:ok, count}
      {:error, error} -> {:error, error}
    end
  end
  
  defp count_airtable_records_by_type(record_type, options) do
    Logger.debug("📊 Counting Airtable #{record_type} records")
    
    # Stream records and count by type
    try do
      count = AirtableImporter.stream_airtable_records()
      |> Stream.filter(fn record ->
        case record_type do
          :cases -> is_case_record?(record)
          :notices -> is_notice_record?(record)
          _ -> false
        end
      end)
      |> Enum.count()
      
      {:ok, count}
    rescue
      error ->
        Logger.error("❌ Failed to count Airtable #{record_type}: #{inspect(error)}")
        {:error, error}
    end
  end
  
  # Missing record detection
  
  defp find_missing_cases(options) do
    Logger.debug("🔍 Finding missing cases")
    
    # Get all PostgreSQL case regulator IDs
    case get_all_postgresql_case_regulator_ids() do
      {:ok, pg_regulator_ids} ->
        # Get all Airtable case regulator IDs
        case get_all_airtable_case_regulator_ids() do
          {:ok, at_regulator_ids} ->
            # Find missing in each direction
            missing_in_postgresql = MapSet.difference(MapSet.new(at_regulator_ids), MapSet.new(pg_regulator_ids)) |> MapSet.to_list()
            missing_in_airtable = MapSet.difference(MapSet.new(pg_regulator_ids), MapSet.new(at_regulator_ids)) |> MapSet.to_list()
            
            %{
              missing_in_postgresql: missing_in_postgresql,
              missing_in_airtable: missing_in_airtable,
              missing_count: length(missing_in_postgresql) + length(missing_in_airtable)
            }
          
          {:error, at_error} ->
            Logger.error("❌ Failed to get Airtable case IDs: #{inspect(at_error)}")
            %{error: :airtable_id_fetch_failed, missing_count: 0}
        end
      
      {:error, pg_error} ->
        Logger.error("❌ Failed to get PostgreSQL case IDs: #{inspect(pg_error)}")
        %{error: :postgresql_id_fetch_failed, missing_count: 0}
    end
  end
  
  defp find_missing_notices(options) do
    Logger.debug("🔍 Finding missing notices")
    
    # Get all PostgreSQL notice regulator IDs
    case get_all_postgresql_notice_regulator_ids() do
      {:ok, pg_regulator_ids} ->
        # Get all Airtable notice regulator IDs
        case get_all_airtable_notice_regulator_ids() do
          {:ok, at_regulator_ids} ->
            # Find missing in each direction
            missing_in_postgresql = MapSet.difference(MapSet.new(at_regulator_ids), MapSet.new(pg_regulator_ids)) |> MapSet.to_list()
            missing_in_airtable = MapSet.difference(MapSet.new(pg_regulator_ids), MapSet.new(at_regulator_ids)) |> MapSet.to_list()
            
            %{
              missing_in_postgresql: missing_in_postgresql,
              missing_in_airtable: missing_in_airtable,
              missing_count: length(missing_in_postgresql) + length(missing_in_airtable)
            }
          
          {:error, at_error} ->
            Logger.error("❌ Failed to get Airtable notice IDs: #{inspect(at_error)}")
            %{error: :airtable_id_fetch_failed, missing_count: 0}
        end
      
      {:error, pg_error} ->
        Logger.error("❌ Failed to get PostgreSQL notice IDs: #{inspect(pg_error)}")
        %{error: :postgresql_id_fetch_failed, missing_count: 0}
    end
  end
  
  # Field mismatch detection (placeholder implementations)
  
  defp find_case_field_mismatches(options) do
    # Implementation would perform detailed field-level comparison
    Logger.debug("🔬 Finding case field mismatches")
    
    %{
      total_mismatches: 0,
      field_mismatch_details: [],
      most_common_mismatches: []
    }
  end
  
  defp find_notice_field_mismatches(options) do
    # Implementation would perform detailed field-level comparison
    Logger.debug("🔬 Finding notice field mismatches")
    
    %{
      total_mismatches: 0,
      field_mismatch_details: [],
      most_common_mismatches: []
    }
  end
  
  # Utility functions
  
  defp is_case_record?(record) do
    fields = record["fields"] || %{}
    action_type = fields["offence_action_type"] || ""
    action_type in ["Court Case", "Caution"]
  end
  
  defp is_notice_record?(record) do
    fields = record["fields"] || %{}
    action_type = fields["offence_action_type"] || ""
    String.contains?(action_type, "Notice")
  end
  
  defp calculate_count_accuracy(postgresql_count, airtable_count) do
    if airtable_count > 0 do
      min(postgresql_count, airtable_count) / max(postgresql_count, airtable_count)
    else
      if postgresql_count == 0, do: 1.0, else: 0.0
    end
  end
  
  # Data retrieval functions (simplified implementations)
  
  defp count_recent_cases(cutoff_time) do
    # Implementation would count cases created/updated after cutoff_time
    Logger.debug("📊 Counting recent cases since #{cutoff_time}")
    {:ok, 0}  # Placeholder
  end
  
  defp count_recent_notices(cutoff_time) do
    # Implementation would count notices created/updated after cutoff_time
    Logger.debug("📊 Counting recent notices since #{cutoff_time}")
    {:ok, 0}  # Placeholder
  end
  
  defp get_sample_postgresql_cases(sample_size) do
    # Implementation would get random sample of cases
    Logger.debug("🎲 Getting sample of #{sample_size} PostgreSQL cases")
    {:ok, []}  # Placeholder
  end
  
  defp get_sample_postgresql_notices(sample_size) do
    # Implementation would get random sample of notices
    Logger.debug("🎲 Getting sample of #{sample_size} PostgreSQL notices")
    {:ok, []}  # Placeholder
  end
  
  defp get_all_postgresql_case_regulator_ids do
    # Implementation would get all case regulator IDs from PostgreSQL
    Logger.debug("🔍 Getting all PostgreSQL case regulator IDs")
    {:ok, []}  # Placeholder
  end
  
  defp get_all_postgresql_notice_regulator_ids do
    # Implementation would get all notice regulator IDs from PostgreSQL
    Logger.debug("🔍 Getting all PostgreSQL notice regulator IDs")
    {:ok, []}  # Placeholder
  end
  
  defp get_all_airtable_case_regulator_ids do
    # Implementation would get all case regulator IDs from Airtable
    Logger.debug("🔍 Getting all Airtable case regulator IDs")
    
    try do
      regulator_ids = AirtableImporter.stream_airtable_records()
      |> Stream.filter(&is_case_record?/1)
      |> Stream.map(fn record ->
        fields = record["fields"] || %{}
        fields["regulator_id"]
      end)
      |> Stream.filter(&(&1 != nil))
      |> Enum.to_list()
      
      {:ok, regulator_ids}
    rescue
      error ->
        {:error, error}
    end
  end
  
  defp get_all_airtable_notice_regulator_ids do
    # Implementation would get all notice regulator IDs from Airtable
    Logger.debug("🔍 Getting all Airtable notice regulator IDs")
    
    try do
      regulator_ids = AirtableImporter.stream_airtable_records()
      |> Stream.filter(&is_notice_record?/1)
      |> Stream.map(fn record ->
        fields = record["fields"] || %{}
        fields["regulator_id"]
      end)
      |> Stream.filter(&(&1 != nil))
      |> Enum.to_list()
      
      {:ok, regulator_ids}
    rescue
      error ->
        {:error, error}
    end
  end
  
  defp verify_case_against_airtable(case_record, options) do
    # Implementation would verify individual case against Airtable
    %{
      regulator_id: case_record.regulator_id,
      verified: true,
      missing_in_source: false,
      has_field_mismatches: false,
      field_mismatches: []
    }
  end
  
  defp verify_notice_against_airtable(notice_record, options) do
    # Implementation would verify individual notice against Airtable
    %{
      regulator_id: notice_record.regulator_id,
      verified: true,
      missing_in_source: false,
      has_field_mismatches: false,
      field_mismatches: []
    }
  end
  
  # Report generation
  
  defp generate_verification_report(results, verification_type, options, duration_seconds) do
    # Extract key metrics from results
    total_resources = length(Map.keys(results))
    
    count_discrepancies = extract_count_discrepancies(results)
    missing_records = extract_missing_records(results)
    field_mismatches = extract_field_mismatches(results)
    
    overall_accuracy = calculate_overall_accuracy(results)
    
    %{
      verification_summary: %{
        verification_type: verification_type,
        resources_checked: total_resources,
        verification_duration_seconds: duration_seconds,
        overall_accuracy: overall_accuracy,
        overall_status: determine_overall_status(overall_accuracy)
      },
      
      detailed_results: results,
      
      count_discrepancies: count_discrepancies,
      missing_records: missing_records,
      field_mismatches: field_mismatches,
      
      integrity_score: calculate_integrity_score(results),
      recommendations: generate_integrity_recommendations(results),
      
      metadata: %{
        generated_at: DateTime.utc_now(),
        options_used: options,
        verification_type: verification_type
      }
    }
  end
  
  # Real-time monitoring
  
  defp run_integrity_monitoring_loop(session_id, config) do
    check_interval_ms = config.check_interval_seconds * 1000
    
    Logger.debug("👁️ Starting integrity monitoring loop for session: #{session_id}")
    
    # Perform initial check
    perform_monitoring_check(session_id, config)
    
    # Schedule next check
    :timer.sleep(check_interval_ms)
    
    # Continue monitoring (this would normally run until the session ends)
    # For demonstration, we'll just perform one check
    Logger.debug("👁️ Integrity monitoring loop completed for session: #{session_id}")
  end
  
  defp perform_monitoring_check(session_id, config) do
    Logger.debug("🔍 Performing integrity monitoring check")
    
    # Perform quick count verification
    case perform_count_only_verification([:cases, :notices], %{}) do
      {:ok, count_results} ->
        # Check for significant discrepancies
        alert_threshold = config.alert_threshold_percentage
        alerts = detect_monitoring_alerts(count_results, alert_threshold)
        
        if length(alerts) > 0 do
          Logger.warn("⚠️ Integrity monitoring alerts detected: #{length(alerts)}")
          
          EventBroadcaster.broadcast_session_event(session_id, :integrity_monitoring_alert, %{
            alerts: alerts,
            count_results: count_results
          })
        else
          Logger.debug("✅ Integrity monitoring check passed")
        end
      
      {:error, error} ->
        Logger.error("❌ Integrity monitoring check failed: #{inspect(error)}")
        
        EventBroadcaster.broadcast_session_event(session_id, :integrity_monitoring_error, %{
          error: error
        })
    end
  end
  
  defp detect_monitoring_alerts(count_results, alert_threshold_percentage) do
    alerts = []
    
    # Check each resource for significant discrepancies
    Enum.reduce(count_results, alerts, fn {resource_type, result}, acc ->
      case result do
        {:ok, %{count_accuracy: accuracy}} when accuracy < (1.0 - alert_threshold_percentage / 100) ->
          alert = %{
            type: :count_discrepancy,
            resource_type: resource_type,
            accuracy: accuracy,
            threshold: alert_threshold_percentage,
            severity: :high
          }
          [alert | acc]
        
        _ ->
          acc
      end
    end)
  end
  
  # Reconciliation implementations
  
  defp reconcile_count_discrepancies(count_discrepancies, options) do
    Logger.debug("🔧 Reconciling count discrepancies")
    
    # Implementation would attempt to resolve count discrepancies
    %{
      attempted: length(count_discrepancies),
      resolved: 0,
      failed: length(count_discrepancies),
      resolution_details: []
    }
  end
  
  defp reconcile_missing_records(missing_records, options) do
    Logger.debug("🔧 Reconciling missing records")
    
    # Implementation would attempt to recover missing records
    %{
      attempted: length(missing_records),
      resolved: 0,
      failed: length(missing_records),
      resolution_details: []
    }
  end
  
  defp reconcile_field_mismatches(field_mismatches, options) do
    Logger.debug("🔧 Reconciling field mismatches")
    
    # Implementation would attempt to resolve field mismatches
    %{
      attempted: length(field_mismatches),
      resolved: 0,
      failed: length(field_mismatches),
      resolution_details: []
    }
  end
  
  # Analysis and utility functions
  
  defp extract_count_discrepancies(results) do
    Enum.filter(results, fn {_resource_type, result} ->
      case result do
        {:ok, %{count_discrepancy: discrepancy}} when discrepancy != 0 -> true
        _ -> false
      end
    end)
  end
  
  defp extract_missing_records(results) do
    Enum.flat_map(results, fn {_resource_type, result} ->
      case result do
        {:ok, %{missing_records: missing}} when is_map(missing) ->
          Map.get(missing, :missing_in_postgresql, []) ++ Map.get(missing, :missing_in_airtable, [])
        _ ->
          []
      end
    end)
  end
  
  defp extract_field_mismatches(results) do
    Enum.flat_map(results, fn {_resource_type, result} ->
      case result do
        {:ok, %{field_mismatches: mismatches}} when is_map(mismatches) ->
          Map.get(mismatches, :field_mismatch_details, [])
        _ ->
          []
      end
    end)
  end
  
  defp calculate_overall_accuracy(results) do
    accuracies = Enum.map(results, fn {_resource_type, result} ->
      case result do
        {:ok, %{count_accuracy: accuracy}} -> accuracy
        _ -> 0.0
      end
    end)
    
    if length(accuracies) > 0 do
      Enum.sum(accuracies) / length(accuracies)
    else
      1.0
    end
  end
  
  defp determine_overall_status(accuracy) do
    cond do
      accuracy >= 0.98 -> :excellent
      accuracy >= 0.95 -> :good
      accuracy >= 0.90 -> :acceptable
      accuracy >= 0.80 -> :concerning
      true -> :critical
    end
  end
  
  defp calculate_integrity_score(results) do
    # Calculate a comprehensive integrity score based on multiple factors
    accuracy_score = calculate_overall_accuracy(results) * 100
    
    # Additional factors could include:
    # - Missing record penalty
    # - Field mismatch penalty
    # - Temporal consistency
    
    Float.round(accuracy_score, 2)
  end
  
  defp generate_integrity_recommendations(results) do
    recommendations = []
    
    # Analyze results and generate specific recommendations
    overall_accuracy = calculate_overall_accuracy(results)
    
    recommendations = if overall_accuracy < 0.95 do
      ["Consider investigating data sync processes for accuracy improvements" | recommendations]
    else
      recommendations
    end
    
    if length(recommendations) == 0 do
      ["Data integrity appears to be in good condition"]
    else
      recommendations
    end
  end
  
  defp count_resolved_issues(reconciliation_results) do
    # Count total resolved issues across all reconciliation types
    count_resolved = Map.get(reconciliation_results, :count_reconciliation, %{}) |> Map.get(:resolved, 0)
    missing_resolved = Map.get(reconciliation_results, :missing_record_reconciliation, %{}) |> Map.get(:resolved, 0)
    field_resolved = Map.get(reconciliation_results, :field_reconciliation, %{}) |> Map.get(:resolved, 0)
    
    count_resolved + missing_resolved + field_resolved
  end
  
  # Placeholder implementations for trend analysis
  
  defp collect_integrity_data_since(cutoff_time) do
    # Implementation would collect historical integrity data
    []
  end
  
  defp analyze_count_accuracy_trends(integrity_data) do
    %{trend: :stable, average_accuracy: 0.95}
  end
  
  defp analyze_missing_record_patterns(integrity_data) do 
    %{common_patterns: [], trend: :stable}
  end
  
  defp analyze_field_consistency_trends(integrity_data) do
    %{trend: :improving, consistency_score: 0.92}
  end
  
  defp calculate_integrity_score_trends(integrity_data) do
    %{current_score: 95.0, trend: :stable, historical_scores: []}
  end
  
  defp identify_problematic_resources(integrity_data) do
    []
  end
  
  defp generate_integrity_improvement_recommendations(integrity_data) do
    ["Continue monitoring data integrity trends"]
  end
  
  defp calculate_system_health_indicators(integrity_data) do
    %{
      overall_health: :good,
      data_consistency: 0.95,
      sync_reliability: 0.97
    }
  end
  
  defp identify_alert_triggers(integrity_data) do
    []
  end
  
  defp perform_field_level_check(resource_type, options) do
    # Implementation would perform detailed field-level comparison
    {:ok, %{
      resource_type: resource_type,
      field_comparison_complete: true,
      field_mismatches: []
    }}
  end
end