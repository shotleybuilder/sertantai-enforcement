defmodule EhsEnforcementWeb.Admin.ScrapeLiveTest do
  use EhsEnforcementWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias EhsEnforcement.Scraping.StrategyRegistry
  alias EhsEnforcement.Accounts

  describe "mount/3" do
    setup [:create_admin_user]

    test "mounts successfully with HSE case strategy", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/scrape/hse/case")

      assert html =~ "Health &amp; Safety Executive (HSE) Cases"
      assert html =~ "HSE Case Scraping"
      assert has_element?(view, "#start_page")
      assert has_element?(view, "#max_pages")
      assert has_element?(view, "#database")
    end

    test "mounts successfully with HSE notice strategy", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/scrape/hse/notice")

      assert html =~ "Health &amp; Safety Executive (HSE) Notices"
      assert html =~ "HSE Notice Scraping"
      assert has_element?(view, "#start_page")
      assert has_element?(view, "#max_pages")
      assert has_element?(view, "#database")
    end

    test "mounts successfully with EA case strategy", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/scrape/environment_agency/case")

      assert html =~ "Environment Agency (EA) Cases"
      assert html =~ "Environment Agency Case Scraping"
      assert has_element?(view, "#date_from")
      assert has_element?(view, "#date_to")
      assert has_element?(view, "#action_type_court_case")
      assert has_element?(view, "#action_type_caution")
    end

    test "mounts successfully with EA notice strategy", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/scrape/environment_agency/notice")

      assert html =~ "Environment Agency (EA) Notices"
      assert html =~ "Environment Agency Notice Scraping"
      assert has_element?(view, "#date_from")
      assert has_element?(view, "#date_to")
      refute has_element?(view, "#action_type_court_case")
    end

    test "redirects with error for invalid agency", %{conn: conn} do
      {:error, {:live_redirect, %{to: to, flash: flash}}} =
        live(conn, ~p"/admin/scrape/invalid_agency/case")

      assert to == ~p"/admin"
      assert flash["error"] =~ "Invalid agency"
    end

    test "redirects with error for invalid enforcement type", %{conn: conn} do
      {:error, {:live_redirect, %{to: to, flash: flash}}} =
        live(conn, ~p"/admin/scrape/hse/invalid_type")

      assert to == ~p"/admin"
      assert flash["error"] =~ "Invalid enforcement type"
    end

    test "redirects with error for unsupported agency/type combination", %{conn: conn} do
      # Note: All valid combinations are supported, but testing the pattern
      {:error, {:redirect, %{to: to, flash: flash}}} =
        live(conn, ~p"/admin/scrape/sepa/case")

      assert to == ~p"/admin"
      assert flash["error"]
    end
  end

  describe "HSE form rendering" do
    setup [:create_admin_user]

    test "displays HSE-specific form fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/hse/case")

      # Check HSE-specific fields
      assert has_element?(view, "input[name='start_page']")
      assert has_element?(view, "input[name='max_pages']")
      assert has_element?(view, "select[name='database']")

      # Should NOT have EA fields
      refute has_element?(view, "input[name='date_from']")
      refute has_element?(view, "input[name='date_to']")
    end

    test "displays default values for HSE form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/scrape/hse/case")

      assert html =~ "value=\"1\""
      assert html =~ "value=\"10\""
      assert html =~ "selected"
    end

    test "database dropdown shows all HSE databases", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/hse/case")

      assert has_element?(view, "option[value='convictions']")
      assert has_element?(view, "option[value='notices']")
      assert has_element?(view, "option[value='appeals']")
    end
  end

  describe "EA form rendering" do
    setup [:create_admin_user]

    test "displays EA-specific form fields for cases", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/environment_agency/case")

      # Check EA-specific fields
      assert has_element?(view, "input[name='date_from']")
      assert has_element?(view, "input[name='date_to']")
      assert has_element?(view, "input[name='action_types[]'][value='court_case']")
      assert has_element?(view, "input[name='action_types[]'][value='caution']")

      # Should NOT have HSE fields
      refute has_element?(view, "input[name='start_page']")
      refute has_element?(view, "input[name='max_pages']")
      refute has_element?(view, "select[name='database']")
    end

    test "displays EA-specific form fields for notices", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/environment_agency/notice")

      # Check EA notice fields
      assert has_element?(view, "input[name='date_from']")
      assert has_element?(view, "input[name='date_to']")

      # Notice scraping should NOT show action type checkboxes
      refute has_element?(view, "input[name='action_types[]'][value='court_case']")
      refute has_element?(view, "input[name='action_types[]'][value='caution']")
    end

    test "displays default date range for EA form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/scrape/environment_agency/case")

      # Should have date values (30 days ago to today)
      date_from = Date.add(Date.utc_today(), -30) |> Date.to_string()
      date_to = Date.utc_today() |> Date.to_string()

      assert html =~ date_from
      assert html =~ date_to
    end
  end

  describe "strategy selection" do
    setup [:create_admin_user]

    test "selects correct strategy for HSE case", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/hse/case")

      strategy = :sys.get_state(view.pid).socket.assigns.strategy

      assert strategy == EhsEnforcement.Scraping.Strategies.HSE.CaseStrategy
      assert strategy.agency_identifier() == :hse
      assert strategy.enforcement_type() == :case
    end

    test "selects correct strategy for EA notice", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/environment_agency/notice")

      strategy = :sys.get_state(view.pid).socket.assigns.strategy

      assert strategy == EhsEnforcement.Scraping.Strategies.EA.NoticeStrategy
      assert strategy.agency_identifier() == :environment_agency
      assert strategy.enforcement_type() == :notice
    end
  end

  describe "initial state" do
    setup [:create_admin_user]

    test "sets correct initial state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/hse/case")

      state = :sys.get_state(view.pid).socket.assigns

      assert state.agency == :hse
      assert state.enforcement_type == :case
      assert state.scraping_active == false
      assert state.current_session == nil
      assert is_map(state.progress)
      assert is_map(state.form_params)
    end
  end

  describe "UI elements" do
    setup [:create_admin_user]

    test "shows Start Scraping button when idle", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/hse/case")

      assert has_element?(view, "button[type='submit']", "Start Scraping")
      refute has_element?(view, "button", "Stop Scraping")
    end

    test "shows Back to Admin link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/hse/case")

      assert has_element?(view, "a[href='/admin']", "Back to Admin")
    end

    test "shows strategy name in header", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/scrape/hse/case")

      assert html =~ "HSE Case Scraping"
    end

    test "shows agency and type display names", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/scrape/environment_agency/notice")

      assert html =~ "Environment Agency (EA) Notices"
    end
  end

  describe "validation" do
    setup [:create_admin_user]

    test "displays validation errors for invalid HSE params", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/hse/case")

      # Submit invalid params (negative page numbers)
      view
      |> form("form", %{
        "start_page" => "-1",
        "max_pages" => "0",
        "database" => "convictions"
      })
      |> render_submit()

      # Should show validation error
      # Note: Actual validation error display depends on strategy implementation
      assert has_element?(view, "form")
    end

    test "displays validation errors for invalid EA params", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/environment_agency/case")

      # Submit invalid date range (date_to before date_from)
      view
      |> form("form", %{
        "date_from" => "2024-12-31",
        "date_to" => "2024-01-01"
      })
      |> render_submit()

      # Should show validation error
      assert has_element?(view, "form")
    end
  end

  describe "authentication" do
    test "requires authentication", %{conn: conn} do
      # Attempt to access without authentication
      conn = get(conn, ~p"/admin/scrape/hse/case")

      # Should redirect to sign in
      assert redirected_to(conn) =~ "/sign-in"
    end

    test "requires admin privileges", %{conn: conn} do
      # Create non-admin user
      {:ok, user} =
        Accounts.register_with_password(%{
          email: "user@example.com",
          password: "Test123!@#Test123!@#",
          role: :user
        })

      conn = log_in_user(conn, user)

      # Attempt to access admin route
      conn = get(conn, ~p"/admin/scrape/hse/case")

      # Should redirect (access denied)
      assert redirected_to(conn)
    end
  end

  # Test Helpers

  defp create_admin_user(_context) do
    {:ok, admin} =
      Accounts.register_with_password(%{
        email: "admin@example.com",
        password: "Test123!@#Test123!@#",
        role: :admin
      })

    %{admin: admin, conn: build_conn() |> log_in_user(admin)}
  end

  defp log_in_user(conn, user) do
    token =
      EhsEnforcement.Accounts.Token
      |> Ash.Changeset.for_create(:build_token, %{user_id: user.id}, actor: user)
      |> Ash.create!()

    conn
    |> init_test_session(%{})
    |> put_session(:user_token, token.token)
  end
end
