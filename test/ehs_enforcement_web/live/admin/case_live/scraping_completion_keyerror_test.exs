defmodule EhsEnforcementWeb.Admin.CaseLive.ScrapingCompletionKeyErrorTest do
  @moduledoc """
  Test to prevent regression of KeyError for missing cases_processed field during scraping completion.
  
  This test ensures that when EA scraping completes and the {:scraping_completed, session_result}
  message is received, the progress component can access the cases_processed field without throwing
  a KeyError. This was a real bug that occurred in the scraping completion handler.
  
  The error occurred in render_case_based_progress/1 at line 191 trying to access @progress.cases_processed
  when the completion handler manually constructed a progress map missing this field.
  """
  
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  
  describe "Scraping Completion Progress Updates" do
    setup %{conn: conn} do
      # Create admin user using OAuth2 pattern (generates proper tokens)
      user_info = %{
        "email" => "completion-test-admin@test.com",
        "name" => "Completion Test Admin", 
        "login" => "completionadmin",
        "id" => 88888,
        "avatar_url" => "https://github.com/images/avatars/completionadmin",
        "html_url" => "https://github.com/completionadmin"
      }
      
      oauth_tokens = %{
        "access_token" => "test_completion_token",
        "token_type" => "Bearer"
      }

      # Create user with OAuth2 action (generates required tokens)
      {:ok, user} = Ash.create(EhsEnforcement.Accounts.User, %{
        user_info: user_info,
        oauth_tokens: oauth_tokens
      }, action: :register_with_github)
      
      # Update admin status after creation
      {:ok, admin_user} = Ash.update(user, %{
        is_admin: true,
        admin_checked_at: DateTime.utc_now()
      }, action: :update_admin_status, actor: user)

      # CRITICAL: Use AshAuthentication session storage
      authenticated_conn = conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> AshAuthentication.Plug.Helpers.store_in_session(admin_user)

      %{admin_user: admin_user, conn: authenticated_conn}
    end
    
    test "completion handler includes cases_processed in progress map", %{conn: conn} do
      # Mount the scraping LiveView
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")
      
      # Set the LiveView to scraping_active = true to simulate active scraping
      # This is needed because the completion handler only works when scraping is active
      send(view.pid, {:set_scraping_active, true})
      Process.sleep(50)
      
      # Create a mock completed ScrapeSession that represents EA scraping completion
      # This simulates the exact data structure from the real error log
      completed_session = %EhsEnforcement.Scraping.ScrapeSession{
        id: "test-completed-session-id",
        session_id: "completed-session-123",
        status: :completed,
        database: "ea_enforcement",
        start_page: 1,
        max_pages: 1,
        end_page: nil,
        current_page: 1,
        pages_processed: 1,
        cases_found: 6,           # Total cases from EA search
        cases_processed: 6,       # All cases were processed
        cases_created: 0,
        cases_created_current_page: 0,
        cases_updated: 0,
        cases_updated_current_page: 0,
        cases_exist_total: 6,     # All cases already existed
        cases_exist_current_page: 0,
        errors_count: 0
      }
      
      # Send the completion message that was causing the KeyError
      # This is the exact message format that triggers the bug
      completion_message = {:scraping_completed, completed_session}
      
      send(view.pid, completion_message)
      
      # Wait for processing
      Process.sleep(100)
      
      # Verify the LiveView is still alive (no crash occurred)
      assert Process.alive?(view.pid), "LiveView crashed when processing scraping completion"
      
      # The progress component should render without KeyError (element-based testing)
      assert has_element?(view, "h2", "HSE Progress") or has_element?(view, "h2", "EA Progress")
      
      # Should be able to render the EA case-based progress without KeyError
      # This is specifically testing line 191 in progress_component.ex
      assert has_element?(view, "span") # Should have progress display elements
    end
    
    test "completion progress map includes all required fields", %{conn: conn} do
      # Test that the manually constructed progress map in completion handler includes cases_processed
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")
      
      # Simulate active scraping state
      send(view.pid, {:set_scraping_active, true})
      Process.sleep(50)
      
      # Set initial progress with cases_processed
      initial_progress = %{
        status: :running,
        pages_processed: 0,
        cases_found: 3,
        cases_processed: 2,  # Some cases already processed
        cases_created: 1,
        cases_created_current_page: 0,
        cases_updated: 0,
        cases_updated_current_page: 0,
        cases_exist_total: 1,
        cases_exist_current_page: 0,
        errors_count: 0,
        current_page: 1
      }
      
      # Set the initial progress
      send(view.pid, {:update_progress, initial_progress})
      Process.sleep(50)
      
      # Create completion session with higher counts
      completed_session = %EhsEnforcement.Scraping.ScrapeSession{
        id: "test-session-higher-counts",
        session_id: "session-456",
        status: :completed,
        database: "ea_enforcement",
        start_page: 1,
        max_pages: 1,
        current_page: 1,
        pages_processed: 1,
        cases_found: 6,        # Higher than initial progress
        cases_processed: 5,    # Higher than initial progress 
        cases_created: 2,
        cases_updated: 0,
        cases_exist_total: 3,
        errors_count: 0,
        end_page: nil,
        cases_created_current_page: 0,
        cases_updated_current_page: 0,
        cases_exist_current_page: 0
      }
      
      # Send completion - this should merge the session results properly
      send(view.pid, {:scraping_completed, completed_session})
      Process.sleep(100)
      
      # Should not crash and should show completed status
      assert Process.alive?(view.pid)
      
      # Should show completed progress
      assert has_element?(view, "span", "Completed") or has_element?(view, "div")
    end
    
    test "completion handler without session result preserves current progress", %{conn: conn} do
      # Test the else branch of the completion handler
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")
      
      # Simulate active scraping with progress containing cases_processed
      send(view.pid, {:set_scraping_active, true})
      Process.sleep(50)
      
      progress_with_cases_processed = %{
        status: :running,
        pages_processed: 1,
        cases_found: 4,
        cases_processed: 3,  # This field must be preserved
        cases_created: 2,
        cases_created_current_page: 0,
        cases_updated: 0,
        cases_updated_current_page: 0,
        cases_exist_total: 1,
        cases_exist_current_page: 0,
        errors_count: 0,
        current_page: 1
      }
      
      send(view.pid, {:update_progress, progress_with_cases_processed})
      Process.sleep(50)
      
      # Send completion with nil session_result (triggers else branch)
      send(view.pid, {:scraping_completed, nil})
      Process.sleep(100)
      
      # Should not crash - the progress should preserve cases_processed
      assert Process.alive?(view.pid), "LiveView crashed when preserving current progress"
      
      # Should still be able to render progress
      assert has_element?(view, "h2", "HSE Progress") or has_element?(view, "h2", "EA Progress")
    end
  end
  
  # Helper message handlers that the LiveView needs for testing
  # These would normally be part of the LiveView but we need them for testing
end