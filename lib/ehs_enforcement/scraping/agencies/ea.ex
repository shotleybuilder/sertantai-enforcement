defmodule EhsEnforcement.Scraping.Agencies.Ea do
  @moduledoc """
  EA-specific scraping implementation following the AgencyBehavior pattern.
  
  This module implements the AgencyBehavior callbacks for Environment Agency (EA)
  scraping operations, including date-range based scraping with action type filtering.
  
  ## EA-Specific Characteristics
  
  - **Date-range scraping**: Uses date_from/date_to parameters for temporal filtering
  - **Action type filtering**: Supports :court_case, :caution, :enforcement_notice types
  - **Single request**: All results fetched in a single API call (no pagination)
  - **Batch processing**: Results processed as a single batch rather than page-by-page
  
  ## Implementation Notes
  
  This module extracts the EA-specific logic from ScrapeCoordinator.start_ea_scraping_session/1
  while maintaining all existing functionality and behavior.
  """
  
  @behaviour EhsEnforcement.Scraping.AgencyBehavior
  
  require Logger
  alias EhsEnforcement.Configuration.ScrapingConfig
  alias EhsEnforcement.Scraping.ScrapeSession
  alias EhsEnforcement.Scraping.Ea.CaseScraper
  alias EhsEnforcement.Agencies.Ea.CaseProcessor
  alias EhsEnforcement.Agencies.Ea.DataTransformer
  alias EhsEnforcement.Scraping.ProcessingLog
  
  @impl true
  def validate_params(opts) do
    Logger.debug("EA: Validating parameters: #{inspect(opts)}")
    
    # Extract and validate EA-specific parameters
    date_from = Keyword.get(opts, :date_from)
    date_to = Keyword.get(opts, :date_to)
    action_types = Keyword.get(opts, :action_types, [:court_case])
    actor = Keyword.get(opts, :actor)
    
    # Load configuration for technical settings
    config = load_scraping_config(opts)
    
    # Build validated parameters
    validated_params = %{
      date_from: date_from,
      date_to: date_to,
      action_types: ensure_action_types_list(action_types),
      actor: actor,
      scrape_type: Keyword.get(opts, :scrape_type, :manual),
      
      # EA-specific defaults
      start_page: 1,  # EA only has "1 page" since it's all results
      max_pages: 1,   # EA processes everything in one batch
      
      # Technical configuration
      network_timeout: config.network_timeout_ms,
      max_consecutive_errors: config.max_consecutive_errors,
      pause_between_pages_ms: config.pause_between_pages_ms,
      batch_size: config.batch_size
    }
    
    # Validate required parameters
    with :ok <- validate_required_fields(validated_params),
         :ok <- validate_date_range(validated_params),
         :ok <- validate_action_types(validated_params.action_types),
         :ok <- validate_scraping_enabled(validated_params) do
      
      Logger.debug("EA: Parameters validated successfully")
      {:ok, validated_params}
    else
      {:error, reason} ->
        Logger.warning("EA: Parameter validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @impl true
  def start_scraping(validated_params, _config) do
    Logger.info("EA: Starting scraping session", 
                date_from: validated_params.date_from,
                date_to: validated_params.date_to,
                action_types: validated_params.action_types)
    
    # Create Ash ScrapeSession record for EA scraping
    session_id = EhsEnforcement.Scraping.AgencyBehavior.generate_session_id()
    
    ash_session_params = %{
      session_id: session_id,
      start_page: validated_params.start_page,
      max_pages: validated_params.max_pages,
      database: "ea_enforcement",  # EA-specific database identifier
      status: :running,
      current_page: validated_params.start_page,
      pages_processed: 0,
      cases_found: 0,
      cases_processed: 0,
      cases_created: 0,
      cases_exist_total: 0,
      errors_count: 0
    }
    
    case Ash.create(ScrapeSession, ash_session_params) do
      {:ok, session} ->
        Logger.info("EA: Created scraping session #{session.session_id}")
        
        # Store validated_params and EA-specific parameters in session
        session_with_params = Map.merge(session, %{
          validated_params: validated_params,
          date_from: validated_params.date_from,
          date_to: validated_params.date_to,
          action_types: validated_params.action_types
        })
        
        # Execute the EA scraping workflow
        execute_ea_scraping_session(session_with_params)
        
      {:error, reason} ->
        Logger.error("EA: Failed to create ScrapeSession record: #{inspect(reason)}")
        {:error, "Failed to create EA scraping session: #{inspect(reason)}"}
    end
  end
  
  @impl true
  def process_results(session_results) do
    Logger.info("EA: Processing scraping results", 
                session_id: session_results.session_id,
                status: session_results.status,
                pages_processed: session_results.pages_processed,
                cases_created: session_results.cases_created)
    
    # For EA, we can pass through the results as-is since the session
    # structure already contains all the necessary information
    session_results
  end
  
  # Private functions for EA-specific implementation
  
  defp load_scraping_config(opts) do
    # Use the same config loading logic as ScrapeCoordinator
    fallback_config = %{
      consecutive_existing_threshold: 10,
      max_pages_per_session: 20,  # Conservative default for EA
      network_timeout_ms: 30_000,
      max_consecutive_errors: 3,
      hse_database: "convictions",
      pause_between_pages_ms: 3_000,
      batch_size: 50
    }
    
    case ScrapingConfig.get_active_config(opts) do
      {:ok, config} -> 
        Logger.debug("EA: Loaded active scraping configuration: #{config.name}")
        config
        
      {:error, :no_active_config} ->
        Logger.warning("EA: No active scraping configuration found, using fallback values")
        struct(ScrapingConfig, fallback_config)
        
      {:error, reason} ->
        Logger.error("EA: Failed to load scraping configuration: #{inspect(reason)}, using fallback values")
        struct(ScrapingConfig, fallback_config)
    end
  end
  
  defp ensure_action_types_list(action_types) when is_list(action_types), do: action_types
  defp ensure_action_types_list(action_type) when is_atom(action_type), do: [action_type]
  defp ensure_action_types_list(_), do: [:court_case]
  
  defp validate_required_fields(params) do
    required = [:date_from, :date_to, :action_types, :scrape_type]
    missing = Enum.filter(required, fn field -> Map.get(params, field) == nil end)
    
    if missing == [] do
      :ok
    else
      {:error, "Missing required EA parameters: #{inspect(missing)}"}
    end
  end
  
  defp validate_date_range(params) do
    with %Date{} <- params.date_from,
         %Date{} <- params.date_to do
      if Date.compare(params.date_from, params.date_to) in [:lt, :eq] do
        :ok
      else
        {:error, "Invalid date range: date_from must be before or equal to date_to"}
      end
    else
      _ -> {:error, "Invalid date format: date_from and date_to must be Date structs"}
    end
  end
  
  defp validate_action_types(action_types) do
    valid_types = [:court_case, :caution, :enforcement_notice]
    invalid_types = Enum.reject(action_types, &(&1 in valid_types))
    
    if invalid_types == [] do
      :ok
    else
      {:error, "Invalid action types: #{inspect(invalid_types)}. Valid types: #{inspect(valid_types)}"}
    end
  end
  
  defp validate_scraping_enabled(params) do
    # Load the actual scraping configuration for checking enabled flags
    config = load_scraping_config([])
    
    if EhsEnforcement.Scraping.AgencyBehavior.scraping_enabled?(:ea, params.scrape_type, config) do
      :ok
    else
      {:error, "#{params.scrape_type} EA scraping is disabled in configuration"}
    end
  end
  
  # EA scraping execution logic (extracted from ScrapeCoordinator)
  
  defp execute_ea_scraping_session(session) do
    Logger.debug("EA: Starting scraping session execution: #{session.session_id}")
    Logger.info("EA: Scraping date range: #{session.date_from} to #{session.date_to}")
    
    session
    |> process_ea_single_request()
    |> finalize_session()
  end
  
  defp process_ea_single_request(session) do
    Logger.debug("EA: Processing single request for session #{session.session_id}")
    
    validated_params = Map.get(session, :validated_params, %{})
    
    # Process each action type individually for real-time feedback
    process_ea_action_types_individually(session, session.action_types, validated_params)
  end
  
  defp process_ea_action_types_individually(session, action_types, validated_params) do
    Logger.debug("EA: Processing #{length(action_types)} action types individually")
    
    # Process each action type one by one
    final_session = Enum.reduce(action_types, session, fn action_type, current_session ->
      Logger.info("EA: Processing action type: #{action_type}")
      
      case process_single_action_type_individually(current_session, action_type, validated_params) do
        {:ok, updated_session} -> updated_session
        {:error, reason} ->
          Logger.error("EA: Failed to process action type #{action_type}: #{inspect(reason)}")
          # Continue with other action types even if one fails
          current_session
      end
    end)
    
    # Update final session status
    update_session_final_processing(final_session)
  end
  
  defp process_single_action_type_individually(session, action_type, validated_params) do
    Logger.debug("EA: Getting summary records for action type #{action_type}")
    
    # Get summary records for this action type (Stage 1)
    case CaseScraper.collect_summary_records_for_action_type(
           session.date_from, 
           session.date_to, 
           action_type,
           [timeout_ms: validated_params.network_timeout]
         ) do
      {:ok, summary_records} ->
        total_cases_for_action = length(summary_records)
        Logger.info("EA: Found #{total_cases_for_action} summary records for #{action_type}")
        
        # Update session with total expected cases for this action type
        updated_session = case Ash.update(session, %{cases_found: session.cases_found + total_cases_for_action}) do
          {:ok, updated} -> updated
          {:error, reason} ->
            Logger.warning("EA: Failed to update cases_found total: #{inspect(reason)}")
            session
        end
        
        # Process each summary record individually with real-time feedback
        process_summary_records_individually(updated_session, summary_records, action_type, validated_params)
        
      {:error, reason} ->
        Logger.error("EA: Failed to get summary records for #{action_type}: #{inspect(reason)}")
        {:error, {:summary_failed, action_type, reason}}
    end
  end
  
  defp process_summary_records_individually(session, summary_records, action_type, validated_params) do
    Logger.debug("EA: Processing #{length(summary_records)} summary records individually")
    
    actor = Map.get(validated_params, :actor)
    
    # Track cumulative results and current session state
    initial_state = %{
      cases_created: 0,
      cases_existing: 0,
      cases_errors: 0,
      processed_cases: [],
      current_session: session  # Track the current session state
    }
    
    # Process each summary record individually and save immediately
    final_state = Enum.reduce(summary_records, initial_state, fn summary_record, acc ->
      Logger.debug("EA: Processing case #{summary_record.ea_record_id} individually")
      
      # Fetch detail record (Stage 2)
      case CaseScraper.fetch_detail_record_individual(summary_record, [
        detail_delay_ms: validated_params.pause_between_pages_ms,
        timeout_ms: validated_params.network_timeout
      ]) do
        {:ok, detail_record} ->
          # Process and save this case immediately
          case_result = process_and_save_single_ea_case(acc.current_session, detail_record, actor)
          
          # Update accumulated results
          updated_acc = merge_case_result(acc, case_result)
          
          # Update session with this single case progress for real-time UI feedback
          # IMPORTANT: Capture the updated session for next iteration
          updated_session = update_session_with_single_case_progress(acc.current_session, case_result)
          
          # Return updated accumulator with new session state
          Map.put(updated_acc, :current_session, updated_session)
          
        {:error, reason} ->
          Logger.warning("EA: Failed to fetch detail for #{summary_record.ea_record_id}: #{inspect(reason)}")
          # Continue processing other cases
          acc
      end
    end)
    
    # Extract the final results (excluding current_session)
    final_results = Map.drop(final_state, [:current_session])
    
    # Create processing log for this action type batch using the original session for logging context
    create_ea_action_type_processing_log(session, action_type, final_results.processed_cases, final_results)
    
    # Return the final session with accumulated progress, not the original session
    {:ok, final_state.current_session}
  end
  
  defp process_and_save_single_ea_case(_session, detail_record, actor) do
    Logger.debug("EA: Processing and saving case: #{detail_record.ea_record_id}")
    
    # Transform EA case to Case resource format using EA DataTransformer
    transformed_case = DataTransformer.transform_ea_record(detail_record)
    
    # Create Case resource using unified processor for consistent UI status
    case CaseProcessor.process_and_create_case_with_status(transformed_case, actor) do
      {:ok, case_record, status} ->
        case status do
          :created ->
            Logger.info("EA: Created case: #{case_record.regulator_id}")
          :updated ->
            Logger.info("EA: Updated case: #{case_record.regulator_id}")
          :existing ->
            Logger.info("EA: Case already exists: #{case_record.regulator_id}")
        end
        
        %{
          status: status,
          case_record: case_record,
          transformed_case: transformed_case
        }
        
      {:error, reason} ->
        Logger.warning("EA: Error creating case: #{inspect(reason)}")
        %{
          status: :error,
          error: reason,
          regulator_id: transformed_case[:regulator_id],
          transformed_case: transformed_case
        }
    end
  end
  
  defp merge_case_result(acc, case_result) do
    case case_result.status do
      :created ->
        %{acc | 
          cases_created: acc.cases_created + 1,
          processed_cases: [case_result.transformed_case | acc.processed_cases]
        }
      :updated ->
        %{acc | 
          cases_created: acc.cases_created + 1,  # Count updates as "created" for UI purposes
          processed_cases: [case_result.transformed_case | acc.processed_cases]
        }
      :existing ->
        %{acc | 
          cases_existing: acc.cases_existing + 1,
          processed_cases: [case_result.transformed_case | acc.processed_cases]
        }
      :error ->
        %{acc | 
          cases_errors: acc.cases_errors + 1,
          processed_cases: [case_result.transformed_case | acc.processed_cases]
        }
    end
  end
  
  defp update_session_with_single_case_progress(session, case_result) do
    # Update session counters for real-time UI feedback
    # cases_processed tracks running count, cases_found holds the total expected
    update_params = case case_result.status do
      :created ->
        %{
          cases_processed: session.cases_processed + 1,
          cases_created: session.cases_created + 1
        }
      :updated ->
        %{
          cases_processed: session.cases_processed + 1,
          cases_created: session.cases_created + 1  # Count updates as "created" for UI purposes
        }
      :existing ->
        %{
          cases_processed: session.cases_processed + 1,
          cases_exist_total: session.cases_exist_total + 1
        }
      :error ->
        %{
          cases_processed: session.cases_processed + 1,
          errors_count: session.errors_count + 1
        }
    end
    
    case Ash.update(session, update_params) do
      {:ok, updated_session} ->
        Logger.debug("EA: Updated session progress for real-time feedback")
        updated_session
      {:error, reason} ->
        Logger.error("EA: Failed to update session progress: #{inspect(reason)}")
        session
    end
  end
  
  defp update_session_final_processing(session) do
    # Mark processing as complete
    update_params = %{
      current_page: 1,
      pages_processed: 1
    }
    
    case Ash.update(session, update_params) do
      {:ok, updated_session} -> updated_session
      {:error, reason} ->
        Logger.error("EA: Failed to update final session processing: #{inspect(reason)}")
        session
    end
  end
  
  
  defp finalize_session(session) do
    # Update session to completed status using Ash.update
    final_status = if session.status == :running, do: :completed, else: session.status
    
    case Ash.update(session, %{status: final_status}) do
      {:ok, final_session} ->
        Logger.info("EA: Scraping session finalized", 
                    session_id: final_session.session_id,
                    status: final_session.status,
                    pages_processed: final_session.pages_processed,
                    cases_created: final_session.cases_created)
        {:ok, final_session}
        
      {:error, reason} ->
        Logger.error("EA: Failed to finalize session: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Helper functions
  
  # Duplicate error handling now handled by UnifiedCaseProcessor
  
  defp create_ea_action_type_processing_log(session, action_type, processed_cases, results) do
    # Create summary of processed EA cases for UI display
    case_summary = Enum.map(processed_cases, fn case_data ->
      %{
        regulator_id: case_data[:regulator_id],
        offender_name: case_data[:offender_name], 
        case_date: case_data[:offence_action_date],
        fine_amount: case_data[:offence_fine]
      }
    end)
    
    # EA-specific processing log with unified field names for each action type
    log_params = %{
      session_id: session.session_id,
      agency: :ea,
      batch_or_page: 1,  # EA batch number (integer, not string)
      items_found: length(processed_cases),
      items_created: results.cases_created,
      items_existing: results.cases_existing,
      items_failed: results.cases_errors,
      creation_errors: [],
      scraped_items: case_summary
    }
    
    case Ash.create(ProcessingLog, log_params) do
      {:ok, _log} ->
        Logger.debug("EA: Created unified processing log for #{action_type} in session #{session.session_id}")
      {:error, reason} ->
        Logger.warning("EA: Failed to create unified processing log for #{action_type}: #{inspect(reason)}")
    end
  end
end