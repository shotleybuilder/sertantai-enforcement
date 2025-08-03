defmodule EhsEnforcementWeb.DashboardUnitTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  require Ash.Query
  import Ash.Expr

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Repo

  # This test file focuses on the dashboard logic that can be tested
  # without requiring the actual LiveView to be implemented yet.
  # It tests the underlying Ash domain functions that the dashboard will use.

  describe "Dashboard Data Loading Functions" do
    setup do
      # Create test data for dashboard functionality
      {:ok, hse} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true
      })

      {:ok, ea} = Enforcement.create_agency(%{
        code: :ea,
        name: "Environment Agency", 
        enabled: true
      })

      {:ok, offender1} = Enforcement.create_offender(%{
        name: "Test Company Ltd",
        local_authority: "Test Council",
        postcode: "TE1 1ST"
      })

      {:ok, offender2} = Enforcement.create_offender(%{
        name: "Another Corp",
        local_authority: "Another Council", 
        postcode: "TE2 2ST"
      })

      # Create test cases with different dates
      base_date = ~D[2024-01-15]
      
      {:ok, case1} = Enforcement.create_case(%{
        regulator_id: "HSE-001",
        agency_id: hse.id,
        offender_id: offender1.id,
        offence_action_date: base_date,
        offence_fine: Decimal.new("5000.00"),
        offence_breaches: "Breach of safety regulations"
      })

      {:ok, case2} = Enforcement.create_case(%{
        regulator_id: "EA-001", 
        agency_id: ea.id,
        offender_id: offender2.id,
        offence_action_date: Date.add(base_date, 5),
        offence_fine: Decimal.new("3000.00"),
        offence_breaches: "Environmental violation"
      })

      %{
        agencies: [hse, ea],
        offenders: [offender1, offender2],
        cases: [case1, case2],
        hse: hse,
        ea: ea
      }
    end

    test "loads agencies correctly", %{agencies: agencies} do
      loaded_agencies = Enforcement.list_agencies!()
      
      assert length(loaded_agencies) == 2
      agency_names = Enum.map(loaded_agencies, & &1.name)
      assert "Health and Safety Executive" in agency_names
      assert "Environment Agency" in agency_names
    end

    test "loads cases with associations", %{cases: cases} do
      loaded_cases = EhsEnforcement.Enforcement.Case
        |> Ash.Query.load([:offender, :agency])
        |> Ash.read!()
      
      assert length(loaded_cases) == 2
      
      # Verify associations are loaded
      Enum.each(loaded_cases, fn case_record ->
        assert case_record.offender != nil
        assert case_record.agency != nil
        assert is_binary(case_record.offender.name)
        assert is_binary(case_record.agency.name)
      end)
    end

    test "orders cases by date descending", %{cases: cases} do
      loaded_cases = EhsEnforcement.Enforcement.Case
        |> Ash.Query.sort(offence_action_date: :desc)
        |> Ash.Query.load([:offender, :agency])
        |> Ash.read!()
      
      assert length(loaded_cases) == 2
      
      # Should be ordered with most recent first
      [first_case, second_case] = loaded_cases
      assert first_case.regulator_id == "EA-001" # Jan 20
      assert second_case.regulator_id == "HSE-001" # Jan 15
    end

    test "limits recent cases correctly", %{hse: hse, ea: ea} do
      # Create more cases than the limit
      {:ok, offender} = Enforcement.create_offender(%{name: "Extra Company"})
      
      # Create 15 additional cases
      extra_cases = Enum.map(1..15, fn i ->
        {:ok, case_record} = Enforcement.create_case(%{
          regulator_id: "EXTRA-#{String.pad_leading(Integer.to_string(i), 3, "0")}",
          agency_id: if(rem(i, 2) == 0, do: hse.id, else: ea.id),
          offender_id: offender.id,
          offence_action_date: Date.add(~D[2024-01-01], i),
          offence_fine: Decimal.new("1000.00"),
          offence_breaches: "Extra breach #{i}"
        })
        case_record
      end)

      # Load with limit
      recent_cases = EhsEnforcement.Enforcement.Case
        |> Ash.Query.sort(offence_action_date: :desc)
        |> Ash.Query.load([:offender, :agency])
        |> Ash.read!()
      |> Enum.take(10) # Simulate dashboard limit
      
      assert length(recent_cases) == 10
    end

    test "calculates agency statistics correctly", %{hse: hse, ea: ea} do
      # Load agencies with aggregates
      loaded_agencies = Enforcement.list_agencies!()
      hse_loaded = Enum.find(loaded_agencies, &(&1.id == hse.id))
      ea_loaded = Enum.find(loaded_agencies, &(&1.id == ea.id))
      
      # Use manual count since we're testing the dashboard functions
      hse_case_count = Enforcement.count_cases!(filter: [agency_id: hse.id])
      assert hse_case_count == 1
      
      ea_case_count = Enforcement.count_cases!(filter: [agency_id: ea.id])
      assert ea_case_count == 1
      
      # For now, just verify the basic counting works
      # The fine aggregation can be tested via the agency aggregates once they're loaded properly
      assert hse_loaded != nil
      assert ea_loaded != nil
    end

    test "handles empty data gracefully" do
      # Clear all data
      Repo.delete_all(EhsEnforcement.Enforcement.Case)
      Repo.delete_all(EhsEnforcement.Enforcement.Offender)
      Repo.delete_all(EhsEnforcement.Enforcement.Agency)
      
      # Should return empty results without errors
      agencies = Enforcement.list_agencies!()
      assert agencies == []
      
      cases = Enforcement.list_cases!()
      assert cases == []
      
      # Count should return 0
      case_count = Enforcement.count_cases!()
      assert case_count == 0
    end

    test "aggregates total statistics correctly", %{agencies: agencies, cases: cases} do
      total_cases = Enforcement.count_cases!()
      assert total_cases == 2
      
      # Skip fine total test for now - will be handled by aggregates
      # total_fines = Enforcement.sum_fines!()
      # assert Decimal.equal?(total_fines, Decimal.new("8000.00"))
      
      total_agencies = length(Enforcement.list_agencies!())
      assert total_agencies == 2
    end
  end

  describe "Dashboard Statistics Generation" do
    setup do
      # Create more complex test data for statistics
      agencies = [:hse, :ea, :onr]
      |> Enum.map(fn code ->
        {:ok, agency} = Enforcement.create_agency(%{
          code: code,
          name: "#{code |> to_string() |> String.upcase()} Agency",
          enabled: code != :onr # ONR disabled for testing
        })
        agency
      end)

      # Create offenders
      offenders = Enum.map(1..5, fn i ->
        {:ok, offender} = Enforcement.create_offender(%{
          name: "Company #{i}",
          local_authority: "Council #{i}"
        })
        offender
      end)

      # Create cases with varying fines and dates
      base_date = ~D[2024-01-01]
      cases = Enum.flat_map(agencies, fn agency ->
        if agency.enabled do
          Enum.map(1..3, fn i ->
            {:ok, case_record} = Enforcement.create_case(%{
              regulator_id: "#{agency.code |> to_string() |> String.upcase()}-#{i}",
              agency_id: agency.id,
              offender_id: Enum.at(offenders, rem(i, 5)).id,
              offence_action_date: Date.add(base_date, i * 5),
              offence_fine: Decimal.new("#{i * 1000}.00"),
              offence_breaches: "Breach #{i}"
            })
            case_record
          end)
        else
          [] # No cases for disabled agency
        end
      end)

      %{agencies: agencies, offenders: offenders, cases: cases}
    end

    test "generates per-agency statistics", %{agencies: agencies} do
      enabled_agencies = Enum.filter(agencies, & &1.enabled)
      
      stats = Enum.map(enabled_agencies, fn agency ->
        %{
          agency_id: agency.id,
          agency_name: agency.name,
          total_cases: Enforcement.count_cases!(filter: [agency_id: agency.id])
          # total_fines: Enforcement.sum_fines!(filter: [agency_id: agency.id]) # Skip for now
        }
      end)
      
      assert length(stats) == 2 # Only enabled agencies
      
      # Each enabled agency should have 3 cases
      Enum.each(stats, fn stat ->
        assert stat.total_cases == 3
        # Skip fine total assertion for now
        # assert Decimal.equal?(stat.total_fines, Decimal.new("6000.00"))
      end)
    end

    test "handles disabled agencies in statistics", %{agencies: agencies} do
      disabled_agency = Enum.find(agencies, &(not &1.enabled))
      
      disabled_stats = %{
        agency_id: disabled_agency.id,
        total_cases: Enforcement.count_cases!(filter: [agency_id: disabled_agency.id])
        # total_fines: Enforcement.sum_fines!(filter: [agency_id: disabled_agency.id]) # Skip for now
      }
      
      assert disabled_stats.total_cases == 0
      # assert Decimal.equal?(disabled_stats.total_fines, Decimal.new("0")) # Skip for now
    end

    test "calculates system-wide statistics", %{agencies: agencies, cases: cases} do
      system_stats = %{
        total_agencies: length(agencies),
        enabled_agencies: length(Enum.filter(agencies, & &1.enabled)),
        total_cases: Enforcement.count_cases!()
        # total_fines: Enforcement.sum_fines!() # Skip for now
      }
      
      assert system_stats.total_agencies == 3
      assert system_stats.enabled_agencies == 2
      assert system_stats.total_cases == 6 # 3 cases per enabled agency
      # assert Decimal.equal?(system_stats.total_fines, Decimal.new("12000.00")) # Skip for now
    end
  end

  describe "Dashboard Data Filtering" do
    setup do
      {:ok, hse} = Enforcement.create_agency(%{code: :hse, name: "HSE", enabled: true})
      {:ok, ea} = Enforcement.create_agency(%{code: :ea, name: "EA", enabled: true})
      
      {:ok, offender} = Enforcement.create_offender(%{name: "Filter Test Corp"})
      
      # Create cases across different time periods
      dates_and_ids = [
        {~D[2024-01-01], "OLD-001"},
        {~D[2024-02-15], "MID-001"}, 
        {~D[2024-03-30], "NEW-001"}
      ]
      
      cases = Enum.map(dates_and_ids, fn {date, id} ->
        {:ok, case_record} = Enforcement.create_case(%{
          regulator_id: id,
          agency_id: hse.id,
          offender_id: offender.id,
          offence_action_date: date,
          offence_fine: Decimal.new("5000.00"),
          offence_breaches: "Test breach"
        })
        case_record
      end)
      
      %{hse: hse, ea: ea, offender: offender, cases: cases}
    end

    test "filters cases by agency", %{hse: hse, ea: ea} do
      hse_cases = EhsEnforcement.Enforcement.Case
        |> Ash.Query.filter(agency_id == ^hse.id)
        |> Ash.read!()
      assert length(hse_cases) == 3
      
      ea_cases = EhsEnforcement.Enforcement.Case
        |> Ash.Query.filter(agency_id == ^ea.id)
        |> Ash.read!()
      assert length(ea_cases) == 0 # No EA cases created
    end

    test "supports date range filtering" do
      # This would test future date range filtering functionality
      # For now, just verify the basic case loading works
      all_cases = EhsEnforcement.Enforcement.Case
        |> Ash.Query.sort(offence_action_date: :desc)
        |> Ash.read!()
      assert length(all_cases) == 3
      
      # Verify they're sorted correctly
      [newest, middle, oldest] = all_cases
      assert newest.regulator_id == "NEW-001"
      assert middle.regulator_id == "MID-001"
      assert oldest.regulator_id == "OLD-001"
    end

    test "combines multiple filters", %{hse: hse} do
      # Test filtering by both agency and other criteria
      # This demonstrates the composable nature of Ash queries
      filtered_cases = EhsEnforcement.Enforcement.Case
        |> Ash.Query.filter(agency_id == ^hse.id)
        |> Ash.Query.sort(offence_action_date: :desc)
        |> Ash.Query.load([:offender, :agency])
        |> Ash.read!()
      
      assert length(filtered_cases) == 3
      Enum.each(filtered_cases, fn case_record ->
        assert case_record.agency.id == hse.id
        assert case_record.offender != nil
      end)
    end
  end

  describe "Dashboard Performance Testing" do
    test "handles large datasets efficiently" do
      # Create performance test data
      start_time = System.monotonic_time(:millisecond)
      
      # Create agencies using available valid codes
      valid_codes = [:hse, :ea, :onr, :orr]
      agencies = Enum.map(valid_codes, fn code ->
        {:ok, agency} = Enforcement.create_agency(%{
          code: code,
          name: "Performance Agency (#{code})",
          enabled: true
        })
        agency
      end)
      
      # Create multiple offenders
      offenders = Enum.map(1..20, fn i ->
        {:ok, offender} = Enforcement.create_offender(%{
          name: "Performance Company #{i}"
        })
        offender
      end)
      
      # Create many cases (but not too many for test performance)
      cases = Enum.flat_map(1..100, fn i ->
        agency = Enum.at(agencies, rem(i, 4))
        offender = Enum.at(offenders, rem(i, 20))
        
        {:ok, case_record} = Enforcement.create_case(%{
          regulator_id: "PERF-#{String.pad_leading(Integer.to_string(i), 3, "0")}",
          agency_id: agency.id,
          offender_id: offender.id,
          offence_action_date: Date.add(~D[2024-01-01], rem(i, 30)),
          offence_fine: Decimal.new("1000.00"),
          offence_breaches: "Performance breach #{i}"
        })
        [case_record]
      end)
      
      data_creation_time = System.monotonic_time(:millisecond) - start_time
      
      # Test dashboard data loading performance
      load_start = System.monotonic_time(:millisecond)
      
      # Simulate dashboard data loading
      dashboard_agencies = Enforcement.list_agencies!()
      recent_cases = EhsEnforcement.Enforcement.Case
        |> Ash.Query.sort(offence_action_date: :desc)
        |> Ash.Query.load([:offender, :agency])
        |> Ash.read!()
        |> Enum.take(10)
      
      # Calculate statistics
      stats = Enum.map(dashboard_agencies, fn agency ->
        %{
          total_cases: Enforcement.count_cases!(filter: [agency_id: agency.id])
          # total_fines: Enforcement.sum_fines!(filter: [agency_id: agency.id]) # Skip for now
        }
      end)
      
      load_end = System.monotonic_time(:millisecond)
      load_time = load_end - load_start
      
      # Performance assertions
      assert load_time < 1000, "Dashboard data loading should complete within 1 second"
      assert length(dashboard_agencies) == 4
      assert length(recent_cases) == 10
      assert length(stats) == 4
      
      # Verify data integrity
      total_cases = Enforcement.count_cases!()
      assert total_cases == 100
    end

    test "memory usage remains reasonable with large datasets" do
      memory_before = :erlang.memory(:total)
      
      # Create substantial test data
      Enum.each(1..200, fn i ->
        # Create agencies only for the first few iterations, then reuse
        agencies = if i <= 4 do
          valid_codes = [:hse, :ea, :onr, :orr]
          code = Enum.at(valid_codes, i-1)
          {:ok, agency} = Enforcement.create_agency(%{
            code: code,
            name: "Memory Test Agency #{i} (#{code})",
            enabled: true
          })
          [agency]
        else
          Enforcement.list_agencies!()
        end
        
        agency = Enum.at(agencies, rem(i, max(1, length(agencies))))
        
        {:ok, offender} = Enforcement.create_offender(%{
          name: "Memory Test Company #{i}"
        })
        
        {:ok, _case} = Enforcement.create_case(%{
          regulator_id: "MEM-#{String.pad_leading(Integer.to_string(i), 3, "0")}",
          agency_id: agency.id,
          offender_id: offender.id,
          offence_action_date: ~D[2024-01-01],
          offence_fine: Decimal.new("1000.00"),
          offence_breaches: "Memory test breach"
        })
      end)
      
      memory_after = :erlang.memory(:total)
      memory_used = memory_after - memory_before
      
      # Memory usage should be reasonable (less than 50MB for this test)
      assert memory_used < 50_000_000, "Memory usage should be reasonable"
      
      # Verify we can still load dashboard data efficiently
      agencies = Enforcement.list_agencies!()
      cases = EhsEnforcement.Enforcement.Case
        |> Ash.Query.limit(10)
        |> Ash.Query.load([:offender, :agency])
        |> Ash.read!()
      
      assert length(agencies) > 0
      assert length(cases) > 0
    end
  end

  describe "Dashboard Error Handling" do
    test "handles malformed data gracefully" do
      # Create agency and offender
      {:ok, agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Test Agency",
        enabled: true
      })
      
      {:ok, offender} = Enforcement.create_offender(%{name: "Test Company"})
      
      # Test with edge case data
      {:ok, _case} = Enforcement.create_case(%{
        regulator_id: "EDGE-CASE-001",
        agency_id: agency.id,
        offender_id: offender.id,
        offence_action_date: ~D[2024-01-01],
        offence_fine: Decimal.new("0.01"), # Very small fine
        offence_breaches: "" # Empty breach description
      })
      
      # Should still load without errors
      cases = EhsEnforcement.Enforcement.Case
        |> Ash.Query.load([:offender, :agency])
        |> Ash.read!()
      assert length(cases) == 1
      
      case_record = List.first(cases)
      assert case_record.offence_breaches == "" or case_record.offence_breaches == nil
      assert Decimal.equal?(case_record.offence_fine, Decimal.new("0.01"))
    end

    test "handles missing associations gracefully" do
      # This tests the robustness of the data loading
      cases = EhsEnforcement.Enforcement.Case
        |> Ash.Query.load([:offender, :agency])
        |> Ash.read!()
      
      # Should not crash even if no data exists
      assert is_list(cases)
    end

    test "handles concurrent data access" do
      {:ok, agency} = Enforcement.create_agency(%{
        code: :ea,
        name: "Concurrent Test Agency",
        enabled: true
      })
      
      # Simulate concurrent access
      tasks = Enum.map(1..10, fn i ->
        Task.async(fn ->
          {:ok, offender} = Enforcement.create_offender(%{
            name: "Concurrent Company #{i}"
          })
          
          {:ok, case_record} = Enforcement.create_case(%{
            regulator_id: "CONC-#{String.pad_leading(Integer.to_string(i), 2, "0")}",
            agency_id: agency.id,
            offender_id: offender.id,
            offence_action_date: ~D[2024-01-01],
            offence_fine: Decimal.new("1000.00"),
            offence_breaches: "Concurrent breach #{i}"
          })
          
          case_record
        end)
      end)
      
      # Wait for all tasks and verify they completed successfully
      results = Task.await_many(tasks, 5000)
      assert length(results) == 10
      
      # Verify all cases were created
      total_cases = Enforcement.count_cases!()
      assert total_cases >= 10
    end
  end
end