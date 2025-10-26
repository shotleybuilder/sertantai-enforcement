defmodule EhsEnforcement.Scraping.Shared.BusinessTypeDetector do
  @moduledoc """
  Shared utility for detecting and normalizing business types from company names.

  This module consolidates business type detection logic that was previously
  duplicated across HSE and EA processors (4 files total).

  ## Usage

      iex> BusinessTypeDetector.determine_business_type("Acme Corporation Ltd")
      "LTD"

      iex> BusinessTypeDetector.determine_business_type("Smith & Sons LLC")
      "LLC"

      iex> BusinessTypeDetector.determine_business_type("John Smith")
      "SOLE"
  """

  @doc """
  Determines the business type based on company name patterns.

  Checks for common business entity suffixes and returns a standardized type code.

  ## Supported Types
  - LLC: Limited Liability Company
  - INC: Incorporated
  - CORP: Corporation
  - PLC: Public Limited Company
  - LTD: Limited (most common in UK)
  - LLP: Limited Liability Partnership
  - SOLE: Sole proprietor/trader (default)

  ## Parameters
  - `offender_name` - Company or individual name (string or nil)

  ## Returns
  - String representing business type code
  """
  def determine_business_type(nil), do: "SOLE"
  def determine_business_type(""), do: "SOLE"

  def determine_business_type(offender_name) when is_binary(offender_name) do
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

  @doc """
  Normalizes a business type string to a standard Ash enum value.

  Converts various business type representations into the enum values
  used by the Offender resource: `:limited_company`, `:individual`, `:partnership`, `:plc`, `:other`.

  ## Parameters
  - `business_type_string` - Business type code or description

  ## Returns
  - Atom representing the normalized business type for Ash resources
  """
  def normalize_business_type(nil), do: :individual
  def normalize_business_type(""), do: :individual

  def normalize_business_type(business_type_string) when is_binary(business_type_string) do
    case String.upcase(business_type_string) do
      "LTD" -> :limited_company
      "LIMITED" -> :limited_company
      "PLC" -> :plc
      "LLC" -> :limited_company
      "INC" -> :limited_company
      "CORP" -> :limited_company
      "LLP" -> :partnership
      "PARTNERSHIP" -> :partnership
      "SOLE" -> :individual
      _ -> :other
    end
  end

  def normalize_business_type(business_type) when is_atom(business_type) do
    # Already normalized
    business_type
  end
end
