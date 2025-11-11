defmodule EhsEnforcement.Scraping.Strategies.EA.CaseStrategy do
  @moduledoc """
  Strategy for scraping Environment Agency court cases and enforcement actions.

  This strategy implements the `ScrapeStrategy` behavior for EA case scraping,
  which uses date-range based scraping with action type filtering.

  ## Scraping Pattern

  EA case scraping follows a date-range pattern:
  - Scrapes cases between `date_from` and `date_to`
  - Filters by action types (`:court_case`, `:caution`)
  - Two-stage process: summary collection + detail enrichment
  - Progress is calculated based on records processed

  ## Action Types

  The EA supports multiple action types:
  - `:court_case` - Court prosecutions (default)
  - `:caution` - Formal cautions
  - `:enforcement_notice` - Enforcement notices (use NoticeStrategy instead)

  ## Example Usage

      iex> strategy = EhsEnforcement.Scraping.Strategies.EA.CaseStrategy
      iex> params = %{
      ...>   date_from: ~D[2024-01-01],
      ...>   date_to: ~D[2024-12-31],
      ...>   action_types: [:court_case]
      ...> }
      iex> {:ok, validated} = strategy.validate_params(params)
      iex> {:ok, cases} = strategy.scrape_data(validated)
  """

  @behaviour EhsEnforcement.Scraping.ScrapeStrategy

  alias EhsEnforcement.Scraping.Ea.CaseProcessor
  alias EhsEnforcement.Scraping.Ea.CaseScraper
  alias EhsEnforcement.Scraping.ScrapeSession

  @valid_action_types [:court_case, :caution]
  @default_action_types [:court_case]

  # ScrapeStrategy Behavior Implementation

  @impl true
  def validate_params(params) do
    with {:ok, date_from} <- validate_date_from(params[:date_from] || params["date_from"]),
         {:ok, date_to} <- validate_date_to(params[:date_to] || params["date_to"], date_from),
         {:ok, action_types} <-
           validate_action_types(params[:action_types] || params["action_types"]) do
      {:ok,
       %{
         date_from: date_from,
         date_to: date_to,
         action_types: action_types
       }}
    end
  end

  @impl true
  def scrape_data(params) do
    # Delegate to existing EA.CaseScraper
    # The scraper expects date_from, date_to, action_types
    CaseScraper.scrape_enforcement_actions(
      params.date_from,
      params.date_to,
      params.action_types
    )
  end

  @impl true
  def process_record(case_data, _session) do
    # Delegate to existing EA.CaseProcessor
    # Returns {:ok, processed_case} or {:error, reason}
    CaseProcessor.process_ea_case(case_data)
  end

  @impl true
  def calculate_progress(%ScrapeSession{} = session) do
    # EA uses RECORD-based progress calculation (not page-based like HSE)
    # Progress = (cases_processed / cases_found) * 100
    cases_found = session.cases_found || 0
    cases_processed = session.cases_processed || 0

    if cases_found > 0 do
      cases_processed / cases_found * 100.0
    else
      0.0
    end
  end

  @impl true
  def calculate_progress(%{cases_processed: processed, cases_found: found}) when found > 0 do
    processed / found * 100.0
  end

  @impl true
  def calculate_progress(_), do: 0.0

  @impl true
  def format_progress_display(%ScrapeSession{} = session) do
    %{
      percentage: calculate_progress(session),
      cases_found: session.cases_found,
      cases_processed: session.cases_processed,
      cases_created: session.cases_created,
      cases_exist_total: session.cases_exist_total,
      date_from: session.date_from,
      date_to: session.date_to,
      action_types: session.action_types,
      status: session.status
    }
  end

  @impl true
  def format_progress_display(session) when is_map(session) do
    %{
      percentage: calculate_progress(session),
      cases_found: Map.get(session, :cases_found, 0),
      cases_processed: Map.get(session, :cases_processed, 0),
      cases_created: Map.get(session, :cases_created, 0),
      cases_exist_total: Map.get(session, :cases_exist_total, 0),
      date_from: Map.get(session, :date_from),
      date_to: Map.get(session, :date_to),
      action_types: Map.get(session, :action_types, []),
      status: Map.get(session, :status, :idle)
    }
  end

  @impl true
  def strategy_name, do: "Environment Agency Case Scraping"

  @impl true
  def agency_identifier, do: :ea

  @impl true
  def enforcement_type, do: :case

  # Private Helper Functions

  defp validate_date_from(nil) do
    # Default to 30 days ago
    {:ok, Date.add(Date.utc_today(), -30)}
  end

  defp validate_date_from(%Date{} = date), do: {:ok, date}

  defp validate_date_from(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, parsed_date} -> {:ok, parsed_date}
      {:error, _} -> {:error, "date_from must be a valid date in YYYY-MM-DD format"}
    end
  end

  defp validate_date_from(_), do: {:error, "date_from must be a valid date"}

  defp validate_date_to(nil, date_from) do
    # Default to today, but ensure it's after date_from
    today = Date.utc_today()

    if Date.compare(today, date_from) in [:gt, :eq] do
      {:ok, today}
    else
      {:ok, date_from}
    end
  end

  defp validate_date_to(%Date{} = date, date_from) do
    if Date.compare(date, date_from) in [:gt, :eq] do
      {:ok, date}
    else
      {:error, "date_to must be on or after date_from"}
    end
  end

  defp validate_date_to(date, date_from) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, parsed_date} -> validate_date_to(parsed_date, date_from)
      {:error, _} -> {:error, "date_to must be a valid date in YYYY-MM-DD format"}
    end
  end

  defp validate_date_to(_, _), do: {:error, "date_to must be a valid date"}

  defp validate_action_types(nil), do: {:ok, @default_action_types}
  defp validate_action_types([]), do: {:ok, @default_action_types}

  defp validate_action_types(types) when is_list(types) do
    invalid_types = Enum.reject(types, &(&1 in @valid_action_types))

    if Enum.empty?(invalid_types) do
      {:ok, types}
    else
      {:error,
       "Invalid action types: #{inspect(invalid_types)}. Valid types: #{inspect(@valid_action_types)}"}
    end
  end

  defp validate_action_types(type) when is_atom(type) do
    validate_action_types([type])
  end

  defp validate_action_types(type) when is_binary(type) do
    try do
      atom_type = String.to_existing_atom(type)
      validate_action_types([atom_type])
    rescue
      ArgumentError -> {:error, "Unknown action type: #{type}"}
    end
  end

  defp validate_action_types(_), do: {:error, "action_types must be a list of valid action types"}
end
