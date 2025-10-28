defmodule EhsEnforcement.Scraping.Strategies.HSE.CaseStrategy do
  @moduledoc """
  Strategy for scraping HSE court cases from the HSE convictions database.

  This strategy implements the `ScrapeStrategy` behavior for HSE case scraping,
  which uses page-based pagination to fetch court case data from the HSE website.

  ## Scraping Pattern

  HSE case scraping follows a page-based pattern:
  - Starts at `start_page` (default: 1)
  - Scrapes up to `max_pages` pages
  - Each page contains multiple cases
  - Cases are enriched with details from individual case pages
  - Progress is calculated based on pages processed

  ## Database Options

  The HSE database parameter determines which HSE database to scrape:
  - `"convictions"` - Court case convictions (default)
  - `"notices"` - Enforcement notices (use NoticeStrategy instead)
  - `"appeals"` - Appeal cases

  ## Example Usage

      iex> strategy = EhsEnforcement.Scraping.Strategies.HSE.CaseStrategy
      iex> params = %{start_page: 1, max_pages: 10, database: "convictions"}
      iex> {:ok, validated} = strategy.validate_params(params)
      iex> {:ok, cases} = strategy.scrape_data(validated)
  """

  @behaviour EhsEnforcement.Scraping.ScrapeStrategy

  alias EhsEnforcement.Scraping.Hse.CaseScraper
  alias EhsEnforcement.Scraping.Hse.CaseProcessor
  alias EhsEnforcement.Scraping.ScrapeSession

  @default_database "convictions"
  @valid_databases ["convictions", "appeals"]

  # ScrapeStrategy Behavior Implementation

  @impl true
  def validate_params(params) do
    with {:ok, start_page} <- validate_start_page(params[:start_page] || params["start_page"]),
         {:ok, max_pages} <- validate_max_pages(params[:max_pages] || params["max_pages"]),
         {:ok, database} <- validate_database(params[:database] || params["database"]) do
      {:ok,
       %{
         start_page: start_page,
         max_pages: max_pages,
         database: database
       }}
    end
  end

  @impl true
  def scrape_data(params) do
    # Delegate to existing HSE.CaseScraper
    # The scraper expects keyword list options
    opts = [
      database: params.database || @default_database
    ]

    # Scrape the specific page
    page_number = params[:page_number] || params.start_page
    CaseScraper.scrape_page(page_number, opts)
  end

  @impl true
  def process_record(case_data, _session) do
    # Delegate to existing HSE.CaseProcessor
    # Returns {:ok, processed_case} or {:error, reason}
    CaseProcessor.process_case(case_data)
  end

  @impl true
  def calculate_progress(%ScrapeSession{} = session) do
    # HSE uses page-based progress calculation
    # Progress = (current_page / max_pages) * 100
    if session.max_pages > 0 do
      current = session.current_page || 0
      current / session.max_pages * 100.0
    else
      0.0
    end
  end

  @impl true
  def calculate_progress(%{current_page: current, max_pages: max}) when max > 0 do
    current / max * 100.0
  end

  @impl true
  def calculate_progress(_), do: 0.0

  @impl true
  def format_progress_display(%ScrapeSession{} = session) do
    %{
      percentage: calculate_progress(session),
      current_page: session.current_page || 0,
      total_pages: session.max_pages,
      cases_found: session.cases_found,
      cases_created: session.cases_created,
      cases_exist_total: session.cases_exist_total,
      status: session.status
    }
  end

  @impl true
  def format_progress_display(session) when is_map(session) do
    %{
      percentage: calculate_progress(session),
      current_page: Map.get(session, :current_page, 0),
      total_pages: Map.get(session, :max_pages, 0),
      cases_found: Map.get(session, :cases_found, 0),
      cases_created: Map.get(session, :cases_created, 0),
      cases_exist_total: Map.get(session, :cases_exist_total, 0),
      status: Map.get(session, :status, :idle)
    }
  end

  @impl true
  def strategy_name, do: "HSE Case Scraping"

  @impl true
  def agency_identifier, do: :hse

  @impl true
  def enforcement_type, do: :case

  # Private Helper Functions

  defp validate_start_page(nil), do: {:ok, 1}
  defp validate_start_page(page) when is_integer(page) and page > 0, do: {:ok, page}

  defp validate_start_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {int, ""} when int > 0 -> {:ok, int}
      _ -> {:error, "start_page must be a positive integer"}
    end
  end

  defp validate_start_page(_), do: {:error, "start_page must be a positive integer"}

  defp validate_max_pages(nil), do: {:ok, 10}
  defp validate_max_pages(pages) when is_integer(pages) and pages > 0, do: {:ok, pages}

  defp validate_max_pages(pages) when is_binary(pages) do
    case Integer.parse(pages) do
      {int, ""} when int > 0 -> {:ok, int}
      _ -> {:error, "max_pages must be a positive integer"}
    end
  end

  defp validate_max_pages(_), do: {:error, "max_pages must be a positive integer"}

  defp validate_database(nil), do: {:ok, @default_database}
  defp validate_database(database) when database in @valid_databases, do: {:ok, database}

  defp validate_database(database) when is_binary(database) do
    if database in @valid_databases do
      {:ok, database}
    else
      {:error, "database must be one of: #{Enum.join(@valid_databases, ", ")}"}
    end
  end

  defp validate_database(_), do: {:error, "database must be a valid string"}
end
