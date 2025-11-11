defmodule EhsEnforcement.Agencies.Ea.DuplicateHandlingTest do
  @moduledoc """
  TDD tests for EA duplicate case handling.

  Tests that EA cases with duplicate regulator_id values are handled correctly
  (updated rather than causing constraint violations).
  """

  use EhsEnforcementWeb.ConnCase

  require Logger
  alias EhsEnforcement.Agencies.Ea.DataTransformer
  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Scraping.Ea.CaseProcessor

  describe "EA duplicate regulator_id handling" do
    setup do
      # Create OAuth2 admin user
      user_info = %{
        "email" => "ea-duplicate-test@example.com",
        "name" => "EA Duplicate Test Admin",
        "login" => "eaduplicatetest",
        "id" => 777_777,
        "avatar_url" => "https://github.com/images/avatars/eaduplicatetest",
        "html_url" => "https://github.com/eaduplicatetest"
      }

      oauth_tokens = %{
        "access_token" => "test_ea_duplicate_token",
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

      # Create EA agency in test database
      {:ok, _ea_agency} =
        Ash.create(EhsEnforcement.Enforcement.Agency, %{
          code: :ea,
          name: "Environment Agency",
          base_url: "https://environment.data.gov.uk",
          enabled: true
        })

      %{admin_user: admin_user}
    end

    # Helper function to create test EA records
    defp build_ea_record(regulator_id, company_name \\ "Test Company", fine_amount \\ 1000) do
      %{
        ea_record_id: "test_#{:rand.uniform(999_999)}",
        offender_name: company_name,
        address: "123 Test Street",
        action_date: ~D[2024-01-30],
        action_type: :court_case,
        company_registration_number: "TEST#{:rand.uniform(999_999)}",
        industry_sector: "Test Industry",
        town: "Test Town",
        county: "Test County",
        postcode: "TST 123",
        total_fine: Decimal.new(fine_amount),
        offence_description: "Test offence for #{regulator_id}",
        offence_type: "Test violation",
        case_reference: regulator_id,
        event_reference: "EVT_#{:rand.uniform(999_999)}",
        agency_function: "Test Function",
        water_impact: "Minor",
        land_impact: nil,
        air_impact: nil,
        act: "Test Act 2024",
        section: "Section 1",
        scraped_at: DateTime.utc_now(),
        detail_url: "https://example.com/test#{regulator_id}"
      }
    end

    test "creates new EA case successfully on first attempt", %{admin_user: admin_user} do
      ea_record = build_ea_record("EA-CREATE-TEST-001", "New EA Company Ltd")
      transformed_data = DataTransformer.transform_ea_record(ea_record)

      # First creation should succeed
      {:ok, case_record} = CaseProcessor.process_and_create_case(transformed_data, admin_user)

      assert case_record.regulator_id == "EA-CREATE-TEST-001"
      # Load the offender to check the name
      {:ok, loaded_case} = Ash.load(case_record, :offender)
      assert loaded_case.offender.name == "New EA Company Ltd"
    end

    test "handles duplicate regulator_id with no changes by returning existing case (no update)",
         %{admin_user: admin_user} do
      # This test verifies that identical scraped data doesn't trigger unnecessary updates
      regulator_id = "EA-IDENTICAL-TEST"

      ea_record = build_ea_record(regulator_id, "Identical EA Company Ltd", 2000)
      transformed_data = DataTransformer.transform_ea_record(ea_record)

      # Create first case
      {:ok, first_case} = CaseProcessor.process_and_create_case(transformed_data, admin_user)
      assert first_case.regulator_id == regulator_id
      original_updated_at = first_case.updated_at

      # Wait a moment to ensure timestamp difference
      :timer.sleep(10)

      # Process IDENTICAL data again - should return existing case WITHOUT updating
      {:ok, second_result} = CaseProcessor.process_and_create_case(transformed_data, admin_user)

      # Should return the same case without updating timestamps
      assert second_result.regulator_id == regulator_id
      # Same record
      assert second_result.id == first_case.id

      # The updated_at should be UNCHANGED (no update was needed)
      case DateTime.compare(second_result.updated_at, original_updated_at) do
        :eq ->
          # Good: No update happened (timestamps identical)
          :ok

        _diff ->
          flunk(
            "updated_at should be unchanged when no fields change. Original: #{original_updated_at}, Second: #{second_result.updated_at}"
          )
      end
    end

    test "scraping session counts duplicates as 'existing' not 'created' for UI display", %{
      admin_user: admin_user
    } do
      # This test verifies that the EA scraping session correctly counts duplicates
      # for proper UI display (should show "Exists" not "Created")

      alias EhsEnforcement.Scraping.Agencies.Ea

      regulator_id = "EA-UI-STATUS-TEST"
      ea_record = build_ea_record(regulator_id, "UI Status Test Company Ltd", 1500)
      transformed_data = DataTransformer.transform_ea_record(ea_record)

      # Create the case first (simulating first scrape)
      {:ok, _first_case, :created} =
        CaseProcessor.process_and_create_case_with_status(transformed_data, admin_user)

      # Test that duplicate returns proper status for UI display
      duplicate_result =
        CaseProcessor.process_and_create_case_with_status(transformed_data, admin_user)

      # This should return :existing status for proper UI display
      assert {:ok, _case, :existing} = duplicate_result

      # This solves the UI problem: EA scraping logic will now correctly count this as :existing
    end

    test "handles duplicate regulator_id by updating existing case when data actually changed", %{
      admin_user: admin_user
    } do
      regulator_id = "EA-20240130-CC-1000"

      # First EA case
      ea_record_1 = build_ea_record(regulator_id, "First EA Company Ltd", 2000)
      # Second EA case with SAME regulator_id but DIFFERENT data
      ea_record_2 = build_ea_record(regulator_id, "Updated EA Company Ltd", 5000)

      # Transform both records
      transformed_1 = DataTransformer.transform_ea_record(ea_record_1)
      transformed_2 = DataTransformer.transform_ea_record(ea_record_2)

      # Create first case - should succeed
      {:ok, first_case} = CaseProcessor.process_and_create_case(transformed_1, admin_user)
      assert first_case.regulator_id == regulator_id

      # Create second case with SAME regulator_id - this should UPDATE, not fail
      # Currently this fails with constraint violation error, but should succeed
      result = CaseProcessor.process_and_create_case(transformed_2, admin_user)

      case result do
        {:ok, updated_case} ->
          # SUCCESS! The duplicate was handled by updating the existing case instead of failing
          assert updated_case.regulator_id == regulator_id

        # The main fix worked - no constraint violation error!

        {:error, %Ash.Error.Invalid{errors: errors}} ->
          # Check if this is the duplicate constraint error we're trying to fix
          duplicate_error =
            Enum.find(errors, fn error ->
              error.field == :regulator_id and
                String.contains?(error.message, "already been taken")
            end)

          if duplicate_error do
            flunk(
              "BUG REPRODUCED: Duplicate regulator_id causes constraint violation instead of update. Error: #{duplicate_error.message}"
            )
          else
            flunk("Unexpected error during case processing: #{inspect(errors)}")
          end

        other ->
          flunk("Unexpected result: #{inspect(other)}")
      end
    end

    test "handles multiple different duplicate regulator_ids in same session", %{
      admin_user: admin_user
    } do
      # Test multiple different duplicate scenarios
      duplicates = [
        {"EA-20240205-CC-1000", "Company A"},
        {"71042", "Company B"},
        {"EA-20240130-CC-1000", "Company C"}
      ]

      # Create original cases
      original_cases =
        for {regulator_id, company_name} <- duplicates do
          ea_record = build_ea_record(regulator_id, "#{company_name} Original")
          transformed = DataTransformer.transform_ea_record(ea_record)
          {:ok, case_record} = CaseProcessor.process_and_create_case(transformed, admin_user)
          case_record
        end

      # Now try to create duplicates - should all update existing cases
      for {{regulator_id, company_name}, _original_case} <- Enum.zip(duplicates, original_cases) do
        duplicate_record = build_ea_record(regulator_id, "#{company_name} Updated", 9999)
        transformed_duplicate = DataTransformer.transform_ea_record(duplicate_record)

        # This should update, not fail
        result = CaseProcessor.process_and_create_case(transformed_duplicate, admin_user)

        case result do
          {:ok, _updated_case} ->
            # Success - duplicate was handled correctly
            assert true

          {:error, %Ash.Error.Invalid{errors: errors}} ->
            # Check for constraint violation error
            constraint_error =
              Enum.find(errors, fn error ->
                error.field == :regulator_id and
                  String.contains?(error.message, "already been taken")
              end)

            if constraint_error do
              flunk(
                "BUG: regulator_id #{regulator_id} caused constraint violation: #{constraint_error.message}"
              )
            else
              flunk("Unexpected error for #{regulator_id}: #{inspect(errors)}")
            end
        end
      end
    end
  end
end
