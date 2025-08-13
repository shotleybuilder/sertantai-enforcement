defmodule EhsEnforcement.Scraping.ScrapeCoordinator do
  @moduledoc """
  Coordinates HSE case scraping operations with PostgreSQL persistence.
  
  Orchestrates the complete scraping workflow:
  - Page-by-page processing with duplicate detection
  - "Stop when 10 consecutive existing records found" logic
  - Progress tracking and metrics collection
  - Error recovery and retry handling
  - Integration with Ash resources for persistence
  """
  
  require Logger
  require Ash.Query
  
  alias EhsEnforcement.Scraping.Hse.CaseScraper
  alias EhsEnforcement.Scraping.Hse.CaseProcessor
  alias EhsEnforcement.Configuration.ScrapingConfig
  alias EhsEnforcement.Scraping.ScrapeSession
  alias EhsEnforcement.Scraping.ProcessingLog
  
  # Dual notification system:
  # 1. Ash PubSub notifications for session-level updates (handled automatically)
  # 2. Manual PubSub for detailed case processing (required for UI components)
  
  # Default fallback values if no configuration is found
  @fallback_config %{
    consecutive_existing_threshold: 10,
    max_pages_per_session: 100,
    network_timeout_ms: 30_000,
    max_consecutive_errors: 3,
    hse_database: "convictions",
    pause_between_pages_ms: 3_000,
    batch_size: 50
  }
  
  # Legacy struct - now we use Ash ScrapeSession resource instead
  # Keeping this module temporarily for backward compatibility during migration
  defmodule LegacyScrapeSession do
    @moduledoc "Legacy scraping session struct - use Ash ScrapeSession resource instead"
    
    @derive Jason.Encoder
    defstruct [
      :session_id,
      :started_at,
      :completed_at,
      :status,
      :current_page,
      :pages_processed,
      :cases_scraped,
      :cases_created,
      :cases_updated,
      :cases_skipped,
      :cases_exist_total,
      :cases_exist_current_page,
      :consecutive_existing_count,
      :consecutive_errors,
      :errors,
      :stop_reason,
      :actor,
      :options
    ]
  end
  
  @doc """
  Load the active scraping configuration from the database.
  
  Returns the active configuration or falls back to default values if none found.
  """
  def load_scraping_config(opts \\ []) do
    case ScrapingConfig.get_active_config(opts) do
      {:ok, config} -> 
        Logger.debug("Loaded active scraping configuration: #{config.name}")
        config
        
      {:error, :no_active_config} ->
        Logger.warning("No active scraping configuration found, using fallback values")
        struct(ScrapingConfig, @fallback_config)
        
      {:error, reason} ->
        Logger.error("Failed to load scraping configuration: #{inspect(reason)}, using fallback values")
        struct(ScrapingConfig, @fallback_config)
    end
  end
  
  @doc """
  Check if scraping is enabled based on configuration flags.
  
  Options:
  - type: :manual or :scheduled (default: :manual)
  - actor: Actor for loading configuration
  """
  def scraping_enabled?(opts \\ []) do
    config = load_scraping_config(opts)
    type = Keyword.get(opts, :type, :manual)
    
    case type do
      :manual -> config.manual_scraping_enabled
      :scheduled -> config.scheduled_scraping_enabled
      _ -> false
    end
  end
  
  @doc """
  Check if scheduled scraping is enabled - convenience function for AshOban triggers.
  
  Returns true if scheduled scraping feature flag is enabled, false otherwise.
  """
  def scheduled_scraping_enabled?(opts \\ []) do
    scraping_enabled?(Keyword.put(opts, :type, :scheduled))
  end
  
  @doc """
  Start a complete scraping session with automatic pagination and stopping logic.
  
  Options:
  - start_page: Page to start scraping from (default: 1)
  - max_pages: Maximum pages to process (default: 100)
  - database: HSE database to scrape (default: "convictions")
  - stop_on_existing: Stop when consecutive existing threshold reached (default: true)
  - actor: Actor for Ash operations (default: nil)
  
  Returns {:ok, session_results} or {:error, reason}
  """
  def start_scraping_session(opts \\ []) do
    # Detect agency from options (default to HSE for backwards compatibility)
    agency = Keyword.get(opts, :agency, :hse)
    
    # Route to agency-specific scraping session
    case agency do
      :hse -> start_hse_scraping_session(opts)
      :ea -> start_ea_scraping_session(opts)
      _ -> {:error, "Unsupported agency: #{agency}. Supported agencies: :hse, :ea"}
    end
  end

  @doc """
  Start HSE-specific scraping session (original implementation).
  
  Options:
  - start_page: Page to start scraping from (default: 1)
  - max_pages: Maximum pages to process (default: 100)
  - database: HSE database to scrape (default: "convictions")
  - stop_on_existing: Stop when consecutive existing threshold reached (default: true)
  - actor: Actor for Ash operations (default: nil)
  """
  def start_hse_scraping_session(opts \\ []) do
    # Load active configuration from database
    config = load_scraping_config(opts)
    
    # Check if scraping is enabled (defaults to manual scraping check)
    scrape_type = Keyword.get(opts, :scrape_type, :manual)
    unless scraping_enabled?(type: scrape_type, actor: opts[:actor]) do
      {:error, "#{scrape_type} scraping is disabled in configuration"}
    else
    
    # Build session options from configuration
    default_opts = %{
      start_page: 1,
      max_pages: config.max_pages_per_session,
      database: config.hse_database,
      stop_on_existing: true,
      actor: opts[:actor],
      network_timeout: config.network_timeout_ms,
      max_consecutive_errors: config.max_consecutive_errors,
      consecutive_existing_threshold: config.consecutive_existing_threshold,
      pause_between_pages_ms: config.pause_between_pages_ms,
      batch_size: config.batch_size
    }
    
    # DEBUG: Check what we're getting from the LiveView
    Logger.debug("Incoming opts: #{inspect(opts)}")
    Logger.debug("Default opts: #{inspect(default_opts)}")
    
    session_opts = Enum.into(opts, default_opts)
    Logger.debug("Combined session_opts: #{inspect(session_opts)}")
    
    # Access using proper atom keys (after Enum.into, the map should have atom keys)
    session_opts = %{
      start_page: Map.get(session_opts, :start_page),
      max_pages: Map.get(session_opts, :max_pages),
      database: Map.get(session_opts, :database),
      stop_on_existing: Map.get(session_opts, :stop_on_existing),
      actor: Map.get(session_opts, :actor),
      network_timeout: Map.get(session_opts, :network_timeout),
      max_consecutive_errors: Map.get(session_opts, :max_consecutive_errors),
      consecutive_existing_threshold: Map.get(session_opts, :consecutive_existing_threshold),
      pause_between_pages_ms: Map.get(session_opts, :pause_between_pages_ms),
      batch_size: Map.get(session_opts, :batch_size)
    }
    
    Logger.debug("Final session_opts: #{inspect(session_opts)}")
    
    # Create Ash ScrapeSession record with proper parameters
    ash_session_params = %{
      session_id: generate_session_id(),
      start_page: session_opts.start_page,
      max_pages: session_opts.max_pages,
      database: session_opts.database,
      status: :running,
      current_page: session_opts.start_page,
      pages_processed: 0,
      cases_found: 0,
      cases_created: 0,
      cases_exist_total: 0,
      errors_count: 0
    }
    
    # DEBUG: Log the values being used
    Logger.debug("Creating session with params: #{inspect(ash_session_params)}")
    Logger.debug("session_opts: #{inspect(session_opts)}")
    
    case Ash.create(ScrapeSession, ash_session_params) do
      {:ok, session} ->
        Logger.info("Starting scraping session #{session.session_id}", 
                    session_id: session.session_id, 
                    options: session_opts)
        
        # Store session_opts in session for later use
        session_with_opts = Map.put(session, :session_opts, session_opts)
        
        # Continue with session execution...
        execute_scraping_session_result = execute_scraping_session(session_with_opts)
        
        Logger.info("Scraping session completed", 
                    session_id: execute_scraping_session_result.session_id,
                    status: execute_scraping_session_result.status,
                    pages_processed: execute_scraping_session_result.pages_processed,
                    cases_created: execute_scraping_session_result.cases_created)
        
        {:ok, execute_scraping_session_result}
        
      {:error, reason} ->
        Logger.error("Failed to create ScrapeSession record: #{inspect(reason)}")
        {:error, "Failed to create scraping session: #{inspect(reason)}"}
    end
    end
  end
  
  @doc """
  Start EA-specific scraping session with date range and pagination.
  
  Options:
  - date_from: Start date for EA search (required)
  - date_to: End date for EA search (required)
  - action_types: List of action types [:court_case, :caution, :enforcement_notice] (default: [:court_case])
  - start_page: Page to start scraping from (default: 1)
  - max_pages: Maximum pages to process (default: 20)
  - actor: Actor for Ash operations (default: nil)
  
  Returns {:ok, session_results} or {:error, reason}
  """
  def start_ea_scraping_session(opts \\ []) do
    # Load active configuration from database
    config = load_scraping_config(opts)
    
    # Check if scraping is enabled
    scrape_type = Keyword.get(opts, :scrape_type, :manual)
    unless scraping_enabled?(type: scrape_type, actor: opts[:actor]) do
      {:error, "#{scrape_type} EA scraping is disabled in configuration"}
    else
    
    # Validate required EA-specific arguments
    date_from = Keyword.get(opts, :date_from)
    date_to = Keyword.get(opts, :date_to)
    
    unless date_from && date_to do
      {:error, "EA scraping requires date_from and date_to parameters"}
    else
    
    # Build EA session options
    default_opts = %{
      start_page: 1,
      max_pages: 20,  # Conservative default for EA
      action_types: [:court_case],
      actor: opts[:actor],
      network_timeout: config.network_timeout_ms,
      max_consecutive_errors: config.max_consecutive_errors,
      pause_between_pages_ms: config.pause_between_pages_ms,
      batch_size: config.batch_size
    }
    
    session_opts = Enum.into(opts, default_opts)
    
    Logger.info("Starting EA scraping session", 
                date_from: date_from, 
                date_to: date_to,
                action_types: session_opts.action_types,
                pages: "#{session_opts.start_page} to #{session_opts.start_page + session_opts.max_pages - 1}")
    
    # Create Ash ScrapeSession record for EA scraping
    ash_session_params = %{
      session_id: generate_session_id(),
      start_page: session_opts.start_page,
      max_pages: session_opts.max_pages,
      database: "ea_enforcement",  # EA-specific database identifier
      status: :running,
      current_page: session_opts.start_page,
      pages_processed: 0,
      cases_found: 0,
      cases_created: 0,
      cases_exist_total: 0,
      errors_count: 0
    }
    
    case Ash.create(ScrapeSession, ash_session_params) do
      {:ok, session} ->
        Logger.info("Starting EA scraping session #{session.session_id}")
        
        # Store session_opts including EA-specific parameters
        session_with_opts = Map.merge(session, %{
          session_opts: session_opts,
          date_from: date_from,
          date_to: date_to,
          action_types: session_opts.action_types
        })
        
        # Execute EA scraping session
        execute_ea_scraping_session_result = execute_ea_scraping_session(session_with_opts)
        
        Logger.info("EA scraping session completed", 
                    session_id: execute_ea_scraping_session_result.session_id,
                    status: execute_ea_scraping_session_result.status,
                    pages_processed: execute_ea_scraping_session_result.pages_processed,
                    cases_created: execute_ea_scraping_session_result.cases_created)
        
        {:ok, execute_ea_scraping_session_result}
        
      {:error, reason} ->
        Logger.error("Failed to create EA ScrapeSession record: #{inspect(reason)}")
        {:error, "Failed to create EA scraping session: #{inspect(reason)}"}
    end
    end
    end
  end
  
  # Helper function to generate session IDs
  defp generate_session_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
  
  @doc """
  Scrape a specific page range without automatic stopping logic.
  
  Useful for targeted scraping or testing specific pages.
  
  Returns {:ok, session_results} or {:error, reason}
  """
  def scrape_page_range(start_page, end_page, opts \\ []) do
    # Load active configuration from database
    config = load_scraping_config(opts)
    
    # Build session options from configuration
    default_opts = %{
      start_page: start_page,
      max_pages: end_page - start_page + 1,
      database: config.hse_database,
      stop_on_existing: false,  # Don't auto-stop for page range scraping
      actor: opts[:actor],
      network_timeout: config.network_timeout_ms,
      max_consecutive_errors: config.max_consecutive_errors,
      consecutive_existing_threshold: config.consecutive_existing_threshold,
      pause_between_pages_ms: config.pause_between_pages_ms,
      batch_size: config.batch_size
    }
    
    session_opts = opts
    |> Enum.into(default_opts)
    |> Map.put(:start_page, start_page)
    |> Map.put(:end_page, end_page)  # Add explicit end_page for range checking
    |> Map.put(:max_pages, end_page - start_page + 1)
    |> Map.put(:stop_on_existing, false)
    
    start_scraping_session(Map.to_list(session_opts))
  end
  
  
  # Private functions
  
  defp execute_scraping_session(session) do
    Logger.debug("Starting execution of scraping session: #{session.session_id}")
    
    # Note: Ash PubSub notifications are automatically sent when ScrapeSession is created
    # No need for manual broadcasting anymore
    
    Logger.debug("Processing pages for session #{session.session_id}")
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
    Logger.debug("Processing page #{session.current_page} for session #{session.session_id}")
    
    # Get session options for actor context
    session_opts = Map.get(session, :session_opts, %{})
    
    # Get basic cases from the page (legacy pattern: basic info only)
    case CaseScraper.scrape_page_basic(session.current_page, database: session.database) do
      {:ok, basic_cases} ->
        Logger.info("Found #{length(basic_cases)} case references on page #{session.current_page}")
        
        # Process cases serially one by one with additional URI requests (legacy pattern)
        process_cases_serially(session, basic_cases, session_opts[:actor])
        
      {:error, reason} ->
        Logger.error("Failed to scrape page #{session.current_page}: #{inspect(reason)}")
        
        # Update session with error using Ash.update
        error_params = %{
          errors_count: session.errors_count + 1
        }
        
        case Ash.update(session, error_params) do
          {:ok, updated_session} -> updated_session
          {:error, update_reason} ->
            Logger.error("Failed to update ScrapeSession with error: #{inspect(update_reason)}")
            session  # Return original session if update fails
        end
    end
  end

  defp process_cases_serially(session, basic_cases, actor) do
    Logger.debug("Processing #{length(basic_cases)} cases serially for session #{session.session_id}")
    
    # Track results for session updates
    results = %{
      cases_created: 0,
      cases_existing: 0,
      cases_errors: 0,
      should_stop_all_exist: false,
      processed_cases: []
    }
    
    # Process each case serially with full data enrichment (legacy pattern from lines 119-132)
    final_results = Enum.reduce(basic_cases, results, fn basic_case, acc ->
      # Skip if no regulator_id
      if basic_case.regulator_id && basic_case.regulator_id != "" do
        process_single_case_with_details(session, basic_case, actor, acc)
      else
        Logger.warning("Skipping case without regulator_id")
        acc
      end
    end)
    
    # Create processing log for the completed page
    create_page_processing_log(session, final_results.processed_cases, final_results)
    
    # Update session with final page results
    update_session_with_page_results(session, final_results)
  end

  defp process_single_case_with_details(session, basic_case, actor, acc) do
    Logger.debug("🔍 Processing case #{basic_case.regulator_id} with additional detail fetching")
    
    # Step 1: Get case details from additional URI (legacy pattern)
    enriched_case = case get_case_details(basic_case, session.database) do
      {:ok, case_with_details} ->
        Logger.debug("✅ Fetched details for case #{basic_case.regulator_id}")
        case_with_details
        
      {:error, reason} ->
        Logger.warning("⚠️ Failed to fetch details for case #{basic_case.regulator_id}: #{inspect(reason)}")
        # Continue with basic case data if details fetch fails
        basic_case
    end
    
    # Step 2: Process and create the fully enriched case
    case CaseProcessor.process_and_create_case(enriched_case, actor) do
      {:ok, case_record} ->
        # Case record created - triggers case:created PubSub event automatically
        Logger.info("✅ Created case: #{case_record.regulator_id} - should appear in UI via case:created PubSub")
        
        %{acc | 
          cases_created: acc.cases_created + 1,
          processed_cases: [enriched_case | acc.processed_cases]
        }
        
      {:error, %Ash.Error.Invalid{errors: errors}} ->
        # Check if error indicates case already exists
        if duplicate_error?(errors) do
          Logger.info("⏭️ Case already exists: #{enriched_case.regulator_id}")
          
          # Find and update existing case with last_synced_at to trigger case:updated PubSub
          case find_and_update_existing_case(enriched_case, actor) do
            {:ok, updated_case} ->
              Logger.info("📝 Updated existing case: #{updated_case.regulator_id} - should appear in UI via case:updated PubSub")
            {:error, find_error} ->
              Logger.warning("Failed to find/update existing case: #{inspect(find_error)}")
          end
          
          %{acc | 
            cases_existing: acc.cases_existing + 1,
            processed_cases: [enriched_case | acc.processed_cases]
          }
        else
          Logger.warning("❌ Error creating case #{enriched_case.regulator_id}: #{inspect(errors)}")
          %{acc | 
            cases_errors: acc.cases_errors + 1,
            processed_cases: [enriched_case | acc.processed_cases]
          }
        end
        
      {:error, reason} ->
        Logger.warning("❌ Error processing case #{enriched_case.regulator_id}: #{inspect(reason)}")
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
        Logger.error("Failed to advance page: #{inspect(reason)}")
        session  # Return original session if update fails
    end
  end

  defp finalize_session(session) do
    # Update session to completed status using Ash.update
    final_status = if session.status == :running, do: :completed, else: session.status
    
    case Ash.update(session, %{status: final_status}) do
      {:ok, final_session} ->
        Logger.info("Scraping session finalized", 
                    session_id: final_session.session_id,
                    status: final_session.status,
                    pages_processed: final_session.pages_processed,
                    cases_created: final_session.cases_created)
        final_session
        
      {:error, reason} ->
        Logger.error("Failed to finalize session: #{inspect(reason)}")
        session  # Return original session if update fails
    end
  end
  
  defp should_continue_scraping?(session) do
    session_opts = Map.get(session, :session_opts, %{})
    
    cond do
      session.status != :running -> false
      session.status == :completed -> false
      session.pages_processed >= session.max_pages -> false
      session.errors_count >= Map.get(session_opts, :max_consecutive_errors, 3) -> false
      true -> true
    end
  end
  
  @doc """
  Get scraping session statistics and progress information.
  
  Returns summary map with key metrics.
  """
  def session_summary(session) do
    duration_seconds = case session.updated_at do
      nil -> DateTime.diff(DateTime.utc_now(), session.inserted_at)
      completed -> DateTime.diff(completed, session.inserted_at)
    end
    
    %{
      session_id: session.session_id,
      status: session.status,
      duration_seconds: duration_seconds,
      pages_processed: session.pages_processed,
      cases_found: session.cases_found,
      cases_created: session.cases_created,
      cases_exist_total: session.cases_exist_total,
      error_count: session.errors_count,
      success_rate: calculate_success_rate(session)
    }
  end
  
  defp calculate_success_rate(session) do
    total_attempts = session.cases_found
    
    if total_attempts > 0 do
      (session.cases_created / total_attempts * 100) |> Float.round(2)
    else
      0.0
    end
  end
  
  # Helper functions for individual case processing
  
  defp get_case_details(basic_case, database) do
    # Use new CaseScraper to get additional case details (following legacy pattern)
    Logger.debug("📡 Fetching case details for #{basic_case.regulator_id} from HSE website")
    
    # Get case details from additional URI using our new scraper (with built-in rate limiting)
    case EhsEnforcement.Scraping.Hse.CaseScraper.scrape_case_details(basic_case.regulator_id, database) do
      {:ok, case_details} ->
        # Merge details into the basic case (legacy pattern from cases.ex)
        enriched_case = Map.merge(basic_case, case_details)
        
        # Add regulator URL (following legacy pattern from cases.ex lines 122-125)
        enriched_case = Map.put(enriched_case, :regulator_url,
          "https://resources.hse.gov.uk/#{database}/case/case_details.asp?SF=CN&SV=#{basic_case.regulator_id}"
        )
        
        {:ok, enriched_case}
        
      {:error, reason} ->
        Logger.warning("Failed to get case details for #{basic_case.regulator_id}: #{inspect(reason)}")
        # Return basic case if details fetch fails (graceful degradation)
        {:ok, basic_case}
    end
  rescue
    error ->
      Logger.error("Failed to get case details: #{inspect(error)}")
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
    # Find existing case by regulator_id using Ash.read with filter
    case Ash.read(EhsEnforcement.Enforcement.Case, 
                  actor: actor,
                  query: [filter: [regulator_id: scraped_case.regulator_id], limit: 1]) do
      {:ok, [existing_case]} ->
        # Update with last_synced_at to trigger case:updated PubSub event
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
    
    # HSE-specific processing log with correct field names
    # Use unified ProcessingLog with field mapping: cases_scraped -> items_found, etc.
    log_params = %{
      session_id: session.session_id,
      agency: :hse,
      batch_or_page: session.current_page,  # HSE page number
      items_found: length(scraped_cases),   # was cases_scraped
      items_created: results.cases_created,
      items_failed: results.cases_errors,   # was cases_skipped
      items_existing: results.cases_existing,  # was existing_count
      creation_errors: [],  # Individual errors already logged
      scraped_items: case_summary  # was scraped_cases
    }
    
    case Ash.create(ProcessingLog, log_params) do
      {:ok, _log} ->
        Logger.debug("Created unified processing log for HSE page #{session.current_page}")
      {:error, reason} ->
        Logger.warning("Failed to create unified processing log: #{inspect(reason)}")
    end
  end
  
  defp update_session_with_page_results(session, results) do
    total_cases = results.cases_created + results.cases_existing + results.cases_errors
    
    # Check if we should stop because all cases on this page already exist
    should_stop_all_exist = (results.cases_existing == total_cases) and total_cases > 0
    
    update_params = %{
      cases_found: session.cases_found + total_cases,
      cases_created: session.cases_created + results.cases_created,
      cases_exist_total: session.cases_exist_total + results.cases_existing,
      errors_count: session.errors_count + results.cases_errors,
      status: if(should_stop_all_exist, do: :completed, else: session.status)
    }
    
    case Ash.update(session, update_params) do
      {:ok, updated_session} ->
        if should_stop_all_exist do
          Logger.info("Stopping scraping - all #{total_cases} cases on page #{session.current_page} already exist")
        end
        updated_session
        
      {:error, reason} ->
        Logger.error("Failed to update ScrapeSession: #{inspect(reason)}")
        session  # Return original session if update fails
    end
  end

  # EA-specific scraping session execution
  
  defp execute_ea_scraping_session(session) do
    Logger.debug("Starting EA scraping session execution: #{session.session_id}")
    Logger.info("EA scraping date range: #{session.date_from} to #{session.date_to}")
    
    session
    |> process_ea_single_request()
    |> finalize_session()
  end
  
  defp process_ea_single_request(session) do
    Logger.debug("Processing EA single request for session #{session.session_id}")
    
    # Get session options for EA scraping parameters
    session_opts = Map.get(session, :session_opts, %{})
    
    # Load config for timeout settings (rate limiting handled internally by EA scraper)
    config = load_scraping_config()
    
    # Use EA CaseScraper to get ALL cases for the date range in a single request
    # Pass rate limiting config to EA scraper for detail page throttling
    case EhsEnforcement.Scraping.Ea.CaseScraper.scrape_enforcement_actions(
           session.date_from, 
           session.date_to, 
           session.action_types,
           timeout_ms: config.network_timeout_ms,
           detail_delay_ms: config.pause_between_pages_ms
         ) do
      {:ok, ea_cases} ->
        Logger.info("Found #{length(ea_cases)} EA enforcement actions for date range")
        
        # Update session with cases found
        cases_found_params = %{
          cases_found: length(ea_cases),
          current_page: 1,  # EA only has "1 page" since it's all results
          pages_processed: 1
        }
        
        updated_session = case Ash.update(session, cases_found_params) do
          {:ok, updated} -> updated
          {:error, reason} ->
            Logger.error("Failed to update session with cases found: #{inspect(reason)}")
            session
        end
        
        # Process EA cases and convert to Case resource format
        process_ea_cases_serially(updated_session, ea_cases, session_opts[:actor])
        
      {:error, reason} ->
        Logger.error("Failed to scrape EA enforcement actions: #{inspect(reason)}")
        
        # Update session with error
        error_params = %{
          errors_count: session.errors_count + 1,
          current_page: 1,
          pages_processed: 1
        }
        
        case Ash.update(session, error_params) do
          {:ok, updated_session} -> updated_session
          {:error, update_reason} ->
            Logger.error("Failed to update ScrapeSession with error: #{inspect(update_reason)}")
            session  # Return original session if update fails
        end
    end
  end
  
  
  defp process_ea_cases_serially(session, ea_cases, actor) do
    Logger.debug("Processing #{length(ea_cases)} EA cases serially for session #{session.session_id}")
    
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
    
    # Update session with final page results
    update_session_with_page_results(session, final_results)
  end
  
  defp process_single_ea_case(_session, ea_case, actor, acc) do
    Logger.debug("🔍 Processing EA case: #{inspect(ea_case)}")
    
    # Transform EA case to Case resource format using EA DataTransformer
    transformed_case = EhsEnforcement.Agencies.Ea.DataTransformer.transform_ea_record(ea_case)
    
    # Create Case resource using EA CaseProcessor pattern
    case EhsEnforcement.Agencies.Ea.CaseProcessor.process_and_create_case(transformed_case, actor) do
      {:ok, case_record} ->
        Logger.info("✅ Created EA case: #{case_record.regulator_id}")
        %{acc | 
          cases_created: acc.cases_created + 1,
          processed_cases: [transformed_case | acc.processed_cases]
        }
        
      {:error, reason} ->
        # Check if error indicates case already exists
        if duplicate_error?(reason) do
          Logger.info("⏭️ EA case already exists: #{transformed_case[:regulator_id]}")
          %{acc | 
            cases_existing: acc.cases_existing + 1,
            processed_cases: [transformed_case | acc.processed_cases]
          }
        else
          Logger.warning("❌ Error creating EA case: #{inspect(reason)}")
          %{acc | 
            cases_errors: acc.cases_errors + 1,
            processed_cases: [transformed_case | acc.processed_cases]
          }
        end
    end
  end
  
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
    
    # EA-specific processing log with correct field names
    # Use unified ProcessingLog with field mapping: cases_found -> items_found, etc.
    log_params = %{
      session_id: session.session_id,
      agency: :ea,
      batch_or_page: 1,  # EA batch number (single batch)
      items_found: length(processed_cases),  # was cases_found
      items_created: results.cases_created,
      items_existing: results.cases_existing,  # was cases_existing
      items_failed: results.cases_errors,  # was cases_failed
      creation_errors: [],  # Individual errors already logged
      scraped_items: case_summary  # was scraped_case_summary
    }
    
    case Ash.create(ProcessingLog, log_params) do
      {:ok, _log} ->
        Logger.debug("Created unified processing log for EA session #{session.session_id}")
      {:error, reason} ->
        Logger.warning("Failed to create unified processing log: #{inspect(reason)}")
    end
  end

end