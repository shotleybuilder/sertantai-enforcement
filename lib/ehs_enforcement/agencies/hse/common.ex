defmodule EhsEnforcement.Agencies.Hse.Common do
  @moduledoc """

  """

  def pages_picker do
    page_number = ExPrompt.get("Page number(s)?")

    case String.split(page_number, ",") do
      [] -> IO.puts("No page numbers entered.")
      [page] -> page
      [page1, page2] -> Range.new(String.to_integer(page1), String.to_integer(page2))
    end
  end

  def country_picker do
    case ExPrompt.choose("Country?", ["England", "Scotland", "Wales", "Northern Ireland"]) do
      -1 -> IO.puts("Invalid selection.")
      0 -> "England"
      1 -> "Scotland"
      2 -> "Wales"
      3 -> "Northern Ireland"
    end
  end

  def offender_business_type(offender_name) do
    cond do
      Regex.match?(~r/LLC|llc/, offender_name) -> "LLC"
      Regex.match?(~r/[Ii]nc$/, offender_name) -> "INC"
      Regex.match?(~r/[ ][Cc]orp[. ]/, offender_name) -> "CORP"
      Regex.match?(~r/PLC|[Pp]lc/, offender_name) -> "PLC"
      Regex.match?(~r/[Ll]imited|LIMITED|Ltd|LTD|Lld/, offender_name) -> "LTD"
      Regex.match?(~r/LLP|[Ll]lp/, offender_name) -> "LLP"
      true -> "SOLE"
    end
  end

  def offender_index(offender_name) do
    String.upcase(String.slice(offender_name, 0, 1))
  end
end
