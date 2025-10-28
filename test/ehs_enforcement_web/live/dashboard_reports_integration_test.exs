defmodule EhsEnforcementWeb.DashboardReportsIntegrationTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "dashboard reports integration" do
    test "dashboard displays reports action card", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Check for reports card presence
      assert html =~ "REPORTS & ANALYTICS"
      assert html =~ "📊"

      # Check for metrics
      assert html =~ "Saved Reports"
      assert html =~ "Last Export"
      assert html =~ "Data Available"

      # Check for action buttons
      assert html =~ "Generate"
      assert html =~ "Report"
      assert html =~ "Export"
      assert html =~ "Data"
    end

    test "reports card uses green theme", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should use green theme as specified
      assert html =~ "bg-green-"
      assert html =~ "text-green-"
    end

    test "reports card displays calculated metrics", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should display actual calculated values, not placeholders
      # Should have numeric values
      assert html =~ ~r/\d+/
      # Time format
      assert html =~ ~r/(days?|hours?|min|Never)/
      # Data size format
      assert html =~ ~r/\d+(\.\d+)?(KB|MB|GB)/
    end

    test "clicking generate report navigates to reports page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Click generate report button in the reports card
      view
      |> element("button[phx-click='generate_report']")
      |> render_click()

      # Should navigate to reports page
      assert_redirected(view, "/reports")
    end

    test "clicking export data navigates to reports page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Click export data button in the reports card
      view
      |> element("button[phx-click='export_data']")
      |> render_click()

      # Should navigate to reports page
      assert_redirected(view, "/reports")
    end

    test "reports card is positioned correctly in grid", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should be in the 4th position (after cases, notices, offenders)
      card_positions = Regex.scan(~r/action_card/, html)
      assert length(card_positions) >= 4

      # Check that reports card comes after the others
      assert html =~
               ~r/ENFORCEMENT CASES.*ENFORCEMENT NOTICES.*OFFENDER DATABASE.*REPORTS & ANALYTICS/s
    end

    test "reports card integrates with dashboard navigation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Navigate to reports and back
      view
      |> element("button[phx-click='generate_report']")
      |> render_click()

      assert_redirected(view, "/reports")

      # Navigate back to dashboard from reports
      {:ok, reports_view, _html} = live(conn, "/reports")

      reports_view
      |> element("button", "Back to Dashboard")
      |> render_click()

      assert_redirected(reports_view, "/dashboard")
    end

    test "reports card actions work without authentication", %{conn: conn} do
      # Reports are open access, should work without login
      {:ok, view, _html} = live(conn, "/dashboard")

      # Both actions should work
      view
      |> element("button[phx-click='generate_report']")
      |> render_click()

      assert_redirected(view, "/reports")
    end

    test "reports card displays alongside other cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # All four main action cards should be present
      assert html =~ "ENFORCEMENT CASES"
      assert html =~ "ENFORCEMENT NOTICES"
      assert html =~ "OFFENDER DATABASE"
      assert html =~ "REPORTS & ANALYTICS"

      # Each should have their respective icons
      # Cases
      assert html =~ "📁"
      # Notices
      assert html =~ "🔔"
      # Offenders
      assert html =~ "👥"
      # Reports
      assert html =~ "📊"
    end

    test "reports card maintains consistent styling with other cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should use consistent card styling patterns
      assert html =~ "dashboard_action_card"

      # Should have proper grid layout
      assert html =~ "dashboard_card_grid"
    end

    test "reports card handles loading states", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Simulate loading state (would normally be set by parent component)
      send(view.pid, {:assign, :reports_loading, true})

      html = render(view)
      # Loading state should be handled gracefully
      assert html =~ "REPORTS & ANALYTICS"
    end

    test "reports card error handling", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Even if there are errors calculating metrics, card should still render
      assert html =~ "REPORTS & ANALYTICS"

      # Should have some form of metrics display (even if defaults)
      assert html =~ "Saved Reports"
      assert html =~ "Last Export"
      assert html =~ "Data Available"
    end

    test "reports card accessibility in dashboard context", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Check for accessibility attributes in reports card context
      assert html =~ "aria-label"

      # Should have proper button semantics
      assert html =~ ~r/<button[^>]*phx-click="generate_report"/
      assert html =~ ~r/<button[^>]*phx-click="export_data"/
    end

    test "reports card responsive behavior", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should be part of responsive grid system
      assert html =~ "grid"
      assert html =~ "lg:"

      # Cards should work on mobile/tablet layouts
      assert html =~ "sm:"
    end

    test "reports card data consistency", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Metrics should be consistent with dashboard data
      # Reports card should calculate from same data sources as dashboard stats

      # Should not show impossible values
      # No negative counts
      refute html =~ "-1"
      refute html =~ "undefined"
      refute html =~ "null"
    end

    test "reports card performance", %{conn: conn} do
      # Test that reports card doesn't significantly slow down dashboard loading
      start_time = System.monotonic_time(:millisecond)

      {:ok, _view, _html} = live(conn, "/dashboard")

      end_time = System.monotonic_time(:millisecond)
      load_time = end_time - start_time

      # Dashboard should load reasonably quickly (adjust threshold as needed)
      # 5 seconds max
      assert load_time < 5000
    end

    test "reports card event handling", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Test that events are properly routed
      initial_path = assert_redirect(view, "/dashboard")

      # Click should trigger navigation
      view
      |> element("button[phx-click='generate_report']")
      |> render_click()

      # Should redirect to reports page
      assert_redirected(view, "/reports")
    end
  end

  describe "reports card metrics calculation" do
    test "calculates saved reports count", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should show a numeric value for saved reports
      assert html =~ ~r/Saved Reports.*\d+/s
    end

    test "calculates last export timestamp", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should show time-based display for last export
      assert html =~ ~r/Last Export.*(Never|\d+\s+(min|hours?|days?|weeks?)\s+ago)/s
    end

    test "calculates available data size", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should show data size with proper units
      assert html =~ ~r/Data Available.*\d+(\.\d+)?(KB|MB|GB)/s
    end

    test "handles metric calculation errors gracefully", %{conn: conn} do
      # Even if there are database or calculation errors, should show defaults
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should always show the card structure
      assert html =~ "REPORTS & ANALYTICS"
      assert html =~ "Saved Reports"
      assert html =~ "Last Export"
      assert html =~ "Data Available"
    end
  end
end
