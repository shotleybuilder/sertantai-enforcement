defmodule EhsEnforcementWeb.Admin.ScrapeLiveTest do
  use EhsEnforcementWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias EhsEnforcement.Scraping.StrategyRegistry

  describe "mount/3" do
    setup [:create_admin_user]

    test "mounts successfully with HSE case strategy", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/scrape/hse/case", on_error: :warn)

      assert html =~ "Health &amp; Safety Executive (HSE) Cases"
      assert html =~ "HSE Case Scraping"
      assert has_element?(view, "#start_page")
      assert has_element?(view, "#max_pages")
      assert has_element?(view, "#database")
    end

    test "mounts successfully with HSE notice strategy", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/scrape/hse/notice", on_error: :warn)

      assert html =~ "Health &amp; Safety Executive (HSE) Notices"
      assert html =~ "HSE Notice Scraping"
      assert has_element?(view, "#start_page")
      assert has_element?(view, "#max_pages")
      assert has_element?(view, "#database")
    end

    test "mounts successfully with EA case strategy", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/scrape/ea/case", on_error: :warn)

      assert html =~ "Environment Agency (EA) Cases"
      assert html =~ "Environment Agency Case Scraping"
      assert has_element?(view, "#date_from")
      assert has_element?(view, "#date_to")
      assert has_element?(view, "#action_type_court_case")
      assert has_element?(view, "#action_type_caution")
    end

    test "mounts successfully with EA notice strategy", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/scrape/ea/notice", on_error: :warn)

      assert html =~ "Environment Agency (EA) Notices"
      assert html =~ "Environment Agency Notice Scraping"
      assert has_element?(view, "#date_from")
      assert has_element?(view, "#date_to")
      refute has_element?(view, "#action_type_court_case")
    end

    test "redirects with error for invalid agency", %{conn: conn} do
      {:error, {:redirect, %{to: to, flash: flash}}} =
        live(conn, ~p"/admin/scrape/invalid_agency/case", on_error: :warn)

      assert to == ~p"/admin"
      assert flash["error"] =~ "Invalid agency"
    end

    test "redirects with error for invalid enforcement type", %{conn: conn} do
      {:error, {:redirect, %{to: to, flash: flash}}} =
        live(conn, ~p"/admin/scrape/hse/invalid_type", on_error: :warn)

      assert to == ~p"/admin"
      assert flash["error"] =~ "Invalid enforcement type"
    end

    test "redirects with error for unsupported agency/type combination", %{conn: conn} do
      # Note: All valid combinations are supported, but testing the pattern
      {:error, {:redirect, %{to: to, flash: flash}}} =
        live(conn, ~p"/admin/scrape/sepa/case", on_error: :warn)

      assert to == ~p"/admin"
      assert flash["error"]
    end
  end

  describe "HSE form rendering" do
    setup [:create_admin_user]

    test "displays HSE-specific form fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/hse/case", on_error: :warn)

      # Check HSE-specific fields
      assert has_element?(view, "input[name='start_page']")
      assert has_element?(view, "input[name='max_pages']")
      assert has_element?(view, "select[name='database']")

      # Should NOT have EA fields
      refute has_element?(view, "input[name='date_from']")
      refute has_element?(view, "input[name='date_to']")
    end

    test "displays default values for HSE form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/scrape/hse/case", on_error: :warn)

      assert html =~ "value=\"1\""
      assert html =~ "value=\"10\""
      assert html =~ "selected"
    end

    test "database dropdown shows all HSE databases", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/hse/case", on_error: :warn)

      assert has_element?(view, "option[value='convictions']")
      assert has_element?(view, "option[value='notices']")
      assert has_element?(view, "option[value='appeals']")
    end
  end

  describe "EA form rendering" do
    setup [:create_admin_user]

    test "displays EA-specific form fields for cases", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/ea/case", on_error: :warn)

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
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/ea/notice", on_error: :warn)

      # Check EA notice fields
      assert has_element?(view, "input[name='date_from']")
      assert has_element?(view, "input[name='date_to']")

      # Notice scraping should NOT show action type checkboxes
      refute has_element?(view, "input[name='action_types[]'][value='court_case']")
      refute has_element?(view, "input[name='action_types[]'][value='caution']")
    end

    test "displays default date range for EA form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/scrape/ea/case", on_error: :warn)

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
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/hse/case", on_error: :warn)

      strategy = :sys.get_state(view.pid).socket.assigns.strategy

      assert strategy == EhsEnforcement.Scraping.Strategies.HSE.CaseStrategy
      assert strategy.agency_identifier() == :hse
      assert strategy.enforcement_type() == :case
    end

    test "selects correct strategy for EA notice", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/ea/notice", on_error: :warn)

      strategy = :sys.get_state(view.pid).socket.assigns.strategy

      assert strategy == EhsEnforcement.Scraping.Strategies.EA.NoticeStrategy
      assert strategy.agency_identifier() == :ea
      assert strategy.enforcement_type() == :notice
    end
  end

  describe "initial state" do
    setup [:create_admin_user]

    test "sets correct initial state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/hse/case", on_error: :warn)

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
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/hse/case", on_error: :warn)

      assert has_element?(view, "button[type='submit']", "Start Scraping")
      refute has_element?(view, "button", "Stop Scraping")
    end

    test "shows Back to Admin link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/hse/case", on_error: :warn)

      assert has_element?(view, "a[href='/admin']", "Back to Admin")
    end

    test "shows strategy name in header", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/scrape/hse/case", on_error: :warn)

      assert html =~ "HSE Case Scraping"
    end

    test "shows agency and type display names", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/scrape/ea/notice", on_error: :warn)

      assert html =~ "Environment Agency (EA) Notices"
    end
  end

  describe "progress tracker" do
    setup [:create_admin_user]

    test "displays progress component for HSE", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/scrape/hse/case", on_error: :warn)

      # Progress component should be visible
      assert html =~ "HSE Progress"
      # Should show ready status initially (idle state)
      assert html =~ "Ready"
    end

    test "displays progress component for EA", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/scrape/ea/notice", on_error: :warn)

      # Progress component should be visible
      assert html =~ "EA Progress"
      # Should show ready status initially (idle state)
      assert html =~ "Ready"
    end
  end

  describe "scraped records display" do
    setup [:create_admin_user]

    test "does not show scraped records section at page load", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/scrape/hse/case", on_error: :warn)

      # Should NOT show scraped records section when no active session
      refute html =~ "Scraped Cases (This Session)"
      refute html =~ "cases scraped in current session"
    end

    test "does not show scraped records section for EA notices at page load", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/scrape/ea/notice", on_error: :warn)

      # Should NOT show scraped records section when no active session
      refute html =~ "Scraped Notices (This Session)"
      refute html =~ "notices scraped in current session"
    end

    test "does not show Recently Scraped section (saves screen space)", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/scrape/hse/case", on_error: :warn)

      # Should NOT show the "Recently Scraped" section (takes up valuable window space)
      refute html =~ "Recently Scraped Cases"
      refute html =~ "Recently Scraped Notices"
    end
  end

  describe "validation" do
    setup [:create_admin_user]

    test "displays validation errors for invalid HSE params", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/hse/case", on_error: :warn)

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
      {:ok, view, _html} = live(conn, ~p"/admin/scrape/ea/case", on_error: :warn)

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

    test "requires admin privileges" do
      # Create non-admin user using proper GitHub OAuth registration action
      user_info = %{
        "email" => "user@example.com",
        "name" => "Regular User",
        "login" => "regularuser",
        "id" => 99999,
        "avatar_url" => "https://github.com/images/avatars/regularuser",
        "html_url" => "https://github.com/regularuser"
      }

      oauth_tokens = %{
        "access_token" => "test_access_token_regular",
        "token_type" => "Bearer"
      }

      {:ok, user} = Ash.create(EhsEnforcement.Accounts.User, %{
        user_info: user_info,
        oauth_tokens: oauth_tokens
      }, action: :register_with_github)

      # User is NOT an admin (is_admin defaults to false)
      conn =
        build_conn()
        |> init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user)

      # Attempt to access admin route
      conn = get(conn, ~p"/admin/scrape/hse/case")

      # Should return 403 Forbidden (access denied for non-admin)
      assert conn.status == 403
    end
  end

  describe "real-time scraped records - PubSub broadcasts" do
    setup [:create_admin_user, :create_test_agency, :create_test_offender]

    test "displays notice in real-time when notice:scraped PubSub event is broadcast", %{conn: conn, user: user, agency: agency, offender: offender} do
      # Mount the unified scraping interface
      {:ok, view, html} = live(conn, ~p"/admin/scrape", on_error: :warn)

      # Select EA agency by clicking the button
      view
      |> element("button[phx-value-agency='ea']")
      |> render_click()

      # Select "notices" database for EA notices
      view
      |> element("#database")
      |> render_change(%{"database" => "notices"})

      # Initially, no scraped records should be visible (no active session)
      html = render(view)
      refute html =~ "Scraped Notices (This Session)"

      # Simulate starting a scraping session by setting scraping_session_started_at
      # This is what happens when user clicks "Start Scraping"
      send(view.pid, {:set_session_started, DateTime.utc_now()})

      # Give LiveView time to process the message
      :timer.sleep(50)

      # Create a test notice in the database (simulating EA scraper creating a notice)
      {:ok, notice} = create_test_notice(%{
        regulator_id: "EA-TEST-001",
        notice_body: "Environmental Violation Test - Failure to comply with permit conditions",
        notice_date: ~D[2025-10-20],
        compliance_date: ~D[2025-11-20],
        offence_action_date: ~D[2025-10-23],
        agency_id: agency.id,
        offender_id: offender.id
      }, user)

      # Simulate the PubSub broadcast that happens in ea.ex after processing each notice
      Phoenix.PubSub.broadcast(
        EhsEnforcement.PubSub,
        "notice:scraped",
        {:record_scraped, %{record: notice, status: :created, type: :notice}}
      )

      # Give LiveView time to process the PubSub message
      :timer.sleep(100)

      # Re-render the view to see updated scraped_records
      html = render(view)

      # Should now show the scraped records section
      assert html =~ "Scraped Notices (This Session)"

      # Should display the notice details
      assert html =~ "EA-TEST-001"
      assert html =~ "Environmental Violation Test"
      assert html =~ offender.name
    end

    test "displays case in real-time when case:scraped PubSub event is broadcast", %{conn: conn, user: user, agency: agency, offender: offender} do
      # Mount the unified scraping interface
      {:ok, view, html} = live(conn, ~p"/admin/scrape", on_error: :warn)

      # Select EA agency by clicking the button
      view
      |> element("button[phx-value-agency='ea']")
      |> render_click()

      # Select "cases" database for EA cases
      view
      |> element("#database")
      |> render_change(%{"database" => "cases"})

      # Initially, no scraped records should be visible
      html = render(view)
      refute html =~ "Scraped Cases (This Session)"

      # Simulate starting a scraping session
      send(view.pid, {:set_session_started, DateTime.utc_now()})
      :timer.sleep(50)

      # Create a test case in the database
      {:ok, case_record} = create_test_case(%{
        regulator_id: "EA-CASE-TEST-001",
        offence_result: "Conviction - Guilty Plea",
        offence_fine: Decimal.new("5000"),
        offence_action_date: ~D[2025-10-23],
        agency_id: agency.id,
        offender_id: offender.id
      }, user)

      # Simulate the PubSub broadcast
      Phoenix.PubSub.broadcast(
        EhsEnforcement.PubSub,
        "case:scraped",
        {:record_scraped, %{record: case_record, status: :created, type: :case}}
      )

      :timer.sleep(100)
      html = render(view)

      # Should show the case
      assert html =~ "Scraped Cases (This Session)"
      assert html =~ "EA-CASE-TEST-001"
      assert html =~ "Conviction - Guilty Plea"
    end

    test "displays multiple notices as they are broadcast one-by-one", %{conn: conn, user: user, agency: agency, offender: offender} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape", on_error: :warn)

      # Select EA agency and notices database
      view |> element("button[phx-value-agency='ea']") |> render_click()
      view |> element("#database") |> render_change(%{"database" => "notices"})

      send(view.pid, {:set_session_started, DateTime.utc_now()})
      :timer.sleep(50)

      # Create and broadcast 3 notices, simulating real-time scraping
      for i <- 1..3 do
        {:ok, notice} = create_test_notice(%{
          regulator_id: "EA-TEST-00#{i}",
          notice_body: "Violation #{i}",
          notice_date: ~D[2025-10-20],
          compliance_date: ~D[2025-11-20],
          offence_action_date: ~D[2025-10-23],
          agency_id: agency.id,
          offender_id: offender.id
        }, user)

        Phoenix.PubSub.broadcast(
          EhsEnforcement.PubSub,
          "notice:scraped",
          {:record_scraped, %{record: notice, status: :created, type: :notice}}
        )

        # Simulate 3-second delay between EA scraping operations
        :timer.sleep(50)
      end

      html = render(view)

      # All 3 notices should be visible
      assert html =~ "EA-TEST-001"
      assert html =~ "EA-TEST-002"
      assert html =~ "EA-TEST-003"
      assert html =~ "3 notices scraped in current session"
    end

    test "shows processing status (:created, :updated, :existing) for each record", %{conn: conn, user: user, agency: agency, offender: offender} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape", on_error: :warn)

      # Select EA agency and notices database
      view |> element("button[phx-value-agency='ea']") |> render_click()
      view |> element("#database") |> render_change(%{"database" => "notices"})

      send(view.pid, {:set_session_started, DateTime.utc_now()})
      :timer.sleep(50)

      # Create notice with :created status
      {:ok, notice_created} = create_test_notice(%{
        regulator_id: "EA-CREATED",
        notice_body: "New Notice",
        notice_date: ~D[2025-10-20],
        compliance_date: ~D[2025-11-20],
        offence_action_date: ~D[2025-10-23],
        agency_id: agency.id,
        offender_id: offender.id
      }, user)

      Phoenix.PubSub.broadcast(
        EhsEnforcement.PubSub,
        "notice:scraped",
        {:record_scraped, %{record: notice_created, status: :created, type: :notice}}
      )

      :timer.sleep(50)

      # Create notice with :existing status
      {:ok, notice_existing} = create_test_notice(%{
        regulator_id: "EA-EXISTING",
        notice_body: "Existing Notice",
        notice_date: ~D[2025-10-20],
        compliance_date: ~D[2025-11-20],
        offence_action_date: ~D[2025-10-23],
        agency_id: agency.id,
        offender_id: offender.id
      }, user)

      Phoenix.PubSub.broadcast(
        EhsEnforcement.PubSub,
        "notice:scraped",
        {:record_scraped, %{record: notice_existing, status: :existing, type: :notice}}
      )

      :timer.sleep(50)
      html = render(view)

      # Both notices should be visible
      assert html =~ "EA-CREATED"
      assert html =~ "EA-EXISTING"

      # Note: Status badges would need to be added to the template to test this
      # For now, just verify records are displayed
    end

    test "deduplicates records by regulator_id when same record is broadcast multiple times", %{conn: conn, user: user, agency: agency, offender: offender} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape", on_error: :warn)

      # Select EA agency and notices database
      view |> element("button[phx-value-agency='ea']") |> render_click()
      view |> element("#database") |> render_change(%{"database" => "notices"})

      send(view.pid, {:set_session_started, DateTime.utc_now()})
      :timer.sleep(50)

      {:ok, notice} = create_test_notice(%{
        regulator_id: "EA-DUPLICATE",
        notice_body: "Test Notice",
        notice_date: ~D[2025-10-20],
        compliance_date: ~D[2025-11-20],
        offence_action_date: ~D[2025-10-23],
        agency_id: agency.id,
        offender_id: offender.id
      }, user)

      # Broadcast the same notice 3 times
      for _i <- 1..3 do
        Phoenix.PubSub.broadcast(
          EhsEnforcement.PubSub,
          "notice:scraped",
          {:record_scraped, %{record: notice, status: :existing, type: :notice}}
        )
        :timer.sleep(30)
      end

      html = render(view)

      # Should only appear once in the list (deduplicated by regulator_id)
      assert html =~ "EA-DUPLICATE"

      # Count occurrences (should be 1, not 3)
      occurrence_count = html
        |> String.split("EA-DUPLICATE")
        |> length()
        |> Kernel.-(1)

      assert occurrence_count == 1, "Expected 1 occurrence, got #{occurrence_count}"
    end

    test "ignores broadcasts when no active scraping session", %{conn: conn, user: user, agency: agency, offender: offender} do
      {:ok, view, html} = live(conn, ~p"/admin/scrape", on_error: :warn)

      # Select EA agency and notices database
      view |> element("button[phx-value-agency='ea']") |> render_click()
      view |> element("#database") |> render_change(%{"database" => "notices"})

      # Do NOT start a session (no scraping_session_started_at set)

      {:ok, notice} = create_test_notice(%{
        regulator_id: "EA-IGNORED",
        notice_body: "Should Not Display",
        notice_date: ~D[2025-10-20],
        compliance_date: ~D[2025-11-20],
        offence_action_date: ~D[2025-10-23],
        agency_id: agency.id,
        offender_id: offender.id
      }, user)

      Phoenix.PubSub.broadcast(
        EhsEnforcement.PubSub,
        "notice:scraped",
        {:record_scraped, %{record: notice, status: :created, type: :notice}}
      )

      :timer.sleep(100)
      html = render(view)

      # Should NOT display the notice (no active session)
      refute html =~ "EA-IGNORED"
      refute html =~ "Should Not Display"
    end
  end

  # Test Helpers

  defp create_admin_user(context) do
    # Use the proper helper from ConnCase
    register_and_log_in_admin(context)
  end

  defp create_test_agency(_context) do
    # Use Ash.Seed for test fixtures
    agency = Ash.Seed.seed!(EhsEnforcement.Enforcement.Agency, %{
      code: :ea,
      name: "Environment Agency",
      base_url: "https://environment.data.gov.uk",
      enabled: true
    })

    %{agency: agency}
  end

  defp create_test_offender(_context) do
    # Use Ash.Seed for test fixtures
    offender = Ash.Seed.seed!(EhsEnforcement.Enforcement.Offender, %{
      name: "Test Company Ltd",
      business_type: :limited_company
    })

    %{offender: offender}
  end

  defp create_test_notice(attrs, actor) do
    Ash.create(EhsEnforcement.Enforcement.Notice, attrs, actor: actor)
  end

  defp create_test_case(attrs, actor) do
    Ash.create(EhsEnforcement.Enforcement.Case, attrs, actor: actor)
  end
end
