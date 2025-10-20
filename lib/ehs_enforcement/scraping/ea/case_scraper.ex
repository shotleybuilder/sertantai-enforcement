defmodule EhsEnforcement.Scraping.Ea.CaseScraper do
  @moduledoc """
  Environment Agency enforcement action scraper - Two-stage URI pattern.
  
  Stage 1: Single summary request (no pagination) gets ALL cases for date range
  Stage 2: Individual detail page requests with throttling between each request
  
  Rate limiting: Configurable delay between detail page requests (default 3s)
  """

  require Logger

  @base_url "https://environment.data.gov.uk/public-register/enforcement-action/registration"
  @detail_url_base "https://environment.data.gov.uk"
  @action_types [
    {:court_case, "http://environment.data.gov.uk/public-register/enforcement-action/def/action-type/court-case"},
    {:caution, "http://environment.data.gov.uk/public-register/enforcement-action/def/action-type/caution"}, 
    {:enforcement_notice, "http://environment.data.gov.uk/public-register/enforcement-action/def/action-type/enforcement-notice"}
  ]
  @default_detail_delay_ms 3000   # Default 3s between detail page requests
  @max_retries 3

  defmodule EaSummaryRecord do
    @moduledoc "Basic record from EA summary pages (Stage 1)"
    
    defstruct [
      :ea_record_id,
      :offender_name,
      :summary_address,  # Address from summary table (may be incomplete)
      :action_date,
      :action_type,
      :detail_url,
      :scraped_at
    ]
  end

  defmodule EaDetailRecord do
    @moduledoc "Complete record from EA detail pages (Stage 2)"
    
    defstruct [
      # From summary
      :ea_record_id,
      :offender_name,
      :action_date,
      :action_type,
      
      # Company information (detail page)
      :company_registration_number,
      :industry_sector,
      :address,
      :town,
      :county,
      :postcode,
      
      # Enforcement details (detail page)
      :total_fine,
      :offence_description,
      :case_reference,
      :event_reference,
      :agency_function,
      
      # Environmental impact (detail page)
      :water_impact,
      :land_impact,
      :air_impact,
      
      # Legal framework (detail page)
      :act,
      :section,
      :legal_reference,
      
      # Metadata
      :scraped_at,
      :detail_url
    ]
  end
  
  @doc """
  Main scraping entry point - implements two-stage scraping pattern.
  
  Returns fully enriched EaDetailRecord structs ready for Case resource creation.
  """
  def scrape_enforcement_actions(date_from, date_to, action_types, opts \\ [])
  def scrape_enforcement_actions(date_from, date_to, action_types, opts) when is_list(action_types) do
    Logger.info("Starting EA two-stage scraping", 
                date_from: date_from, 
                date_to: date_to, 
                action_types: action_types)
    
    page_start = Keyword.get(opts, :page, 1)
    max_pages = Keyword.get(opts, :max_pages, 20)
    
    # Stage 1: Collect summary records from all action types
    case collect_all_summary_records(date_from, date_to, action_types, page_start, max_pages, opts) do
      {:ok, summary_records} ->
        Logger.info("Stage 1 complete: #{length(summary_records)} summary records collected")
        
        # Stage 2: Fetch detail data for each record
        case collect_all_detail_records(summary_records, opts) do
          {:ok, detail_records} ->
            Logger.info("Stage 2 complete: #{length(detail_records)} detail records enriched")
            {:ok, detail_records}
            
          {:error, reason} ->
            Logger.error("Stage 2 failed: #{inspect(reason)}")
            {:error, {:detail_stage_failed, reason}}
        end
        
      {:error, reason} ->
        Logger.error("Stage 1 failed: #{inspect(reason)}")
        {:error, {:summary_stage_failed, reason}}
    end
  end

  def scrape_enforcement_actions(date_from, date_to, action_type, opts) when is_atom(action_type) do
    scrape_enforcement_actions(date_from, date_to, [action_type], opts)
  end
  
  # Stage 1: Summary page collection
  
  defp collect_all_summary_records(date_from, date_to, action_types, page_start, max_pages, opts) do
    Logger.debug("Stage 1: Collecting summary records for #{length(action_types)} action types")
    
    results = Enum.reduce_while(action_types, {:ok, []}, fn action_type, {:ok, acc} ->
      Logger.debug("Processing action type: #{action_type}")
      
      case collect_summary_records_for_action_type(date_from, date_to, action_type, page_start, max_pages, opts) do
        {:ok, records} ->
          Logger.info("Action type #{action_type}: #{length(records)} records")
          {:cont, {:ok, acc ++ records}}
          
        {:error, reason} ->
          Logger.error("Failed to collect records for action type #{action_type}: #{inspect(reason)}")
          {:halt, {:error, reason}}
      end
    end)
    
    case results do
      {:ok, all_records} ->
        # Remove duplicates based on EA record ID
        unique_records = Enum.uniq_by(all_records, & &1.ea_record_id)
        Logger.info("Stage 1 deduplication: #{length(all_records)} → #{length(unique_records)} unique records")
        {:ok, unique_records}
        
      error -> error
    end
  end
  
  defp collect_summary_records_for_action_type(date_from, date_to, action_type, _page_start, _max_pages, opts) do
    # EA website returns ALL results for a search query on a single page (no pagination)
    # So we just make one request per action type
    scrape_single_action_type(date_from, date_to, action_type, opts)
  end
  
  defp scrape_single_action_type(date_from, date_to, action_type, opts) do
    Logger.debug("Scraping complete result set for action type #{action_type}")
    
    case scrape_single_summary_page(date_from, date_to, action_type, opts) do
      {:ok, records} ->
        Logger.info("Action type #{action_type}: #{length(records)} total records (complete result set)")
        {:ok, records}
        
      {:error, reason} ->
        Logger.error("Failed to scrape action type #{action_type}: #{inspect(reason)}")
        {:error, {:action_type_failed, action_type, reason}}
    end
  end
  
  defp scrape_single_summary_page(date_from, date_to, action_type, opts) do
    url = build_search_url(action_type, date_from, date_to, opts)
    Logger.debug("Scraping complete result set: #{url}")
    
    with {:ok, html} <- fetch_with_retry(url, @max_retries, opts),
         {:ok, records} <- parse_summary_page(html, action_type) do
      {:ok, records}
    else
      error -> error
    end
  end
  
  # Stage 2: Detail page collection
  
  defp collect_all_detail_records(summary_records, opts) do
    Logger.debug("Stage 2: Collecting detail records for #{length(summary_records)} summary records")
    
    results = Enum.reduce_while(summary_records, {:ok, []}, fn summary_record, {:ok, acc} ->
      case fetch_detail_record(summary_record, opts) do
        {:ok, detail_record} ->
          {:cont, {:ok, [detail_record | acc]}}
          
        {:error, reason} ->
          Logger.warning("Failed to fetch detail for record #{summary_record.ea_record_id}: #{inspect(reason)}")
          # Continue processing other records, don't fail the whole batch
          {:cont, {:ok, acc}}
      end
    end)
    
    case results do
      {:ok, detail_records} ->
        {:ok, Enum.reverse(detail_records)}  # Restore original order
      error -> error
    end
  end
  
  defp fetch_detail_record(summary_record, opts) do
    Logger.debug("Fetching detail for EA record: #{summary_record.ea_record_id}")
    
    with {:ok, html} <- fetch_with_retry(summary_record.detail_url, @max_retries, opts),
         {:ok, detail_data} <- parse_detail_page(html) do
      
      # Merge summary data with detail data
      detail_record = %EaDetailRecord{
        # From summary
        ea_record_id: summary_record.ea_record_id,
        offender_name: summary_record.offender_name,
        action_date: summary_record.action_date,
        action_type: summary_record.action_type,
        detail_url: summary_record.detail_url,
        
        # From detail page
        company_registration_number: detail_data.company_registration_number,
        industry_sector: detail_data.industry_sector,
        address: detail_data.address,
        town: detail_data.town,
        county: detail_data.county,
        postcode: detail_data.postcode,
        total_fine: detail_data.total_fine,
        offence_description: detail_data.offence_description,
        case_reference: detail_data.case_reference,
        event_reference: detail_data.event_reference,
        agency_function: detail_data.agency_function,
        water_impact: detail_data.water_impact,
        land_impact: detail_data.land_impact,
        air_impact: detail_data.air_impact,
        act: detail_data.act,
        section: detail_data.section,
        legal_reference: detail_data.legal_reference,
        
        # Metadata
        scraped_at: DateTime.utc_now()
      }
      
      # Rate limiting between detail requests (configurable)
      delay_ms = Keyword.get(opts, :detail_delay_ms, @default_detail_delay_ms)
      Process.sleep(delay_ms)
      {:ok, detail_record}
    else
      error -> error
    end
  end
  
  # URL building and HTTP handling
  
  defp build_search_url(action_type, date_from, date_to, opts) do
    action_type_url = get_action_type_url(action_type)

    # Build query parameters - match working EA URL format exactly
    # Note: EA website doesn't seem to support pagination parameters, so we'll ignore page for now
    params = %{
      "name-search" => "",  # Always include empty name-search as in working URL
      "actionType" => action_type_url,
      "offenceType" => "",  # Include empty offenceType
      "agencyFunction" => "",  # Include empty agencyFunction
      "after" => Date.to_string(date_from),
      "before" => Date.to_string(date_to)  # Use date_to parameter for proper filtering
    }
    
    # Override name search if specifically provided
    params = case Keyword.get(opts, :name_search) do
      nil -> params
      name when name != "" -> Map.put(params, "name-search", name)
      _ -> params  # Keep empty if empty string provided
    end
    
    query_string = URI.encode_query(params)
    "#{@base_url}?#{query_string}"
  end
  
  defp get_action_type_url(action_type) do
    case List.keyfind(@action_types, action_type, 0) do
      {^action_type, url} -> url
      nil -> 
        Logger.warning("Unknown action type: #{action_type}, using court_case as default")
        get_action_type_url(:court_case)
    end
  end
  
  defp fetch_with_retry(url, retries, opts) do
    Logger.debug("Fetching URL: #{url}")
    
    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}
      
      {:ok, %{status: status}} when status >= 400 ->
        Logger.warning("HTTP error #{status} for URL: #{url}")
        if retries > 0 do
          Process.sleep(2000)  # Wait before retry
          fetch_with_retry(url, retries - 1, opts)
        else
          {:error, {:http_error, status}}
        end
      
      {:error, reason} ->
        Logger.warning("Request failed for URL #{url}: #{inspect(reason)}")
        if retries > 0 do
          Process.sleep(2000)  # Wait before retry
          fetch_with_retry(url, retries - 1, opts)
        else
          {:error, reason}
        end
    end
  end
  
  # HTML parsing functions
  
  defp parse_summary_page(html, action_type) do
    try do
      {:ok, document} = Floki.parse_document(html)
      
      # Find the results table - EA returns ALL results on a single page
      records = document
      |> Floki.find("table tbody tr")  # Find table rows
      |> parse_summary_table_rows(action_type)
      
      Logger.debug("Parsed #{length(records)} records from EA results page")
      {:ok, records}
    rescue
      error ->
        Logger.error("Failed to parse summary page HTML: #{inspect(error)}")
        {:error, {:parse_error, error}}
    end
  end
  
  defp parse_summary_table_rows(rows, action_type) do
    timestamp = DateTime.utc_now()
    
    Enum.reduce(rows, [], fn row, acc ->
      case extract_summary_record_from_row(row, action_type, timestamp) do
        {:ok, record} -> [record | acc]
        {:error, _reason} -> acc  # Skip invalid rows
      end
    end)
    |> Enum.reverse()
  end
  
  defp extract_summary_record_from_row(row, action_type, timestamp) do
    try do
      cells = Floki.find(row, "td")
      
      # EA table structure: [Name, Address, Date] with detail link in name cell
      case cells do
        [name_cell, address_cell, date_cell | _] ->
          # Extract offender name
          offender_name = name_cell |> Floki.text() |> String.trim()
          
          # Extract address (may be empty for some records)
          address = address_cell |> Floki.text() |> String.trim()
          
          # Extract action date from third cell
          action_date_str = date_cell |> Floki.text() |> String.trim()
          action_date = parse_ea_date(action_date_str)
          
          # Extract detail URL from the name cell link
          detail_url = case Floki.find(name_cell, "a") do
            [{"a", attrs, _}] ->
              case List.keyfind(attrs, "href", 0) do
                {"href", href} -> build_absolute_detail_url(href)
                nil -> nil
              end
            _ -> nil
          end
          
          # Extract EA record ID from detail URL
          ea_record_id = extract_record_id_from_url(detail_url)
          
          if offender_name != "" && action_date && detail_url && ea_record_id do
            record = %EaSummaryRecord{
              ea_record_id: ea_record_id,
              offender_name: offender_name,
              summary_address: if(address != "", do: address, else: nil),
              action_date: action_date,
              action_type: action_type,
              detail_url: detail_url,
              scraped_at: timestamp
            }
            {:ok, record}
          else
            Logger.debug("Insufficient data for EA record: name='#{offender_name}', date=#{inspect(action_date)}, url=#{detail_url}, id=#{ea_record_id}")
            {:error, :insufficient_data}
          end
        
        [name_cell, date_cell | _] ->
          # Fallback for 2-column format (no address column)
          offender_name = name_cell |> Floki.text() |> String.trim()
          action_date_str = date_cell |> Floki.text() |> String.trim()
          action_date = parse_ea_date(action_date_str)
          
          detail_url = case Floki.find(name_cell, "a") do
            [{"a", attrs, _}] ->
              case List.keyfind(attrs, "href", 0) do
                {"href", href} -> build_absolute_detail_url(href)
                nil -> nil
              end
            _ -> nil
          end
          
          ea_record_id = extract_record_id_from_url(detail_url)
          
          if offender_name != "" && action_date && detail_url && ea_record_id do
            record = %EaSummaryRecord{
              ea_record_id: ea_record_id,
              offender_name: offender_name,
              summary_address: nil,  # No address in 2-column format
              action_date: action_date,
              action_type: action_type,
              detail_url: detail_url,
              scraped_at: timestamp
            }
            {:ok, record}
          else
            Logger.debug("Insufficient data for EA record (2-col): name='#{offender_name}', date=#{inspect(action_date)}, url=#{detail_url}, id=#{ea_record_id}")
            {:error, :insufficient_data}
          end
          
        _ ->
          Logger.debug("Invalid table structure: found #{length(cells)} cells")
          {:error, :invalid_table_structure}
      end
    rescue
      error ->
        Logger.error("Row parse error: #{inspect(error)}")
        {:error, {:row_parse_error, error}}
    end
  end
  
  defp parse_detail_page(html) do
    try do
      {:ok, document} = Floki.parse_document(html)
      
      # Extract all detail fields from the EA detail page structure
      detail_data = %{
        company_registration_number: extract_field(document, "Company No."),
        industry_sector: extract_field(document, "Industry Sector"),
        address: extract_field(document, "Address"),
        town: extract_field(document, "Town"),
        county: extract_field(document, "County"),
        postcode: extract_field(document, "Postcode"),
        total_fine: extract_and_parse_fine(document, "Total Fine"),
        offence_description: extract_field(document, "Offence"),
        case_reference: extract_field(document, "Case Reference"),
        event_reference: extract_field(document, "Event Reference"),
        agency_function: extract_field(document, "Agency Function"),
        water_impact: extract_field(document, "Water Impact"),
        land_impact: extract_field(document, "Land Impact"),
        air_impact: extract_field(document, "Air Impact"),
        act: extract_field(document, "Act"),
        section: extract_field(document, "Section"),
        legal_reference: extract_legal_reference(document)
      }
      
      {:ok, detail_data}
    rescue
      error ->
        Logger.error("Failed to parse detail page HTML: #{inspect(error)}")
        {:error, {:parse_detail_error, error}}
    end
  end
  
  # Helper functions for detail page parsing
  
  defp extract_field(document, field_label) do
    # EA uses definition list format: <dt>Field Label</dt><dd>Field Value</dd>
    case Floki.find(document, "dt:fl-contains('#{field_label}')") do
      [_dt] ->
        case Floki.find(document, "dt:fl-contains('#{field_label}') + dd") do
          [dd] -> dd |> Floki.text() |> String.trim()
          _ -> nil
        end
      _ ->
        # Fallback: look for table-based layouts
        extract_field_from_table(document, field_label)
    end
  end
  
  defp extract_field_from_table(document, field_label) do
    # Alternative parsing for table-based detail layouts
    case Floki.find(document, "td:fl-contains('#{field_label}')") do
      [td] ->
        # Find the next cell (value cell)
        case Floki.find(td, "+ td") do
          [value_cell] -> value_cell |> Floki.text() |> String.trim()
          _ -> nil
        end
      _ -> nil
    end
  end
  
  defp extract_and_parse_fine(document, field_label) do
    case extract_field(document, field_label) do
      nil -> Decimal.new(0)
      fine_str ->
        # Parse amounts like "£5,000" -> 5000.00
        case Regex.run(~r/[\d,]+\.?\d*/, fine_str) do
          [number_str] ->
            number_str
            |> String.replace(",", "")
            |> Decimal.new()
          _ -> Decimal.new(0)
        end
    end
  end
  
  defp extract_legal_reference(document) do
    act = extract_field(document, "Act")
    section = extract_field(document, "Section")
    
    case {act, section} do
      {act_val, section_val} when is_binary(act_val) and is_binary(section_val) ->
        "#{String.trim(act_val)} - #{String.trim(section_val)}"
      {act_val, _} when is_binary(act_val) -> String.trim(act_val)
      _ -> nil
    end
  end
  
  # Utility functions
  
  defp build_absolute_detail_url(relative_url) when is_binary(relative_url) do
    # Trim whitespace and newlines that may be present in HTML extraction
    cleaned_url = String.trim(relative_url)
    
    if String.starts_with?(cleaned_url, "http") do
      cleaned_url
    else
      # Handle relative URLs
      cleaned_url = String.trim_leading(cleaned_url, "/")
      "#{@detail_url_base}/#{cleaned_url}"
    end
  end
  
  defp build_absolute_detail_url(_), do: nil
  
  defp extract_record_id_from_url(nil), do: nil
  defp extract_record_id_from_url(url) when is_binary(url) do
    # Extract record ID from URLs like: registration/10000368?__pageState=result-enforcement-action
    case Regex.run(~r/registration\/(\d+)/, url) do
      [_, record_id] -> record_id
      _ -> 
        # Fallback: use URL hash
        :crypto.hash(:sha256, url) |> Base.encode16() |> String.slice(0, 8)
    end
  end
  
  defp parse_ea_date(date_string) when is_binary(date_string) do
    # Handle EA date formats: "05/11/2009", "2009-11-05", etc.
    cond do
      String.match?(date_string, ~r/^\d{2}\/\d{2}\/\d{4}$/) ->
        # DD/MM/YYYY format
        [day, month, year] = String.split(date_string, "/")
        Date.from_erl!({String.to_integer(year), String.to_integer(month), String.to_integer(day)})
        
      String.match?(date_string, ~r/^\d{4}-\d{2}-\d{2}$/) ->
        # ISO format
        Date.from_iso8601!(date_string)
        
      true ->
        Logger.warning("Unable to parse EA date: #{date_string}")
        nil
    end
  rescue
    error ->
      Logger.warning("Failed to parse EA date '#{date_string}': #{inspect(error)}")
      nil
  end
  
  defp parse_ea_date(_), do: nil
  
  @doc """
  Public function to collect summary records for a single action type.
  Used by individual processing workflow for real-time feedback.
  """
  def collect_summary_records_for_action_type(date_from, date_to, action_type, opts \\ []) do
    collect_summary_records_for_action_type(date_from, date_to, action_type, 1, 20, opts)
  end
  
  @doc """
  Public function to fetch detail record for individual processing.
  Used by individual processing workflow for real-time feedback.
  """
  def fetch_detail_record_individual(summary_record, opts \\ []) do
    fetch_detail_record(summary_record, opts)
  end

  # Test helpers - only available in test environment
  if Mix.env() == :test do
    def test_parse_summary_page(html, action_type), do: parse_summary_page(html, action_type)
    def test_parse_detail_page(html), do: parse_detail_page(html)
    def test_parse_ea_date(date_string), do: parse_ea_date(date_string)
    def test_extract_record_id_from_url(url), do: extract_record_id_from_url(url)
    def test_build_absolute_detail_url(url), do: build_absolute_detail_url(url)
    def test_extract_summary_record_from_row(row, action_type, timestamp), do: extract_summary_record_from_row(row, action_type, timestamp)
  end
end