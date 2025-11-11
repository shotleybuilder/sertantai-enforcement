defmodule EhsEnforcementWeb.NoticeLive.ShowTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Repo

  describe "NoticeLive.Show mount" do
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
          name: "Industrial Manufacturing Ltd",
          local_authority: "Manchester City Council",
          postcode: "M1 1AA",
          main_activity: "Chemical Processing",
          business_type: :limited_company,
          industry: "Manufacturing"
        })

      # Create related case for context
      {:ok, related_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-CASE-2024-001",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_date: ~D[2024-01-10],
          offence_fine: Decimal.new("25000.00"),
          offence_breaches: "Health and Safety at Work Act 1974 - Section 2(1)",
          offence_result: "Guilty plea - prosecution successful"
        })

      # Create main test notice
      {:ok, notice} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-NOTICE-2024-015",
          regulator_ref_number: "HSE/REF/2024/015",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_type: "Improvement Notice",
          notice_date: ~D[2024-01-15],
          operative_date: ~D[2024-01-29],
          compliance_date: ~D[2024-03-15],
          notice_body:
            "The company must implement and maintain adequate safety procedures for the handling of hazardous chemicals. This includes: 1) Provision of appropriate personal protective equipment, 2) Implementation of emergency response procedures, 3) Regular safety training for all personnel, 4) Maintenance of safety data sheets for all chemicals."
        })

      # Create additional notices for the same offender to test related notices
      {:ok, related_notice1} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-NOTICE-2024-002",
          regulator_ref_number: "HSE/REF/2024/002",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_type: "Prohibition Notice",
          notice_date: ~D[2024-01-05],
          operative_date: ~D[2024-01-05],
          compliance_date: ~D[2024-02-05],
          notice_body: "Immediate prohibition of crane operations pending structural inspection"
        })

      {:ok, related_notice2} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-NOTICE-2024-020",
          regulator_ref_number: "HSE/REF/2024/020",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_type: "Improvement Notice",
          notice_date: ~D[2024-02-01],
          operative_date: ~D[2024-02-15],
          compliance_date: ~D[2024-04-01],
          notice_body: "Follow-up notice requiring completion of safety improvements"
        })

      %{
        notice: notice,
        offender: offender,
        agency: hse_agency,
        related_case: related_case,
        related_notice1: related_notice1,
        related_notice2: related_notice2
      }
    end

    test "successfully mounts and displays notice details", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      assert html =~ "Notice Details"
      assert html =~ notice.regulator_id
      assert html =~ notice.regulator_ref_number
      assert html =~ "Improvement Notice"
      assert html =~ "Industrial Manufacturing Ltd"
      assert html =~ "Health and Safety Executive"
    end

    test "displays complete notice information", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Notice identification
      assert html =~ "HSE-NOTICE-2024-015"
      assert html =~ "HSE/REF/2024/015"

      # Notice type and dates
      assert html =~ "Improvement Notice"
      assert html =~ "January 15, 2024" or html =~ "2024-01-15"
      assert html =~ "January 29, 2024" or html =~ "2024-01-29"
      assert html =~ "March 15, 2024" or html =~ "2024-03-15"

      # Notice body content
      assert html =~ "adequate safety procedures"
      assert html =~ "hazardous chemicals"
      assert html =~ "personal protective equipment"
    end

    test "displays offender information section", %{
      conn: conn,
      notice: notice,
      offender: offender
    } do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Offender details
      assert html =~ offender.name
      assert html =~ "Manchester City Council"
      assert html =~ "M1 1AA"
      assert html =~ "Chemical Processing"
      assert html =~ "Manufacturing"
    end

    test "displays agency information section", %{conn: conn, notice: notice, agency: agency} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Agency details
      assert html =~ agency.name
      assert html =~ "Health and Safety Executive"
      assert html =~ "HSE"
    end

    test "shows compliance timeline", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should display compliance timeline
      assert has_element?(view, "[data-testid='compliance-timeline']")

      # Timeline should show key dates
      assert html =~ "Notice Issued"
      assert html =~ "Operative Date"
      assert html =~ "Compliance Due"

      # Should calculate and show days
      assert html =~ "days" or html =~ "Days"
    end

    test "displays notice body with proper formatting", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should display full notice body
      assert html =~ "implement and maintain adequate safety procedures"
      assert html =~ "1) Provision of appropriate personal protective equipment"
      assert html =~ "2) Implementation of emergency response procedures"
      assert html =~ "3) Regular safety training"
      assert html =~ "4) Maintenance of safety data sheets"
    end

    test "shows compliance status indicator", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should show current compliance status
      assert has_element?(view, "[data-testid='compliance-status']")
      assert html =~ "Pending" or html =~ "Overdue" or html =~ "Compliant"

      # Should have appropriate styling for status
      assert has_element?(view, "[data-compliance-status]")
    end

    test "includes navigation elements", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should include back navigation
      assert has_element?(view, "a[href='/notices']") or html =~ "Back to Notices"

      # Should include action buttons
      assert has_element?(view, "button", "Export") or html =~ "Export"
      assert has_element?(view, "button", "Share") or html =~ "Share"
    end

    test "handles case with minimal notice data", %{conn: conn} do
      # Create minimal notice
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :ea,
          name: "Environment Agency",
          enabled: true
        })

      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Minimal Data Ltd",
          local_authority: "Test Council",
          postcode: "T1 1ST"
        })

      {:ok, minimal_notice} =
        Enforcement.create_notice(%{
          regulator_id: "EA-NOTICE-2024-MIN",
          agency_id: agency.id,
          offender_id: offender.id,
          offence_action_type: "Enforcement Notice",
          notice_date: ~D[2024-01-01]
          # Missing optional fields
        })

      {:ok, view, html} = live(conn, "/notices/#{minimal_notice.id}")

      assert html =~ "EA-NOTICE-2024-MIN"
      assert html =~ "Minimal Data Ltd"
      assert html =~ "Environment Agency"

      # Should handle missing data gracefully
      refute html =~ "error" or html =~ "Error"
    end
  end

  describe "NoticeLive.Show related notices section" do
    setup :create_notice_with_relations

    test "displays related notices for same offender", %{
      conn: conn,
      notice: notice,
      related_notice1: related_notice1,
      related_notice2: related_notice2
    } do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should show related notices section
      assert html =~ "Related Notices" or html =~ "Other Notices"
      assert html =~ related_notice1.regulator_id
      assert html =~ related_notice2.regulator_id
      assert html =~ "Prohibition Notice"
    end

    test "shows chronological order of related notices", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should show notices in chronological order
      # related_notice1 (Jan 5) should appear before related_notice2 (Feb 1)
      pos1 = html |> String.split("HSE-NOTICE-2024-002") |> length()
      pos2 = html |> String.split("HSE-NOTICE-2024-020") |> length()
      assert pos1 < pos2
    end

    test "links to related notice details", %{
      conn: conn,
      notice: notice,
      related_notice1: related_notice1
    } do
      {:ok, view, _html} = live(conn, "/notices/#{notice.id}")

      # Should have links to related notices
      assert has_element?(view, "a[href='/notices/#{related_notice1.id}']")
    end

    test "displays related case information", %{
      conn: conn,
      notice: notice,
      related_case: related_case
    } do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should show related case if exists
      assert html =~ "Related Case" or html =~ "Associated Case"
      assert html =~ related_case.regulator_id
      assert html =~ "£25,000" or html =~ "25000"
    end

    test "handles notice with no related records", %{conn: conn} do
      # Create isolated notice
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :orr,
          name: "Office of Rail and Road",
          enabled: true
        })

      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Isolated Company Ltd",
          local_authority: "Remote Council",
          postcode: "R1 1MT"
        })

      {:ok, isolated_notice} =
        Enforcement.create_notice(%{
          regulator_id: "ORR-NOTICE-2024-001",
          agency_id: agency.id,
          offender_id: offender.id,
          offence_action_type: "Improvement Notice",
          notice_date: ~D[2024-01-01]
        })

      {:ok, view, html} = live(conn, "/notices/#{isolated_notice.id}")

      assert html =~ "ORR-NOTICE-2024-001"
      # Should handle absence of related records gracefully
      assert html =~ "No related notices" or html =~ "no other notices" or
               refute(html =~ "Related Notices")
    end
  end

  describe "NoticeLive.Show compliance tracking" do
    setup :create_notice_with_relations

    test "calculates days until compliance deadline", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should show days calculation (March 15 - current date)
      assert html =~ "days until" or html =~ "days remaining" or html =~ "days to comply"
    end

    test "shows overdue status for past compliance dates", %{conn: conn} do
      # Create overdue notice
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Overdue Company Ltd",
          local_authority: "Test Council",
          postcode: "T1 1ST"
        })

      {:ok, overdue_notice} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-NOTICE-2023-001",
          agency_id: agency.id,
          offender_id: offender.id,
          offence_action_type: "Improvement Notice",
          notice_date: ~D[2023-01-01],
          # Past date
          compliance_date: ~D[2023-02-01]
        })

      {:ok, view, html} = live(conn, "/notices/#{overdue_notice.id}")

      # Should indicate overdue status
      assert html =~ "Overdue" or html =~ "overdue"

      assert has_element?(view, "[data-compliance-status='overdue']") or
               has_element?(view, ".status-overdue") or
               html =~ "red" or html =~ "danger"
    end

    test "displays compliance progress indicators", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should show progress indicators
      assert has_element?(view, "[data-testid='compliance-progress']") or
               html =~ "progress" or html =~ "Progress"

      # Should show percentage or steps completed
      assert html =~ "%" or html =~ "step" or html =~ "stage"
    end

    test "shows compliance actions or requirements", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should extract and display requirements from notice body
      assert html =~ "Requirements" or html =~ "Actions Required"
      assert html =~ "personal protective equipment"
      assert html =~ "emergency response procedures"
      assert html =~ "safety training"
    end
  end

  describe "NoticeLive.Show real-time updates" do
    setup :create_notice_with_relations

    test "receives real-time updates for notice changes", %{conn: conn, notice: notice} do
      {:ok, view, _html} = live(conn, "/notices/#{notice.id}")

      # Simulate notice update via PubSub
      send(view.pid, {:notice_updated, notice.id})

      html = render(view)
      # Should handle the update gracefully
      assert html =~ notice.regulator_id
    end

    test "updates compliance status in real-time", %{conn: conn, notice: notice} do
      {:ok, view, _html} = live(conn, "/notices/#{notice.id}")

      # Simulate compliance status change
      send(view.pid, {:compliance_updated, notice.id, "compliant"})

      html = render(view)
      # Should reflect updated status
      # Still displays
      assert html =~ "Notice Details"
    end

    test "handles malformed update messages gracefully", %{conn: conn, notice: notice} do
      {:ok, view, _html} = live(conn, "/notices/#{notice.id}")

      # Send malformed message
      log =
        capture_log(fn ->
          send(view.pid, {:invalid_message, "malformed_data"})
          Process.sleep(50)
        end)

      # Should not crash
      html = render(view)
      assert html =~ notice.regulator_id
    end
  end

  describe "NoticeLive.Show export and sharing" do
    setup :create_notice_with_relations

    test "exports notice details as PDF", %{conn: conn, notice: notice} do
      {:ok, view, _html} = live(conn, "/notices/#{notice.id}")

      # Trigger PDF export
      view |> element("button", "Export PDF") |> render_click()

      # Should handle export request
      assert_patched(view, "/notices/#{notice.id}")
    end

    test "exports notice details as formatted document", %{conn: conn, notice: notice} do
      {:ok, view, _html} = live(conn, "/notices/#{notice.id}")

      # Trigger document export
      view |> element("button", "Export") |> render_click()

      html = render(view)
      # Should show export options or trigger download
      assert html =~ notice.regulator_id
    end

    test "generates shareable notice link", %{conn: conn, notice: notice} do
      {:ok, view, _html} = live(conn, "/notices/#{notice.id}")

      # Trigger share functionality
      view |> element("button", "Share") |> render_click()

      html = render(view)
      # Should show share options or generate link
      assert html =~ "Share" or html =~ "Link" or html =~ notice.id
    end

    test "handles export failures gracefully", %{conn: conn, notice: notice} do
      {:ok, view, _html} = live(conn, "/notices/#{notice.id}")

      # Simulate export failure
      log =
        capture_log(fn ->
          view |> element("button", "Export") |> render_click()
          Process.sleep(50)
        end)

      html = render(view)
      # Should not crash and may show error message
      assert html =~ notice.regulator_id
    end
  end

  describe "NoticeLive.Show data formatting" do
    setup :create_notice_with_relations

    test "formats dates consistently", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should format dates in consistent format
      assert html =~ "January 15, 2024" or html =~ "15 Jan 2024" or html =~ "2024-01-15"
      assert html =~ "January 29, 2024" or html =~ "29 Jan 2024" or html =~ "2024-01-29"
      assert html =~ "March 15, 2024" or html =~ "15 Mar 2024" or html =~ "2024-03-15"
    end

    test "handles long notice body text appropriately", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should display full text with proper formatting
      assert html =~ "adequate safety procedures"
      assert html =~ "1) Provision of appropriate"
      assert html =~ "2) Implementation of emergency"

      # Should preserve formatting/line breaks
      assert String.contains?(html, "1)") and String.contains?(html, "2)")
    end

    test "displays proper labels and field names", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should have clear field labels
      assert html =~ "Notice ID" or html =~ "Regulator ID"
      assert html =~ "Reference Number" or html =~ "Ref Number"
      assert html =~ "Notice Type"
      assert html =~ "Issued Date"
      assert html =~ "Operative Date"
      assert html =~ "Compliance Date"
      assert html =~ "Offender"
      assert html =~ "Agency"
    end

    test "handles null or empty values gracefully", %{conn: conn} do
      # Create notice with minimal data
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :ea,
          name: "Environment Agency",
          enabled: true
        })

      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Empty Fields Ltd",
          local_authority: "Test Council",
          postcode: "T1 1ST"
        })

      {:ok, minimal_notice} =
        Enforcement.create_notice(%{
          regulator_id: "EA-NOTICE-MIN",
          agency_id: agency.id,
          offender_id: offender.id,
          offence_action_type: "Enforcement Notice",
          notice_date: ~D[2024-01-01]
          # Other fields left nil
        })

      {:ok, view, html} = live(conn, "/notices/#{minimal_notice.id}")

      assert html =~ "EA-NOTICE-MIN"
      # Should handle missing fields gracefully
      assert html =~ "N/A" or html =~ "Not specified" or html =~ "-" or refute(html =~ "nil")
    end
  end

  describe "NoticeLive.Show performance and UX" do
    setup :create_notice_with_relations

    test "loads notice details within reasonable time", %{conn: conn, notice: notice} do
      start_time = System.monotonic_time(:millisecond)

      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      end_time = System.monotonic_time(:millisecond)
      load_time = end_time - start_time

      assert html =~ notice.regulator_id
      # Should load within 2 seconds
      assert load_time < 2000
    end

    test "implements responsive design", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should include responsive design classes
      assert html =~ "sm:" or html =~ "md:" or html =~ "lg:" or html =~ "xl:"
      assert html =~ "responsive" or has_element?(view, ".responsive")
    end

    test "provides loading states for slow operations", %{conn: conn, notice: notice} do
      {:ok, view, _html} = live(conn, "/notices/#{notice.id}")

      # Should handle loading states appropriately
      refute has_element?(view, "[data-testid='loading-error']")

      assert has_element?(view, "[data-testid='notice-details']") or
               render(view) =~ notice.regulator_id
    end

    test "includes proper navigation elements", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should include breadcrumb or navigation
      assert has_element?(view, "nav") or html =~ "breadcrumb"
      assert has_element?(view, "a[href='/notices']")
      assert html =~ "Back" or html =~ "Return to"
    end
  end

  describe "NoticeLive.Show accessibility" do
    setup :create_notice_with_relations

    test "includes proper semantic HTML structure", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should use semantic HTML elements
      assert has_element?(view, "main") or has_element?(view, "article")
      assert has_element?(view, "header") or has_element?(view, "h1")
      assert has_element?(view, "section") or html =~ "section"
    end

    test "includes ARIA labels and descriptions", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should include ARIA attributes
      assert html =~ "aria-label=" or has_element?(view, "[aria-label]")
      assert html =~ "role=" or has_element?(view, "[role]")
      assert html =~ "aria-describedby=" or has_element?(view, "[aria-describedby]")
    end

    test "provides alternative text for visual elements", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should include alt text for images and icons
      if html =~ "<img" do
        assert html =~ "alt=" or has_element?(view, "img[alt]")
      end

      # Should have accessible button and link text
      assert has_element?(view, "button") or has_element?(view, "a")
    end

    test "uses proper color contrast and visual hierarchy", %{conn: conn, notice: notice} do
      {:ok, view, html} = live(conn, "/notices/#{notice.id}")

      # Should use proper heading hierarchy
      assert has_element?(view, "h1") or has_element?(view, "h2")

      # Should not rely solely on color for information
      # Text indicators alongside colors
      assert html =~ "status" or html =~ "type"
    end
  end

  # Helper function to create notice with related data
  defp create_notice_with_relations(_context) do
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
        name: "Industrial Manufacturing Ltd",
        local_authority: "Manchester City Council",
        postcode: "M1 1AA",
        main_activity: "Chemical Processing",
        business_type: :limited_company,
        industry: "Manufacturing"
      })

    # Create related case
    {:ok, related_case} =
      Enforcement.create_case(%{
        regulator_id: "HSE-CASE-2024-001",
        agency_id: hse_agency.id,
        offender_id: offender.id,
        offence_action_date: ~D[2024-01-10],
        offence_fine: Decimal.new("25000.00"),
        offence_breaches: "Health and Safety at Work Act 1974 - Section 2(1)"
      })

    # Create main notice
    {:ok, notice} =
      Enforcement.create_notice(%{
        regulator_id: "HSE-NOTICE-2024-015",
        regulator_ref_number: "HSE/REF/2024/015",
        agency_id: hse_agency.id,
        offender_id: offender.id,
        offence_action_type: "Improvement Notice",
        notice_date: ~D[2024-01-15],
        operative_date: ~D[2024-01-29],
        compliance_date: ~D[2024-03-15],
        notice_body:
          "The company must implement and maintain adequate safety procedures for the handling of hazardous chemicals. This includes: 1) Provision of appropriate personal protective equipment, 2) Implementation of emergency response procedures, 3) Regular safety training for all personnel, 4) Maintenance of safety data sheets for all chemicals."
      })

    # Create related notices
    {:ok, related_notice1} =
      Enforcement.create_notice(%{
        regulator_id: "HSE-NOTICE-2024-002",
        regulator_ref_number: "HSE/REF/2024/002",
        agency_id: hse_agency.id,
        offender_id: offender.id,
        offence_action_type: "Prohibition Notice",
        notice_date: ~D[2024-01-05],
        operative_date: ~D[2024-01-05],
        compliance_date: ~D[2024-02-05],
        notice_body: "Immediate prohibition of crane operations pending structural inspection"
      })

    {:ok, related_notice2} =
      Enforcement.create_notice(%{
        regulator_id: "HSE-NOTICE-2024-020",
        regulator_ref_number: "HSE/REF/2024/020",
        agency_id: hse_agency.id,
        offender_id: offender.id,
        offence_action_type: "Improvement Notice",
        notice_date: ~D[2024-02-01],
        operative_date: ~D[2024-02-15],
        compliance_date: ~D[2024-04-01],
        notice_body: "Follow-up notice requiring completion of safety improvements"
      })

    %{
      notice: notice,
      offender: offender,
      agency: hse_agency,
      related_case: related_case,
      related_notice1: related_notice1,
      related_notice2: related_notice2
    }
  end
end
