defmodule EhsEnforcement.Scraping.Agencies.Hse do
  @moduledoc """
  HSE-specific scraping implementation following the AgencyBehavior pattern.
  
  This module implements the AgencyBehavior callbacks for Health and Safety Executive (HSE)
  scraping operations, including page-based scraping with automatic stopping logic.
  
  ## HSE-Specific Characteristics
  
  - **Page-based scraping**: Uses start_page/end_page parameters for pagination
  - **Database selection**: Supports "convictions", "notices", etc.
  - **Stopping logic**: Stops when consecutive existing threshold reached
  - **Rate limiting**: Built-in pause between pages for respectful scraping
  
  ## Implementation Notes
  
  This module extracts the HSE-specific logic from ScrapeCoordinator.start_hse_scraping_session/1
  while maintaining all existing functionality and behavior.
  """
  
  @behaviour EhsEnforcement.Scraping.AgencyBehavior
  
  require Logger
  alias EhsEnforcement.Configuration.ScrapingConfig
  alias EhsEnforcement.Scraping.ScrapeSession
  alias EhsEnforcement.Scraping.Hse.CaseScraper
  alias EhsEnforcement.Scraping.Hse.CaseProcessor
  alias EhsEnforcement.Scraping.ProcessingLog
  
  @impl true
  def validate_params(opts) do
    Logger.debug("HSE: Validating parameters: #{inspect(opts)}")
    
    # Extract and validate HSE-specific parameters
    start_page = Keyword.get(opts, :start_page, 1)
    max_pages = Keyword.get(opts, :max_pages)
    database = Keyword.get(opts, :database)
    actor = Keyword.get(opts, :actor)
    
    # Load configuration for defaults if max_pages or database not provided
    config = load_scraping_config(opts)
    
    # Build validated parameters with defaults from config
    validated_params = %{
      start_page: validate_page_number(start_page),
      max_pages: max_pages || config.max_pages_per_session,
      database: database || config.hse_database,
      stop_on_existing: Keyword.get(opts, :stop_on_existing, true),
      actor: actor,
      scrape_type: Keyword.get(opts, :scrape_type, :manual),
      
      # Technical configuration
      network_timeout: config.network_timeout_ms,
      max_consecutive_errors: config.max_consecutive_errors,
      consecutive_existing_threshold: config.consecutive_existing_threshold,
      pause_between_pages_ms: config.pause_between_pages_ms,
      batch_size: config.batch_size
    }
    
    # Validate required parameters
    with :ok <- validate_required_fields(validated_params),
         :ok <- validate_page_range(validated_params),
         :ok <- validate_database(validated_params.database),
         :ok <- validate_scraping_enabled(validated_params) do
      
      Logger.debug("HSE: Parameters validated successfully")
      {:ok, validated_params}
    else
      {:error, reason} ->
        Logger.warning("HSE: Parameter validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @impl true
  def start_scraping(validated_params, _config) do
    Logger.info("HSE: Starting scraping session", 
                start_page: validated_params.start_page,
                max_pages: validated_params.max_pages,
                database: validated_params.database)
    
    # Create Ash ScrapeSession record with proper parameters
    session_id = EhsEnforcement.Scraping.AgencyBehavior.generate_session_id()
    
    ash_session_params = %{
      session_id: session_id,
      start_page: validated_params.start_page,
      max_pages: validated_params.max_pages,
      database: validated_params.database,
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
        Logger.info("HSE: Created scraping session #{session.session_id}")
        
        # Store validated_params in session for execution
        session_with_params = Map.put(session, :validated_params, validated_params)
        
        # Execute the HSE scraping workflow
        execute_hse_scraping_session(session_with_params)
        
      {:error, reason} ->
        Logger.error("HSE: Failed to create ScrapeSession record: #{inspect(reason)}")
        {:error, "Failed to create HSE scraping session: #{inspect(reason)}"}
    end
  end
  
  @impl true
  def process_results(session_results) do
    Logger.info("HSE: Processing scraping results", 
                session_id: session_results.session_id,
                status: session_results.status,
                pages_processed: session_results.pages_processed,
                cases_created: session_results.cases_created)
    
    # For HSE, we can pass through the results as-is since the session
    # structure already contains all the necessary information
    session_results
  end
  
  # Private functions for HSE-specific implementation
  
  defp load_scraping_config(opts) do
    # Use the same config loading logic as ScrapeCoordinator
    fallback_config = %{
      consecutive_existing_threshold: 10,
      max_pages_per_session: 100,
      network_timeout_ms: 30_000,
      max_consecutive_errors: 3,
      hse_database: "convictions",
      pause_between_pages_ms: 3_000,
      batch_size: 50
    }
    
    case ScrapingConfig.get_active_config(opts) do
      {:ok, config} -> 
        Logger.debug("HSE: Loaded active scraping configuration: #{config.name}")
        config
        
      {:error, :no_active_config} ->
        Logger.warning("HSE: No active scraping configuration found, using fallback values")
        struct(ScrapingConfig, fallback_config)
        
      {:error, reason} ->
        Logger.error("HSE: Failed to load scraping configuration: #{inspect(reason)}, using fallback values")
        struct(ScrapingConfig, fallback_config)
    end
  end
  
  defp validate_page_number(page) when is_integer(page) and page > 0, do: page
  defp validate_page_number(_), do: 1
  
  defp validate_required_fields(params) do
    required = [:start_page, :max_pages, :database, :scrape_type]
    missing = Enum.filter(required, fn field -> Map.get(params, field) == nil end)
    
    if missing == [] do
      :ok
    else
      {:error, "Missing required HSE parameters: #{inspect(missing)}"}
    end
  end
  
  defp validate_page_range(params) do
    if params.start_page > 0 and params.max_pages > 0 do
      :ok
    else
      {:error, "Invalid page range: start_page and max_pages must be positive integers"}
    end
  end
  
  defp validate_database(database) when database in ["convictions", "notices", "appeals"], do: :ok
  defp validate_database(database), do: {:error, "Invalid HSE database: #{database}. Supported: convictions, notices, appeals"}
  
  defp validate_scraping_enabled(params) do
    # Load the actual scraping configuration for checking enabled flags
    config = load_scraping_config([])
    
    if EhsEnforcement.Scraping.AgencyBehavior.scraping_enabled?(:hse, params.scrape_type, config) do
      :ok
    else
      {:error, "#{params.scrape_type} HSE scraping is disabled in configuration"}
    end
  end
  
  # HSE scraping execution logic (extracted from ScrapeCoordinator)
  
  defp execute_hse_scraping_session(session) do
    Logger.debug("HSE: Starting execution of scraping session: #{session.session_id}")
    
    session
    |> process_pages_until_complete()
    |> finalize_session()
  end
  
  defp process_pages_until_complete(session) do
    if should_continue_scraping?(session) do
      session
      |> process_current_page()
      |> advance_to_next_page()
      |> process_pages_until_complete()
    else
      session
    end
  end
  
  defp process_current_page(session) do
    Logger.debug("HSE: Processing page #{session.current_page} for session #{session.session_id}")
    
    # Get basic cases from the page
    case CaseScraper.scrape_page_basic(session.current_page, database: session.database) do
      {:ok, basic_cases} ->
        Logger.info("HSE: Found #{length(basic_cases)} case references on page #{session.current_page}")
        
        # Process cases serially with additional URI requests
        process_cases_serially(session, basic_cases)
        
      {:error, reason} ->
        Logger.error("HSE: Failed to scrape page #{session.current_page}: #{inspect(reason)}")
        
        # Update session with error using Ash.update
        error_params = %{errors_count: session.errors_count + 1}
        
        case Ash.update(session, error_params) do
          {:ok, updated_session} -> updated_session
          {:error, update_reason} ->
            Logger.error("HSE: Failed to update ScrapeSession with error: #{inspect(update_reason)}")
            session
        end
    end
  end
  
  defp process_cases_serially(session, basic_cases) do
    Logger.debug("HSE: Processing #{length(basic_cases)} cases serially for session #{session.session_id}")
    
    validated_params = Map.get(session, :validated_params, %{})
    actor = Map.get(validated_params, :actor)
    
    # Track results for session updates
    results = %{
      cases_created: 0,
      cases_existing: 0,
      cases_errors: 0,
      processed_cases: []
    }
    
    # Process each case serially with full data enrichment
    final_results = Enum.reduce(basic_cases, results, fn basic_case, acc ->
      if basic_case.regulator_id && basic_case.regulator_id != "" do
        process_single_case_with_details(session, basic_case, actor, acc)
      else
        Logger.warning("HSE: Skipping case without regulator_id")
        acc
      end
    end)
    
    # Create processing log for the completed page
    create_page_processing_log(session, final_results.processed_cases, final_results)
    
    # Update session with final page results
    update_session_with_page_results(session, final_results)
  end
  
  defp process_single_case_with_details(session, basic_case, actor, acc) do
    Logger.debug("HSE: Processing case #{basic_case.regulator_id} with additional detail fetching")
    
    # Step 1: Get case details from additional URI
    enriched_case = case get_case_details(basic_case, session.database) do
      {:ok, case_with_details} ->
        Logger.debug("HSE: Fetched details for case #{basic_case.regulator_id}")
        case_with_details
        
      {:error, reason} ->
        Logger.warning("HSE: Failed to fetch details for case #{basic_case.regulator_id}: #{inspect(reason)}")
        basic_case
    end
    
    # Step 2: Process and create the fully enriched case
    case CaseProcessor.process_and_create_case(enriched_case, actor) do
      {:ok, case_record} ->
        Logger.info("HSE: Created case: #{case_record.regulator_id}")
        
        %{acc | 
          cases_created: acc.cases_created + 1,
          processed_cases: [enriched_case | acc.processed_cases]
        }
        
      {:error, %Ash.Error.Invalid{errors: errors}} ->
        if duplicate_error?(errors) do
          Logger.info("HSE: Case already exists: #{enriched_case.regulator_id}")
          
          # Find and update existing case with last_synced_at
          case find_and_update_existing_case(enriched_case, actor) do
            {:ok, updated_case} ->
              Logger.info("HSE: Updated existing case: #{updated_case.regulator_id}")
            {:error, find_error} ->
              Logger.warning("HSE: Failed to find/update existing case: #{inspect(find_error)}")
          end
          
          %{acc | 
            cases_existing: acc.cases_existing + 1,
            processed_cases: [enriched_case | acc.processed_cases]
          }
        else
          Logger.warning("HSE: Error creating case #{enriched_case.regulator_id}: #{inspect(errors)}")
          %{acc | 
            cases_errors: acc.cases_errors + 1,
            processed_cases: [enriched_case | acc.processed_cases]
          }
        end
        
      {:error, reason} ->
        Logger.warning("HSE: Error processing case #{enriched_case.regulator_id}: #{inspect(reason)}")
        %{acc | 
          cases_errors: acc.cases_errors + 1,
          processed_cases: [enriched_case | acc.processed_cases]
        }
    end
  end
  
  defp advance_to_next_page(session) do
    # Update session to next page using Ash.update
    update_params = %{
      current_page: session.current_page + 1,
      pages_processed: session.pages_processed + 1
    }
    
    case Ash.update(session, update_params) do
      {:ok, updated_session} -> updated_session
      {:error, reason} ->
        Logger.error("HSE: Failed to advance page: #{inspect(reason)}")
        session
    end
  end
  
  defp finalize_session(session) do
    # Determine final status based on how the session ended
    final_status = determine_final_status(session)

    case Ash.update(session, %{status: final_status}) do
      {:ok, final_session} ->
        Logger.info("HSE: Scraping session finalized",
                    session_id: final_session.session_id,
                    status: final_session.status,
                    pages_processed: final_session.pages_processed,
                    cases_created: final_session.cases_created)
        {:ok, final_session}

      {:error, reason} ->
        Logger.error("HSE: Failed to finalize session: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp determine_final_status(session) do
    validated_params = Map.get(session, :validated_params, %{})
    max_consecutive_errors = Map.get(validated_params, :max_consecutive_errors, 3)

    cond do
      # If already failed or stopped, preserve that status
      session.status == :failed -> :failed
      session.status == :stopped -> :stopped

      # If stopped due to too many errors, mark as failed
      session.errors_count >= max_consecutive_errors ->
        Logger.warning("HSE: Session stopped due to #{session.errors_count} errors (threshold: #{max_consecutive_errors})")
        :failed

      # If stopped before completing all pages and not due to "all exist" logic, mark as stopped
      session.pages_processed < session.max_pages && session.status == :running ->
        Logger.info("HSE: Session stopped early at page #{session.current_page} (max: #{session.max_pages})")
        :stopped

      # Otherwise, session completed successfully
      true -> :completed
    end
  end
  
  defp should_continue_scraping?(session) do
    validated_params = Map.get(session, :validated_params, %{})
    
    cond do
      session.status != :running -> false
      session.status == :completed -> false
      session.pages_processed >= session.max_pages -> false
      session.errors_count >= Map.get(validated_params, :max_consecutive_errors, 3) -> false
      true -> true
    end
  end
  
  # Helper functions
  
  defp get_case_details(basic_case, database) do
    Logger.debug("HSE: Fetching case details for #{basic_case.regulator_id} from HSE website")
    
    case CaseScraper.scrape_case_details(basic_case.regulator_id, database) do
      {:ok, case_details} ->
        # Merge details into the basic case
        enriched_case = Map.merge(basic_case, case_details)
        
        # Add regulator URL
        enriched_case = Map.put(enriched_case, :regulator_url,
          "https://resources.hse.gov.uk/#{database}/case/case_details.asp?SF=CN&SV=#{basic_case.regulator_id}"
        )
        
        {:ok, enriched_case}
        
      {:error, reason} ->
        Logger.warning("HSE: Failed to get case details for #{basic_case.regulator_id}: #{inspect(reason)}")
        {:ok, basic_case}
    end
  rescue
    error ->
      Logger.error("HSE: Failed to get case details: #{inspect(error)}")
      {:error, error}
  end
  
  defp duplicate_error?(errors) when is_list(errors) do
    Enum.any?(errors, fn error ->
      case error do
        %{message: message} -> String.contains?(message, "already exists") or String.contains?(message, "duplicate")
        _ -> false
      end
    end)
  end
  
  defp duplicate_error?(_), do: false
  
  defp find_and_update_existing_case(scraped_case, actor) do
    case Ash.read(EhsEnforcement.Enforcement.Case, 
                  actor: actor,
                  query: [filter: [regulator_id: scraped_case.regulator_id], limit: 1]) do
      {:ok, [existing_case]} ->
        Ash.update(existing_case, %{last_synced_at: DateTime.utc_now()}, actor: actor)
      
      {:ok, []} ->
        {:error, :not_found}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp create_page_processing_log(session, scraped_cases, results) do
    # Create summary of scraped cases for UI display
    case_summary = Enum.map(scraped_cases, fn case_data ->
      %{
        regulator_id: case_data.regulator_id,
        offender_name: case_data.offender_name,
        case_date: case_data.offence_action_date,
        fine_amount: case_data.offence_fine
      }
    end)
    
    # HSE-specific processing log with unified field names
    log_params = %{
      session_id: session.session_id,
      agency: :hse,
      batch_or_page: session.current_page,
      items_found: length(scraped_cases),
      items_created: results.cases_created,
      items_failed: results.cases_errors,
      items_existing: results.cases_existing,
      creation_errors: [],
      scraped_items: case_summary
    }
    
    case Ash.create(ProcessingLog, log_params) do
      {:ok, _log} ->
        Logger.debug("HSE: Created unified processing log for page #{session.current_page}")
      {:error, reason} ->
        Logger.warning("HSE: Failed to create unified processing log: #{inspect(reason)}")
    end
  end
  
  defp update_session_with_page_results(session, results) do
    total_cases = results.cases_created + results.cases_existing + results.cases_errors
    
    # Check if we should stop because all cases on this page already exist
    should_stop_all_exist = (results.cases_existing == total_cases) and total_cases > 0
    
    update_params = %{
      cases_processed: session.cases_processed + total_cases,
      cases_created: session.cases_created + results.cases_created,
      cases_exist_total: session.cases_exist_total + results.cases_existing,
      errors_count: session.errors_count + results.cases_errors,
      status: if(should_stop_all_exist, do: :completed, else: session.status)
    }
    
    case Ash.update(session, update_params) do
      {:ok, updated_session} ->
        if should_stop_all_exist do
          Logger.info("HSE: Stopping scraping - all #{total_cases} cases on page #{session.current_page} already exist")
        end
        updated_session
        
      {:error, reason} ->
        Logger.error("HSE: Failed to update ScrapeSession: #{inspect(reason)}")
        session
    end
  end
end