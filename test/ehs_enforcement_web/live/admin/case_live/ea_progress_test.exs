defmodule EhsEnforcementWeb.Admin.CaseLive.EaProgressTest do
  @moduledoc """
  Tests for EA-specific progress functionality in the scraping admin interface.

  This test module focuses on testing the EA Progress component that shows
  case-based progress (no pages) for Environment Agency scraping operations.
  """

  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  require Ash.Query
  import Ash.Expr

  describe "EA Progress Component" do
    setup %{conn: conn} do
      # Create admin user using OAuth2 pattern (generates proper tokens)
      user_info = %{
        "email" => "ea-progress-admin@test.com",
        "name" => "EA Progress Admin",
        "login" => "eaprogressadmin",
        "id" => 12345,
        "avatar_url" => "https://github.com/images/avatars/eaprogressadmin",
        "html_url" => "https://github.com/eaprogressadmin"
      }

      oauth_tokens = %{
        "access_token" => "test_access_token",
        "token_type" => "Bearer"
      }

      # Create user with OAuth2 action (generates required tokens)
      {:ok, user} =
        Ash.create(
          EhsEnforcement.Accounts.User,
          %{
            user_info: user_info,
            oauth_tokens: oauth_tokens
          },
          action: :register_with_github
        )

      # Update admin status after creation
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

      # CRITICAL: Use AshAuthentication session storage
      authenticated_conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(admin_user)

      %{admin_user: admin_user, conn: authenticated_conn}
    end

    test "shows EA progress component when EA agency is selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Change to EA agency
      view
      |> form("form", scrape_request: %{agency: "ea"})
      |> render_change()

      # Should show EA Progress header (not HSE Progress)
      assert has_element?(view, "h2", "EA Progress")
      refute has_element?(view, "h2", "HSE Progress")

      # Should NOT show page-based metrics (HSE specific)
      refute has_element?(view, "div", "Pages Processed:")
      refute has_element?(view, "div", "Currently processing page:")

      # Should show case-based metrics only (EA specific)
      assert has_element?(view, "div", "Cases Found:")
      assert has_element?(view, "div", "Cases Created:")

      # Cases Updated is conditional - only shown when > 0
      # Cases Already Exist is conditional - only shown when > 0
      # In initial state, these would be 0 so not displayed
    end

    test "shows HSE progress component when HSE agency is selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # HSE should be selected by default
      html = render(view)

      # Should show HSE Progress header (not EA Progress)
      assert html =~ "HSE Progress"
      refute html =~ "EA Progress"

      # Should show page-based metrics
      assert html =~ "Pages Processed:"
      assert html =~ "Cases Created (This Page):"
      assert html =~ "Cases Updated (This Page):"
      assert html =~ "Cases Exist (Current Page):"

      # Should also show case-based totals
      assert html =~ "Cases Found:"
      assert html =~ "Cases Created (Total):"
      assert html =~ "Cases Updated (Total):"
      assert html =~ "Cases Exist (Total):"
    end

    test "EA progress component switches back and forth correctly", %{
      conn: conn,
      admin_user: admin_user
    } do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Start with HSE (default)
      html = render(view)
      assert html =~ "HSE Progress"
      assert html =~ "Pages Processed:"

      # Switch to EA
      html =
        view
        |> form("#scrape-form", scrape_request: %{agency: "ea"})
        |> render_change()

      assert html =~ "EA Progress"
      assert html =~ "Cases Processed:"
      refute html =~ "Pages Processed:"

      # Switch back to HSE
      html =
        view
        |> form("#scrape-form", scrape_request: %{agency: "hse"})
        |> render_change()

      assert html =~ "HSE Progress"
      assert html =~ "Pages Processed:"
      refute html =~ "EA Progress"
    end

    test "EA progress component shows initial state correctly", %{
      conn: conn,
      admin_user: admin_user
    } do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Switch to EA
      html =
        view
        |> form("#scrape-form", scrape_request: %{agency: "ea"})
        |> render_change()

      # Check initial EA progress state
      assert html =~ "Ready to scrape"
      assert html =~ "0%"
      assert html =~ "Processing cases from EA enforcement data"

      # Check EA-specific metrics are present and zeroed
      assert html =~ "Cases Found:"
      assert html =~ "Cases Processed:"
      assert html =~ "Cases Created:"
      assert html =~ "Cases Updated:"
      assert html =~ "Cases Exist:"

      # Verify initial values are 0
      assert extract_metric_value(html, "Cases Found") == 0
      assert extract_metric_value(html, "Cases Processed") == 0
      assert extract_metric_value(html, "Cases Created") == 0
    end
  end

  describe "EA Progress Percentage Calculation" do
    setup do
      admin_user =
        Ash.Seed.seed!(EhsEnforcement.Accounts.User, %{
          email: "ea-calc-admin@test.com",
          name: "EA Calc Admin",
          github_login: "eacalcadmin",
          is_admin: true,
          admin_checked_at: DateTime.utc_now()
        })

      %{admin_user: admin_user}
    end

    test "EA progress percentage calculation with case-based metrics", %{
      conn: conn,
      admin_user: admin_user
    } do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Switch to EA
      view
      |> form("#scrape-form", scrape_request: %{agency: "ea"})
      |> render_change()

      # Simulate EA scraping progress
      ea_progress_data = %{
        session_id: "ea_test123",
        status: :running,
        cases_found: 50,
        cases_created: 20,
        cases_updated: 10,
        cases_exist_total: 15,
        # EA doesn't use pages
        pages_processed: nil,
        # EA doesn't use pages
        current_page: nil,
        errors_count: 0
      }

      # Send progress update
      send(view.pid, {:ea_progress_update, ea_progress_data})
      :ok = GenServer.call(view.pid, :sync)

      html = render(view)

      # EA progress should be calculated as: (20 + 10 + 15) / 50 = 45/50 = 90%
      progress_percentage = extract_progress_percentage(html)
      # Allow some tolerance for rounding
      assert progress_percentage > 85
      # Should cap at 95% for running status
      assert progress_percentage <= 95

      # Check that the EA metrics are displayed
      # cases found
      assert html =~ "50"
      # cases created
      assert html =~ "20"
      # cases updated
      assert html =~ "10"
      # cases exist
      assert html =~ "15"

      # Cases processed should be sum: 20 + 10 + 15 = 45
      assert html =~ "45"
    end

    test "EA progress reaches 100% when completed", %{conn: conn, admin_user: admin_user} do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Switch to EA
      view
      |> form("#scrape-form", scrape_request: %{agency: "ea"})
      |> render_change()

      # Simulate EA completion
      ea_completion_data = %{
        session_id: "ea_complete_test",
        status: :completed,
        cases_found: 30,
        cases_created: 25,
        cases_updated: 3,
        cases_exist_total: 2,
        errors_count: 0
      }

      # Send completion message
      send(view.pid, {:ea_completed, ea_completion_data})
      :ok = GenServer.call(view.pid, :sync)

      html = render(view)

      # Progress should be 100%
      assert html =~ "100%"
      assert html =~ "Scraping completed" or html =~ "completed"
    end

    test "EA progress handles edge cases correctly", %{conn: conn, admin_user: admin_user} do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Switch to EA
      view
      |> form("#scrape-form", scrape_request: %{agency: "ea"})
      |> render_change()

      # Test division by zero case
      ea_zero_data = %{
        session_id: "ea_zero_test",
        status: :running,
        # This could cause division by zero
        cases_found: 0,
        cases_created: 0,
        cases_updated: 0,
        cases_exist_total: 0,
        errors_count: 0
      }

      # Send zero data
      send(view.pid, {:ea_progress_update, ea_zero_data})
      :ok = GenServer.call(view.pid, :sync)

      html = render(view)

      # Should not crash and should show reasonable progress
      progress_percentage = extract_progress_percentage(html)
      assert is_number(progress_percentage)
      assert progress_percentage >= 0
      assert progress_percentage <= 100
    end
  end

  describe "EA Progress Status Messages" do
    setup do
      admin_user =
        Ash.Seed.seed!(EhsEnforcement.Accounts.User, %{
          email: "ea-status-admin@test.com",
          name: "EA Status Admin",
          github_login: "eastatusadmin",
          is_admin: true,
          admin_checked_at: DateTime.utc_now()
        })

      %{admin_user: admin_user}
    end

    test "EA progress shows appropriate status messages", %{conn: conn, admin_user: admin_user} do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Switch to EA
      view
      |> form("#scrape-form", scrape_request: %{agency: "ea"})
      |> render_change()

      html = render(view)

      # Should show EA-specific status message
      assert html =~ "Processing cases from EA enforcement data"

      # Should NOT show HSE-specific messages
      refute html =~ "Currently processing page:"
      refute html =~ "processing page"
    end
  end

  describe "EA Case Table Integration" do
    setup do
      admin_user =
        Ash.Seed.seed!(EhsEnforcement.Accounts.User, %{
          email: "ea-case-table-admin@test.com",
          name: "EA Case Table Admin",
          github_login: "eacasetableadmin",
          is_admin: true,
          admin_checked_at: DateTime.utc_now()
        })

      # Create EA agency
      {:ok, ea_agency} =
        EhsEnforcement.Enforcement.create_agency(%{
          code: :ea,
          name: "Environment Agency",
          enabled: true
        })

      %{admin_user: admin_user, ea_agency: ea_agency}
    end

    test "EA cases appear in scraped cases table during EA scraping", %{
      conn: conn,
      admin_user: admin_user,
      ea_agency: ea_agency
    } do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Switch to EA and simulate starting scraping session
      view
      |> form("#scrape-form", scrape_request: %{agency: "ea"})
      |> render_change()

      # Simulate setting scraping session start time (like EA scraping would do)
      send(
        view.pid,
        {:ea_scraping_started, %{session_id: "ea_test", timestamp: DateTime.utc_now()}}
      )

      :ok = GenServer.call(view.pid, :sync)

      # Create an EA case (simulating EA scraping creating a case)
      {:ok, ea_case} =
        EhsEnforcement.Enforcement.create_case(%{
          agency_id: ea_agency.id,
          offender_attrs: %{name: "EA Test Company Ltd"},
          regulator_id: "EA_TEST_001",
          offence_result: "Enforcement Notice Served",
          offence_action_date: Date.utc_today(),
          offence_fine: Decimal.new("5000.00")
        })

      # Simulate the case:created PubSub event that would be triggered by EA scraping
      case_created_event = %Phoenix.Socket.Broadcast{
        topic: "case:created",
        event: "create",
        payload: %Ash.Notifier.Notification{
          resource: EhsEnforcement.Enforcement.Case,
          action: %{name: :create},
          data: ea_case
        }
      }

      # Send the event to the LiveView
      send(view.pid, case_created_event)
      :ok = GenServer.call(view.pid, :sync)

      html = render(view)

      # Should show the scraped cases table
      assert html =~ "Scraped Cases"

      # Should show the EA case details
      # regulator_id
      assert html =~ "EA_TEST_001"
      # offender name
      assert html =~ "EA Test Company Ltd"
      # fine amount
      assert html =~ "£5,000.00"
      # status badge
      assert html =~ "Created"
    end

    test "EA cases are deduplicated in scraped cases table by regulator_id", %{
      conn: conn,
      admin_user: admin_user,
      ea_agency: ea_agency
    } do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Switch to EA and simulate starting scraping session
      view
      |> form("#scrape-form", scrape_request: %{agency: "ea"})
      |> render_change()

      # Simulate setting scraping session start time
      send(
        view.pid,
        {:ea_scraping_started, %{session_id: "ea_dedup_test", timestamp: DateTime.utc_now()}}
      )

      :ok = GenServer.call(view.pid, :sync)

      # Create an EA case
      {:ok, ea_case} =
        EhsEnforcement.Enforcement.create_case(%{
          agency_id: ea_agency.id,
          offender_attrs: %{name: "EA Dedup Test Ltd"},
          regulator_id: "EA_DEDUP_001",
          offence_result: "Investigation"
        })

      # Send case created event
      case_created_event = %Phoenix.Socket.Broadcast{
        topic: "case:created",
        event: "create",
        payload: %Ash.Notifier.Notification{
          resource: EhsEnforcement.Enforcement.Case,
          action: %{name: :create},
          data: ea_case
        }
      }

      send(view.pid, case_created_event)
      :ok = GenServer.call(view.pid, :sync)

      # Update the same case (simulating EA scraping updating an existing case)
      {:ok, updated_ea_case} =
        EhsEnforcement.Enforcement.update_case(ea_case, %{
          offence_result: "Enforcement Notice Served"
        })

      # Send case updated event for the same regulator_id
      case_updated_event = %Phoenix.Socket.Broadcast{
        topic: "case:updated",
        event: "update",
        payload: %Ash.Notifier.Notification{
          resource: EhsEnforcement.Enforcement.Case,
          action: %{name: :update},
          data: updated_ea_case
        }
      }

      send(view.pid, case_updated_event)
      :ok = GenServer.call(view.pid, :sync)

      html = render(view)

      # Should only show ONE entry for EA_DEDUP_001 (deduplicated)
      regulator_id_count =
        html
        |> String.split("EA_DEDUP_001")
        |> length()
        # Subtract 1 because split adds empty string at start
        |> Kernel.-(1)

      assert regulator_id_count == 1,
             "EA case should be deduplicated - expected 1 occurrence of EA_DEDUP_001, got #{regulator_id_count}"

      # Should show the updated case data
      assert html =~ "Enforcement Notice Served"
      # status badge for updated case
      assert html =~ "Updated"
    end

    test "EA cases only appear in table during active EA scraping session", %{
      conn: conn,
      admin_user: admin_user,
      ea_agency: ea_agency
    } do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Switch to EA but DON'T start scraping session
      view
      |> form("#scrape-form", scrape_request: %{agency: "ea"})
      |> render_change()

      # Create an EA case without an active scraping session
      {:ok, ea_case} =
        EhsEnforcement.Enforcement.create_case(%{
          agency_id: ea_agency.id,
          offender_attrs: %{name: "EA No Session Test Ltd"},
          regulator_id: "EA_NO_SESSION_001",
          offence_result: "Investigation"
        })

      # Send case created event
      case_created_event = %Phoenix.Socket.Broadcast{
        topic: "case:created",
        event: "create",
        payload: %Ash.Notifier.Notification{
          resource: EhsEnforcement.Enforcement.Case,
          action: %{name: :create},
          data: ea_case
        }
      }

      send(view.pid, case_created_event)
      :ok = GenServer.call(view.pid, :sync)

      html = render(view)

      # Should NOT show the scraped cases table (no active session)
      refute html =~ "Scraped Cases"
      refute html =~ "EA_NO_SESSION_001"
    end

    test "mixed HSE and EA cases can appear in same scraping session", %{
      conn: conn,
      admin_user: admin_user,
      ea_agency: ea_agency
    } do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Create HSE agency
      {:ok, hse_agency} =
        EhsEnforcement.Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      # Start a scraping session (could be either HSE or EA - table is agency-agnostic)
      send(
        view.pid,
        {:scraping_started, %{session_id: "mixed_test", timestamp: DateTime.utc_now()}}
      )

      :ok = GenServer.call(view.pid, :sync)

      # Create both HSE and EA cases
      {:ok, hse_case} =
        EhsEnforcement.Enforcement.create_case(%{
          agency_id: hse_agency.id,
          offender_attrs: %{name: "HSE Mixed Test Ltd"},
          regulator_id: "HSE_MIXED_001",
          offence_result: "Prosecution"
        })

      {:ok, ea_case} =
        EhsEnforcement.Enforcement.create_case(%{
          agency_id: ea_agency.id,
          offender_attrs: %{name: "EA Mixed Test Ltd"},
          regulator_id: "EA_MIXED_001",
          offence_result: "Enforcement Notice"
        })

      # Send events for both cases
      for case <- [hse_case, ea_case] do
        event = %Phoenix.Socket.Broadcast{
          topic: "case:created",
          event: "create",
          payload: %Ash.Notifier.Notification{
            resource: EhsEnforcement.Enforcement.Case,
            action: %{name: :create},
            data: case
          }
        }

        send(view.pid, event)
      end

      :ok = GenServer.call(view.pid, :sync)

      html = render(view)

      # Should show both HSE and EA cases in the same table
      assert html =~ "HSE_MIXED_001"
      assert html =~ "HSE Mixed Test Ltd"
      assert html =~ "EA_MIXED_001"
      assert html =~ "EA Mixed Test Ltd"
      assert html =~ "Scraped Cases"
    end
  end

  # Helper functions
  defp extract_progress_percentage(html) do
    case Regex.run(~r/(\d+)%/, html) do
      [_, percentage_str] -> String.to_integer(percentage_str)
      _ -> 0
    end
  end

  defp extract_metric_value(html, metric_name) do
    # Look for pattern like "Cases Found:</span> <span>123</span>"
    pattern = ~r/#{Regex.escape(metric_name)}:.*?(\d+)/s

    case Regex.run(pattern, html) do
      [_, value_str] -> String.to_integer(value_str)
      _ -> 0
    end
  end
end
