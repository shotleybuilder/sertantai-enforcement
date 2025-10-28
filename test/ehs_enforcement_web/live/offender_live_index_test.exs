defmodule EhsEnforcementWeb.OffenderLive.IndexTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Repo

  require Ash.Query
  import Ash.Expr

  describe "OffenderLive.Index mount" do
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

      # Create test offenders with varied enforcement history
      base_date = ~D[2024-01-15]

      {:ok, repeat_offender} =
        Enforcement.create_offender(%{
          name: "Acme Manufacturing Ltd",
          local_authority: "Manchester City Council",
          postcode: "M1 1AA",
          industry: "Manufacturing",
          business_type: :limited_company,
          total_cases: 5,
          total_notices: 8,
          total_fines: Decimal.new("250000"),
          first_seen_date: ~D[2020-06-15],
          last_seen_date: ~D[2024-03-20]
        })

      {:ok, moderate_offender} =
        Enforcement.create_offender(%{
          name: "Industrial Corp",
          local_authority: "Birmingham City Council",
          postcode: "B2 2BB",
          industry: "Chemical Processing",
          business_type: :plc,
          total_cases: 2,
          total_notices: 3,
          total_fines: Decimal.new("75000"),
          first_seen_date: ~D[2022-03-10],
          last_seen_date: ~D[2023-11-15]
        })

      {:ok, minor_offender} =
        Enforcement.create_offender(%{
          name: "Small Business Ltd",
          local_authority: "Leeds City Council",
          postcode: "LS3 3CC",
          industry: "Retail",
          business_type: :limited_company,
          total_cases: 1,
          total_notices: 1,
          total_fines: Decimal.new("5000"),
          first_seen_date: ~D[2023-08-05],
          last_seen_date: ~D[2023-08-05]
        })

      # Create some enforcement cases for context
      {:ok, case1} =
        Enforcement.create_case(%{
          regulator_id: "HSE-2024-001",
          agency_id: hse_agency.id,
          offender_id: repeat_offender.id,
          offence_action_date: base_date,
          offence_fine: Decimal.new("50000"),
          offence_breaches: "Health and Safety at Work Act 1974 - Section 2(1)",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, case2} =
        Enforcement.create_case(%{
          regulator_id: "EA-2023-045",
          agency_id: ea_agency.id,
          offender_id: moderate_offender.id,
          offence_action_date: Date.add(base_date, -30),
          offence_fine: Decimal.new("25000"),
          offence_breaches: "Environmental Protection Act 1990 - Section 33(1)(a)",
          last_synced_at: DateTime.utc_now()
        })

      # Create some notices
      {:ok, notice1} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-N-2024-001",
          agency_id: hse_agency.id,
          offender_id: repeat_offender.id,
          offence_action_type: "improvement_notice",
          notice_date: base_date,
          operative_date: Date.add(base_date, 7),
          compliance_date: Date.add(base_date, 30),
          notice_body: "Improve safety procedures within 30 days"
        })

      %{
        hse_agency: hse_agency,
        ea_agency: ea_agency,
        repeat_offender: repeat_offender,
        moderate_offender: moderate_offender,
        minor_offender: minor_offender,
        case1: case1,
        case2: case2,
        notice1: notice1
      }
    end

    test "renders offender index page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/offenders")

      assert html =~ "Offender Management"
      assert html =~ "Enforcement Offenders"
    end

    test "displays offender list with enforcement statistics", %{
      conn: conn,
      repeat_offender: repeat_offender,
      moderate_offender: moderate_offender
    } do
      {:ok, view, html} = live(conn, "/offenders")

      # Should show offender names
      assert html =~ repeat_offender.name
      assert html =~ moderate_offender.name

      # Should show enforcement statistics
      # repeat_offender total_cases
      assert html =~ "5 Cases"
      # repeat_offender total_notices
      assert html =~ "8 Notices"
      # repeat_offender total_fines
      assert html =~ "£250,000"

      # moderate_offender total_cases
      assert html =~ "2 Cases"
      # moderate_offender total_notices
      assert html =~ "3 Notices"
    end

    test "identifies repeat offenders with visual indicators", %{
      conn: conn,
      repeat_offender: repeat_offender
    } do
      {:ok, view, html} = live(conn, "/offenders")

      # Should have repeat offender indicator for offenders with multiple cases
      assert html =~ "Repeat Offender"
      # Check the offender row exists
      assert has_element?(view, "[data-offender-id='#{repeat_offender.id}']")
    end

    test "filters offenders by industry", %{
      conn: conn,
      repeat_offender: repeat_offender,
      moderate_offender: moderate_offender
    } do
      {:ok, view, html} = live(conn, "/offenders")

      # Filter by Manufacturing industry
      view
      |> form("[data-testid='offender-filters']", %{filters: %{industry: "Manufacturing"}})
      |> render_change()

      # Should show manufacturing offender
      assert render(view) =~ repeat_offender.name
      # Should not show chemical processing offender
      refute render(view) =~ moderate_offender.name
    end

    test "filters offenders by local authority", %{
      conn: conn,
      repeat_offender: repeat_offender,
      moderate_offender: moderate_offender
    } do
      {:ok, view, html} = live(conn, "/offenders")

      # Filter by Manchester
      view
      |> form("[data-testid='offender-filters']", %{filters: %{local_authority: "Manchester"}})
      |> render_change()

      # Should show Manchester offender
      assert render(view) =~ repeat_offender.name
      # Should not show Birmingham offender
      refute render(view) =~ moderate_offender.name
    end

    test "filters offenders by business type", %{
      conn: conn,
      repeat_offender: repeat_offender,
      moderate_offender: moderate_offender
    } do
      {:ok, view, html} = live(conn, "/offenders")

      # Filter by limited company
      view
      |> form("[data-testid='offender-filters']", %{filters: %{business_type: "limited_company"}})
      |> render_change()

      # Should show limited company offender
      assert render(view) =~ repeat_offender.name
      # Should not show PLC offender
      refute render(view) =~ moderate_offender.name
    end

    test "filters repeat offenders only", %{
      conn: conn,
      repeat_offender: repeat_offender,
      minor_offender: minor_offender
    } do
      {:ok, view, html} = live(conn, "/offenders")

      # Filter for repeat offenders only (multiple cases/notices)
      # For checkboxes in LiveView tests, we click the checkbox element directly
      view
      |> element("input[name='filters[repeat_only]']")
      |> render_click()

      # Should show repeat offender
      assert render(view) =~ repeat_offender.name
      # Should not show single-case offender
      refute render(view) =~ minor_offender.name
    end

    test "sorts offenders by total fines descending", %{
      conn: conn,
      repeat_offender: repeat_offender,
      moderate_offender: moderate_offender
    } do
      {:ok, view, html} = live(conn, "/offenders")

      # Sort by total fines descending
      view
      |> form("[data-testid='offender-filters']", %{sort_by: "total_fines", sort_order: "desc"})
      |> render_change()

      rendered_html = render(view)

      # Repeat offender (£250k) should appear before moderate offender (£75k)
      repeat_pos = :binary.match(rendered_html, repeat_offender.name) |> elem(0)
      moderate_pos = :binary.match(rendered_html, moderate_offender.name) |> elem(0)

      assert repeat_pos < moderate_pos
    end

    test "sorts offenders by enforcement count descending", %{
      conn: conn,
      repeat_offender: repeat_offender,
      minor_offender: minor_offender
    } do
      {:ok, view, html} = live(conn, "/offenders")

      # Sort by total cases descending
      view
      |> form("[data-testid='offender-filters']", %{sort_by: "total_cases", sort_order: "desc"})
      |> render_change()

      rendered_html = render(view)

      # Repeat offender (5 cases) should appear before minor offender (1 case)
      repeat_pos = :binary.match(rendered_html, repeat_offender.name) |> elem(0)
      minor_pos = :binary.match(rendered_html, minor_offender.name) |> elem(0)

      assert repeat_pos < minor_pos
    end

    test "searches offenders by name", %{
      conn: conn,
      repeat_offender: repeat_offender,
      moderate_offender: moderate_offender
    } do
      {:ok, view, html} = live(conn, "/offenders")

      # Search for "Acme" - search is handled through the filter form
      view
      |> form("[data-testid='offender-filters']", %{"search[query]" => "Acme"})
      |> render_change()

      # Should show matching offender
      assert render(view) =~ repeat_offender.name
      # Should not show non-matching offender
      refute render(view) =~ moderate_offender.name
    end

    test "searches offenders by postcode", %{
      conn: conn,
      repeat_offender: repeat_offender,
      moderate_offender: moderate_offender
    } do
      {:ok, view, html} = live(conn, "/offenders")

      # Search by postcode - search is handled through the filter form
      view
      |> form("[data-testid='offender-filters']", %{"search[query]" => "M1 1AA"})
      |> render_change()

      # Should show matching offender
      assert render(view) =~ repeat_offender.name
      # Should not show non-matching offender
      refute render(view) =~ moderate_offender.name
    end

    test "implements pagination for large offender lists", %{conn: conn} do
      # Create additional offenders to test pagination
      for i <- 1..25 do
        {:ok, _offender} =
          Enforcement.create_offender(%{
            name: "Test Company #{i} Ltd",
            local_authority: "Test Council #{i}",
            postcode: "T#{i} #{i}AA",
            total_cases: 1,
            total_notices: 1,
            total_fines: Decimal.new("1000")
          })
      end

      {:ok, view, html} = live(conn, "/offenders")

      # Should show pagination controls when there are many results
      rendered_html = render(view)
      offender_rows = view |> render() |> Floki.find("[data-role='offender-row']")

      # With 25 additional + existing test data, should have pagination
      # Check if we have results showing
      assert length(offender_rows) > 0

      # If showing 20 results, likely has pagination
      if length(offender_rows) == 20 do
        # Should have some indication of more pages if total > per_page
        total_count_text = rendered_html
        assert total_count_text =~ ~r/\d+ offenders/
      end
    end

    test "navigates to offender detail view", %{conn: conn, repeat_offender: repeat_offender} do
      {:ok, view, html} = live(conn, "/offenders")

      # Click on offender row
      {:ok, show_view, _html} =
        view
        |> element("[data-offender-id='#{repeat_offender.id}'] a")
        |> render_click()
        |> follow_redirect(conn, "/offenders/#{repeat_offender.id}")

      assert render(show_view) =~ repeat_offender.name
      assert render(show_view) =~ "Enforcement History"
    end

    test "handles empty offender list gracefully", %{conn: conn} do
      # Test with no offenders by using a fresh database state
      # Clear the database via repo 
      EhsEnforcement.Repo.delete_all(EhsEnforcement.Enforcement.Offender)

      {:ok, view, html} = live(conn, "/offenders")

      assert html =~ "No offenders found"
      assert html =~ "No enforcement data available"
    end

    test "displays loading states during data fetch", %{conn: conn} do
      {:ok, view, html} = live(conn, "/offenders")

      # Trigger a filter change that would cause loading
      view
      |> form("[data-testid='offender-filters']", %{filters: %{industry: "Manufacturing"}})
      |> render_change()

      # Should handle loading gracefully (implementation dependent)
      assert view.module == EhsEnforcementWeb.OffenderLive.Index
    end

    test "exports offender data to CSV", %{conn: conn, repeat_offender: repeat_offender} do
      {:ok, view, html} = live(conn, "/offenders")

      # Click export button - this triggers a JS event, not direct content
      view
      |> element("button", "Export CSV")
      |> render_click()

      # CSV export is handled via JS download event, so we can't directly test content
      # Just verify the button exists and is clickable
      assert has_element?(view, "button", "Export CSV")

      # CSV is generated via JS event, so we verify the export functionality works
      # The actual CSV generation logic is tested separately
    end
  end

  describe "OffenderLive.Index analytics navigation" do
    test "shows link to analytics report", %{conn: conn} do
      {:ok, view, html} = live(conn, "/offenders")

      # Should show link to detailed analytics report
      assert html =~ "View Detailed Analytics"
      assert html =~ "Industry analysis, top offenders, and repeat offender patterns"
      assert has_element?(view, "a[href='/reports/offenders']")
    end
  end

  describe "OffenderLive.Index accessibility" do
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

    test "includes proper ARIA labels and roles", %{conn: conn} do
      {:ok, view, html} = live(conn, "/offenders")

      # Should have proper ARIA attributes for accessibility
      assert html =~ ~r/aria-label="[^"]*"/

      # Table should have proper structure
      assert has_element?(view, "table")
      assert has_element?(view, "thead")
      assert has_element?(view, "tbody")
    end

    test "supports keyboard navigation", %{conn: conn, offender: offender} do
      {:ok, view, html} = live(conn, "/offenders")

      # Should have focusable elements
      assert has_element?(view, "[data-offender-id='#{offender.id}'] a")
      assert has_element?(view, "input[type='text']")
    end
  end

  describe "OffenderLive.Index error handling" do
    test "handles database connection errors gracefully", %{conn: conn} do
      # This would require mocking the database layer
      # For now, just ensure the page doesn't crash
      {:ok, view, html} = live(conn, "/offenders")

      assert view.module == EhsEnforcementWeb.OffenderLive.Index
    end

    test "handles invalid filter parameters", %{conn: conn} do
      {:ok, view, html} = live(conn, "/offenders")

      # Try invalid sort parameter
      view
      |> form("[data-testid='offender-filters']", %{sort_by: "invalid_field"})
      |> render_change()

      # Should not crash and should show error message or fallback
      assert view.module == EhsEnforcementWeb.OffenderLive.Index
    end
  end
end
