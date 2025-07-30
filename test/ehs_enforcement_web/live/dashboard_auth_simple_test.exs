defmodule EhsEnforcementWeb.DashboardAuthSimpleTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  
  describe "DashboardLive authentication integration" do
    setup do
      # Create test agency for dashboard functionality
      {:ok, hse_agency} = EhsEnforcement.Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true
      })

      %{agency: hse_agency}
    end

    test "displays sign-in link when user is not authenticated", %{conn: conn} do
      {:ok, view, html} = live(conn, "/dashboard")

      # Should show sign-in link
      assert html =~ "Sign In"
      assert has_element?(view, "a[href='/auth/user/github']")
    end

    test "shows user information when authenticated as regular user", %{conn: conn} do
      # Create a mock user (without hitting the database)
      user = %{
        id: "test-user-id",
        email: "user@test.com",
        name: "Test User",
        github_login: "testuser",
        is_admin: false,
        admin_checked_at: DateTime.utc_now()
      }
      
      # Sign in the user by setting in connection assigns
      conn = conn |> assign(:current_user, user)
      
      {:ok, view, html} = live(conn, "/dashboard")

      # Should show user's name
      assert html =~ "Welcome, Test User"
      # Should show sign-out link
      assert html =~ "Sign Out"
      assert has_element?(view, "a[href='/sign-out']")
      # Should NOT show admin badge
      refute html =~ "ADMIN"
    end

    test "shows admin badge and admin actions when authenticated as admin user", %{conn: conn} do
      # Create a mock admin user
      admin_user = %{
        id: "admin-user-id",
        email: "admin@test.com",
        name: "Admin User",
        github_login: "adminuser",
        is_admin: true,
        admin_checked_at: DateTime.utc_now()
      }
      
      # Sign in the admin user
      conn = conn |> assign(:current_user, admin_user)
      
      {:ok, view, html} = live(conn, "/dashboard")

      # Should show user's name
      assert html =~ "Welcome, Admin User"
      # Should show admin badge
      assert html =~ "ADMIN"
      # Should show sign-out link
      assert has_element?(view, "a[href='/sign-out']")
      
      # Should show admin actions
      assert html =~ "[ADMIN] > Add New Case"
      assert html =~ "[ADMIN] > Add New Notice"
      
      # Admin buttons should have proper phx-click handlers
      assert has_element?(view, "button[phx-click='navigate_to_new_case']")
      assert has_element?(view, "button[phx-click='navigate_to_new_notice']")
    end

    test "regular users do not see admin actions", %{conn: conn} do
      # Test with regular user
      regular_user = %{
        id: "regular-user-id",
        email: "user@test.com",
        name: "Regular User",
        github_login: "regularuser",
        is_admin: false,
        admin_checked_at: DateTime.utc_now()
      }
      
      conn = conn |> assign(:current_user, regular_user)
      
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should NOT show admin actions for regular user
      refute html =~ "[ADMIN] > Add New Case"
      refute html =~ "[ADMIN] > Add New Notice"
      refute html =~ "ADMIN" # No admin badge
    end

    test "handles nil current_user gracefully", %{conn: conn} do
      # Explicitly set current_user to nil
      conn = conn |> assign(:current_user, nil)
      
      {:ok, _view, html} = live(conn, "/dashboard")

      # Should not crash and show sign-in option
      assert html =~ "Sign In"
      refute html =~ "Welcome,"
      refute html =~ "ADMIN"
      refute html =~ "[ADMIN]"
    end

    test "admin navigation buttons work correctly", %{conn: conn} do
      admin_user = %{
        id: "admin-user-id",
        email: "admin@test.com",
        name: "Admin User",
        github_login: "adminuser",
        is_admin: true,
        admin_checked_at: DateTime.utc_now()
      }
      
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/dashboard")

      # Test case navigation
      view |> element("button[phx-click='navigate_to_new_case']") |> render_click()
      assert_redirected(view, "/cases/new")

      # Restart view for next test
      {:ok, view, _html} = live(conn, "/dashboard")
      
      # Test notice navigation
      view |> element("button[phx-click='navigate_to_new_notice']") |> render_click()
      assert_redirected(view, "/notices/new")
    end
  end
end