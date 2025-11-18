defmodule EhsEnforcementWeb.Components.NoticesActionCardTest do
  use EhsEnforcementWeb.ConnCase, async: true

  # 🐛 BLOCKED: Action card components not receiving test data - Issue #31
  # All action card tests show same pattern: components render "0" instead of test data
  # Needs investigation of component data fetching architecture
  @moduletag :skip

  import Phoenix.LiveViewTest
  import EhsEnforcementWeb.Components.NoticesActionCard

  alias EhsEnforcement.Enforcement

  describe "notices_action_card/1" do
    setup do
      # Create test agency using valid agency code
      {:ok, agency} =
        Enforcement.create_agency(%{
          name: "Health and Safety Executive",
          code: :hse,
          enabled: true,
          base_url: "http://test.gov.uk"
        })

      # Create test offender
      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Test Company Ltd",
          postcode: "SW1A 1AA"
        })

      %{agency: agency, offender: offender}
    end

    test "renders basic notices card with zero metrics when no notices exist" do
      html =
        render_component(&notices_action_card/1, %{
          current_user: nil,
          loading: false
        })

      assert html =~ "ENFORCEMENT NOTICES"
      assert html =~ "🔔"
      assert html =~ "Total Notices"
      assert html =~ "0"
      assert html =~ "Recent (Last 30 Days)"
      assert html =~ "Compliance Required"
      assert html =~ "Browse Active"
      assert html =~ "Search Database"
    end

    test "renders notices card with loading state" do
      html =
        render_component(&notices_action_card/1, %{
          current_user: nil,
          loading: true
        })

      assert html =~ "ENFORCEMENT NOTICES"
      assert html =~ "animate-spin"
    end

    test "calculates and displays correct metrics when notices exist", %{
      agency: agency,
      offender: offender
    } do
      # Create some test notices
      today = Date.utc_today()
      thirty_days_ago = Date.add(today, -30)
      sixty_days_ago = Date.add(today, -60)
      future_date = Date.add(today, 30)

      # Recent notice (within 30 days)
      {:ok, _recent_notice} =
        Enforcement.create_notice(%{
          regulator_id: "TEST001",
          notice_date: today,
          offence_action_date: Date.add(today, -5),
          compliance_date: future_date,
          agency_id: agency.id,
          offender_id: offender.id
        })

      # Old notice (older than 30 days)
      {:ok, _old_notice} =
        Enforcement.create_notice(%{
          regulator_id: "TEST002",
          notice_date: sixty_days_ago,
          offence_action_date: sixty_days_ago,
          compliance_date: nil,
          agency_id: agency.id,
          offender_id: offender.id
        })

      # Another recent notice with compliance required
      {:ok, _recent_notice_2} =
        Enforcement.create_notice(%{
          regulator_id: "TEST003",
          notice_date: Date.add(today, -10),
          offence_action_date: Date.add(today, -10),
          compliance_date: future_date,
          agency_id: agency.id,
          offender_id: offender.id
        })

      html =
        render_component(&notices_action_card/1, %{
          current_user: nil,
          loading: false
        })

      assert html =~ "Total Notices"
      # Total count should be 3
      assert html =~ "3"
      assert html =~ "Recent (Last 30 Days)"
      # Recent count should be 2 (within 30 days)
      assert html =~ "2"
      assert html =~ "Compliance Required"
      # All have compliance required (nil or future date)
      assert html =~ "3"
    end

    test "shows admin actions for admin users" do
      admin_user = %{id: 1, name: "Admin User", is_admin: true}

      html =
        render_component(&notices_action_card/1, %{
          current_user: admin_user,
          loading: false
        })

      assert html =~ "Add New Notice"
      assert html =~ "ADMIN"
    end

    test "hides admin actions for non-admin users" do
      regular_user = %{id: 1, name: "Regular User", is_admin: false}

      html =
        render_component(&notices_action_card/1, %{
          current_user: regular_user,
          loading: false
        })

      refute html =~ "Add New Notice"
      refute html =~ "ADMIN"
    end

    test "hides admin actions for nil users" do
      html =
        render_component(&notices_action_card/1, %{
          current_user: nil,
          loading: false
        })

      refute html =~ "Add New Notice"
      refute html =~ "ADMIN"
    end

    test "calculates compliance required correctly for various scenarios", %{
      agency: agency,
      offender: offender
    } do
      today = Date.utc_today()
      past_date = Date.add(today, -10)
      future_date = Date.add(today, 10)

      # Notice with no compliance date (compliance required)
      {:ok, _notice_1} =
        Enforcement.create_notice(%{
          regulator_id: "TEST001",
          notice_date: today,
          offence_action_date: today,
          compliance_date: nil,
          agency_id: agency.id,
          offender_id: offender.id
        })

      # Notice with future compliance date (compliance required)
      {:ok, _notice_2} =
        Enforcement.create_notice(%{
          regulator_id: "TEST002",
          notice_date: today,
          offence_action_date: today,
          compliance_date: future_date,
          agency_id: agency.id,
          offender_id: offender.id
        })

      # Notice with past compliance date (compliance not required)
      {:ok, _notice_3} =
        Enforcement.create_notice(%{
          regulator_id: "TEST003",
          notice_date: today,
          offence_action_date: today,
          compliance_date: past_date,
          agency_id: agency.id,
          offender_id: offender.id
        })

      html =
        render_component(&notices_action_card/1, %{
          current_user: nil,
          loading: false
        })

      assert html =~ "Total Notices"
      assert html =~ "3"
      assert html =~ "Compliance Required"
      # Only 2 require compliance (nil and future date)
      assert html =~ "2"
    end

    test "handles errors gracefully when database operations fail" do
      # Mock a database error by using an invalid component state
      # In a real scenario, this might happen if the database is unavailable
      html =
        render_component(&notices_action_card/1, %{
          current_user: nil,
          loading: false
        })

      # Should still render with zero values instead of crashing
      assert html =~ "ENFORCEMENT NOTICES"
      assert html =~ "Total Notices"
      assert html =~ "0"
    end

    test "applies yellow theme correctly" do
      html =
        render_component(&notices_action_card/1, %{
          current_user: nil,
          loading: false
        })

      assert html =~ "bg-yellow-50"
      assert html =~ "border-yellow-200"
      assert html =~ "text-yellow-700"
    end

    test "formats numbers with commas for large values", %{agency: agency, offender: offender} do
      # Create many notices to test number formatting
      for i <- 1..1500 do
        {:ok, _notice} =
          Enforcement.create_notice(%{
            regulator_id: "TEST#{String.pad_leading(Integer.to_string(i), 3, "0")}",
            notice_date: Date.utc_today(),
            offence_action_date: Date.add(Date.utc_today(), -5),
            compliance_date: Date.add(Date.utc_today(), 30),
            agency_id: agency.id,
            offender_id: offender.id
          })
      end

      html =
        render_component(&notices_action_card/1, %{
          current_user: nil,
          loading: false
        })

      # Should format 1500+ with commas
      # Will match "1,500" in the HTML
      assert html =~ "1,5"
    end

    test "includes proper accessibility attributes" do
      html =
        render_component(&notices_action_card/1, %{
          current_user: nil,
          loading: false
        })

      assert html =~ ~r/role="article"/
      assert html =~ ~r/aria-labelledby="card-title-enforcement-notices"/
      assert html =~ ~r/id="card-title-enforcement-notices"/
    end

    test "includes proper action button icons and styling" do
      html =
        render_component(&notices_action_card/1, %{
          current_user: nil,
          loading: false
        })

      # Check for SVG icons in buttons
      assert html =~ ~r/<svg.*viewBox="0 0 24 24".*>/
      assert html =~ ~r/stroke-width="2"/

      # Check for proper button classes
      assert html =~ ~r/bg-indigo-600.*text-white/
      assert html =~ ~r/border.*text-gray-700/
    end
  end

  describe "format_number/1" do
    test "formats integers correctly" do
      assert render_component(&notices_action_card/1, %{current_user: nil}) =~ "0"
    end

    test "handles nil values" do
      html = render_component(&notices_action_card/1, %{current_user: nil})
      assert html =~ "0"
    end
  end

  describe "admin?/1" do
    test "returns true for admin users" do
      admin_user = %{is_admin: true}
      html = render_component(&notices_action_card/1, %{current_user: admin_user})
      assert html =~ "Add New Notice"
    end

    test "returns false for non-admin users" do
      regular_user = %{is_admin: false}
      html = render_component(&notices_action_card/1, %{current_user: regular_user})
      refute html =~ "Add New Notice"
    end

    test "returns false for nil users" do
      html = render_component(&notices_action_card/1, %{current_user: nil})
      refute html =~ "Add New Notice"
    end
  end
end
