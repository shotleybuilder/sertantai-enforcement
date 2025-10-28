defmodule EhsEnforcement.Enforcement.AgencyAutoPopulationTest do
  use EhsEnforcement.DataCase

  alias EhsEnforcement.Enforcement

  describe "agency auto-population" do
    setup do
      # Create HSE agency for testing
      {:ok, agency} =
        Enforcement.create_agency(%{
          name: "Health and Safety Executive",
          code: :hse,
          base_url: "https://www.hse.gov.uk",
          enabled: true
        })

      # Create a test offender with empty agencies
      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Test Auto Population Company",
          postcode: "AUTO123",
          industry: "Testing",
          business_type: :limited_company,
          agencies: []
        })

      %{agency: agency, offender: offender}
    end

    test "creating a case automatically updates offender agencies", %{
      agency: agency,
      offender: offender
    } do
      # Verify offender starts with empty agencies
      assert offender.agencies == []

      # Create a case for this offender
      case_attrs = %{
        agency_id: agency.id,
        offender_id: offender.id,
        regulator_id: "AUTO_TEST_001",
        offence_result: "Guilty - Fine",
        offence_fine: Decimal.new("1000"),
        offence_action_date: Date.utc_today(),
        offence_breaches: "Test breach"
      }

      {:ok, _case} = Enforcement.create_case(case_attrs)

      # Give the background process time to update (since it's spawned)
      Process.sleep(100)

      # Reload the offender and check if agencies were updated
      {:ok, updated_offender} = Enforcement.get_offender(offender.id)

      assert agency.name in updated_offender.agencies
      assert length(updated_offender.agencies) == 1
    end

    test "creating a notice automatically updates offender agencies", %{
      agency: agency,
      offender: offender
    } do
      # Verify offender starts with empty agencies
      assert offender.agencies == []

      # Create a notice for this offender
      notice_attrs = %{
        agency_id: agency.id,
        offender_id: offender.id,
        regulator_id: "AUTO_NOTICE_001",
        notice_date: Date.utc_today(),
        operative_date: Date.add(Date.utc_today(), 30),
        compliance_date: Date.add(Date.utc_today(), 60),
        notice_body: "Test notice body",
        offence_action_type: "Improvement Notice"
      }

      {:ok, _notice} = Enforcement.create_notice(notice_attrs)

      # Give the background process time to update
      Process.sleep(100)

      # Reload the offender and check if agencies were updated
      {:ok, updated_offender} = Enforcement.get_offender(offender.id)

      assert agency.name in updated_offender.agencies
      assert length(updated_offender.agencies) == 1
    end

    test "multiple enforcement actions from same agency don't duplicate", %{
      agency: agency,
      offender: offender
    } do
      # Create both a case and notice for the same agency/offender
      case_attrs = %{
        agency_id: agency.id,
        offender_id: offender.id,
        regulator_id: "DUP_TEST_CASE",
        offence_result: "Guilty - Fine",
        offence_action_date: Date.utc_today()
      }

      notice_attrs = %{
        agency_id: agency.id,
        offender_id: offender.id,
        regulator_id: "DUP_TEST_NOTICE",
        notice_date: Date.utc_today(),
        offence_action_type: "Improvement Notice"
      }

      {:ok, _case} = Enforcement.create_case(case_attrs)
      {:ok, _notice} = Enforcement.create_notice(notice_attrs)

      # Give background processes time to complete
      Process.sleep(200)

      # Check that agency appears only once
      {:ok, updated_offender} = Enforcement.get_offender(offender.id)

      agency_count = Enum.count(updated_offender.agencies, &(&1 == agency.name))
      assert agency_count == 1
      assert length(updated_offender.agencies) == 1
    end

    test "multiple agencies are properly tracked", %{offender: offender} do
      # Create ONR agency for this test (HSE already exists from setup)
      {:ok, hse_agency} = Enforcement.get_agency_by_code(:hse)

      {:ok, onr_agency} =
        Enforcement.create_agency(%{
          name: "Office for Nuclear Regulation",
          code: :onr,
          enabled: true
        })

      # Create cases for different agencies
      {:ok, _case1} =
        Enforcement.create_case(%{
          agency_id: hse_agency.id,
          offender_id: offender.id,
          regulator_id: "MULTI_001",
          offence_result: "Guilty",
          offence_action_date: Date.utc_today()
        })

      {:ok, _case2} =
        Enforcement.create_case(%{
          agency_id: onr_agency.id,
          offender_id: offender.id,
          regulator_id: "MULTI_002",
          offence_result: "Guilty",
          offence_action_date: Date.utc_today()
        })

      # Give background processes time to complete
      Process.sleep(200)

      # Check that both agencies are tracked
      {:ok, updated_offender} = Enforcement.get_offender(offender.id)

      assert hse_agency.name in updated_offender.agencies
      assert onr_agency.name in updated_offender.agencies
      assert length(updated_offender.agencies) == 2

      # Verify they're sorted alphabetically
      assert updated_offender.agencies == Enum.sort([hse_agency.name, onr_agency.name])
    end
  end
end
