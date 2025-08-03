defmodule EhsEnforcement.Sync.OffenderRealDataTest do
  @moduledoc """
  Tests OffenderMatcher with real-world HSE data patterns that might cause failures.
  """
  use EhsEnforcement.DataCase, async: true

  alias EhsEnforcement.Sync.OffenderMatcher

  describe "real-world data patterns" do
    test "handles extremely long company names" do
      attrs = %{
        name: "Very Long International Multi-National Construction Services Engineering and Building Solutions Limited Partnership with Additional Subsidiaries Company Name That Exceeds Normal Lengths",
        postcode: "M1 1AA"
      }
      
      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(attrs)
      assert offender.name == attrs.name
    end

    test "handles special characters in company names" do
      attrs = %{
        name: "O'Malley & Sons (Construction) Ltd. - Est. 1985",
        postcode: "M2 2BB"
      }
      
      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(attrs)
      assert offender.name == attrs.name
    end

    test "handles unicode characters" do
      attrs = %{
        name: "Müller & Sønstruction Façade Ltd",
        postcode: "M3 3CC"
      }
      
      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(attrs)
      assert offender.name == attrs.name
    end

    test "handles nil and empty attributes" do
      attrs = %{
        name: "Test Company",
        postcode: nil,
        local_authority: "",
        main_activity: nil,
        business_type: nil,
        industry: ""
      }
      
      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(attrs)
      assert offender.name == "Test Company"
      assert offender.postcode == nil
    end

    test "handles malformed postcodes" do
      attrs = %{
        name: "Bad Postcode Ltd",
        postcode: "invalid_postcode_format"
      }
      
      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(attrs)
      assert offender.postcode == "INVALID_POSTCODE_FORMAT"
    end

    test "handles very short names" do
      attrs = %{
        name: "AB",  # Very short name
        postcode: "M4 4DD"
      }
      
      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(attrs)
      assert offender.name == "AB"
    end

    test "handles names with only numbers" do
      attrs = %{
        name: "123456 Ltd",
        postcode: "M5 5EE"
      }
      
      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(attrs)
      assert offender.name == "123456 Ltd"
    end

    test "handles duplicate creation attempts with identical data" do
      attrs = %{
        name: "Duplicate Test Ltd",
        postcode: "M6 6FF"
      }
      
      # First creation
      assert {:ok, offender1} = OffenderMatcher.find_or_create_offender(attrs)
      
      # Second attempt with identical data should find existing
      assert {:ok, offender2} = OffenderMatcher.find_or_create_offender(attrs)
      
      assert offender1.id == offender2.id
    end

    test "handles business_type variations" do
      # Test with valid business type
      attrs1 = %{
        name: "Limited Company Test",
        business_type: :limited_company,
        postcode: "M7 7GG"
      }
      
      assert {:ok, offender1} = OffenderMatcher.find_or_create_offender(attrs1)
      assert offender1.business_type == :limited_company
      
      # Test with invalid business type (should be filtered out)
      attrs2 = %{
        name: "Invalid Type Test",
        business_type: :invalid_type,
        postcode: "M8 8HH"
      }
      
      # Should succeed but invalid business_type should be filtered out
      assert {:ok, offender2} = OffenderMatcher.find_or_create_offender(attrs2)
      assert offender2.name == "Invalid Type Test"
      assert offender2.business_type == nil  # Invalid type filtered out
    end

    test "handles mixed case and spacing in names" do
      # Create with one format
      attrs1 = %{
        name: "mixed   case    company    ltd",
        postcode: "M9 9II"
      }
      
      assert {:ok, offender1} = OffenderMatcher.find_or_create_offender(attrs1)
      
      # Try to find with different spacing/case
      attrs2 = %{
        name: "Mixed Case Company Ltd",
        postcode: "M9 9II"
      }
      
      assert {:ok, offender2} = OffenderMatcher.find_or_create_offender(attrs2)
      
      # Should find the same offender due to normalization
      assert offender1.id == offender2.id
    end

    test "stress test with many similar names" do
      base_name = "Construction Company"
      
      # Create many similar offenders
      offenders = Enum.map(1..10, fn i ->
        attrs = %{
          name: "#{base_name} #{i} Ltd",
          postcode: "ST#{i} #{i}XX"
        }
        {:ok, offender} = OffenderMatcher.find_or_create_offender(attrs)
        offender
      end)
      
      # All should be unique
      unique_ids = offenders |> Enum.map(& &1.id) |> Enum.uniq()
      assert length(unique_ids) == 10
      
      # Test fuzzy search doesn't match too broadly
      search_attrs = %{
        name: "#{base_name} Services Ltd",
        postcode: "NEW 1AA"
      }
      
      assert {:ok, new_offender} = OffenderMatcher.find_or_create_offender(search_attrs)
      refute Enum.any?(offenders, fn o -> o.id == new_offender.id end)
    end
  end

  describe "edge cases that might cause validation errors" do
    test "handles extremely long postcode" do
      attrs = %{
        name: "Long Postcode Test",
        postcode: "THIS IS A VERY LONG INVALID POSTCODE THAT EXCEEDS NORMAL LENGTH LIMITS"
      }
      
      # Should normalize and truncate appropriately
      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(attrs)
      assert is_binary(offender.postcode)
    end

    test "handles name with leading/trailing whitespace" do
      attrs = %{
        name: "   Whitespace Test Ltd   ",
        postcode: "  M10 10JJ  "
      }
      
      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(attrs)
      assert String.trim(offender.name) == offender.name
      assert String.trim(offender.postcode) == offender.postcode
    end

    test "handles empty string name (should fail)" do
      attrs = %{
        name: "",
        postcode: "M11 11KK"
      }
      
      # Should fail validation
      assert {:error, %Ash.Error.Invalid{}} = OffenderMatcher.find_or_create_offender(attrs)
    end

    test "handles map with string keys instead of atom keys" do
      attrs = %{
        "name" => "String Key Test Ltd",
        "postcode" => "M12 12LL",
        "local_authority" => "Test Authority"
      }
      
      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(attrs)
      assert offender.name == "String Key Test Ltd"
    end
  end
end