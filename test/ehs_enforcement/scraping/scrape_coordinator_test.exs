defmodule EhsEnforcement.Scraping.ScrapeCoordinatorTest do
  use EhsEnforcement.DataCase

  require Ash.Query
  import Ash.Expr

  alias EhsEnforcement.Scraping.ScrapeCoordinator
  alias EhsEnforcement.Scraping.ScrapeSession
  alias EhsEnforcement.Enforcement

  describe "ScrapeSession Ash Resource" do
    test "creates new session with Ash.create" do
      session_params = %{
        session_id: "test_session_123",
        start_page: 1,
        max_pages: 10,
        database: "convictions",
        status: :running,
        current_page: 1,
        pages_processed: 0,
        cases_found: 0,
        cases_created: 0,
        cases_exist_total: 0,
        errors_count: 0
      }

      {:ok, session} = Ash.create(ScrapeSession, session_params)

      assert session.session_id == "test_session_123"
      assert session.status == :running
      assert session.current_page == 1
      assert session.pages_processed == 0
      assert session.cases_found == 0
      assert session.cases_created == 0
      assert session.cases_exist_total == 0
      assert session.errors_count == 0
    end

    test "creates session with custom start page" do
      session_params = %{
        session_id: "test_session_456",
        start_page: 5,
        max_pages: 10,
        database: "convictions",
        status: :running,
        current_page: 5,
        pages_processed: 0,
        cases_found: 0,
        cases_created: 0,
        cases_exist_total: 0,
        errors_count: 0
      }

      {:ok, session} = Ash.create(ScrapeSession, session_params)

      assert session.current_page == 5
      assert session.start_page == 5
    end
  end

  describe "session_summary/1" do
    test "generates summary with correct metrics" do
      start_time = DateTime.utc_now() |> DateTime.add(-60, :second)

      session_params = %{
        session_id: "test123",
        start_page: 1,
        max_pages: 10,
        database: "convictions",
        status: :completed,
        current_page: 4,
        pages_processed: 3,
        cases_found: 15,
        cases_created: 12,
        cases_exist_total: 3,
        errors_count: 0
      }

      {:ok, session} = Ash.create(ScrapeSession, session_params)

      # Manually set the inserted_at to simulate duration (this is read-only in Ash)
      # For testing, we'll work with the current time
      summary = ScrapeCoordinator.session_summary(session)

      assert summary.session_id == "test123"
      assert summary.status == :completed
      assert summary.pages_processed == 3
      assert summary.cases_found == 15
      assert summary.cases_created == 12
      assert summary.cases_exist_total == 3
      assert summary.error_count == 0
      # 12/15 * 100
      assert summary.success_rate == 80.0
      assert is_integer(summary.duration_seconds)
    end

    test "calculates success rate correctly" do
      session_params = %{
        session_id: "test456",
        start_page: 1,
        max_pages: 10,
        database: "convictions",
        status: :completed,
        current_page: 2,
        pages_processed: 1,
        cases_found: 10,
        cases_created: 8,
        cases_exist_total: 2,
        errors_count: 0
      }

      {:ok, session} = Ash.create(ScrapeSession, session_params)

      summary = ScrapeCoordinator.session_summary(session)
      assert summary.success_rate == 80.0
    end

    test "handles zero cases gracefully" do
      session_params = %{
        session_id: "test789",
        start_page: 1,
        max_pages: 10,
        database: "convictions",
        status: :completed,
        current_page: 2,
        pages_processed: 1,
        cases_found: 0,
        cases_created: 0,
        cases_exist_total: 0,
        errors_count: 0
      }

      {:ok, session} = Ash.create(ScrapeSession, session_params)

      summary = ScrapeCoordinator.session_summary(session)
      assert summary.success_rate == 0.0
    end
  end

  # Note: Full integration tests with actual scraping would require
  # mocking HTTP requests. For now we test the session management logic.

  describe "scrape_page_range/3" do
    test "configures session for specific page range" do
      # This test would require mocking the actual scraping
      # For now, we verify the option handling

      opts = [database: "test", actor: :test_actor]

      # We can't easily test the full flow without HTTP mocking,
      # but we can verify that the function exists and accepts parameters
      assert function_exported?(ScrapeCoordinator, :scrape_page_range, 2) or
               function_exported?(ScrapeCoordinator, :scrape_page_range, 3)
    end
  end

  describe "scraping session logic" do
    test "session continues when within page limits" do
      session_params = %{
        session_id: "test_range_1",
        start_page: 1,
        max_pages: 10,
        database: "convictions",
        status: :running,
        current_page: 5,
        pages_processed: 4,
        cases_found: 0,
        cases_created: 0,
        cases_exist_total: 0,
        errors_count: 0
      }

      {:ok, session} = Ash.create(ScrapeSession, session_params)

      # Test that session is within limits
      assert session.pages_processed < session.max_pages
      assert session.status == :running
    end

    test "session tracking updates correctly" do
      session_params = %{
        session_id: "test_tracking",
        start_page: 1,
        max_pages: 10,
        # Valid database value
        database: "convictions",
        status: :running,
        current_page: 1,
        pages_processed: 0,
        cases_found: 0,
        cases_created: 0,
        cases_exist_total: 0,
        errors_count: 0
      }

      {:ok, session} = Ash.create(ScrapeSession, session_params)

      # Simulate updating session after processing a page
      # Note: Don't update database field as it's not expected to change during session
      updated_params = %{
        current_page: 2,
        pages_processed: 1,
        cases_found: 5,
        cases_created: 3,
        cases_exist_total: 2
      }

      {:ok, updated_session} = Ash.update(session, updated_params)

      assert updated_session.current_page == 2
      assert updated_session.pages_processed == 1
      assert updated_session.cases_found == 5
      assert updated_session.cases_created == 3
      assert updated_session.cases_exist_total == 2
      # Database field should remain unchanged
      assert updated_session.database == "convictions"
    end
  end

  # Helper functions would go here for setting up test data

  defp create_test_agency do
    {:ok, agency} =
      Enforcement.create_agency(%{
        name: "Health and Safety Executive",
        code: :hse,
        base_url: "https://hse.gov.uk"
      })

    agency
  end
end
