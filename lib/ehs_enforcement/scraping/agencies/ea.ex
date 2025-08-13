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
  def start_scraping(validated_params, config) do
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
    if EhsEnforcement.Scraping.AgencyBehavior.scraping_enabled?(:ea, params.scrape_type, params) do
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
    
    # Use EA CaseScraper to get ALL cases for the date range in a single request
    case CaseScraper.scrape_enforcement_actions(
           session.date_from, 
           session.date_to, 
           session.action_types,
           timeout_ms: validated_params.network_timeout,
           detail_delay_ms: validated_params.pause_between_pages_ms
         ) do
      {:ok, ea_cases} ->
        Logger.info("EA: Found #{length(ea_cases)} enforcement actions for date range")
        
        # Update session with cases found
        cases_found_params = %{
          cases_found: length(ea_cases),
          current_page: 1,  # EA only has "1 page" since it's all results
          pages_processed: 1
        }
        
        updated_session = case Ash.update(session, cases_found_params) do
          {:ok, updated} -> updated
          {:error, reason} ->
            Logger.error("EA: Failed to update session with cases found: #{inspect(reason)}")
            session
        end
        
        # Process EA cases and convert to Case resource format
        process_ea_cases_serially(updated_session, ea_cases)
        
      {:error, reason} ->
        Logger.error("EA: Failed to scrape enforcement actions: #{inspect(reason)}")
        
        # Update session with error
        error_params = %{
          errors_count: session.errors_count + 1,
          current_page: 1,
          pages_processed: 1
        }
        
        case Ash.update(session, error_params) do
          {:ok, updated_session} -> updated_session
          {:error, update_reason} ->
            Logger.error("EA: Failed to update ScrapeSession with error: #{inspect(update_reason)}")
            session
        end
    end
  end
  
  defp process_ea_cases_serially(session, ea_cases) do
    Logger.debug("EA: Processing #{length(ea_cases)} cases serially for session #{session.session_id}")
    
    validated_params = Map.get(session, :validated_params, %{})
    actor = Map.get(validated_params, :actor)
    
    # Track results for session updates
    results = %{
      cases_created: 0,
      cases_existing: 0,
      cases_errors: 0,
      processed_cases: []
    }
    
    # Process each EA case and transform to Case/Violation resources
    final_results = Enum.reduce(ea_cases, results, fn ea_case, acc ->
      process_single_ea_case(session, ea_case, actor, acc)
    end)
    
    # Create processing log for the completed EA batch
    create_ea_processing_log(session, final_results.processed_cases, final_results)
    
    # Update session with final batch results
    update_session_with_batch_results(session, final_results)
  end
  
  defp process_single_ea_case(_session, ea_case, actor, acc) do
    Logger.debug("EA: Processing case: #{inspect(ea_case)}")
    
    # Transform EA case to Case resource format using EA DataTransformer
    transformed_case = DataTransformer.transform_ea_record(ea_case)
    
    # Create Case resource using EA CaseProcessor pattern
    case CaseProcessor.process_and_create_case(transformed_case, actor) do
      {:ok, case_record} ->
        Logger.info("EA: Created case: #{case_record.regulator_id}")
        %{acc | 
          cases_created: acc.cases_created + 1,
          processed_cases: [transformed_case | acc.processed_cases]
        }
        
      {:error, reason} ->
        # Check if error indicates case already exists
        if duplicate_error?(reason) do
          Logger.info("EA: Case already exists: #{transformed_case[:regulator_id]}")
          %{acc | 
            cases_existing: acc.cases_existing + 1,
            processed_cases: [transformed_case | acc.processed_cases]
          }
        else
          Logger.warning("EA: Error creating case: #{inspect(reason)}")
          %{acc | 
            cases_errors: acc.cases_errors + 1,
            processed_cases: [transformed_case | acc.processed_cases]
          }
        end
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
  
  defp duplicate_error?(reason) do
    case reason do
      %Ash.Error.Invalid{errors: errors} -> duplicate_error_list?(errors)
      %{message: message} -> String.contains?(message, "already exists") or String.contains?(message, "duplicate")
      _ -> false
    end
  end
  
  defp duplicate_error_list?(errors) when is_list(errors) do
    Enum.any?(errors, fn error ->
      case error do
        %{message: message} -> String.contains?(message, "already exists") or String.contains?(message, "duplicate")
        _ -> false
      end
    end)
  end
  
  defp duplicate_error_list?(_), do: false
  
  defp create_ea_processing_log(session, processed_cases, results) do
    # Create summary of processed EA cases for UI display
    case_summary = Enum.map(processed_cases, fn case_data ->
      %{
        regulator_id: case_data[:regulator_id],
        offender_name: case_data[:offender_name], 
        case_date: case_data[:offence_action_date],
        fine_amount: case_data[:offence_fine]
      }
    end)
    
    # EA-specific processing log with unified field names
    log_params = %{
      session_id: session.session_id,
      agency: :ea,
      batch_or_page: 1,  # EA batch number (single batch)
      items_found: length(processed_cases),
      items_created: results.cases_created,
      items_existing: results.cases_existing,
      items_failed: results.cases_errors,
      creation_errors: [],
      scraped_items: case_summary
    }
    
    case Ash.create(ProcessingLog, log_params) do
      {:ok, _log} ->
        Logger.debug("EA: Created unified processing log for session #{session.session_id}")
      {:error, reason} ->
        Logger.warning("EA: Failed to create unified processing log: #{inspect(reason)}")
    end
  end
  
  defp update_session_with_batch_results(session, results) do
    total_cases = results.cases_created + results.cases_existing + results.cases_errors
    
    update_params = %{
      cases_found: session.cases_found + total_cases,
      cases_created: session.cases_created + results.cases_created,
      cases_exist_total: session.cases_exist_total + results.cases_existing,
      errors_count: session.errors_count + results.cases_errors
    }
    
    case Ash.update(session, update_params) do
      {:ok, updated_session} ->
        Logger.info("EA: Updated session with batch results: #{total_cases} total cases processed")
        updated_session
        
      {:error, reason} ->
        Logger.error("EA: Failed to update ScrapeSession: #{inspect(reason)}")
        session
    end
  end
end