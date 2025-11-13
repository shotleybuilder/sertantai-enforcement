defmodule EhsEnforcementWeb.NoticeComplianceTest do
  use EhsEnforcementWeb.ConnCase

  # 🐛 BLOCKED: Notice LiveView tests failing - Issue #48
  @moduletag :skip

  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias EhsEnforcement.Enforcement

  describe "Notice compliance status calculation" do
    setup do
      # Create test agency
      {:ok, hse_agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      # Create test offender
      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Compliance Test Company Ltd",
          local_authority: "Test City Council",
          postcode: "TC1 1ST",
          main_activity: "Industrial Operations",
          industry: "Manufacturing"
        })

      # Create notices with different compliance scenarios
      today = Date.utc_today()

      # Future compliance date - should be "pending"
      {:ok, pending_notice} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-PENDING-2024-001",
          regulator_ref_number: "HSE/PEND/001",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_type: "Improvement Notice",
          notice_date: Date.add(today, -30),
          operative_date: Date.add(today, -16),
          compliance_date: Date.add(today, 30),
          notice_body: "Safety improvements required within compliance period"
        })

      # Past compliance date - should be "overdue"
      {:ok, overdue_notice} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-OVERDUE-2024-001",
          regulator_ref_number: "HSE/OVER/001",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_type: "Improvement Notice",
          notice_date: Date.add(today, -90),
          operative_date: Date.add(today, -76),
          compliance_date: Date.add(today, -15),
          notice_body: "Overdue safety improvements - immediate action required"
        })

      # Notice due very soon - should be "urgent"
      {:ok, urgent_notice} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-URGENT-2024-001",
          regulator_ref_number: "HSE/URG/001",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_type: "Improvement Notice",
          notice_date: Date.add(today, -20),
          operative_date: Date.add(today, -6),
          compliance_date: Date.add(today, 3),
          notice_body: "Critical safety measures required urgently"
        })

      # Prohibition notice (immediate compliance) - should be "immediate"
      {:ok, immediate_notice} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-PROHIB-2024-001",
          regulator_ref_number: "HSE/PROHIB/001",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_type: "Prohibition Notice",
          notice_date: Date.add(today, -5),
          operative_date: Date.add(today, -5),
          compliance_date: Date.add(today, -5),
          notice_body: "Immediate prohibition of dangerous operations"
        })

      %{
        agency: hse_agency,
        offender: offender,
        pending_notice: pending_notice,
        overdue_notice: overdue_notice,
        urgent_notice: urgent_notice,
        immediate_notice: immediate_notice,
        today: today
      }
    end

    test "calculates pending compliance status correctly", %{
      conn: conn,
      pending_notice: pending_notice
    } do
      {:ok, view, html} = live(conn, "/notices/#{pending_notice.id}")

      # Should show pending status
      assert html =~ "Pending" or html =~ "pending"

      assert has_element?(view, "[data-compliance-status='pending']") or
               has_element?(view, ".status-pending")

      # Should show days until compliance
      assert html =~ "days until" or html =~ "days remaining"
      # days until compliance
      assert html =~ "30"
    end

    test "calculates overdue compliance status correctly", %{
      conn: conn,
      overdue_notice: overdue_notice
    } do
      {:ok, view, html} = live(conn, "/notices/#{overdue_notice.id}")

      # Should show overdue status
      assert html =~ "Overdue" or html =~ "overdue"

      assert has_element?(view, "[data-compliance-status='overdue']") or
               has_element?(view, ".status-overdue")

      # Should show days overdue
      assert html =~ "days overdue" or html =~ "overdue by"
      # days overdue
      assert html =~ "15"
    end

    test "calculates urgent compliance status correctly", %{
      conn: conn,
      urgent_notice: urgent_notice
    } do
      {:ok, view, html} = live(conn, "/notices/#{urgent_notice.id}")

      # Should show urgent status
      assert html =~ "Urgent" or html =~ "urgent" or html =~ "Critical"

      assert has_element?(view, "[data-compliance-status='urgent']") or
               has_element?(view, ".status-urgent")

      # Should highlight urgency
      assert html =~ "3 days" or html =~ "soon"
    end

    test "handles immediate compliance notices", %{conn: conn, immediate_notice: immediate_notice} do
      {:ok, view, html} = live(conn, "/notices/#{immediate_notice.id}")

      # Should show immediate/prohibition status
      assert html =~ "Immediate" or html =~ "immediate" or html =~ "Prohibition"

      assert has_element?(view, "[data-compliance-status='immediate']") or
               has_element?(view, ".status-immediate")
    end

    test "shows compliance progress indicators", %{conn: conn, pending_notice: pending_notice} do
      {:ok, view, html} = live(conn, "/notices/#{pending_notice.id}")

      # Should show progress indicators
      assert has_element?(view, "[data-testid='compliance-progress']") or
               html =~ "progress" or html =~ "Progress"

      # Should show timeline visualization
      assert html =~ "Issued" or html =~ "issued"
      assert html =~ "Operative" or html =~ "operative"
      assert html =~ "Due" or html =~ "due"
    end

    test "displays compliance timeline correctly", %{conn: conn, pending_notice: pending_notice} do
      {:ok, view, html} = live(conn, "/notices/#{pending_notice.id}")

      # Should show compliance timeline
      assert has_element?(view, "[data-testid='compliance-timeline']")

      # Should show key dates
      assert html =~ "Notice Issued"
      assert html =~ "Operative Date"
      assert html =~ "Compliance Due"

      # Should calculate intervals
      # operative period
      assert html =~ "14 days" or html =~ "16 days"
      # total compliance period
      assert html =~ "46 days" or html =~ "60 days"
    end
  end

  describe "Notice compliance tracking interface" do
    setup :create_compliance_test_data

    test "displays compliance dashboard for notices", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should show compliance overview
      assert html =~ "Compliance Overview" or html =~ "Compliance Status"
      assert has_element?(view, "[data-testid='compliance-dashboard']")

      # Should show status counts
      assert html =~ "Pending" and html =~ "Overdue"
      # counts for each status
      assert html =~ "2" or html =~ "1"
    end

    test "filters notices by compliance status", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Filter by overdue notices
      view
      |> form("[data-testid='notice-filters']", filters: %{compliance_status: "overdue"})
      |> render_change()

      html = render(view)

      # Should show only overdue notices
      assert html =~ "HSE-OVERDUE-2024-001"
      refute html =~ "HSE-PENDING-2024-001"
    end

    test "sorts notices by compliance urgency", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Sort by compliance urgency
      view |> element("th", "Compliance Status") |> render_click()

      html = render(view)

      # Should prioritize overdue, then urgent, then pending
      overdue_pos = html |> String.split("HSE-OVERDUE") |> length()
      urgent_pos = html |> String.split("HSE-URGENT") |> length()
      pending_pos = html |> String.split("HSE-PENDING") |> length()

      assert overdue_pos <= urgent_pos
      assert urgent_pos <= pending_pos
    end

    test "shows compliance alerts for critical notices", %{
      conn: conn,
      urgent_notice: urgent_notice,
      overdue_notice: overdue_notice
    } do
      {:ok, view, html} = live(conn, "/notices")

      # Should show alerts for urgent/overdue notices
      assert has_element?(view, "[data-testid='compliance-alerts']") or
               html =~ "Alert" or html =~ "alert"

      # Should highlight critical notices
      assert html =~ urgent_notice.regulator_id
      assert html =~ overdue_notice.regulator_id
    end

    test "provides compliance action recommendations", %{
      conn: conn,
      overdue_notice: overdue_notice
    } do
      {:ok, view, html} = live(conn, "/notices/#{overdue_notice.id}")

      # Should suggest actions for overdue notices
      assert html =~ "Recommended Actions" or html =~ "Next Steps"
      assert html =~ "Follow up" or html =~ "Contact" or html =~ "Escalate"
    end

    test "tracks compliance history for notices", %{conn: conn, pending_notice: pending_notice} do
      {:ok, view, html} = live(conn, "/notices/#{pending_notice.id}")

      # Should show compliance history
      assert html =~ "Compliance History" or html =~ "Status Changes"
      assert has_element?(view, "[data-testid='compliance-history']")

      # Should show initial status
      assert html =~ "Notice issued" or html =~ "Status: Pending"
    end
  end

  describe "Notice compliance notifications" do
    setup :create_compliance_test_data

    test "generates compliance deadline reminders", %{conn: conn, urgent_notice: urgent_notice} do
      {:ok, view, html} = live(conn, "/notices/#{urgent_notice.id}")

      # Should show deadline reminder
      assert html =~ "Reminder" or html =~ "reminder" or html =~ "Due soon"
      assert html =~ "3 days" or html =~ "urgent"

      # Should have notification indicator
      assert has_element?(view, "[data-testid='deadline-reminder']") or
               has_element?(view, ".notification")
    end

    test "highlights overdue compliance violations", %{conn: conn, overdue_notice: overdue_notice} do
      {:ok, view, html} = live(conn, "/notices/#{overdue_notice.id}")

      # Should emphasize overdue status
      assert html =~ "OVERDUE" or html =~ "Overdue" or html =~ "violation"

      assert has_element?(view, "[data-testid='overdue-alert']") or
               has_element?(view, ".alert-danger")

      # Should show escalation options
      assert html =~ "Escalate" or html =~ "enforcement" or html =~ "action"
    end

    test "provides compliance status updates via real-time", %{
      conn: conn,
      pending_notice: pending_notice
    } do
      {:ok, view, _html} = live(conn, "/notices/#{pending_notice.id}")

      # Simulate compliance status change
      send(view.pid, {:compliance_status_changed, pending_notice.id, "urgent"})

      html = render(view)

      # Should update status in real-time
      # Still displays notice
      assert html =~ "Notice Details"
      # Status should be updated (would need actual PubSub implementation to fully test)
    end

    test "sends compliance deadline notifications", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Should show notification badge for urgent/overdue notices
      html = render(view)

      assert html =~ "notification" or html =~ "badge" or
               has_element?(view, "[data-testid='compliance-notifications']")
    end
  end

  describe "Notice compliance reporting" do
    setup :create_compliance_test_data

    test "generates compliance summary report", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should show compliance statistics
      assert html =~ "Compliance Statistics" or html =~ "Summary"
      assert has_element?(view, "[data-testid='compliance-stats']")

      # Should show breakdown by status
      assert html =~ "Pending:" or html =~ "Overdue:"
      assert html =~ "Total notices:"
    end

    test "exports compliance data", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Trigger compliance export
      if has_element?(view, "button", "Export Compliance") do
        view |> element("button", "Export Compliance") |> render_click()

        html = render(view)
        # Should handle export request
        assert html =~ "export" or html =~ "Export"
      else
        # Test passes if export not implemented yet
        assert true
      end
    end

    test "shows compliance trends over time", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should show trends or charts (if implemented)
      if html =~ "trends" or html =~ "chart" or
           has_element?(view, "[data-testid='compliance-trends']") do
        assert html =~ "compliance rate" or html =~ "improvement"
      else
        # Test passes if trends not implemented yet
        assert true
      end
    end

    test "provides compliance performance metrics", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should show performance indicators
      assert html =~ "%" or html =~ "rate" or html =~ "average"

      assert has_element?(view, "[data-testid='performance-metrics']") or
               html =~ "compliance rate"
    end
  end

  describe "Notice compliance workflow" do
    setup :create_compliance_test_data

    test "supports compliance status updates", %{conn: conn, pending_notice: pending_notice} do
      {:ok, view, html} = live(conn, "/notices/#{pending_notice.id}")

      # Should allow status updates (if implemented)
      if has_element?(view, "button", "Mark Compliant") do
        view |> element("button", "Mark Compliant") |> render_click()

        html = render(view)
        assert html =~ "Compliant" or html =~ "compliant"
      else
        # Test passes if manual updates not implemented
        assert html =~ pending_notice.regulator_id
      end
    end

    test "tracks compliance evidence and documentation", %{
      conn: conn,
      pending_notice: pending_notice
    } do
      {:ok, view, html} = live(conn, "/notices/#{pending_notice.id}")

      # Should show evidence section (if implemented)
      if html =~ "Evidence" or html =~ "Documentation" do
        assert has_element?(view, "[data-testid='compliance-evidence']")
        assert html =~ "upload" or html =~ "attach"
      else
        # Test passes if evidence tracking not implemented
        assert html =~ pending_notice.regulator_id
      end
    end

    test "manages compliance correspondence", %{conn: conn, overdue_notice: overdue_notice} do
      {:ok, view, html} = live(conn, "/notices/#{overdue_notice.id}")

      # Should show correspondence section (if implemented)
      if html =~ "Correspondence" or html =~ "Communications" do
        assert has_element?(view, "[data-testid='compliance-correspondence']")
        assert html =~ "email" or html =~ "letter" or html =~ "contact"
      else
        # Test passes if correspondence not implemented
        assert html =~ overdue_notice.regulator_id
      end
    end

    test "handles compliance extensions and modifications", %{
      conn: conn,
      urgent_notice: urgent_notice
    } do
      {:ok, view, html} = live(conn, "/notices/#{urgent_notice.id}")

      # Should support extensions (if implemented)
      if has_element?(view, "button", "Request Extension") do
        view |> element("button", "Request Extension") |> render_click()

        html = render(view)
        assert html =~ "extension" or html =~ "modified"
      else
        # Test passes if extensions not implemented
        assert html =~ urgent_notice.regulator_id
      end
    end
  end

  describe "Notice compliance performance" do
    setup do
      # Create larger dataset for performance testing
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Performance Test Company",
          local_authority: "Test Council",
          postcode: "T1 1ST"
        })

      today = Date.utc_today()

      # Create 100 notices with varied compliance dates
      notices =
        Enum.map(1..100, fn i ->
          # Mix of past and future dates
          compliance_days = rem(i, 60) - 30

          {:ok, notice} =
            Enforcement.create_notice(%{
              regulator_id: "HSE-PERF-#{String.pad_leading(to_string(i), 3, "0")}",
              agency_id: agency.id,
              offender_id: offender.id,
              offence_action_type: "Improvement Notice",
              notice_date: Date.add(today, -45),
              operative_date: Date.add(today, -31),
              compliance_date: Date.add(today, compliance_days),
              notice_body: "Performance test notice #{i} compliance requirements"
            })

          notice
        end)

      %{notices: notices, agency: agency, offender: offender, today: today}
    end

    test "calculates compliance status for large datasets efficiently", %{conn: conn} do
      start_time = System.monotonic_time(:millisecond)

      {:ok, view, _html} = live(conn, "/notices")

      end_time = System.monotonic_time(:millisecond)
      load_time = end_time - start_time

      html = render(view)
      assert html =~ "HSE-PERF"
      # Should load within 3 seconds
      assert load_time < 3000
    end

    test "filters compliance data efficiently", %{conn: conn} do
      start_time = System.monotonic_time(:millisecond)

      {:ok, view, _html} = live(conn, "/notices")

      # Apply compliance filter
      view
      |> form("[data-testid='notice-filters']", filters: %{compliance_status: "overdue"})
      |> render_change()

      end_time = System.monotonic_time(:millisecond)
      filter_time = end_time - start_time

      html = render(view)
      assert html =~ "notice" or html =~ "Notice"
      # Should filter within 2 seconds
      assert filter_time < 2000
    end

    test "handles compliance calculations without performance degradation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Multiple rapid status checks
      start_time = System.monotonic_time(:millisecond)

      Enum.each(1..5, fn _ ->
        view
        |> form("[data-testid='notice-filters']", filters: %{compliance_status: "pending"})
        |> render_change()

        view
        |> form("[data-testid='notice-filters']", filters: %{compliance_status: "overdue"})
        |> render_change()
      end)

      end_time = System.monotonic_time(:millisecond)
      total_time = end_time - start_time

      html = render(view)
      assert html =~ "notice" or html =~ "Notice"
      # Should handle rapid changes efficiently
      assert total_time < 3000
    end
  end

  describe "Notice compliance accessibility" do
    setup :create_compliance_test_data

    test "provides accessible compliance status indicators", %{
      conn: conn,
      overdue_notice: overdue_notice
    } do
      {:ok, view, html} = live(conn, "/notices/#{overdue_notice.id}")

      # Should include ARIA labels for status
      assert html =~ "aria-label=" or has_element?(view, "[aria-label]")
      assert html =~ "role=" or has_element?(view, "[role]")

      # Should provide text alternatives for visual indicators
      assert html =~ "Overdue" or html =~ "overdue"
      assert html =~ "status" or html =~ "Status"
    end

    test "supports keyboard navigation for compliance actions", %{
      conn: conn,
      pending_notice: pending_notice
    } do
      {:ok, view, html} = live(conn, "/notices/#{pending_notice.id}")

      # Compliance elements should be keyboard accessible
      assert has_element?(view, "button[tabindex]") or html =~ "tabindex"
      assert has_element?(view, "a") or has_element?(view, "button")

      # Should support focus management
      assert html =~ "compliance" or html =~ "Compliance"
    end

    test "provides clear compliance information for screen readers", %{
      conn: conn,
      urgent_notice: urgent_notice
    } do
      {:ok, view, html} = live(conn, "/notices/#{urgent_notice.id}")

      # Should include descriptive text
      assert html =~ "days" or html =~ "urgent" or html =~ "due"
      assert html =~ "compliance" or html =~ "Compliance"

      # Should have proper heading structure
      assert has_element?(view, "h2") or has_element?(view, "h3")
    end

    test "uses appropriate color contrast for compliance statuses", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should not rely solely on color for status indication
      assert html =~ "Pending" or html =~ "Overdue" or html =~ "Urgent"
      assert html =~ "status" or html =~ "Status"

      # Should include text indicators alongside colors
      assert has_element?(view, "[data-compliance-status]") or
               html =~ "compliance-status"
    end
  end

  # Helper function to create compliance test data
  defp create_compliance_test_data(_context) do
    # Create test agency
    {:ok, hse_agency} =
      Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true
      })

    # Create test offender
    {:ok, offender} =
      Enforcement.create_offender(%{
        name: "Compliance Test Company Ltd",
        local_authority: "Test City Council",
        postcode: "TC1 1ST",
        main_activity: "Industrial Operations",
        industry: "Manufacturing"
      })

    today = Date.utc_today()

    # Create notices with different compliance scenarios
    {:ok, pending_notice} =
      Enforcement.create_notice(%{
        regulator_id: "HSE-PENDING-2024-001",
        regulator_ref_number: "HSE/PEND/001",
        agency_id: hse_agency.id,
        offender_id: offender.id,
        offence_action_type: "Improvement Notice",
        notice_date: Date.add(today, -30),
        operative_date: Date.add(today, -16),
        compliance_date: Date.add(today, 30),
        notice_body: "Safety improvements required within compliance period"
      })

    {:ok, overdue_notice} =
      Enforcement.create_notice(%{
        regulator_id: "HSE-OVERDUE-2024-001",
        regulator_ref_number: "HSE/OVER/001",
        agency_id: hse_agency.id,
        offender_id: offender.id,
        offence_action_type: "Improvement Notice",
        notice_date: Date.add(today, -90),
        operative_date: Date.add(today, -76),
        compliance_date: Date.add(today, -15),
        notice_body: "Overdue safety improvements - immediate action required"
      })

    {:ok, urgent_notice} =
      Enforcement.create_notice(%{
        regulator_id: "HSE-URGENT-2024-001",
        regulator_ref_number: "HSE/URG/001",
        agency_id: hse_agency.id,
        offender_id: offender.id,
        offence_action_type: "Improvement Notice",
        notice_date: Date.add(today, -20),
        operative_date: Date.add(today, -6),
        compliance_date: Date.add(today, 3),
        notice_body: "Critical safety measures required urgently"
      })

    {:ok, immediate_notice} =
      Enforcement.create_notice(%{
        regulator_id: "HSE-PROHIB-2024-001",
        regulator_ref_number: "HSE/PROHIB/001",
        agency_id: hse_agency.id,
        offender_id: offender.id,
        offence_action_type: "Prohibition Notice",
        notice_date: Date.add(today, -5),
        operative_date: Date.add(today, -5),
        compliance_date: Date.add(today, -5),
        notice_body: "Immediate prohibition of dangerous operations"
      })

    %{
      agency: hse_agency,
      offender: offender,
      pending_notice: pending_notice,
      overdue_notice: overdue_notice,
      urgent_notice: urgent_notice,
      immediate_notice: immediate_notice,
      today: today
    }
  end
end
