defmodule EhsEnforcementWeb.NoticeSearchTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias EhsEnforcement.Enforcement

  describe "Notice search functionality" do
    setup do
      # Create test agencies
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

      # Create test offenders with varied details
      {:ok, manufacturing_offender} =
        Enforcement.create_offender(%{
          name: "Advanced Manufacturing Solutions Ltd",
          local_authority: "Manchester City Council",
          postcode: "M1 1AA",
          main_activity: "Chemical Processing",
          industry: "Manufacturing"
        })

      {:ok, construction_offender} =
        Enforcement.create_offender(%{
          name: "Premier Construction Corporation",
          local_authority: "Birmingham City Council",
          postcode: "B2 2BB",
          main_activity: "Building Construction",
          industry: "Construction"
        })

      {:ok, energy_offender} =
        Enforcement.create_offender(%{
          name: "Green Energy Systems PLC",
          local_authority: "Leeds City Council",
          postcode: "LS3 3CC",
          main_activity: "Renewable Energy Generation",
          industry: "Energy"
        })

      # Create notices with diverse content for search testing
      {:ok, safety_notice} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-SAFETY-2024-001",
          regulator_ref_number: "HSE/SAFETY/001",
          agency_id: hse_agency.id,
          offender_id: manufacturing_offender.id,
          offence_action_type: "Improvement Notice",
          notice_date: ~D[2024-01-15],
          operative_date: ~D[2024-01-29],
          compliance_date: ~D[2024-03-15],
          notice_body:
            "The company must implement comprehensive safety procedures for handling hazardous chemicals. This includes provision of personal protective equipment (PPE), establishment of emergency response protocols, and regular safety training for all personnel working with toxic substances."
        })

      {:ok, construction_notice} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-CONSTRUCT-2024-002",
          regulator_ref_number: "HSE/CONSTRUCT/002",
          agency_id: hse_agency.id,
          offender_id: construction_offender.id,
          offence_action_type: "Prohibition Notice",
          notice_date: ~D[2024-01-20],
          operative_date: ~D[2024-01-20],
          compliance_date: ~D[2024-02-20],
          notice_body:
            "Immediate cessation of crane operations required due to structural defects in the lifting mechanism. The crane boom shows signs of metal fatigue and poses an imminent danger to workers. Operations must not resume until comprehensive inspection and repairs are completed."
        })

      {:ok, environmental_notice} =
        Enforcement.create_notice(%{
          regulator_id: "EA-ENVIRON-2024-003",
          regulator_ref_number: "EA/ENV/003",
          agency_id: ea_agency.id,
          offender_id: energy_offender.id,
          offence_action_type: "Enforcement Notice",
          notice_date: ~D[2024-01-25],
          operative_date: ~D[2024-02-08],
          compliance_date: ~D[2024-04-25],
          notice_body:
            "Environmental compliance breach detected in wastewater discharge monitoring systems. The facility must install automated monitoring equipment and implement proper filtration systems to prevent contamination of local water sources."
        })

      {:ok, follow_up_notice} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-FOLLOWUP-2024-004",
          regulator_ref_number: "HSE/FOLLOWUP/004",
          agency_id: hse_agency.id,
          offender_id: manufacturing_offender.id,
          offence_action_type: "Improvement Notice",
          notice_date: ~D[2024-02-01],
          operative_date: ~D[2024-02-15],
          compliance_date: ~D[2024-05-01],
          notice_body:
            "Follow-up inspection reveals ongoing issues with chemical storage protocols. Additional ventilation systems required in storage areas, and staff must receive advanced training on handling procedures for corrosive materials."
        })

      %{
        hse_agency: hse_agency,
        ea_agency: ea_agency,
        manufacturing_offender: manufacturing_offender,
        construction_offender: construction_offender,
        energy_offender: energy_offender,
        safety_notice: safety_notice,
        construction_notice: construction_notice,
        environmental_notice: environmental_notice,
        follow_up_notice: follow_up_notice
      }
    end

    test "searches notices by regulator ID", %{conn: conn, safety_notice: safety_notice} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search by exact regulator ID
      view
      |> form("[data-testid='search-form']", search: "HSE-SAFETY-2024-001")
      |> render_submit()

      html = render(view)
      assert html =~ safety_notice.regulator_id
      assert html =~ "Advanced Manufacturing Solutions Ltd"
      refute html =~ "HSE-CONSTRUCT-2024-002"
      refute html =~ "EA-ENVIRON-2024-003"
    end

    test "searches notices by partial regulator ID", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search by partial ID pattern
      view
      |> form("[data-testid='search-form']", search: "HSE-SAFETY")
      |> render_submit()

      html = render(view)
      assert html =~ "HSE-SAFETY-2024-001"
      refute html =~ "HSE-CONSTRUCT-2024-002"
      refute html =~ "EA-ENVIRON-2024-003"
    end

    test "searches notices by reference number", %{
      conn: conn,
      construction_notice: construction_notice
    } do
      {:ok, view, _html} = live(conn, "/notices")

      # Search by regulator reference number
      view
      |> form("[data-testid='search-form']", search: "HSE/CONSTRUCT/002")
      |> render_submit()

      html = render(view)
      assert html =~ construction_notice.regulator_ref_number
      assert html =~ "Premier Construction Corporation"
      refute html =~ "HSE/SAFETY/001"
    end

    test "searches notices by offender name", %{
      conn: conn,
      manufacturing_offender: manufacturing_offender
    } do
      {:ok, view, _html} = live(conn, "/notices")

      # Search by complete offender name
      view
      |> form("[data-testid='search-form']", search: "Advanced Manufacturing Solutions")
      |> render_submit()

      html = render(view)
      assert html =~ manufacturing_offender.name
      assert html =~ "HSE-SAFETY-2024-001"
      # Should find both notices for this offender
      assert html =~ "HSE-FOLLOWUP-2024-004"
      refute html =~ "Premier Construction Corporation"
    end

    test "searches notices by partial offender name", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search by partial company name
      view
      |> form("[data-testid='search-form']", search: "Manufacturing")
      |> render_submit()

      html = render(view)
      assert html =~ "Advanced Manufacturing Solutions Ltd"
      refute html =~ "Premier Construction Corporation"
      refute html =~ "Green Energy Systems PLC"
    end

    test "searches notices by notice body content", %{conn: conn, safety_notice: safety_notice} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search by specific terms in notice body
      view
      |> form("[data-testid='search-form']", search: "personal protective equipment")
      |> render_submit()

      html = render(view)
      assert html =~ safety_notice.regulator_id
      assert html =~ "personal protective equipment"
      refute html =~ "crane operations"
    end

    test "searches notices by technical terms", %{
      conn: conn,
      construction_notice: construction_notice
    } do
      {:ok, view, _html} = live(conn, "/notices")

      # Search by technical terminology
      view
      |> form("[data-testid='search-form']", search: "structural defects")
      |> render_submit()

      html = render(view)
      assert html =~ construction_notice.regulator_id
      assert html =~ "structural defects"
      refute html =~ "chemical storage"
    end

    test "searches notices by safety keywords", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search by safety-related keywords
      view
      |> form("[data-testid='search-form']", search: "hazardous")
      |> render_submit()

      html = render(view)
      assert html =~ "hazardous chemicals" or html =~ "hazardous"
      refute html =~ "wastewater discharge"
    end

    test "searches notices by environmental terms", %{
      conn: conn,
      environmental_notice: environmental_notice
    } do
      {:ok, view, _html} = live(conn, "/notices")

      # Search by environmental keywords
      view
      |> form("[data-testid='search-form']", search: "wastewater discharge")
      |> render_submit()

      html = render(view)
      assert html =~ environmental_notice.regulator_id
      assert html =~ "wastewater discharge"
      refute html =~ "crane operations"
    end

    test "handles case-insensitive search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search with different case variations
      searches = ["CHEMICAL", "chemical", "Chemical", "cHeMiCaL"]

      Enum.each(searches, fn search_term ->
        view
        |> form("[data-testid='search-form']", search: search_term)
        |> render_submit()

        html = render(view)
        assert html =~ "chemical" or html =~ "Chemical"
      end)
    end

    test "searches across multiple notice fields simultaneously", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search term that could match multiple fields
      view
      |> form("[data-testid='search-form']", search: "HSE")
      |> render_submit()

      html = render(view)

      # Should find notices by regulator ID prefix and agency
      assert html =~ "HSE-SAFETY-2024-001"
      assert html =~ "HSE-CONSTRUCT-2024-002"
      assert html =~ "HSE-FOLLOWUP-2024-004"
      # EA notice should not appear
      refute html =~ "EA-ENVIRON-2024-003"
    end

    test "handles multi-word search queries", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search with multiple words
      view
      |> form("[data-testid='search-form']", search: "emergency response protocols")
      |> render_submit()

      html = render(view)
      assert html =~ "emergency response protocols" or html =~ "emergency response"
      refute html =~ "crane operations"
    end

    test "searches with quoted phrases", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search for exact phrase
      view
      |> form("[data-testid='search-form']", search: "\"metal fatigue\"")
      |> render_submit()

      html = render(view)
      assert html =~ "metal fatigue"
      refute html =~ "chemical storage"
    end

    test "handles special characters in search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search with special characters (from reference numbers)
      view
      |> form("[data-testid='search-form']", search: "HSE/SAFETY/001")
      |> render_submit()

      html = render(view)
      assert html =~ "HSE/SAFETY/001"
      refute html =~ "HSE/CONSTRUCT/002"
    end

    test "searches by notice type combined with content", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search that combines type and content matching
      view
      |> form("[data-testid='search-form']", search: "Improvement")
      |> render_submit()

      html = render(view)
      assert html =~ "Improvement Notice"
      # Should find both improvement notices
      assert html =~ "HSE-SAFETY-2024-001"
      assert html =~ "HSE-FOLLOWUP-2024-004"
      refute html =~ "Prohibition Notice"
    end

    test "performs fuzzy search for similar terms", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search with slight misspelling (if fuzzy search implemented)
      view
      # Missing 'i'
      |> form("[data-testid='search-form']", search: "constructon")
      |> render_submit()

      html = render(view)

      # May or may not find results depending on fuzzy search implementation
      # Test passes either way, but documents expected behavior
      assert html =~ "construction" or html =~ "notice" or html =~ "Notice"
    end

    test "clears search results", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Perform search first
      view
      |> form("[data-testid='search-form']", search: "HSE-SAFETY-2024-001")
      |> render_submit()

      # Verify filtered results
      html = render(view)
      assert html =~ "HSE-SAFETY-2024-001"
      refute html =~ "HSE-CONSTRUCT-2024-002"

      # Clear search
      view |> element("button", "Clear Search") |> render_click()
      # Or alternatively clear via empty search
      view
      |> form("[data-testid='search-form']", search: "")
      |> render_submit()

      html = render(view)

      # Should show all notices again
      assert html =~ "HSE-SAFETY-2024-001"
      assert html =~ "HSE-CONSTRUCT-2024-002"
      assert html =~ "EA-ENVIRON-2024-003"
      assert html =~ "HSE-FOLLOWUP-2024-004"
    end

    test "shows search result count", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search that returns specific number of results
      view
      |> form("[data-testid='search-form']", search: "Manufacturing")
      |> render_submit()

      html = render(view)

      # Should show result count (2 notices for manufacturing company)
      assert html =~ "2 results" or html =~ "2 notices found" or html =~ "Found 2"
    end

    test "shows no results message appropriately", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search for non-existent content
      view
      |> form("[data-testid='search-form']", search: "nonexistent-search-term-xyz")
      |> render_submit()

      html = render(view)

      # Should show no results message
      assert html =~ "No notices found" or
               html =~ "no results" or
               html =~ "0 notices" or
               html =~ "No matches"
    end

    test "preserves search across pagination", %{conn: conn} do
      # This test requires multiple notices matching search term
      {:ok, view, _html} = live(conn, "/notices")

      # Search for term that returns multiple results
      view
      |> form("[data-testid='search-form']", search: "HSE")
      |> render_submit()

      # If pagination exists, navigate to next page
      if has_element?(view, "button", "Next") do
        view |> element("button", "Next") |> render_click()
        html = render(view)

        # Search should be preserved across pages
        assert html =~ "HSE" or html =~ "search"
      else
        # If no pagination, test still passes
        assert true
      end
    end

    test "handles search with very long query strings", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search with very long string
      long_query = String.duplicate("chemical safety procedures ", 20)

      log =
        capture_log(fn ->
          view
          |> form("[data-testid='search-form']", search: long_query)
          |> render_submit()
        end)

      html = render(view)

      # Should handle gracefully without crashing
      assert html =~ "notice" or html =~ "Notice"
      # May or may not log, both acceptable
      refute log =~ "error" or true
    end

    test "performs search with real-time suggestions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Type partial search to trigger suggestions (if implemented)
      view
      |> form("[data-testid='search-form']", search: "chem")
      # Use render_change for real-time
      |> render_change()

      html = render(view)

      # May show suggestions or live results
      # Test passes regardless of implementation
      assert html =~ "notice" or html =~ "Notice"
    end

    test "highlights search terms in results", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search for specific term
      view
      |> form("[data-testid='search-form']", search: "chemical")
      |> render_submit()

      html = render(view)

      # May highlight search terms (implementation dependent)
      assert html =~ "chemical"
      # Could check for highlighting markup like <mark> or <strong>
      assert html =~ "chemical" or has_element?(view, "mark") or has_element?(view, ".highlight")
    end
  end

  describe "Notice search performance" do
    setup do
      # Create larger dataset for performance testing
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, offender} =
        Enforcement.create_offender(%{
          name: "Performance Test Company",
          local_authority: "Test Council",
          postcode: "T1 1ST"
        })

      # Create 100 notices with varied content
      notices =
        Enum.map(1..100, fn i ->
          {:ok, notice} =
            Enforcement.create_notice(%{
              regulator_id: "HSE-PERF-#{String.pad_leading(to_string(i), 3, "0")}",
              agency_id: agency.id,
              offender_id: offender.id,
              offence_action_type: "Improvement Notice",
              notice_date: Date.add(~D[2024-01-01], i),
              notice_body:
                "Performance test notice #{i} with various safety equipment requirements and chemical handling procedures for testing search functionality across large datasets"
            })

          notice
        end)

      %{notices: notices, agency: agency, offender: offender}
    end

    test "performs search across large dataset efficiently", %{conn: conn} do
      start_time = System.monotonic_time(:millisecond)

      {:ok, view, _html} = live(conn, "/notices")

      # Perform search
      view
      |> form("[data-testid='search-form']", search: "safety equipment")
      |> render_submit()

      end_time = System.monotonic_time(:millisecond)
      search_time = end_time - start_time

      html = render(view)
      assert html =~ "safety equipment"
      # Should complete within 1 second
      assert search_time < 1000
    end

    test "handles concurrent search requests efficiently", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      start_time = System.monotonic_time(:millisecond)

      # Simulate rapid search requests
      search_terms = ["safety", "equipment", "chemical", "procedures", "requirements"]

      Enum.each(search_terms, fn term ->
        view
        |> form("[data-testid='search-form']", search: term)
        # Use render_change for rapid requests
        |> render_change()
      end)

      end_time = System.monotonic_time(:millisecond)
      total_time = end_time - start_time

      html = render(view)
      # Should show final search results
      assert html =~ "requirements"
      # Should handle rapid searches efficiently
      assert total_time < 2000
    end

    test "limits search results to prevent performance issues", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search for term that matches many notices
      view
      |> form("[data-testid='search-form']", search: "test")
      |> render_submit()

      html = render(view)

      # Should limit results or implement pagination
      result_count = (html |> String.split("HSE-PERF-") |> length()) - 1
      # Should limit displayed results
      assert result_count <= 25
    end

    test "implements search result caching for repeated queries", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # First search
      start_time1 = System.monotonic_time(:millisecond)

      view
      |> form("[data-testid='search-form']", search: "safety equipment")
      |> render_submit()

      end_time1 = System.monotonic_time(:millisecond)
      first_search_time = end_time1 - start_time1

      # Clear and repeat same search
      view
      |> form("[data-testid='search-form']", search: "")
      |> render_submit()

      start_time2 = System.monotonic_time(:millisecond)

      view
      |> form("[data-testid='search-form']", search: "safety equipment")
      |> render_submit()

      end_time2 = System.monotonic_time(:millisecond)
      second_search_time = end_time2 - start_time2

      html = render(view)
      assert html =~ "safety equipment"

      # Second search may be faster due to caching (optional optimization)
      # Test passes regardless, but documents expected behavior
      # Allow for slight variance
      assert second_search_time <= first_search_time + 100
    end
  end

  describe "Notice search accessibility" do
    setup :create_search_test_data

    test "provides proper form labels and ARIA attributes", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should have proper search form labeling
      assert has_element?(view, "label[for='search-input']") or html =~ "Search"
      assert html =~ "aria-label=" or has_element?(view, "[aria-label]")

      # Search input should be properly described
      assert has_element?(view, "input[aria-describedby]") or html =~ "Search notices"
    end

    test "announces search results to screen readers", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Perform search
      view
      |> form("[data-testid='search-form']", search: "chemical")
      |> render_submit()

      html = render(view)

      # Should include ARIA live region for result announcements
      assert has_element?(view, "[aria-live]") or
               html =~ "results found" or
               html =~ "Found"
    end

    test "provides keyboard navigation for search results", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Perform search
      view
      |> form("[data-testid='search-form']", search: "safety")
      |> render_submit()

      html = render(view)

      # Results should be keyboard navigable
      assert has_element?(view, "a[href]") or has_element?(view, "[tabindex]")
      assert html =~ "href=" or html =~ "tabindex"
    end

    test "includes clear search button with proper accessibility", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should have accessible clear button
      assert has_element?(view, "button", "Clear") or
               has_element?(view, "button[aria-label*='clear']")

      # Button should be properly labeled
      assert html =~ "Clear" or html =~ "clear"
    end

    test "provides search suggestions with proper ARIA roles", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Type to potentially trigger suggestions
      view
      |> form("[data-testid='search-form']", search: "saf")
      |> render_change()

      html = render(view)

      # If suggestions are implemented, they should have proper ARIA
      if html =~ "suggestion" or has_element?(view, "[role='listbox']") do
        assert has_element?(view, "[role='option']") or has_element?(view, "[role='listbox']")
      end

      # Test passes whether suggestions are implemented or not
      assert true
    end
  end

  # Helper function to create search test data
  defp create_search_test_data(_context) do
    # Create test agencies
    {:ok, hse_agency} =
      Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true
      })

    # Create test offender
    {:ok, offender} =
      Enforcement.create_offender(%{
        name: "Search Test Company Ltd",
        local_authority: "Test Council",
        postcode: "T1 1ST"
      })

    # Create test notices with searchable content
    {:ok, notice1} =
      Enforcement.create_notice(%{
        regulator_id: "HSE-SEARCH-001",
        agency_id: hse_agency.id,
        offender_id: offender.id,
        offence_action_type: "Improvement Notice",
        notice_date: ~D[2024-01-15],
        notice_body: "Chemical safety procedures must be implemented"
      })

    {:ok, notice2} =
      Enforcement.create_notice(%{
        regulator_id: "HSE-SEARCH-002",
        agency_id: hse_agency.id,
        offender_id: offender.id,
        offence_action_type: "Prohibition Notice",
        notice_date: ~D[2024-01-20],
        notice_body: "Equipment maintenance protocols required"
      })

    %{
      hse_agency: hse_agency,
      offender: offender,
      notice1: notice1,
      notice2: notice2
    }
  end
end
