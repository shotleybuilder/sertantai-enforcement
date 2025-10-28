defmodule EhsEnforcement.Enforcement.LegislationDeduplicationTest do
  use EhsEnforcementWeb.ConnCase, async: false

  alias EhsEnforcement.Enforcement

  require Ash.Query
  import Ash.Expr

  describe "find_or_create_legislation/4" do
    test "creates new legislation when none exists" do
      title = "Test Environmental Protection Act"
      year = 1990
      number = 123
      type = :act

      assert {:ok, legislation} =
               Enforcement.find_or_create_legislation(title, year, number, type)

      assert legislation.legislation_title == "Test Environmental Protection Act"
      assert legislation.legislation_year == year
      assert legislation.legislation_number == number
      assert legislation.legislation_type == type
    end

    test "returns existing legislation for exact match" do
      # Create initial legislation
      initial_attrs = %{
        legislation_title: "Test Safety Regulations",
        legislation_year: 2005,
        legislation_number: 456,
        legislation_type: :regulation
      }

      {:ok, original} = Enforcement.create_legislation(initial_attrs)

      # Try to create the same legislation again
      assert {:ok, found} =
               Enforcement.find_or_create_legislation(
                 "Test Safety Regulations",
                 2005,
                 456,
                 :regulation
               )

      assert found.id == original.id
    end

    test "finds similar legislation with fuzzy matching" do
      # Create legislation with normalized title
      initial_attrs = %{
        legislation_title: "Health and Safety at Work etc. Act",
        legislation_year: 1974,
        legislation_number: 37,
        legislation_type: :act
      }

      {:ok, original} = Enforcement.create_legislation(initial_attrs)

      # Try with slightly different title that should match
      assert {:ok, found} =
               Enforcement.find_or_create_legislation(
                 "HEALTH AND SAFETY AT WORK ACT",
                 1974,
                 37,
                 :act
               )

      assert found.id == original.id
    end

    test "normalizes title before processing" do
      title = "CONTROL OF SUBSTANCES HAZARDOUS TO HEALTH REGULATIONS"

      assert {:ok, legislation} =
               Enforcement.find_or_create_legislation(title, 2002, 2677, :regulation)

      assert legislation.legislation_title ==
               "Control of Substances Hazardous to Health Regulations"
    end

    test "auto-determines type when nil" do
      title = "Test Pollution Regulations"

      assert {:ok, legislation} = Enforcement.find_or_create_legislation(title, 2010, 123, nil)

      assert legislation.legislation_type == :regulation
    end

    test "extracts year from title when not provided" do
      title = "Test Climate Change Act 2008"

      assert {:ok, legislation} = Enforcement.find_or_create_legislation(title, nil, nil, nil)

      assert legislation.legislation_year == 2008
      assert legislation.legislation_type == :act
    end

    test "rejects invalid title" do
      assert {:error, reason} = Enforcement.find_or_create_legislation("", 2020, 123, :act)

      assert reason == "Legislation title cannot be empty"
    end

    test "handles concurrent creation attempts" do
      title = "Concurrent Test Act"
      year = 2023
      number = 999

      # Simulate concurrent creation
      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            Enforcement.find_or_create_legislation(title, year, number, :act)
          end)
        end

      results = Enum.map(tasks, &Task.await/1)

      # All should succeed
      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)

      # All should return the same legislation ID
      legislation_ids = Enum.map(results, fn {:ok, legislation} -> legislation.id end)
      assert length(Enum.uniq(legislation_ids)) == 1
    end
  end

  describe "batch_find_or_create_legislation/1" do
    test "processes multiple legislation records" do
      legislation_data = [
        %{title: "Batch Test Act 1", year: 2020, number: 1, type: :act},
        %{title: "Batch Test Regulations 1", year: 2021, number: 2, type: :regulation},
        %{title: "Batch Test Order 1", year: 2022, number: 3, type: :order}
      ]

      assert {:ok, results} = Enforcement.batch_find_or_create_legislation(legislation_data)

      assert map_size(results) == 3
      assert Map.has_key?(results, "Batch Test Act 1")
      assert Map.has_key?(results, "Batch Test Regulations 1")
      assert Map.has_key?(results, "Batch Test Order 1")
    end

    test "handles mixed success and failure" do
      legislation_data = [
        %{title: "Valid Act", year: 2020, number: 1, type: :act},
        # Invalid
        %{title: "", year: 2021, number: 2, type: :regulation},
        %{title: "Another Valid Act", year: 2022, number: 3, type: :act}
      ]

      assert {:error, {"", _reason}} =
               Enforcement.batch_find_or_create_legislation(legislation_data)
    end
  end

  describe "search_legislation_fuzzy/2" do
    setup do
      # Create some test legislation
      {:ok, _} =
        Enforcement.create_legislation(%{
          legislation_title: "Health and Safety at Work etc. Act",
          legislation_year: 1974,
          legislation_number: 37,
          legislation_type: :act
        })

      {:ok, _} =
        Enforcement.create_legislation(%{
          legislation_title: "Control of Substances Hazardous to Health Regulations",
          legislation_year: 2002,
          legislation_number: 2677,
          legislation_type: :regulation
        })

      {:ok, _} =
        Enforcement.create_legislation(%{
          legislation_title: "Environmental Protection Act",
          legislation_year: 1990,
          legislation_number: 143,
          legislation_type: :act
        })

      :ok
    end

    test "finds exact matches" do
      assert {:ok, matches} =
               Enforcement.search_legislation_fuzzy("Health and Safety at Work etc. Act")

      assert length(matches) >= 1

      assert Enum.any?(matches, fn leg ->
               String.contains?(leg.legislation_title, "Health and Safety")
             end)
    end

    test "finds similar matches with fuzzy search" do
      assert {:ok, matches} =
               Enforcement.search_legislation_fuzzy("HEALTH AND SAFETY AT WORK ACT")

      assert length(matches) >= 1

      assert Enum.any?(matches, fn leg ->
               String.contains?(leg.legislation_title, "Health and Safety")
             end)
    end

    test "respects similarity threshold" do
      # Very different search should return fewer results
      assert {:ok, matches_low} =
               Enforcement.search_legislation_fuzzy("Completely Different Act", 0.9)

      assert {:ok, matches_high} =
               Enforcement.search_legislation_fuzzy("Completely Different Act", 0.1)

      assert length(matches_low) <= length(matches_high)
    end

    test "returns empty list for no matches" do
      assert {:ok, matches} =
               Enforcement.search_legislation_fuzzy("Nonexistent Legislation XYZ", 0.8)

      assert matches == []
    end
  end

  describe "get_legislation_stats/0" do
    setup do
      # Create test legislation with various completeness levels
      {:ok, _} =
        Enforcement.create_legislation(%{
          legislation_title: "Complete Act",
          legislation_year: 2020,
          legislation_number: 1,
          legislation_type: :act
        })

      {:ok, _} =
        Enforcement.create_legislation(%{
          legislation_title: "Missing Number Act",
          legislation_year: 2021,
          legislation_number: nil,
          legislation_type: :act
        })

      {:ok, _} =
        Enforcement.create_legislation(%{
          legislation_title: "Missing Year Act",
          legislation_year: nil,
          legislation_number: 3,
          legislation_type: :act
        })

      :ok
    end

    test "returns comprehensive statistics" do
      assert {:ok, stats} = Enforcement.get_legislation_stats()

      assert is_integer(stats.total_count)
      assert is_map(stats.by_type)
      assert is_integer(stats.missing_year)
      assert is_integer(stats.missing_number)
      assert is_list(stats.potential_duplicates)

      # Should have at least our test data
      assert stats.total_count >= 3
      assert stats.missing_year >= 1
      assert stats.missing_number >= 1
    end

    test "detects potential duplicates" do
      # Create duplicate with different case
      {:ok, _} =
        Enforcement.create_legislation(%{
          # Same as "Complete Act" but different case
          legislation_title: "COMPLETE ACT",
          legislation_year: 2020,
          legislation_number: 1,
          legislation_type: :act
        })

      assert {:ok, stats} = Enforcement.get_legislation_stats()

      # Should detect the duplicate
      duplicate_groups = stats.potential_duplicates
      assert length(duplicate_groups) >= 1

      complete_act_duplicate =
        Enum.find(duplicate_groups, fn group ->
          String.contains?(String.downcase(group.normalized_title), "complete act")
        end)

      assert complete_act_duplicate != nil
      assert complete_act_duplicate.count >= 2
    end
  end

  describe "legislation validation and normalization" do
    test "Ash resource validates and normalizes titles on creation" do
      # Test that the Ash resource applies validation and normalization
      attrs = %{
        # All caps
        legislation_title: "VALIDATION TEST ACT",
        legislation_year: 2023,
        legislation_number: 999,
        legislation_type: :act
      }

      assert {:ok, legislation} = Enforcement.create_legislation(attrs)

      # Title should be normalized to proper case
      assert legislation.legislation_title == "Validation Test Act"
    end

    test "Ash resource auto-determines type if not provided" do
      attrs = %{
        legislation_title: "Auto Type Regulations",
        legislation_year: 2023,
        legislation_number: 888
        # No legislation_type provided
      }

      assert {:ok, legislation} = Enforcement.create_legislation(attrs)

      # Should auto-detect as regulation
      assert legislation.legislation_type == :regulation
    end

    test "Ash resource validates year range" do
      attrs = %{
        legislation_title: "Invalid Year Act",
        # Too old
        legislation_year: 1700,
        legislation_number: 1,
        legislation_type: :act
      }

      assert {:error, error} = Enforcement.create_legislation(attrs)

      # Should contain validation error about year
      assert is_struct(error, Ash.Error.Invalid)
    end

    test "Ash resource validates positive number" do
      attrs = %{
        legislation_title: "Invalid Number Act",
        legislation_year: 2023,
        # Negative number
        legislation_number: -1,
        legislation_type: :act
      }

      assert {:error, error} = Enforcement.create_legislation(attrs)

      # Should contain validation error about number
      assert is_struct(error, Ash.Error.Invalid)
    end
  end
end
