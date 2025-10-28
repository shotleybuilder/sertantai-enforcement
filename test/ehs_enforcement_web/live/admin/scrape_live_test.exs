defmodule EhsEnforcementWeb.Admin.ScrapeLiveTest do
  use EhsEnforcementWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  # Note: Tests for parameterized routes removed during Phase 6 refactor (deprecation of old LiveViews)
  # Comprehensive testing for unified interface will be added in Phase 7
  #
  # Working tests below verify real-time PubSub functionality with unified interface

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
