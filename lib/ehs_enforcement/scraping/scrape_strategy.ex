defmodule EhsEnforcement.Scraping.ScrapeStrategy do
  @moduledoc """
  Behavior for agency-specific scraping strategies.

  This behavior defines a unified interface for scraping enforcement data
  from different UK regulatory agencies (HSE, EA, SEPA, NRW, etc.) and
  enforcement types (cases, notices).

  Each agency/enforcement-type combination implements this behavior,
  enabling a single unified scraping interface in the LiveView layer.

  ## Example Implementation

      defmodule EhsEnforcement.Scraping.Strategies.HSE.CaseStrategy do
        @behaviour EhsEnforcement.Scraping.ScrapeStrategy

        @impl true
        def validate_params(params) do
          # Validate HSE-specific parameters (start_page, max_pages, database)
          {:ok, validated_params}
        end

        @impl true
        def scrape_data(params) do
          # Delegate to HSE.CaseScraper
          HSE.CaseScraper.scrape_cases(params)
        end

        @impl true
        def process_record(case_data, session) do
          # Delegate to HSE.CaseProcessor
          HSE.CaseProcessor.process_case(case_data, session)
        end

        @impl true
        def calculate_progress(session) do
          # HSE uses page-based progress
          if session.total_pages > 0 do
            (session.current_page / session.total_pages) * 100
          else
            0.0
          end
        end

        @impl true
        def format_progress_display(session) do
          %{
            percentage: calculate_progress(session),
            current_page: session.current_page,
            total_pages: session.total_pages,
            cases_found: session.cases_found,
            cases_created: session.cases_created,
            cases_exist_total: session.cases_exist_total
          }
        end

        @impl true
        def strategy_name, do: "HSE Case Scraping"

        @impl true
        def agency_identifier, do: :hse

        @impl true
        def enforcement_type, do: :case
      end

  ## Usage in LiveView

  The unified scraping LiveView uses strategies via the StrategyRegistry:

      def mount(%{"agency" => agency, "type" => type}, _session, socket) do
        {:ok, strategy} = StrategyRegistry.get_strategy(
          String.to_existing_atom(agency),
          String.to_existing_atom(type)
        )

        socket =
          socket
          |> assign(:strategy, strategy)
          |> assign(:agency, agency)
          |> assign(:enforcement_type, type)

        {:ok, socket}
      end

      def handle_event("start_scraping", params, socket) do
        strategy = socket.assigns.strategy

        case strategy.validate_params(params) do
          {:ok, validated_params} ->
            {:ok, session} = start_scraping(strategy, validated_params)
            {:noreply, assign(socket, :session, session)}

          {:error, errors} ->
            {:noreply, put_flash(socket, :error, "Invalid parameters")}
        end
      end
  """

  alias EhsEnforcement.Scraping.ScrapeSession

  @typedoc """
  Scraping parameters map containing agency-specific configuration.

  Common fields:
  - `:start_date` - Start date for date-range scraping (EA pattern)
  - `:end_date` - End date for date-range scraping (EA pattern)
  - `:start_page` - Starting page number for pagination (HSE pattern)
  - `:max_pages` - Maximum pages to scrape (HSE pattern)
  - `:database` - Database identifier (HSE: "convictions", "notices", "appeals")
  - `:action_types` - List of action types (EA: [:court_case, :caution, :enforcement_notice])
  """
  @type params :: map()

  @typedoc """
  A ScrapeSession resource tracking scraping progress and results.
  """
  @type session :: ScrapeSession.t()

  @typedoc """
  Result tuple for operations that can succeed or fail.
  """
  @type result :: {:ok, any()} | {:error, term()}

  @typedoc """
  Progress display map containing UI-specific fields.

  Common fields:
  - `:percentage` - Progress percentage (0.0-100.0)
  - `:status` - Current status (:idle, :running, :completed, :stopped, :failed)
  - Agency-specific fields for displaying current state
  """
  @type progress_display :: map()

  @doc """
  Validates scraping parameters for this strategy.

  Each strategy implements agency-specific validation:
  - HSE: Validates `start_page`, `max_pages`, `database`
  - EA: Validates `date_from`, `date_to`, `action_types`

  Returns normalized/validated parameters or error with validation messages.

  ## Examples

      # HSE Case Strategy
      iex> validate_params(%{start_page: 1, max_pages: 10, database: "convictions"})
      {:ok, %{start_page: 1, max_pages: 10, database: "convictions"}}

      iex> validate_params(%{start_page: -1})
      {:error, "start_page must be positive"}

      # EA Case Strategy
      iex> validate_params(%{date_from: ~D[2024-01-01], date_to: ~D[2024-12-31]})
      {:ok, %{date_from: ~D[2024-01-01], date_to: ~D[2024-12-31], action_types: [:court_case]}}
  """
  @callback validate_params(params()) :: result()

  @doc """
  Executes the scraping operation for this strategy.

  Delegates to the appropriate scraper module (e.g., HSE.CaseScraper, EA.NoticeScraper)
  to fetch raw data from the agency website.

  Returns scraped data or error if scraping fails.

  ## Examples

      # HSE Case Strategy
      iex> scrape_data(%{start_page: 1, max_pages: 5, database: "convictions"})
      {:ok, [%{case_number: "123", offender_name: "ABC Ltd", ...}, ...]}

      # EA Notice Strategy
      iex> scrape_data(%{date_from: ~D[2024-01-01], date_to: ~D[2024-12-31]})
      {:ok, [%{notice_id: "EN-456", company_name: "XYZ Corp", ...}, ...]}
  """
  @callback scrape_data(params()) :: result()

  @doc """
  Processes a single scraped record for this strategy.

  Delegates to the appropriate processor module (e.g., HSE.CaseProcessor, EA.NoticeProcessor)
  to transform raw scraped data into Ash resources (Case, Notice, Offender, etc.).

  Returns processed record result including creation/update status.

  ## Examples

      iex> process_record(case_data, session)
      {:ok, %{status: :created, case: %Case{}, offender: %Offender{}}}

      iex> process_record(notice_data, session)
      {:ok, %{status: :existing, notice: %Notice{}}}
  """
  @callback process_record(any(), session()) :: result()

  @doc """
  Calculates current progress percentage for this strategy.

  Each strategy implements agency-specific progress calculation:
  - HSE: Page-based progress (current_page / total_pages * 100)
  - EA: Record-based progress (processed_records / total_records * 100)

  Returns float between 0.0 and 100.0.

  ## Examples

      # HSE page-based progress
      iex> calculate_progress(%{current_page: 5, total_pages: 10})
      50.0

      # EA record-based progress
      iex> calculate_progress(%{cases_processed: 15, cases_found: 30})
      50.0
  """
  @callback calculate_progress(session()) :: float()

  @doc """
  Formats progress data for UI display.

  Returns a map with all fields needed by the progress component,
  including agency-specific display fields.

  ## Examples

      # HSE Case Strategy
      iex> format_progress_display(session)
      %{
        percentage: 50.0,
        current_page: 5,
        total_pages: 10,
        cases_found: 42,
        cases_created: 15,
        cases_exist_total: 27
      }

      # EA Notice Strategy
      iex> format_progress_display(session)
      %{
        percentage: 75.0,
        notices_found: 20,
        notices_processed: 15,
        notices_created: 8,
        notices_exist_total: 7
      }
  """
  @callback format_progress_display(session()) :: progress_display()

  @doc """
  Returns human-readable name for this strategy.

  Used in UI headings and logs.

  ## Examples

      iex> strategy_name()
      "HSE Case Scraping"

      iex> strategy_name()
      "Environment Agency Notice Scraping"
  """
  @callback strategy_name() :: String.t()

  @doc """
  Returns agency identifier atom for this strategy.

  Used for routing and agency-specific logic.

  ## Examples

      iex> agency_identifier()
      :hse

      iex> agency_identifier()
      :environment_agency
  """
  @callback agency_identifier() :: atom()

  @doc """
  Returns enforcement type for this strategy.

  Either `:case` or `:notice`.

  ## Examples

      iex> enforcement_type()
      :case

      iex> enforcement_type()
      :notice
  """
  @callback enforcement_type() :: :case | :notice
end
