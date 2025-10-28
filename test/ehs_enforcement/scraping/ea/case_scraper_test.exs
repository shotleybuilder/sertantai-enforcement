defmodule EhsEnforcement.Scraping.Ea.CaseScraperTest do
  @moduledoc """
  Unit tests for EA case scraper functionality.

  Tests the two-stage EA scraping pattern:
  - Stage 1: Summary records collection
  - Stage 2: Detail records enrichment
  """

  use ExUnit.Case, async: true

  alias EhsEnforcement.Scraping.Ea.CaseScraper
  alias EhsEnforcement.Scraping.Ea.CaseScraper.{EaSummaryRecord, EaDetailRecord}

  describe "EA case scraper functions" do
    test "collect_summary_records_for_action_type/4 has correct arity" do
      assert function_exported?(CaseScraper, :collect_summary_records_for_action_type, 4)
    end

    test "fetch_detail_record_individual/2 has correct arity" do
      assert function_exported?(CaseScraper, :fetch_detail_record_individual, 2)
    end

    test "collect_summary_records_for_action_type/4 accepts correct parameters" do
      date_from = ~D[2025-08-01]
      date_to = ~D[2025-08-02]
      action_type = :court_case
      opts = [timeout_ms: 30_000]

      # Should not crash with parameter errors (will fail with HTTP errors)
      result =
        CaseScraper.collect_summary_records_for_action_type(date_from, date_to, action_type, opts)

      # Should return {:ok, list} or {:error, reason} - not crash
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "fetch_detail_record_individual/2 accepts correct parameters" do
      summary_record = %EaSummaryRecord{
        ea_record_id: "test123",
        offender_name: "Test Company",
        action_date: ~D[2025-08-01],
        action_type: :court_case,
        detail_url: "https://example.com/test",
        scraped_at: DateTime.utc_now()
      }

      opts = [detail_delay_ms: 1000, timeout_ms: 30_000]

      # Should not crash with parameter errors (will fail with HTTP errors)
      result = CaseScraper.fetch_detail_record_individual(summary_record, opts)

      # Should return {:ok, detail} or {:error, reason} - not crash
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "EA scraper data structures" do
    test "EaSummaryRecord struct has required fields" do
      record = %EaSummaryRecord{
        ea_record_id: "test123",
        offender_name: "Test Company",
        action_date: ~D[2025-08-01],
        action_type: :court_case,
        detail_url: "https://example.com/test",
        scraped_at: DateTime.utc_now()
      }

      assert record.ea_record_id == "test123"
      assert record.offender_name == "Test Company"
      assert record.action_type == :court_case
    end

    test "EaDetailRecord struct has required fields" do
      record = %EaDetailRecord{
        ea_record_id: "test123",
        offender_name: "Test Company",
        action_date: ~D[2025-08-01],
        action_type: :court_case,
        total_fine: Decimal.new(5000),
        scraped_at: DateTime.utc_now()
      }

      assert record.ea_record_id == "test123"
      assert record.total_fine == Decimal.new(5000)
    end
  end
end
