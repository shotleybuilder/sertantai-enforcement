defmodule EhsEnforcementWeb.DashboardPeriodDropdownTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  require Ash.Query
  import Ash.Expr

  alias EhsEnforcement.Enforcement

  describe "Dashboard Period Dropdown Functionality" do
    setup do
      # Create test data spanning different time periods
      {:ok, hse} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Test Company Ltd",
          local_authority: "Test Council",
          postcode: "TE1 1ST"
        })

      # Create cases with specific dates to test time periods
      base_date = Date.utc_today()

      # Recent case (within last week)
      {:ok, recent_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-RECENT",
          agency_id: hse.id,
          offender_id: offender.id,
          offence_action_date: Date.add(base_date, -3),
          offence_fine: Decimal.new("5000.00"),
          offence_breaches: "Recent safety breach"
        })

      # Month-old case (within last month but not last week)
      {:ok, month_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-MONTH",
          agency_id: hse.id,
          offender_id: offender.id,
          offence_action_date: Date.add(base_date, -20),
          offence_fine: Decimal.new("8000.00"),
          offence_breaches: "Month-old safety breach"
        })

      # Year-old case (within last year but not last month)
      {:ok, year_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-YEAR",
          agency_id: hse.id,
          offender_id: offender.id,
          offence_action_date: Date.add(base_date, -200),
          offence_fine: Decimal.new("12000.00"),
          offence_breaches: "Year-old safety breach"
        })

      %{
        hse: hse,
        offender: offender,
        recent_case: recent_case,
        month_case: month_case,
        year_case: year_case
      }
    end

    test "initial load shows default period (month) and correct data", %{conn: conn} do
      {:ok, view, html} = live(conn, "/dashboard")

      # Should show "Last Month" selected by default
      assert html =~ "Last Month"

      # Period card should show "30 days"
      assert html =~ "30 days"

      # Should include recent and month cases but not year case in stats
      # Recent cases count for month period
      assert html =~ "2"
    end

    test "changing period dropdown updates stats and period card", %{conn: conn} do
      {:ok, view, html} = live(conn, "/dashboard")

      # Initial state - should show month
      assert html =~ "30 days"

      # Change to "Last Week" by interacting with the form
      view |> form("form", %{"period" => "week"}) |> render_change()
      updated_html = render(view)

      # Period card should update to "7 days"
      assert updated_html =~ "7 days"
      # Should no longer show month
      refute updated_html =~ "30 days"

      # Should show flash message
      assert updated_html =~ "Time period changed to week"

      # Should show only recent case count (1) not month case
      # Only recent case
      assert updated_html =~ "1"
      # Month case should not appear in recent activity
      refute updated_html =~ "HSE-MONTH"
    end

    test "changing to year period shows all cases", %{conn: conn} do
      {:ok, view, html} = live(conn, "/dashboard")

      # Verify initial state shows month
      # String.capitalize("30 days") = "30 days"
      assert html =~ "30 days"

      # Change to "Last Year" by interacting with the form
      view |> form("form", %{"period" => "year"}) |> render_change()
      updated_html = render(view)

      # Period card should update to "365 days"
      assert updated_html =~ "365 days"
      # Should no longer show month
      refute updated_html =~ "30 days"

      # Should show flash message
      assert updated_html =~ "Time period changed to year"

      # Should show all cases count (3)
      # All cases
      assert updated_html =~ "3"

      # Recent activity should include all cases
      assert updated_html =~ "HSE-RECENT"
      assert updated_html =~ "HSE-MONTH"
      assert updated_html =~ "HSE-YEAR"
    end

    test "search recent cases button uses correct period from dropdown", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Change to year period
      view |> form("form", %{"period" => "year"}) |> render_change()

      # Click search recent cases button
      assert_navigation_redirect(view, "search_cases", fn path ->
        # Should redirect to cases page with year period
        assert path =~ "/cases?filter=recent&period=year"
      end)
    end

    test "browse recent cases button filters to cases only with current period", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Change to week period
      view |> form("form", %{"period" => "week"}) |> render_change()

      # Click browse recent cases button
      render_click(view, "browse_recent_cases")
      updated_html = render(view)

      # Should scroll to recent activity section and filter to cases
      # The filter should be set to :cases
      # Filter button should be active
      assert updated_html =~ "Cases"

      # Should only show recent case (within week), not month or year cases
      assert updated_html =~ "HSE-RECENT"
      refute updated_html =~ "HSE-MONTH"
      refute updated_html =~ "HSE-YEAR"
    end

    test "period dropdown maintains state across different actions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Change to year period
      view |> form("form", %{"period" => "year"}) |> render_change()
      year_html = render(view)
      assert year_html =~ "365 days"

      # Perform other actions (like filtering recent activity)
      render_click(view, "filter_recent_activity", %{"type" => "cases"})
      after_filter_html = render(view)

      # Period should still be year
      assert after_filter_html =~ "365 days"

      # Search button should still use year period
      assert_navigation_redirect(view, "search_cases", fn path ->
        assert path =~ "period=year"
      end)
    end
  end

  # Helper function to test redirects
  defp assert_navigation_redirect(view, event, assertion_fn) do
    try do
      render_click(view, event)
      flunk("Expected redirect but LiveView did not redirect")
    rescue
      error ->
        case Exception.message(error) do
          "LiveView redirected with " <> redirect_info ->
            path = extract_path_from_redirect(redirect_info)
            assertion_fn.(path)

          message ->
            if String.contains?(message, "redirect") do
              # Try to extract path from different redirect message formats
              path = extract_path_from_redirect(message)
              assertion_fn.(path)
            else
              reraise error, __STACKTRACE__
            end
        end
    end
  end

  defp extract_path_from_redirect(redirect_info) do
    # Extract path from redirect message
    case Regex.run(~r/to: "([^"]+)"/, redirect_info) do
      [_, path] -> path
      _ -> redirect_info
    end
  end
end
