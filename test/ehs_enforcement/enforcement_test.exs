defmodule EhsEnforcement.EnforcementTest do
  use EhsEnforcement.DataCase

  alias EhsEnforcement.Enforcement

  describe "domain interface" do
    test "has all required resources defined" do
      # Test that the domain module exists and has resources
      assert Code.ensure_loaded?(EhsEnforcement.Enforcement)

      # Verify domain has the expected resources via Ash.Domain.Info
      resources = Ash.Domain.Info.resources(EhsEnforcement.Enforcement)

      expected_resources = [
        EhsEnforcement.Enforcement.Agency,
        EhsEnforcement.Enforcement.Offender,
        EhsEnforcement.Enforcement.Case,
        EhsEnforcement.Enforcement.Notice,
        EhsEnforcement.Enforcement.Breach
      ]

      Enum.each(expected_resources, fn resource ->
        assert resource in resources, "#{resource} not found in domain resources"
      end)
    end

    test "registry includes all enforcement resources" do
      # Test that all resources are properly registered
      registry_entries = EhsEnforcement.Registry.entries()

      expected_resources = [
        EhsEnforcement.Enforcement.Agency,
        EhsEnforcement.Enforcement.Offender,
        EhsEnforcement.Enforcement.Case,
        EhsEnforcement.Enforcement.Notice,
        EhsEnforcement.Enforcement.Breach
      ]

      Enum.each(expected_resources, fn resource ->
        assert Enum.any?(registry_entries, fn {reg_resource, _config} ->
                 reg_resource == resource
               end),
               "#{resource} not registered"
      end)
    end

    test "can perform basic CRUD operations through domain" do
      # Test basic agency operations
      agency_attrs = %{code: :hse, name: "Health and Safety Executive"}
      assert {:ok, agency} = Enforcement.create_agency(agency_attrs)
      assert {:ok, fetched_agency} = Enforcement.get_agency!(agency.id)
      assert fetched_agency.id == agency.id
      assert fetched_agency.code == agency.code

      agencies = Enforcement.list_agencies!()
      assert Enum.any?(agencies, &(&1.id == agency.id))

      # Test offender operations
      offender_attrs = %{name: "Test Company Ltd"}
      assert {:ok, offender} = Enforcement.create_offender(offender_attrs)
      assert {:ok, fetched_offender} = Enforcement.get_offender!(offender.id)
      assert fetched_offender.id == offender.id
      # normalized
      assert fetched_offender.name == "test company limited"

      # Test case operations with direct IDs
      case_attrs = %{
        agency_id: agency.id,
        offender_id: offender.id,
        regulator_id: "HSE001"
      }

      assert {:ok, case_record} = Enforcement.create_case(case_attrs)

      assert {:ok, case_with_relations} =
               Enforcement.get_case!(
                 case_record.id,
                 load: [:agency, :offender]
               )

      assert case_with_relations.agency.id == agency.id
      assert case_with_relations.offender.id == offender.id
    end
  end

  describe "check_existing_notice_regulator_ids/3 - pre-filtering for EA notices" do
    setup do
      # Create EA agency
      {:ok, ea_agency} =
        Enforcement.create_agency(%{
          code: :ea,
          name: "Environment Agency",
          base_url: "https://environment.data.gov.uk",
          enabled: true
        })

      # Create test offender
      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Test Environmental Company Ltd"
        })

      %{ea_agency: ea_agency, offender: offender}
    end

    test "returns empty lists when no regulator_ids provided", %{ea_agency: _ea_agency} do
      result = Enforcement.check_existing_notice_regulator_ids([], :ea)

      assert result == %{
               existing: [],
               new: [],
               total: 0,
               existing_count: 0,
               new_count: 0
             }
    end

    test "identifies all as new when no notices exist", %{ea_agency: _ea_agency} do
      regulator_ids = ["EA-2024-001", "EA-2024-002", "EA-2024-003"]

      result = Enforcement.check_existing_notice_regulator_ids(regulator_ids, :ea)

      assert result.existing == []
      assert result.new == regulator_ids
      assert result.total == 3
      assert result.existing_count == 0
      assert result.new_count == 3
    end

    test "identifies existing vs new notices correctly", %{
      ea_agency: ea_agency,
      offender: offender
    } do
      # Create 2 existing notices
      {:ok, _notice1} =
        Enforcement.create_notice(%{
          agency_id: ea_agency.id,
          offender_id: offender.id,
          regulator_id: "EA-2024-001",
          offence_action_date: ~D[2024-01-15]
        })

      {:ok, _notice2} =
        Enforcement.create_notice(%{
          agency_id: ea_agency.id,
          offender_id: offender.id,
          regulator_id: "EA-2024-002",
          offence_action_date: ~D[2024-01-20]
        })

      # Check batch including existing and new
      regulator_ids = ["EA-2024-001", "EA-2024-002", "EA-2024-003", "EA-2024-004"]

      result = Enforcement.check_existing_notice_regulator_ids(regulator_ids, :ea)

      assert length(result.existing) == 2
      assert "EA-2024-001" in result.existing
      assert "EA-2024-002" in result.existing

      assert length(result.new) == 2
      assert "EA-2024-003" in result.new
      assert "EA-2024-004" in result.new

      assert result.total == 4
      assert result.existing_count == 2
      assert result.new_count == 2
    end

    test "handles large batch efficiently (performance test)", %{
      ea_agency: ea_agency,
      offender: offender
    } do
      # Create 100 existing notices
      existing_ids =
        Enum.map(1..100, fn i ->
          regulator_id = "EA-2024-#{String.pad_leading(Integer.to_string(i), 4, "0")}"

          {:ok, _notice} =
            Enforcement.create_notice(%{
              agency_id: ea_agency.id,
              offender_id: offender.id,
              regulator_id: regulator_id,
              offence_action_date: ~D[2024-01-01]
            })

          regulator_id
        end)

      # Add 50 new IDs
      new_ids = Enum.map(101..150, fn i -> "EA-2024-#{String.pad_leading(Integer.to_string(i), 4, "0")}" end)

      all_ids = existing_ids ++ new_ids

      # Should complete quickly with single query
      result = Enforcement.check_existing_notice_regulator_ids(all_ids, :ea)

      assert result.existing_count == 100
      assert result.new_count == 50
      assert result.total == 150
    end

    test "filters by agency code correctly", %{ea_agency: ea_agency, offender: offender} do
      # Create EA notice
      {:ok, _ea_notice} =
        Enforcement.create_notice(%{
          agency_id: ea_agency.id,
          offender_id: offender.id,
          regulator_id: "EA-2024-001",
          offence_action_date: ~D[2024-01-01]
        })

      # Create HSE agency and notice with same regulator_id
      {:ok, hse_agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, _hse_notice} =
        Enforcement.create_notice(%{
          agency_id: hse_agency.id,
          offender_id: offender.id,
          regulator_id: "HSE-2024-001",
          offence_action_date: ~D[2024-01-01]
        })

      # Check EA notices - should only find EA notice
      result =
        Enforcement.check_existing_notice_regulator_ids(
          ["EA-2024-001", "HSE-2024-001"],
          :ea
        )

      assert result.existing == ["EA-2024-001"]
      assert result.new == ["HSE-2024-001"]
      assert result.existing_count == 1
      assert result.new_count == 1
    end
  end
end
