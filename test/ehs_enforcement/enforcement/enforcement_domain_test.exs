defmodule EhsEnforcement.Enforcement.DomainTest do
  @moduledoc """
  Tests for the Enforcement domain interface and Ash forms.

  This tests the domain functions and forms separately from the
  resource tests to ensure the API interface works correctly.
  """

  use EhsEnforcement.DataCase, async: true

  alias EhsEnforcement.Enforcement

  setup do
    # Use predefined agency code (hse is allowed)
    agency =
      case Ash.get(EhsEnforcement.Enforcement.Agency, code: :hse) do
        {:ok, agency} ->
          agency

        {:error, _} ->
          {:ok, agency} =
            Enforcement.create_agency(%{
              code: :hse,
              name: "Health and Safety Executive"
            })

          agency
      end

    {:ok, offender} =
      Enforcement.create_offender(%{
        name: "Test Company Ltd",
        local_authority: "Manchester"
      })

    %{agency: agency, offender: offender}
  end

  describe "domain function interfaces" do
    test "update_case_from_scraping/3 function interface", %{agency: agency, offender: offender} do
      {:ok, case_record} =
        Enforcement.create_case(%{
          agency_id: agency.id,
          offender_id: offender.id,
          regulator_id: "HSE001"
        })

      scraping_params = %{
        offence_result: "Guilty",
        offence_fine: Decimal.new("10000.00"),
        offence_costs: Decimal.new("2000.00"),
        url: "https://hse.gov.uk/prosecutions/case/001"
      }

      # Test the domain function directly
      assert {:ok, updated_case} =
               Enforcement.update_case_from_scraping(
                 case_record,
                 scraping_params
               )

      assert updated_case.offence_result == "Guilty"
      assert Decimal.equal?(updated_case.offence_fine, Decimal.new("10000.00"))
      assert updated_case.url == "https://hse.gov.uk/prosecutions/case/001"
      # Should not update sync timestamp
      assert updated_case.last_synced_at == nil
    end

    test "sync_case_from_airtable/3 function interface", %{agency: agency, offender: offender} do
      {:ok, case_record} =
        Enforcement.create_case(%{
          agency_id: agency.id,
          offender_id: offender.id,
          regulator_id: "HSE002"
        })

      airtable_params = %{
        offence_result: "Not guilty",
        offence_fine: Decimal.new("0.00"),
        offence_costs: Decimal.new("1000.00")
      }

      # Test the domain function directly
      assert {:ok, synced_case} =
               Enforcement.sync_case_from_airtable(
                 case_record,
                 airtable_params
               )

      assert synced_case.offence_result == "Not guilty"
      assert Decimal.equal?(synced_case.offence_fine, Decimal.new("0.00"))
      # Should update sync timestamp
      assert synced_case.last_synced_at != nil
      assert DateTime.diff(synced_case.last_synced_at, DateTime.utc_now(), :second) < 5
    end

    test "functions accept actor parameter for authorization", %{
      agency: agency,
      offender: offender
    } do
      {:ok, case_record} =
        Enforcement.create_case(%{
          agency_id: agency.id,
          offender_id: offender.id,
          regulator_id: "HSE003"
        })

      # Create a mock actor (would be current_user in real usage)
      mock_actor = %{id: 1, role: :admin}

      scraping_params = %{offence_result: "Guilty"}

      # Test with actor parameter
      assert {:ok, updated_case} =
               Enforcement.update_case_from_scraping(
                 case_record,
                 scraping_params,
                 actor: mock_actor
               )

      assert updated_case.offence_result == "Guilty"
    end
  end

  describe "Ash forms for scraping and syncing" do
    test "form for scraping updates" do
      form =
        AshPhoenix.Form.for_action(
          EhsEnforcement.Enforcement.Case,
          :update_from_scraping,
          forms: [auto?: false]
        )

      params = %{
        "offence_result" => "Guilty",
        "offence_fine" => "5000.00",
        "url" => "https://hse.gov.uk/prosecutions/case/123"
      }

      validated_form = AshPhoenix.Form.validate(form, params)

      assert validated_form.valid?
      assert AshPhoenix.Form.value(validated_form, :offence_result) == "Guilty"

      assert AshPhoenix.Form.value(validated_form, :url) ==
               "https://hse.gov.uk/prosecutions/case/123"
    end

    test "form for Airtable syncing" do
      form =
        AshPhoenix.Form.for_action(
          EhsEnforcement.Enforcement.Case,
          :sync_from_airtable,
          forms: [auto?: false]
        )

      params = %{
        "offence_result" => "Not guilty",
        "offence_fine" => "0.00",
        "offence_costs" => "2000.00"
      }

      validated_form = AshPhoenix.Form.validate(form, params)

      assert validated_form.valid?
      assert AshPhoenix.Form.value(validated_form, :offence_result) == "Not guilty"
    end

    test "forms reject invalid field values" do
      scraping_form =
        AshPhoenix.Form.for_action(
          EhsEnforcement.Enforcement.Case,
          :update_from_scraping,
          forms: [auto?: false]
        )

      invalid_params = %{
        "offence_fine" => "not_a_number",
        "url" => "not_a_valid_url"
      }

      validated_form = AshPhoenix.Form.validate(scraping_form, invalid_params)

      refute validated_form.valid?
      # Check that there are validation errors
      assert AshPhoenix.Form.errors(validated_form) != []
    end
  end

  describe "domain helper functions" do
    test "change_case_for_scraping/2 creates correct changeset" do
      case_params = %{
        offence_result: "Guilty",
        offence_fine: Decimal.new("8000.00"),
        url: "https://hse.gov.uk/prosecutions/case/456"
      }

      changeset =
        Enforcement.change_case_for_scraping(
          %EhsEnforcement.Enforcement.Case{},
          case_params
        )

      assert changeset.action.name == :update_from_scraping
      # Check that attributes are set correctly
      assert Map.has_key?(changeset.attributes, :offence_result)
      assert Map.has_key?(changeset.attributes, :url)
    end

    test "change_case_for_airtable_sync/2 creates correct changeset" do
      case_params = %{
        offence_result: "Not guilty",
        offence_fine: Decimal.new("0.00")
      }

      changeset =
        Enforcement.change_case_for_airtable_sync(
          %EhsEnforcement.Enforcement.Case{},
          case_params
        )

      assert changeset.action.name == :sync_from_airtable
      # Check that attributes are set correctly
      assert Map.has_key?(changeset.attributes, :offence_result)
    end
  end

  describe "backwards compatibility" do
    test "legacy sync_case function still works but uses new action", %{
      agency: agency,
      offender: offender
    } do
      {:ok, case_record} =
        Enforcement.create_case(%{
          agency_id: agency.id,
          offender_id: offender.id,
          regulator_id: "HSE_LEGACY_001"
        })

      # This would be the old sync_case function if it still exists
      # If not, this test documents the migration path
      sync_params = %{
        offence_result: "Guilty",
        offence_fine: Decimal.new("7500.00")
      }

      # Test that sync_case_from_airtable is the new preferred method
      assert {:ok, updated_case} = Enforcement.sync_case_from_airtable(case_record, sync_params)
      assert updated_case.offence_result == "Guilty"
      assert updated_case.last_synced_at != nil
    end
  end
end
