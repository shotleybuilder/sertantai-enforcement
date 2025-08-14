defmodule EhsEnforcement.Scraping.Workflows.NoticeScrapingIntegrationTest do
  use EhsEnforcement.DataCase

  require Ash.Query
  import Ash.Expr
  import ExUnit.CaptureLog

  alias EhsEnforcement.Scraping.{ScrapeSession, ScrapeCoordinator}
  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Services.Hse.ClientNotices

  @moduletag :integration

  describe "Full Notice Scraping Workflow" do
    setup do
      # Create HSE agency
      {:ok, hse_agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true
      })

      # Create admin user for actor context
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
        is_admin: true,
        admin_checked_at: DateTime.utc_now()
      }, action: :update_admin_status, actor: admin_user_base)

      # Subscribe to PubSub for testing
      :ok = Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "scraping:global")

      %{agency: hse_agency, actor: admin_user}
    end

    test "complete notice scraping workflow from start to finish", %{agency: agency, actor: actor} do
      # Mock HSE API responses
      mock_notices_page_1 = [
        %{
          "href" => "/notices/2024/12/in-001",
          "noticeNumber" => "IN/2024/001",
          "title" => "Company A - Improvement Notice",
          "noticeType" => "Improvement",
          "dateOfIssue" => "2024-12-01",
          "complianceDate" => "2025-01-15"
        },
        %{
          "href" => "/notices/2024/12/pn-001",
          "noticeNumber" => "PN/2024/001",
          "title" => "Company B - Prohibition Notice",
          "noticeType" => "Prohibition",
          "dateOfIssue" => "2024-12-02"
        }
      ]

      mock_notices_page_2 = [
        %{
          "href" => "/notices/2024/12/cn-001",
          "noticeNumber" => "CN/2024/001",
          "title" => "Crown Body - Crown Improvement Notice",
          "noticeType" => "Crown Improvement",
          "dateOfIssue" => "2024-12-03",
          "complianceDate" => "2025-02-01"
        }
      ]

      # Mock notice details for each notice
      mock_notice_details = %{
        "/notices/2024/12/in-001" => %{
          "noticeNumber" => "IN/2024/001",
          "recipientName" => "Company A Ltd",
          "recipientAddress" => "123 Business Park, London",
          "noticeType" => "Improvement",
          "dateOfIssue" => "2024-12-01",
          "complianceDate" => "2025-01-15",
          "breaches" => [
            %{
              "legislation" => "Health and Safety at Work etc. Act 1974",
              "section" => "Section 2(1)",
              "description" => "Failed to ensure employee safety"
            }
          ],
          "inspectorName" => "Inspector A",
          "localAuthority" => nil
        },
        "/notices/2024/12/pn-001" => %{
          "noticeNumber" => "PN/2024/001",
          "recipientName" => "Company B Construction",
          "recipientAddress" => "456 Builder Street, Manchester",
          "noticeType" => "Prohibition",
          "dateOfIssue" => "2024-12-02",
          "prohibitionDetails" => "Stop all work at height immediately",
          "breaches" => [
            %{
              "legislation" => "Work at Height Regulations 2005",
              "section" => "Regulation 4",
              "description" => "Inadequate fall protection"
            }
          ],
          "inspectorName" => "Inspector B",
          "localAuthority" => nil
        },
        "/notices/2024/12/cn-001" => %{
          "noticeNumber" => "CN/2024/001",
          "recipientName" => "NHS Trust",
          "recipientAddress" => "Hospital Road, Birmingham",
          "noticeType" => "Crown Improvement",
          "dateOfIssue" => "2024-12-03",
          "complianceDate" => "2025-02-01",
          "breaches" => [
            %{
              "legislation" => "Control of Substances Hazardous to Health Regulations 2002",
              "section" => "Regulation 6",
              "description" => "Inadequate control measures"
            }
          ],
          "inspectorName" => "Inspector C",
          "localAuthority" => nil
        }
      }

      # Set up mocks
      setup_notice_list_mocks([{1, mock_notices_page_1}, {2, mock_notices_page_2}])
      setup_notice_details_mocks(mock_notice_details)

      # Create scrape session
      {:ok, session} = Ash.create(ScrapeSession, %{
        agency_id: agency.id,
        data_type: :notice,
        status: :pending,
        config: %{
          pages_to_scrape: 2,
          starting_page: 1
        }
      }, actor: actor)

      # Start the scraping coordinator
      {:ok, coordinator_pid} = ScrapeCoordinator.start_session(session, actor: actor)

      # Monitor the coordinator
      ref = Process.monitor(coordinator_pid)

      # Wait for completion or timeout
      receive do
        {:DOWN, ^ref, :process, ^coordinator_pid, :normal} ->
          # Coordinator finished normally
          :ok
        {:DOWN, ^ref, :process, ^coordinator_pid, reason} ->
          flunk("Coordinator crashed: #{inspect(reason)}")
      after
        10_000 ->
          flunk("Scraping timed out after 10 seconds")
      end

      # Verify session was completed
      {:ok, updated_session} = Ash.get(ScrapeSession, session.id, actor: actor)
      assert updated_session.status == :completed
      assert updated_session.pages_scraped == 2
      assert updated_session.total_found == 3
      assert updated_session.total_created == 3
      assert updated_session.total_errors == 0

      # Verify notices were created
      {:ok, notices} = Enforcement.list_notices(actor: actor)
      assert length(notices) == 3

      # Verify notice types
      notice_types = Enum.map(notices, & &1.notice_type) |> Enum.sort()
      assert notice_types == [:crown_improvement, :improvement, :prohibition]

      # Verify offenders were created
      {:ok, offenders} = Enforcement.list_offenders(actor: actor)
      assert length(offenders) == 3

      # Verify offender types
      offender_names = Enum.map(offenders, & &1.name) |> Enum.sort()
      assert offender_names == ["Company A Ltd", "Company B Construction", "NHS Trust"]

      # Verify company types
      company_types = Enum.map(offenders, & &1.company_type) |> Enum.sort()
      assert company_types == [:construction, :crown_body, :limited_company]

      # Verify compliance dates
      compliance_dates = 
        notices
        |> Enum.filter(& &1.compliance_date)
        |> Enum.map(& &1.compliance_date)
        |> Enum.sort()
      
      assert compliance_dates == [~D[2025-01-15], ~D[2025-02-01]]

      # Verify PubSub events were sent
      session_id = session.id
      assert_received {:scraping_started, %{session_id: ^session_id}}
      assert_received {:scraping_page_completed, %{session_id: ^session_id, page: 1, found: 2, created: 2}}
      assert_received {:scraping_page_completed, %{session_id: ^session_id, page: 2, found: 1, created: 1}}
      assert_received {:scraping_completed, %{session_id: ^session_id, total_found: 3, total_created: 3}}
    end

    test "handles partial failures gracefully", %{agency: agency, actor: actor} do
      # Mock first page success, second page failure
      mock_notices_page_1 = [
        %{
          "href" => "/notices/2024/12/test-001",
          "noticeNumber" => "IN/2024/TEST001",
          "title" => "Test Company - Improvement Notice",
          "noticeType" => "Improvement",
          "dateOfIssue" => "2024-12-01",
          "complianceDate" => "2025-01-15"
        }
      ]

      mock_notice_details = %{
        "/notices/2024/12/test-001" => %{
          "noticeNumber" => "IN/2024/TEST001",
          "recipientName" => "Test Company Ltd",
          "recipientAddress" => "Test Address",
          "noticeType" => "Improvement",
          "dateOfIssue" => "2024-12-01",
          "complianceDate" => "2025-01-15",
          "breaches" => [],
          "inspectorName" => "Test Inspector",
          "localAuthority" => nil
        }
      }

      # Set up mocks - page 2 will fail
      setup_notice_list_mocks([{1, mock_notices_page_1}])
      setup_notice_list_error(2)
      setup_notice_details_mocks(mock_notice_details)

      # Create scrape session
      {:ok, session} = Ash.create(ScrapeSession, %{
        agency_id: agency.id,
        data_type: :notice,
        status: :pending,
        config: %{
          pages_to_scrape: 2,
          starting_page: 1
        }
      }, actor: actor)

      # Start scraping
      {:ok, coordinator_pid} = ScrapeCoordinator.start_session(session, actor: actor)
      ref = Process.monitor(coordinator_pid)

      # Wait for completion
      receive do
        {:DOWN, ^ref, :process, ^coordinator_pid, _} -> :ok
      after
        10_000 -> flunk("Timeout")
      end

      # Verify partial success
      {:ok, updated_session} = Ash.get(ScrapeSession, session.id, actor: actor)
      assert updated_session.status == :failed
      assert updated_session.pages_scraped == 1
      assert updated_session.total_found == 1
      assert updated_session.total_created == 1
      assert updated_session.total_errors > 0

      # Verify the successful notice was still created
      {:ok, notices} = Enforcement.list_notices(actor: actor)
      assert length(notices) == 1
      assert hd(notices).notice_number == "IN/2024/TEST001"
    end

    test "handles duplicate notices across pages", %{agency: agency, actor: actor} do
      # Same notice appears on multiple pages
      duplicate_notice = %{
        "href" => "/notices/2024/12/dup-001",
        "noticeNumber" => "IN/2024/DUP001",
        "title" => "Duplicate Co - Improvement Notice",
        "noticeType" => "Improvement",
        "dateOfIssue" => "2024-12-01",
        "complianceDate" => "2025-01-15"
      }

      mock_notices_page_1 = [duplicate_notice]
      mock_notices_page_2 = [
        duplicate_notice,  # Duplicate
        %{
          "href" => "/notices/2024/12/new-001",
          "noticeNumber" => "IN/2024/NEW001",
          "title" => "New Co - Improvement Notice",
          "noticeType" => "Improvement",
          "dateOfIssue" => "2024-12-02",
          "complianceDate" => "2025-01-20"
        }
      ]

      mock_notice_details = %{
        "/notices/2024/12/dup-001" => %{
          "noticeNumber" => "IN/2024/DUP001",
          "recipientName" => "Duplicate Co Ltd",
          "recipientAddress" => "Dup Address",
          "noticeType" => "Improvement",
          "dateOfIssue" => "2024-12-01",
          "complianceDate" => "2025-01-15",
          "breaches" => [],
          "inspectorName" => "Inspector D",
          "localAuthority" => nil
        },
        "/notices/2024/12/new-001" => %{
          "noticeNumber" => "IN/2024/NEW001",
          "recipientName" => "New Co Ltd",
          "recipientAddress" => "New Address",
          "noticeType" => "Improvement",
          "dateOfIssue" => "2024-12-02",
          "complianceDate" => "2025-01-20",
          "breaches" => [],
          "inspectorName" => "Inspector N",
          "localAuthority" => nil
        }
      }

      setup_notice_list_mocks([{1, mock_notices_page_1}, {2, mock_notices_page_2}])
      setup_notice_details_mocks(mock_notice_details)

      # Create and run session
      {:ok, session} = Ash.create(ScrapeSession, %{
        agency_id: agency.id,
        data_type: :notice,
        status: :pending,
        config: %{
          pages_to_scrape: 2,
          starting_page: 1
        }
      }, actor: actor)

      {:ok, coordinator_pid} = ScrapeCoordinator.start_session(session, actor: actor)
      ref = Process.monitor(coordinator_pid)

      receive do
        {:DOWN, ^ref, :process, ^coordinator_pid, _} -> :ok
      after
        10_000 -> flunk("Timeout")
      end

      # Verify results
      {:ok, updated_session} = Ash.get(ScrapeSession, session.id, actor: actor)
      assert updated_session.status == :completed
      assert updated_session.total_found == 3  # 1 + 2
      assert updated_session.total_created == 2  # Only unique notices

      # Verify only unique notices exist
      {:ok, notices} = Enforcement.list_notices(actor: actor)
      assert length(notices) == 2
      notice_numbers = Enum.map(notices, & &1.notice_number) |> Enum.sort()
      assert notice_numbers == ["IN/2024/DUP001", "IN/2024/NEW001"]
    end

    test "respects cancellation during scraping", %{agency: agency, actor: actor} do
      # Mock many pages to allow time for cancellation
      mock_notices = for i <- 1..10 do
        %{
          "href" => "/notices/2024/12/notice-#{i}",
          "noticeNumber" => "IN/2024/#{String.pad_leading("#{i}", 3, "0")}",
          "title" => "Company #{i} - Improvement Notice",
          "noticeType" => "Improvement",
          "dateOfIssue" => "2024-12-01",
          "complianceDate" => "2025-01-15"
        }
      end

      # Set up mocks for 5 pages
      pages_data = Enum.chunk_every(mock_notices, 2) |> Enum.with_index(1)
      setup_notice_list_mocks(Enum.map(pages_data, fn {notices, page} -> {page, notices} end))

      # Create session
      {:ok, session} = Ash.create(ScrapeSession, %{
        agency_id: agency.id,
        data_type: :notice,
        status: :pending,
        config: %{
          pages_to_scrape: 5,
          starting_page: 1
        }
      }, actor: actor)

      # Start scraping
      {:ok, coordinator_pid} = ScrapeCoordinator.start_session(session, actor: actor)

      # Wait a bit then cancel
      Process.sleep(500)
      ScrapeCoordinator.cancel_session(session.id)

      # Wait for coordinator to stop
      ref = Process.monitor(coordinator_pid)
      receive do
        {:DOWN, ^ref, :process, ^coordinator_pid, _} -> :ok
      after
        5_000 -> flunk("Coordinator didn't stop after cancellation")
      end

      # Verify session was cancelled
      {:ok, updated_session} = Ash.get(ScrapeSession, session.id, actor: actor)
      assert updated_session.status == :cancelled
      assert updated_session.pages_scraped < 5  # Should not have completed all pages
    end
  end

  # Helper functions for mocking
  defp setup_notice_list_mocks(pages_data) do
    Enum.each(pages_data, fn {page, notices} ->
      Process.put({:mock_notices_page, page}, {:ok, notices})
    end)
  end

  defp setup_notice_list_error(page) do
    Process.put({:mock_notices_page, page}, {:error, "Network error"})
  end

  defp setup_notice_details_mocks(details_map) do
    Enum.each(details_map, fn {href, details} ->
      Process.put({:mock_notice_details, href}, {:ok, details})
    end)
  end
end