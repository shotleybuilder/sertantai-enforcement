defmodule EhsEnforcement.Scraping.Ea.HistoricalScraper do
  @moduledoc """
  Handles systematic historical scraping of EA enforcement data.
  Manages date range chunking to handle 2000-record limits.
  """

  require Logger
  alias EhsEnforcement.Scraping.Ea.CaseScraper

  # Year ranges optimized based on expected enforcement volume
  @year_ranges [
    # Early years (likely lower volume)
    {2000, 2005}, {2006, 2010}, {2011, 2015}, 
    # Recent years (likely higher volume - yearly)
    {2016, 2016}, {2017, 2017}, {2018, 2018}, {2019, 2019},
    {2020, 2020}, {2021, 2021}, {2022, 2022}, {2023, 2023}, {2024, 2024}
  ]

  def scrape_historical_enforcement_data do
    for {start_year, end_year} <- @year_ranges do
      for action_type <- [:court_case, :caution, :enforcement_notice] do
        scrape_year_range(start_year, end_year, action_type)
        Process.sleep(5000)  # 5 second pause between ranges
      end
    end
  end
  
  defp scrape_year_range(start_year, end_year, action_type) do
    date_from = Date.new!(start_year, 1, 1)
    date_to = Date.new!(end_year, 12, 31)
    
    # Always attempt full year first - will hit 2000-record limit and paginate if needed
    case CaseScraper.scrape_enforcement_actions(date_from, date_to, action_type) do
      {:ok, results} when length(results) == 2000 ->
        # Hit the limit - this year needs to be split into smaller chunks
        Logger.warning("Year range #{start_year}-#{end_year} #{action_type} hit 2000-record limit, splitting into quarters")
        scrape_quarterly_chunks(start_year, end_year, action_type)
        
      {:ok, results} ->
        # Successfully scraped all records for this period
        Logger.info("Scraped #{length(results)} #{action_type} records for #{start_year}-#{end_year}")
        {:ok, results}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp scrape_quarterly_chunks(start_year, end_year, action_type) do
    # Split into quarterly chunks when annual scraping hits 2000-record limit
    quarters = generate_quarterly_ranges(start_year, end_year)
    
    Enum.reduce_while(quarters, {:ok, []}, fn {q_start, q_end}, {:ok, acc} ->
      case CaseScraper.scrape_enforcement_actions(q_start, q_end, action_type) do
        {:ok, results} ->
          Process.sleep(5000)  # 5 second pause between quarters
          {:cont, {:ok, acc ++ results}}
          
        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end
  
  defp generate_quarterly_ranges(_start_year, _end_year) do
    # TODO: Generate quarterly date ranges for given year span
    # - Q1: Jan-Mar, Q2: Apr-Jun, Q3: Jul-Sep, Q4: Oct-Dec
    []
  end
end