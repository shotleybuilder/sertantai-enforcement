defmodule EhsEnforcementWeb.Admin.ScrapeSessionsLiveTest do
  use EhsEnforcementWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "ScrapeSessionsLive (admin route)" do
    setup :register_and_log_in_admin

    test "mounts successfully with authenticated admin user", %{conn: conn} do
      # This test reproduces the production bug:
      # KeyError: key :current_user not found in socket.assigns

      {:ok, _view, html} = live(conn, "/admin/scrape-sessions")

      # Should render without KeyError
      assert html =~ "Scraping Sessions"
    end

    test "has current_user in socket assigns", %{conn: conn, user: user} do
      # Verify that the LiveView mount hook properly sets current_user
      {:ok, view, _html} = live(conn, "/admin/scrape-sessions")

      # The socket should have current_user assigned
      assert view.pid
      # We can't directly access socket.assigns from the test, but if mount
      # succeeds without KeyError, it means current_user is available
    end

    test "loads scrape sessions for authenticated admin", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/scrape-sessions")

      # Should show the sessions table/list
      assert html =~ "Status"
      assert html =~ "Database"
    end

    test "handles filter changes without KeyError", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/scrape-sessions")

      # Change filter - this calls load_sessions with socket.assigns.current_user
      html = render_change(view, "filter_status", %{"status" => "running"})

      # Should not raise KeyError on current_user access
      assert html =~ "Scraping Sessions"
    end
  end

  describe "ScrapeSessionsDesignLive (admin route)" do
    setup :register_and_log_in_admin

    test "mounts successfully with authenticated admin user", %{conn: conn} do
      # This is the other route that fails in production
      {:ok, _view, html} = live(conn, "/admin/scrape-sessions-design")

      # Should render without KeyError
      assert html =~ "Session Design Parameters"
    end

    test "has current_user in socket assigns", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/scrape-sessions-design")

      # Should mount successfully (proves current_user is available)
      assert view.pid
    end
  end

  describe "Other admin routes (working correctly)" do
    setup :register_and_log_in_admin

    test "admin dashboard mounts successfully", %{conn: conn} do
      # This route works - serves as a control test
      {:ok, _view, html} = live(conn, "/admin")

      assert html =~ "Admin Dashboard"
    end

    test "scrape route mounts successfully", %{conn: conn} do
      # This route works - serves as a control test
      {:ok, _view, html} = live(conn, "/admin/scrape")

      assert html =~ "EHS Enforcement"
    end

    test "agencies index mounts successfully", %{conn: conn} do
      # This route works - serves as a control test
      {:ok, _view, html} = live(conn, "/admin/agencies")

      assert html =~ "Agencies"
    end
  end
end
