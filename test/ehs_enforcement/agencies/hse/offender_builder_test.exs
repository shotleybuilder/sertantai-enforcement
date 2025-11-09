defmodule EhsEnforcement.Agencies.Hse.OffenderBuilderTest do
  # mix test test/ehs_enforcement/agencies/hse/offender_builder_test.exs
  use ExUnit.Case, async: false

  alias EhsEnforcement.Agencies.Hse.OffenderBuilder
  alias EhsEnforcement.Scraping.Hse.CaseScraper.ScrapedCase

  describe "build_offender_attrs/2 with :case" do
    test "builds basic offender attributes from case data" do
      scraped_case = %ScrapedCase{
        offender_name: "ABC Limited",
        offender_local_authority: "Sheffield",
        offender_main_activity: "43910 - ROOFING ACTIVITIES",
        offender_industry: "Construction"
      }

      attrs = OffenderBuilder.build_offender_attrs(scraped_case, :case)

      assert attrs.name == "ABC Limited"
      assert attrs.local_authority == "Sheffield"
      assert attrs.main_activity == "43910 - ROOFING ACTIVITIES"
      assert attrs.industry == "Construction"
      assert attrs.business_type == :limited_company
    end

    test "detects business type correctly" do
      test_cases = [
        {"ABC Limited", :limited_company},
        {"XYZ PLC", :plc},
        {"Smith & Jones LLP", :partnership},
        {"John Smith", :individual}
      ]

      for {name, expected_type} <- test_cases do
        scraped_case = %ScrapedCase{offender_name: name}
        attrs = OffenderBuilder.build_offender_attrs(scraped_case, :case)
        assert attrs.business_type == expected_type
      end
    end

    test "filters out nil and empty values" do
      scraped_case = %ScrapedCase{
        offender_name: "ABC Limited",
        offender_local_authority: nil,
        offender_main_activity: "",
        offender_industry: "Construction"
      }

      attrs = OffenderBuilder.build_offender_attrs(scraped_case, :case)

      refute Map.has_key?(attrs, :local_authority)
      refute Map.has_key?(attrs, :main_activity)
      assert attrs.industry == "Construction"
    end
  end

  describe "build_offender_attrs/2 with :notice" do
    test "builds offender attributes from notice data" do
      notice_data = %{
        offender_name: "XYZ PLC",
        offender_local_authority: "Manchester",
        offender_sic: "1234",
        offender_main_activity: "Manufacturing"
      }

      attrs = OffenderBuilder.build_offender_attrs(notice_data, :notice)

      assert attrs.name == "XYZ PLC"
      assert attrs.local_authority == "Manchester"
      assert attrs.sic_code == "1234"
      assert attrs.main_activity == "Manufacturing"
      assert attrs.business_type == :plc
    end
  end

  describe "match_companies_house_number/1" do
    test "skips matching for individuals" do
      attrs = %{name: "John Smith", business_type: :individual}

      result = OffenderBuilder.match_companies_house_number(attrs)
      assert {:ok, ^attrs} = result
      # Individuals should not get a company_registration_number
      refute Map.has_key?(attrs, :company_registration_number)
    end

    test "returns original attrs when company name is missing" do
      attrs = %{business_type: :limited_company}

      result = OffenderBuilder.match_companies_house_number(attrs)
      assert {:ok, ^attrs} = result
    end

    # Note: The following tests demonstrate expected behavior but require mocking
    # In production testing, you would:
    # 1. Use a mocking library like Mox to mock CompaniesHouse.search_companies/2
    # 2. Or use tagged tests that only run when COMPANIES_HOUSE_API_KEY is set
    # 3. Or create integration tests that use real API calls (careful with rate limits)

    test "handles Companies House API errors gracefully (missing API key)" do
      # When API key is not configured, should return error but not crash
      attrs = %{name: "Test Company Ltd", business_type: :limited_company}

      # With no API key configured, this should return {:error, :missing_api_key}
      result = OffenderBuilder.match_companies_house_number(attrs)

      # Should return an error, not crash
      assert {:error, _reason} = result
    end
  end

  describe "helper functions (unit tests)" do
    # These tests would require exposing private functions or using mocking
    # For now, they serve as documentation of the matching logic

    test "business type detection works correctly" do
      # Test through the public API
      test_cases = [
        {"ABC Limited", :limited_company},
        {"XYZ PLC", :plc},
        {"Smith & Jones LLP", :partnership},
        {"John Smith", :individual}
      ]

      for {name, expected_type} <- test_cases do
        scraped_case = %ScrapedCase{offender_name: name}
        attrs = OffenderBuilder.build_offender_attrs(scraped_case, :case)
        assert attrs.business_type == expected_type, "Expected #{name} to be #{expected_type}"
      end
    end
  end
end

# Testing Strategy Notes:
#
# The match_companies_house_number/1 function makes real API calls which:
# 1. Require an API key to be configured
# 2. Are subject to rate limiting
# 3. Return live data that changes over time
#
# For comprehensive testing, you should:
#
# 1. **Unit Tests** (current file):
#    - Test input validation (individuals, missing names)
#    - Test error handling (missing API key)
#    - Test attribute building logic
#
# 2. **Mock-Based Tests** (future):
#    - Use Mox to mock CompaniesHouse module
#    - Test all matching scenarios:
#      - High confidence (1 result, >=0.90 similarity, type match)
#      - Medium confidence (2-3 results)
#      - Low confidence (4+ results)
#      - No results
#      - Rate limiting
#      - API errors
#
# 3. **Integration Tests** (tagged as :integration):
#    - Only run when COMPANIES_HOUSE_API_KEY is set
#    - Test with real API calls using known companies
#    - Run manually or in CI with API key configured
#    - Be mindful of rate limits (2 req/sec)
#
# Example integration test (future):
#
#   @tag :integration
#   test "matches real company with high confidence" do
#     # Only runs if: mix test --only integration
#     # And if COMPANIES_HOUSE_API_KEY is set
#     attrs = %{name: "FORD WINDOWS LIMITED", business_type: :limited_company}
#     {:ok, enhanced} = OffenderBuilder.match_companies_house_number(attrs)
#     assert enhanced.company_registration_number == "03353423"
#   end
