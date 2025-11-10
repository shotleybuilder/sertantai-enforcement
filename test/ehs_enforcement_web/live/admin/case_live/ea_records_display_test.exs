defmodule EhsEnforcementWeb.Admin.CaseLive.EaRecordsDisplayTest do
  @moduledoc """
  Test to ensure EA scraped cases display in Records table after completion.

  This test verifies that when EA scraping creates ProcessingLog records,
  they appear in the LiveView's case_processing_log and are displayed
  in the Records table below the progress component.

  The bug was that LiveView was subscribing to wrong PubSub topics:
  - Wrong: "ea_case_processing_log:created"
  - Correct: "processing_log:created"
  """

  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  alias EhsEnforcement.Scraping.ProcessingLog

  describe "EA Records Display" do
    setup %{conn: conn} do
      # Create admin user using OAuth2 pattern
      user_info = %{
        "email" => "records-test-admin@test.com",
        "name" => "Records Test Admin",
        "login" => "recordsadmin",
        "id" => 77777,
        "avatar_url" => "https://github.com/images/avatars/recordsadmin",
        "html_url" => "https://github.com/recordsadmin"
      }

      oauth_tokens = %{
        "access_token" => "test_records_token",
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

    test "EA processing logs appear in Records table via PubSub", %{conn: conn} do
      # Mount the scraping LiveView
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Verify initially empty
      assert has_element?(view, "h1", "Case Scraping")

      # Create an EA processing log (this should trigger PubSub notification)
      ea_log_params = %{
        session_id: "test-ea-session-123",
        agency: :ea,
        batch_or_page: 1,
        items_found: 3,
        items_created: 1,
        items_existing: 2,
        items_failed: 0,
        creation_errors: [],
        scraped_items: [
          %{
            regulator_id: "EA-TEST-001",
            offender_name: "Test Company Ltd",
            case_date: ~D[2024-01-15],
            fine_amount: Decimal.new("5000.00")
          },
          %{
            regulator_id: "EA-TEST-002",
            offender_name: "Another Corp",
            case_date: ~D[2024-01-20],
            fine_amount: Decimal.new("2500.00")
          }
        ]
      }

      # Create the processing log - this should publish to "processing_log:created"
      {:ok, _log} = Ash.create(ProcessingLog, ea_log_params)

      # Wait for PubSub message to be processed
      Process.sleep(100)

      # Verify the Records section now shows the processing log
      assert has_element?(view, "h2", "Live Processing Details")

      # Should show the EA batch information
      # EA shows "Batch" not "Page"
      assert has_element?(view, "span", "Batch 1")

      # Should show the case statistics
      # items_found
      assert has_element?(view, "span", "3")
      # items_created
      assert has_element?(view, "span", "1")
      # items_existing
      assert has_element?(view, "span", "2")

      # Should show the actual case details
      assert has_element?(view, "div", "EA-TEST-001")
      assert has_element?(view, "div", "Test Company Ltd")
      assert has_element?(view, "div", "EA-TEST-002")
      assert has_element?(view, "div", "Another Corp")
    end

    test "Records table distinguishes between HSE pages and EA batches", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/cases/scrape")

      # Create HSE processing log
      hse_log_params = %{
        session_id: "test-hse-session-456",
        agency: :hse,
        # This is a page number for HSE
        batch_or_page: 2,
        items_found: 5,
        items_created: 3,
        items_existing: 2,
        items_failed: 0,
        creation_errors: [],
        scraped_items: [
          %{
            regulator_id: "HSE-TEST-001",
            offender_name: "HSE Test Company",
            case_date: ~D[2024-02-01],
            fine_amount: Decimal.new("10000.00")
          }
        ]
      }

      {:ok, _hse_log} = Ash.create(ProcessingLog, hse_log_params)
      Process.sleep(50)

      # Create EA processing log
      ea_log_params = %{
        session_id: "test-ea-session-789",
        agency: :ea,
        # This is a batch number for EA
        batch_or_page: 1,
        items_found: 2,
        items_created: 0,
        items_existing: 2,
        items_failed: 0,
        creation_errors: [],
        scraped_items: [
          %{
            regulator_id: "EA-TEST-003",
            offender_name: "EA Test Corp",
            case_date: ~D[2024-02-05],
            fine_amount: Decimal.new("7500.00")
          }
        ]
      }

      {:ok, _ea_log} = Ash.create(ProcessingLog, ea_log_params)
      Process.sleep(100)

      # Should show both processing logs with correct labels
      # HSE shows "Page"
      assert has_element?(view, "span", "Page 2")
      # EA shows "Batch"
      assert has_element?(view, "span", "Batch 1")

      # Should show both sets of cases
      assert has_element?(view, "div", "HSE-TEST-001")
      assert has_element?(view, "div", "HSE Test Company")
      assert has_element?(view, "div", "EA-TEST-003")
      assert has_element?(view, "div", "EA Test Corp")
    end
  end
end
