defmodule EhsEnforcement.Agencies.Hse.BreachesDeduplicationTest do
  use EhsEnforcementWeb.ConnCase, async: false

  alias EhsEnforcement.Agencies.Hse.Breaches
  alias EhsEnforcement.Enforcement

  require Ash.Query
  import Ash.Expr

  describe "process_breaches_with_deduplication/2" do
    test "processes simple HSE breach" do
      breaches = ["Health and Safety at Work Act 1974 / Section 2(1)"]

      assert {:ok, processed} = Breaches.process_breaches_with_deduplication(breaches)

      assert length(processed) == 1

      breach_data = hd(processed)
      assert breach_data.sequence_number == 1
      assert breach_data.legislation_title == "Health and Safety at Work etc. Act"
      assert breach_data.legislation_part == "Section 2(1)"
      assert String.contains?(breach_data.offence_description, "Section 2(1)")
    end

    test "processes multiple breaches" do
      breaches = [
        "Health and Safety at Work Act 1974 / Section 2(1)",
        "Construction (Design and Management) Regulations 2015 / Regulation 13",
        "COSHH 2002 / Regulation 7"
      ]

      assert {:ok, processed} = Breaches.process_breaches_with_deduplication(breaches)

      assert length(processed) == 3

      # Check sequence numbers
      sequence_numbers = Enum.map(processed, & &1.sequence_number)
      assert sequence_numbers == [1, 2, 3]

      # Check that different legislation was created/found
      legislation_ids = Enum.map(processed, & &1.legislation_id)
      assert length(Enum.uniq(legislation_ids)) == 3
    end

    test "handles duplicate breaches by reusing legislation" do
      breaches = [
        "Health and Safety at Work Act 1974 / Section 2(1)",
        # Same act, different section
        "HEALTH AND SAFETY AT WORK ACT 1974 / Section 3(1)"
      ]

      assert {:ok, processed} = Breaches.process_breaches_with_deduplication(breaches)

      assert length(processed) == 2

      # Both should reference the same legislation
      [breach1, breach2] = processed
      assert breach1.legislation_id == breach2.legislation_id
      assert breach1.legislation_title == breach2.legislation_title

      # But different sections
      assert breach1.legislation_part == "Section 2(1)"
      assert breach2.legislation_part == "Section 3(1)"
    end

    test "expands HSE abbreviations" do
      breaches = ["PUWER 1998 / Regulation 4"]

      assert {:ok, processed} = Breaches.process_breaches_with_deduplication(breaches)

      breach_data = hd(processed)

      assert String.contains?(
               breach_data.legislation_title,
               "Provision and Use of Work Equipment"
             )
    end

    test "handles breaches without sections" do
      breaches = ["Environmental Protection Act 1990"]

      assert {:ok, processed} = Breaches.process_breaches_with_deduplication(breaches)

      breach_data = hd(processed)
      assert breach_data.legislation_part == nil
      assert breach_data.offence_description == "Environmental Protection Act 1990"
    end

    test "handles malformed breach strings gracefully" do
      breaches = [
        # Valid
        "Health and Safety at Work Act 1974 / Section 2(1)",
        # Empty
        "",
        # No clear structure
        "Some Random Text",
        # Malformed
        "Another Act / / / Multiple Slashes"
      ]

      assert {:ok, processed} = Breaches.process_breaches_with_deduplication(breaches)

      # Should process at least the valid one
      assert length(processed) >= 1

      valid_breach =
        Enum.find(processed, fn breach ->
          String.contains?(breach.legislation_title, "Health and Safety")
        end)

      assert valid_breach != nil
    end
  end

  describe "parse_hse_breach_components/1" do
    test "parses standard HSE breach format" do
      breach = "Health and Safety at Work Act 1974 / Section 2(1)"

      assert {:ok, components} = Breaches.parse_hse_breach_components(breach)

      assert components.title == "Health and Safety at Work Act"
      assert components.year == 1974
      assert components.section == "Section 2(1)"
    end

    test "parses breach without section" do
      breach = "Construction (Design and Management) Regulations 2015"

      assert {:ok, components} = Breaches.parse_hse_breach_components(breach)

      assert String.contains?(components.title, "Construction")
      assert components.year == 2015
      assert components.section == nil
    end

    test "handles missing year with recovery" do
      breach = "Electricity at Work Regulations / Regulation 4"

      assert {:ok, components} = Breaches.parse_hse_breach_components(breach)

      assert String.contains?(components.title, "Electricity at Work")
      # Should recover missing year
      assert components.year == 1989
      assert components.section == "Regulation 4"
    end

    test "normalizes section references" do
      test_cases = [
        {"reg 4", "Regulation 4"},
        {"s.2(1)", "Section 2(1)"},
        {"regulation 13", "Regulation 13"},
        {"section 37", "Section 37"}
      ]

      for {input_section, expected_section} <- test_cases do
        breach = "Test Act 2020 / #{input_section}"

        assert {:ok, components} = Breaches.parse_hse_breach_components(breach)
        assert components.section == expected_section
      end
    end
  end

  describe "find_or_create_hse_legislation/1" do
    test "uses HSE lookup table for known legislation" do
      # This should match the @lrt lookup table
      components = %{
        title: "Health and Safety at Work Act",
        year: 1974
      }

      assert {:ok, legislation} = Breaches.find_or_create_hse_legislation(components)

      assert legislation.legislation_title == "Health and Safety at Work etc. Act"
      assert legislation.legislation_year == 1974
      assert legislation.legislation_number == 37
      assert legislation.legislation_type == :act
    end

    test "falls back to normalized processing for unknown legislation" do
      components = %{
        title: "Unknown Test Safety Act",
        year: 2023
      }

      assert {:ok, legislation} = Breaches.find_or_create_hse_legislation(components)

      assert legislation.legislation_title == "Unknown Test Safety Act"
      assert legislation.legislation_year == 2023
      assert legislation.legislation_type == :act
    end

    test "reuses existing legislation from lookup table" do
      # Create first instance
      components1 = %{title: "Health and Safety at Work Act", year: 1974}
      assert {:ok, legislation1} = Breaches.find_or_create_hse_legislation(components1)

      # Create second instance (should reuse)
      components2 = %{title: "HEALTH AND SAFETY AT WORK ACT", year: 1974}
      assert {:ok, legislation2} = Breaches.find_or_create_hse_legislation(components2)

      assert legislation1.id == legislation2.id
    end
  end

  describe "create_hse_offences/3" do
    setup do
      # Create a test case to link offences to
      {:ok, agency} =
        Enforcement.create_agency(%{
          name: "Health and Safety Executive",
          code: :hse,
          country: "UK"
        })

      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Test Company Ltd",
          business_type: :limited_company
        })

      {:ok, test_case} =
        Enforcement.create_case(%{
          regulator_id: "TEST_HSE_001",
          agency_id: agency.id,
          offender_id: offender.id,
          offence_action_type: "Court Case",
          offence_fine: Decimal.new("5000.00")
        })

      %{case_id: test_case.id}
    end

    test "creates offences for HSE breaches", %{case_id: case_id} do
      breach_texts = [
        "Health and Safety at Work Act 1974 / Section 2(1)",
        "Construction (Design and Management) Regulations 2015 / Regulation 13"
      ]

      opts = [total_fine: Decimal.new("10000.00")]

      assert {:ok, offences} = Breaches.create_hse_offences(case_id, breach_texts, opts)

      assert length(offences) == 2

      # Check that offences are linked to the case
      offence_case_ids = Enum.map(offences, & &1.case_id)
      assert Enum.all?(offence_case_ids, &(&1 == case_id))

      # Check that fines are distributed proportionally
      total_fine =
        offences |> Enum.map(& &1.fine) |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)

      assert Decimal.equal?(total_fine, Decimal.new("10000.00"))
    end

    test "handles single breach with full fine", %{case_id: case_id} do
      breach_texts = ["Health and Safety at Work Act 1974 / Section 2(1)"]
      opts = [total_fine: Decimal.new("5000.00")]

      assert {:ok, offences} = Breaches.create_hse_offences(case_id, breach_texts, opts)

      assert length(offences) == 1

      offence = hd(offences)
      assert Decimal.equal?(offence.fine, Decimal.new("5000.00"))
    end

    test "creates offences with proper sequence numbers", %{case_id: case_id} do
      breach_texts = [
        "Health and Safety at Work Act 1974 / Section 2(1)",
        "COSHH 2002 / Regulation 7",
        "Construction Regulations 2015 / Regulation 13"
      ]

      assert {:ok, offences} = Breaches.create_hse_offences(case_id, breach_texts, [])

      sequence_numbers = Enum.map(offences, & &1.sequence_number) |> Enum.sort()
      assert sequence_numbers == [1, 2, 3]
    end

    test "links offences to correct legislation", %{case_id: case_id} do
      breach_texts = ["Health and Safety at Work Act 1974 / Section 2(1)"]

      assert {:ok, offences} = Breaches.create_hse_offences(case_id, breach_texts, [])

      offence = hd(offences)
      assert offence.legislation_id != nil

      # Verify the legislation exists and has correct data
      {:ok, legislation} = Enforcement.get_legislation(offence.legislation_id)
      assert legislation.legislation_title == "Health and Safety at Work etc. Act"
      assert legislation.legislation_year == 1974
    end
  end

  describe "integration with deduplication system" do
    test "multiple cases with same breaches reuse legislation" do
      # Process breaches for first case
      breaches1 = ["Health and Safety at Work Act 1974 / Section 2(1)"]
      {:ok, processed1} = Breaches.process_breaches_with_deduplication(breaches1)

      # Process same breaches for second case
      breaches2 = ["HEALTH AND SAFETY AT WORK ACT 1974 / Section 3(1)"]
      {:ok, processed2} = Breaches.process_breaches_with_deduplication(breaches2)

      # Should reference the same legislation
      breach1 = hd(processed1)
      breach2 = hd(processed2)

      assert breach1.legislation_id == breach2.legislation_id
      assert breach1.legislation_title == breach2.legislation_title

      # Verify only one legislation record was created
      {:ok, all_legislation} = Enforcement.list_legislation()

      hse_legislation =
        Enum.filter(all_legislation, fn leg ->
          String.contains?(leg.legislation_title, "Health and Safety at Work")
        end)

      assert length(hse_legislation) == 1
    end

    test "different breach formats for same act are deduplicated" do
      breach_variants = [
        "Health and Safety at Work Act 1974 / Section 2(1)",
        "HEALTH AND SAFETY AT WORK ACT 1974 / Section 3(1)",
        "health and safety at work etc. act 1974 / Section 37"
      ]

      # Process each variant
      results =
        Enum.map(breach_variants, fn breach ->
          {:ok, processed} = Breaches.process_breaches_with_deduplication([breach])
          hd(processed)
        end)

      # All should reference the same legislation
      legislation_ids = Enum.map(results, & &1.legislation_id)
      assert length(Enum.uniq(legislation_ids)) == 1

      # All should have the same normalized title
      titles = Enum.map(results, & &1.legislation_title)
      assert length(Enum.uniq(titles)) == 1
    end
  end
end
