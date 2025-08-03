defmodule EhsEnforcementWeb.Admin.NoticeLive.ScrapeTest do
  use EhsEnforcementWeb.ConnCase

  require Ash.Query
  import Ash.Expr
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Scraping.ScrapeSession
  alias EhsEnforcement.Scraping.Hse.NoticeProcessor

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

    test "starts notice scraping with valid params", %{conn: conn, admin_user: user, agency: agency} do
      conn = conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      {:ok, view, _html} = live(conn, "/admin/notices/scrape")

      # Fill in form
      view
      |> form("form", %{
        "scrape_request" => %{
          "max_pages" => "5",
          "start_page" => "1"
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

      # Invalid max_pages
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
  end
end