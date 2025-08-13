defmodule EhsEnforcement.Agencies.Ea.CaseScraperTest do
  @moduledoc """
  Unit tests for EA Case Scraper parsing logic.
  
  Tests focus on HTML parsing and data extraction without making live HTTP calls.
  """
  
  use ExUnit.Case, async: true
  
  alias EhsEnforcement.Scraping.Ea.CaseScraper
  alias EhsEnforcement.Scraping.Ea.CaseScraper.{EaSummaryRecord, EaDetailRecord}
  
  # Mock HTML response that matches the actual EA website structure
  @mock_ea_summary_html """
  <!DOCTYPE html>
  <html>
  <head><title>Environment Agency - Public Register</title></head>
  <body>
    <div class="content">
      <table class="results-table">
        <thead>
          <tr>
            <th>Offender Name</th>
            <th>Address</th>
            <th>Action Date</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>
              <a href="/public-register/enforcement-action/registration/10002155?__pageState=result-enforcement-action">
                BYCOTT FARMS LIMITED
              </a>
            </td>
            <td></td>
            <td>11/01/2024</td>
          </tr>
          <tr>
            <td>
              <a href="/public-register/enforcement-action/registration/10002273?__pageState=result-enforcement-action">
                ERWIN RHODES CONTRACTING LTD.
              </a>
            </td>
            <td>Axe Road, Bridgwater, Somerset, TA6 5LP</td>
            <td>30/01/2024</td>
          </tr>
          <tr>
            <td>
              <a href="/public-register/enforcement-action/registration/10001620?__pageState=result-enforcement-action">
                FAW BAKER'S KINGSTON FARMS LTD
              </a>
            </td>
            <td></td>
            <td>05/02/2024</td>
          </tr>
          <tr>
            <td>
              <a href="/public-register/enforcement-action/registration/10002100?__pageState=result-enforcement-action">
                TEST COMPANY WITH LONG NAME & SPECIAL CHARS
              </a>
            </td>
            <td>123 Test Street, Test Town, Test County, AB1 2CD</td>
            <td>15/03/2024</td>
          </tr>
        </tbody>
      </table>
    </div>
  </body>
  </html>
  """
  
  @mock_ea_detail_html """
  <!DOCTYPE html>
  <html>
  <head><title>Environment Agency - Case Details</title></head>
  <body>
    <div class="case-details">
      <dl>
        <dt>Company No.</dt>
        <dd>12345678</dd>
        <dt>Industry Sector</dt>
        <dd>Agriculture</dd>
        <dt>Address</dt>
        <dd>Farm Road</dd>
        <dt>Town</dt>
        <dd>Somerset</dd>
        <dt>County</dt>
        <dd>Somerset</dd>
        <dt>Postcode</dt>
        <dd>TA1 2AB</dd>
        <dt>Total Fine</dt>
        <dd>£5,000</dd>
        <dt>Offence</dt>
        <dd>Pollution of controlled waters</dd>
        <dt>Case Reference</dt>
        <dd>EA/2024/001</dd>
        <dt>Event Reference</dt>
        <dd>205107</dd>
        <dt>Agency Function</dt>
        <dd>Water Quality</dd>
        <dt>Water Impact</dt>
        <dd>Minor</dd>
        <dt>Land Impact</dt>
        <dd>None</dd>
        <dt>Air Impact</dt>
        <dd>None</dd>
        <dt>Act</dt>
        <dd>Environmental Protection Act 1990</dd>
        <dt>Section</dt>
        <dd>Section 33(1)(a)</dd>
      </dl>
    </div>
  </body>
  </html>
  """
  
  describe "parse_summary_page/2" do
    test "parses EA summary page HTML correctly" do
      action_type = :court_case
      
      # Use reflection to call the private function for testing
      result = call_private(CaseScraper, :parse_summary_page, [@mock_ea_summary_html, action_type])
      
      assert {:ok, records} = result
      assert length(records) == 4
      
      # Test first record (empty address)
      [first_record | _] = records
      assert %EaSummaryRecord{} = first_record
      assert first_record.offender_name == "BYCOTT FARMS LIMITED"
      assert first_record.summary_address == nil  # Empty address should be nil
      assert first_record.action_date == ~D[2024-01-11]  # DD/MM/YYYY -> YYYY-MM-DD
      assert first_record.action_type == :court_case
      assert first_record.ea_record_id == "10002155"
      assert String.contains?(first_record.detail_url, "/registration/10002155")
      
      # Test second record (with address)
      second_record = Enum.at(records, 1)
      assert second_record.offender_name == "ERWIN RHODES CONTRACTING LTD."
      assert second_record.summary_address == "Axe Road, Bridgwater, Somerset, TA6 5LP"
      assert second_record.action_date == ~D[2024-01-30]
      assert second_record.ea_record_id == "10002273"
      
      # Test record with special characters
      fourth_record = Enum.at(records, 3)
      assert fourth_record.offender_name == "TEST COMPANY WITH LONG NAME & SPECIAL CHARS"
      assert fourth_record.summary_address == "123 Test Street, Test Town, Test County, AB1 2CD"
      assert fourth_record.action_date == ~D[2024-03-15]
      assert fourth_record.ea_record_id == "10002100"
    end
    
    test "handles empty table gracefully" do
      empty_html = """
      <html><body>
        <table>
          <thead><tr><th>Name</th><th>Address</th><th>Date</th></tr></thead>
          <tbody></tbody>
        </table>
      </body></html>
      """
      
      result = call_private(CaseScraper, :parse_summary_page, [empty_html, :court_case])
      
      assert {:ok, records} = result
      assert records == []
    end
    
    test "handles malformed HTML gracefully" do
      malformed_html = "<html><body>Not a table</body></html>"
      
      result = call_private(CaseScraper, :parse_summary_page, [malformed_html, :court_case])
      
      assert {:ok, records} = result
      assert records == []
    end
  end
  
  describe "parse_detail_page/1" do
    test "parses EA detail page HTML correctly" do
      result = call_private(CaseScraper, :parse_detail_page, [@mock_ea_detail_html])
      
      assert {:ok, detail_data} = result
      assert detail_data.company_registration_number == "12345678"
      assert detail_data.industry_sector == "Agriculture"
      assert detail_data.address == "Farm Road"
      assert detail_data.town == "Somerset"
      assert detail_data.county == "Somerset"
      assert detail_data.postcode == "TA1 2AB"
      assert Decimal.equal?(detail_data.total_fine, Decimal.new("5000"))
      assert detail_data.offence_description == "Pollution of controlled waters"
      assert detail_data.case_reference == "EA/2024/001"
      assert detail_data.event_reference == "205107"
      assert detail_data.agency_function == "Water Quality"
      assert detail_data.water_impact == "Minor"
      assert detail_data.land_impact == "None"
      assert detail_data.air_impact == "None"
      assert detail_data.act == "Environmental Protection Act 1990"
      assert detail_data.section == "Section 33(1)(a)"
      assert detail_data.legal_reference == "Environmental Protection Act 1990 - Section 33(1)(a)"
    end
    
    test "handles missing fields gracefully" do
      minimal_html = """
      <html><body>
        <dl>
          <dt>Company No.</dt>
          <dd>12345678</dd>
          <dt>Total Fine</dt>
          <dd>£1,000</dd>
        </dl>
      </body></html>
      """
      
      result = call_private(CaseScraper, :parse_detail_page, [minimal_html])
      
      assert {:ok, detail_data} = result
      assert detail_data.company_registration_number == "12345678"
      assert Decimal.equal?(detail_data.total_fine, Decimal.new("1000"))
      assert detail_data.industry_sector == nil
      assert detail_data.legal_reference == nil
    end
  end
  
  describe "date parsing" do
    test "parses DD/MM/YYYY format correctly" do
      date_result = call_private(CaseScraper, :parse_ea_date, ["11/01/2024"])
      assert date_result == ~D[2024-01-11]
      
      date_result = call_private(CaseScraper, :parse_ea_date, ["29/02/2024"])  # Leap year
      assert date_result == ~D[2024-02-29]
    end
    
    test "parses ISO format correctly" do
      date_result = call_private(CaseScraper, :parse_ea_date, ["2024-01-11"])
      assert date_result == ~D[2024-01-11]
    end
    
    test "handles invalid dates gracefully" do
      assert call_private(CaseScraper, :parse_ea_date, ["invalid"]) == nil
      assert call_private(CaseScraper, :parse_ea_date, ["32/01/2024"]) == nil
      assert call_private(CaseScraper, :parse_ea_date, [""]) == nil
      assert call_private(CaseScraper, :parse_ea_date, [nil]) == nil
    end
  end
  
  describe "record ID extraction" do
    test "extracts record ID from EA URLs correctly" do
      url1 = "/public-register/enforcement-action/registration/10002155?__pageState=result-enforcement-action"
      result1 = call_private(CaseScraper, :extract_record_id_from_url, [url1])
      assert result1 == "10002155"
      
      url2 = "https://environment.data.gov.uk/public-register/enforcement-action/registration/10001620"
      result2 = call_private(CaseScraper, :extract_record_id_from_url, [url2])
      assert result2 == "10001620"
    end
    
    test "falls back to hash for non-standard URLs" do
      url = "https://example.com/some/other/path"
      result = call_private(CaseScraper, :extract_record_id_from_url, [url])
      
      # Should return an 8-character hash
      assert String.length(result) == 8
      assert String.match?(result, ~r/^[A-F0-9]+$/)
    end
    
    test "handles nil URLs" do
      result = call_private(CaseScraper, :extract_record_id_from_url, [nil])
      assert result == nil
    end
  end
  
  describe "URL building" do
    test "builds absolute detail URLs correctly" do
      relative_url = "/public-register/enforcement-action/registration/10002155?__pageState=result-enforcement-action"
      result = call_private(CaseScraper, :build_absolute_detail_url, [relative_url])
      
      expected = "https://environment.data.gov.uk/public-register/enforcement-action/registration/10002155?__pageState=result-enforcement-action"
      assert result == expected
    end
    
    test "handles already absolute URLs" do
      absolute_url = "https://environment.data.gov.uk/public-register/enforcement-action/registration/10002155"
      result = call_private(CaseScraper, :build_absolute_detail_url, [absolute_url])
      
      assert result == absolute_url
    end
    
    test "handles nil URLs" do
      result = call_private(CaseScraper, :build_absolute_detail_url, [nil])
      assert result == nil
    end
  end
  
  describe "row extraction validation" do
    test "validates all required fields are present" do
      # Test the validation logic that was failing
      {:ok, document} = Floki.parse_document(@mock_ea_summary_html)
      rows = Floki.find(document, "table tbody tr")
      
      # Test first row (should pass validation)
      first_row = List.first(rows)
      result = call_private(CaseScraper, :extract_summary_record_from_row, [first_row, :court_case, DateTime.utc_now()])
      
      assert {:ok, record} = result
      assert record.offender_name == "BYCOTT FARMS LIMITED"
      assert record.action_date == ~D[2024-01-11]
      assert record.ea_record_id == "10002155"
      assert String.contains?(record.detail_url, "/registration/10002155")
    end
    
    test "rejects rows with insufficient data" do
      # Create a malformed row with missing link
      malformed_html = """
      <table><tbody>
        <tr>
          <td>COMPANY NAME</td>
          <td>Some Address</td>
          <td>11/01/2024</td>
        </tr>
      </tbody></table>
      """
      
      {:ok, document} = Floki.parse_document(malformed_html)
      [row] = Floki.find(document, "tbody tr")
      
      result = call_private(CaseScraper, :extract_summary_record_from_row, [row, :court_case, DateTime.utc_now()])
      
      # Should fail validation because there's no link (therefore no detail_url or record_id)
      assert {:error, :insufficient_data} = result
    end
  end
  
  # Helper function to call test-exposed functions
  defp call_private(CaseScraper, :parse_summary_page, [html, action_type]) do
    CaseScraper.test_parse_summary_page(html, action_type)
  end
  
  defp call_private(CaseScraper, :parse_detail_page, [html]) do
    CaseScraper.test_parse_detail_page(html)
  end
  
  defp call_private(CaseScraper, :parse_ea_date, [date_string]) do
    CaseScraper.test_parse_ea_date(date_string)
  end
  
  defp call_private(CaseScraper, :extract_record_id_from_url, [url]) do
    CaseScraper.test_extract_record_id_from_url(url)
  end
  
  defp call_private(CaseScraper, :build_absolute_detail_url, [url]) do
    CaseScraper.test_build_absolute_detail_url(url)
  end
  
  defp call_private(CaseScraper, :extract_summary_record_from_row, [row, action_type, timestamp]) do
    CaseScraper.test_extract_summary_record_from_row(row, action_type, timestamp)
  end
end