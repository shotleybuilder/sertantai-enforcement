defmodule EhsEnforcement.EnforcementTest do
  use EhsEnforcement.DataCase, async: true

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
end
