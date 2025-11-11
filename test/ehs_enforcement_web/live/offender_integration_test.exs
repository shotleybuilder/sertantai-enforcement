defmodule EhsEnforcementWeb.OffenderIntegrationTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Repo

  require Ash.Query
  import Ash.Expr

  describe "Offender Management Integration" do
    setup do
      # Create comprehensive test data for integration testing
      {:ok, hse_agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, ea_agency} =
        Enforcement.create_agency(%{
          code: :ea,
          name: "Environment Agency",
          enabled: true
        })

      # Create different types of offenders for comprehensive testing
      {:ok, repeat_offender} =
        Enforcement.create_offender(%{
          name: "Repeat Violations Manufacturing Ltd",
          local_authority: "Manchester City Council",
          postcode: "M1 1AA",
          industry: "Manufacturing",
          business_type: :limited_company,
          main_activity: "Heavy machinery manufacturing",
          total_cases: 12,
          total_notices: 18,
          total_fines: Decimal.new("750000"),
          first_seen_date: ~D[2018-03-15],
          last_seen_date: ~D[2024-02-10]
        })

      {:ok, escalating_offender} =
        Enforcement.create_offender(%{
          name: "Escalating Issues Corp",
          local_authority: "Birmingham City Council",
          postcode: "B2 2BB",
          industry: "Chemical Processing",
          business_type: :plc,
          total_cases: 6,
          total_notices: 8,
          total_fines: Decimal.new("425000"),
          first_seen_date: ~D[2020-06-20],
          last_seen_date: ~D[2024-01-25]
        })

      {:ok, multi_agency_offender} =
        Enforcement.create_offender(%{
          name: "Multi-Agency Violations Ltd",
          local_authority: "Leeds City Council",
          postcode: "LS3 3CC",
          industry: "Waste Management",
          business_type: :limited_company,
          total_cases: 8,
          total_notices: 10,
          total_fines: Decimal.new("320000"),
          first_seen_date: ~D[2019-11-10],
          last_seen_date: ~D[2023-12-15]
        })

      {:ok, new_offender} =
        Enforcement.create_offender(%{
          name: "New Violator Inc",
          local_authority: "Sheffield City Council",
          postcode: "S4 4DD",
          industry: "Construction",
          business_type: :limited_company,
          total_cases: 2,
          total_notices: 2,
          total_fines: Decimal.new("45000"),
          first_seen_date: ~D[2023-10-05],
          last_seen_date: ~D[2023-12-20]
        })

      # Create comprehensive enforcement history
      base_date = ~D[2024-01-15]

      # Repeat offender history (escalating pattern)
      enforcement_history = [
        # Recent major case
        %{
          regulator_id: "HSE-2024-001",
          agency_id: hse_agency.id,
          offender_id: repeat_offender.id,
          offence_action_date: base_date,
          offence_fine: Decimal.new("150000"),
          offence_breaches: "Health and Safety at Work Act 1974 - Multiple sections"
        },
        # Previous case with increasing fine
        %{
          regulator_id: "HSE-2023-089",
          agency_id: hse_agency.id,
          offender_id: repeat_offender.id,
          offence_action_date: Date.add(base_date, -120),
          offence_fine: Decimal.new("100000"),
          offence_breaches: "Management of Health and Safety at Work Regulations 1999"
        },
        # Multi-agency offender cases
        %{
          regulator_id: "HSE-2023-156",
          agency_id: hse_agency.id,
          offender_id: multi_agency_offender.id,
          offence_action_date: Date.add(base_date, -180),
          offence_fine: Decimal.new("75000"),
          offence_breaches: "Health and Safety at Work Act 1974 - Section 2(1)"
        },
        %{
          regulator_id: "EA-2023-245",
          agency_id: ea_agency.id,
          offender_id: multi_agency_offender.id,
          offence_action_date: Date.add(base_date, -150),
          offence_fine: Decimal.new("85000"),
          offence_breaches: "Environmental Protection Act 1990 - Section 33"
        }
      ]

      # Create all cases
      cases =
        for case_attrs <- enforcement_history do
          {:ok, case} =
            Enforcement.create_case(Map.put(case_attrs, :last_synced_at, DateTime.utc_now()))

          case
        end

      # Create notices for pattern analysis
      notices = [
        # Improvement notices leading to major case
        %{
          regulator_id: "HSE-N-2023-001",
          agency_id: hse_agency.id,
          offender_id: repeat_offender.id,
          offence_action_type: "improvement_notice",
          notice_date: Date.add(base_date, -60),
          operative_date: Date.add(base_date, -53),
          compliance_date: Date.add(base_date, -30),
          notice_body: "Improve machinery safety procedures - final warning"
        },
        # Prohibition notice for serious violation
        %{
          regulator_id: "HSE-N-2024-002",
          agency_id: hse_agency.id,
          offender_id: escalating_offender.id,
          offence_action_type: "prohibition_notice",
          notice_date: Date.add(base_date, -10),
          operative_date: Date.add(base_date, -10),
          compliance_date: Date.add(base_date, 20),
          notice_body: "Immediate cessation of operations - critical safety violation"
        }
      ]

      created_notices =
        for notice_attrs <- notices do
          {:ok, notice} = Enforcement.create_notice(notice_attrs)
          notice
        end

      %{
        hse_agency: hse_agency,
        ea_agency: ea_agency,
        repeat_offender: repeat_offender,
        escalating_offender: escalating_offender,
        multi_agency_offender: multi_agency_offender,
        new_offender: new_offender,
        cases: cases,
        notices: created_notices
      }
    end

    test "complete workflow: index to detail view navigation", %{
      conn: conn,
      repeat_offender: repeat_offender
    } do
      # Start at offender index
      {:ok, index_view, index_html} = live(conn, "/offenders")

      # Verify repeat offender is shown with indicators
      assert index_html =~ repeat_offender.name
      assert index_html =~ "High Risk"
      assert index_html =~ "Repeat Offender"
      assert index_html =~ "12 Cases"
      assert index_html =~ "£750,000"

      # Navigate to detail view
      {:ok, detail_view, detail_html} =
        index_view
        |> element("[data-offender-id='#{repeat_offender.id}'] a")
        |> render_click()
        |> follow_redirect(conn, "/offenders/#{repeat_offender.id}")

      # Verify comprehensive detail view
      assert detail_html =~ repeat_offender.name
      assert detail_html =~ "Enforcement Timeline"
      assert detail_html =~ "Risk Assessment"
      # Risk indicator
      assert detail_html =~ "High Risk"

      # Verify timeline shows recent enforcement
      assert detail_html =~ "HSE-2024-001"
      assert detail_html =~ "£150,000"

      # Navigate back to index
      {:ok, back_view, _back_html} =
        detail_view
        |> element("a[href='/offenders']")
        |> render_click()
        |> follow_redirect(conn, "/offenders")

      assert back_view.module == EhsEnforcementWeb.OffenderLive.Index
    end

    test "repeat offender identification algorithm", %{
      conn: conn,
      repeat_offender: repeat_offender,
      new_offender: new_offender
    } do
      {:ok, view, html} = live(conn, "/offenders")

      # Should identify repeat offender (12 cases, 6+ year history)
      assert has_element?(
               view,
               "[data-offender-id='#{repeat_offender.id}'][data-repeat-offender='true']"
             )

      assert html =~ "Repeat Offender"

      # Should NOT mark new offender as repeat (2 cases, recent history)
      assert has_element?(
               view,
               "[data-offender-id='#{new_offender.id}'][data-repeat-offender='false']"
             )

      refute html =~ ~r/#{Regex.escape(new_offender.name)}.*Repeat Offender/
    end

    test "risk assessment calculation across multiple factors", %{
      conn: conn,
      repeat_offender: repeat_offender,
      escalating_offender: escalating_offender,
      new_offender: new_offender
    } do
      {:ok, _view, html} = live(conn, "/offenders")

      # High risk: 12 cases, £750k fines, 6-year history
      assert has_element?(
               view,
               "[data-offender-id='#{repeat_offender.id}'][data-risk-level='high']"
             )

      # Medium-high risk: 6 cases, £425k fines, escalating pattern
      assert has_element?(
               view,
               "[data-offender-id='#{escalating_offender.id}'][data-risk-level='medium-high']"
             ) ||
               has_element?(
                 view,
                 "[data-offender-id='#{escalating_offender.id}'][data-risk-level='high']"
               )

      # Low risk: 2 cases, £45k fines, recent first offense
      assert has_element?(view, "[data-offender-id='#{new_offender.id}'][data-risk-level='low']")
    end

    test "multi-agency enforcement pattern detection", %{
      conn: conn,
      multi_agency_offender: multi_agency_offender
    } do
      {:ok, view, html} = live(conn, "/offenders/#{multi_agency_offender.id}")

      # Should identify multi-agency involvement
      assert html =~ "Multiple agencies involved"
      assert html =~ "Health and Safety Executive"
      assert html =~ "Environment Agency"

      # Should show agency breakdown
      assert html =~ "Agency Breakdown"
      assert has_element?(view, "[data-agency='hse']")
      assert has_element?(view, "[data-agency='ea']")

      # Should indicate cross-agency coordination concern
      assert html =~ "Cross-agency violations" || html =~ "Multiple regulatory concerns"
    end

    test "enforcement escalation pattern analysis", %{
      conn: conn,
      repeat_offender: repeat_offender
    } do
      {:ok, _view, html} = live(conn, "/offenders/#{repeat_offender.id}")

      # Should detect escalating fine pattern
      assert html =~ "Escalating fines" || html =~ "Increasing penalties"
      assert html =~ "Enforcement Pattern"

      # Should show progression: Notice → Fine increase → Major penalty
      # Previous case
      assert html =~ "£100,000"
      # Latest case showing escalation
      assert html =~ "£150,000"

      # Should highlight pattern as risk factor
      assert html =~ "Risk Factors"
      assert html =~ "Escalating enforcement pattern"
    end

    test "industry and geographic analysis integration", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/offenders")

      # Should show industry breakdown
      assert html =~ "Industry Analysis"
      # Most problematic
      assert html =~ "Manufacturing"
      assert html =~ "Chemical Processing"
      assert html =~ "Waste Management"

      # Should show geographic concentration
      assert html =~ "Geographic Analysis" || html =~ "Regional Breakdown"
      # High concentration area
      assert html =~ "Manchester"
      assert html =~ "Birmingham"

      # Should identify hotspots
      assert html =~ "High-risk areas" || html =~ "Enforcement hotspots"
    end

    test "comprehensive export functionality", %{conn: conn, repeat_offender: repeat_offender} do
      # Test index-level export
      {:ok, index_view, _html} = live(conn, "/offenders")

      csv_response =
        index_view
        |> element("[data-role='export-csv']")
        |> render_click()

      # Should contain comprehensive offender data
      assert csv_response =~
               "Name,Industry,Local Authority,Total Cases,Total Notices,Total Fines,Risk Level,First Seen,Last Activity"

      assert csv_response =~ repeat_offender.name
      assert csv_response =~ "Manufacturing"
      # Fine amount without formatting
      assert csv_response =~ "750000"

      # Test detail-level export
      {:ok, detail_view, _html} = live(conn, "/offenders/#{repeat_offender.id}")

      pdf_response =
        detail_view
        |> element("[data-role='export-pdf']")
        |> render_click()

      # Should trigger PDF generation
      assert pdf_response =~ "Generating report" || pdf_response =~ "Download ready"
    end

    test "real-time updates across offender interfaces", %{
      conn: conn,
      repeat_offender: repeat_offender,
      hse_agency: hse_agency
    } do
      # Start views for index and detail
      {:ok, index_view, _index_html} = live(conn, "/offenders")
      {:ok, detail_view, _detail_html} = live(conn, "/offenders/#{repeat_offender.id}")

      # Simulate new case creation
      {:ok, new_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-2024-LIVE",
          agency_id: hse_agency.id,
          offender_id: repeat_offender.id,
          offence_action_date: ~D[2024-02-15],
          offence_fine: Decimal.new("200000"),
          offence_breaches: "Critical safety violation - new case",
          last_synced_at: DateTime.utc_now()
        })

      # Send PubSub updates to both views
      send(index_view.pid, {:case_created, new_case})
      send(detail_view.pid, {:case_created, new_case})

      # Index should update statistics
      index_html = render(index_view)
      # Updated from 12
      assert index_html =~ "13 Cases"
      # Updated total fines
      assert index_html =~ "£950,000"

      # Detail should update timeline
      detail_html = render(detail_view)
      assert detail_html =~ "HSE-2024-LIVE"
      assert detail_html =~ "Critical safety violation - new case"
      assert detail_html =~ "£200,000"
    end

    test "advanced filtering and search integration", %{
      conn: conn,
      repeat_offender: repeat_offender,
      multi_agency_offender: multi_agency_offender
    } do
      {:ok, _view, html} = live(conn, "/offenders")

      # Test complex filter combination: High-risk Manufacturing in Manchester
      view
      |> form("#offender-filters", %{
        filters: %{
          industry: "Manufacturing",
          local_authority: "Manchester",
          risk_level: "high",
          repeat_only: true
        }
      })
      |> render_change()

      filtered_html = render(view)

      # Should show repeat offender (matches all criteria)
      assert filtered_html =~ repeat_offender.name

      # Should not show multi-agency offender (different industry/location)
      refute filtered_html =~ multi_agency_offender.name

      # Test search combined with filters
      view
      |> form("#offender-search", %{search: %{query: "Repeat"}})
      |> render_change()

      search_html = render(view)
      # Matches "Repeat Violations Manufacturing"
      assert search_html =~ repeat_offender.name
    end

    test "performance with large dataset pagination", %{conn: conn, hse_agency: hse_agency} do
      # Create many additional offenders to test pagination
      additional_offenders =
        for i <- 1..50 do
          {:ok, offender} =
            Enforcement.create_offender(%{
              name: "Performance Test Company #{i} Ltd",
              local_authority: "Test Council #{rem(i, 10)}",
              industry:
                ["Manufacturing", "Chemical", "Construction", "Retail"] |> Enum.at(rem(i, 4)),
              total_cases: rem(i, 10) + 1,
              total_notices: rem(i, 8) + 1,
              total_fines: Decimal.new("#{i * 5000 + 10000}")
            })

          offender
        end

      {:ok, _view, html} = live(conn, "/offenders")

      # Should implement pagination
      assert has_element?(view, ".pagination") || has_element?(view, "[data-role='load-more']")

      # Should limit initial load (e.g., 20 per page)
      offender_rows = view |> render() |> Floki.find("[data-role='offender-row']")
      assert length(offender_rows) <= 20

      # Test pagination navigation
      if has_element?(view, "[data-role='next-page']") do
        view
        |> element("[data-role='next-page']")
        |> render_click()

        # Should load next page
        page_2_html = render(view)
        assert page_2_html =~ "Page 2" || page_2_html =~ "21-40"
      end
    end

    test "accessibility compliance across offender interfaces", %{
      conn: conn,
      repeat_offender: repeat_offender
    } do
      # Test index accessibility
      {:ok, index_view, index_html} = live(conn, "/offenders")

      # Should have proper ARIA structure
      assert index_html =~ ~r/role="main"/
      assert index_html =~ ~r/aria-label="[^"]*offender[^"]*"/
      assert has_element?(index_view, "table[role='table']")
      assert has_element?(index_view, "th[scope='col']")

      # Test detail view accessibility
      {:ok, detail_view, detail_html} = live(conn, "/offenders/#{repeat_offender.id}")

      # Should have proper heading hierarchy
      assert detail_html =~ ~r/<h1[^>]*>/
      assert detail_html =~ ~r/<h2[^>]*>/

      # Timeline should be accessible
      # Timeline as list
      assert has_element?(detail_view, "[role='list']")
      # Timeline items
      assert has_element?(detail_view, "[role='listitem']")

      # Should support keyboard navigation
      assert has_element?(detail_view, "[tabindex='0']")
    end

    test "error handling and recovery across workflow", %{conn: conn} do
      # Test handling non-existent offender
      non_existent_id = Ash.UUID.generate()
      {:ok, view, html} = live(conn, "/offenders/#{non_existent_id}")

      assert html =~ "Offender not found"
      # Back navigation
      assert has_element?(view, "a[href='/offenders']")

      # Test invalid filter recovery
      {:ok, index_view, _html} = live(conn, "/offenders")

      # Send invalid filter data
      index_view
      |> form("#offender-filters", %{filters: %{invalid_field: "invalid_value"}})
      |> render_change()

      # Should not crash and should provide feedback
      # Page still functional
      assert render(index_view) =~ "Offender Management"
    end

    test "cross-component integration and state management", %{
      conn: conn,
      repeat_offender: repeat_offender
    } do
      {:ok, _view, html} = live(conn, "/offenders/#{repeat_offender.id}")

      # Test timeline filtering affects summary statistics
      view
      |> form("#timeline-filters", %{filter_type: "cases"})
      |> render_change()

      filtered_html = render(view)

      # Should show only cases in timeline
      # Case
      assert filtered_html =~ "HSE-2024-001"
      # Notice
      refute filtered_html =~ "HSE-N-2023-001"

      # Summary should reflect filtered view
      assert filtered_html =~ "Showing cases only"

      # Test agency filter integration
      view
      |> form("#timeline-filters", %{agency: "hse"})
      |> render_change()

      agency_filtered_html = render(view)
      assert agency_filtered_html =~ "Health and Safety Executive"
      assert agency_filtered_html =~ "HSE enforcement actions"
    end
  end

  describe "Offender Export Integration" do
    setup do
      {:ok, hse_agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Export Test Corp",
          local_authority: "Test Council",
          industry: "Manufacturing",
          total_cases: 3,
          total_notices: 4,
          total_fines: Decimal.new("125000")
        })

      %{hse_agency: hse_agency, offender: offender}
    end

    test "CSV export contains complete offender data", %{conn: conn, offender: offender} do
      {:ok, view, _html} = live(conn, "/offenders")

      csv_content =
        view
        |> element("[data-role='export-csv']")
        |> render_click()

      # Should contain all expected columns
      expected_headers = [
        "Name",
        "Industry",
        "Local Authority",
        "Postcode",
        "Business Type",
        "Total Cases",
        "Total Notices",
        "Total Fines",
        "Risk Level",
        "First Seen",
        "Last Activity",
        "Main Activity"
      ]

      for header <- expected_headers do
        assert csv_content =~ header
      end

      # Should contain offender data
      assert csv_content =~ offender.name
      assert csv_content =~ "Manufacturing"
      assert csv_content =~ "Test Council"
      # Unformatted fine amount
      assert csv_content =~ "125000"
    end

    test "PDF export generates comprehensive report", %{conn: conn, offender: offender} do
      {:ok, view, _html} = live(conn, "/offenders/#{offender.id}")

      response =
        view
        |> element("[data-role='export-pdf']")
        |> render_click()

      # Should initiate PDF generation
      # If direct download
      assert response =~ "Generating report" ||
               response =~ "Download ready" ||
               response =~ "application/pdf"
    end

    test "export respects current filters", %{conn: conn} do
      # Create additional offender in different industry
      {:ok, _other_offender} =
        Enforcement.create_offender(%{
          name: "Other Industry Corp",
          industry: "Retail",
          total_cases: 1,
          total_notices: 1,
          total_fines: Decimal.new("15000")
        })

      {:ok, view, _html} = live(conn, "/offenders")

      # Apply filter for Manufacturing only
      view
      |> form("#offender-filters", %{filters: %{industry: "Manufacturing"}})
      |> render_change()

      # Export should respect filter
      csv_content =
        view
        |> element("[data-role='export-csv']")
        |> render_click()

      # Should only contain Manufacturing offenders
      # Manufacturing
      assert csv_content =~ "Export Test Corp"
      # Retail (filtered out)
      refute csv_content =~ "Other Industry Corp"
    end
  end
end
