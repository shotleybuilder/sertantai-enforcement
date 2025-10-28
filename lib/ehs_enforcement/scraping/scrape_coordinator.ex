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

  alias EhsEnforcement.Configuration.ScrapingConfig
  alias EhsEnforcement.Scraping.AgencyBehavior

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
        Logger.error(
          "Failed to load scraping configuration: #{inspect(reason)}, using fallback values"
        )

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
  Start a complete scraping session using agency behavior pattern.

  This function uses the AgencyBehavior pattern to delegate to agency-specific
  implementations, replacing the previous case statement approach.

  Options:
  - agency: Agency to scrape (:hse, :ea) - required
  - Actor and agency-specific parameters (see individual agency modules)

  HSE Options:
  - start_page: Page to start scraping from (default: 1)
  - max_pages: Maximum pages to process (default: 100) 
  - database: HSE database to scrape (default: "convictions")
  - stop_on_existing: Stop when consecutive existing threshold reached (default: true)

  EA Options:
  - date_from: Start date for EA search (required)
  - date_to: End date for EA search (required)
  - action_types: List of action types (default: [:court_case])

  Returns {:ok, session_results} or {:error, reason}
  """
  def start_scraping_session(opts \\ []) do
    # Detect agency from options (default to HSE for backwards compatibility)
    agency = Keyword.get(opts, :agency, :hse)

    Logger.info("Starting scraping session", agency: agency, opts: Keyword.drop(opts, [:actor]))

    # Use AgencyBehavior pattern instead of case statements
    try do
      agency_module = AgencyBehavior.get_agency_module(agency)
      config = load_scraping_config(opts)

      with {:ok, validated_params} <- agency_module.validate_params(opts),
           {:ok, session_results} <- agency_module.start_scraping(validated_params, config) do
        # Process results through agency-specific post-processing
        final_results = agency_module.process_results(session_results)

        Logger.info("Scraping session completed successfully",
          agency: agency,
          session_id: final_results.session_id,
          status: final_results.status
        )

        {:ok, final_results}
      else
        {:error, reason} ->
          Logger.error("Scraping session failed", agency: agency, reason: inspect(reason))
          {:error, reason}
      end
    rescue
      error in ArgumentError ->
        Logger.error("Unsupported agency: #{agency}")
        {:error, error.message}
    end
  end

  @doc """
  Start HSE-specific scraping session (legacy implementation).

  @deprecated "Use start_scraping_session(opts ++ [agency: :hse]) instead"

  This function is maintained for backward compatibility but delegates to the new
  AgencyBehavior pattern. New code should use start_scraping_session/1 instead.

  Options:
  - start_page: Page to start scraping from (default: 1)
  - max_pages: Maximum pages to process (default: 100)
  - database: HSE database to scrape (default: "convictions")
  - stop_on_existing: Stop when consecutive existing threshold reached (default: true)
  - actor: Actor for Ash operations (default: nil)
  """
  def start_hse_scraping_session(opts \\ []) do
    Logger.warning(
      "start_hse_scraping_session/1 is deprecated. Use start_scraping_session/1 with agency: :hse instead."
    )

    # Delegate to new behavior-based implementation
    opts_with_agency = Keyword.put(opts, :agency, :hse)
    start_scraping_session(opts_with_agency)
  end

  @doc """
  Start EA-specific scraping session (legacy implementation).

  @deprecated "Use start_scraping_session(opts ++ [agency: :ea]) instead"

  This function is maintained for backward compatibility but delegates to the new
  AgencyBehavior pattern. New code should use start_scraping_session/1 instead.

  Options:
  - date_from: Start date for EA search (required)
  - date_to: End date for EA search (required)
  - action_types: List of action types [:court_case, :caution, :enforcement_notice] (default: [:court_case])
  - actor: Actor for Ash operations (default: nil)

  Returns {:ok, session_results} or {:error, reason}
  """
  def start_ea_scraping_session(opts \\ []) do
    Logger.warning(
      "start_ea_scraping_session/1 is deprecated. Use start_scraping_session/1 with agency: :ea instead."
    )

    # Delegate to new behavior-based implementation
    opts_with_agency = Keyword.put(opts, :agency, :ea)
    start_scraping_session(opts_with_agency)
  end

  @doc """
  Scrape a specific page range without automatic stopping logic.

  Useful for targeted scraping or testing specific pages. Defaults to HSE scraping.

  Returns {:ok, session_results} or {:error, reason}
  """
  def scrape_page_range(start_page, end_page, opts \\ []) do
    # Set agency to HSE if not specified (backward compatibility)
    agency = Keyword.get(opts, :agency, :hse)

    # Build session options for page range scraping
    range_opts =
      opts
      |> Keyword.put(:agency, agency)
      |> Keyword.put(:start_page, start_page)
      |> Keyword.put(:max_pages, end_page - start_page + 1)
      # Don't auto-stop for range scraping
      |> Keyword.put(:stop_on_existing, false)

    Logger.info("Starting page range scraping",
      agency: agency,
      start_page: start_page,
      end_page: end_page
    )

    start_scraping_session(range_opts)
  end

  @doc """
  Get scraping session statistics and progress information.

  Returns summary map with key metrics.
  """
  def session_summary(session) do
    duration_seconds =
      case session.updated_at do
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
end
