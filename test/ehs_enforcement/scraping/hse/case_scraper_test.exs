defmodule EhsEnforcement.Scraping.Hse.CaseScraperTest do
  use EhsEnforcement.DataCase

  require Ash.Query
  import Ash.Expr

  alias EhsEnforcement.Scraping.Hse.CaseScraper
  alias EhsEnforcement.Scraping.Hse.CaseScraper.ScrapedCase
  alias EhsEnforcement.Enforcement

  describe "case_exists?/1" do
    test "returns false when case does not exist" do
      assert {:ok, false} = CaseScraper.case_exists?("NONEXISTENT123")
    end

    test "returns true when case exists" do
      # Create a test case using Ash
      agency = create_test_agency()
      offender = create_test_offender()

      {:ok, case_record} =
        Enforcement.create_case(%{
          agency_id: agency.id,
          offender_id: offender.id,
          regulator_id: "TEST123",
          offence_action_date: ~D[2023-01-15],
          offence_action_type: "Court Case"
        })

      assert {:ok, true} = CaseScraper.case_exists?("TEST123")
    end
  end

  describe "cases_exist?/1" do
    test "returns correct existence map for multiple regulator IDs" do
      # Create one existing case
      agency = create_test_agency()
      offender = create_test_offender()

      {:ok, _case} =
        Enforcement.create_case(%{
          agency_id: agency.id,
          offender_id: offender.id,
          regulator_id: "EXISTS123",
          offence_action_date: ~D[2023-01-15],
          offence_action_type: "Court Case"
        })

      regulator_ids = ["EXISTS123", "NOTEXISTS456", "ALSONOTEXISTS789"]

      assert {:ok, results} = CaseScraper.cases_exist?(regulator_ids)
      assert results["EXISTS123"] == true
      assert results["NOTEXISTS456"] == false
      assert results["ALSONOTEXISTS789"] == false
    end
  end

  # Note: Testing actual HTTP scraping would require mocking or VCR
  # For now, we test the core logic and Ash integration

  describe "ScrapedCase struct" do
    test "can encode to JSON" do
      scraped_case = %ScrapedCase{
        regulator_id: "TEST123",
        offender_name: "Test Company Ltd",
        offence_action_date: ~D[2023-01-15],
        page_number: 1,
        scrape_timestamp: DateTime.utc_now()
      }

      assert Jason.encode!(scraped_case)
    end
  end

  # Helper functions

  defp create_test_agency do
    {:ok, agency} =
      Enforcement.create_agency(%{
        name: "Health and Safety Executive",
        code: :hse,
        base_url: "https://hse.gov.uk"
      })

    agency
  end

  defp create_test_offender do
    {:ok, offender} =
      Enforcement.create_offender(%{
        name: "Test Company Limited"
      })

    offender
  end
end
