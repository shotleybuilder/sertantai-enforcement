defmodule EhsEnforcement.Enforcement.AgencyTest do
  use EhsEnforcement.DataCase, async: true

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Enforcement.Agency

  describe "agency resource" do
    test "creates an agency with valid attributes" do
      attrs = %{
        code: :hse,
        name: "Health and Safety Executive",
        base_url: "https://resources.hse.gov.uk",
        enabled: true
      }

      assert {:ok, agency} = Enforcement.create_agency(attrs)
      assert agency.code == :hse
      assert agency.name == "Health and Safety Executive"
      assert agency.base_url == "https://resources.hse.gov.uk"
      assert agency.enabled == true
      assert agency.id != nil
    end

    test "validates required fields" do
      attrs = %{}

      assert {:error, %Ash.Error.Invalid{} = error} = Enforcement.create_agency(attrs)

      # Check that required field errors are present
      assert Enum.any?(error.errors, fn err ->
               err.field == :code and err.__struct__ == Ash.Error.Changes.Required
             end)

      assert Enum.any?(error.errors, fn err ->
               err.field == :name and err.__struct__ == Ash.Error.Changes.Required
             end)
    end

    test "validates code format" do
      attrs = %{
        code: :invalid_code,
        name: "Test Agency"
      }

      assert {:error, %Ash.Error.Invalid{}} = Enforcement.create_agency(attrs)
    end

    test "enforces unique code constraint" do
      attrs = %{
        code: :hse,
        name: "Health and Safety Executive"
      }

      assert {:ok, _agency1} = Enforcement.create_agency(attrs)

      attrs2 = %{
        code: :hse,
        name: "Another HSE"
      }

      assert {:error, %Ash.Error.Invalid{}} = Enforcement.create_agency(attrs2)
    end

    test "lists all agencies" do
      attrs1 = %{code: :hse, name: "Health and Safety Executive"}
      attrs2 = %{code: :onr, name: "Office for Nuclear Regulation"}

      assert {:ok, _agency1} = Enforcement.create_agency(attrs1)
      assert {:ok, _agency2} = Enforcement.create_agency(attrs2)

      agencies = Enforcement.list_agencies!()
      assert length(agencies) == 2
    end

    test "gets agency by code" do
      attrs = %{code: :hse, name: "Health and Safety Executive"}
      assert {:ok, created_agency} = Enforcement.create_agency(attrs)

      assert {:ok, found_agency} = Enforcement.get_agency_by_code(:hse)
      assert found_agency.id == created_agency.id
    end

    test "updates agency" do
      attrs = %{code: :hse, name: "Health and Safety Executive"}
      assert {:ok, agency} = Enforcement.create_agency(attrs)

      update_attrs = %{name: "Updated HSE Name", enabled: false}
      assert {:ok, updated_agency} = Enforcement.update_agency(agency, update_attrs)

      assert updated_agency.name == "Updated HSE Name"
      assert updated_agency.enabled == false
    end
  end
end
