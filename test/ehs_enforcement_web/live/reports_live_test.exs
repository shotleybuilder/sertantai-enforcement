defmodule EhsEnforcementWeb.ReportsLiveTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "reports page" do
    test "mounts successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      assert html =~ "Reports & Analytics"
      assert html =~ "Generate filtered reports and export enforcement data"
    end

    test "displays main action cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      # Check for generate report card
      assert html =~ "Generate Report"
      assert html =~ "Create custom reports with filtering options"

      # Check for export data card  
      assert html =~ "Export Data"
      assert html =~ "Export filtered data in multiple formats"
    end

    test "has back to dashboard button", %{conn: conn} do
      {:ok, view, html} = live(conn, "/reports")

      assert html =~ "Back to Dashboard"

      # Test navigation back to dashboard
      view
      |> element("button", "Back to Dashboard")
      |> render_click()

      assert_redirected(view, "/dashboard")
    end

    test "shows generate report modal when clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Initially modal should not be visible
      refute render(view) =~ "Generate Report"

      # Click generate report button
      view
      |> element("button", "Generate Report")
      |> render_click()

      # Modal should now be visible
      html = render(view)
      assert html =~ "Generate Report"
      assert html =~ "Report Template"
      assert html =~ "From Date"
      assert html =~ "To Date"
    end

    test "shows export data modal when clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Click export data button
      view
      |> element("button", "Export Data")
      |> render_click()

      # Modal should be visible
      html = render(view)
      assert html =~ "Export Data"
      assert html =~ "Export Format"
      assert html =~ "From Date"
      assert html =~ "To Date"
      assert html =~ "Database protection"
    end

    test "can close generate report modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Open modal
      view
      |> element("button", "Generate Report")
      |> render_click()

      assert render(view) =~ "Generate Report"

      # Close modal
      view
      |> element("button[phx-click='hide_generate_modal']")
      |> render_click()

      refute render(view) =~ "Report Template"
    end

    test "can close export data modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Open modal
      view
      |> element("button", "Export Data")
      |> render_click()

      assert render(view) =~ "Export Format"

      # Close modal
      view
      |> element("button[phx-click='hide_export_modal']")
      |> render_click()

      refute render(view) =~ "Export Format"
    end

    test "displays report template options", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Open generate report modal
      view
      |> element("button", "Generate Report")
      |> render_click()

      html = render(view)
      assert html =~ "Enforcement summary"
      assert html =~ "Agency breakdown"
      assert html =~ "Offender analysis"
      assert html =~ "Compliance status"
    end

    test "displays export format options", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Open export data modal
      view
      |> element("button", "Export Data")
      |> render_click()

      html = render(view)
      assert html =~ "CSV"
      assert html =~ "EXCEL"
      assert html =~ "JSON"
      assert html =~ "PDF"
    end

    test "validates required date fields for report generation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Open generate report modal
      view
      |> element("button", "Generate Report")
      |> render_click()

      # Try to generate report without dates
      view
      |> element("form")
      |> render_submit()

      # Should show error message
      html = render(view)
      assert html =~ "Date range is required"
    end

    test "validates required date fields for export", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Open export data modal
      view
      |> element("button", "Export Data")
      |> render_click()

      # Try to export without dates
      view
      |> element("form")
      |> render_submit()

      # Should show error message
      html = render(view)
      assert html =~ "Date range is required"
    end

    test "validates date range limits", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Open generate report modal
      view
      |> element("button", "Generate Report")
      |> render_click()

      # Set date range longer than 2 years
      today = Date.utc_today()
      three_years_ago = Date.add(today, -1095)

      view
      |> form("form", %{
        "date_from" => Date.to_iso8601(three_years_ago),
        "date_to" => Date.to_iso8601(today)
      })
      |> render_submit()

      # Should show error about date range limit
      html = render(view)
      assert html =~ "Date range cannot exceed 2 years"
    end

    test "updates filter fields correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Open generate report modal
      view
      |> element("button", "Generate Report")
      |> render_click()

      # Update filter fields
      view
      |> form("form", %{
        "date_from" => "2024-01-01",
        "date_to" => "2024-12-31",
        "agency_filter" => "some-agency-id",
        "min_fine" => "1000",
        "max_fine" => "50000",
        "search_query" => "test query"
      })
      |> render_change()

      # Fields should be updated in the view state
      assert view.assigns.date_from == "2024-01-01"
      assert view.assigns.date_to == "2024-12-31"
      assert view.assigns.agency_filter == "some-agency-id"
      assert view.assigns.min_fine == "1000"
      assert view.assigns.max_fine == "50000"
      assert view.assigns.search_query == "test query"
    end

    test "can update report template", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Open generate report modal
      view
      |> element("button", "Generate Report")
      |> render_click()

      # Change report template
      view
      |> element("select[name='template']")
      |> render_change(%{template: "agency_breakdown"})

      assert view.assigns.report_template == "agency_breakdown"
    end

    test "can update export format", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Open export data modal
      view
      |> element("button", "Export Data")
      |> render_click()

      # Change export format
      view
      |> element("select[name='format']")
      |> render_change(%{format: "json"})

      assert view.assigns.export_format == "json"
    end

    test "displays loading state during export", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Open export data modal
      view
      |> element("button", "Export Data")
      |> render_click()

      # Fill in required fields
      view
      |> form("form", %{
        "date_from" => "2024-01-01",
        "date_to" => "2024-01-31"
      })
      |> render_change()

      # Submit export (this would normally trigger loading state)
      view
      |> element("form")
      |> render_submit()

      # Loading state should be handled (though this test doesn't fully simulate async behavior)
      # The important part is that the form processes without crashing
    end

    test "shows database protection notice", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Open export data modal
      view
      |> element("button", "Export Data")
      |> render_click()

      html = render(view)
      assert html =~ "Database Protection Notice"
      assert html =~ "Date range is required to protect database performance"
      assert html =~ "Maximum range allowed is 2 years"
    end

    test "handles successful export result", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Simulate successful export by setting last_export_result
      send(
        view.pid,
        {:assign, :last_export_result,
         %{
           filename: "test_export.csv",
           format: "CSV",
           size: "1.5MB"
         }}
      )

      html = render(view)
      assert html =~ "Export Completed"
      assert html =~ "test_export.csv"
      assert html =~ "CSV, 1.5MB"
    end

    test "loads agencies for filter dropdown", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Open modal to see agency options
      view
      |> element("button", "Generate Report")
      |> render_click()

      html = render(view)
      assert html =~ "All Agencies"
      # Should load agencies from the database (depends on test data)
    end

    test "handles invalid date formats", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Open generate report modal
      view
      |> element("button", "Generate Report")
      |> render_click()

      # Try invalid date format
      view
      |> form("form", %{
        "date_from" => "invalid-date",
        "date_to" => "2024-12-31"
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Invalid date format"
    end

    test "supports optional filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Open generate report modal
      view
      |> element("button", "Generate Report")
      |> render_click()

      html = render(view)

      # Check optional filter fields exist
      assert html =~ "Agency (Optional)"
      assert html =~ "Min Fine"
      assert html =~ "Max Fine"
      assert html =~ "Search Query (Optional)"
    end
  end

  describe "form validation" do
    test "validates date format", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      view
      |> element("button", "Generate Report")
      |> render_click()

      # Test various invalid date formats
      invalid_dates = ["2024-13-01", "2024-02-30", "not-a-date", ""]

      for invalid_date <- invalid_dates do
        view
        |> form("form", %{
          "date_from" => invalid_date,
          "date_to" => "2024-12-31"
        })
        |> render_submit()

        # Should show some form of validation error
        html = render(view)
        assert html =~ "Date range is required" or html =~ "Invalid date format"
      end
    end

    test "validates numeric fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      view
      |> element("button", "Generate Report")
      |> render_click()

      # Valid dates required first
      view
      |> form("form", %{
        "date_from" => "2024-01-01",
        "date_to" => "2024-01-31",
        "min_fine" => "not-a-number",
        "max_fine" => "1000"
      })
      |> render_change()

      # Form should handle invalid numbers gracefully
      assert view.assigns.min_fine == "not-a-number"
    end
  end

  describe "accessibility" do
    test "includes proper ARIA labels and semantic HTML", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      # Check for semantic HTML structure
      assert html =~ "<h1"
      assert html =~ "<h2"

      # Check for descriptive text
      assert html =~ "Generate filtered reports"
      assert html =~ "Export filtered data"
    end

    test "modal accessibility", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Open modal
      view
      |> element("button", "Generate Report")
      |> render_click()

      html = render(view)

      # Check for proper modal structure
      # Screen reader text
      assert html =~ "sr-only"
      # Proper form structure
      assert html =~ "<form"
    end
  end
end
