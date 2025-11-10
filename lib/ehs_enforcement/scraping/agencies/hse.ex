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
  alias EhsEnforcement.Scraping.Hse.NoticeScraper
  alias EhsEnforcement.Scraping.Hse.NoticeProcessor
  alias EhsEnforcement.Scraping.ProcessingLog

  @impl true
  def validate_params(opts) do
    Logger.debug("HSE: Validating parameters: #{inspect(opts)}")

    # Extract and validate HSE-specific parameters
    start_page = Keyword.get(opts, :start_page, 1)
    max_pages = Keyword.get(opts, :max_pages)
    database = Keyword.get(opts, :database)
    actor = Keyword.get(opts, :actor)
    enforcement_type = Keyword.get(opts, :enforcement_type, :case)

    # Load configuration for defaults if max_pages or database not provided
    config = load_scraping_config(opts)

    # Build validated parameters with defaults from config
    validated_params = %{
      start_page: validate_page_number(start_page),
      max_pages: max_pages || config.max_pages_per_session,
      database: database || config.hse_database,
      enforcement_type: enforcement_type,
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
      database: validated_params.database
    )

    # Create Ash ScrapeSession record with proper parameters
    session_id = EhsEnforcement.Scraping.AgencyBehavior.generate_session_id()

    ash_session_params = %{
      session_id: session_id,
      agency: :hse,
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
        # Set logger metadata for this scraping session
        Logger.metadata(session_id: session.session_id, agency: :hse)

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
      cases_created: session_results.cases_created
    )

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
        Logger.error(
          "HSE: Failed to load scraping configuration: #{inspect(reason)}, using fallback values"
        )

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

  defp validate_database(database),
    do: {:error, "Invalid HSE database: #{database}. Supported: convictions, notices, appeals"}

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
    Logger.info("🚀 HSE: Starting execution of scraping session: #{session.session_id}")

    Logger.info(
      "🚀 HSE: Initial state - pages_processed: #{session.pages_processed}, current_page: #{session.current_page}, status: #{session.status}"
    )

    session
    |> process_pages_until_complete()
    |> finalize_session()
  end

  defp process_pages_until_complete(session) do
    continue? = should_continue_scraping?(session)

    Logger.info(
      "🔄 HSE: Loop iteration - should_continue?: #{continue?}, pages_processed: #{session.pages_processed}/#{session.max_pages}, status: #{session.status}"
    )

    if continue? do
      Logger.info("✅ HSE: Continuing to process page #{session.current_page}")

      session
      |> process_current_page()
      |> advance_to_next_page()
      |> process_pages_until_complete()
    else
      Logger.warning(
        "⛔ HSE: Stopping scraping loop - pages_processed: #{session.pages_processed}, status: #{session.status}"
      )

      session
    end
  end

  defp process_current_page(session) do
    Logger.info(
      "📄 HSE: ENTERING process_current_page - page #{session.current_page}, session #{session.session_id}"
    )

    Logger.info(
      "📄 HSE: Session state - pages_processed: #{session.pages_processed}, cases_found: #{session.cases_found}, cases_created: #{session.cases_created}"
    )

    Logger.debug(
      "HSE: session.database value: #{inspect(session.database)} (type: #{inspect(is_binary(session.database))})"
    )

    # Route to correct scraper based on database type
    case session.database do
      "notices" ->
        # Get notices from the page (notices use country parameter, default to England)
        # NoticeScraper.get_hse_notices returns a list directly, or {:error, reason}
        case NoticeScraper.get_hse_notices(page_number: session.current_page, country: "England") do
          {:error, reason} ->
            Logger.error("HSE: Failed to scrape page #{session.current_page}: #{inspect(reason)}")

            # Update session with error using Ash.update
            error_params = %{errors_count: session.errors_count + 1}

            case Ash.update(session, error_params) do
              {:ok, updated_session} ->
                updated_session

              {:error, update_reason} ->
                Logger.error(
                  "HSE: Failed to update ScrapeSession with error: #{inspect(update_reason)}"
                )

                session
            end

          notices when is_list(notices) ->
            Logger.info(
              "📋 HSE: Found #{length(notices)} notice references on page #{session.current_page}"
            )

            Logger.info("📋 HSE: About to process notices serially...")

            # Process notices serially
            result = process_notices_serially(session, notices)
            Logger.info("✅ HSE: Finished processing notices for page #{session.current_page}")

            Logger.info(
              "✅ HSE: Result session state - pages_processed: #{result.pages_processed}, cases_found: #{result.cases_found}, cases_created: #{result.cases_created}"
            )

            result
        end

      _ ->
        # Get basic cases from the page (convictions, appeals)
        case CaseScraper.scrape_page_basic(session.current_page, database: session.database) do
          {:ok, basic_cases} ->
            Logger.info(
              "HSE: Found #{length(basic_cases)} case references on page #{session.current_page}"
            )

            # Process cases serially with additional URI requests
            process_cases_serially(session, basic_cases)

          {:error, reason} ->
            Logger.error("HSE: Failed to scrape page #{session.current_page}: #{inspect(reason)}")

            # Update session with error using Ash.update
            error_params = %{errors_count: session.errors_count + 1}

            case Ash.update(session, error_params) do
              {:ok, updated_session} ->
                updated_session

              {:error, update_reason} ->
                Logger.error(
                  "HSE: Failed to update ScrapeSession with error: #{inspect(update_reason)}"
                )

                session
            end
        end
    end
  end

  defp process_cases_serially(session, basic_cases) do
    Logger.debug(
      "HSE: Processing #{length(basic_cases)} cases serially for session #{session.session_id}"
    )

    validated_params = Map.get(session, :validated_params, %{})
    actor = Map.get(validated_params, :actor)

    # Track both session and results through the reduction
    initial_state = {
      session,
      %{
        cases_created: 0,
        cases_existing: 0,
        cases_errors: 0,
        processed_cases: []
      }
    }

    # Process each case serially with incremental session updates
    {final_session, final_results} =
      Enum.reduce(basic_cases, initial_state, fn basic_case, {current_session, acc} ->
        if basic_case.regulator_id && basic_case.regulator_id != "" do
          # Get case details
          enriched_case =
            case get_case_details(basic_case, current_session.database) do
              {:ok, case_with_details} ->
                Logger.debug("HSE: Fetched details for case #{basic_case.regulator_id}")
                case_with_details

              {:error, reason} ->
                Logger.warning(
                  "HSE: Failed to fetch details for case #{basic_case.regulator_id}: #{inspect(reason)}"
                )

                basic_case
            end

          # Process and create the case
          case CaseProcessor.process_and_create_case(enriched_case, actor) do
            {:ok, case_record} ->
              Logger.info("HSE: Created case: #{case_record.regulator_id}")

              # Update session IMMEDIATELY after creating case
              updated_session = update_session_incremental(current_session, :created)

              updated_acc = %{
                acc
                | cases_created: acc.cases_created + 1,
                  processed_cases: [enriched_case | acc.processed_cases]
              }

              {updated_session, updated_acc}

            {:error, %Ash.Error.Invalid{errors: errors}} ->
              if duplicate_error?(errors) do
                Logger.info("HSE: Case already exists: #{enriched_case.regulator_id}")

                # Find and update existing case with last_synced_at
                case find_and_update_existing_case(enriched_case, actor) do
                  {:ok, updated_case} ->
                    Logger.info("HSE: Updated existing case: #{updated_case.regulator_id}")

                  {:error, find_error} ->
                    Logger.warning(
                      "HSE: Failed to find/update existing case: #{inspect(find_error)}"
                    )
                end

                # Update session with existing status
                updated_session = update_session_incremental(current_session, :existing)

                updated_acc = %{
                  acc
                  | cases_existing: acc.cases_existing + 1,
                    processed_cases: [enriched_case | acc.processed_cases]
                }

                {updated_session, updated_acc}
              else
                Logger.warning(
                  "HSE: Error creating case #{enriched_case.regulator_id}: #{inspect(errors)}"
                )

                # Update session with error
                updated_session = update_session_incremental(current_session, :error)

                updated_acc = %{
                  acc
                  | cases_errors: acc.cases_errors + 1,
                    processed_cases: [enriched_case | acc.processed_cases]
                }

                {updated_session, updated_acc}
              end

            {:error, reason} ->
              Logger.warning(
                "HSE: Error processing case #{enriched_case.regulator_id}: #{inspect(reason)}"
              )

              # Update session with error
              updated_session = update_session_incremental(current_session, :error)

              updated_acc = %{
                acc
                | cases_errors: acc.cases_errors + 1,
                  processed_cases: [enriched_case | acc.processed_cases]
              }

              {updated_session, updated_acc}
          end
        else
          Logger.warning("HSE: Skipping case without regulator_id")
          {current_session, acc}
        end
      end)

    # Create processing log for the completed page
    create_page_processing_log(final_session, final_results.processed_cases, final_results)

    # Update session with page completion (increments pages_processed)
    update_session_with_page_results(final_session, final_results)
  end

  defp advance_to_next_page(session) do
    Logger.info(
      "⏭️  HSE: ENTERING advance_to_next_page - current_page: #{session.current_page}, pages_processed: #{session.pages_processed}"
    )

    # Update session to next page using Ash.update
    # NOTE: pages_processed is now incremented in update_session_with_page_results
    update_params = %{
      current_page: session.current_page + 1
    }

    Logger.info(
      "⏭️  HSE: Updating session - new current_page will be: #{session.current_page + 1}"
    )

    # Preserve validated_params across updates
    validated_params = Map.get(session, :validated_params)

    case Ash.update(session, update_params) do
      {:ok, updated_session} ->
        Logger.info("✅ HSE: Successfully advanced to page #{updated_session.current_page}")

        # Re-attach validated_params to preserve across pipeline
        if validated_params do
          Map.put(updated_session, :validated_params, validated_params)
        else
          updated_session
        end

      {:error, reason} ->
        Logger.error("❌ HSE: Failed to advance page: #{inspect(reason)}")
        session
    end
  end

  # Notice processing functions (similar to case processing but using NoticeProcessor)

  defp process_notices_serially(session, notices) do
    Logger.debug(
      "HSE: Processing #{length(notices)} notices serially for session #{session.session_id}"
    )

    validated_params = Map.get(session, :validated_params, %{})
    actor = Map.get(validated_params, :actor)

    # Track both session and results through the reduction
    initial_state = {
      session,
      %{
        cases_created: 0,
        cases_existing: 0,
        cases_errors: 0,
        processed_cases: []
      }
    }

    # Process each notice serially with incremental session updates
    {final_session, final_results} =
      Enum.reduce(notices, initial_state, fn notice, {current_session, acc} ->
        if notice.regulator_id && notice.regulator_id != "" do
          # Process the notice
          enriched_notice = enrich_notice_with_details(notice)

          case NoticeProcessor.process_and_create_notice(enriched_notice, actor) do
            {:ok, _notice} ->
              Logger.info("HSE: Created/updated notice #{enriched_notice.regulator_id}")

              # Update session IMMEDIATELY after processing this record
              updated_session = update_session_incremental(current_session, :created)

              # Update accumulator
              updated_acc = %{acc | cases_created: acc.cases_created + 1}

              updated_acc = %{
                updated_acc
                | processed_cases: [enriched_notice | acc.processed_cases]
              }

              {updated_session, updated_acc}

            {:error, reason} ->
              Logger.error(
                "HSE: Failed to process notice #{notice.regulator_id}: #{inspect(reason)}"
              )

              # Update session with error
              updated_session = update_session_incremental(current_session, :error)

              # Update accumulator
              updated_acc = %{acc | cases_errors: acc.cases_errors + 1}

              {updated_session, updated_acc}
          end
        else
          Logger.warning("HSE: Skipping notice without regulator_id")
          {current_session, acc}
        end
      end)

    # Create processing log for the completed page
    create_page_processing_log(final_session, final_results.processed_cases, final_results)

    # Update session with page completion (increments pages_processed)
    update_session_with_page_results(final_session, final_results)
  end

  defp enrich_notice_with_details(notice) do
    # Fetch notice details
    details = NoticeScraper.get_notice_details(notice.regulator_id)

    # Fetch notice breaches
    breaches = NoticeScraper.get_notice_breaches(notice.regulator_id)

    # Merge all data together
    notice
    |> Map.merge(details)
    |> Map.merge(breaches)
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
          cases_created: final_session.cases_created
        )

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
      session.status == :failed ->
        :failed

      session.status == :stopped ->
        :stopped

      # If stopped due to too many errors, mark as failed
      session.errors_count >= max_consecutive_errors ->
        Logger.warning(
          "HSE: Session stopped due to #{session.errors_count} errors (threshold: #{max_consecutive_errors})"
        )

        :failed

      # If stopped before completing all pages and not due to "all exist" logic, mark as stopped
      session.pages_processed < session.max_pages && session.status == :running ->
        Logger.info(
          "HSE: Session stopped early at page #{session.current_page} (max: #{session.max_pages})"
        )

        :stopped

      # Otherwise, session completed successfully
      true ->
        :completed
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
        enriched_case =
          Map.put(
            enriched_case,
            :regulator_url,
            "https://resources.hse.gov.uk/#{database}/case/case_details.asp?SF=CN&SV=#{basic_case.regulator_id}"
          )

        {:ok, enriched_case}

      {:error, reason} ->
        Logger.warning(
          "HSE: Failed to get case details for #{basic_case.regulator_id}: #{inspect(reason)}"
        )

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
        %{message: message} ->
          String.contains?(message, "already exists") or String.contains?(message, "duplicate")

        _ ->
          false
      end
    end)
  end

  defp duplicate_error?(_), do: false

  defp find_and_update_existing_case(scraped_case, actor) do
    case Ash.read(EhsEnforcement.Enforcement.Case,
           actor: actor,
           query: [filter: [regulator_id: scraped_case.regulator_id], limit: 1]
         ) do
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
    # Note: Notices don't have offence_fine, so use Map.get with nil default
    case_summary =
      Enum.map(scraped_cases, fn case_data ->
        %{
          regulator_id: case_data.regulator_id,
          offender_name: case_data.offender_name,
          case_date: case_data.offence_action_date,
          fine_amount: Map.get(case_data, :offence_fine, nil)
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

  # Updates session incrementally after processing each individual record.
  #
  # This function is called after EACH notice/case is processed to provide
  # real-time progress updates to the UI via PubSub.
  #
  # Parameters:
  # - `session` - Current ScrapeSession
  # - `result_type` - `:created`, `:existing`, or `:error`
  #
  # Returns: Updated session with incremented counters or original session on error
  defp update_session_incremental(session, result_type) do
    update_params =
      case result_type do
        :created ->
          %{
            cases_found: session.cases_found + 1,
            cases_created: session.cases_created + 1,
            cases_processed: session.cases_processed + 1
          }

        :existing ->
          %{
            cases_found: session.cases_found + 1,
            cases_exist_total: session.cases_exist_total + 1,
            cases_processed: session.cases_processed + 1
          }

        :error ->
          %{
            cases_found: session.cases_found + 1,
            errors_count: session.errors_count + 1,
            cases_processed: session.cases_processed + 1
          }
      end

    # Preserve validated_params
    validated_params = Map.get(session, :validated_params)

    case Ash.update(session, update_params) do
      {:ok, updated_session} ->
        Logger.debug(
          "📊 HSE: Updated session incrementally - cases_found: #{updated_session.cases_found}, cases_created: #{updated_session.cases_created}, result: #{result_type}"
        )

        # Ash PubSub will broadcast "scrape_session:updated" automatically

        if validated_params do
          Map.put(updated_session, :validated_params, validated_params)
        else
          updated_session
        end

      {:error, reason} ->
        Logger.error("❌ HSE: Failed incremental update: #{inspect(reason)}")
        # Return original session on failure
        session
    end
  end

  defp update_session_with_page_results(session, results) do
    total_cases = results.cases_created + results.cases_existing + results.cases_errors

    Logger.info("💾 HSE: ENTERING update_session_with_page_results")

    Logger.info(
      "💾 HSE: Page results - created: #{results.cases_created}, existing: #{results.cases_existing}, errors: #{results.cases_errors}, total: #{total_cases}"
    )

    Logger.info(
      "💾 HSE: Current session - cases_processed: #{session.cases_processed}, cases_created: #{session.cases_created}, cases_exist_total: #{session.cases_exist_total}"
    )

    # Check if we should stop because all cases on this page already exist
    should_stop_all_exist = results.cases_existing == total_cases and total_cases > 0

    # NOTE: cases_found, cases_created, cases_exist_total, cases_processed, and errors_count
    # are now updated incrementally per record. We only need to increment pages_processed here.
    update_params = %{
      pages_processed: session.pages_processed + 1,
      status: if(should_stop_all_exist, do: :completed, else: session.status)
    }

    Logger.info("💾 HSE: Update params - #{inspect(update_params)}")

    # Preserve validated_params across updates
    validated_params = Map.get(session, :validated_params)

    case Ash.update(session, update_params) do
      {:ok, updated_session} ->
        Logger.info(
          "✅ HSE: Successfully updated session - new cases_processed: #{updated_session.cases_processed}, cases_found: #{updated_session.cases_found}, cases_created: #{updated_session.cases_created}"
        )

        if should_stop_all_exist do
          Logger.info(
            "⛔ HSE: Stopping scraping - all #{total_cases} cases on page #{session.current_page} already exist"
          )
        end

        # Re-attach validated_params to preserve across pipeline
        if validated_params do
          Map.put(updated_session, :validated_params, validated_params)
        else
          updated_session
        end

      {:error, reason} ->
        Logger.error("❌ HSE: Failed to update ScrapeSession: #{inspect(reason)}")
        session
    end
  end
end
