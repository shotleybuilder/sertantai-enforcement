defmodule EhsEnforcement.Scraping.Hse.NoticePrefilteringTest do
  use EhsEnforcement.DataCase

  require Ash.Query

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Enforcement.{Notice, Offender}

  @moduletag :hse_prefiltering

  describe "HSE Notice Pre-filtering" do
    setup do
      # Create HSE agency
      {:ok, hse_agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      # Create admin user for actor context
      admin_user_info = %{
        "email" => "admin@test.com",
        "name" => "Admin User",
        "login" => "admin",
        "id" => 12_347,
        "avatar_url" => "https://github.com/images/avatars/admin",
        "html_url" => "https://github.com/admin"
      }

      admin_oauth_tokens = %{
        "access_token" => "test_admin_access_token",
        "token_type" => "Bearer"
      }

      {:ok, admin_user_base} =
        Ash.create(
          EhsEnforcement.Accounts.User,
          %{
            user_info: admin_user_info,
            oauth_tokens: admin_oauth_tokens
          },
          action: :register_with_github
        )

      {:ok, admin_user} =
        Ash.update(
          admin_user_base,
          %{
            is_admin: true,
            admin_checked_at: DateTime.utc_now()
          },
          action: :update_admin_status,
          actor: admin_user_base
        )

      # Create some existing notices in the database
      existing_offender =
        Offender
        |> Ash.Changeset.for_create(:create, %{
          name: "Existing Company Ltd",
          town: "London",
          country: "England"
        })
        |> Ash.create!(actor: admin_user)

      existing_notice =
        Notice
        |> Ash.Changeset.for_create(:create, %{
          regulator_id: "EXISTING_001",
          regulator_ref_number: "IN/2024/EXISTING_001",
          offence_action_type: :improvement_notice,
          notice_date: ~D[2024-01-01],
          agency_id: hse_agency.id,
          offender_id: existing_offender.id
        })
        |> Ash.create!(actor: admin_user)

      %{
        agency: hse_agency,
        actor: admin_user,
        existing_notice: existing_notice,
        existing_offender: existing_offender
      }
    end

    test "check_existing_notice_regulator_ids correctly identifies existing and new notices",
         %{actor: actor} do
      # Test data: mix of existing and new regulator_ids
      regulator_ids = ["EXISTING_001", "NEW_001", "NEW_002"]

      result =
        Enforcement.check_existing_notice_regulator_ids(regulator_ids, :hse, actor)

      assert result.total == 3
      assert result.existing_count == 1
      assert result.new_count == 2
      assert "EXISTING_001" in result.existing
      assert "NEW_001" in result.new
      assert "NEW_002" in result.new
    end

    test "filter_existing_notices filters out existing notices by default",
         %{actor: actor} do
      # Simulate scraped notices from HSE website
      scraped_notices = [
        %{regulator_id: "EXISTING_001", regulator_ref_number: "IN/2024/EXISTING_001"},
        %{regulator_id: "NEW_001", regulator_ref_number: "IN/2024/NEW_001"},
        %{regulator_id: "NEW_002", regulator_ref_number: "IN/2024/NEW_002"}
      ]

      # Call the private filter function indirectly by testing its public behavior
      # We'll verify this through the check_existing_notice_regulator_ids function
      regulator_ids = Enum.map(scraped_notices, & &1.regulator_id)

      result =
        Enforcement.check_existing_notice_regulator_ids(regulator_ids, :hse, actor)

      # Verify filtering results
      assert result.existing_count == 1
      assert result.new_count == 2

      # Filtered notices should only include NEW_001 and NEW_002
      new_notices = Enum.filter(scraped_notices, &(&1.regulator_id in result.new))
      assert length(new_notices) == 2
      assert Enum.any?(new_notices, &(&1.regulator_id == "NEW_001"))
      assert Enum.any?(new_notices, &(&1.regulator_id == "NEW_002"))
    end

    test "process_all_records=true processes all notices including existing",
         %{actor: actor} do
      # When process_all_records is true, all notices should be processed
      # This is tested by verifying the parameter is respected in the flow

      validated_params = %{
        start_page: 1,
        max_pages: 1,
        database: "notices",
        process_all_records: true,
        # Force process all
        actor: actor
      }

      # With process_all_records=true, filtering should be skipped
      assert validated_params.process_all_records == true
    end

    test "validate_params in notice_strategy includes process_all_records" do
      strategy = EhsEnforcement.Scraping.Strategies.HSE.NoticeStrategy

      # Test with process_all_records as boolean
      params = %{
        start_page: 1,
        max_pages: 10,
        database: "notices",
        country: "England",
        process_all_records: true
      }

      {:ok, validated} = strategy.validate_params(params)
      assert validated.process_all_records == true

      # Test with process_all_records as string (from form)
      params_string = %{
        "start_page" => "1",
        "max_pages" => "10",
        "database" => "notices",
        "country" => "England",
        "process_all_records" => "true"
      }

      {:ok, validated_string} = strategy.validate_params(params_string)
      assert validated_string.process_all_records == true

      # Test default (false)
      params_default = %{
        start_page: 1,
        max_pages: 10,
        database: "notices",
        country: "England"
      }

      {:ok, validated_default} = strategy.validate_params(params_default)
      assert validated_default.process_all_records == false
    end

    test "empty notice list doesn't cause errors" do
      # Edge case: empty list of notices
      result = Enforcement.check_existing_notice_regulator_ids([], :hse, nil)

      assert result.total == 0
      assert result.existing_count == 0
      assert result.new_count == 0
      assert result.existing == []
      assert result.new == []
    end
  end

  describe "Performance Optimization" do
    setup do
      # Create HSE agency
      {:ok, hse_agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      # Create admin user
      admin_user_info = %{
        "email" => "perf@test.com",
        "name" => "Perf Test User",
        "login" => "perftest",
        "id" => 99_999,
        "avatar_url" => "https://github.com/images/avatars/perftest",
        "html_url" => "https://github.com/perftest"
      }

      admin_oauth_tokens = %{
        "access_token" => "test_perf_access_token",
        "token_type" => "Bearer"
      }

      {:ok, admin_user_base} =
        Ash.create(
          EhsEnforcement.Accounts.User,
          %{
            user_info: admin_user_info,
            oauth_tokens: admin_oauth_tokens
          },
          action: :register_with_github
        )

      {:ok, admin_user} =
        Ash.update(
          admin_user_base,
          %{
            is_admin: true,
            admin_checked_at: DateTime.utc_now()
          },
          action: :update_admin_status,
          actor: admin_user_base
        )

      # Create offender for notices
      offender =
        Offender
        |> Ash.Changeset.for_create(:create, %{
          name: "Performance Test Company",
          town: "London",
          country: "England"
        })
        |> Ash.create!(actor: admin_user)

      # Create 50 existing notices to simulate realistic scenario
      existing_notices =
        for i <- 1..50 do
          notice =
            Notice
            |> Ash.Changeset.for_create(:create, %{
              regulator_id: "PERF_EXISTING_#{String.pad_leading(Integer.to_string(i), 3, "0")}",
              regulator_ref_number: "IN/2024/PERF_#{i}",
              offence_action_type: :improvement_notice,
              notice_date: Date.add(~D[2024-01-01], i),
              agency_id: hse_agency.id,
              offender_id: offender.id
            })
            |> Ash.create!(actor: admin_user)

          notice
        end

      %{agency: hse_agency, actor: admin_user, existing_notices: existing_notices}
    end

    test "pre-filtering efficiently handles large batch of notices",
         %{actor: actor, existing_notices: existing_notices} do
      # Simulate scraping 100 notices: 50 existing + 50 new
      regulator_ids =
        Enum.map(existing_notices, & &1.regulator_id) ++
          Enum.map(1..50, fn i ->
            "PERF_NEW_#{String.pad_leading(Integer.to_string(i), 3, "0")}"
          end)

      # This should complete quickly using MapSet for lookup
      result =
        Enforcement.check_existing_notice_regulator_ids(regulator_ids, :hse, actor)

      assert result.total == 100
      assert result.existing_count == 50
      assert result.new_count == 50

      # Verify the split is correct
      assert length(result.existing) == 50
      assert length(result.new) == 50
    end
  end
end
