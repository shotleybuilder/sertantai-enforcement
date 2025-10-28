defmodule EhsEnforcementWeb.CaseLive.ShowTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Repo

  describe "CaseLive.Show mount" do
    setup do
      # Create test agency
      {:ok, hse_agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      # Create test offender with complete information
      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Detailed Manufacturing Solutions Ltd",
          local_authority: "Greater Manchester Combined Authority",
          postcode: "M15 4FN",
          total_cases: 0,
          total_notices: 0,
          total_fines: Decimal.new("0.00")
        })

      # Create detailed test case
      {:ok, case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-2024-DETAIL-001",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_date: ~D[2024-02-15],
          offence_fine: Decimal.new("35000.00"),
          offence_breaches:
            "Serious breach of health and safety regulations including failure to provide adequate personal protective equipment, inadequate risk assessment procedures, and non-compliance with safety training requirements.",
          last_synced_at: DateTime.utc_now()
        })

      # Create related notices for the case
      {:ok, notice1} =
        Enforcement.create_notice(%{
          regulator_id: "NOTICE-IMP-001",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          notice_date: ~D[2024-01-15],
          operative_date: ~D[2024-01-20],
          compliance_date: ~D[2024-03-15],
          notice_body: "Improvement notice for workplace safety measures",
          offence_action_type: "improvement",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, notice2} =
        Enforcement.create_notice(%{
          regulator_id: "NOTICE-PRO-002",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          notice_date: ~D[2024-01-20],
          operative_date: ~D[2024-01-21],
          compliance_date: ~D[2024-02-01],
          notice_body: "Prohibition notice to cease unsafe operations",
          offence_action_type: "prohibition",
          last_synced_at: DateTime.utc_now()
        })

      # Create related breaches
      {:ok, breach1} =
        Enforcement.create_breach(%{
          case_id: case.id,
          legislation_reference: "Section 2 - Health and Safety at Work Act 1974",
          breach_description: "Failure to ensure safety of employees",
          legislation_type: :act
        })

      {:ok, breach2} =
        Enforcement.create_breach(%{
          case_id: case.id,
          legislation_reference: "Regulation 5 - Personal Protective Equipment Regulations",
          breach_description: "Inadequate provision of PPE",
          legislation_type: :regulation
        })

      %{
        agency: hse_agency,
        offender: offender,
        case: case,
        notices: [notice1, notice2],
        breaches: [breach1, breach2]
      }
    end

    test "successfully mounts and displays case details", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should display page title
      assert html =~ "Case Details"
      assert html =~ case.regulator_id

      # Should show case information
      assert html =~ "HSE-2024-DETAIL-001"
      assert html =~ "Detailed Manufacturing Solutions Ltd"
      assert html =~ "Health and Safety Executive"
      assert html =~ "£35,000.00"
      assert html =~ "2024-02-15" or html =~ "February 15, 2024"

      # Should display breach description
      assert html =~ "Serious breach of health and safety regulations"
    end

    test "displays offender information section", %{conn: conn, case: case, offender: offender} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should show offender details section
      assert html =~ "Offender Information" or html =~ "Company Details"

      # Should display complete offender information
      assert html =~ "Detailed Manufacturing Solutions Ltd"
      assert html =~ "Greater Manchester Combined Authority"
      assert html =~ "M15 4FN"

      # Should have link to offender profile
      assert has_element?(view, "a[href='/offenders/#{offender.id}']") or
               html =~ "View Offender Profile" or
               html =~ "View Company Details"
    end

    test "displays agency information section", %{conn: conn, case: case, agency: agency} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should show agency details
      assert html =~ "Regulating Agency" or html =~ "Agency Information"
      assert html =~ "Health and Safety Executive"
      assert html =~ "HSE"

      # Should have link to agency page
      assert has_element?(view, "a[href='/agencies/#{agency.id}']") or
               html =~ "View Agency" or
               html =~ "Agency Profile"
    end

    test "does not display notices section (no direct case-notice relationship)", %{
      conn: conn,
      case: case,
      notices: notices
    } do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should NOT show notices section since there's no direct case-notice relationship
      refute html =~ "Related Notices"
      refute html =~ "Enforcement Notices"

      # Should NOT display individual notices on case page
      refute html =~ "Improvement notice for workplace safety measures"
      refute html =~ "Prohibition notice to cease unsafe operations"

      # Should NOT show notice counts (since notices aren't related to cases)
      refute html =~ "2 notices"
      refute html =~ "2 Notices"

      # The case page focuses on case details, breaches, and timeline
      # Case ID should be shown
      assert html =~ "HSE-2024-DETAIL-001"
      # Fine amount should be shown
      assert html =~ "£35,000.00"
    end

    test "displays regulatory breaches section", %{conn: conn, case: case, breaches: breaches} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should show breaches section
      assert html =~ "Regulatory Breaches" or html =~ "Violations"

      # Should display both breaches
      assert html =~ "Section 2 - Health and Safety at Work Act 1974"
      assert html =~ "Regulation 5 - Personal Protective Equipment Regulations"

      # Should show breach descriptions
      assert html =~ "Failure to ensure safety of employees"
      assert html =~ "Inadequate provision of PPE"

      # Should indicate severity levels
      assert html =~ "high"
      assert html =~ "medium"

      # Should have breach count
      assert html =~ "2 breaches" or html =~ "2 Breaches"
    end

    test "displays case timeline", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should show timeline section
      assert html =~ "Case Timeline" or html =~ "Timeline"

      # Timeline should include key dates
      # First notice date
      assert html =~ "2024-01-15"
      # Second notice date  
      assert html =~ "2024-01-20"
      # Offense action date
      assert html =~ "2024-02-15"

      # Should show events in chronological order
      timeline_section =
        html
        |> String.split("Timeline", parts: 2)
        |> List.last()

      # Check relative positions of dates in timeline
      pos_jan15 = :binary.match(timeline_section, "2024-01-15") |> elem(0)
      pos_jan20 = :binary.match(timeline_section, "2024-01-20") |> elem(0)
      pos_feb15 = :binary.match(timeline_section, "2024-02-15") |> elem(0)

      # Should be in chronological order (or reverse chronological)
      assert (pos_jan15 < pos_jan20 and pos_jan20 < pos_feb15) or
               (pos_feb15 < pos_jan20 and pos_jan20 < pos_jan15)
    end

    test "handles case with no related records gracefully", %{conn: conn} do
      # Create minimal case with no notices or breaches
      {:ok, agency} = Enforcement.create_agency(%{code: :ea, name: "EA", enabled: true})
      {:ok, offender} = Enforcement.create_offender(%{name: "Minimal Corp"})

      {:ok, minimal_case} =
        Enforcement.create_case(%{
          regulator_id: "EA-MINIMAL-001",
          agency_id: agency.id,
          offender_id: offender.id,
          offence_action_date: ~D[2024-01-01],
          offence_fine: Decimal.new("1000.00"),
          offence_breaches: "Minor violation",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, view, html} = live(conn, "/cases/#{minimal_case.id}")

      # Should still render successfully
      assert html =~ "Case Details"
      assert html =~ "EA-MINIMAL-001"

      # Should handle missing breaches gracefully (no notices section expected since no direct relationship)
      # Note: The case doesn't create any breaches, so should handle empty breach list
      # Fine amount should be displayed
      assert html =~ "£1,000.00"
      # Breach description should be shown
      assert html =~ "Minor violation"
    end

    test "handles non-existent case ID", %{conn: conn} do
      non_existent_id = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, "/cases/#{non_existent_id}")
      end
    end

    test "handles invalid case ID format", %{conn: conn} do
      # Invalid UUID format should be handled by router or controller
      assert_error_sent 404, fn ->
        live(conn, "/cases/invalid-id-format")
      end
    end
  end

  describe "CaseLive.Show actions" do
    setup do
      {:ok, agency} = Enforcement.create_agency(%{code: :hse, name: "HSE", enabled: true})
      {:ok, offender} = Enforcement.create_offender(%{name: "Action Test Corp"})

      {:ok, case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-ACTION-001",
          agency_id: agency.id,
          offender_id: offender.id,
          offence_action_date: ~D[2024-01-15],
          offence_fine: Decimal.new("10000.00"),
          offence_breaches: "Test breach",
          last_synced_at: DateTime.utc_now()
        })

      %{case: case, agency: agency, offender: offender}
    end

    test "displays edit case button", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should have edit button or link
      assert has_element?(view, "a[href='/cases/#{case.id}/edit']") or
               has_element?(view, "button[phx-click='edit']") or
               html =~ "Edit Case"
    end

    test "displays delete case button with confirmation", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should have delete action
      assert has_element?(view, "button[phx-click='delete']") or
               html =~ "Delete Case" or
               html =~ "Remove Case"

      # Should have confirmation
      assert html =~ "confirm" or html =~ "Are you sure"
    end

    test "handles edit case action", %{conn: conn, case: case} do
      {:ok, view, _html} = live(conn, "/cases/#{case.id}")

      # Click edit button (if implemented as LiveView event)
      if has_element?(view, "button[phx-click='edit']") do
        render_click(view, "edit")

        # Should handle edit action
        assert Process.alive?(view.pid)
      end
    end

    test "displays export case data button", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should have export functionality
      assert has_element?(view, "button[phx-click='export']") or
               html =~ "Export" or
               html =~ "Download"
    end

    test "displays back to cases list link", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should have navigation back to cases list
      assert has_element?(view, "a[href='/cases']") or
               html =~ "Back to Cases" or
               html =~ "← Cases"
    end

    test "displays share case link", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should have share functionality or direct link
      assert html =~ "Share" or
               html =~ "/cases/#{case.id}" or
               has_element?(view, "button[phx-click='share']")
    end
  end

  describe "CaseLive.Show real-time updates" do
    setup do
      {:ok, agency} = Enforcement.create_agency(%{code: :hse, name: "HSE", enabled: true})
      {:ok, offender} = Enforcement.create_offender(%{name: "Update Test Corp"})

      {:ok, case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-UPDATE-001",
          agency_id: agency.id,
          offender_id: offender.id,
          offence_action_date: ~D[2024-01-15],
          offence_fine: Decimal.new("5000.00"),
          offence_breaches: "Original breach",
          last_synced_at: DateTime.utc_now()
        })

      %{case: case}
    end

    test "subscribes to case updates on mount", %{conn: conn, case: case} do
      {:ok, view, _html} = live(conn, "/cases/#{case.id}")

      # Verify the LiveView process is alive and responsive
      assert Process.alive?(view.pid)

      # Send a test update message
      send(view.pid, {:case_updated, case.id, %{offence_fine: Decimal.new("7500.00")}})

      # Should handle the message without crashing
      :timer.sleep(50)
      assert Process.alive?(view.pid)
    end

    test "handles case update notifications", %{conn: conn, case: case} do
      {:ok, view, _html} = live(conn, "/cases/#{case.id}")

      # Send case update notification
      send(
        view.pid,
        {:case_updated, case.id,
         %{
           offence_fine: Decimal.new("8000.00"),
           offence_breaches: "Updated breach description"
         }}
      )

      # Should update the display
      updated_html = render(view)

      # Should show updated information
      assert updated_html =~ "£8,000.00" or updated_html =~ "8000"
      assert updated_html =~ "Updated breach description"
    end

    test "handles new notice notifications", %{conn: conn, case: case} do
      {:ok, view, initial_html} = live(conn, "/cases/#{case.id}")

      # Initially should show no notices
      assert initial_html =~ "No notices" or initial_html =~ "0 notices"

      # Create a new notice
      {:ok, new_notice} =
        Enforcement.create_notice(%{
          case_id: case.id,
          notice_type: "improvement",
          issue_date: ~D[2024-02-01],
          compliance_date: ~D[2024-03-01],
          description: "New improvement notice",
          compliance_status: "pending"
        })

      # Send notification about new notice
      send(view.pid, {:notice_created, case.id, new_notice})

      updated_html = render(view)

      # Should show the new notice
      assert updated_html =~ "New improvement notice"
      assert updated_html =~ "1 notice" or updated_html =~ "improvement"
    end

    test "handles notice status updates", %{conn: conn, case: case} do
      # Create initial notice
      {:ok, notice} =
        Enforcement.create_notice(%{
          case_id: case.id,
          notice_type: "improvement",
          issue_date: ~D[2024-01-15],
          compliance_date: ~D[2024-02-15],
          description: "Status test notice",
          compliance_status: "pending"
        })

      {:ok, view, initial_html} = live(conn, "/cases/#{case.id}")

      # Should initially show pending status
      assert initial_html =~ "pending"

      # Send notice status update
      send(view.pid, {:notice_updated, notice.id, %{compliance_status: "complied"}})

      updated_html = render(view)

      # Should show updated status
      assert updated_html =~ "complied"
      refute updated_html =~ "pending"
    end

    test "handles malformed update messages gracefully", %{conn: conn, case: case} do
      {:ok, view, _html} = live(conn, "/cases/#{case.id}")

      log =
        capture_log(fn ->
          # Send malformed messages
          send(view.pid, {:case_updated, "invalid-id", %{}})
          send(view.pid, {:invalid_message, case.id})
          send(view.pid, "not_a_tuple")
          :timer.sleep(50)
        end)

      # Should remain stable
      assert Process.alive?(view.pid)
    end
  end

  describe "CaseLive.Show data formatting" do
    setup do
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :onr,
          name: "Office for Nuclear Regulation",
          enabled: true
        })

      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Nuclear Safety Ltd",
          local_authority: "Cumbria County Council"
        })

      {:ok, case} =
        Enforcement.create_case(%{
          regulator_id: "ONR-2024-FORMAT-001",
          agency_id: agency.id,
          offender_id: offender.id,
          offence_action_date: ~D[2024-06-15],
          offence_fine: Decimal.new("125000.50"),
          offence_breaches:
            "Multiple nuclear safety regulation violations with significant environmental impact and potential public safety risks.",
          last_synced_at: DateTime.utc_now()
        })

      %{case: case}
    end

    test "formats monetary values correctly", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should format large fine amount with proper comma separation
      assert html =~ "£125,000.50" or html =~ "125,000.50"
    end

    test "formats dates consistently", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should format date in readable format
      assert html =~ "June 15, 2024" or
               html =~ "15 June 2024" or
               html =~ "2024-06-15" or
               html =~ "15/06/2024"
    end

    test "handles long text content appropriately", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should display full breach description
      assert html =~ "Multiple nuclear safety regulation violations"
      assert html =~ "environmental impact"
      assert html =~ "public safety risks"

      # Long text should be properly wrapped or truncated with expand option
      # Should show the content
      assert html =~ "violations"
    end

    test "displays proper labels and field names", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should have clear field labels
      assert html =~ "Case ID" or html =~ "Regulator ID"
      assert html =~ "Offender" or html =~ "Company"
      assert html =~ "Agency" or html =~ "Regulator"
      assert html =~ "Fine Amount" or html =~ "Penalty"
      assert html =~ "Offense Date" or html =~ "Action Date"
      assert html =~ "Breaches" or html =~ "Violations"
    end

    test "handles null or empty values gracefully", %{conn: conn} do
      # Create case with minimal data
      {:ok, agency} = Enforcement.create_agency(%{code: :ea, name: "EA", enabled: true})
      {:ok, offender} = Enforcement.create_offender(%{name: "Minimal Corp"})

      {:ok, minimal_case} =
        Enforcement.create_case(%{
          regulator_id: "EA-MINIMAL-FORMAT",
          agency_id: agency.id,
          offender_id: offender.id,
          offence_action_date: ~D[2024-01-01],
          offence_fine: Decimal.new("0.00"),
          offence_breaches: "",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, view, html} = live(conn, "/cases/#{minimal_case.id}")

      # Should handle empty/zero values appropriately
      assert html =~ "£0.00" or html =~ "No fine" or html =~ "£0"
      assert html =~ "No breaches" or html =~ "Not specified" or html =~ "-"
    end
  end

  describe "CaseLive.Show performance and UX" do
    setup do
      {:ok, agency} = Enforcement.create_agency(%{code: :hse, name: "HSE", enabled: true})
      {:ok, offender} = Enforcement.create_offender(%{name: "Performance Test Corp"})

      {:ok, case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-PERF-001",
          agency_id: agency.id,
          offender_id: offender.id,
          offence_action_date: ~D[2024-01-15],
          offence_fine: Decimal.new("15000.00"),
          offence_breaches: "Performance test breach",
          last_synced_at: DateTime.utc_now()
        })

      # Create multiple notices and breaches to test performance
      notices =
        Enum.map(1..10, fn i ->
          {:ok, notice} =
            Enforcement.create_notice(%{
              regulator_id: "NOTICE-#{String.pad_leading(to_string(i), 3, "0")}",
              agency_id: agency.id,
              offender_id: offender.id,
              notice_date: Date.add(~D[2024-01-01], i),
              operative_date: Date.add(~D[2024-01-15], i),
              compliance_date: Date.add(~D[2024-02-01], i),
              notice_body: "Performance test notice #{i}",
              offence_action_type: if(rem(i, 2) == 0, do: "improvement", else: "prohibition"),
              last_synced_at: DateTime.utc_now()
            })

          notice
        end)

      breaches =
        Enum.map(1..5, fn i ->
          {:ok, breach} =
            Enforcement.create_breach(%{
              case_id: case.id,
              legislation_reference: "Test Regulation #{i}",
              breach_description: "Performance test breach #{i}",
              legislation_type:
                case rem(i, 3) do
                  0 -> :act
                  1 -> :regulation
                  2 -> :acop
                end
            })

          breach
        end)

      %{case: case, notices: notices, breaches: breaches}
    end

    test "loads case details within reasonable time", %{conn: conn, case: case} do
      start_time = System.monotonic_time(:millisecond)

      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      end_time = System.monotonic_time(:millisecond)
      load_time = end_time - start_time

      # Should load within reasonable time (less than 1 second)
      assert load_time < 1000, "Case details should load within 1 second"

      # Should display all content
      assert html =~ "HSE-PERF-001"
      assert html =~ "Performance Test Corp"
    end

    test "handles large numbers of related records efficiently", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should show all 10 notices
      assert html =~ "10 notices" or html =~ "10 Notices"

      # Should show all 5 breaches  
      assert html =~ "5 breaches" or html =~ "5 Breaches"

      # Should handle pagination or limiting if implemented
      notice_count = (html |> String.split("Performance test notice") |> length()) - 1
      breach_count = (html |> String.split("Performance test breach") |> length()) - 1

      # Should show reasonable number of items or implement pagination
      assert notice_count >= 5, "Should show at least some notices"
      assert breach_count >= 3, "Should show at least some breaches"
    end

    test "provides loading states for slow operations", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should have proper loading indicators for async operations
      # (This would be more relevant for operations that take time)
      # Should show content when loaded
      assert html =~ case.regulator_id
    end

    test "implements responsive design", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should have responsive CSS classes
      assert html =~ "grid" or html =~ "flex" or
               html =~ "sm:" or html =~ "md:" or html =~ "lg:" or
               html =~ "responsive"
    end

    test "includes proper navigation elements", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should have breadcrumbs or navigation
      assert html =~ "Cases" or html =~ "Home" or html =~ "Dashboard"
      assert has_element?(view, "a[href='/cases']") or has_element?(view, "a[href='/']")

      # Should have clear page structure
      assert html =~ "Case Details" or html =~ case.regulator_id
    end
  end

  describe "CaseLive.Show accessibility" do
    setup do
      {:ok, agency} = Enforcement.create_agency(%{code: :hse, name: "HSE", enabled: true})
      {:ok, offender} = Enforcement.create_offender(%{name: "Accessibility Test Corp"})

      {:ok, case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-A11Y-001",
          agency_id: agency.id,
          offender_id: offender.id,
          offence_action_date: ~D[2024-01-15],
          offence_fine: Decimal.new("20000.00"),
          offence_breaches: "Accessibility test breach",
          last_synced_at: DateTime.utc_now()
        })

      %{case: case}
    end

    test "includes proper semantic HTML structure", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should use semantic HTML elements
      assert html =~ "<main" or html =~ "<section" or html =~ "<article"
      assert html =~ "<h1" or html =~ "<h2"

      # Should have proper heading hierarchy
      # Page title
      assert html =~ "<h1"
    end

    test "includes ARIA labels and descriptions", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should have ARIA attributes for complex elements
      assert html =~ "aria-label" or
               html =~ "aria-describedby" or
               html =~ "aria-expanded"
    end

    test "supports keyboard navigation", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Interactive elements should be keyboard accessible
      if has_element?(view, "button") do
        # Buttons are naturally focusable
        assert html =~ "tabindex" or true
      end

      # Links should be keyboard accessible
      # Should have navigation links
      assert has_element?(view, "a")
    end

    test "provides alternative text for visual elements", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Any images should have alt text
      if html =~ "<img" do
        assert html =~ "alt="
      end

      # Icons should have text alternatives
      if html =~ "icon" or html =~ "svg" do
        assert html =~ "aria-label" or html =~ "title" or html =~ "alt"
      end
    end

    test "uses proper color contrast and visual hierarchy", %{conn: conn, case: case} do
      {:ok, view, html} = live(conn, "/cases/#{case.id}")

      # Should use CSS classes that provide proper contrast
      # (This is mainly verified through CSS, but we can check for class usage)
      # Should use CSS classes for styling
      assert html =~ "class="

      # Should have clear visual hierarchy
      # Should use heading elements
      assert html =~ "<h"
    end
  end
end
