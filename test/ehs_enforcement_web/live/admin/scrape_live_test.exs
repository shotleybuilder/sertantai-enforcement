defmodule EhsEnforcementWeb.Admin.ScrapeLiveTest do
  use EhsEnforcementWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  # Note: Tests for parameterized routes removed during Phase 6 refactor (deprecation of old LiveViews)
  # Comprehensive testing for unified interface added in Phase 7
  #
  # PubSub tests below are currently commented out - see Phase 7 session notes
  # These tests require integration testing approach rather than unit testing with LiveViewTest
  # Real-time PubSub functionality works correctly in production but cannot be reliably tested
  # with LiveViewTest.render() which doesn't synchronously process PubSub messages

  describe "unified scraping interface - mounting and initialization" do
    setup [:create_admin_user]

    test "mounts successfully at /admin/scrape", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/scrape")

      assert html =~ "UK Enforcement Data Scraping"
      assert html =~ "Scraping Configuration"
    end

    test "displays agency selection buttons (HSE and EA)", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/scrape")

      assert html =~ "HSE (Health &amp; Safety Executive)"
      assert html =~ "Environment Agency (EA)"
    end

    test "initializes with default HSE agency and convictions database", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape")

      assert view.assigns.agency == :hse
      assert view.assigns.database == "convictions"
    end
  end

  describe "unified scraping interface - agency selection" do
    setup [:create_admin_user]

    test "selecting HSE agency sets HSE and defaults to convictions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape")

      # Click EA first to change from default
      view |> element("button[phx-value-agency='ea']") |> render_click()

      # Now select HSE
      view |> element("button[phx-value-agency='hse']") |> render_click()

      assert view.assigns.agency == :hse
      assert view.assigns.database == "convictions"
      assert view.assigns.enforcement_type == :case
    end

    test "selecting EA agency sets EA and defaults to cases", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape")

      view |> element("button[phx-value-agency='ea']") |> render_click()

      assert view.assigns.agency == :ea
      assert view.assigns.database == "cases"
      assert view.assigns.enforcement_type == :case
    end

    test "switching agencies resets database to default for new agency", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape")

      # Default is HSE/convictions
      assert view.assigns.agency == :hse
      assert view.assigns.database == "convictions"

      # Change to HSE notices
      view |> element("#database") |> render_change(%{"database" => "notices"})
      assert view.assigns.database == "notices"

      # Switch to EA - should reset to EA's default (cases)
      view |> element("button[phx-value-agency='ea']") |> render_click()
      assert view.assigns.agency == :ea
      assert view.assigns.database == "cases"
    end
  end

  describe "unified scraping interface - database selection" do
    setup [:create_admin_user]

    test "selecting convictions database sets enforcement_type to :case", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape")

      # Default is already convictions
      assert view.assigns.database == "convictions"
      assert view.assigns.enforcement_type == :case
    end

    test "selecting notices database sets enforcement_type to :notice", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape")

      view |> element("#database") |> render_change(%{"database" => "notices"})

      assert view.assigns.database == "notices"
      assert view.assigns.enforcement_type == :notice
    end

    test "selecting cases database for EA sets enforcement_type to :case", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape")

      view |> element("button[phx-value-agency='ea']") |> render_click()
      view |> element("#database") |> render_change(%{"database" => "cases"})

      assert view.assigns.database == "cases"
      assert view.assigns.enforcement_type == :case
    end

    test "selecting notices database for EA sets enforcement_type to :notice", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape")

      view |> element("button[phx-value-agency='ea']") |> render_click()
      view |> element("#database") |> render_change(%{"database" => "notices"})

      assert view.assigns.database == "notices"
      assert view.assigns.enforcement_type == :notice
    end
  end

  describe "unified scraping interface - strategy pattern" do
    setup [:create_admin_user]

    test "HSE convictions uses HSE CaseStrategy", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape")

      # Default is HSE convictions
      assert view.assigns.strategy == EhsEnforcement.Scraping.Strategies.HSE.CaseStrategy
      assert view.assigns.strategy_name == "HSE Case Strategy"
    end

    test "HSE notices uses HSE NoticeStrategy", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape")

      view |> element("#database") |> render_change(%{"database" => "notices"})

      assert view.assigns.strategy == EhsEnforcement.Scraping.Strategies.HSE.NoticeStrategy
      assert view.assigns.strategy_name == "HSE Notice Strategy"
    end

    test "EA cases uses EA CaseStrategy", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape")

      view |> element("button[phx-value-agency='ea']") |> render_click()
      view |> element("#database") |> render_change(%{"database" => "cases"})

      assert view.assigns.strategy == EhsEnforcement.Scraping.Strategies.EA.CaseStrategy
      assert view.assigns.strategy_name == "EA Case Strategy"
    end

    test "EA notices uses EA NoticeStrategy", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape")

      view |> element("button[phx-value-agency='ea']") |> render_click()
      view |> element("#database") |> render_change(%{"database" => "notices"})

      assert view.assigns.strategy == EhsEnforcement.Scraping.Strategies.EA.NoticeStrategy
      assert view.assigns.strategy_name == "EA Notice Strategy"
    end
  end

  describe "unified scraping interface - scraped records" do
    setup [:create_admin_user]

    test "initializes with empty scraped_records", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/scrape")

      assert view.assigns.scraped_records == []
    end

    test "does not display scraped records section when empty", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/scrape")

      refute html =~ "Scraped Cases (This Session)"
      refute html =~ "Scraped Notices (This Session)"
    end
  end

  # =============================================================================
  # PubSub TESTS DEFERRED - See Phase 7 session notes
  # =============================================================================
  # These tests require integration testing approach rather than unit testing
  # with LiveViewTest. Real-time PubSub functionality works correctly in
  # production but cannot be reliably tested with LiveViewTest.render() which
  # doesn't synchronously process PubSub messages.
  #
  # Future work:
  # - Implement integration tests with actual scraping processes
  # - Consider mocking strategy for PubSub in unit tests
  # - Or use test-specific endpoints that bypass PubSub
  # =============================================================================

  # Test Helpers

  defp create_admin_user(context) do
    # Use the proper helper from ConnCase
    register_and_log_in_admin(context)
  end

  defp create_test_agency(_context) do
    # Use Ash.Seed for test fixtures
    agency =
      Ash.Seed.seed!(EhsEnforcement.Enforcement.Agency, %{
        code: :ea,
        name: "Environment Agency",
        base_url: "https://environment.data.gov.uk",
        enabled: true
      })

    %{agency: agency}
  end

  defp create_test_offender(_context) do
    # Use Ash.Seed for test fixtures
    offender =
      Ash.Seed.seed!(EhsEnforcement.Enforcement.Offender, %{
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
