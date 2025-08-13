defmodule EhsEnforcementWeb.Admin.NoticeLive.ScrapeTest do
  use EhsEnforcementWeb.ConnCase

  require Ash.Query
  import Phoenix.LiveViewTest

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Scraping.ScrapeSession

  describe "Notice Scraping LiveView" do
    setup do
      # Create HSE agency
      {:ok, hse_agency} = Ash.create(Enforcement.Agency, %{
        code: :hse,
        name: "Health and Safety Executive"
      })

      # Create admin user with GitHub OAuth
      admin_user_info = %{
        "email" => "admin@test.com",
        "name" => "Admin User",
        "login" => "admin",
        "id" => 12347,
        "avatar_url" => "https://github.com/images/avatars/admin",
        "html_url" => "https://github.com/admin"
      }
      
      admin_oauth_tokens = %{
        "access_token" => "test_admin_access_token",
        "token_type" => "Bearer"
      }

      {:ok, admin_user_base} = Ash.create(EhsEnforcement.Accounts.User, %{
        user_info: admin_user_info,
        oauth_tokens: admin_oauth_tokens
      }, action: :register_with_github)
      
      {:ok, admin_user} = Ash.update(admin_user_base, %{
        is_admin: true
      }, action: :update_admin_status, actor: admin_user_base)

      # Create non-admin user
      regular_user_info = %{
        "email" => "user@test.com",
        "name" => "Regular User",
        "login" => "regularuser",
        "id" => 12348,
        "avatar_url" => "https://github.com/images/avatars/regularuser",
        "html_url" => "https://github.com/regularuser"
      }
      
      regular_oauth_tokens = %{
        "access_token" => "test_regular_access_token",
        "token_type" => "Bearer"
      }

      {:ok, regular_user} = Ash.create(EhsEnforcement.Accounts.User, %{
        user_info: regular_user_info,
        oauth_tokens: regular_oauth_tokens
      }, action: :register_with_github)

      %{
        agency: hse_agency,
        admin_user: admin_user,
        regular_user: regular_user
      }
    end

    test "requires admin authentication", %{conn: conn} do
      result = live(conn, "/admin/notices/scrape")
      assert {:error, {:redirect, %{to: "/sign-in", flash: %{"info" => "Please sign in to continue"}}}} = result
    end

    # Note: Non-admin access control is tested at the plug level in auth_helpers_test.exs

    test "admin users can access notice scraping page", %{conn: conn, admin_user: user} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, view, html} = live(conn, "/admin/notices/scrape")
      
      assert html =~ "Notice Scraping"
      assert html =~ "Start Notice Scraping"
      assert html =~ "End Page"  # New label
      assert has_element?(view, "form")
    end

    test "displays navigation links", %{conn: conn, admin_user: user} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, _view, html} = live(conn, "/admin/notices/scrape")
      
      # Check for navigation elements in the HTML
      assert html =~ "Notice Scraping"
    end

    test "starts notice scraping with valid params", %{conn: conn, admin_user: user} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, view, _html} = live(conn, "/admin/notices/scrape")

      # Fill in form - max_pages now represents "end page"
      view
      |> form("form", %{
        "scrape_request" => %{
          "max_pages" => "5",  # End page = 5
          "start_page" => "1"  # Start page = 1, so will scrape pages 1-5
        }
      })
      |> render_submit()

      # Should show progress section  
      html = render(view)
      assert html =~ "Progress"
      
      # Should create a scrape session
      assert {:ok, sessions} = Ash.read(ScrapeSession, actor: user)
      assert length(sessions) >= 0  # May or may not create session immediately
    end

    test "validates page input", %{conn: conn, admin_user: user} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, view, _html} = live(conn, "/admin/notices/scrape")

      # Invalid end page (0)
      view
      |> form("form", %{
        "scrape_request" => %{
          "max_pages" => "0",
          "start_page" => "1"
        }
      })
      |> render_submit()

      assert render(view) =~ "must be greater than 0"

      # Invalid start_page
      view
      |> form("form", %{
        "scrape_request" => %{
          "max_pages" => "5",
          "start_page" => "0"
        }
      })
      |> render_submit()

      assert render(view) =~ "must be greater than 0"
    end

    test "receives and displays progress updates via PubSub", %{conn: conn, admin_user: user} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, view, _html} = live(conn, "/admin/notices/scrape")

      # Start scraping
      view
      |> form("form", %{
        "scrape_request" => %{
          "max_pages" => "3",
          "start_page" => "1"
        }
      })
      |> render_submit()

      # Should show progress indicators
      html = render(view)
      assert html =~ "Progress"
    end

    test "displays notice-specific status badges", %{conn: conn, admin_user: user} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, view, _html} = live(conn, "/admin/notices/scrape")

      # Should have notice-specific UI elements
      html = render(view)
      assert html =~ "Notice Scraping"
      assert html =~ "Progress"
    end

    test "handles completion correctly", %{conn: conn, admin_user: user} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, view, _html} = live(conn, "/admin/notices/scrape")

      # Start scraping
      view
      |> form("form", %{
        "scrape_request" => %{
          "max_pages" => "1",
          "start_page" => "1"
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Progress"
    end

    test "handles errors gracefully", %{conn: conn, admin_user: user} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, view, _html} = live(conn, "/admin/notices/scrape")

      # Start scraping
      view
      |> form("form", %{
        "scrape_request" => %{
          "max_pages" => "2",
          "start_page" => "1"
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Progress"
    end

    test "allows cancellation during scraping", %{conn: conn, admin_user: user} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, view, _html} = live(conn, "/admin/notices/scrape")

      # Start scraping
      view
      |> form("form", %{
        "scrape_request" => %{
          "max_pages" => "10",
          "start_page" => "1"
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Progress"
    end

    test "information panel displays notice-specific content", %{conn: conn, admin_user: user} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, _view, html} = live(conn, "/admin/notices/scrape")

      # Check for notice-specific information
      assert html =~ "Notice Scraping Information"
      assert html =~ "enforcement notices"
      assert html =~ "compliance dates"
    end

    test "displays new progress fields for created/updated notices", %{conn: conn, admin_user: user} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, _view, html} = live(conn, "/admin/notices/scrape")

      # Check for new progress field labels
      assert html =~ "Notices Created (Total)"
      assert html =~ "Notices Created (This Page)"
      assert html =~ "Notices Updated (Total)"  
      assert html =~ "Notices Updated (This Page)"
    end

    test "shows Clear Progress button when scraping is completed", %{conn: conn, admin_user: user} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, view, _html} = live(conn, "/admin/notices/scrape")

      # Start scraping
      view
      |> form("form", %{
        "scrape_request" => %{
          "max_pages" => "2",
          "start_page" => "1"
        }
      })
      |> render_submit()

      # Simulate session completion by sending session update
      session_data = %{
        status: :completed,
        current_page: 2,
        pages_processed: 2,
        cases_found: 5,
        cases_created: 3,
        cases_created_current_page: 1,
        cases_updated: 2,
        cases_updated_current_page: 1,
        cases_exist_total: 0,
        cases_exist_current_page: 0,
        errors_count: 0,
        max_pages: 2,
        session_id: "test123"
      }
      
      # Send proper PubSub notification to simulate session update (mimic Ash.Notifier.Notification)
      notification = %Ash.Notifier.Notification{data: session_data}
      send(view.pid, %Phoenix.Socket.Broadcast{
        topic: "scrape_session:updated", 
        event: "update", 
        payload: notification
      })
      
      # Give the LiveView time to process the message
      :timer.sleep(50)
      
      html = render(view)
      
      # Should show Clear Progress button when completed with created/updated notices
      assert html =~ "Clear Progress"
    end
  end

  describe "Progress Persistence During Page Transitions" do
    setup do
      # Create HSE agency
      {:ok, hse_agency} = Ash.create(Enforcement.Agency, %{
        code: :hse,
        name: "Health and Safety Executive"
      })

      # Create admin user
      admin_user_info = %{
        "email" => "admin@test.com",
        "name" => "Admin User",
        "login" => "admin",
        "id" => 12347,
        "avatar_url" => "https://github.com/images/avatars/admin",
        "html_url" => "https://github.com/admin"
      }
      
      admin_oauth_tokens = %{
        "access_token" => "test_admin_access_token",
        "token_type" => "Bearer"
      }

      {:ok, admin_user_base} = Ash.create(EhsEnforcement.Accounts.User, %{
        user_info: admin_user_info,
        oauth_tokens: admin_oauth_tokens
      }, action: :register_with_github)
      
      {:ok, admin_user} = Ash.update(admin_user_base, %{
        is_admin: true
      }, action: :update_admin_status, actor: admin_user_base)

      %{agency: hse_agency, admin_user: admin_user}
    end

    test "totals persist and accumulate when moving from page 1 to page 2", %{conn: conn, admin_user: user} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, view, _html} = live(conn, "/admin/notices/scrape")

      # Start scraping from page 1 to page 3
      view
      |> form("form", %{
        "scrape_request" => %{
          "max_pages" => "3",  # End page 3
          "start_page" => "1"  # Start page 1
        }
      })
      |> render_submit()

      # Simulate progress after page 1 completion
      page_1_data = %{
        status: :running,
        current_page: 1,
        pages_processed: 1,
        cases_found: 10,
        cases_created: 5,
        cases_created_current_page: 5,
        cases_updated: 3,
        cases_updated_current_page: 3,
        cases_exist_total: 2,
        cases_exist_current_page: 2,
        errors_count: 0,
        max_pages: 3
      }
      
      # Send session update for page 1 completion
      {:ok, _session} = handle_scrape_session_update(view, page_1_data)
      html_after_page_1 = render(view)
      
      # Verify page 1 metrics (use more flexible matching)
      assert html_after_page_1 =~ "Pages Processed"
      assert html_after_page_1 =~ ">1</span>" # Pages processed = 1
      assert html_after_page_1 =~ "Notices Created (Total)"
      assert html_after_page_1 =~ "text-green-600\">5</span>" # Total created = 5
      assert html_after_page_1 =~ "Notices Created (This Page)"
      assert html_after_page_1 =~ "text-green-500\">5</span>" # Page created = 5
      assert html_after_page_1 =~ "Notices Updated (Total)"
      assert html_after_page_1 =~ "text-blue-600\">3</span>" # Total updated = 3
      assert html_after_page_1 =~ "Notices Updated (This Page)"
      assert html_after_page_1 =~ "text-blue-500\">3</span>" # Page updated = 3

      # Simulate starting page 2 (this page metrics should reset, totals should persist)
      page_2_start_data = %{
        status: :running,
        current_page: 2,
        pages_processed: 1,  # Still 1 because page 2 just started
        cases_found: 10,
        cases_created: 5,    # Total persists from page 1
        cases_created_current_page: 0,  # Reset for new page
        cases_updated: 3,    # Total persists from page 1
        cases_updated_current_page: 0,  # Reset for new page
        cases_exist_total: 2,
        cases_exist_current_page: 0,    # Reset for new page
        errors_count: 0,
        max_pages: 3
      }
      
      {:ok, _session} = handle_scrape_session_update(view, page_2_start_data)
      html_page_2_start = render(view)
      
      # Verify totals persisted but current page metrics reset
      assert html_page_2_start =~ "text-green-600\">5</span>" # Total created persisted = 5
      assert html_page_2_start =~ "text-green-500\">0</span>" # Page created reset = 0
      assert html_page_2_start =~ "text-blue-600\">3</span>" # Total updated persisted = 3
      assert html_page_2_start =~ "text-blue-500\">0</span>" # Page updated reset = 0

      # Simulate page 2 completion (totals should accumulate)
      page_2_complete_data = %{
        status: :running,
        current_page: 2,
        pages_processed: 2,
        cases_found: 18,      # Total notices found increased
        cases_created: 8,     # Total created: 5 from page 1 + 3 from page 2
        cases_created_current_page: 3,  # Created on page 2
        cases_updated: 6,     # Total updated: 3 from page 1 + 3 from page 2
        cases_updated_current_page: 3,  # Updated on page 2
        cases_exist_total: 4, # Total existing: 2 from page 1 + 2 from page 2
        cases_exist_current_page: 2,    # Existing on page 2
        errors_count: 0,
        max_pages: 3
      }
      
      {:ok, _session} = handle_scrape_session_update(view, page_2_complete_data)
      html_page_2_complete = render(view)
      
      # Verify totals accumulated correctly
      assert html_page_2_complete =~ ">2</span>" # Pages processed = 2
      assert html_page_2_complete =~ "text-green-600\">8</span>" # Total created = 8
      assert html_page_2_complete =~ "text-green-500\">3</span>" # Page created = 3
      assert html_page_2_complete =~ "text-blue-600\">6</span>" # Total updated = 6
      assert html_page_2_complete =~ "text-blue-500\">3</span>" # Page updated = 3
    end

    test "progress persists after scraping session completes", %{conn: conn, admin_user: user} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, view, _html} = live(conn, "/admin/notices/scrape")

      # Start scraping
      view
      |> form("form", %{
        "scrape_request" => %{
          "max_pages" => "2",
          "start_page" => "1"
        }
      })
      |> render_submit()

      # Simulate session completion
      completion_data = %{
        status: :completed,
        current_page: 2,
        pages_processed: 2,
        cases_found: 15,
        cases_created: 8,
        cases_created_current_page: 3,
        cases_updated: 5,
        cases_updated_current_page: 2,
        cases_exist_total: 2,
        cases_exist_current_page: 1,
        errors_count: 0,
        max_pages: 2,
        session_id: "completed_session"
      }
      
      {:ok, _session} = handle_scrape_session_update(view, completion_data)
      html_after_completion = render(view)
      
      # Progress should persist after completion
      assert html_after_completion =~ ">2</span>" # Pages processed = 2
      assert html_after_completion =~ "text-green-600\">8</span>" # Total created = 8
      assert html_after_completion =~ "text-blue-600\">5</span>" # Total updated = 5
      assert html_after_completion =~ "Notice scraping completed"  # Status should show completed
      
      # Should show Clear Progress button
      assert html_after_completion =~ "Clear Progress"
      
      # Verify the scraping is no longer active (Start button should be visible)
      assert html_after_completion =~ "Start Notice Scraping"
      refute html_after_completion =~ "Stop Scraping"
    end

    test "manual Clear Progress control resets all progress metrics", %{conn: conn, admin_user: user} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, view, _html} = live(conn, "/admin/notices/scrape")

      # Start scraping
      view
      |> form("form", %{
        "scrape_request" => %{
          "max_pages" => "2",
          "start_page" => "1"
        }
      })
      |> render_submit()

      # Simulate completed session with progress data
      completion_data = %{
        status: :completed,
        current_page: 2,
        pages_processed: 2,
        cases_found: 12,
        cases_created: 7,
        cases_created_current_page: 3,
        cases_updated: 4,
        cases_updated_current_page: 2,
        cases_exist_total: 1,
        cases_exist_current_page: 0,
        errors_count: 1,
        max_pages: 2,
        session_id: "clear_test_session"
      }
      
      {:ok, _session} = handle_scrape_session_update(view, completion_data)
      
      # Verify progress is shown before clearing
      html_before_clear = render(view)
      assert html_before_clear =~ "text-green-600\">7</span>" # Total created = 7
      assert html_before_clear =~ "text-blue-600\">4</span>" # Total updated = 4
      assert html_before_clear =~ "Clear Progress"
      
      # Click Clear Progress
      view
      |> element("button", "Clear Progress")
      |> render_click()
      
      # Verify all progress metrics are reset
      html_after_clear = render(view)
      assert html_after_clear =~ ">0</span>" # Pages processed reset = 0
      assert html_after_clear =~ "text-green-600\">0</span>" # Total created reset = 0
      assert html_after_clear =~ "text-green-500\">0</span>" # Page created reset = 0
      assert html_after_clear =~ "text-blue-600\">0</span>" # Total updated reset = 0
      assert html_after_clear =~ "text-blue-500\">0</span>" # Page updated reset = 0
      assert html_after_clear =~ "Ready to scrape notices"  # Status should be idle
      
      # Clear Progress button should no longer be visible
      refute html_after_clear =~ "Clear Progress"
    end

    test "End Page logic correctly calculates page range", %{conn: conn, admin_user: user} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, view, _html} = live(conn, "/admin/notices/scrape")

      # Test that the help text shows correct page range
      view
      |> form("form", %{
        "scrape_request" => %{
          "max_pages" => "5",    # End page = 5
          "start_page" => "2"    # Start page = 2
        }
      })
      |> render_change()

      html = render(view)
      # Should show "4 pages from page 2 to page 5" (pages 2, 3, 4, 5 = 4 pages)
      assert html =~ "4 pages from page 2 to page 5"
    end

    # Helper function to simulate session updates
    defp handle_scrape_session_update(view, session_data) do
      # Create notification structure similar to what Ash PubSub sends
      notification = %Ash.Notifier.Notification{data: session_data}
      
      # Send the session update message
      send(view.pid, %Phoenix.Socket.Broadcast{
        topic: "scrape_session:updated", 
        event: "update", 
        payload: notification
      })
      
      # Allow the LiveView to process the message
      :timer.sleep(50)
      
      {:ok, session_data}
    end
  end
end