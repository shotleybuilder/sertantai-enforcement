defmodule EhsEnforcementWeb.Admin.NoticeLive.EaNoticeProgressTest do
  @moduledoc """
  Tests for EA notice scraping progress tracking.

  This test ensures that ScrapeSession updates are properly batched and preserve all fields.
  """

  use EhsEnforcementWeb.ConnCase

  require Ash.Query
  import Ash.Expr

  alias EhsEnforcement.Scraping.ScrapeSession

  describe "ScrapeSession Field Preservation" do
    setup do
      # Create admin user
      user_info = %{
        "email" => "ea-notice-progress-admin@test.com",
        "name" => "EA Notice Progress Admin",
        "login" => "eanoticeprogressadmin",
        "id" => 12346,
        "avatar_url" => "https://github.com/images/avatars/eanoticeprogressadmin",
        "html_url" => "https://github.com/eanoticeprogressadmin"
      }

      oauth_tokens = %{
        "access_token" => "test_access_token_notice",
        "token_type" => "Bearer"
      }

      {:ok, user} = Ash.create(EhsEnforcement.Accounts.User, %{
        user_info: user_info,
        oauth_tokens: oauth_tokens
      }, action: :register_with_github)

      {:ok, admin_user} = Ash.update(user, %{
        is_admin: true,
        admin_checked_at: DateTime.utc_now()
      }, action: :update_admin_status, actor: user)

      %{admin_user: admin_user}
    end

    test "single-field updates preserve cases_found", %{admin_user: admin_user} do
      # Create session with cases_found set
      {:ok, session} = ScrapeSession
      |> Ash.Changeset.for_create(:create, %{
        session_id: "test_single_field_001",
        database: "ea_notices",
        status: :running,
        start_page: 1,
        max_pages: 1,
        cases_found: 41  # Initial value - should be preserved
      })
      |> Ash.create(actor: admin_user)

      # Verify initial state
      assert session.cases_found == 41
      assert session.cases_created == 0

      # Update only cases_created (simulating broken per-notice pattern)
      {:ok, updated_session} = session
      |> Ash.Changeset.for_update(:update, %{
        cases_created: 1
      })
      |> Ash.update(actor: admin_user)

      # Reload from database to verify persistence
      session_from_db = Ash.get!(ScrapeSession, updated_session.id, actor: admin_user)

      # THIS IS THE KEY TEST: cases_found should still be 41
      assert session_from_db.cases_found == 41,
        "Expected cases_found=41, got #{session_from_db.cases_found}. Single-field update should preserve other fields."
      assert session_from_db.cases_created == 1
    end

    test "batched updates work correctly", %{admin_user: admin_user} do
      # Create session
      {:ok, session} = ScrapeSession
      |> Ash.Changeset.for_create(:create, %{
        session_id: "test_batched_001",
        database: "ea_notices",
        status: :running,
        start_page: 1,
        max_pages: 1,
        cases_found: 41
      })
      |> Ash.create(actor: admin_user)

      # Batched update (correct pattern)
      {:ok, updated_session} = session
      |> Ash.Changeset.for_update(:update, %{
        status: :completed,
        cases_found: 41,  # Explicitly preserve
        cases_created: 15,
        cases_updated: 2,
        cases_exist_total: 24,
        errors_count: 0
      })
      |> Ash.update(actor: admin_user)

      # Reload and verify ALL fields updated correctly
      session_from_db = Ash.get!(ScrapeSession, updated_session.id, actor: admin_user)

      assert session_from_db.status == :completed
      assert session_from_db.cases_found == 41
      assert session_from_db.cases_created == 15
      assert session_from_db.cases_updated == 2
      assert session_from_db.cases_exist_total == 24
      assert session_from_db.errors_count == 0
    end

    test "multiple single-field updates show the problem", %{admin_user: admin_user} do
      # This test demonstrates the bug: multiple single-field updates

      {:ok, session} = ScrapeSession
      |> Ash.Changeset.for_create(:create, %{
        session_id: "test_multiple_updates_001",
        database: "ea_notices",
        status: :running,
        start_page: 1,
        max_pages: 1,
        cases_found: 41
      })
      |> Ash.create(actor: admin_user)

      # Update 1: cases_created
      {:ok, session} = session
      |> Ash.Changeset.for_update(:update, %{cases_created: 5})
      |> Ash.update(actor: admin_user)

      session = Ash.get!(ScrapeSession, session.id, actor: admin_user)
      assert session.cases_found == 41, "After update 1, cases_found should still be 41, got #{session.cases_found}"
      assert session.cases_created == 5

      # Update 2: cases_updated
      {:ok, session} = session
      |> Ash.Changeset.for_update(:update, %{cases_updated: 2})
      |> Ash.update(actor: admin_user)

      session = Ash.get!(ScrapeSession, session.id, actor: admin_user)
      assert session.cases_found == 41, "After update 2, cases_found should still be 41, got #{session.cases_found}"
      assert session.cases_created == 5, "After update 2, cases_created should still be 5, got #{session.cases_created}"
      assert session.cases_updated == 2

      # Update 3: cases_exist_total
      {:ok, session} = session
      |> Ash.Changeset.for_update(:update, %{cases_exist_total: 24})
      |> Ash.update(actor: admin_user)

      session = Ash.get!(ScrapeSession, session.id, actor: admin_user)
      assert session.cases_found == 41, "After update 3, cases_found should still be 41, got #{session.cases_found}"
      assert session.cases_created == 5, "After update 3, cases_created should still be 5, got #{session.cases_created}"
      assert session.cases_updated == 2, "After update 3, cases_updated should still be 2, got #{session.cases_updated}"
      assert session.cases_exist_total == 24

      # Final completion update
      {:ok, session} = session
      |> Ash.Changeset.for_update(:update, %{status: :completed})
      |> Ash.update(actor: admin_user)

      session = Ash.get!(ScrapeSession, session.id, actor: admin_user)

      # These should all be preserved
      assert session.status == :completed
      assert session.cases_found == 41, "After completion, cases_found should be 41, got #{session.cases_found}"
      assert session.cases_created == 5, "After completion, cases_created should be 5, got #{session.cases_created}"
      assert session.cases_updated == 2
      assert session.cases_exist_total == 24
    end
  end
end
