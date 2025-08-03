defmodule EhsEnforcementWeb.Admin.CaseLive.ScrapeProgressTest do
  @moduledoc """
  Tests for progress update functionality in the scraping admin interface.
  
  This test module specifically focuses on testing the real-time progress updates
  that should occur during scraping operations.
  """
  
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  require Ash.Query
  import Ash.Expr

  alias EhsEnforcement.Scraping.ScrapeCoordinator
  alias Phoenix.PubSub

  @pubsub_topic "case:scraped:updated"

  describe "Progress update functionality" do
    setup do
      # Create admin user
      admin_user = Ash.Seed.seed!(EhsEnforcement.Accounts.User, %{
        email: "progress-admin@test.com",
        name: "Progress Admin",
        github_login: "progressadmin",
        is_admin: true,
        admin_checked_at: DateTime.utc_now()
      })

      # Create test agency
      {:ok, hse_agency} = EhsEnforcement.Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true
      })

      %{admin_user: admin_user, agency: hse_agency}
    end

    test "progress section shows initial state correctly", %{conn: conn, admin_user: admin_user} do
      conn = conn 
      |> assign(:current_user, admin_user)
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, admin_user.id)
      {:ok, view, html} = live(conn, "/admin/cases/scrape")

      # Check initial progress state
      assert html =~ "Ready to scrape"
      assert html =~ "0%"
      assert html =~ "Pages Processed:"
      assert html =~ "Cases Found:"
      assert html =~ "Cases Created:"
    end

    test "progress updates when PubSub messages are received", %{conn: conn, admin_user: admin_user} do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Simulate starting scraping
      progress_data = %{
        session_id: "test123",
        current_page: 1,
        pages_processed: 0,
        cases_scraped: 0,
        cases_created: 0,
        cases_skipped: 0,
        status: :running
      }

      # Send PubSub message that should update progress
      send(view.pid, {:started, progress_data})

      # Allow LiveView to process the message
      :ok = GenServer.call(view.pid, :sync)

      html = render(view)
      
      # Check that progress updated
      assert html =~ "Scraping in progress" or html =~ "running"
      refute html =~ "Ready to scrape"
    end

    test "progress percentage calculation works correctly", %{conn: conn, admin_user: admin_user} do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Simulate page completion
      progress_data = %{
        session_id: "test123",
        current_page: 2,
        pages_processed: 2,
        cases_scraped: 10,
        cases_created: 8,
        cases_skipped: 2,
        status: :running
      }

      # Send page_completed message
      send(view.pid, {:page_completed, progress_data})
      
      # Allow LiveView to process the message
      :ok = GenServer.call(view.pid, :sync)

      html = render(view)
      
      # Progress should be greater than 0% but less than 100%
      progress_percentage = extract_progress_percentage(html)
      assert progress_percentage > 0
      assert progress_percentage < 100
      
      # Stats should be updated
      assert html =~ "2" # pages processed
      assert html =~ "8" # cases created
    end

    test "progress reaches 100% when scraping completes", %{conn: conn, admin_user: admin_user} do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Simulate completion
      completion_data = %{
        session_id: "test123",
        result: %{
          pages_processed: 5,
          cases_created: 25,
          cases_skipped: 3,
          errors: []
        },
        status: :completed
      }

      # Send completed message
      send(view.pid, {:completed, completion_data})
      
      # Allow LiveView to process the message
      :ok = GenServer.call(view.pid, :sync)

      html = render(view)
      
      # Progress should be 100%
      assert html =~ "100%"
      assert html =~ "Scraping completed" or html =~ "completed"
    end

    test "error states are handled correctly in progress updates", %{conn: conn, admin_user: admin_user} do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Simulate error
      error_data = %{
        session_id: "test123",
        page: 3,
        reason: "Network timeout"
      }

      # Send error message
      send(view.pid, {:error, error_data})
      
      # Allow LiveView to process the message
      :ok = GenServer.call(view.pid, :sync)

      html = render(view)
      
      # Error should be displayed
      assert html =~ "Network timeout" or html =~ "error" or html =~ "Error"
    end

    test "PubSub subscription is established on mount", %{conn: conn, admin_user: admin_user} do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Check that the view process is subscribed to progress updates
      subscribers = PubSub.subscribers(EhsEnforcement.PubSub, @pubsub_topic)
      assert view.pid in subscribers
    end

    test "real-time progress feature flag is respected", %{conn: conn, admin_user: admin_user} do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, html} = live(conn, "/admin/cases/scrape")

      # Check if real-time progress is enabled (this should match actual config)
      # The view should show progress section when enabled
      assert html =~ "Progress" or html =~ "progress"
    end

    @tag :integration
    test "progress updates work with actual scraping coordinator", %{conn: conn, admin_user: admin_user} do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # This test would require mocking the actual scraping process
      # For now, we verify the interface can handle the events properly
      
      # Simulate what ScrapeCoordinator would broadcast
      session_data = %{
        session_id: "real_test",
        current_page: 1,
        pages_processed: 0,
        cases_scraped: 0,
        cases_created: 0,
        cases_skipped: 0,
        status: :running,
        timestamp: DateTime.utc_now()
      }

      # Test the actual PubSub broadcast mechanism
      PubSub.broadcast(EhsEnforcement.PubSub, @pubsub_topic, {:started, session_data})
      
      # Allow time for message processing
      Process.sleep(50)
      
      # Check that the view received and processed the broadcast
      html = render(view)
      assert html =~ "running" or html =~ "Scraping in progress"
    end

    test "handles case update events from scraping", %{conn: conn, admin_user: admin_user, agency: agency} do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Create a test case first
      {:ok, test_case} = EhsEnforcement.Enforcement.create_case(%{
        agency_id: agency.id,
        offender_attrs: %{name: "Test Company Ltd"},
        regulator_id: "HSE_TEST_001",
        offence_result: "Under investigation"
      })

      # Simulate a case update event from scraping
      case_update_event = %Phoenix.Socket.Broadcast{
        topic: "case:scraped:updated",
        event: "update_from_scraping",
        payload: test_case
      }

      # Send the event to the LiveView
      send(view.pid, case_update_event)
      
      # Allow time for message processing
      Process.sleep(50)
      
      # The view should handle the update properly without crashing
      html = render(view)
      assert html =~ "Scraping" # Should still show scraping interface
    end
  end

  describe "Progress calculation edge cases" do
    setup do
      admin_user = Ash.Seed.seed!(EhsEnforcement.Accounts.User, %{
        email: "edge-admin@test.com",
        name: "Edge Case Admin",
        github_login: "edgeadmin",
        is_admin: true,
        admin_checked_at: DateTime.utc_now()
      })

      %{admin_user: admin_user}
    end

    test "handles division by zero in progress calculation", %{conn: conn, admin_user: admin_user} do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Send progress with zero values that could cause division by zero
      progress_data = %{
        session_id: "zero_test",
        current_page: nil,
        pages_processed: 0,
        cases_scraped: 0,
        cases_created: 0,
        cases_skipped: 0,
        status: :running
      }

      send(view.pid, {:page_started, progress_data})
      :ok = GenServer.call(view.pid, :sync)

      html = render(view)
      
      # Should not crash and should show reasonable progress
      progress_percentage = extract_progress_percentage(html)
      assert is_number(progress_percentage)
      assert progress_percentage >= 0
      assert progress_percentage <= 100
    end

    test "handles very large numbers in progress", %{conn: conn, admin_user: admin_user} do
      conn = conn |> assign(:current_user, admin_user)
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Send progress with large numbers
      progress_data = %{
        session_id: "large_test",
        current_page: 1000,
        pages_processed: 999,
        cases_scraped: 50000,
        cases_created: 49500,
        cases_skipped: 500,
        status: :running
      }

      send(view.pid, {:page_completed, progress_data})
      :ok = GenServer.call(view.pid, :sync)

      html = render(view)
      
      # Should handle large numbers gracefully
      assert html =~ "50000" or html =~ "50,000"
      assert html =~ "49500" or html =~ "49,500"
    end
  end

  # Helper function to extract progress percentage from HTML
  defp extract_progress_percentage(html) do
    case Regex.run(~r/(\d+)%/, html) do
      [_, percentage_str] -> String.to_integer(percentage_str)
      _ -> 0
    end
  end
end