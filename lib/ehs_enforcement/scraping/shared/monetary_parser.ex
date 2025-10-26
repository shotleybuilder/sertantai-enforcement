defmodule EhsEnforcement.Scraping.Shared.MonetaryParser do
  @moduledoc """
  Shared utility for parsing monetary amounts from scraped text.

  This module consolidates monetary parsing logic that was previously
  duplicated across HSE scraper modules.

  ## Usage

      iex> MonetaryParser.parse_monetary_amount("£12,345.67")
      #Decimal<12345.67>

      iex> MonetaryParser.parse_monetary_amount("$1,000")
      #Decimal<1000>

      iex> MonetaryParser.parse_monetary_amount("invalid")
      #Decimal<0>
  """

  @doc """
  Parses a monetary amount from a string, extracting numeric value.

  Handles common formats:
  - Currency symbols (£, $, etc.) are ignored
  - Thousand separators (commas) are removed
  - Decimal points are preserved
  - Invalid inputs return Decimal.new("0")

  ## Parameters
  - `amount_str` - String containing monetary amount (e.g., "£12,345.67")

  ## Returns
  - Decimal representing the parsed amount, or Decimal.new("0") for invalid input
  """
  def parse_monetary_amount(amount_str) when is_binary(amount_str) do
    case Regex.run(~r/[\d,]+\.?\d*/, amount_str) do
      [number_str] ->
        number_str
        |> String.replace(",", "")
        |> Decimal.new()

      _ -> Decimal.new("0")
    end
  end

  def parse_monetary_amount(_), do: Decimal.new("0")
end
