defmodule EhsEnforcement.Agencies.Ea.OffenderMatcherTest do
  @moduledoc """
  Comprehensive tests for EA OffenderMatcher module.

  Tests edge cases and missing data scenarios that occur in real-world EA data,
  ensuring graceful degradation when data is incomplete or malformed.

  **Critical Bug**: This test suite was created after a production crash caused by
  nil address data in EA notices. The `extract_postcode/1` function was calling
  `Regex.run/3` with nil, causing FunctionClauseError.
  """

  use EhsEnforcementWeb.ConnCase

  alias EhsEnforcement.Agencies.Ea.OffenderMatcher

  describe "find_or_create_offender/1 with complete data" do
    setup do
      # Create EA agency
      {:ok, _ea_agency} =
        Ash.create(EhsEnforcement.Enforcement.Agency, %{
          code: :ea,
          name: "Environment Agency",
          base_url: "https://environment.data.gov.uk",
          enabled: true
        })

      :ok
    end

    test "creates offender with all fields present" do
      ea_case_data = %{
        offender_name: "Complete Company Ltd",
        offender_address: "123 High Street, London, SW1A 1AA",
        company_registration_number: "12345678",
        industry_sector: "Manufacturing"
      }

      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(ea_case_data)
      assert offender.name =~ "Complete Company"
      assert offender.postcode == "SW1A1AA"
      assert offender.company_registration_number == "12345678"
    end

    test "creates offender with normalized company name" do
      ea_case_data = %{
        offender_name: "TEST   COMPANY    LIMITED",
        offender_address: "123 Test St, TE1 1ST"
      }

      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(ea_case_data)
      # Should normalize: collapse spaces, standardize LIMITED -> LTD, COMPANY -> CO
      assert offender.name =~ "TEST"
    end
  end

  describe "find_or_create_offender/1 with missing address data (REGRESSION TEST)" do
    setup do
      # Create EA agency
      {:ok, _ea_agency} =
        Ash.create(EhsEnforcement.Enforcement.Agency, %{
          code: :ea,
          name: "Environment Agency",
          base_url: "https://environment.data.gov.uk",
          enabled: true
        })

      :ok
    end

    test "handles nil address gracefully WITHOUT CRASHING" do
      # This is the EXACT pattern that caused production crash
      ea_case_data = %{
        offender_name: "No Address Company Ltd",
        offender_address: nil,
        company_registration_number: "87654321"
      }

      # Should not crash - should create offender with nil postcode
      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(ea_case_data)
      assert offender.name =~ "No Address Company"
      assert offender.postcode == nil
      assert offender.company_registration_number == "87654321"
    end

    test "handles empty string address gracefully" do
      ea_case_data = %{
        offender_name: "Empty Address Company Ltd",
        offender_address: "",
        company_registration_number: nil
      }

      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(ea_case_data)
      assert offender.name =~ "Empty Address Company"
      # Empty string should result in nil postcode (no match)
      assert offender.postcode == nil
    end

    test "handles whitespace-only address gracefully" do
      ea_case_data = %{
        offender_name: "Whitespace Address Company Ltd",
        offender_address: "   \t\n   "
      }

      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(ea_case_data)
      assert offender.name =~ "Whitespace Address Company"
      assert offender.postcode == nil
    end

    test "handles address without postcode" do
      ea_case_data = %{
        offender_name: "No Postcode Company Ltd",
        offender_address: "123 High Street, London"
      }

      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(ea_case_data)
      assert offender.name =~ "No Postcode Company"
      # Address present but no postcode pattern found
      assert offender.postcode == nil
    end
  end

  describe "find_or_create_offender/1 with valid UK postcodes" do
    setup do
      {:ok, _ea_agency} =
        Ash.create(EhsEnforcement.Enforcement.Agency, %{
          code: :ea,
          name: "Environment Agency",
          base_url: "https://environment.data.gov.uk",
          enabled: true
        })

      :ok
    end

    test "extracts and normalizes various valid UK postcode formats" do
      test_cases = [
        {"SW1A 1AA", "SW1A1AA"},
        {"M1 1AA", "M11AA"},
        {"B33 8TH", "B338TH"},
        {"CR2 6XH", "CR26XH"},
        {"DN55 1PT", "DN551PT"},
        {"W1A 0AX", "W1A0AX"},
        {"EC1A 1BB", "EC1A1BB"}
      ]

      for {address_postcode, expected_normalized} <- test_cases do
        ea_case_data = %{
          offender_name: "Test Company #{address_postcode}",
          offender_address: "123 Street, Town, #{address_postcode}"
        }

        assert {:ok, offender} = OffenderMatcher.find_or_create_offender(ea_case_data)

        assert offender.postcode == expected_normalized,
               "Expected postcode #{expected_normalized} but got #{offender.postcode} for input #{address_postcode}"
      end
    end
  end

  describe "find_or_create_offender/1 real-world EA notice pattern (CRASH REGRESSION)" do
    setup do
      {:ok, _ea_agency} =
        Ash.create(EhsEnforcement.Enforcement.Agency, %{
          code: :ea,
          name: "Environment Agency",
          base_url: "https://environment.data.gov.uk",
          enabled: true
        })

      :ok
    end

    test "handles EA enforcement notice data with nil address (production crash scenario)" do
      # This is the EXACT pattern from production that caused FunctionClauseError
      # Error: Regex.run(~r/pattern/, nil, []) <- nil address caused crash
      notice_data = %{
        offender_name: "Environmental Enforcement Notice Recipient",
        offender_address: nil,
        company_registration_number: nil
      }

      # Should NOT crash - this was the actual bug
      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(notice_data)
      assert offender.name =~ "Environmental Enforcement Notice Recipient"
      assert is_nil(offender.postcode)
      assert is_nil(offender.company_registration_number)
    end

    test "batch processing with mixed data quality simulating real scraping session" do
      # Simulates an EA scraping session with varying data quality levels
      batch_data = [
        %{offender_name: "Complete Data Ltd", offender_address: "1 Street, SW1A 1AA", company_registration_number: "12345678"},
        %{offender_name: "No Address Ltd", offender_address: nil, company_registration_number: "87654321"},
        %{offender_name: "No Company Number", offender_address: "2 Street, M1 1AA", company_registration_number: nil},
        %{offender_name: "Minimal Data", offender_address: nil, company_registration_number: nil},
        %{offender_name: "Empty Address String", offender_address: ""}
      ]

      results =
        Enum.map(batch_data, fn data ->
          OffenderMatcher.find_or_create_offender(data)
        end)

      # All should succeed - none should crash
      assert Enum.all?(results, fn
               {:ok, _offender} -> true
               _ -> false
             end),
             "Expected all offender creations to succeed but some failed: #{inspect(Enum.filter(results, fn {status, _} -> status == :error end))}"

      # Verify we created 5 offenders
      created_offenders = Enum.map(results, fn {:ok, offender} -> offender end)
      assert length(created_offenders) == 5

      # Verify each has at least a name
      assert Enum.all?(created_offenders, fn offender ->
               is_binary(offender.name) and String.length(offender.name) > 0
             end)
    end
  end
end
