defmodule EhsEnforcement.Scraping.Ea.IntegrationTest do
  @moduledoc """
  Integration tests for EA case scraping that actually test the execution paths.

  These tests ensure that the EA scraping functions are called correctly and
  catch errors like FunctionClauseError that the validation tests miss.
  """

  use EhsEnforcementWeb.ConnCase

  require Logger
  alias EhsEnforcement.Scraping.Agencies.Ea
  alias EhsEnforcement.Scraping.Ea.CaseScraper
  alias EhsEnforcement.Enforcement.Case

  @moduletag :integration

  describe "EA scraping integration" do
    setup do
      # Create OAuth2 admin user (following test/README.md patterns)
      user_info = %{
        "email" => "ea-integration-test@example.com",
        "name" => "EA Integration Test Admin",
        "login" => "eaintegrationtest",
        "id" => 888_888,
        "avatar_url" => "https://github.com/images/avatars/eaintegrationtest",
        "html_url" => "https://github.com/eaintegrationtest"
      }

      oauth_tokens = %{
        "access_token" => "test_ea_integration_token",
        "token_type" => "Bearer"
      }

      {:ok, user} =
        Ash.create(
          EhsEnforcement.Accounts.User,
          %{
            user_info: user_info,
            oauth_tokens: oauth_tokens
          },
          action: :register_with_github
        )

      {:ok, admin_user} =
        Ash.update(
          user,
          %{
            is_admin: true,
            admin_checked_at: DateTime.utc_now()
          },
          action: :update_admin_status,
          actor: user
        )

      %{admin_user: admin_user}
    end

    test "EA CaseScraper functions are called with correct parameters", %{admin_user: admin_user} do
      # Test the actual function calls that were breaking
      date_from = ~D[2025-08-01]
      date_to = ~D[2025-08-02]
      action_type = :court_case
      opts = [timeout_ms: 30_000]

      # Test collect_summary_records_for_action_type - this was the broken function
      assert {:ok, summary_records} =
               CaseScraper.collect_summary_records_for_action_type(
                 date_from,
                 date_to,
                 action_type,
                 opts
               )

      # Should return empty list (no real EA data) but NOT crash with Keyword.get/3 error
      assert is_list(summary_records)
    end

    test "EA agency start_scraping calls CaseScraper correctly", %{admin_user: admin_user} do
      # Test the exact parameters that the agency module uses
      ea_opts = [
        date_from: ~D[2025-08-01],
        date_to: ~D[2025-08-02],
        action_types: [:court_case],
        scrape_type: :manual,
        actor: admin_user
      ]

      # This should NOT crash with FunctionClauseError
      assert {:ok, validated_params} = Ea.validate_params(ea_opts)

      # The start_scraping function should at least create a session without crashing
      # (it will fail at HTTP requests, but should not have parameter errors)
      case Ea.start_scraping(validated_params, %{}) do
        {:ok, _session} ->
          # Unexpected success - but no parameter errors
          assert true

        {:error, reason} ->
          # Expected failure due to HTTP/session creation, but should not be parameter errors
          error_msg = inspect(reason)

          refute String.contains?(error_msg, "Keyword.get/3"),
                 "Should not have Keyword.get/3 parameter error: #{error_msg}"

          refute String.contains?(error_msg, "FunctionClauseError"),
                 "Should not have FunctionClauseError: #{error_msg}"
      end
    end

    test "EA case scraping action executes without parameter errors", %{admin_user: admin_user} do
      # Test the actual Ash action that was failing in production

      # This should NOT crash with FunctionClauseError or Keyword.get/3 errors
      case Ash.create(Case, %{}, action: :scrape_ea_cases, actor: admin_user) do
        {:ok, _result} ->
          # Unexpected success - but no parameter errors
          assert true

        {:error, error} ->
          # Expected failure due to network/configuration issues, but NOT parameter errors
          error_msg = Exception.message(error)

          refute String.contains?(error_msg, "Keyword.get/3"),
                 "Should not have Keyword.get/3 parameter error: #{error_msg}"

          refute String.contains?(error_msg, "FunctionClauseError"),
                 "Should not have FunctionClauseError: #{error_msg}"

          refute String.contains?(error_msg, "no function clause matching"),
                 "Should not have function clause matching error: #{error_msg}"
      end
    end

    test "EA individual processing functions exist and have correct arity", %{
      admin_user: admin_user
    } do
      # Test that the functions we added for individual processing exist

      # Test function exists and has correct arity
      assert function_exported?(CaseScraper, :collect_summary_records_for_action_type, 4)
      assert function_exported?(CaseScraper, :fetch_detail_record_individual, 2)

      # Test they can be called with correct parameters
      summary_record = %{
        ea_record_id: "test123",
        detail_url: "https://example.com/test"
      }

      opts = [detail_delay_ms: 1000, timeout_ms: 30_000]

      # This should not crash with parameter errors (will fail with HTTP errors)
      case CaseScraper.fetch_detail_record_individual(summary_record, opts) do
        {:ok, _detail} -> assert true
        # Expected - no real URL
        {:error, _reason} -> assert true
      end
    end

    test "EA DataTransformer handles nil values without crashing", %{admin_user: admin_user} do
      alias EhsEnforcement.Agencies.Ea.DataTransformer

      # Test data with nil values that should not crash String.trim/1
      ea_record_with_nils = %{
        ea_record_id: "test123",
        # This should not crash clean_company_name/1
        offender_name: nil,
        # This should not crash normalize_address/1
        address: nil,
        action_date: ~D[2025-08-01],
        action_type: :court_case,
        company_registration_number: nil,
        industry_sector: nil,
        town: nil,
        county: nil,
        postcode: nil,
        total_fine: Decimal.new(0),
        # Required field
        offence_description: "Test offence",
        # Required field
        offence_type: "Test offence type",
        case_reference: nil,
        event_reference: nil,
        agency_function: nil,
        water_impact: nil,
        land_impact: nil,
        air_impact: nil,
        act: nil,
        section: nil,
        legal_reference: nil,
        scraped_at: DateTime.utc_now(),
        detail_url: "https://example.com/test"
      }

      # This should NOT crash with String.trim(nil) error
      transformed = DataTransformer.transform_ea_record(ea_record_with_nils)

      # Verify nil values are handled correctly (no String.trim(nil) crash)
      assert transformed[:offender_name] == nil
      assert transformed[:address] == nil
      # Should generate ID even with nil values
      assert is_binary(transformed[:regulator_id])
    end

    test "EA Case creation now works with CaseProcessor fix", %{admin_user: admin_user} do
      alias EhsEnforcement.Agencies.Ea.DataTransformer
      alias EhsEnforcement.Scraping.Ea.CaseProcessor

      # Test data that represents a real EA record that would be transformed
      ea_record = %{
        ea_record_id: "10000529",
        offender_name: "Test EA Company Ltd",
        address: "123 EA Test Street",
        action_date: ~D[2025-08-01],
        action_type: :court_case,
        company_registration_number: "12345678",
        industry_sector: "Manufacturing",
        town: "EA Town",
        county: "EA County",
        postcode: "EA1 2TE",
        total_fine: Decimal.new(5000),
        offence_description: "Environmental breach test",
        offence_type: "Water pollution",
        case_reference: "EA/CC/2025/001",
        event_reference: "EVT10000529",
        agency_function: "Regulation",
        water_impact: "Major",
        land_impact: nil,
        air_impact: nil,
        act: "Environmental Protection Act 1990",
        section: "Section 33",
        scraped_at: DateTime.utc_now(),
        detail_url:
          "https://environment.data.gov.uk/public-register/enforcement-action/registration/10000529"
      }

      # Transform the EA record using DataTransformer (this should work and return :ea)
      transformed_case_data = DataTransformer.transform_ea_record(ea_record)

      # Verify transformation worked
      assert transformed_case_data[:agency_code] == :ea
      assert transformed_case_data[:regulator_id] == "EA/CC/2025/001"

      # First create the EA agency in the test database
      {:ok, _ea_agency} =
        Ash.create(EhsEnforcement.Enforcement.Agency, %{
          code: :ea,
          name: "Environment Agency",
          base_url: "https://environment.data.gov.uk",
          enabled: true
        })

      # NOW TEST THE FIXED PRODUCTION CODE PATH - use CaseProcessor.process_and_create_case
      # This should now work because CaseProcessor uses agency_code from transformed data (:ea)
      case CaseProcessor.process_and_create_case(transformed_case_data, admin_user) do
        {:ok, case_record} ->
          # The fix worked! Case creation should succeed now
          assert case_record.regulator_id == "EA/CC/2025/001"
          # Verify the case was created with the correct agency
          case Ash.load(case_record, :agency) do
            {:ok, loaded_case} ->
              assert loaded_case.agency.code == :ea

            {:error, _} ->
              flunk("Failed to load agency for created case")
          end

        {:error, %Ash.Error.Invalid{errors: errors}} ->
          # Check what error we got - should not be agency lookup error anymore
          error_messages =
            Enum.map(errors, fn error ->
              case error do
                %{message: msg} when is_binary(msg) -> msg
                error -> inspect(error)
              end
            end)

          flunk("Case creation should succeed with fix. Got errors: #{inspect(error_messages)}")
      end
    end
  end
end
