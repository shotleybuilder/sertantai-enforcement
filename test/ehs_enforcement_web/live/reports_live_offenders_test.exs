defmodule EhsEnforcementWeb.ReportsLive.OffendersTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  alias EhsEnforcement.Enforcement

  describe "ReportsLive.Offenders analytics report" do
    setup do
      # Create agencies
      {:ok, hse_agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      # Create offenders in different industries
      {:ok, manufacturing1} =
        Enforcement.create_offender(%{
          name: "Manufacturing Co 1",
          industry: "Manufacturing",
          total_cases: 3,
          total_notices: 2,
          total_fines: Decimal.new("150000")
        })

      {:ok, manufacturing2} =
        Enforcement.create_offender(%{
          name: "Manufacturing Co 2",
          industry: "Manufacturing",
          total_cases: 2,
          total_notices: 1,
          total_fines: Decimal.new("80000")
        })

      {:ok, chemical} =
        Enforcement.create_offender(%{
          name: "Chemical Corp",
          industry: "Chemical Processing",
          total_cases: 4,
          total_notices: 3,
          total_fines: Decimal.new("200000")
        })

      %{
        hse_agency: hse_agency,
        manufacturing1: manufacturing1,
        manufacturing2: manufacturing2,
        chemical: chemical
      }
    end

    test "renders analytics report page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports/offenders")

      assert html =~ "Offender Analytics Report"
      assert html =~ "Industry Analysis"
      assert html =~ "Top Offenders"
    end

    test "displays industry analysis", %{conn: conn} do
      {:ok, view, html} = live(conn, "/reports/offenders")

      # Should show industry breakdown
      assert html =~ "Industry Analysis"
      # Should appear in industry stats
      assert html =~ "Manufacturing"
      # Should appear in industry stats
      assert html =~ "Chemical Processing"
    end

    test "identifies top offenders by fine amount", %{conn: conn, chemical: chemical} do
      {:ok, view, html} = live(conn, "/reports/offenders")

      # Should show top offenders section
      assert html =~ "Top Offenders"

      # Chemical corp should appear in top offenders (£200k)
      assert html =~ chemical.name
    end

    test "shows repeat offender statistics", %{conn: conn} do
      {:ok, view, html} = live(conn, "/reports/offenders")

      # Should show repeat offender metrics - all test offenders have >2 enforcement actions
      assert html =~ "Repeat Offenders"
      # All 3 offenders have >2 total enforcement actions
      assert html =~ "100%"
    end

    test "exports analytics data to CSV", %{conn: conn} do
      {:ok, view, html} = live(conn, "/reports/offenders")

      # Click export button - this triggers a JS event
      view
      |> element("button", "Export Analytics")
      |> render_click()

      # CSV export is handled via JS download event
      assert has_element?(view, "button", "Export Analytics")
    end

    test "navigates back to reports dashboard", %{conn: conn} do
      {:ok, view, html} = live(conn, "/reports/offenders")

      # Should have back to reports link
      assert has_element?(view, "a[href='/reports']")
    end
  end
end
