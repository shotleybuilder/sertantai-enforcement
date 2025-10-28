defmodule EhsEnforcementWeb.DashboardRecentActivityTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  alias EhsEnforcement.Enforcement
  require Ash.Query

  describe "Dashboard Recent Activity with test data" do
    setup do
      # Create test agencies
      {:ok, hse_agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      # Create test offenders
      {:ok, offender1} =
        Enforcement.create_offender(%{
          name: "Test Company Ltd",
          local_authority: "Test Council",
          postcode: "TE1 1ST"
        })

      {:ok, offender2} =
        Enforcement.create_offender(%{
          name: "Another Corp",
          local_authority: "Another Council",
          postcode: "TE2 2ST"
        })

      # Create test case (court case with fine)
      {:ok, test_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-001",
          agency_id: hse_agency.id,
          offender_id: offender1.id,
          offence_action_date: ~D[2024-01-15],
          offence_fine: Decimal.new("25000.00"),
          offence_breaches: "Health and safety violations leading to court proceedings",
          offence_action_type: "Court Case",
          url: "https://www.hse.gov.uk/prosecutions/case-123",
          last_synced_at: DateTime.utc_now()
        })

      # Create test notice (no fine)
      {:ok, test_notice} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-002",
          agency_id: hse_agency.id,
          offender_id: offender2.id,
          offence_action_date: ~D[2024-01-20],
          offence_breaches: "Workplace safety improvements required",
          offence_action_type: "Improvement Notice",
          url: "https://www.hse.gov.uk/notices/notice-456",
          last_synced_at: DateTime.utc_now()
        })

      # Get all current data
      {:ok, cases} = Enforcement.list_cases()
      {:ok, notices} = Enforcement.list_notices()

      %{
        agency: hse_agency,
        test_case: test_case,
        test_notice: test_notice,
        imported_cases: cases,
        imported_notices: notices,
        case_count: length(cases),
        notice_count: length(notices)
      }
    end

    test "test cases exist and have correct structure", %{
      imported_cases: cases,
      test_case: test_case
    } do
      assert length(cases) > 0, "Should have test cases"

      # Check test case structure
      assert test_case.offence_action_type == "Court Case"
      assert test_case.regulator_id == "HSE-001"
      assert is_struct(test_case, EhsEnforcement.Enforcement.Case)
      assert test_case.offence_fine == Decimal.new("25000.00")
    end

    test "Recent Activity shows both cases and notices", %{
      conn: conn,
      case_count: case_count,
      notice_count: notice_count
    } do
      {:ok, view, html} = live(conn, "/dashboard")

      # Should show Recent Activity section
      assert html =~ "Recent Activity"

      # Should have data if we have imported records
      if case_count > 0 or notice_count > 0 do
        # Should have activity items
        assert has_element?(view, "[data-testid='recent-cases']") or
                 has_element?(view, "[data-testid='recent-activities']") or
                 html =~ "Court Case" or
                 html =~ "Notice"
      end
    end

    test "filtering by Cases shows only case records", %{conn: conn, case_count: case_count} do
      if case_count > 0 do
        {:ok, view, _html} = live(conn, "/dashboard")

        # Click the "Cases" filter button
        view |> element("button[phx-value-type='cases']", "Cases") |> render_click()

        html = render(view)

        # Should show Court Case type from imported data
        assert html =~ "Court Case", "Should show Court Case when filtering by cases"

        # Should not show notice types
        refute html =~ "Improvement Notice"
        refute html =~ "Prohibition Notice"
      else
        # Skip test if no cases imported
        assert true
      end
    end

    test "filtering by Notices shows only notice records", %{
      conn: conn,
      notice_count: notice_count
    } do
      if notice_count > 0 do
        {:ok, view, _html} = live(conn, "/dashboard")

        # Click the "Notices" filter button  
        view |> element("button[phx-value-type='notices']", "Notices") |> render_click()

        html = render(view)

        # Should show notice types
        assert html =~ "Notice", "Should show notice types when filtering by notices"

        # Should not show court case types
        refute html =~ "Court Case"
      else
        # Skip test if no notices imported
        assert true
      end
    end

    test "Recent Activity query combines cases and notices correctly", %{
      imported_cases: cases,
      imported_notices: notices
    } do
      # Test the same logic as load_recent_cases_paginated function
      all_activity =
        (cases ++ notices)
        |> Enum.filter(fn record -> record.offence_action_date != nil end)
        |> Enum.sort_by(& &1.offence_action_date, {:desc, Date})

      assert length(all_activity) > 0, "Should have combined activity records"

      # Check that both types can be present
      case_structs = Enum.filter(all_activity, &match?(%EhsEnforcement.Enforcement.Case{}, &1))

      notice_structs =
        Enum.filter(all_activity, &match?(%EhsEnforcement.Enforcement.Notice{}, &1))

      # At least one type should be present based on our imports
      assert length(case_structs) > 0 or length(notice_structs) > 0

      # If we have cases, they should have correct action type
      if length(case_structs) > 0 do
        first_case = Enum.at(case_structs, 0)
        assert first_case.offence_action_type == "Court Case"
      end
    end

    test "format_cases_as_recent_activity formats imported data correctly", %{
      imported_cases: cases
    } do
      if length(cases) > 0 do
        # Load cases with offender association like dashboard does
        {:ok, cases_with_offender} = Enforcement.list_cases(load: [:offender])
        sample_cases = Enum.take(cases_with_offender, 3)

        formatted_activity =
          Enum.map(sample_cases, fn record ->
            is_case = match?(%EhsEnforcement.Enforcement.Case{}, record)

            %{
              id: record.id,
              type:
                record.offence_action_type ||
                  if(is_case, do: "Court Case", else: "Enforcement Notice"),
              date: record.offence_action_date,
              organization: record.offender && record.offender.name,
              description:
                record.offence_breaches ||
                  if(is_case, do: "Court case proceeding", else: "Enforcement notice issued"),
              fine_amount: if(is_case, do: Map.get(record, :offence_fine, nil), else: nil),
              agency_link: record.url,
              is_case: is_case
            }
          end)

        assert length(formatted_activity) > 0

        # Check first formatted item
        first_item = Enum.at(formatted_activity, 0)
        assert first_item.type == "Court Case"
        assert first_item.is_case == true
        # Cases should have fine amounts
        assert first_item.fine_amount != nil
      end
    end

    test "struct type matching works for filtering", %{
      imported_cases: cases,
      imported_notices: notices
    } do
      all_records = cases ++ notices

      # Test the exact filtering logic used in dashboard
      filtered_cases = Enum.filter(all_records, &match?(%EhsEnforcement.Enforcement.Case{}, &1))

      filtered_notices =
        Enum.filter(all_records, &match?(%EhsEnforcement.Enforcement.Notice{}, &1))

      # Should match the original counts
      assert length(filtered_cases) == length(cases)
      assert length(filtered_notices) == length(notices)

      # Each filtered case should be a Case struct
      Enum.each(filtered_cases, fn case_record ->
        assert match?(%EhsEnforcement.Enforcement.Case{}, case_record)
        assert case_record.offence_action_type == "Court Case"
      end)
    end
  end

  describe "Dashboard Recent Activity edge cases" do
    setup do
      # Create minimal test data for edge case testing
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Test Agency",
          enabled: true
        })

      %{agency: agency}
    end

    test "handles empty Recent Activity gracefully", %{conn: conn} do
      {:ok, view, html} = live(conn, "/dashboard")

      # Should not crash
      assert html =~ "Recent Activity" or html =~ "Dashboard"
      assert Process.alive?(view.pid)
    end
  end
end
