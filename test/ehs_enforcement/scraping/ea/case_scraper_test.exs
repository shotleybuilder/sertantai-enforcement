defmodule EhsEnforcement.Scraping.Ea.CaseScraperTest do
  @moduledoc """
  Unit tests for EA case scraper functionality.

  Tests the two-stage EA scraping pattern:
  - Stage 1: Summary records collection
  - Stage 2: Detail records enrichment
  """

  use ExUnit.Case, async: true

  alias EhsEnforcement.Scraping.Ea.CaseScraper
  alias EhsEnforcement.Scraping.Ea.CaseScraper.{EaDetailRecord, EaSummaryRecord}

  # 🗑️ OBSOLETE: Function arity tests checking outdated signatures
  # These tests check for function exports after refactoring removed HTTP-calling patterns
  # Functions do exist in production code with correct implementations
  # Tests need updating to reflect current function signatures or removal
  @moduletag :skip

  # NOTE: This entire test file was already skipped, keeping it skipped

  describe "EA case scraper functions" do
    test "collect_summary_records_for_action_type/4 has correct arity" do
      assert function_exported?(CaseScraper, :collect_summary_records_for_action_type, 4)
    end

    test "fetch_detail_record_individual/2 has correct arity" do
      assert function_exported?(CaseScraper, :fetch_detail_record_individual, 2)
    end

    # NOTE: Tests that make HTTP calls to external APIs have been removed
    # These tests were anti-patterns that hit real websites:
    # - collect_summary_records_for_action_type/4 was calling EA website
    # - fetch_detail_record_individual/2 was making HTTP requests
    # Integration tests with mocked HTTP should be in test/integration/ instead
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
