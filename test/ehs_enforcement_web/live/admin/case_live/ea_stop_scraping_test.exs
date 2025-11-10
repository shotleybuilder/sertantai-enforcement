defmodule EhsEnforcementWeb.Admin.CaseLive.EaStopScrapingTest do
  @moduledoc """
  Test that EA scraping can actually be stopped by the Stop Scraping button.

  This test verifies that when EA scraping is running and user clicks "Stop Scraping",
  the background scraping task is actually terminated.
  """

  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  require Logger

  describe "EA Stop Scraping functionality" do
    setup %{conn: conn} do
      # Create admin user
      user_info = %{
        "email" => "ea-stop-test@example.com",
        "name" => "EA Stop Test Admin",
        "login" => "eastoptest",
        "id" => 555_555,
        "avatar_url" => "https://github.com/images/avatars/eastoptest",
        "html_url" => "https://github.com/eastoptest"
      }

      oauth_tokens = %{
        "access_token" => "test_ea_stop_token",
        "token_type" => "Bearer"
      }

      {:ok, user} =
        Ash.create(
          EhsEnforcement.Accounts.User,
          %{
            user_info: user_info,
            oauth_tokens: oauth_tokens
          },
          action: :register_with_github
        )

      {:ok, admin_user} =
        Ash.update(
          user,
          %{
            is_admin: true,
            admin_checked_at: DateTime.utc_now()
          },
          action: :update_admin_status,
          actor: user
        )

      authenticated_conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(admin_user)

      %{admin_user: admin_user, conn: authenticated_conn}
    end

    test "Stop Scraping button should actually stop EA scraping task", %{conn: conn} do
      # Visit the case scraping page
      {:ok, view, _html} = live(conn, "/admin/scrape")

      # Create EA agency in test database
      {:ok, _ea_agency} =
        Ash.create(EhsEnforcement.Enforcement.Agency, %{
          code: :ea,
          name: "Environment Agency",
          base_url: "https://environment.data.gov.uk",
          enabled: true
        })

      # Start EA scraping with minimal date range (will fail quickly but should start)
      ea_scrape_params = %{
        "scrape_request" => %{
          "agency" => "ea",
          "date_from" => "2025-08-14",
          "date_to" => "2025-08-14",
          "action_types" => ["court_case"],
          "start_page" => "1",
          "max_pages" => "1",
          "scrape_type" => "manual"
        }
      }

      # Start the scraping using the form submit event
      render_submit(view, "submit", ea_scrape_params)

      # Give it a moment to start the background task
      :timer.sleep(100)

      # Verify scraping is running by checking socket assigns
      scraping_task = :sys.get_state(view.pid).socket.assigns[:scraping_task]
      current_session = :sys.get_state(view.pid).socket.assigns[:current_session]

      # EA scraping should have task but no session (different architecture than HSE)
      assert scraping_task != nil, "EA scraping task should be started"

      assert current_session == nil,
             "EA scraping should not create a session (sessionless architecture)"

      # Verify the task is actually alive
      assert Process.alive?(scraping_task.pid), "Scraping task process should be alive"

      # Click the Stop Scraping button
      render_click(view, "stop_scraping")

      # Give it a moment to stop
      :timer.sleep(100)

      # Verify the task was actually stopped
      refute Process.alive?(scraping_task.pid),
             "Scraping task should be killed after stop_scraping"

      # Verify socket state is updated
      updated_task = :sys.get_state(view.pid).socket.assigns[:scraping_task]
      assert updated_task == nil, "Scraping task should be nil after stopping"
    end

    test "Stop Scraping handles case when no scraping is running", %{conn: conn} do
      # Visit the case scraping page
      {:ok, view, _html} = live(conn, "/admin/scrape")

      # Try to stop scraping when nothing is running (should not crash)
      result = render_click(view, "stop_scraping")

      # Should handle gracefully
      assert Process.alive?(view.pid), "LiveView should not crash"
      assert is_binary(result), "Should return HTML response"
    end
  end
end
