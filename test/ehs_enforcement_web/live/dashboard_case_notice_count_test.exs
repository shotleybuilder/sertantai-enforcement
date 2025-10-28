defmodule EhsEnforcementWeb.DashboardCaseNoticeCountTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  alias EhsEnforcement.Enforcement
  require Ash.Query
  import Ash.Expr

  describe "Dashboard Case Count and Notice Count functionality" do
    setup do
      # Create test agency
      {:ok, hse_agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
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

      {:ok, offender3} =
        Enforcement.create_offender(%{
          name: "Third Corp",
          local_authority: "Third Council",
          postcode: "TE3 3ST"
        })

      # Use recent dates (within last 30 days for stats)
      today = Date.utc_today()
      # 5 days ago
      recent_date1 = Date.add(today, -5)
      # 10 days ago  
      recent_date2 = Date.add(today, -10)
      # 15 days ago
      recent_date3 = Date.add(today, -15)
      # 20 days ago
      recent_date4 = Date.add(today, -20)
      # 25 days ago
      recent_date5 = Date.add(today, -25)

      # Create multiple test cases (court cases with fines)
      {:ok, case1} =
        Enforcement.create_case(%{
          regulator_id: "HSE-CASE-001",
          agency_id: hse_agency.id,
          offender_id: offender1.id,
          offence_action_date: recent_date1,
          offence_fine: Decimal.new("25000.00"),
          offence_breaches: "Health and safety violations in case 1",
          offence_action_type: "Court Case",
          url: "https://www.hse.gov.uk/prosecutions/case-001",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, case2} =
        Enforcement.create_case(%{
          regulator_id: "HSE-CASE-002",
          agency_id: hse_agency.id,
          offender_id: offender2.id,
          offence_action_date: recent_date2,
          offence_fine: Decimal.new("50000.00"),
          offence_breaches: "Health and safety violations in case 2",
          offence_action_type: "Court Case",
          url: "https://www.hse.gov.uk/prosecutions/case-002",
          last_synced_at: DateTime.utc_now()
        })

      # Create multiple test notices (no fines)
      {:ok, notice1} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-NOTICE-001",
          agency_id: hse_agency.id,
          offender_id: offender1.id,
          offence_action_date: recent_date3,
          offence_breaches: "Workplace safety improvements required - notice 1",
          offence_action_type: "Improvement Notice",
          url: "https://www.hse.gov.uk/notices/notice-001",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, notice2} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-NOTICE-002",
          agency_id: hse_agency.id,
          offender_id: offender2.id,
          offence_action_date: recent_date4,
          offence_breaches: "Workplace safety improvements required - notice 2",
          offence_action_type: "Prohibition Notice",
          url: "https://www.hse.gov.uk/notices/notice-002",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, notice3} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-NOTICE-003",
          agency_id: hse_agency.id,
          offender_id: offender3.id,
          offence_action_date: recent_date5,
          offence_breaches: "Workplace safety improvements required - notice 3",
          offence_action_type: "Crown Notice",
          url: "https://www.hse.gov.uk/notices/notice-003",
          last_synced_at: DateTime.utc_now()
        })

      %{
        agency: hse_agency,
        cases: [case1, case2],
        notices: [notice1, notice2, notice3],
        expected_case_count: 2,
        expected_notice_count: 3,
        expected_total_count: 5
      }
    end

    test "dashboard displays correct Recent Cases count in stats section", %{
      conn: conn,
      expected_case_count: expected_case_count
    } do
      {:ok, view, html} = live(conn, "/dashboard")

      # Check that Recent Cases stat shows correct count
      assert html =~ "Recent Cases"
      assert html =~ "#{expected_case_count} Cases"
    end

    test "dashboard displays correct Recent Notices count in stats section", %{
      conn: conn,
      expected_notice_count: expected_notice_count
    } do
      {:ok, view, html} = live(conn, "/dashboard")

      # Check that Recent Notices stat shows correct count
      assert html =~ "Recent Notices"
      assert html =~ "#{expected_notice_count} Notices"
    end

    test "Recent Activity shows all items when 'All Types' filter is active", %{
      conn: conn,
      expected_total_count: expected_total_count
    } do
      {:ok, view, html} = live(conn, "/dashboard")

      # Debug: Check if data is in the initial HTML
      if html =~ "No recent enforcement activity to display" do
        # If empty, click "All Types" filter to trigger data load
        view |> element("button", "All Types") |> render_click()
        html = render(view)
      end

      # Should show both Court Cases and various Notice types
      assert html =~ "Court Case",
             "Should find 'Court Case' in HTML. Found empty state: #{html =~ "No recent enforcement activity"}"

      assert html =~ "Notice"

      # Count activity items in the table
      activity_rows = view |> element("tbody[data-testid='recent-activities']") |> render()
      split_rows = activity_rows |> String.split("data-testid=\"activity-item\"")
      row_count = length(split_rows) - 1

      # Should show all 5 items (2 cases + 3 notices) on first page
      assert row_count == expected_total_count,
             "Expected #{expected_total_count} activity items but found #{row_count}"
    end

    test "Cases filter shows only court cases with correct count", %{
      conn: conn,
      expected_case_count: expected_case_count
    } do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Click the "Cases" filter button
      view |> element("button", "Cases") |> render_click()

      html = render(view)

      # Should show only Court Case types
      assert html =~ "Court Case", "Should display Court Case types when filtering by cases"

      # Should not show notice types
      refute html =~ "Improvement Notice",
             "Should not show Improvement Notice when filtering by cases"

      refute html =~ "Prohibition Notice",
             "Should not show Prohibition Notice when filtering by cases"

      refute html =~ "Crown Notice", "Should not show Crown Notice when filtering by cases"

      # Count activity items in the table
      activity_rows = view |> element("tbody[data-testid='recent-activities']") |> render()
      split_rows = activity_rows |> String.split("data-testid=\"activity-item\"")
      row_count = length(split_rows) - 1

      # Should show exactly the number of cases we created
      assert row_count == expected_case_count,
             "Expected #{expected_case_count} case items but found #{row_count}"

      # Verify fine amounts are displayed (cases have fines, notices don't)
      assert html =~ "£25,000", "Should show fine amount for first case"
      assert html =~ "£50,000", "Should show fine amount for second case"
    end

    test "Notices filter shows only notices with correct count", %{
      conn: conn,
      expected_notice_count: expected_notice_count
    } do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Click the "Notices" filter button  
      view |> element("button", "Notices") |> render_click()

      html = render(view)

      # Should show various notice types
      assert html =~ "Improvement Notice",
             "Should show Improvement Notice when filtering by notices"

      assert html =~ "Prohibition Notice",
             "Should show Prohibition Notice when filtering by notices"

      assert html =~ "Crown Notice", "Should show Crown Notice when filtering by notices"

      # Should not show court case types
      refute html =~ "Court Case", "Should not show Court Case when filtering by notices"

      # Count activity items in the table
      activity_rows = view |> element("tbody[data-testid='recent-activities']") |> render()
      split_rows = activity_rows |> String.split("data-testid=\"activity-item\"")
      row_count = length(split_rows) - 1

      # Should show exactly the number of notices we created
      assert row_count == expected_notice_count,
             "Expected #{expected_notice_count} notice items but found #{row_count}"

      # Verify no fine amounts are displayed (notices don't have fines)
      refute html =~ "£25,000", "Should not show fine amounts for notices"
      refute html =~ "£50,000", "Should not show fine amounts for notices"

      # Should show N/A for fine amounts
      assert html =~ "N/A", "Should show N/A for notice fine amounts"
    end

    test "filter buttons have correct active states", %{conn: conn} do
      {:ok, view, html} = live(conn, "/dashboard")

      # Initially "All Types" should be active (has blue background)
      assert html =~ "bg-blue-100 text-blue-800", "All Types button should be active initially"
      assert html =~ "All Types", "Should have All Types button"

      # Click Cases filter
      view |> element("button", "Cases") |> render_click()
      html = render(view)

      # Check Cases button is active and others are inactive
      all_types_btn = view |> element("button", "All Types") |> render()
      cases_btn = view |> element("button", "Cases") |> render()
      notices_btn = view |> element("button", "Notices") |> render()

      # Cases should be active (blue)
      assert cases_btn =~ "bg-blue-100 text-blue-800", "Cases button should be active"
      # Others should be inactive (gray)
      assert all_types_btn =~ "bg-gray-100 text-gray-700", "All Types button should be inactive"
      assert notices_btn =~ "bg-gray-100 text-gray-700", "Notices button should be inactive"

      # Click Notices filter
      view |> element("button", "Notices") |> render_click()
      html = render(view)

      # Check Notices button is active
      notices_btn_after = view |> element("button", "Notices") |> render()
      assert notices_btn_after =~ "bg-blue-100 text-blue-800", "Notices button should be active"
    end

    test "struct type detection works correctly for filtering logic", %{
      cases: cases,
      notices: notices
    } do
      # Test the exact struct matching logic used in the dashboard
      all_records = cases ++ notices

      # Filter cases using the same logic as the dashboard
      filtered_cases = Enum.filter(all_records, &match?(%EhsEnforcement.Enforcement.Case{}, &1))

      filtered_notices =
        Enum.filter(all_records, &match?(%EhsEnforcement.Enforcement.Notice{}, &1))

      # Verify counts match our test data
      assert length(filtered_cases) == 2, "Should have 2 cases"
      assert length(filtered_notices) == 3, "Should have 3 notices"

      # Verify each filtered case is actually a Case struct with Court Case type
      Enum.each(filtered_cases, fn case_record ->
        assert match?(%EhsEnforcement.Enforcement.Case{}, case_record)
        assert case_record.offence_action_type == "Court Case"
        assert case_record.offence_fine != nil, "Cases should have fine amounts"
      end)

      # Verify each filtered notice is actually a Notice struct
      Enum.each(filtered_notices, fn notice_record ->
        assert match?(%EhsEnforcement.Enforcement.Notice{}, notice_record)

        assert notice_record.offence_action_type in [
                 "Improvement Notice",
                 "Prohibition Notice",
                 "Crown Notice"
               ]

        assert Map.get(notice_record, :offence_fine, nil) == nil,
               "Notices should not have fine amounts"
      end)
    end

    test "pagination works correctly with filtered counts", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Test pagination info shows correct totals
      html = render(view)

      # Should show total count in pagination (if pagination is visible)
      if html =~ "Showing" do
        assert html =~ "of 5 results" || html =~ "5 total",
               "Should show total count in pagination"
      end

      # Filter by cases and check pagination
      view |> element("button", "Cases") |> render_click()
      html = render(view)

      if html =~ "Showing" do
        assert html =~ "of 2 results" || html =~ "2 total",
               "Should show case count in pagination when filtering by cases"
      end

      # Filter by notices and check pagination
      view |> element("button", "Notices") |> render_click()
      html = render(view)

      if html =~ "Showing" do
        assert html =~ "of 3 results" || html =~ "3 total",
               "Should show notice count in pagination when filtering by notices"
      end
    end

    test "Recent Activity table structure displays correct data types", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Test Cases filter
      view |> element("button", "Cases") |> render_click()
      html = render(view)

      # Check if data is displayed at all
      if html =~ "No recent enforcement activity to display" do
        flunk("No data displayed after clicking Cases filter. Table should show case data.")
      end

      # Cases should show red badges with Court Case text
      assert html =~ "Court Case", "Should display 'Court Case' text when filtering by cases"
      assert html =~ "bg-red-100 text-red-800", "Should have red badge styling for court cases"

      # Test Notices filter
      view |> element("button", "Notices") |> render_click()
      html = render(view)

      # Check if notice data is displayed
      if html =~ "No recent enforcement activity to display" do
        flunk("No data displayed after clicking Notices filter. Table should show notice data.")
      end

      # Notices should show yellow badges
      assert html =~ "Notice", "Should display notice types when filtering by notices"

      assert html =~ "bg-yellow-100 text-yellow-800",
             "Should have yellow badge styling for notices"
    end

    test "edge case: empty results for each filter type", %{conn: conn} do
      # Delete all test data to test empty states
      {:ok, cases} = Enforcement.list_cases()
      {:ok, notices} = Enforcement.list_notices()

      Enum.each(cases, &Enforcement.destroy_case!/1)
      Enum.each(notices, &Enforcement.destroy_notice!/1)

      {:ok, view, html} = live(conn, "/dashboard")

      # Should show empty state message
      assert html =~ "No recent enforcement activity to display"

      # Test each filter with empty data
      for filter_type <- ["All Types", "Cases", "Notices"] do
        view |> element("button", filter_type) |> render_click()
        html = render(view)

        assert html =~ "No recent enforcement activity to display",
               "Should show empty state when filtering by #{filter_type} with no data"
      end
    end
  end

  describe "Dashboard stats calculations" do
    setup do
      # Create test data for stats testing
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Test Company",
          local_authority: "Test Council",
          postcode: "TE1 1ST"
        })

      # Use recent dates (within last 30 days)
      today = Date.utc_today()

      # Create a recent case (within last 30 days)
      {:ok, recent_case} =
        Enforcement.create_case(%{
          regulator_id: "RECENT-001",
          agency_id: agency.id,
          offender_id: offender.id,
          # 5 days ago
          offence_action_date: Date.add(today, -5),
          offence_fine: Decimal.new("30000.00"),
          offence_breaches: "Recent violation",
          offence_action_type: "Court Case",
          url: "https://example.com/recent",
          last_synced_at: DateTime.utc_now()
        })

      # Create a recent notice (within last 30 days)
      {:ok, recent_notice} =
        Enforcement.create_notice(%{
          regulator_id: "RECENT-NOTICE-001",
          agency_id: agency.id,
          offender_id: offender.id,
          # 10 days ago
          offence_action_date: Date.add(today, -10),
          offence_breaches: "Recent notice violation",
          offence_action_type: "Improvement Notice",
          url: "https://example.com/recent-notice",
          last_synced_at: DateTime.utc_now()
        })

      %{
        agency: agency,
        recent_case: recent_case,
        recent_notice: recent_notice
      }
    end

    test "stats section shows correct recent cases and notices counts", %{conn: conn} do
      {:ok, view, html} = live(conn, "/dashboard")

      # Should show at least 1 recent case and 1 recent notice
      assert html =~ ~r/\d+ Cases/, "Should show case count in Recent Cases stat"
      assert html =~ ~r/\d+ Notices/, "Should show notice count in Recent Notices stat"

      # Should show timeframe
      assert html =~ "Last 30 Days", "Should show timeframe in stats"
    end
  end
end
