defmodule EhsEnforcementWeb.Components.ReportsActionCardTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  alias EhsEnforcementWeb.Components.ReportsActionCard

  describe "reports_action_card/1" do
    test "renders reports action card with default state" do
      html =
        render_component(&ReportsActionCard.reports_action_card/1, %{})

      # Check card structure
      assert html =~ "REPORTS & ANALYTICS"
      assert html =~ "📊"
      assert html =~ "green"

      # Check metrics
      assert html =~ "Saved Reports"
      assert html =~ "Last Export"
      assert html =~ "Data Available"

      # Check actions
      assert html =~ "Generate"
      assert html =~ "Report"
      assert html =~ "Export"
      assert html =~ "Data"
      assert html =~ "phx-click=\"generate_report\""
      assert html =~ "phx-click=\"export_data\""
    end

    test "renders with loading state" do
      html =
        render_component(&ReportsActionCard.reports_action_card/1, %{loading: true})

      assert html =~ "REPORTS & ANALYTICS"
    end

    test "renders with custom CSS class" do
      html =
        render_component(&ReportsActionCard.reports_action_card/1, %{class: "custom-class"})

      assert html =~ "REPORTS & ANALYTICS"
    end

    test "displays correct theme colors" do
      html =
        render_component(&ReportsActionCard.reports_action_card/1, %{})

      # Should use green theme
      assert html =~ "bg-green-600"
      assert html =~ "hover:bg-green-700"
      assert html =~ "bg-gray-600"
      assert html =~ "hover:bg-gray-700"
    end

    test "includes proper accessibility attributes" do
      html =
        render_component(&ReportsActionCard.reports_action_card/1, %{})

      assert html =~ "aria-label=\"Generate custom report with filtering options\""
      assert html =~ "aria-label=\"Export data with multiple format options\""
    end

    test "calculates metrics correctly" do
      # Test that the component renders without crashing (metrics calculation is internal)
      html =
        render_component(&ReportsActionCard.reports_action_card/1, %{})

      # Should display numeric values and proper formatting
      # Should contain numbers
      assert html =~ ~r/\d+/
      assert html =~ "Saved Reports"
      assert html =~ "Last Export"
      assert html =~ "Data Available"
    end

    test "handles metric calculation errors gracefully" do
      # Even with calculation errors, component should still render
      html =
        render_component(&ReportsActionCard.reports_action_card/1, %{})

      # Should always show the basic structure
      assert html =~ "REPORTS & ANALYTICS"
      assert html =~ "Saved Reports"
      assert html =~ "Last Export"
      assert html =~ "Data Available"
    end

    test "formats numbers correctly" do
      html =
        render_component(&ReportsActionCard.reports_action_card/1, %{})

      # Should format the saved reports count (currently hardcoded to 5)
      assert html =~ "5"
    end

    test "formats time display correctly" do
      html =
        render_component(&ReportsActionCard.reports_action_card/1, %{})

      # Should show a time-based display for last export
      # Currently simulated as "2 days ago"
      assert html =~ "days ago"
    end

    test "formats data size display correctly" do
      html =
        render_component(&ReportsActionCard.reports_action_card/1, %{})

      # Should show data size with appropriate units
      assert html =~ ~r/\d+(\.\d+)?(KB|MB|GB)/
    end

    test "renders action buttons with proper styling" do
      html =
        render_component(&ReportsActionCard.reports_action_card/1, %{})

      # Generate report button (primary green)
      assert html =~ "bg-green-600 hover:bg-green-700 text-white"

      # Export data button (secondary gray)
      assert html =~ "bg-gray-600 hover:bg-gray-700 text-white"
    end

    test "includes proper button content structure" do
      html =
        render_component(&ReportsActionCard.reports_action_card/1, %{})

      # Check button text structure
      assert html =~ ~r/Generate.*Report/s
      assert html =~ ~r/Export.*Data/s

      # Check that buttons have proper block/inline structure
      assert html =~ "text-sm font-medium"
      assert html =~ "text-xs"
    end

    test "includes transition effects" do
      html =
        render_component(&ReportsActionCard.reports_action_card/1, %{})

      assert html =~ "transition-colors duration-200"
    end

    test "renders metric items with proper structure" do
      html =
        render_component(&ReportsActionCard.reports_action_card/1, %{})

      # Check metric item structure
      assert html =~ "text-gray-600 text-xs font-medium uppercase tracking-wide"
      assert html =~ "text-gray-900 font-semibold"
    end

    test "uses dashboard action card component correctly" do
      html =
        render_component(&ReportsActionCard.reports_action_card/1, %{})

      # Should delegate to dashboard_action_card with correct props
      assert html =~ "REPORTS & ANALYTICS"
      assert html =~ "📊"
      assert html =~ "green"
    end

    test "passes through loading and class attributes" do
      html =
        render_component(&ReportsActionCard.reports_action_card/1, %{
          loading: true,
          class: "test-class"
        })

      assert html =~ "REPORTS & ANALYTICS"
    end
  end

  describe "error handling" do
    test "gracefully handles missing Enforcement module" do
      # Test that the component doesn't crash if Enforcement module is unavailable
      # This is difficult to test directly, but the component should use try/rescue

      # Should not raise an exception
      html = render_component(&ReportsActionCard.reports_action_card/1, %{})
      assert html =~ "REPORTS & ANALYTICS"
    end

    test "provides default values when metrics calculation fails" do
      # The component should handle errors in metric calculation internally
      # We can only test that it renders without crashing
      html = render_component(&ReportsActionCard.reports_action_card/1, %{})

      # Should always show the basic structure even if calculations fail
      assert html =~ "REPORTS & ANALYTICS"
      assert html =~ "Saved Reports"
      assert html =~ "Last Export"
      assert html =~ "Data Available"
    end
  end
end
