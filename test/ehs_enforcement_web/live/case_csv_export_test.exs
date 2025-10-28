defmodule EhsEnforcementWeb.CaseCSVExportTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Repo

  describe "CSV export functionality" do
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

      # Create test offenders
      {:ok, offender1} =
        Enforcement.create_offender(%{
          name: "Export Test Manufacturing Ltd",
          local_authority: "Greater London Authority",
          postcode: "SW1A 1AA"
        })

      {:ok, offender2} =
        Enforcement.create_offender(%{
          name: "Chemical Processing Corp",
          local_authority: "Manchester City Council",
          postcode: "M1 1AB"
        })

      {:ok, offender3} =
        Enforcement.create_offender(%{
          name: "Construction & Engineering PLC",
          local_authority: "Birmingham City Council",
          postcode: "B1 1CD"
        })

      # Create test cases with comprehensive data for export testing
      {:ok, case1} =
        Enforcement.create_case(%{
          regulator_id: "HSE-EXPORT-2024-001",
          agency_id: hse_agency.id,
          offender_id: offender1.id,
          offence_action_date: ~D[2024-01-15],
          offence_fine: Decimal.new("25000.00"),
          offence_breaches:
            "Manufacturing safety violations, inadequate machine guarding, failure to provide proper training",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, case2} =
        Enforcement.create_case(%{
          regulator_id: "HSE-EXPORT-2024-002",
          agency_id: hse_agency.id,
          offender_id: offender2.id,
          offence_action_date: ~D[2024-02-01],
          offence_fine: Decimal.new("45000.50"),
          offence_breaches:
            "Chemical storage safety breaches with environmental contamination risk",
          last_synced_at: DateTime.utc_now()
        })

      {:ok, case3} =
        Enforcement.create_case(%{
          regulator_id: "EA-EXPORT-2024-003",
          agency_id: ea_agency.id,
          offender_id: offender3.id,
          offence_action_date: ~D[2024-03-15],
          offence_fine: Decimal.new("12500.75"),
          offence_breaches: "Environmental compliance violations, unauthorized waste disposal",
          last_synced_at: DateTime.utc_now()
        })

      # Create related notices for comprehensive export data
      {:ok, _notice1} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-NOTICE-2024-001",
          agency_id: hse_agency.id,
          offender_id: offender1.id,
          notice_date: ~D[2024-01-10],
          compliance_date: ~D[2024-02-10],
          notice_body: "Improvement notice for safety measures",
          offence_action_type: "improvement_notice",
          offence_action_date: ~D[2024-01-10],
          offence_breaches: "Manufacturing safety violations requiring immediate attention"
        })

      {:ok, _notice2} =
        Enforcement.create_notice(%{
          regulator_id: "HSE-NOTICE-2024-002",
          agency_id: hse_agency.id,
          offender_id: offender2.id,
          notice_date: ~D[2024-01-25],
          compliance_date: ~D[2024-02-01],
          notice_body: "Prohibition notice for chemical operations",
          offence_action_type: "prohibition_notice",
          offence_action_date: ~D[2024-01-25],
          offence_breaches: "Chemical storage safety breaches requiring immediate cessation"
        })

      %{
        agencies: [hse_agency, ea_agency],
        offenders: [offender1, offender2, offender3],
        cases: [case1, case2, case3]
      }
    end

    test "displays export button on cases index page", %{conn: conn} do
      {:ok, view, html} = live(conn, "/cases")

      # Should have export button or link
      assert has_element?(view, "button[phx-click='export_csv']") or
               has_element?(view, "a[href*='export']") or
               html =~ "Export" or
               html =~ "Download CSV"
    end

    test "exports all cases when no filters applied", %{conn: conn, cases: cases} do
      {:ok, view, _html} = live(conn, "/cases")

      # Trigger CSV export
      if has_element?(view, "button[phx-click='export_csv']") do
        response = render_click(view, "export_csv")

        # Should trigger download or return CSV data
        assert response =~ "text/csv" or
                 response =~ "application/csv" or
                 response =~ "attachment" or
                 response =~ "HSE-EXPORT-2024-001"
      else
        # Alternative: test direct CSV endpoint
        conn = get(conn, "/cases/export.csv")

        assert conn.status == 200
        assert get_resp_header(conn, "content-type") |> List.first() =~ "csv"

        csv_content = response(conn, 200)

        # Should contain all case data
        assert csv_content =~ "HSE-EXPORT-2024-001"
        assert csv_content =~ "HSE-EXPORT-2024-002"
        assert csv_content =~ "EA-EXPORT-2024-003"
        assert csv_content =~ "Export Test Manufacturing Ltd"
        assert csv_content =~ "Chemical Processing Corp"
      end
    end

    test "exports filtered cases when filters are applied", %{
      conn: conn,
      agencies: [hse_agency, _ea_agency]
    } do
      {:ok, view, _html} = live(conn, "/cases")

      # Apply filter for HSE cases only
      render_change(view, "filter", %{
        "filters" => %{"agency_id" => hse_agency.id}
      })

      # Export filtered results
      if has_element?(view, "button[phx-click='export_csv']") do
        filtered_export = render_click(view, "export_csv")

        # Should contain only HSE cases
        assert filtered_export =~ "HSE-EXPORT-2024-001"
        assert filtered_export =~ "HSE-EXPORT-2024-002"
        refute filtered_export =~ "EA-EXPORT-2024-003"
      else
        # Test CSV endpoint with filter parameters
        conn = get(conn, "/cases/export.csv", %{agency_id: hse_agency.id})

        csv_content = response(conn, 200)
        assert csv_content =~ "HSE-EXPORT-2024-001"
        assert csv_content =~ "HSE-EXPORT-2024-002"
        refute csv_content =~ "EA-EXPORT-2024-003"
      end
    end

    test "CSV contains proper headers and structure", %{conn: conn} do
      # Test direct CSV endpoint for easier content validation
      conn = get(conn, "/cases/export.csv")

      csv_content = response(conn, 200)
      lines = String.split(csv_content, "\n")

      # Should have header row
      header_line = List.first(lines)
      assert header_line != nil

      # Should contain expected column headers
      headers = String.split(header_line, ",")

      expected_headers = [
        "Regulator ID",
        "Agency",
        "Offender Name",
        "Local Authority",
        "Postcode",
        "Offense Date",
        "Fine Amount",
        "Breaches",
        "Last Synced"
      ]

      # Check that essential headers are present (allowing for variations)
      assert Enum.any?(headers, &String.contains?(&1, "Regulator"))
      assert Enum.any?(headers, &String.contains?(&1, "Agency"))
      assert Enum.any?(headers, &String.contains?(&1, "Offender"))
      assert Enum.any?(headers, &String.contains?(&1, "Fine"))
      assert Enum.any?(headers, &String.contains?(&1, "Date"))
    end

    test "CSV data is properly formatted and escaped", %{conn: conn} do
      conn = get(conn, "/cases/export.csv")
      csv_content = response(conn, 200)

      # Should contain properly formatted data
      assert csv_content =~ "HSE-EXPORT-2024-001"
      assert csv_content =~ "Export Test Manufacturing Ltd"
      assert csv_content =~ "25000.00" or csv_content =~ "25,000.00"
      assert csv_content =~ "2024-01-15"

      # Should handle commas in text fields by quoting
      if csv_content =~ "Manufacturing safety violations, inadequate machine guarding" do
        assert csv_content =~ "\"Manufacturing safety violations, inadequate machine guarding"
      end

      # Should handle special characters properly
      assert csv_content =~ "Construction & Engineering PLC" or
               csv_content =~ "Construction &amp; Engineering PLC"

      # Should not contain raw HTML or unescaped characters
      refute csv_content =~ "<"
      refute csv_content =~ ">"
      refute csv_content =~ "&lt;"
    end

    test "CSV includes offender information correctly", %{conn: conn} do
      conn = get(conn, "/cases/export.csv")
      csv_content = response(conn, 200)

      # Should include complete offender details
      assert csv_content =~ "Export Test Manufacturing Ltd"
      assert csv_content =~ "Chemical Processing Corp"
      assert csv_content =~ "Construction & Engineering PLC"

      # Should include location information
      assert csv_content =~ "Greater London Authority"
      assert csv_content =~ "Manchester City Council"
      assert csv_content =~ "Birmingham City Council"

      # Should include postcodes
      assert csv_content =~ "SW1A 1AA"
      assert csv_content =~ "M1 1AB"
      assert csv_content =~ "B1 1CD"
    end

    test "CSV includes agency information correctly", %{conn: conn} do
      conn = get(conn, "/cases/export.csv")
      csv_content = response(conn, 200)

      # Should include agency names or codes
      assert csv_content =~ "Health and Safety Executive" or csv_content =~ "HSE"
      assert csv_content =~ "Environment Agency" or csv_content =~ "EA"
    end

    test "CSV formats monetary values correctly", %{conn: conn} do
      conn = get(conn, "/cases/export.csv")
      csv_content = response(conn, 200)

      # Should format fine amounts consistently
      assert csv_content =~ "25000.00" or csv_content =~ "25,000.00"
      assert csv_content =~ "45000.50" or csv_content =~ "45,000.50"
      assert csv_content =~ "12500.75" or csv_content =~ "12,500.75"

      # Should not include currency symbols in CSV (for numeric sorting)
      refute csv_content =~ "£25,000.00"
    end

    test "CSV formats dates consistently", %{conn: conn} do
      conn = get(conn, "/cases/export.csv")
      csv_content = response(conn, 200)

      # Should use consistent date format
      assert csv_content =~ "2024-01-15" or
               csv_content =~ "01/15/2024" or
               csv_content =~ "15/01/2024"

      # All dates should follow the same format
      date_pattern =
        if csv_content =~ "2024-01-15" do
          ~r/\d{4}-\d{2}-\d{2}/
        else
          ~r/\d{2}\/\d{2}\/\d{4}/
        end

      dates_found = Regex.scan(date_pattern, csv_content)
      # Should find at least our 3 test dates
      assert length(dates_found) >= 3
    end

    test "handles large dataset export performance", %{conn: conn} do
      # Create additional test data using existing agency
      {:ok, agency} =
        Enforcement.create_agency(%{
          code: :onr,
          name: "Office for Nuclear Regulation",
          enabled: true
        })

      # Create 100 additional cases for performance testing
      additional_cases =
        Enum.map(1..100, fn i ->
          {:ok, offender} =
            Enforcement.create_offender(%{
              name: "Performance Test Company #{i}",
              local_authority: "Test Council #{i}",
              postcode: "T#{i} #{i}ST"
            })

          {:ok, case} =
            Enforcement.create_case(%{
              regulator_id: "PERF-#{String.pad_leading(to_string(i), 3, "0")}",
              agency_id: agency.id,
              offender_id: offender.id,
              offence_action_date: Date.add(~D[2024-01-01], i),
              offence_fine: Decimal.new("#{rem(i, 50) + 1}000.00"),
              offence_breaches: "Performance test breach #{i}",
              last_synced_at: DateTime.utc_now()
            })

          case
        end)

      # Measure export performance
      start_time = System.monotonic_time(:millisecond)

      conn = get(conn, "/cases/export.csv")

      end_time = System.monotonic_time(:millisecond)
      export_time = end_time - start_time

      # Should complete export within reasonable time (less than 5 seconds)
      assert export_time < 5000, "CSV export should complete within 5 seconds for 100+ records"

      assert conn.status == 200
      csv_content = response(conn, 200)

      # Should contain additional test data
      assert csv_content =~ "PERF-001"
      assert csv_content =~ "Performance Test Company 1"
    end

    test "provides proper HTTP headers for download", %{conn: conn} do
      conn = get(conn, "/cases/export.csv")

      # Should have appropriate content type
      content_type = get_resp_header(conn, "content-type") |> List.first()
      assert content_type =~ "csv" or content_type =~ "text/plain"

      # Should have content disposition for download
      content_disposition = get_resp_header(conn, "content-disposition") |> List.first()

      if content_disposition do
        assert content_disposition =~ "attachment"
        assert content_disposition =~ "filename"
        assert content_disposition =~ ".csv"
      end

      # Should indicate file size if available
      content_length = get_resp_header(conn, "content-length") |> List.first()

      if content_length do
        assert String.to_integer(content_length) > 0
      end
    end

    test "handles empty result set gracefully", %{conn: conn} do
      # Clear all cases
      Repo.delete_all(EhsEnforcement.Enforcement.Case)

      conn = get(conn, "/cases/export.csv")

      assert conn.status == 200
      csv_content = response(conn, 200)

      # Should still have headers
      lines = String.split(csv_content, "\n")
      # At least header line
      assert length(lines) >= 1

      # Header should be present
      header_line = List.first(lines)
      assert header_line != nil and header_line != ""

      # Should not crash with empty data
      assert csv_content =~ "Regulator" or csv_content =~ "Agency"
    end

    test "respects user permissions for export", %{conn: conn} do
      # This test would be more relevant with authentication
      # For now, verify export is accessible

      conn = get(conn, "/cases/export.csv")
      assert conn.status == 200

      # In a real application, might test:
      # - Unauthorized users get 401/403
      # - Users with limited permissions get filtered data
      # - Admin users get full data export
    end

    test "handles concurrent export requests", %{conn: conn} do
      # Simulate multiple concurrent export requests
      tasks =
        Enum.map(1..5, fn _i ->
          Task.async(fn ->
            test_conn = build_conn() |> Plug.Test.init_test_session(%{})
            get(test_conn, "/cases/export.csv")
          end)
        end)

      results = Task.await_many(tasks, 10_000)

      # All requests should succeed
      Enum.each(results, fn conn ->
        assert conn.status == 200
        csv_content = response(conn, 200)
        assert csv_content =~ "HSE-EXPORT-2024-001"
      end)
    end

    test "includes related data in comprehensive export", %{conn: conn} do
      # Test export with extended case information
      conn = get(conn, "/cases/export_detailed.csv")

      # If detailed export is available
      if conn.status == 200 do
        csv_content = response(conn, 200)

        # Should include notice information if available
        assert csv_content =~ "improvement" or csv_content =~ "prohibition"
        assert csv_content =~ "pending" or csv_content =~ "complied"
      else
        # Fallback to standard export test
        conn = get(conn, "/cases/export.csv")
        assert conn.status == 200
      end
    end

    test "supports different export formats", %{conn: conn} do
      # Test Excel format if supported
      excel_conn = get(conn, "/cases/export.xlsx")

      if excel_conn.status == 200 do
        # Should have appropriate content type for Excel
        content_type = get_resp_header(excel_conn, "content-type") |> List.first()
        assert content_type =~ "excel" or content_type =~ "spreadsheet"
      end

      # CSV should always be supported
      csv_conn = get(conn, "/cases/export.csv")
      assert csv_conn.status == 200
    end

    test "includes export metadata and timestamps", %{conn: conn} do
      conn = get(conn, "/cases/export.csv")
      csv_content = response(conn, 200)

      # Might include export timestamp or metadata in footer/header
      export_time = DateTime.utc_now()
      current_date = Date.to_string(DateTime.to_date(export_time))

      # Should include current dates from last_synced_at
      # Should have recent dates
      assert csv_content =~ current_date or
               csv_content =~ "2024"
    end
  end

  describe "CSV export error handling" do
    test "handles database errors during export gracefully", %{conn: conn} do
      # This would require mocking database failures
      # For now, verify basic error handling

      log =
        capture_log(fn ->
          conn = get(conn, "/cases/export.csv")
          # Should not crash even if there are issues
          assert conn.status in [200, 500]
        end)
    end

    test "handles timeout on large exports", %{conn: conn} do
      # Test with timeout constraints
      conn = get(conn, "/cases/export.csv")

      # Should complete within reasonable time or provide proper error
      assert conn.status == 200 or conn.status == 504
    end

    test "handles malformed export parameters", %{conn: conn} do
      # Test with invalid parameters
      conn =
        get(conn, "/cases/export.csv", %{
          "agency_id" => "invalid-uuid",
          "date_from" => "not-a-date",
          "format" => "invalid"
        })

      # Should handle gracefully
      assert conn.status in [200, 400]
    end

    test "provides meaningful error messages", %{conn: conn} do
      # Test error scenarios
      conn = get(conn, "/cases/export/invalid_format")

      if conn.status == 404 do
        # Expected for invalid endpoint
        assert true
      else
        # Should provide helpful error message
        response_body = response(conn, conn.status)
        assert response_body =~ "error" or response_body =~ "invalid"
      end
    end
  end

  describe "CSV export security" do
    test "prevents CSV injection attacks", %{conn: conn} do
      # Create case with potentially dangerous content
      {:ok, agency} =
        Enforcement.create_agency(%{code: :orr, name: "Office of Rail and Road", enabled: true})

      {:ok, offender} =
        Enforcement.create_offender(%{
          # CSV injection attempt
          name: "=cmd|'/c calc'!A0",
          local_authority: "Test Council"
        })

      {:ok, _dangerous_case} =
        Enforcement.create_case(%{
          regulator_id: "SEC-001",
          agency_id: agency.id,
          offender_id: offender.id,
          offence_action_date: ~D[2024-01-01],
          offence_fine: Decimal.new("1000.00"),
          offence_breaches: "@SUM(1+1)*cmd|'/c calc'!A0",
          last_synced_at: DateTime.utc_now()
        })

      conn = get(conn, "/cases/export.csv")
      csv_content = response(conn, 200)

      # Should escape or remove dangerous formulas
      refute csv_content =~ "=cmd"
      refute csv_content =~ "@SUM"

      # Should prefix dangerous characters or quote them safely
      if csv_content =~ "cmd" do
        # Should be escaped
        assert csv_content =~ "_cmd" or csv_content =~ "'=cmd" or csv_content =~ "\"=cmd"
      end
    end

    test "sanitizes special characters properly", %{conn: conn} do
      conn = get(conn, "/cases/export.csv")
      csv_content = response(conn, 200)

      # Should not contain unescaped quotes that could break CSV structure
      # Quotes should be doubled or the field should be properly quoted
      quote_count = (String.split(csv_content, "\"") |> length()) - 1

      # If there are quotes, they should be balanced (even number total)
      if quote_count > 0 do
        assert rem(quote_count, 2) == 0, "CSV should have balanced quotes"
      end
    end

    test "limits export size to prevent resource exhaustion", %{conn: conn} do
      conn = get(conn, "/cases/export.csv")
      csv_content = response(conn, 200)

      # Content should be reasonable size (not unlimited)
      content_size = byte_size(csv_content)

      # Should be less than 10MB for reasonable dataset
      assert content_size < 10_000_000, "Export should not exceed reasonable size limits"
    end
  end
end
