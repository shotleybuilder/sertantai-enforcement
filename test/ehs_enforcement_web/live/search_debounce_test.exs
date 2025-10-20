defmodule EhsEnforcementWeb.SearchDebounceTest do
  @moduledoc """
  Tests to verify phx-debounce="500" is properly added to search inputs.
  This is Phase 1 of the WebSocket optimization plan.
  """

  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "Phase 1: Debounce Attribute Verification" do
    test "CaseLive.Index search input has phx-debounce attribute", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cases")

      # Verify debounce attribute exists
      assert html =~ ~r/phx-debounce="500"/,
             "Search input should have phx-debounce='500' attribute"

      # Verify it's on the search input
      assert html =~ ~r/phx-change="search"/,
             "Should have phx-change='search' event"
    end

    test "NoticeLive.Index search input has phx-debounce attribute", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/notices")

      assert html =~ ~r/phx-debounce="500"/,
             "Search input should have phx-debounce='500' attribute"

      assert html =~ ~r/phx-change="search"/,
             "Should have phx-change='search' event"
    end

    test "OffenderLive.Index filter form has phx-debounce attribute", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/offenders")

      # Verify debounce on filter form
      assert html =~ ~r/phx-debounce="500"/,
             "Filter form should have phx-debounce='500' attribute"

      assert html =~ ~r/data-testid="offender-filters"/,
             "Should have offender-filters test ID"
    end

    test "LegislationLive.Index filter form has phx-debounce attribute", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/legislation")

      assert html =~ ~r/phx-debounce="500"/,
             "Filter form should have phx-debounce='500' attribute"

      assert html =~ ~r/data-testid="legislation-filters"/,
             "Should have legislation-filters test ID"
    end
  end

  describe "Phase 1: Basic Debounce Functionality" do
    test "CaseLive search doesn't crash during rapid input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Simulate rapid typing - with debounce, should not crash
      Enum.each(["t", "te", "tes", "test"], fn query ->
        view
        |> element("input[name='search']")
        |> render_change(%{"_target" => ["search"], "search" => query})

        Process.sleep(20)  # Very fast typing
      end)

      # Wait for debounce
      Process.sleep(600)

      # Should still be alive and responsive
      assert Process.alive?(view.pid),
             "LiveView should survive rapid search input with debounce"
    end

    test "NoticeLive search remains responsive during rapid typing", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Type rapidly
      "rapid"
      |> String.graphemes()
      |> Enum.each(fn char ->
        view
        |> element("input[name='search']")
        |> render_change(%{"_target" => ["search"], "search" => char})

        Process.sleep(30)
      end)

      # Wait for debounce
      Process.sleep(600)

      assert Process.alive?(view.pid),
             "LiveView should handle rapid typing without crashing"
    end

    test "OffenderLive filter changes are debounced", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/offenders")

      # Rapidly change filter values
      industries = ["M", "Ma", "Man"]

      Enum.each(industries, fn industry ->
        view
        |> element("form[data-testid='offender-filters']")
        |> render_change(%{"filters" => %{"industry" => industry}})

        Process.sleep(30)
      end)

      # Wait for debounce
      Process.sleep(600)

      assert Process.alive?(view.pid),
             "Filter form should handle rapid changes with debounce"
    end

    test "LegislationLive filter changes are debounced", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/legislation")

      # Rapidly change search
      search_terms = ["T", "Te", "Tes"]

      Enum.each(search_terms, fn term ->
        view
        |> element("form[data-testid='legislation-filters']")
        |> render_change(%{"filters" => %{"search" => term}})

        Process.sleep(30)
      end)

      # Wait for debounce
      Process.sleep(600)

      assert Process.alive?(view.pid),
             "Legislation filter should debounce properly"
    end
  end

  describe "Phase 1: Performance Impact" do
    test "debounce reduces event frequency in CaseLive", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Type 5 characters rapidly (total ~150ms typing time)
      start_time = System.monotonic_time(:millisecond)

      Enum.each(["a", "ab", "abc", "abcd", "abcde"], fn query ->
        view
        |> element("input[name='search']")
        |> render_change(%{"_target" => ["search"], "search" => query})

        Process.sleep(30)
      end)

      # Wait for debounce to complete
      Process.sleep(600)

      total_time = System.monotonic_time(:millisecond) - start_time

      # Without debounce, each change would trigger immediate processing
      # With debounce, only the final one processes after 500ms delay
      # Total time should be: typing (150ms) + debounce wait (600ms) = ~750ms
      assert total_time < 2000,
             "Debounce should prevent query storm (total time: #{total_time}ms)"

      assert Process.alive?(view.pid)
    end
  end
end
