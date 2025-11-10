defmodule EhsEnforcementWeb.DashboardIntegrationTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Sync.SyncManager
  alias EhsEnforcement.Repo

  describe "Dashboard Integration Workflow" do
    setup do
      # Create comprehensive test data representing real-world scenario
      {:ok, hse} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, ea} =
        Enforcement.create_agency(%{
          code: :ea,
          name: "Environment Agency",
          enabled: true
        })

      {:ok, onr} =
        Enforcement.create_agency(%{
          code: :onr,
          name: "Office for Nuclear Regulation",
          # Test disabled agency
          enabled: false
        })

      # Create diverse offenders
      offenders =
        [
          %{name: "Manufacturing Corp Ltd", local_authority: "Birmingham", postcode: "B1 1AA"},
          %{name: "Chemical Industries PLC", local_authority: "Manchester", postcode: "M1 1BB"},
          %{name: "Construction Co", local_authority: "Leeds", postcode: "LS1 1CC"},
          %{name: "Waste Management Ltd", local_authority: "Bristol", postcode: "BS1 1DD"}
        ]
        |> Enum.map(fn attrs ->
          {:ok, offender} = Enforcement.create_offender(attrs)
          offender
        end)

      # Create realistic case data spanning different time periods
      base_date = ~D[2024-01-01]

      cases =
        [
          # Recent HSE cases
          %{
            agency: hse,
            offender: Enum.at(offenders, 0),
            date: Date.add(base_date, 20),
            fine: "15000.00",
            id: "HSE-2024-001",
            breach: "Failure to ensure workplace safety"
          },
          %{
            agency: hse,
            offender: Enum.at(offenders, 1),
            date: Date.add(base_date, 18),
            fine: "8500.00",
            id: "HSE-2024-002",
            breach: "Inadequate risk assessment"
          },
          %{
            agency: hse,
            offender: Enum.at(offenders, 0),
            date: Date.add(base_date, 15),
            fine: "22000.00",
            id: "HSE-2024-003",
            breach: "Multiple safety violations"
          },

          # Environment Agency cases
          %{
            agency: ea,
            offender: Enum.at(offenders, 2),
            date: Date.add(base_date, 19),
            fine: "12000.00",
            id: "EA-2024-001",
            breach: "Illegal waste disposal"
          },
          %{
            agency: ea,
            offender: Enum.at(offenders, 3),
            date: Date.add(base_date, 10),
            fine: "35000.00",
            id: "EA-2024-002",
            breach: "Water pollution incident"
          },

          # Older cases for timeline testing
          %{
            agency: hse,
            offender: Enum.at(offenders, 2),
            date: Date.add(base_date, -30),
            fine: "5000.00",
            id: "HSE-2023-099",
            breach: "Historic safety breach"
          }
        ]
        |> Enum.map(fn case_attrs ->
          {:ok, case_record} =
            Enforcement.create_case(%{
              regulator_id: case_attrs.id,
              agency_id: case_attrs.agency.id,
              offender_id: case_attrs.offender.id,
              offence_action_date: case_attrs.date,
              offence_fine: Decimal.new(case_attrs.fine),
              offence_breaches: case_attrs.breach,
              last_synced_at: DateTime.utc_now()
            })

          case_record
        end)

      %{
        agencies: [hse, ea, onr],
        offenders: offenders,
        cases: cases,
        hse: hse,
        ea: ea,
        onr: onr
      }
    end

    test "complete dashboard workflow with real data", %{
      conn: conn,
      agencies: agencies,
      cases: cases
    } do
      {:ok, view, html} = live(conn, "/dashboard")

      # 1. Initial Load - Verify all data loads correctly
      assert html =~ "EHS Enforcement Dashboard"

      # Agency cards should be present
      assert has_element?(view, "[data-testid='agency-card']", 3)

      # HSE should show 4 cases, £50,500 total (15000 + 8500 + 22000 + 5000)
      hse_card =
        element(
          view,
          "[data-testid='agency-card']:has(h3:fl-contains('Health and Safety Executive'))"
        )

      hse_content = render(hse_card)
      # Case count
      assert hse_content =~ "4"
      # Total fines
      assert hse_content =~ "50,500" or hse_content =~ "50500"

      # EA should show 2 cases, £47,000 total
      ea_card =
        element(view, "[data-testid='agency-card']:has(h3:fl-contains('Environment Agency'))")

      ea_content = render(ea_card)
      # Case count
      assert ea_content =~ "2"
      # Total fines
      assert ea_content =~ "47,000" or ea_content =~ "47000"

      # ONR (disabled) should show 0 cases
      onr_card =
        element(
          view,
          "[data-testid='agency-card']:has(h3:fl-contains('Office for Nuclear Regulation'))"
        )

      onr_content = render(onr_card)
      # Case count
      assert onr_content =~ "0"
      assert onr_content =~ "disabled" or onr_content =~ "Disabled"

      # 2. Recent Activity Timeline - Should show most recent cases first
      timeline = element(view, "[data-testid='recent-cases']") |> render()

      # Most recent cases should appear first
      # Jan 21 (most recent)
      assert timeline =~ "HSE-2024-001"
      # Jan 20
      assert timeline =~ "EA-2024-001"
      # Jan 19
      assert timeline =~ "HSE-2024-002"

      # Should include case details
      assert timeline =~ "Manufacturing Corp Ltd"
      assert timeline =~ "£15,000" or timeline =~ "15000"
      assert timeline =~ "Failure to ensure workplace safety"

      # 3. Statistics Summary
      # All cases across agencies
      assert html =~ "6 Total Cases"
      # Total fines
      assert html =~ "£97,500" or html =~ "97500"
      # Including disabled agency
      assert html =~ "3 Agencies"

      # 4. Verify timeline ordering
      case_positions =
        ["HSE-2024-001", "EA-2024-001", "HSE-2024-002", "HSE-2024-003"]
        |> Enum.map(fn id ->
          case :binary.match(timeline, id) do
            {pos, _} -> {id, pos}
            :nomatch -> {id, 99999}
          end
        end)
        |> Enum.sort_by(fn {_, pos} -> pos end)

      # Should be in chronological order (most recent first)
      expected_order = ["HSE-2024-001", "EA-2024-001", "HSE-2024-002", "HSE-2024-003"]
      actual_order = Enum.map(case_positions, fn {id, _} -> id end)
      assert actual_order == expected_order, "Cases should be ordered by date descending"
    end

    test "manual sync workflow integration", %{conn: conn, hse: hse} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # 1. Initial state - verify sync button is available
      sync_button = element(view, "[phx-click='sync_agency'][phx-value-agency='hse']")
      assert has_element?(sync_button)

      # 2. Mock sync operation (in real implementation, this would trigger actual sync)
      log =
        capture_log(fn ->
          render_click(view, "sync_agency", %{"agency" => "hse"})
        end)

      # 3. Verify sync was triggered without errors
      assert Process.alive?(view.pid)
      refute log =~ "error" or log =~ "Error"

      # 4. Simulate sync progress updates
      send(view.pid, {:sync_progress, "hse", 25})
      updated_html = render(view)
      assert updated_html =~ "25%" or updated_html =~ "Syncing" or updated_html =~ "In Progress"

      # 5. Simulate sync completion
      completion_time = DateTime.utc_now()
      send(view.pid, {:sync_complete, "hse", completion_time})
      final_html = render(view)
      assert final_html =~ "Complete" or final_html =~ "Success" or final_html =~ "Last Sync"

      # 6. Verify sync button is re-enabled
      assert has_element?(view, "[phx-click='sync_agency'][phx-value-agency='hse']")
    end

    test "real-time sync updates across multiple agencies", %{conn: conn, hse: hse, ea: ea} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # 1. Simulate simultaneous sync operations on different agencies
      send(view.pid, {:sync_progress, "hse", 0})
      send(view.pid, {:sync_progress, "ea", 0})

      # 2. Send progress updates
      send(view.pid, {:sync_progress, "hse", 30})
      send(view.pid, {:sync_progress, "ea", 60})

      html_during_sync = render(view)

      # Should show both agencies syncing
      assert html_during_sync =~ "30%" or html_during_sync =~ "Syncing"
      assert html_during_sync =~ "60%" or html_during_sync =~ "Syncing"

      # 3. Complete one sync, error on another
      send(view.pid, {:sync_complete, "hse", DateTime.utc_now()})
      send(view.pid, {:sync_error, "ea", "Connection timeout"})

      final_html = render(view)

      # HSE should show success
      hse_card =
        element(
          view,
          "[data-testid='agency-card']:has(h3:fl-contains('Health and Safety Executive'))"
        )

      hse_status = render(hse_card)
      assert hse_status =~ "Complete" or hse_status =~ "Success"

      # EA should show error
      ea_card =
        element(view, "[data-testid='agency-card']:has(h3:fl-contains('Environment Agency'))")

      ea_status = render(ea_card)
      assert ea_status =~ "Error" or ea_status =~ "Failed" or ea_status =~ "timeout"
    end

    test "dashboard data refresh after external data changes", %{conn: conn, hse: hse} do
      {:ok, view, initial_html} = live(conn, "/dashboard")

      # Initial state verification
      # HSE case count
      assert initial_html =~ "4"

      # Simulate external data change (e.g., from sync operation)
      {:ok, new_offender} =
        Enforcement.create_offender(%{
          name: "New Violation Company",
          local_authority: "London"
        })

      {:ok, _new_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-2024-NEW",
          agency_id: hse.id,
          offender_id: new_offender.id,
          # Most recent date
          offence_action_date: ~D[2024-01-25],
          offence_fine: Decimal.new("18000.00"),
          offence_breaches: "New safety violation",
          last_synced_at: DateTime.utc_now()
        })

      # Simulate data refresh (in real app, this might be via PubSub or periodic refresh)
      send(view.pid, {:data_updated, "hse"})

      # Navigate away and back to trigger reload (simulating refresh)
      {:ok, view, updated_html} = live(conn, "/dashboard")

      # Should show updated data
      hse_card =
        element(
          view,
          "[data-testid='agency-card']:has(h3:fl-contains('Health and Safety Executive'))"
        )

      hse_content = render(hse_card)
      # Updated case count
      assert hse_content =~ "5"

      # New case should appear in recent activity
      timeline = element(view, "[data-testid='recent-cases']") |> render()
      assert timeline =~ "HSE-2024-NEW"
      assert timeline =~ "New Violation Company"
      assert timeline =~ "£18,000" or timeline =~ "18000"
    end

    test "error handling and recovery workflow", %{conn: conn} do
      # Test various error scenarios and recovery

      # 1. Database connection issues (simulated)
      {:ok, view, html} = live(conn, "/dashboard")
      assert html =~ "EHS Enforcement Dashboard"

      # 2. Invalid sync request
      log =
        capture_log(fn ->
          render_click(view, "sync", %{"agency" => "invalid_agency"})
        end)

      # Should handle gracefully
      assert Process.alive?(view.pid)

      # 3. Malformed PubSub messages
      capture_log(fn ->
        send(view.pid, {:invalid_message, "bad_data"})
        send(view.pid, "not_a_tuple")
        send(view.pid, {:sync_progress, nil, nil})
        :timer.sleep(50)
      end)

      # Should remain stable
      assert Process.alive?(view.pid)

      # Should still respond to valid interactions
      updated_html = render(view)
      assert updated_html =~ "Health and Safety Executive"
    end

    test "performance with large dataset workflow", %{conn: conn} do
      # Create larger dataset to test performance
      start_time = System.monotonic_time(:millisecond)

      # Add more agencies
      additional_agencies =
        Enum.map(1..10, fn i ->
          {:ok, agency} =
            Enforcement.create_agency(%{
              code: String.to_atom("agency_#{i}"),
              name: "Test Agency #{i}",
              # Mix of enabled/disabled
              enabled: rem(i, 3) != 0
            })

          agency
        end)

      # Add more offenders
      additional_offenders =
        Enum.map(1..20, fn i ->
          {:ok, offender} =
            Enforcement.create_offender(%{
              name: "Company #{i}",
              local_authority: "Council #{i}"
            })

          offender
        end)

      # Add more cases (but not too many to avoid test timeout)
      Enum.each(1..50, fn i ->
        agency = Enum.at(additional_agencies, rem(i, 10))
        offender = Enum.at(additional_offenders, rem(i, 20))

        {:ok, _} =
          Enforcement.create_case(%{
            regulator_id: "PERF-#{i}",
            agency_id: agency.id,
            offender_id: offender.id,
            offence_action_date: Date.add(~D[2024-01-01], rem(i, 30)),
            offence_fine: Decimal.new("#{rem(i, 10) + 1}000.00"),
            offence_breaches: "Performance test breach #{i}",
            last_synced_at: DateTime.utc_now()
          })
      end)

      load_start = System.monotonic_time(:millisecond)
      {:ok, view, html} = live(conn, "/dashboard")
      load_end = System.monotonic_time(:millisecond)

      load_time = load_end - load_start
      total_time = load_end - start_time

      # Performance assertions
      assert load_time < 2000, "Dashboard should load within 2 seconds"
      # Original 3 + 10 new
      assert html =~ "13 Agencies"
      # Original 6 + 50 new
      assert html =~ "56 Total Cases"

      # Recent cases should still be limited to 10
      timeline = element(view, "[data-testid='recent-cases']") |> render()
      case_count = timeline |> String.split("PERF-") |> length()
      # 10 cases + 1 for the split
      assert case_count <= 11

      # Navigation should remain responsive
      nav_start = System.monotonic_time(:millisecond)
      render_click(view, "sync", %{"agency" => "agency_1"})
      nav_end = System.monotonic_time(:millisecond)

      nav_time = nav_end - nav_start
      assert nav_time < 500, "Navigation should be responsive even with large datasets"
    end

    test "accessibility and usability workflow", %{conn: conn} do
      {:ok, view, html} = live(conn, "/dashboard")

      # 1. Verify semantic HTML structure
      assert html =~ "<main>" or html =~ "role=\"main\""
      # Proper heading hierarchy
      assert html =~ "<h1>" or html =~ "<h2>"

      # 2. Check ARIA labels and accessibility attributes
      assert html =~ "aria-label" or html =~ "aria-describedby"

      # 3. Verify keyboard navigation support
      # Buttons should be focusable
      assert has_element?(view, "button[phx-click]")

      # 4. Check screen reader friendly content
      agency_cards = element(view, "[data-testid='agency-card']", :all) |> render()
      assert agency_cards =~ "aria-label" or agency_cards =~ "role"

      # 5. Verify color contrast and visual indicators
      # (This would typically be tested with browser automation tools)
      assert html =~ "status" or html =~ "indicator"

      # 6. Test with keyboard navigation simulation
      # In a real test, you'd simulate tab navigation and enter key presses
      # For now, verify the structure supports it
      sync_buttons = view |> element("[phx-click='sync_agency']")
      assert has_element?(sync_buttons)
    end

    test "mobile responsiveness workflow", %{conn: conn} do
      {:ok, view, html} = live(conn, "/dashboard")

      # 1. Verify responsive CSS classes are present
      assert html =~ "sm:" or html =~ "md:" or html =~ "lg:" or html =~ "xl:"

      # 2. Check for mobile-friendly layout
      assert html =~ "grid" or html =~ "flex"
      assert html =~ "col-span" or html =~ "w-full"

      # 3. Verify touch-friendly button sizes
      # (In real testing, this would check computed styles)
      sync_buttons = view |> element("[phx-click='sync_agency']") |> render()
      # Adequate padding
      assert sync_buttons =~ "p-" or sync_buttons =~ "py-"

      # 4. Check for mobile navigation patterns
      # Scrollable content
      assert html =~ "overflow-" or html =~ "scroll"
    end
  end

  describe "Dashboard Cross-Browser Compatibility" do
    # Note: These tests would typically require browser automation tools
    # like Wallaby or Hound for full cross-browser testing

    test "JavaScript-free graceful degradation", %{conn: conn} do
      # Test that basic functionality works without JavaScript
      {:ok, view, html} = live(conn, "/dashboard")

      # Core content should be visible
      assert html =~ "EHS Enforcement Dashboard"
      assert html =~ "Health and Safety Executive"

      # Forms should have proper action attributes for non-JS fallback
      # (In real implementation, this would test server-side form handling)
      assert Process.alive?(view.pid)
    end
  end

  describe "Dashboard Data Consistency" do
    test "data consistency across multiple page loads", %{conn: conn, cases: cases} do
      # Load dashboard multiple times and verify consistent data
      results =
        Enum.map(1..5, fn _ ->
          {:ok, view, html} = live(conn, "/dashboard")

          # Extract key metrics
          case_count = (html |> String.split("Total Cases") |> length()) - 1
          agency_count = (html |> String.split("Agencies") |> length()) - 1

          %{case_count: case_count, agency_count: agency_count, html: html}
        end)

      # All results should be consistent
      first_result = List.first(results)

      Enum.each(results, fn result ->
        assert result.case_count == first_result.case_count
        assert result.agency_count == first_result.agency_count
        assert result.html =~ "Health and Safety Executive"
      end)
    end

    test "data integrity during concurrent operations", %{conn: conn, hse: hse} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Simulate concurrent sync operations
      tasks =
        Enum.map(1..5, fn i ->
          Task.async(fn ->
            send(view.pid, {:sync_progress, "hse", i * 20})
            :timer.sleep(10)
            send(view.pid, {:sync_complete, "hse", DateTime.utc_now()})
          end)
        end)

      # Wait for all tasks to complete
      Task.await_many(tasks, 1000)

      # Dashboard should remain stable
      assert Process.alive?(view.pid)

      final_html = render(view)
      assert final_html =~ "Health and Safety Executive"
    end
  end
end
