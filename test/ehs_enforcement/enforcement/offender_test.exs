defmodule EhsEnforcement.Enforcement.OffenderTest do
  use EhsEnforcement.DataCase, async: true
  require Ash.Query
  import Ash.Expr

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Enforcement.Offender

  describe "offender resource" do
    test "creates an offender with valid attributes" do
      attrs = %{
        name: "Acme Construction Ltd",
        local_authority: "Manchester",
        postcode: "M1 1AA",
        main_activity: "Commercial construction",
        business_type: :limited_company,
        industry: "Construction"
      }

      assert {:ok, offender} = Enforcement.create_offender(attrs)
      # original name preserved
      assert offender.name == "Acme Construction Ltd"
      # normalized version
      assert offender.normalized_name == "acme construction limited"
      assert offender.local_authority == "Manchester"
      assert offender.postcode == "M1 1AA"
      assert offender.business_type == :limited_company
      assert offender.total_cases == 0
      assert offender.total_notices == 0
      assert offender.total_fines == Decimal.new("0")
    end

    test "normalizes company names" do
      attrs = %{
        name: "Test Company Ltd.",
        business_type: :limited_company
      }

      assert {:ok, offender} = Enforcement.create_offender(attrs)
      # original preserved
      assert offender.name == "Test Company Ltd."
      assert offender.normalized_name == "test company limited"
    end

    test "normalizes PLC names" do
      attrs = %{
        name: "Big Corp P.L.C.",
        business_type: :plc
      }

      assert {:ok, offender} = Enforcement.create_offender(attrs)
      # original preserved
      assert offender.name == "Big Corp P.L.C."
      assert offender.normalized_name == "big corp plc"
    end

    test "validates required name field" do
      attrs = %{}

      assert {:error, %Ash.Error.Invalid{}} = Enforcement.create_offender(attrs)
    end

    test "enforces unique name and postcode constraint" do
      attrs = %{
        name: "Duplicate Company Ltd",
        postcode: "M1 1AA"
      }

      assert {:ok, _offender1} = Enforcement.create_offender(attrs)
      assert {:error, %Ash.Error.Invalid{}} = Enforcement.create_offender(attrs)
    end

    test "allows same name with different postcodes" do
      attrs1 = %{name: "Same Company Ltd", postcode: "M1 1AA"}
      attrs2 = %{name: "Same Company Ltd", postcode: "M2 2BB"}

      assert {:ok, _offender1} = Enforcement.create_offender(attrs1)
      assert {:ok, _offender2} = Enforcement.create_offender(attrs2)
    end

    test "searches offenders by name" do
      attrs1 = %{name: "Construction Company Ltd"}
      attrs2 = %{name: "Building Services Ltd"}
      attrs3 = %{name: "Electrical Services Ltd"}

      assert {:ok, _} = Enforcement.create_offender(attrs1)
      assert {:ok, _} = Enforcement.create_offender(attrs2)
      assert {:ok, _} = Enforcement.create_offender(attrs3)

      {:ok, results} = Enforcement.search_offenders("construction")
      assert length(results) == 1

      {:ok, results} = Enforcement.search_offenders("services")
      assert length(results) == 2
    end

    test "updates offender statistics" do
      attrs = %{name: "Test Company Ltd"}
      assert {:ok, offender} = Enforcement.create_offender(attrs)

      fine_amount = Decimal.new("5000.00")

      assert {:ok, updated_offender} =
               Enforcement.update_offender_statistics(
                 offender,
                 %{fine_amount: fine_amount}
               )

      assert updated_offender.total_cases == 1
      assert updated_offender.total_notices == 1
      assert Decimal.equal?(updated_offender.total_fines, fine_amount)
    end

    test "calculates enforcement count" do
      attrs = %{
        name: "Test Company Ltd"
      }

      assert {:ok, offender} = Enforcement.create_offender(attrs)

      # Update statistics separately using the update_statistics action
      assert {:ok, updated_offender} =
               Enforcement.update_offender_statistics(
                 offender,
                 %{fine_amount: Decimal.new("1000")}
               )

      # Load with calculation - should be total_cases + total_notices
      offender_with_calc =
        Enforcement.get_offender!(updated_offender.id, load: [:enforcement_count])

      # After one update_statistics call, total_cases = 1, total_notices = 1
      assert offender_with_calc.enforcement_count == 2
    end
  end

  describe "find_or_create_offender/1" do
    test "creates new offender when none exists" do
      attrs = %{
        name: "New Company Ltd",
        postcode: "M1 1AA",
        local_authority: "Manchester",
        business_type: :limited_company
      }

      assert {:ok, offender} = Offender.find_or_create_offender(attrs)
      # original preserved
      assert offender.name == "New Company Ltd"
      # normalized version
      assert offender.normalized_name == "new company limited"
      assert offender.postcode == "M1 1AA"
      assert offender.business_type == :limited_company
    end

    test "finds existing offender by exact name and postcode match" do
      # Create existing offender
      existing_attrs = %{
        name: "Existing Company Ltd",
        postcode: "M2 2BB"
      }

      {:ok, existing_offender} = Enforcement.create_offender(existing_attrs)

      # Try to find with same normalized data
      search_attrs = %{
        # Different format but normalizes to same
        name: "Existing Company Ltd.",
        postcode: "M2 2BB",
        # Additional data should be ignored for matching
        local_authority: "Different Authority"
      }

      assert {:ok, found_offender} = Offender.find_or_create_offender(search_attrs)
      assert found_offender.id == existing_offender.id
      # Original name preserved
      assert found_offender.name == "Existing Company Ltd"
      # Normalized for matching
      assert found_offender.normalized_name == "existing company limited"
    end

    test "creates new offender when postcode differs" do
      # Create existing offender
      {:ok, _existing} =
        Enforcement.create_offender(%{
          name: "Same Name Ltd",
          postcode: "M1 1AA"
        })

      # Try with same name but different postcode
      attrs = %{
        name: "Same Name Ltd",
        # Different postcode
        postcode: "M3 3CC"
      }

      assert {:ok, new_offender} = Offender.find_or_create_offender(attrs)
      assert new_offender.postcode == "M3 3CC"

      # Should have 2 offenders with same name but different postcodes
      {:ok, all_offenders} = Enforcement.list_offenders()

      same_name_offenders =
        Enum.filter(all_offenders, &(&1.normalized_name == "same name limited"))

      assert length(same_name_offenders) == 2
    end

    test "performs fuzzy search when exact match fails" do
      # Create offender with slight name variation
      {:ok, existing_offender} =
        Enforcement.create_offender(%{
          name: "ABC Construction Limited",
          postcode: "M4 4DD"
        })

      # Search with slightly different name
      search_attrs = %{
        # Should fuzzy match to existing
        name: "A.B.C. Construction Ltd",
        postcode: "M4 4DD"
      }

      assert {:ok, found_offender} = Offender.find_or_create_offender(search_attrs)
      assert found_offender.id == existing_offender.id
    end

    test "creates new offender when fuzzy match confidence is too low" do
      # Create offender
      {:ok, _existing} =
        Enforcement.create_offender(%{
          name: "Completely Different Company Ltd",
          postcode: "M5 5EE"
        })

      # Search with very different name
      search_attrs = %{
        name: "Totally Unrelated Business Ltd",
        postcode: "M6 6FF"
      }

      assert {:ok, new_offender} = Offender.find_or_create_offender(search_attrs)
      # Original preserved
      assert new_offender.name == "Totally Unrelated Business Ltd"
      # Normalized version
      assert new_offender.normalized_name == "totally unrelated business limited"
      assert new_offender.postcode == "M6 6FF"

      # Should have 2 different offenders
      {:ok, all_offenders} = Enforcement.list_offenders()
      assert length(all_offenders) == 2
    end

    test "handles multiple fuzzy matches by selecting best one" do
      # Create similar offenders
      {:ok, offender1} =
        Enforcement.create_offender(%{
          name: "ABC Construction Ltd",
          postcode: "M7 7GG"
        })

      {:ok, _offender2} =
        Enforcement.create_offender(%{
          name: "ABC Building Ltd",
          postcode: "M8 8HH"
        })

      # Search with name that could match either
      search_attrs = %{
        # Closer to first one
        name: "ABC Construction Limited",
        # Exact postcode match with first
        postcode: "M7 7GG"
      }

      assert {:ok, matched_offender} = Offender.find_or_create_offender(search_attrs)
      # Should pick the better match
      assert matched_offender.id == offender1.id
    end

    test "normalizes company name variations correctly" do
      attrs = %{name: "Company Ltd.", postcode: "TEST"}
      {:ok, offender} = Offender.find_or_create_offender(attrs)
      # Original preserved
      assert offender.name == "Company Ltd."
      # Normalized version
      assert offender.normalized_name == "company limited"
    end

    test "handles missing postcode gracefully" do
      attrs = %{
        name: "No Postcode Company Ltd"
        # postcode deliberately omitted
      }

      assert {:ok, offender} = Offender.find_or_create_offender(attrs)
      # Original preserved
      assert offender.name == "No Postcode Company Ltd"
      # Normalized version
      assert offender.normalized_name == "no postcode company limited"
      assert offender.postcode == nil
    end

    test "handles empty or whitespace-only names" do
      attrs = %{
        # Whitespace only
        name: "   ",
        postcode: "M9 9II"
      }

      # Should fail validation
      assert {:error, %Ash.Error.Invalid{}} = Offender.find_or_create_offender(attrs)
    end

    test "finds offender when postcode case differs" do
      {:ok, existing} =
        Enforcement.create_offender(%{
          name: "Case Test Ltd",
          # lowercase
          postcode: "m10 10jj"
        })

      search_attrs = %{
        name: "Case Test Ltd",
        # uppercase
        postcode: "M10 10JJ"
      }

      assert {:ok, found_offender} = Offender.find_or_create_offender(search_attrs)
      assert found_offender.id == existing.id
    end

    test "handles database constraint violations gracefully" do
      # This tests race conditions where two processes try to create the same offender
      attrs = %{
        name: "Race Condition Ltd",
        postcode: "M11 11KK"
      }

      # Simulate what happens if offender is created between find and create
      {:ok, _existing} = Enforcement.create_offender(attrs)

      # This should find the existing one instead of failing on constraint
      assert {:ok, found_offender} = Offender.find_or_create_offender(attrs)
      # Original name preserved
      assert found_offender.name == "Race Condition Ltd"
    end

    test "preserves additional attributes when creating new offender" do
      attrs = %{
        name: "Full Details Ltd",
        postcode: "M12 12LL",
        local_authority: "Test Authority",
        main_activity: "Testing",
        business_type: :limited_company,
        industry: "Software"
      }

      assert {:ok, offender} = Offender.find_or_create_offender(attrs)
      assert offender.local_authority == "Test Authority"
      assert offender.main_activity == "Testing"
      assert offender.business_type == :limited_company
      assert offender.industry == "Software"
    end

    test "performance with large dataset" do
      # Create many offenders
      Enum.each(1..100, fn i ->
        {:ok, _} =
          Enforcement.create_offender(%{
            name: "Performance Test Company #{i} Ltd",
            postcode: "PT#{i} #{i}XX"
          })
      end)

      # Search should still be fast
      attrs = %{
        name: "Performance Test Company 50 Ltd",
        postcode: "PT50 50XX"
      }

      {duration_us, result} =
        :timer.tc(fn ->
          Offender.find_or_create_offender(attrs)
        end)

      assert {:ok, _offender} = result

      # Should complete in under 100ms even with 100 existing records
      duration_ms = duration_us / 1000
      assert duration_ms < 100
    end
  end

  describe "normalize_company_name/1" do
    test "normalizes various company name formats" do
      assert Offender.normalize_company_name("Test Company Ltd") == "test company limited"
      assert Offender.normalize_company_name("Test Company Ltd.") == "test company limited"
      assert Offender.normalize_company_name("Test Company LIMITED") == "test company limited"
      assert Offender.normalize_company_name("Big Corp PLC") == "big corp plc"
      assert Offender.normalize_company_name("Big Corp P.L.C.") == "big corp plc"
      assert Offender.normalize_company_name("Simple Business") == "simple business"
    end

    test "handles extra whitespace" do
      assert Offender.normalize_company_name("  Test Company  Ltd  ") == "test company limited"

      assert Offender.normalize_company_name("Multiple   Spaces   Ltd") ==
               "multiple spaces limited"
    end

    test "handles empty strings" do
      assert Offender.normalize_company_name("") == ""
      assert Offender.normalize_company_name("   ") == ""
    end
  end

  describe "real-world data patterns" do
    test "handles extremely long company names" do
      attrs = %{
        name:
          "Very Long International Multi-National Construction Services Engineering and Building Solutions Limited Partnership with Additional Subsidiaries Company Name That Exceeds Normal Lengths",
        postcode: "M1 1AA"
      }

      assert {:ok, offender} = Offender.find_or_create_offender(attrs)
      assert offender.name == attrs.name
    end

    test "handles special characters in company names" do
      attrs = %{
        name: "O'Malley & Sons (Construction) Ltd. - Est. 1985",
        postcode: "M2 2BB"
      }

      assert {:ok, offender} = Offender.find_or_create_offender(attrs)
      assert offender.name == attrs.name
    end

    test "handles unicode characters" do
      attrs = %{
        name: "Müller & Sønstruction Façade Ltd",
        postcode: "M3 3CC"
      }

      assert {:ok, offender} = Offender.find_or_create_offender(attrs)
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

      assert {:ok, offender} = Offender.find_or_create_offender(attrs)
      assert offender.name == "Test Company"
      assert offender.postcode == nil
    end

    test "handles malformed postcodes" do
      attrs = %{
        name: "Bad Postcode Ltd",
        postcode: "invalid_postcode_format"
      }

      assert {:ok, offender} = Offender.find_or_create_offender(attrs)
      assert offender.postcode == "INVALID_POSTCODE_FORMAT"
    end

    test "handles very short names" do
      attrs = %{
        # Very short name
        name: "AB",
        postcode: "M4 4DD"
      }

      assert {:ok, offender} = Offender.find_or_create_offender(attrs)
      assert offender.name == "AB"
    end

    test "handles names with only numbers" do
      attrs = %{
        name: "123456 Ltd",
        postcode: "M5 5EE"
      }

      assert {:ok, offender} = Offender.find_or_create_offender(attrs)
      assert offender.name == "123456 Ltd"
    end

    test "handles duplicate creation attempts with identical data" do
      attrs = %{
        name: "Duplicate Test Ltd",
        postcode: "M6 6FF"
      }

      # First creation
      assert {:ok, offender1} = Offender.find_or_create_offender(attrs)

      # Second attempt with identical data should find existing
      assert {:ok, offender2} = Offender.find_or_create_offender(attrs)

      assert offender1.id == offender2.id
    end

    test "handles business_type variations" do
      # Test with valid business type
      attrs1 = %{
        name: "Limited Company Test",
        business_type: :limited_company,
        postcode: "M7 7GG"
      }

      assert {:ok, offender1} = Offender.find_or_create_offender(attrs1)
      assert offender1.business_type == :limited_company

      # Test with invalid business type (should be filtered out)
      attrs2 = %{
        name: "Invalid Type Test",
        business_type: :invalid_type,
        postcode: "M8 8HH"
      }

      # Should succeed but invalid business_type should be filtered out
      assert {:ok, offender2} = Offender.find_or_create_offender(attrs2)
      assert offender2.name == "Invalid Type Test"
      # Invalid type filtered out
      assert offender2.business_type == nil
    end

    test "handles mixed case and spacing in names" do
      # Create with one format
      attrs1 = %{
        name: "mixed   case    company    ltd",
        postcode: "M9 9II"
      }

      assert {:ok, offender1} = Offender.find_or_create_offender(attrs1)

      # Try to find with different spacing/case
      attrs2 = %{
        name: "Mixed Case Company Ltd",
        postcode: "M9 9II"
      }

      assert {:ok, offender2} = Offender.find_or_create_offender(attrs2)

      # Should find the same offender due to normalization
      assert offender1.id == offender2.id
    end

    test "stress test with many similar names" do
      base_name = "Construction Company"

      # Create many similar offenders
      offenders =
        Enum.map(1..10, fn i ->
          attrs = %{
            name: "#{base_name} #{i} Ltd",
            postcode: "ST#{i} #{i}XX"
          }

          {:ok, offender} = Offender.find_or_create_offender(attrs)
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

      assert {:ok, new_offender} = Offender.find_or_create_offender(search_attrs)
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
      assert {:ok, offender} = Offender.find_or_create_offender(attrs)
      assert is_binary(offender.postcode)
    end

    test "handles name with leading/trailing whitespace" do
      attrs = %{
        name: "   Whitespace Test Ltd   ",
        postcode: "  M10 10JJ  "
      }

      assert {:ok, offender} = Offender.find_or_create_offender(attrs)
      assert String.trim(offender.name) == offender.name
      assert String.trim(offender.postcode) == offender.postcode
    end

    test "handles empty string name (should fail)" do
      attrs = %{
        name: "",
        postcode: "M11 11KK"
      }

      # Should fail validation
      assert {:error, %Ash.Error.Invalid{}} = Offender.find_or_create_offender(attrs)
    end

    test "handles map with string keys instead of atom keys" do
      attrs = %{
        "name" => "String Key Test Ltd",
        "postcode" => "M12 12LL",
        "local_authority" => "Test Authority"
      }

      assert {:ok, offender} = Offender.find_or_create_offender(attrs)
      assert offender.name == "String Key Test Ltd"
    end
  end
end
