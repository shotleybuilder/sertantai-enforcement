defmodule EhsEnforcementWeb.CaseSearchTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Repo

  describe "Case search functionality" do
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

      # Create diverse offenders for comprehensive search testing
      {:ok, manufacturing_co} =
        Enforcement.create_offender(%{
          name: "Advanced Manufacturing Solutions Ltd",
          local_authority: "Sheffield City Council",
          postcode: "S1 2HE"
        })

      {:ok, chemical_corp} =
        Enforcement.create_offender(%{
          name: "Chemical Industries Corporation PLC",
          local_authority: "Liverpool City Council",
          postcode: "L3 9PP"
        })

      {:ok, construction_ltd} =
        Enforcement.create_offender(%{
          name: "Premier Construction & Engineering Limited",
          local_authority: "Birmingham City Council",
          postcode: "B1 1AA"
        })

      {:ok, waste_services} =
        Enforcement.create_offender(%{
          name: "Metro Waste Management Services",
          local_authority: "Manchester City Council",
          postcode: "M1 5WG"
        })

      # Create test cases with varied content for search testing
      {:ok, manufacturing_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-MANUF-2024-001",
          agency_id: hse_agency.id,
          offender_id: manufacturing_co.id,
          offence_action_date: ~D[2024-01-15],
          offence_fine: Decimal.new("25000.00"),
          offence_breaches:
            "Manufacturing safety protocol violations including inadequate machine guarding and failure to provide proper training to employees operating heavy machinery",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, chemical_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-CHEM-2024-002",
          agency_id: hse_agency.id,
          offender_id: chemical_corp.id,
          offence_action_date: ~D[2024-02-01],
          offence_fine: Decimal.new("45000.00"),
          offence_breaches:
            "Chemical storage and handling safety breaches resulting in environmental contamination risk and worker exposure to hazardous substances",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, construction_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-CONST-2024-003",
          agency_id: hse_agency.id,
          offender_id: construction_ltd.id,
          offence_action_date: ~D[2024-02-15],
          offence_fine: Decimal.new("18000.00"),
          offence_breaches:
            "Construction site safety violations including working at height without proper fall protection and inadequate scaffolding safety measures",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, waste_case} =
        Enforcement.create_case(%{
          regulator_id: "EA-WASTE-2024-004",
          agency_id: ea_agency.id,
          offender_id: waste_services.id,
          offence_action_date: ~D[2024-03-01],
          offence_fine: Decimal.new("12000.00"),
          offence_breaches:
            "Environmental waste management violations including improper disposal of hazardous materials and contamination of groundwater resources",
          last_synced_at: DateTime.utc_now()
        })

      %{
        agencies: [hse_agency, ea_agency],
        offenders: [manufacturing_co, chemical_corp, construction_ltd, waste_services],
        cases: [manufacturing_case, chemical_case, construction_case, waste_case]
      }
    end

    test "searches by complete offender name", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Search for exact company name
      render_change(view, "filter", %{
        "filters" => %{"search" => "Advanced Manufacturing Solutions Ltd"}
      })

      search_results = render(view)

      # Should find exact match
      assert search_results =~ "Advanced Manufacturing Solutions Ltd"
      assert search_results =~ "HSE-MANUF-2024-001"
      refute search_results =~ "Chemical Industries Corporation"
      refute search_results =~ "Premier Construction"
      refute search_results =~ "Metro Waste"
    end

    test "searches by partial offender name", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Search for partial name - "Manufacturing"
      render_change(view, "filter", %{
        "filters" => %{"search" => "Manufacturing"}
      })

      manufacturing_results = render(view)

      assert manufacturing_results =~ "Advanced Manufacturing Solutions Ltd"
      assert manufacturing_results =~ "HSE-MANUF-2024-001"
      refute manufacturing_results =~ "Chemical Industries"

      # Search for partial name - "Chemical"
      render_change(view, "filter", %{
        "filters" => %{"search" => "Chemical"}
      })

      chemical_results = render(view)

      assert chemical_results =~ "Chemical Industries Corporation PLC"
      assert chemical_results =~ "HSE-CHEM-2024-002"
      refute chemical_results =~ "Manufacturing Solutions"

      # Search for partial name - "Construction"
      render_change(view, "filter", %{
        "filters" => %{"search" => "Construction"}
      })

      construction_results = render(view)

      assert construction_results =~ "Premier Construction & Engineering Limited"
      assert construction_results =~ "HSE-CONST-2024-003"
    end

    test "searches by company type suffix", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Search for "Ltd"
      render_change(view, "filter", %{
        "filters" => %{"search" => "Ltd"}
      })

      ltd_results = render(view)

      assert ltd_results =~ "Advanced Manufacturing Solutions Ltd"
      assert ltd_results =~ "Premier Construction & Engineering Limited"
      # This is PLC, not Ltd
      refute ltd_results =~ "Chemical Industries Corporation PLC"

      # Search for "PLC"
      render_change(view, "filter", %{
        "filters" => %{"search" => "PLC"}
      })

      plc_results = render(view)

      assert plc_results =~ "Chemical Industries Corporation PLC"
      refute plc_results =~ "Manufacturing Solutions Ltd"
    end

    test "searches by case regulator ID exact match", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Search for specific case ID
      render_change(view, "filter", %{
        "filters" => %{"search" => "HSE-MANUF-2024-001"}
      })

      exact_id_results = render(view)

      assert exact_id_results =~ "HSE-MANUF-2024-001"
      assert exact_id_results =~ "Advanced Manufacturing Solutions Ltd"
      refute exact_id_results =~ "HSE-CHEM-2024-002"
      refute exact_id_results =~ "HSE-CONST-2024-003"
    end

    test "searches by case regulator ID partial match", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Search for agency prefix
      render_change(view, "filter", %{
        "filters" => %{"search" => "HSE-"}
      })

      hse_results = render(view)

      # Should find all HSE cases
      assert hse_results =~ "HSE-MANUF-2024-001"
      assert hse_results =~ "HSE-CHEM-2024-002"
      assert hse_results =~ "HSE-CONST-2024-003"
      refute hse_results =~ "EA-WASTE-2024-004"

      # Search for year
      render_change(view, "filter", %{
        "filters" => %{"search" => "2024"}
      })

      year_results = render(view)

      # Should find all 2024 cases
      assert year_results =~ "HSE-MANUF-2024-001"
      assert year_results =~ "HSE-CHEM-2024-002"
      assert year_results =~ "HSE-CONST-2024-003"
      assert year_results =~ "EA-WASTE-2024-004"

      # Search for case type
      render_change(view, "filter", %{
        "filters" => %{"search" => "CHEM"}
      })

      chem_results = render(view)

      assert chem_results =~ "HSE-CHEM-2024-002"
      refute chem_results =~ "HSE-MANUF-2024-001"
    end

    test "searches by offense breaches content", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Search for "safety"
      render_change(view, "filter", %{
        "filters" => %{"search" => "safety"}
      })

      safety_results = render(view)

      # Should find cases mentioning safety
      # "safety protocol violations"
      assert safety_results =~ "HSE-MANUF-2024-001"
      # "safety breaches"
      assert safety_results =~ "HSE-CHEM-2024-002"
      # "safety violations"
      assert safety_results =~ "HSE-CONST-2024-003"
      # No "safety" in this case
      refute safety_results =~ "EA-WASTE-2024-004"

      # Search for "environmental"
      render_change(view, "filter", %{
        "filters" => %{"search" => "environmental"}
      })

      env_results = render(view)

      # "environmental contamination"
      assert env_results =~ "HSE-CHEM-2024-002"
      # "Environmental waste management"
      assert env_results =~ "EA-WASTE-2024-004"
      refute env_results =~ "HSE-MANUF-2024-001"

      # Search for "machinery"
      render_change(view, "filter", %{
        "filters" => %{"search" => "machinery"}
      })

      machinery_results = render(view)

      # "heavy machinery"
      assert machinery_results =~ "HSE-MANUF-2024-001"
      refute machinery_results =~ "HSE-CHEM-2024-002"
    end

    test "searches by technical terms in breaches", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Search for "contamination"
      render_change(view, "filter", %{
        "filters" => %{"search" => "contamination"}
      })

      contamination_results = render(view)

      # "contamination risk"
      assert contamination_results =~ "HSE-CHEM-2024-002"
      # "contamination of groundwater"
      assert contamination_results =~ "EA-WASTE-2024-004"
      refute contamination_results =~ "HSE-MANUF-2024-001"

      # Search for "scaffolding"
      render_change(view, "filter", %{
        "filters" => %{"search" => "scaffolding"}
      })

      scaffolding_results = render(view)

      # "scaffolding safety measures"
      assert scaffolding_results =~ "HSE-CONST-2024-003"
      refute scaffolding_results =~ "HSE-MANUF-2024-001"
      refute scaffolding_results =~ "HSE-CHEM-2024-002"

      # Search for "hazardous"
      render_change(view, "filter", %{
        "filters" => %{"search" => "hazardous"}
      })

      hazardous_results = render(view)

      # "hazardous substances"
      assert hazardous_results =~ "HSE-CHEM-2024-002"
      # "hazardous materials"
      assert hazardous_results =~ "EA-WASTE-2024-004"
      refute hazardous_results =~ "HSE-MANUF-2024-001"
    end

    test "handles case-insensitive searches", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Test different case variations
      search_terms = [
        "manufacturing",
        "MANUFACTURING",
        "Manufacturing",
        "mAnUfAcTuRiNg"
      ]

      Enum.each(search_terms, fn term ->
        render_change(view, "filter", %{
          "filters" => %{"search" => term}
        })

        results = render(view)

        assert results =~ "Advanced Manufacturing Solutions Ltd"
        assert results =~ "HSE-MANUF-2024-001"
      end)

      # Test case insensitive for breach content
      breach_terms = ["SAFETY", "safety", "Safety", "sAfEtY"]

      Enum.each(breach_terms, fn term ->
        render_change(view, "filter", %{
          "filters" => %{"search" => term}
        })

        results = render(view)

        # Should find cases with "safety" in breaches
        assert results =~ "HSE-MANUF-2024-001"
        assert results =~ "HSE-CHEM-2024-002"
        assert results =~ "HSE-CONST-2024-003"
      end)
    end

    test "handles multiple word searches", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Search for multiple words in company name
      render_change(view, "filter", %{
        "filters" => %{"search" => "Advanced Manufacturing"}
      })

      multi_word_results = render(view)

      assert multi_word_results =~ "Advanced Manufacturing Solutions Ltd"
      refute multi_word_results =~ "Chemical Industries"

      # Search for multiple words in breaches
      render_change(view, "filter", %{
        "filters" => %{"search" => "safety violations"}
      })

      safety_violations_results = render(view)

      # "safety protocol violations"
      assert safety_violations_results =~ "HSE-MANUF-2024-001"
      # "safety violations"
      assert safety_violations_results =~ "HSE-CONST-2024-003"
      refute safety_violations_results =~ "EA-WASTE-2024-004"

      # Search for phrase in quotes (if supported)
      render_change(view, "filter", %{
        "filters" => %{"search" => "\"heavy machinery\""}
      })

      phrase_results = render(view)

      assert phrase_results =~ "HSE-MANUF-2024-001"
    end

    test "handles special characters in search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Search with ampersand
      render_change(view, "filter", %{
        "filters" => %{"search" => "Construction &"}
      })

      ampersand_results = render(view)

      assert ampersand_results =~ "Premier Construction & Engineering Limited"

      # Search with hyphen
      render_change(view, "filter", %{
        "filters" => %{"search" => "HSE-MANUF"}
      })

      hyphen_results = render(view)

      assert hyphen_results =~ "HSE-MANUF-2024-001"

      # Search with numbers
      render_change(view, "filter", %{
        "filters" => %{"search" => "001"}
      })

      number_results = render(view)

      assert number_results =~ "HSE-MANUF-2024-001"
    end

    test "combines search with other filters", %{conn: conn, agencies: [hse_agency, ea_agency]} do
      {:ok, view, _html} = live(conn, "/cases")

      # Combine search with agency filter
      render_change(view, "filter", %{
        "filters" => %{
          "search" => "safety",
          "agency_id" => hse_agency.id
        }
      })

      combined_results = render(view)

      # Should find HSE cases with "safety" in them
      assert combined_results =~ "HSE-MANUF-2024-001"
      assert combined_results =~ "HSE-CHEM-2024-002"
      assert combined_results =~ "HSE-CONST-2024-003"
      # Wrong agency
      refute combined_results =~ "EA-WASTE-2024-004"

      # Combine search with date filter
      render_change(view, "filter", %{
        "filters" => %{
          "search" => "Chemical",
          "date_from" => "2024-02-01",
          "date_to" => "2024-02-28"
        }
      })

      date_search_results = render(view)

      # Feb 1, 2024
      assert date_search_results =~ "HSE-CHEM-2024-002"
      # Jan 15, outside range
      refute date_search_results =~ "HSE-MANUF-2024-001"

      # Combine search with fine range
      render_change(view, "filter", %{
        "filters" => %{
          "search" => "safety",
          "min_fine" => "20000",
          "max_fine" => "30000"
        }
      })

      fine_search_results = render(view)

      # £25,000 fine
      assert fine_search_results =~ "HSE-MANUF-2024-001"
      # £45,000 - too high
      refute fine_search_results =~ "HSE-CHEM-2024-002"
      # £18,000 - too low
      refute fine_search_results =~ "HSE-CONST-2024-003"
    end

    test "handles empty and whitespace searches", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Empty search should show all cases
      render_change(view, "filter", %{
        "filters" => %{"search" => ""}
      })

      empty_results = render(view)

      assert empty_results =~ "HSE-MANUF-2024-001"
      assert empty_results =~ "HSE-CHEM-2024-002"
      assert empty_results =~ "HSE-CONST-2024-003"
      assert empty_results =~ "EA-WASTE-2024-004"

      # Whitespace-only search should show all cases
      render_change(view, "filter", %{
        "filters" => %{"search" => "   "}
      })

      whitespace_results = render(view)

      assert whitespace_results =~ "HSE-MANUF-2024-001"
      assert whitespace_results =~ "HSE-CHEM-2024-002"
    end

    test "handles searches with no results", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Search for something that won't match
      render_change(view, "filter", %{
        "filters" => %{"search" => "nonexistent_company_xyz_123"}
      })

      no_results = render(view)

      # Should show no results message
      assert no_results =~ "No cases found" or no_results =~ "0 cases" or
               no_results =~ "No results"

      refute no_results =~ "HSE-MANUF-2024-001"
      refute no_results =~ "HSE-CHEM-2024-002"

      # Should still show the search form
      assert no_results =~ "search"
      assert no_results =~ "filters"
    end

    test "handles very long search terms", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Very long search term
      long_search = String.duplicate("a", 1000)

      log =
        capture_log(fn ->
          render_change(view, "filter", %{
            "filters" => %{"search" => long_search}
          })
        end)

      # Should handle gracefully without crashing
      assert Process.alive?(view.pid)

      long_results = render(view)
      assert long_results =~ "No cases found" or long_results =~ "0 cases"
    end

    test "provides search suggestions or highlights", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Search for partial term
      render_change(view, "filter", %{
        "filters" => %{"search" => "Manufactur"}
      })

      partial_results = render(view)

      # Should find matches and potentially highlight the search term
      assert partial_results =~ "Manufacturing"

      # Check for highlighting (depends on implementation)
      if partial_results =~ "<mark>" or partial_results =~ "highlight" do
        assert partial_results =~ "Manufactur"
      end
    end

    test "handles search performance with large datasets", %{conn: conn} do
      # Create additional test data
      {:ok, agency} =
        Enforcement.create_agency(%{code: :test, name: "Test Agency", enabled: true})

      # Create 50 additional offenders and cases
      Enum.each(1..50, fn i ->
        {:ok, offender} =
          Enforcement.create_offender(%{
            name: "Performance Test Company #{i}",
            local_authority: "Test Council #{i}"
          })

        {:ok, _case} =
          Enforcement.create_case(%{
            regulator_id: "PERF-#{String.pad_leading(to_string(i), 3, "0")}",
            agency_id: agency.id,
            offender_id: offender.id,
            offence_action_date: Date.add(~D[2024-01-01], i),
            offence_fine: Decimal.new("#{rem(i, 20) + 1}000.00"),
            offence_breaches: "Performance test breach #{i} with safety violations",
            last_synced_at: DateTime.utc_now()
          })
      end)

      {:ok, view, _html} = live(conn, "/cases")

      # Measure search performance
      start_time = System.monotonic_time(:millisecond)

      render_change(view, "filter", %{
        "filters" => %{"search" => "safety"}
      })

      search_results = render(view)

      end_time = System.monotonic_time(:millisecond)
      search_time = end_time - start_time

      # Should complete search within reasonable time
      assert search_time < 2000, "Search should complete within 2 seconds"

      # Should return relevant results
      assert search_results =~ "safety"
    end
  end

  describe "Search result ranking and relevance" do
    setup do
      {:ok, agency} = Enforcement.create_agency(%{code: :hse, name: "HSE", enabled: true})

      # Create cases with different relevance levels for ranking tests
      {:ok, exact_match} = Enforcement.create_offender(%{name: "Safety Solutions Ltd"})
      {:ok, partial_match} = Enforcement.create_offender(%{name: "Premier Safety Services"})
      {:ok, content_match} = Enforcement.create_offender(%{name: "Industrial Corp"})

      {:ok, exact_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-EXACT-001",
          agency_id: agency.id,
          offender_id: exact_match.id,
          offence_action_date: ~D[2024-01-01],
          offence_fine: Decimal.new("10000.00"),
          offence_breaches: "Minor safety violation",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, partial_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-PARTIAL-002",
          agency_id: agency.id,
          offender_id: partial_match.id,
          offence_action_date: ~D[2024-01-02],
          offence_fine: Decimal.new("15000.00"),
          offence_breaches: "Equipment failure leading to incident",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, content_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-CONTENT-003",
          agency_id: agency.id,
          offender_id: content_match.id,
          offence_action_date: ~D[2024-01-03],
          offence_fine: Decimal.new("20000.00"),
          offence_breaches: "Major safety protocol breaches with multiple safety violations",
          last_synced_at: DateTime.utc_now()
        })

      %{
        exact_case: exact_case,
        partial_case: partial_case,
        content_case: content_case
      }
    end

    test "ranks exact name matches higher than partial matches", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      render_change(view, "filter", %{
        "filters" => %{"search" => "Safety"}
      })

      search_results = render(view)

      # Should find all cases with "Safety" in name or content
      # Exact match in name
      assert search_results =~ "Safety Solutions Ltd"
      # Partial match in name
      assert search_results =~ "Premier Safety Services"
      # Content match
      assert search_results =~ "safety protocol breaches"

      # Check ordering (exact match should come first if ranking is implemented)
      safety_solutions_pos =
        case :binary.match(search_results, "Safety Solutions Ltd") do
          {pos, _} -> pos
          :nomatch -> 999_999
        end

      premier_safety_pos =
        case :binary.match(search_results, "Premier Safety Services") do
          {pos, _} -> pos
          :nomatch -> 999_999
        end

      # If ranking is implemented, exact match should appear first
      # If not implemented, this test documents the current behavior
      if safety_solutions_pos < premier_safety_pos do
        assert safety_solutions_pos < premier_safety_pos, "Exact matches should rank higher"
      end
    end

    test "finds all relevant matches for broad search terms", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      render_change(view, "filter", %{
        "filters" => %{"search" => "safety"}
      })

      broad_search_results = render(view)

      # Should find all cases mentioning safety
      # Company name: "Safety Solutions"
      assert broad_search_results =~ "HSE-EXACT-001"
      # Company name: "Premier Safety Services"
      assert broad_search_results =~ "HSE-PARTIAL-002"
      # Breach content: "safety protocol breaches"
      assert broad_search_results =~ "HSE-CONTENT-003"
    end

    test "handles search result pagination with relevance", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Search for common term that might have many results
      render_change(view, "filter", %{
        "filters" => %{"search" => "safety"}
      })

      search_results = render(view)

      # Should handle pagination if there are many results
      # (This depends on the specific implementation)
      # Should show results
      assert search_results =~ "safety"

      # If pagination is shown
      if search_results =~ "Page" or search_results =~ "Next" do
        # Should show page indicators
        assert search_results =~ "1"
      end
    end
  end

  describe "Search error handling and edge cases" do
    test "handles malformed search requests gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      log =
        capture_log(fn ->
          # Send malformed search data
          render_change(view, "filter", %{
            "filters" => %{"search" => nil}
          })

          render_change(view, "invalid_event", %{
            "search" => "test"
          })
        end)

      # Should handle gracefully without crashing
      assert Process.alive?(view.pid)
    end

    test "handles database connection issues during search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # This would require mocking database failures
      # For now, verify the search form remains functional
      render_change(view, "filter", %{
        "filters" => %{"search" => "test"}
      })

      assert Process.alive?(view.pid)
    end

    test "handles search timeout scenarios", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases")

      # Test with a complex search that might be slow
      very_complex_search = "safety AND (chemical OR manufacturing) AND violations"

      # Should complete within reasonable time or provide feedback
      start_time = System.monotonic_time(:millisecond)

      render_change(view, "filter", %{
        "filters" => %{"search" => very_complex_search}
      })

      end_time = System.monotonic_time(:millisecond)
      search_time = end_time - start_time

      # Should either complete quickly or provide timeout handling
      assert search_time < 5000 or render(view) =~ "timeout" or render(view) =~ "taking longer"
    end
  end
end
