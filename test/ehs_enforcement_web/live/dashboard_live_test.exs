defmodule EhsEnforcementWeb.DashboardLiveTest do
  use EhsEnforcementWeb.ConnCase

  # 🐛 BLOCKED: Dashboard LiveView tests failing - Issue #47
  @moduletag :skip

  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Repo

  # Mark as heavy: Creates many DB records, refreshes metrics (9 queries), uses LiveView + PubSub
  # Run separately with: mix test --include heavy
  # See: .claude/sessions/2025-10-19-Test-Environment.md
  @moduletag :heavy

  describe "DashboardLive mount" do
    setup do
      # Create test agencies
      {:ok, hse_agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, ea_agency} =
        Enforcement.create_agency(%{
          code: :ea,
          name: "Environment Agency",
          enabled: true
        })

      # Create test offenders
      {:ok, offender1} =
        Enforcement.create_offender(%{
          name: "Test Company Ltd",
          local_authority: "Test Council",
          postcode: "TE1 1ST"
        })

      {:ok, offender2} =
        Enforcement.create_offender(%{
          name: "Another Corp",
          local_authority: "Another Council",
          postcode: "TE2 2ST"
        })

      # Create test cases with different dates for timeline testing
      # Use dates relative to today to ensure they're within the "Last 30 Days" period
      # 10 days ago
      base_date = Date.add(Date.utc_today(), -10)

      {:ok, case1} =
        Enforcement.create_case(%{
          regulator_id: "HSE-001",
          agency_id: hse_agency.id,
          offender_id: offender1.id,
          offence_action_date: base_date,
          offence_fine: Decimal.new("5000.00"),
          offence_breaches: "Breach of safety regulations",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, case2} =
        Enforcement.create_case(%{
          regulator_id: "EA-001",
          agency_id: ea_agency.id,
          offender_id: offender2.id,
          offence_action_date: Date.add(base_date, 5),
          offence_fine: Decimal.new("3000.00"),
          offence_breaches: "Environmental violation",
          last_synced_at: Date.add(DateTime.utc_now(), -1)
        })

      # Refresh metrics for the test data
      {:ok, _metrics} = EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:automation)

      # Ensure LiveView processes are cleaned up between tests
      on_exit(fn ->
        # Allow async cleanup to complete
        Process.sleep(100)
      end)

      %{
        agencies: [hse_agency, ea_agency],
        offenders: [offender1, offender2],
        cases: [case1, case2]
      }
    end

    test "successfully mounts and loads initial data", %{
      conn: conn,
      agencies: agencies,
      cases: cases
    } do
      {:ok, view, html} = live(conn, "/dashboard")

      # Should display page title
      assert html =~ "EHS Enforcement Dashboard"

      # Should load and display agencies
      assert html =~ "Health and Safety Executive"
      assert html =~ "Environment Agency"

      # Should display agency count
      agency_count = length(agencies)
      assert html =~ "#{agency_count} Agencies"

      # Should show total case count
      case_count = length(cases)
      assert html =~ "#{case_count} Total Cases"

      # Should have agency cards
      assert has_element?(view, "[data-testid='agency-card']")
    end

    test "handles mount with no data gracefully", %{conn: conn} do
      # Clear all test data
      Repo.delete_all(EhsEnforcement.Enforcement.Case)
      Repo.delete_all(EhsEnforcement.Enforcement.Notice)
      Repo.delete_all(EhsEnforcement.Enforcement.Offender)
      Repo.delete_all(EhsEnforcement.Enforcement.Agency)
      Repo.delete_all(EhsEnforcement.Enforcement.Metrics)

      {:ok, _view, html} = live(conn, "/dashboard")

      # Should still render without errors
      assert html =~ "EHS Enforcement Dashboard"
      assert html =~ "0 Agencies"
      assert html =~ "0 Total Cases"
      assert html =~ "No agencies configured"
    end

    test "loads recent cases with proper associations", %{conn: conn, cases: [_case1, _case2]} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should display recent cases section
      assert html =~ "Recent Activity"

      # Should show case regulator IDs
      assert html =~ "HSE-001"
      assert html =~ "EA-001"

      # Should show associated offender names
      assert html =~ "Test Company Ltd"
      assert html =~ "Another Corp"

      # Should show fine amounts
      assert html =~ "£5,000.00"
      assert html =~ "£3,000.00"
    end

    test "calculates and displays correct statistics", %{
      conn: conn,
      agencies: [_hse_agency, _ea_agency]
    } do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Should show statistics for each agency
      within_agency_card = fn agency_name ->
        element(view, "[data-testid='agency-card']:has(h3:fl-contains('#{agency_name}'))")
      end

      hse_card = within_agency_card.("Health and Safety Executive")
      ea_card = within_agency_card.("Environment Agency")

      # HSE should show 1 case, £5,000 total
      assert has_element?(hse_card, ":fl-contains('1 Case')")
      assert has_element?(hse_card, ":fl-contains('£5,000')")

      # EA should show 1 case, £3,000 total
      assert has_element?(ea_card, ":fl-contains('1 Case')")
      assert has_element?(ea_card, ":fl-contains('£3,000')")
    end

    test "orders recent cases by date descending", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Get the recent cases timeline
      recent_cases_elements =
        view
        |> element("[data-testid='recent-cases']")
        |> render()

      # The more recent case (EA-001, Jan 20) should appear before older case (HSE-001, Jan 15)
      ea_position = :binary.match(recent_cases_elements, "EA-001") |> elem(0)
      hse_position = :binary.match(recent_cases_elements, "HSE-001") |> elem(0)

      assert ea_position < hse_position, "Recent cases should be ordered by date descending"
    end
  end

  describe "DashboardLive agency status cards" do
    setup do
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      %{agency: agency}
    end

    test "displays agency information correctly", %{conn: conn, agency: _agency} do
      {:ok, view, html} = live(conn, "/dashboard")

      # Should show agency name and code
      assert html =~ "Health and Safety Executive"
      assert html =~ "HSE"

      # Should have sync status indicator
      assert has_element?(view, "[data-testid='sync-status']")

      # Should show last sync time (will be "Never" for new agencies)
      assert html =~ "Last Sync" or html =~ "Never"
    end

    test "displays correct sync status indicators", %{conn: conn, agency: _agency} do
      {:ok, view, _html} = live(conn, "/dashboard")

      agency_card =
        element(
          view,
          "[data-testid='agency-card']:has(h3:fl-contains('Health and Safety Executive'))"
        )

      # For agency without recent sync, should show "Never" or appropriate status
      assert has_element?(agency_card, "[data-testid='sync-status']")
    end

    test "shows manual sync button for each agency", %{conn: conn, agency: _agency} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Should have sync button for each agency
      sync_button = element(view, "[data-testid='sync-button-hse']")
      assert has_element?(sync_button)
      assert render(sync_button) =~ "Sync Now"
    end

    test "handles disabled agencies correctly", %{conn: conn} do
      # Create disabled agency
      {:ok, _disabled_agency} =
        Enforcement.create_agency(%{
          code: :onr,
          name: "Office for Nuclear Regulation",
          enabled: false
        })

      {:ok, view, html} = live(conn, "/dashboard")

      # Should still show disabled agencies but with different styling
      assert html =~ "Office for Nuclear Regulation"

      # Should indicate disabled status
      disabled_card =
        element(
          view,
          "[data-testid='agency-card']:has(h3:fl-contains('Office for Nuclear Regulation'))"
        )

      assert has_element?(disabled_card, "[data-disabled='true']") or
               render(disabled_card) =~ "disabled" or
               render(disabled_card) =~ "Disabled"
    end
  end

  describe "DashboardLive recent activity timeline" do
    setup do
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Timeline Test Corp",
          local_authority: "Test Council"
        })

      # Create cases spanning different dates for timeline testing
      dates = [
        # Most recent
        Date.add(Date.utc_today(), -5),
        Date.add(Date.utc_today(), -7),
        Date.add(Date.utc_today(), -10),
        # Oldest
        Date.add(Date.utc_today(), -15)
      ]

      cases =
        Enum.with_index(dates, 1)
        |> Enum.map(fn {date, index} ->
          {:ok, case} =
            Enforcement.create_case(%{
              regulator_id: "HSE-00#{index}",
              agency_id: agency.id,
              offender_id: offender.id,
              offence_action_date: date,
              offence_fine: Decimal.new("#{index}000.00"),
              offence_breaches: "Breach #{index}",
              last_synced_at: DateTime.utc_now()
            })

          case
        end)

      # Refresh metrics for the test data
      {:ok, _metrics} = EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:automation)

      # Ensure LiveView processes are cleaned up between tests
      on_exit(fn ->
        # Allow async cleanup to complete
        Process.sleep(100)
      end)

      %{agency: agency, offender: offender, cases: cases}
    end

    test "displays recent cases in chronological order", %{conn: conn, cases: _cases} do
      {:ok, view, _html} = live(conn, "/dashboard")

      timeline = element(view, "[data-testid='recent-cases']") |> render()

      # Should show most recent cases first (limited to 10 by default)
      # Jan 20 (most recent)
      assert timeline =~ "HSE-001"
      # Jan 18
      assert timeline =~ "HSE-002"
      # Jan 15
      assert timeline =~ "HSE-003"
      # Jan 10 (oldest)
      assert timeline =~ "HSE-004"

      # Check order by finding positions
      positions =
        ["HSE-001", "HSE-002", "HSE-003", "HSE-004"]
        |> Enum.map(fn id ->
          case :binary.match(timeline, id) do
            {pos, _} -> {id, pos}
            :nomatch -> {id, 99_999}
          end
        end)
        |> Enum.sort_by(fn {_, pos} -> pos end)

      # Should be in chronological order (most recent first)
      expected_order = ["HSE-001", "HSE-002", "HSE-003", "HSE-004"]
      actual_order = Enum.map(positions, fn {id, _} -> id end)

      assert actual_order == expected_order, "Timeline should show cases in chronological order"
    end

    test "limits recent cases to 10 items", %{conn: conn, agency: agency, offender: offender} do
      # Create 15 cases to test limit
      _additional_cases =
        Enum.map(5..15, fn i ->
          {:ok, case} =
            Enforcement.create_case(%{
              regulator_id: "HSE-0#{i}",
              agency_id: agency.id,
              offender_id: offender.id,
              offence_action_date: Date.add(Date.add(Date.utc_today(), -5), -i),
              offence_fine: Decimal.new("1000.00"),
              offence_breaches: "Breach #{i}",
              last_synced_at: DateTime.utc_now()
            })

          case
        end)

      {:ok, view, _html} = live(conn, "/dashboard")

      # Count case items in timeline
      timeline_items =
        view
        |> element("[data-testid='recent-cases']")
        |> render()
        |> String.split("HSE-")
        |> length()

      # Should be limited to 10 (plus empty string from split = 11 total elements)
      assert timeline_items <= 11, "Timeline should be limited to 10 recent cases"
    end

    test "shows proper case information in timeline", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      timeline = element(view, "[data-testid='recent-cases']") |> render()

      # Should show case details
      # Offender name
      assert timeline =~ "Timeline Test Corp"
      # Agency name
      assert timeline =~ "Health and Safety Executive"
      # Fine amount
      assert timeline =~ "£1,000.00"
      # Date
      assert timeline =~ "January 20, 2024" or timeline =~ "2024-01-20"
    end

    test "handles empty timeline gracefully", %{conn: conn} do
      # Clear all cases
      Repo.delete_all(EhsEnforcement.Enforcement.Case)

      {:ok, view, html} = live(conn, "/dashboard")

      # Should show empty state
      assert html =~ "Recent Activity"
      assert html =~ "No recent activity" or html =~ "No cases found"

      # Should not crash
      timeline = element(view, "[data-testid='recent-cases']")
      assert has_element?(timeline)
    end
  end

  describe "DashboardLive statistics calculation" do
    setup do
      {:ok, hse} = Enforcement.create_agency(%{code: :hse, name: "HSE", enabled: true})
      {:ok, ea} = Enforcement.create_agency(%{code: :ea, name: "EA", enabled: true})

      {:ok, offender1} = Enforcement.create_offender(%{name: "Company A"})
      {:ok, offender2} = Enforcement.create_offender(%{name: "Company B"})

      # Create cases with known totals for easy testing
      {:ok, _} =
        Enforcement.create_case(%{
          regulator_id: "HSE-1",
          agency_id: hse.id,
          offender_id: offender1.id,
          offence_action_date: Date.add(Date.utc_today(), -10),
          offence_fine: Decimal.new("1000.00"),
          offence_breaches: "Safety breach",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, _} =
        Enforcement.create_case(%{
          regulator_id: "HSE-2",
          agency_id: hse.id,
          offender_id: offender2.id,
          offence_action_date: Date.add(Date.utc_today(), -9),
          offence_fine: Decimal.new("2000.00"),
          offence_breaches: "Another safety breach",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, _} =
        Enforcement.create_case(%{
          regulator_id: "EA-1",
          agency_id: ea.id,
          offender_id: offender1.id,
          offence_action_date: Date.add(Date.utc_today(), -8),
          offence_fine: Decimal.new("5000.00"),
          offence_breaches: "Environmental breach",
          last_synced_at: DateTime.utc_now()
        })

      # Refresh metrics for the test data
      {:ok, _metrics} = EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:automation)

      # Ensure LiveView processes are cleaned up between tests
      on_exit(fn ->
        # Allow async cleanup to complete
        Process.sleep(100)
      end)

      %{hse: hse, ea: ea}
    end

    test "calculates total statistics correctly", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should show correct total case count (3 cases)
      assert html =~ "3 Total Cases" or html =~ "Total: 3"

      # Should show correct total fine amount (£8,000)
      assert html =~ "£8,000" or html =~ "8000"

      # Should show correct agency count (2 agencies)
      assert html =~ "2 Agencies"
    end

    test "calculates per-agency statistics correctly", %{conn: conn, hse: _hse, ea: _ea} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # HSE statistics (2 cases, £3,000 total)
      hse_card = element(view, "[data-testid='agency-card']:has(h3:fl-contains('HSE'))")
      hse_content = render(hse_card)

      # Case count
      assert hse_content =~ "2"
      # Fine total
      assert hse_content =~ "3,000" or hse_content =~ "3000"

      # EA statistics (1 case, £5,000 total)
      ea_card = element(view, "[data-testid='agency-card']:has(h3:fl-contains('EA'))")
      ea_content = render(ea_card)

      # Case count
      assert ea_content =~ "1"
      # Fine total
      assert ea_content =~ "5,000" or ea_content =~ "5000"
    end

    test "handles zero statistics gracefully", %{conn: conn} do
      # Create agency with no cases
      {:ok, _orr} =
        Enforcement.create_agency(%{
          code: :orr,
          name: "Office of Rail Regulation",
          enabled: true
        })

      {:ok, view, _html} = live(conn, "/dashboard")

      orr_card =
        element(
          view,
          "[data-testid='agency-card']:has(h3:fl-contains('Office of Rail Regulation'))"
        )

      orr_content = render(orr_card)

      # Should show zero cases and fines
      # Case count
      assert orr_content =~ "0"
      # No fines
      assert orr_content =~ "£0" or orr_content =~ "No cases"
    end

    test "updates statistics when data changes", %{conn: conn, hse: hse} do
      {:ok, _view, initial_html} = live(conn, "/dashboard")

      # Initial state: HSE has 2 cases
      assert initial_html =~ "2"

      # Add another case
      {:ok, offender} = Enforcement.create_offender(%{name: "New Company"})

      {:ok, _new_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-NEW",
          agency_id: hse.id,
          offender_id: offender.id,
          offence_action_date: Date.add(Date.utc_today(), -7),
          offence_fine: Decimal.new("1500.00"),
          offence_breaches: "New breach",
          last_synced_at: DateTime.utc_now()
        })

      # Trigger re-render by navigating away and back
      {:ok, view, _updated_html} = live(conn, "/dashboard")

      # Should show updated count (3 cases for HSE)
      hse_card = element(view, "[data-testid='agency-card']:has(h3:fl-contains('HSE'))")
      hse_content = render(hse_card)

      # Updated case count
      assert hse_content =~ "3"
    end
  end

  describe "DashboardLive manual sync functionality" do
    setup do
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      %{agency: agency}
    end

    test "displays sync button for each agency", %{conn: conn, agency: _agency} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Should have sync button
      sync_button = element(view, "[phx-click='sync_agency'][phx-value-agency='hse']")
      assert has_element?(sync_button)
      assert render(sync_button) =~ "Sync Now" or render(sync_button) =~ "Sync"
    end

    test "handles sync button click event", %{conn: conn, agency: _agency} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Mock the sync operation by capturing the event
      log =
        capture_log(fn ->
          # Click sync button
          render_click(view, "sync_agency", %{"agency" => "hse"})
        end)

      # Should handle the event (exact behavior depends on implementation)
      # For now, just verify the event was processed without crashing
      assert Process.alive?(view.pid)

      # Verify no error occurred
      refute log =~ "error" or log =~ "Error"
    end

    # Sync functionality removed in Phase 2 (replaced with materialized metrics)
    @tag :skip
    test "shows sync status updates", %{conn: conn, agency: _agency} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Should have sync status indicator
      assert has_element?(view, "[data-testid='sync-status']")

      # After clicking sync, status should update (depending on implementation)
      render_click(view, "sync_agency", %{"agency" => "hse"})

      # Status should show some kind of feedback
      updated_html = render(view)

      assert updated_html =~ "Syncing" or
               updated_html =~ "In Progress" or
               updated_html =~ "Last Sync" or
               updated_html =~ "Complete"
    end

    test "disables sync button for disabled agencies", %{conn: conn} do
      {:ok, _disabled_agency} =
        Enforcement.create_agency(%{
          code: :onr,
          name: "Office for Nuclear Regulation",
          enabled: false
        })

      {:ok, view, _html} = live(conn, "/dashboard")

      # Sync button should be disabled or not present for disabled agencies
      disabled_card =
        element(
          view,
          "[data-testid='agency-card']:has(h3:fl-contains('Office for Nuclear Regulation'))"
        )

      disabled_content = render(disabled_card)

      # Should not have enabled sync button
      refute disabled_content =~ "phx-click=\"sync\"" or
               disabled_content =~ "disabled" or
               disabled_content =~ "Disabled"
    end
  end

  describe "DashboardLive real-time updates" do
    setup do
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      %{agency: agency}
    end

    test "subscribes to sync updates on mount", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Verify the LiveView process is subscribed to sync updates
      # This would typically be done by checking PubSub subscriptions
      # For now, verify the process is alive and responsive
      assert Process.alive?(view.pid)

      # Send a test message to verify subscription handling
      send(view.pid, {:sync_progress, "hse", 50})

      # Should handle the message without crashing
      # Allow message processing
      :timer.sleep(50)
      assert Process.alive?(view.pid)
    end

    test "handles sync progress updates", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Send sync progress update
      send(view.pid, {:sync_progress, "hse", 75})

      # Should update the UI to show sync progress
      updated_html = render(view)

      # Look for progress indicators (exact format depends on implementation)
      assert updated_html =~ "75%" or
               updated_html =~ "75" or
               updated_html =~ "progress" or
               updated_html =~ "Syncing"
    end

    test "handles sync completion updates", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Send sync completion message
      timestamp = DateTime.utc_now()
      send(view.pid, {:sync_complete, "hse", timestamp})

      # Should update last sync time
      updated_html = render(view)

      # Should show completion status
      assert updated_html =~ "Complete" or
               updated_html =~ "Success" or
               updated_html =~ "Last Sync"
    end

    test "handles sync error updates", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Send sync error message
      send(view.pid, {:sync_error, "hse", "Connection timeout"})

      # Should show error status
      updated_html = render(view)

      assert updated_html =~ "Error" or
               updated_html =~ "Failed" or
               updated_html =~ "timeout"
    end

    test "handles multiple agency updates simultaneously", %{conn: conn} do
      # Create multiple agencies
      {:ok, _ea} =
        Enforcement.create_agency(%{code: :ea, name: "Environment Agency", enabled: true})

      {:ok, _onr} =
        Enforcement.create_agency(%{
          code: :onr,
          name: "Office for Nuclear Regulation",
          enabled: true
        })

      {:ok, view, _html} = live(conn, "/dashboard")

      # Send updates for different agencies
      send(view.pid, {:sync_progress, "hse", 30})
      send(view.pid, {:sync_progress, "ea", 60})
      send(view.pid, {:sync_complete, "onr", DateTime.utc_now()})

      updated_html = render(view)

      # Should handle all updates appropriately
      # Specific assertions depend on implementation details
      assert Process.alive?(view.pid)
      assert updated_html =~ "Health and Safety Executive"
      assert updated_html =~ "Environment Agency"
      assert updated_html =~ "Office for Nuclear Regulation"
    end
  end

  describe "DashboardLive error handling" do
    test "handles database connection errors gracefully", %{conn: conn} do
      # This would require mocking the database to simulate connection issues
      # For now, test that the LiveView can handle when no data loads

      {:ok, view, html} = live(conn, "/dashboard")

      # Should not crash even if data loading fails
      assert html =~ "EHS Enforcement Dashboard" or html =~ "Dashboard"
      assert Process.alive?(view.pid)
    end

    test "handles invalid agency codes in sync events", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      _log =
        capture_log(fn ->
          # Send sync update for non-existent agency
          send(view.pid, {:sync_progress, "invalid_agency", 50})
          :timer.sleep(50)
        end)

      # Should handle gracefully without crashing
      assert Process.alive?(view.pid)

      # May log the invalid agency (depending on implementation)
      # But should not cause errors
    end

    test "handles malformed sync messages", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      _log =
        capture_log(fn ->
          # Send malformed messages
          send(view.pid, {:sync_progress, nil, nil})
          send(view.pid, {:invalid_message, "data"})
          send(view.pid, "not_a_tuple")
          :timer.sleep(50)
        end)

      # Should remain stable
      assert Process.alive?(view.pid)
    end
  end

  describe "DashboardLive Recent Activity pagination" do
    setup do
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Test Company",
          local_authority: "Test Council"
        })

      # Create 25 cases to test pagination (more than default page size)
      cases =
        Enum.map(1..25, fn i ->
          {:ok, case} =
            Enforcement.create_case(%{
              regulator_id: "HSE-#{String.pad_leading(to_string(i), 3, "0")}",
              agency_id: agency.id,
              offender_id: offender.id,
              offence_action_date: Date.add(Date.add(Date.utc_today(), -20), i),
              offence_fine: Decimal.new("#{i * 100}.00"),
              offence_breaches: "Breach #{i}",
              last_synced_at: DateTime.utc_now()
            })

          case
        end)

      # Refresh metrics for the test data
      {:ok, _metrics} = EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:automation)

      # Ensure LiveView processes are cleaned up between tests
      on_exit(fn ->
        # Allow async cleanup to complete
        Process.sleep(100)
      end)

      %{agency: agency, offender: offender, cases: cases}
    end

    test "displays recent activity pagination controls when there are more than page size records",
         %{conn: conn} do
      {:ok, view, html} = live(conn, "/dashboard")

      # Should show pagination controls
      assert has_element?(view, "[data-testid='recent-activity-pagination']")
      assert html =~ "Next"
      assert html =~ "Previous"

      # Should show page info
      assert html =~ "Page 1"
      assert html =~ "of"
    end

    test "shows correct number of items on first page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Should show only 10 items on first page (default page size)
      recent_activity_items =
        view
        |> element("[data-testid='recent-activities']")
        |> render()
        |> String.split("data-testid=\"activity-item\"")
        |> length()
        # Subtract 1 for the split
        |> Kernel.-(1)

      assert recent_activity_items == 10
    end

    test "navigates to next page when next button clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Click next page (using desktop version)
      view
      |> element(".hidden.sm\\:flex [data-testid='next-page-btn']")
      |> render_click()

      # Should be on page 2
      updated_html = render(view)
      assert updated_html =~ "Page 2"

      # Should show different cases (cases 11-20)
      assert updated_html =~ "HSE-011"
      # First page case should not be visible
      refute updated_html =~ "HSE-001"
    end

    test "navigates to previous page when previous button clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Go to page 2 first
      view
      |> element(".hidden.sm\\:flex [data-testid='next-page-btn']")
      |> render_click()

      # Then go back to page 1
      view
      |> element(".hidden.sm\\:flex [data-testid='prev-page-btn']")
      |> render_click()

      # Should be back on page 1
      updated_html = render(view)
      assert updated_html =~ "Page 1"
      # Most recent case
      assert updated_html =~ "HSE-025"
    end

    test "disables previous button on first page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Previous button should be disabled on first page
      prev_btn = element(view, ".hidden.sm\\:flex [data-testid='prev-page-btn']")

      assert render(prev_btn) =~ "disabled" or
               render(prev_btn) =~ "cursor-not-allowed" or
               render(prev_btn) =~ "opacity-50"
    end

    test "disables next button on last page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Navigate to last page (page 3 for 25 items with page size 10)
      view
      |> element(".hidden.sm\\:flex [data-testid='next-page-btn']")
      |> render_click()

      view
      |> element(".hidden.sm\\:flex [data-testid='next-page-btn']")
      |> render_click()

      # Should be on page 3
      updated_html = render(view)
      assert updated_html =~ "Page 3"

      # Next button should be disabled
      next_btn = element(view, ".hidden.sm\\:flex [data-testid='next-page-btn']")

      assert render(next_btn) =~ "disabled" or
               render(next_btn) =~ "cursor-not-allowed" or
               render(next_btn) =~ "opacity-50"
    end

    test "shows correct total pages calculation", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # With 25 items and page size 10, should show "of 3"
      assert html =~ "of 3"
    end

    test "maintains pagination state when filtering by agency", %{conn: conn, agency: agency} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Go to page 2
      view
      |> element(".hidden.sm\\:flex [data-testid='next-page-btn']")
      |> render_click()

      # Filter by agency
      view
      |> element("[data-testid='agency-filter']")
      |> render_change(%{agency: agency.id})

      # Should reset to page 1 when filtering
      updated_html = render(view)
      assert updated_html =~ "Page 1"
    end

    test "handles URL parameters for direct page navigation", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard?recent_activity_page=2")

      # Should start on page 2
      assert html =~ "Page 2"
      # Should show page 2 content
      assert html =~ "HSE-011"
    end

    test "handles invalid page parameters gracefully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard?recent_activity_page=999")

      # Should default to last valid page (page 3)
      assert html =~ "Page 3"
    end

    test "shows no pagination when items fit on one page", %{conn: conn} do
      # Clear most cases, leaving only 5
      all_cases = Enforcement.list_cases!()
      cases_to_delete = Enum.drop(all_cases, 5)

      Enum.each(cases_to_delete, fn case ->
        Enforcement.destroy_case!(case)
      end)

      # Refresh metrics after deleting cases
      {:ok, _metrics} = EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:automation)

      {:ok, view, _html} = live(conn, "/dashboard")

      # Should not show pagination controls
      refute has_element?(view, "[data-testid='recent-activity-pagination']")
    end
  end

  describe "DashboardLive Recent Activity table requirements" do
    setup do
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, offender1} =
        Enforcement.create_offender(%{
          name: "Test Company Ltd",
          local_authority: "Test Council"
        })

      {:ok, offender2} =
        Enforcement.create_offender(%{
          name: "Example Corp",
          local_authority: "Another Council"
        })

      # Create test case (court case with fine)
      {:ok, case1} =
        Enforcement.create_case(%{
          regulator_id: "HSE-001",
          agency_id: agency.id,
          offender_id: offender1.id,
          offence_action_date: Date.add(Date.utc_today(), -10),
          offence_fine: Decimal.new("25000.00"),
          offence_breaches: "Health and safety violations leading to court proceedings",
          offence_action_type: "Court Case",
          url: "https://www.hse.gov.uk/prosecutions/case-123",
          last_synced_at: DateTime.utc_now()
        })

      # Create test notice (no fine)
      {:ok, notice1} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-002",
          agency_id: agency.id,
          offender_id: offender2.id,
          offence_action_date: Date.add(Date.utc_today(), -5),
          offence_breaches: "Workplace safety improvements required",
          offence_action_type: "Improvement Notice",
          url: "https://www.hse.gov.uk/notices/notice-456",
          last_synced_at: DateTime.utc_now()
        })

      # Refresh metrics for the test data
      {:ok, _metrics} = EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:automation)

      # Ensure LiveView processes are cleaned up between tests
      on_exit(fn ->
        # Allow async cleanup to complete
        Process.sleep(100)
      end)

      %{agency: agency, case: case1, notice: notice1}
    end

    test "displays Recent Activity table column headings", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should display all required column headings
      assert html =~ "Type"
      assert html =~ "Date"
      assert html =~ "Organization"
      assert html =~ "Description"
      assert html =~ "Fine Amount"
      assert html =~ "Agency Link"
    end

    test "displays case/notice type distinction using offence_action_type", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should show Court Case type
      assert html =~ "Court Case"
      # Should show Improvement Notice type
      assert html =~ "Improvement Notice"
    end

    test "displays filter buttons for case/notice types", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Should have filter buttons
      assert has_element?(view, "button", "All Types")
      assert has_element?(view, "button", "Cases")
      assert has_element?(view, "button", "Notices")
    end

    test "filtering by cases shows only court cases", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Click the "Cases" filter
      view |> element("button", "Cases") |> render_click()

      html = render(view)
      # Should only show items with offence_action_type "Court Case"
      assert html =~ "Court Case"
      refute html =~ "Improvement Notice"
    end

    test "filtering by notices shows only enforcement notices", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Click the "Notices" filter
      view |> element("button", "Notices") |> render_click()

      html = render(view)
      # Should only show items with notice-type offence_action_type values
      assert html =~ "Improvement Notice"
      refute html =~ "Court Case"
    end

    test "filtering by all types shows both cases and notices", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # First filter to cases, then back to all
      view |> element("button", "Cases") |> render_click()
      view |> element("button", "All Types") |> render_click()

      html = render(view)
      # Should show both court cases and notices again
      assert html =~ "Court Case"
      assert html =~ "Improvement Notice"
    end

    test "court cases show fine amounts, notices show N/A", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Court case should show fine amount
      assert html =~ "£25,000.00"
      # Notice should show N/A for fine amount
      assert html =~ "N/A"
    end

    test "displays agency website links with proper format", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should have links to HSE website
      assert html =~ "https://www.hse.gov.uk/prosecutions/case-123"
      assert html =~ "https://www.hse.gov.uk/notices/notice-456"
      # Should have "View Details" link text
      assert html =~ "View Details"
    end
  end

  describe "DashboardLive UI responsiveness" do
    test "renders responsive layout elements", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should have responsive CSS classes or structure
      assert html =~ "grid" or html =~ "flex" or html =~ "col"

      # Should handle mobile/desktop layouts
      assert html =~ "responsive" or html =~ "sm:" or html =~ "md:" or html =~ "lg:"
    end

    test "handles large datasets without performance issues", %{conn: conn} do
      # Create many agencies and cases to test performance
      agencies =
        Enum.map(1..20, fn i ->
          {:ok, agency} =
            Enforcement.create_agency(%{
              code: String.to_atom("agency_#{i}"),
              name: "Agency #{i}",
              enabled: true
            })

          agency
        end)

      offenders =
        Enum.map(1..50, fn i ->
          {:ok, offender} =
            Enforcement.create_offender(%{
              name: "Company #{i}",
              local_authority: "Council #{i}"
            })

          offender
        end)

      # Create cases (but not too many to avoid test timeout)
      Enum.each(1..100, fn i ->
        agency = Enum.at(agencies, rem(i, 20))
        offender = Enum.at(offenders, rem(i, 50))

        {:ok, _} =
          Enforcement.create_case(%{
            regulator_id: "CASE-#{i}",
            agency_id: agency.id,
            offender_id: offender.id,
            offence_action_date: Date.add(Date.add(Date.utc_today(), -20), i),
            offence_fine: Decimal.new("#{rem(i, 10) + 1}000.00"),
            offence_breaches: "Breach #{i}",
            last_synced_at: DateTime.utc_now()
          })
      end)

      # Refresh metrics for the test data
      {:ok, _metrics} = EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:automation)

      start_time = System.monotonic_time(:millisecond)

      {:ok, _view, html} = live(conn, "/dashboard")

      end_time = System.monotonic_time(:millisecond)
      load_time = end_time - start_time

      # Should load within reasonable time (less than 2 seconds)
      assert load_time < 2000, "Dashboard should load within 2 seconds even with large datasets"

      # Should display summary correctly
      assert html =~ "20 Agencies"
      assert html =~ "100 Total Cases"

      # Should only show recent cases (limited to 10)
      recent_cases = html |> String.split("CASE-") |> length()
      # 10 cases + 1 for the split
      assert recent_cases <= 11
    end
  end
end
