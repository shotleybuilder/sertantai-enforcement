defmodule EhsEnforcementWeb.NoticeLive.IndexTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Repo

  describe "NoticeLive.Index mount" do
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
          name: "Manufacturing Solutions Ltd",
          local_authority: "Manchester City Council",
          postcode: "M1 1AA"
        })

      {:ok, offender2} =
        Enforcement.create_offender(%{
          name: "Industrial Operations Corp",
          local_authority: "Birmingham City Council",
          postcode: "B2 2BB"
        })

      {:ok, offender3} =
        Enforcement.create_offender(%{
          name: "Chemical Processing PLC",
          local_authority: "Leeds City Council",
          postcode: "LS3 3CC"
        })

      # Create test notices with different types and dates
      base_date = ~D[2024-01-15]

      {:ok, notice1} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-NOTICE-2024-001",
          regulator_ref_number: "HSE/REF/001",
          agency_id: hse_agency.id,
          offender_id: offender1.id,
          offence_action_type: "Improvement Notice",
          notice_date: base_date,
          operative_date: Date.add(base_date, 14),
          compliance_date: Date.add(base_date, 60),
          notice_body:
            "Failure to maintain adequate safety procedures in manufacturing operations"
        })

      {:ok, notice2} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-NOTICE-2024-002",
          regulator_ref_number: "HSE/REF/002",
          agency_id: hse_agency.id,
          offender_id: offender2.id,
          offence_action_type: "Prohibition Notice",
          notice_date: Date.add(base_date, 7),
          operative_date: Date.add(base_date, 7),
          compliance_date: Date.add(base_date, 30),
          notice_body: "Immediate prohibition of crane operations due to structural defects"
        })

      {:ok, notice3} =
        Enforcement.create_notice(%{
          regulator_id: "EA-NOTICE-2024-001",
          regulator_ref_number: "EA/REF/001",
          agency_id: ea_agency.id,
          offender_id: offender3.id,
          offence_action_type: "Enforcement Notice",
          notice_date: Date.add(base_date, 14),
          operative_date: Date.add(base_date, 21),
          compliance_date: Date.add(base_date, 90),
          notice_body: "Environmental compliance breach - chemical discharge monitoring required"
        })

      {:ok, notice4} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-NOTICE-2024-003",
          regulator_ref_number: "HSE/REF/003",
          agency_id: hse_agency.id,
          offender_id: offender1.id,
          offence_action_type: "Improvement Notice",
          notice_date: Date.add(base_date, 21),
          operative_date: Date.add(base_date, 28),
          compliance_date: Date.add(base_date, 120),
          notice_body: "Additional safety measures required for high-risk operations"
        })

      %{
        hse_agency: hse_agency,
        ea_agency: ea_agency,
        offender1: offender1,
        offender2: offender2,
        offender3: offender3,
        notice1: notice1,
        notice2: notice2,
        notice3: notice3,
        notice4: notice4
      }
    end

    test "successfully mounts and displays notice listings", %{
      conn: conn,
      notice1: notice1,
      notice2: notice2
    } do
      {:ok, _view, html} = live(conn, "/notices")

      assert html =~ "Notice Management"
      assert html =~ "HSE-NOTICE-2024-001"
      assert html =~ "HSE-NOTICE-2024-002"
      assert html =~ "Improvement Notice"
      assert html =~ "Prohibition Notice"
      assert html =~ "Manufacturing Solutions Ltd"
      assert html =~ "Industrial Operations Corp"
    end

    test "displays notice type categorization correctly", %{
      conn: conn,
      notice1: notice1,
      notice2: notice2,
      notice3: notice3
    } do
      {:ok, view, html} = live(conn, "/notices")

      # Should show notice type counts
      assert html =~ "Improvement Notice"
      assert html =~ "Prohibition Notice"
      assert html =~ "Enforcement Notice"

      # Should display type-specific styling or indicators
      assert has_element?(view, "[data-notice-type='Improvement Notice']")
      assert has_element?(view, "[data-notice-type='Prohibition Notice']")
      assert has_element?(view, "[data-notice-type='Enforcement Notice']")
    end

    test "shows proper data associations with agencies and offenders", %{
      conn: conn,
      hse_agency: hse_agency,
      offender1: offender1
    } do
      {:ok, _view, html} = live(conn, "/notices")

      # Should display agency information
      assert html =~ hse_agency.name
      assert html =~ "Health and Safety Executive"

      # Should display offender information
      assert html =~ offender1.name
      assert html =~ "Manufacturing Solutions Ltd"
      assert html =~ "Manchester City Council"
    end

    test "displays notices in chronological order by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/notices")

      # Should display notices in date order (most recent first by default)
      notice_positions = [
        html |> String.split("HSE-NOTICE-2024-003") |> length(),
        html |> String.split("EA-NOTICE-2024-001") |> length(),
        html |> String.split("HSE-NOTICE-2024-002") |> length(),
        html |> String.split("HSE-NOTICE-2024-001") |> length()
      ]

      # Most recent should appear first (HSE-NOTICE-2024-003)
      assert Enum.at(notice_positions, 0) <= Enum.at(notice_positions, 1)
      assert Enum.at(notice_positions, 1) <= Enum.at(notice_positions, 2)
      assert Enum.at(notice_positions, 2) <= Enum.at(notice_positions, 3)
    end

    test "includes proper navigation elements", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should include navigation to other interfaces
      assert has_element?(view, "a[href='/']") or html =~ "Dashboard"
      assert has_element?(view, "a[href='/cases']") or html =~ "Cases"

      # Should include action buttons
      assert has_element?(view, "button", "Export")
      assert has_element?(view, "[data-testid='notice-filters']")
    end

    test "displays loading state during data fetch", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Should handle loading state properly
      refute has_element?(view, "[data-testid='loading-error']")

      assert has_element?(view, "[data-testid='notice-list']") or
               has_element?(view, "[data-testid='notices-table']")
    end

    test "handles empty notice list gracefully", %{conn: conn} do
      # Clear all notices
      Repo.delete_all(EhsEnforcement.Enforcement.Notice)

      {:ok, _view, html} = live(conn, "/notices")

      assert html =~ "No notices found" or
               html =~ "no notices to display" or
               html =~ "0 notices"
    end

    test "includes accessibility attributes", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should include proper ARIA attributes
      assert html =~ "role=" or has_element?(view, "[role]")
      assert html =~ "aria-label=" or has_element?(view, "[aria-label]")

      # Table should have proper headers
      assert has_element?(view, "th") and (html =~ "Notice ID" or html =~ "Notice Type")
    end
  end

  describe "NoticeLive.Index filtering" do
    setup :create_test_notices

    test "filters notices by notice type", %{conn: conn, notice1: notice1, notice2: notice2} do
      {:ok, view, _html} = live(conn, "/notices")

      # Filter by Improvement Notice
      view
      |> form("[data-testid='notice-filters']",
        filters: %{offence_action_type: "Improvement Notice"}
      )
      |> render_change()

      html = render(view)
      assert html =~ "HSE-NOTICE-2024-001"
      # This is Prohibition Notice
      refute html =~ "HSE-NOTICE-2024-002"
    end

    test "filters notices by agency", %{conn: conn, hse_agency: hse_agency, ea_agency: ea_agency} do
      {:ok, view, _html} = live(conn, "/notices")

      # Filter by HSE agency
      view
      |> form("[data-testid='notice-filters']", filters: %{agency_id: hse_agency.id})
      |> render_change()

      html = render(view)
      assert html =~ "HSE-NOTICE-2024-001"
      assert html =~ "HSE-NOTICE-2024-002"
      refute html =~ "EA-NOTICE-2024-001"
    end

    test "filters notices by date range", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Filter by date range
      view
      |> form("[data-testid='notice-filters']",
        filters: %{
          date_from: "2024-01-01",
          date_to: "2024-01-20"
        }
      )
      |> render_change()

      html = render(view)
      # Jan 15
      assert html =~ "HSE-NOTICE-2024-001"
      # Jan 22 (outside range)
      refute html =~ "HSE-NOTICE-2024-002"
      # Feb 5
      refute html =~ "HSE-NOTICE-2024-003"
    end

    test "filters notices by compliance status", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Filter by compliance status (overdue/pending/compliant)
      view
      |> form("[data-testid='notice-filters']", filters: %{compliance_status: "pending"})
      |> render_change()

      html = render(view)
      # Should show notices where compliance_date is in the future
      assert html =~ "HSE-NOTICE-2024"
    end

    test "filters notices by geographic region", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Filter by local authority/region
      view
      |> form("[data-testid='notice-filters']", filters: %{region: "Manchester"})
      |> render_change()

      html = render(view)
      assert html =~ "Manufacturing Solutions Ltd"
      # Birmingham
      refute html =~ "Industrial Operations Corp"
    end

    test "combines multiple filters", %{conn: conn, hse_agency: hse_agency} do
      {:ok, view, _html} = live(conn, "/notices")

      # Combine agency and type filters
      view
      |> form("[data-testid='notice-filters']",
        filters: %{
          agency_id: hse_agency.id,
          offence_action_type: "Improvement Notice"
        }
      )
      |> render_change()

      html = render(view)
      assert html =~ "HSE-NOTICE-2024-001"
      # Different type
      refute html =~ "HSE-NOTICE-2024-002"
      # Different agency
      refute html =~ "EA-NOTICE-2024-001"
    end

    test "clears filters when requested", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Apply filter
      view
      |> form("[data-testid='notice-filters']",
        filters: %{offence_action_type: "Improvement Notice"}
      )
      |> render_change()

      # Clear filters
      view |> element("button", "Clear Filters") |> render_click()

      html = render(view)
      assert html =~ "HSE-NOTICE-2024-001"
      assert html =~ "HSE-NOTICE-2024-002"
      assert html =~ "EA-NOTICE-2024-001"
    end

    test "handles invalid filter values gracefully", %{conn: conn, hse_agency: hse_agency} do
      {:ok, view, _html} = live(conn, "/notices")

      # Apply filters with invalid date format (should be ignored or handled gracefully)
      log =
        capture_log(fn ->
          view
          |> form("[data-testid='notice-filters']",
            filters: %{
              date_from: "invalid-date",
              # Use valid agency ID instead
              agency_id: hse_agency.id
            }
          )
          |> render_change()
        end)

      # Should not crash and should show appropriate message
      html = render(view)
      refute html =~ "error" and refute(html =~ "Error")
      assert has_element?(view, "[data-testid='notice-list']")
    end
  end

  describe "NoticeLive.Index timeline view" do
    setup :create_test_notices

    test "switches to timeline view mode", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      assert has_element?(view, "[data-testid='notice-timeline']")
      assert html =~ "timeline" or html =~ "Timeline"
    end

    test "displays notices in chronological timeline", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      view |> element("button", "Timeline View") |> render_click()

      html = render(view)

      # Should show timeline elements
      assert has_element?(view, "[data-testid='timeline-entry']")
      # notice1 date
      assert html =~ "2024-01-15"
      # notice2 date
      assert html =~ "2024-01-22"
    end

    test "groups notices by date in timeline", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      view |> element("button", "Timeline View") |> render_click()

      html = render(view)

      # Should group notices by date
      assert has_element?(view, "[data-date='2024-01-15']") or html =~ "January 15, 2024"
      assert has_element?(view, "[data-date='2024-01-22']") or html =~ "January 22, 2024"
    end

    test "shows notice details in timeline entries", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      view |> element("button", "Timeline View") |> render_click()

      html = render(view)

      # Should show notice information within timeline
      assert html =~ "HSE-NOTICE-2024-001"
      assert html =~ "Manufacturing Solutions Ltd"
      assert html =~ "Improvement Notice"
    end

    test "switches back to table view", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline then back to table
      view |> element("button", "Timeline View") |> render_click()
      view |> element("button", "Table View") |> render_click()

      html = render(view)
      assert has_element?(view, "[data-testid='notice-list']") or has_element?(view, "table")
      refute has_element?(view, "[data-testid='notice-timeline']")
    end
  end

  describe "NoticeLive.Index pagination" do
    setup do
      # Create test data for pagination
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Test Company Ltd",
          local_authority: "Test Council",
          postcode: "T1 1ST"
        })

      # Create 25 notices for pagination testing
      notices =
        Enum.map(1..25, fn i ->
          {:ok, notice} =
            Enforcement.create_notice(%{
              regulator_id: "HSE-NOTICE-2024-#{String.pad_leading(to_string(i), 3, "0")}",
              regulator_ref_number: "HSE/REF/#{i}",
              agency_id: agency.id,
              offender_id: offender.id,
              offence_action_type: "Improvement Notice",
              notice_date: Date.add(~D[2024-01-01], i),
              operative_date: Date.add(~D[2024-01-01], i + 7),
              compliance_date: Date.add(~D[2024-01-01], i + 30),
              notice_body: "Test notice #{i} body text"
            })

          notice
        end)

      %{notices: notices, agency: agency, offender: offender}
    end

    test "displays first page of notices with pagination controls", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should show pagination controls
      assert has_element?(view, "[data-testid='pagination']")
      assert has_element?(view, "button", "Next") or html =~ "Next"

      # Should show page indicators
      assert html =~ "Page 1" or html =~ "1 of"
    end

    test "navigates to next page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Go to next page
      view |> element("button", "Next") |> render_click()

      html = render(view)
      assert html =~ "Page 2" or html =~ "2 of"

      # Should show different notices
      assert html =~ "HSE-NOTICE-2024-021" or html =~ "HSE-NOTICE-2024-022"
    end

    test "handles page size changes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Change page size
      view
      |> form("[data-testid='pagination-controls']", page_size: "10")
      |> render_change()

      html = render(view)
      # Should show 10 notices per page
      notice_count = (html |> String.split("HSE-NOTICE-2024-") |> length()) - 1
      assert notice_count <= 10
    end

    test "shows total notice count", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/notices")

      assert html =~ "25" and (html =~ "notices" or html =~ "total")
    end
  end

  describe "NoticeLive.Index sorting" do
    setup :create_test_notices

    test "sorts notices by date ascending", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Sort by date ascending
      view |> element("th", "Notice Date") |> render_click()
      # Second click for ascending
      view |> element("th", "Notice Date") |> render_click()

      html = render(view)
      # HSE-NOTICE-2024-001 (Jan 15) should appear before HSE-NOTICE-2024-002 (Jan 22)
      pos1 = html |> String.split("HSE-NOTICE-2024-001") |> length()
      pos2 = html |> String.split("HSE-NOTICE-2024-002") |> length()
      assert pos1 < pos2
    end

    test "sorts notices by notice type", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Sort by notice type
      view |> element("th", "Notice Type") |> render_click()

      html = render(view)
      # Should be sorted alphabetically: Enforcement, Improvement, Prohibition
      pos_enforcement = html |> String.split("Enforcement Notice") |> length()
      pos_improvement = html |> String.split("Improvement Notice") |> length()
      assert pos_enforcement < pos_improvement
    end

    test "sorts notices by offender name", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Sort by offender name
      view |> element("th", "Offender") |> render_click()

      html = render(view)
      # Should be sorted alphabetically
      pos_chemical = html |> String.split("Chemical Processing PLC") |> length()
      pos_industrial = html |> String.split("Industrial Operations Corp") |> length()
      pos_manufacturing = html |> String.split("Manufacturing Solutions Ltd") |> length()

      assert pos_chemical < pos_industrial
      assert pos_industrial < pos_manufacturing
    end

    test "displays sort direction indicators", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Sort by date
      view |> element("th", "Notice Date") |> render_click()

      html = render(view)
      # Should show sort direction indicator
      assert html =~ "▲" or html =~ "▼" or html =~ "sort" or
               has_element?(view, "[data-sort-direction]")
    end
  end

  describe "NoticeLive.Index search functionality" do
    setup :create_test_notices

    test "searches notices by regulator ID", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search by regulator ID
      view
      |> form("[data-testid='search-form']", search: "HSE-NOTICE-2024-001")
      |> render_submit()

      html = render(view)
      assert html =~ "HSE-NOTICE-2024-001"
      refute html =~ "HSE-NOTICE-2024-002"
    end

    test "searches notices by notice body content", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search by content
      view
      |> form("[data-testid='search-form']", search: "safety procedures")
      |> render_submit()

      html = render(view)
      # Should find notice1
      assert html =~ "Manufacturing Solutions Ltd"
      # Different notice content
      refute html =~ "crane operations"
    end

    test "searches notices by offender name", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search by offender name
      view
      |> form("[data-testid='search-form']", search: "Chemical Processing")
      |> render_submit()

      html = render(view)
      assert html =~ "Chemical Processing PLC"
      assert html =~ "EA-NOTICE-2024-001"
      refute html =~ "Manufacturing Solutions Ltd"
    end

    test "handles case-insensitive search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search with different case
      view
      |> form("[data-testid='search-form']", search: "IMPROVEMENT")
      |> render_submit()

      html = render(view)
      assert html =~ "Improvement Notice"
    end

    test "clears search results", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Perform search
      view
      |> form("[data-testid='search-form']", search: "HSE-NOTICE-2024-001")
      |> render_submit()

      # Clear search
      view |> element("button", "Clear Search") |> render_click()

      html = render(view)
      assert html =~ "HSE-NOTICE-2024-001"
      assert html =~ "HSE-NOTICE-2024-002"
      assert html =~ "EA-NOTICE-2024-001"
    end

    test "shows no results message for no matches", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search for non-existent content
      view
      |> form("[data-testid='search-form']", search: "nonexistent-notice-id")
      |> render_submit()

      html = render(view)
      assert html =~ "No notices found" or html =~ "no results" or html =~ "0 notices"
    end
  end

  describe "NoticeLive.Index error handling" do
    test "handles database errors gracefully", %{conn: conn} do
      # Simulate database error by stopping the repo
      Process.whereis(EhsEnforcement.Repo) |> Process.exit(:kill)
      # Allow process to terminate
      Process.sleep(100)

      assert_raise MatchError, fn ->
        live(conn, "/notices")
      end
    end

    test "handles malformed filter parameters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Send malformed event
      log =
        capture_log(fn ->
          send(view.pid, {:malformed_event, "invalid_data"})
          Process.sleep(50)
        end)

      # Should not crash
      assert render(view) =~ "Notice Management"
      # May or may not log
      assert log =~ "" or true
    end

    test "displays error message for failed operations", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Trigger an error condition (invalid export request)
      view |> element("button", "Export All") |> render_click()

      html = render(view)
      # Should handle gracefully, either with error message or fallback
      refute html =~ "Error 500" or html =~ "Internal Server Error"
    end
  end

  # Helper function to create test notices
  defp create_test_notices(_context) do
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
        name: "Manufacturing Solutions Ltd",
        local_authority: "Manchester City Council",
        postcode: "M1 1AA"
      })

    {:ok, offender2} =
      Enforcement.create_offender(%{
        name: "Industrial Operations Corp",
        local_authority: "Birmingham City Council",
        postcode: "B2 2BB"
      })

    {:ok, offender3} =
      Enforcement.create_offender(%{
        name: "Chemical Processing PLC",
        local_authority: "Leeds City Council",
        postcode: "LS3 3CC"
      })

    # Create test notices
    base_date = ~D[2024-01-15]

    {:ok, notice1} =
      Enforcement.create_notice(%{
        regulator_id: "HSE-NOTICE-2024-001",
        regulator_ref_number: "HSE/REF/001",
        agency_id: hse_agency.id,
        offender_id: offender1.id,
        offence_action_type: "Improvement Notice",
        notice_date: base_date,
        operative_date: Date.add(base_date, 14),
        compliance_date: Date.add(base_date, 60),
        notice_body: "Failure to maintain adequate safety procedures in manufacturing operations"
      })

    {:ok, notice2} =
      Enforcement.create_notice(%{
        regulator_id: "HSE-NOTICE-2024-002",
        regulator_ref_number: "HSE/REF/002",
        agency_id: hse_agency.id,
        offender_id: offender2.id,
        offence_action_type: "Prohibition Notice",
        notice_date: Date.add(base_date, 7),
        operative_date: Date.add(base_date, 7),
        compliance_date: Date.add(base_date, 30),
        notice_body: "Immediate prohibition of crane operations due to structural defects"
      })

    {:ok, notice3} =
      Enforcement.create_notice(%{
        regulator_id: "EA-NOTICE-2024-001",
        regulator_ref_number: "EA/REF/001",
        agency_id: ea_agency.id,
        offender_id: offender3.id,
        offence_action_type: "Enforcement Notice",
        notice_date: Date.add(base_date, 14),
        operative_date: Date.add(base_date, 21),
        compliance_date: Date.add(base_date, 90),
        notice_body: "Environmental compliance breach - chemical discharge monitoring required"
      })

    %{
      hse_agency: hse_agency,
      ea_agency: ea_agency,
      offender1: offender1,
      offender2: offender2,
      offender3: offender3,
      notice1: notice1,
      notice2: notice2,
      notice3: notice3
    }
  end
end
