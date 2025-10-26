defmodule EhsEnforcement.Scraping.Strategies.EA.NoticeStrategy do
  @moduledoc """
  Strategy for scraping Environment Agency enforcement notices.

  This strategy implements the `ScrapeStrategy` behavior for EA notice scraping,
  which uses date-range based scraping filtered to enforcement notice action types only.

  ## Scraping Pattern

  EA notice scraping follows a date-range pattern:
  - Scrapes notices between `date_from` and `date_to`
  - Filters to `:enforcement_notice` action type only
  - Two-stage process: summary collection + detail enrichment
  - Progress is calculated based on records processed

  ## Progress Tracking Fix

  **This strategy fixes the EA Notice progress tracking bug**:
  - Previous implementation: Progress stuck at 0%
  - Root cause: Improper progress calculation in LiveView
  - Solution: Record-based progress tracking (notices_processed / notices_found * 100)
  - Consistent with EA Case scraping pattern

  ## Example Usage

      iex> strategy = EhsEnforcement.Scraping.Strategies.EA.NoticeStrategy
      iex> params = %{
      ...>   date_from: ~D[2024-01-01],
      ...>   date_to: ~D[2024-12-31]
      ...> }
      iex> {:ok, validated} = strategy.validate_params(params)
      iex> {:ok, notices} = strategy.scrape_data(validated)
  """

  @behaviour EhsEnforcement.Scraping.ScrapeStrategy

  alias EhsEnforcement.Scraping.Ea.CaseScraper
  alias EhsEnforcement.Scraping.Ea.NoticeProcessor
  alias EhsEnforcement.Scraping.ScrapeSession

  @enforcement_notice_action_type [:enforcement_notice]

  # ScrapeStrategy Behavior Implementation

  @impl true
  def validate_params(params) do
    with {:ok, date_from} <- validate_date_from(params[:date_from] || params["date_from"]),
         {:ok, date_to} <- validate_date_to(params[:date_to] || params["date_to"], date_from) do
      {:ok,
       %{
         date_from: date_from,
         date_to: date_to,
         action_types: @enforcement_notice_action_type
       }}
    end
  end

  @impl true
  def scrape_data(params) do
    # Delegate to EA.CaseScraper with enforcement_notice action type
    # EA notice scraping reuses the case scraper infrastructure
    CaseScraper.scrape_enforcement_actions(
      params.date_from,
      params.date_to,
      @enforcement_notice_action_type
    )
  end

  @impl true
  def process_record(notice_data, _session) do
    # Delegate to existing EA.NoticeProcessor
    # Returns {:ok, processed_notice} or {:error, reason}
    NoticeProcessor.process_notice(notice_data)
  end

  @impl true
  def calculate_progress(%ScrapeSession{} = session) do
    # EA uses RECORD-based progress calculation (not page-based like HSE)
    # Progress = (notices_processed / notices_found) * 100
    # Note: Session uses "cases_*" fields for both cases and notices (legacy naming)
    if session.cases_found > 0 do
      (session.cases_processed / session.cases_found) * 100.0
    else
      0.0
    end
  end

  @impl true
  def calculate_progress(%{cases_processed: processed, cases_found: found}) when found > 0 do
    # Map generic "cases_*" fields to notices for progress calculation
    (processed / found) * 100.0
  end

  @impl true
  def calculate_progress(_), do: 0.0

  @impl true
  def format_progress_display(%ScrapeSession{} = session) do
    # Note: ScrapeSession uses "cases_*" fields for both cases and notices
    # We map them to "notices_*" for UI display clarity
    %{
      percentage: calculate_progress(session),
      notices_found: session.cases_found,
      notices_processed: session.cases_processed,
      notices_created: session.cases_created,
      notices_exist_total: session.cases_exist_total,
      date_from: session.date_from,
      date_to: session.date_to,
      action_types: session.action_types || @enforcement_notice_action_type,
      status: session.status
    }
  end

  @impl true
  def format_progress_display(session) when is_map(session) do
    %{
      percentage: calculate_progress(session),
      notices_found: Map.get(session, :cases_found, 0),
      notices_processed: Map.get(session, :cases_processed, 0),
      notices_created: Map.get(session, :cases_created, 0),
      notices_exist_total: Map.get(session, :cases_exist_total, 0),
      date_from: Map.get(session, :date_from),
      date_to: Map.get(session, :date_to),
      action_types: Map.get(session, :action_types, @enforcement_notice_action_type),
      status: Map.get(session, :status, :idle)
    }
  end

  @impl true
  def strategy_name, do: "Environment Agency Notice Scraping"

  @impl true
  def agency_identifier, do: :environment_agency

  @impl true
  def enforcement_type, do: :notice

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
end
