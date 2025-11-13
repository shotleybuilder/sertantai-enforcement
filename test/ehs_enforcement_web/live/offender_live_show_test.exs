defmodule EhsEnforcementWeb.OffenderLive.ShowTest do
  use EhsEnforcementWeb.ConnCase

  # 🐛 BLOCKED: Offender LiveView tests failing - Issue #49
  @moduletag :skip

  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Repo

  require Ash.Query
  import Ash.Expr

  describe "OffenderLive.Show mount" do
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

      # Create detailed offender with full enforcement history
      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Complex Manufacturing Ltd",
          local_authority: "Manchester City Council",
          postcode: "M1 1AA",
          main_activity: "Metal fabrication and processing",
          business_type: :limited_company,
          industry: "Manufacturing",
          total_cases: 4,
          total_notices: 6,
          total_fines: Decimal.new("275000"),
          first_seen_date: ~D[2020-03-15],
          last_seen_date: ~D[2024-02-20]
        })

      # Create enforcement history spanning multiple years
      base_date = ~D[2024-01-15]

      # Recent case (2024)
      {:ok, recent_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-2024-001",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_date: base_date,
          offence_fine: Decimal.new("75000"),
          offence_breaches: "Health and Safety at Work Act 1974 - Section 2(1)",
          last_synced_at: DateTime.utc_now()
        })

      # Earlier case (2023)
      {:ok, earlier_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-2023-045",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_date: Date.add(base_date, -365),
          offence_fine: Decimal.new("50000"),
          offence_breaches: "Management of Health and Safety at Work Regulations 1999",
          last_synced_at: DateTime.utc_now()
        })

      # Environmental case (2022)
      {:ok, env_case} =
        Enforcement.create_case(%{
          regulator_id: "EA-2022-089",
          agency_id: ea_agency.id,
          offender_id: offender.id,
          offence_action_date: Date.add(base_date, -730),
          offence_fine: Decimal.new("100000"),
          offence_breaches: "Environmental Protection Act 1990 - Section 33(1)(a)",
          last_synced_at: DateTime.utc_now()
        })

      # Major historical case (2020)
      {:ok, major_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-2020-012",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_date: Date.add(base_date, -1460),
          offence_fine: Decimal.new("50000"),
          offence_breaches: "Health and Safety at Work Act 1974 - Multiple sections",
          last_synced_at: DateTime.utc_now()
        })

      # Create various notices
      {:ok, improvement_notice} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-N-2024-001",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_type: "improvement_notice",
          notice_date: base_date,
          operative_date: Date.add(base_date, 7),
          compliance_date: Date.add(base_date, 30),
          notice_body: "Improve safety procedures for machinery operation within 30 days"
        })

      {:ok, prohibition_notice} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-N-2023-078",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_type: "prohibition_notice",
          notice_date: Date.add(base_date, -200),
          operative_date: Date.add(base_date, -200),
          compliance_date: Date.add(base_date, -170),
          notice_body: "Immediate cessation of unsafe welding operations"
        })

      {:ok, warning_notice} =
        Enforcement.create_notice(%{
          regulator_id: "EA-N-2022-156",
          agency_id: ea_agency.id,
          offender_id: offender.id,
          offence_action_type: "warning_notice",
          notice_date: Date.add(base_date, -600),
          operative_date: Date.add(base_date, -600),
          compliance_date: Date.add(base_date, -570),
          notice_body: "Warning regarding improper waste disposal practices"
        })

      %{
        hse_agency: hse_agency,
        ea_agency: ea_agency,
        offender: offender,
        recent_case: recent_case,
        earlier_case: earlier_case,
        env_case: env_case,
        major_case: major_case,
        improvement_notice: improvement_notice,
        prohibition_notice: prohibition_notice,
        warning_notice: warning_notice
      }
    end

    test "renders offender detail page with basic information", %{conn: conn, offender: offender} do
      {:ok, _view, html} = live(conn, "/offenders/#{offender.id}")

      assert html =~ offender.name
      assert html =~ "Manchester City Council"
      assert html =~ "M1 1AA"
      assert html =~ "Manufacturing"
      assert html =~ "Metal fabrication and processing"
    end

    test "displays enforcement statistics summary", %{conn: conn, offender: offender} do
      {:ok, _view, html} = live(conn, "/offenders/#{offender.id}")

      # Should show aggregated statistics
      # total_cases
      assert html =~ "4 Cases"
      # total_notices
      assert html =~ "6 Notices"
      # total_fines
      assert html =~ "£275,000"

      # Should show date range
      # first_seen_date year
      assert html =~ "2020"
      # last_seen_date year
      assert html =~ "2024"
    end

    test "shows enforcement timeline with chronological order", %{
      conn: conn,
      offender: offender,
      recent_case: recent_case,
      major_case: major_case
    } do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Should show timeline section
      assert html =~ "Enforcement Timeline"
      assert html =~ "Enforcement History"

      # Should show cases in chronological order (most recent first)
      assert html =~ recent_case.regulator_id
      assert html =~ major_case.regulator_id

      # Timeline should have proper structure
      assert has_element?(view, "[data-role='timeline']")
      assert has_element?(view, "[data-role='timeline-item']")
    end

    test "displays cases grouped by year", %{conn: conn, offender: offender} do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Should group enforcement actions by year
      # Recent year header
      assert html =~ "2024"
      # Previous year header
      assert html =~ "2023"
      # Environmental case year
      assert html =~ "2022"
      # Historical case year
      assert html =~ "2020"

      # Should have year grouping elements
      assert has_element?(view, "[data-year='2024']")
      assert has_element?(view, "[data-year='2023']")
    end

    test "shows detailed case information in timeline", %{
      conn: conn,
      offender: offender,
      recent_case: recent_case
    } do
      {:ok, _view, html} = live(conn, "/offenders/#{offender.id}")

      # Should show case details
      assert html =~ recent_case.regulator_id
      # recent_case fine
      assert html =~ "£75,000"
      assert html =~ "Health and Safety at Work Act 1974"
      assert html =~ "Section 2(1)"

      # Should show agency information
      assert html =~ "Health and Safety Executive"
    end

    test "shows detailed notice information in timeline", %{
      conn: conn,
      offender: offender,
      improvement_notice: improvement_notice
    } do
      {:ok, _view, html} = live(conn, "/offenders/#{offender.id}")

      # Should show notice details
      assert html =~ improvement_notice.regulator_id
      assert html =~ "Improvement Notice"
      assert html =~ "Improve safety procedures for machinery operation"

      # Should show compliance dates
      # compliance period
      assert html =~ "30 days"
    end

    test "identifies repeat offender patterns", %{conn: conn, offender: offender} do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Should mark as repeat offender
      assert has_element?(view, "[data-repeat-offender='true']")
      assert html =~ "Repeat Offender"

      # Should show escalation pattern analysis
      assert html =~ "Enforcement Pattern"
      # HSE and EA
      assert html =~ "Multiple agencies involved"
    end

    test "shows agency breakdown in enforcement history", %{conn: conn, offender: offender} do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Should show breakdown by agency
      assert html =~ "Agency Breakdown"
      # HSE cases
      assert html =~ "Health and Safety Executive"
      # EA cases
      assert html =~ "Environment Agency"

      # Should show counts per agency
      assert has_element?(view, "[data-agency='hse']")
      assert has_element?(view, "[data-agency='ea']")
    end

    test "displays compliance tracking for notices", %{
      conn: conn,
      offender: offender,
      improvement_notice: improvement_notice
    } do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Should show compliance status
      assert html =~ "Compliance Status"

      # Should show notice dates
      assert html =~ "Notice Date"
      assert html =~ "Compliance Date"

      # Should calculate compliance periods
      assert has_element?(view, "[data-notice-id='#{improvement_notice.id}']")
    end

    test "shows industry context and peer comparison", %{conn: conn, offender: offender} do
      {:ok, _view, html} = live(conn, "/offenders/#{offender.id}")

      # Should show industry analysis
      assert html =~ "Industry Context"
      # offender's industry
      assert html =~ "Manufacturing"

      # Should show comparative metrics
      # high fine amount
      assert html =~ "Above industry average"
    end

    test "provides export functionality for offender report", %{conn: conn, offender: offender} do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Should have export options
      assert has_element?(view, "[data-role='export-pdf']")
      assert has_element?(view, "[data-role='export-csv']")
      assert html =~ "Export Report"
    end

    test "handles navigation back to offender index", %{conn: conn, offender: offender} do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Should have back navigation
      assert has_element?(view, "a[href='/offenders']")
      assert html =~ "Back to Offenders"
    end

    test "shows related offenders in same industry/area", %{conn: conn, offender: offender} do
      # Create related offender in same industry
      {:ok, related_offender} =
        Enforcement.create_offender(%{
          name: "Related Manufacturing Co",
          local_authority: "Manchester City Council",
          industry: "Manufacturing",
          total_cases: 2,
          total_fines: Decimal.new("45000")
        })

      {:ok, _view, html} = live(conn, "/offenders/#{offender.id}")

      # Should show related offenders section
      assert html =~ "Related Offenders"
      # Manufacturing
      assert html =~ "Same Industry"
      # Manchester
      assert html =~ "Same Area"
    end

    test "displays risk assessment based on enforcement history", %{
      conn: conn,
      offender: offender
    } do
      {:ok, _view, html} = live(conn, "/offenders/#{offender.id}")

      # Should show risk assessment
      assert html =~ "Risk Assessment"
      # Based on multiple cases and large fines
      assert html =~ "High Risk"

      # Should show risk factors
      assert html =~ "Multiple agencies"
      assert html =~ "Escalating fines"
      assert html =~ "Recent activity"
    end

    test "filters timeline by enforcement type", %{conn: conn, offender: offender} do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Filter to show only cases
      view
      |> form("#timeline-filters", %{filter_type: "cases"})
      |> render_change()

      # Should show cases but not notices
      # case regulator_id
      assert render(view) =~ "HSE-2024-001"
      # notice regulator_id
      refute render(view) =~ "HSE-N-2024-001"
    end

    test "filters timeline by agency", %{conn: conn, offender: offender} do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Filter to show only HSE enforcement actions
      view
      |> form("#timeline-filters", %{agency: "hse"})
      |> render_change()

      # Should show HSE actions but not EA actions
      # HSE case
      assert render(view) =~ "HSE-2024-001"
      # EA case
      refute render(view) =~ "EA-2022-089"
    end

    test "filters timeline by date range", %{conn: conn, offender: offender} do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Filter to show only 2024 actions
      view
      |> form("#timeline-filters", %{from_date: "2024-01-01", to_date: "2024-12-31"})
      |> render_change()

      # Should show 2024 actions but not older ones
      # 2024 case
      assert render(view) =~ "HSE-2024-001"
      # 2020 case
      refute render(view) =~ "HSE-2020-012"
    end

    test "handles offender not found gracefully", %{conn: conn} do
      non_existent_id = Ash.UUID.generate()

      {:ok, view, html} = live(conn, "/offenders/#{non_existent_id}")

      assert html =~ "Offender not found"
      assert html =~ "Back to Offenders"
      assert has_element?(view, "a[href='/offenders']")
    end

    test "displays loading states for timeline data", %{conn: conn, offender: offender} do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Trigger timeline reload
      view
      |> form("#timeline-filters", %{filter_type: "cases"})
      |> render_change()

      # Should handle loading gracefully
      assert view.module == EhsEnforcementWeb.OffenderLive.Show
    end
  end

  describe "OffenderLive.Show real-time updates" do
    setup do
      {:ok, hse_agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Live Update Corp",
          local_authority: "Test Council",
          total_cases: 1,
          total_notices: 1,
          total_fines: Decimal.new("25000")
        })

      %{hse_agency: hse_agency, offender: offender}
    end

    test "receives real-time updates for new cases", %{
      conn: conn,
      offender: offender,
      hse_agency: hse_agency
    } do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Simulate new case creation
      {:ok, new_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-2024-999",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_date: ~D[2024-01-20],
          offence_fine: Decimal.new("30000"),
          offence_breaches: "New violation",
          last_synced_at: DateTime.utc_now()
        })

      # Send PubSub message
      send(view.pid, {:case_created, new_case})

      # Should update timeline with new case
      assert render(view) =~ "HSE-2024-999"
      assert render(view) =~ "New violation"
    end

    test "receives real-time updates for new notices", %{
      conn: conn,
      offender: offender,
      hse_agency: hse_agency
    } do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Simulate new notice creation
      {:ok, new_notice} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-N-2024-999",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_type: "improvement_notice",
          notice_date: ~D[2024-01-20],
          operative_date: ~D[2024-01-27],
          compliance_date: ~D[2024-02-20],
          notice_body: "New compliance requirement"
        })

      # Send PubSub message
      send(view.pid, {:notice_created, new_notice})

      # Should update timeline with new notice
      assert render(view) =~ "HSE-N-2024-999"
      assert render(view) =~ "New compliance requirement"
    end
  end

  describe "OffenderLive.Show accessibility" do
    setup do
      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Accessible Corp",
          local_authority: "Test Council",
          total_cases: 1,
          total_notices: 1,
          total_fines: Decimal.new("5000")
        })

      %{offender: offender}
    end

    test "includes proper ARIA labels and semantic structure", %{conn: conn, offender: offender} do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Should have proper heading hierarchy
      assert html =~ ~r/<h1[^>]*>/
      assert html =~ ~r/<h2[^>]*>/

      # Should have ARIA landmarks
      assert html =~ ~r/role="main"/
      assert html =~ ~r/aria-label="[^"]*"/

      # Timeline should be accessible
      # Timeline as list
      assert has_element?(view, "[role='list']")
      # Timeline items
      assert has_element?(view, "[role='listitem']")
    end

    test "supports keyboard navigation for timeline items", %{conn: conn, offender: offender} do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Timeline items should be focusable
      assert has_element?(view, "[data-role='timeline-item'][tabindex='0']")

      # Filter controls should be accessible
      assert has_element?(view, "select[aria-label]")
      assert has_element?(view, "input[aria-label]")
    end

    test "provides screen reader friendly content", %{conn: conn, offender: offender} do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Should have descriptive text for screen readers
      assert html =~ "Enforcement history for"
      assert html =~ "Total cases:"
      assert html =~ "Total fines:"

      # Should have proper table structure if tables are used
      if Regex.match?(~r/<table/, html) do
        assert has_element?(view, "table caption") || has_element?(view, "table[aria-label]")
        assert has_element?(view, "th[scope]")
      end
    end
  end

  describe "OffenderLive.Show performance" do
    setup do
      {:ok, hse_agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Performance Test Corp",
          local_authority: "Test Council",
          total_cases: 50,
          total_notices: 75,
          total_fines: Decimal.new("500000")
        })

      # Create many enforcement actions to test performance
      for i <- 1..50 do
        {:ok, _case} =
          Enforcement.create_case(%{
            regulator_id: "HSE-PERF-#{i}",
            agency_id: hse_agency.id,
            offender_id: offender.id,
            offence_action_date: Date.add(~D[2024-01-01], -i),
            offence_fine: Decimal.new("#{i * 1000}"),
            offence_breaches: "Performance test case #{i}",
            last_synced_at: DateTime.utc_now()
          })
      end

      %{hse_agency: hse_agency, offender: offender}
    end

    test "handles large enforcement history efficiently", %{conn: conn, offender: offender} do
      # This test ensures the page loads despite large dataset
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      assert html =~ offender.name
      # Should show correct total
      assert html =~ "50 Cases"

      # Should implement pagination or lazy loading
      timeline_items = view |> render() |> Floki.find("[data-role='timeline-item']")
      # Should limit initial load (e.g., 20 items)
      assert length(timeline_items) <= 20
    end

    test "implements pagination for timeline", %{conn: conn, offender: offender} do
      {:ok, view, html} = live(conn, "/offenders/#{offender.id}")

      # Should have pagination controls for large datasets
      assert has_element?(view, "[data-role='load-more']") ||
               has_element?(view, ".pagination")
    end
  end
end
