defmodule EhsEnforcement.Agencies.Ea.OffenderBuilder do
  @moduledoc """
  Builds offender attributes for EA (Environment Agency) enforcement data.

  This module consolidates offender attribute building logic that was previously
  duplicated across EA.CaseProcessor and EA.NoticeProcessor.

  ## Usage

  For case data (EaDetailRecord):
      iex> ea_record = %EaDetailRecord{offender_name: "ABC Water Treatment Ltd", ...}
      iex> OffenderBuilder.build_offender_attrs(ea_record, :case)
      %{name: "ABC Water Treatment Ltd", business_type: :limited_company, ...}

  For notice data (map):
      iex> notice_data = %{offender_name: "XYZ Environmental Services", ...}
      iex> OffenderBuilder.build_offender_attrs(notice_data, :notice)
      %{offender_name: "XYZ Environmental Services", ...}

  ## Data Types

  - `:case` - EA case data from enforcement action scraping
  - `:notice` - EA notice data from notice scraping

  ## EA-Specific Fields

  EA offenders include unique fields not present in HSE data:
  - `:company_registration_number` - Company registration number
  - `:town` - Town (separate from address)
  - `:county` - County
  - `:postcode` - Postcode
  - `:industry_sector` - EA industry classification
  """

  alias EhsEnforcement.Scraping.Ea.CaseScraper.EaDetailRecord
  alias EhsEnforcement.Scraping.Shared.BusinessTypeDetector

  @doc """
  Builds offender attributes from EA case or notice data.

  ## Parameters

  - `data` - Either an `%EaDetailRecord{}` struct (for cases) or a map (for notices)
  - `data_type` - Either `:case` or `:notice` to indicate the data source

  ## Returns

  A map of offender attributes with:
  - Common fields: `:name`, `:address`, `:business_type`
  - EA case fields: `:local_authority`, `:postcode`, `:main_activity`, `:industry`,
    `:company_registration_number`, `:town`, `:county`
  - EA notice fields: `:offender_name`, `:offender_address`, `:company_registration_number`,
    `:industry_sector`

  Nil and empty string values are automatically filtered out.

  ## Examples

      # Case data
      ea_record = %EaDetailRecord{
        offender_name: "ABC Water Ltd",
        county: "Yorkshire",
        industry_sector: "Water Supply"
      }
      OffenderBuilder.build_offender_attrs(ea_record, :case)
      # => %{
      #   name: "ABC Water Ltd",
      #   business_type: :limited_company,
      #   local_authority: "Yorkshire",
      #   industry: "Extractive and utility supply industries"
      # }

      # Notice data
      notice_data = %{
        offender_name: "XYZ Environmental Services",
        address: "123 Green Street",
        town: "Manchester",
        county: "Greater Manchester"
      }
      OffenderBuilder.build_offender_attrs(notice_data, :notice)
      # => %{
      #   offender_name: "XYZ Environmental Services",
      #   offender_address: "123 Green Street, Manchester, Greater Manchester"
      # }
  """
  def build_offender_attrs(data, :case) when is_struct(data, EaDetailRecord) do
    build_case_offender_attrs(data)
  end

  def build_offender_attrs(data, :notice) when is_map(data) do
    build_notice_offender_attrs(data)
  end

  # Private Functions

  defp build_case_offender_attrs(%EaDetailRecord{} = ea_record) do
    base_attrs = %{
      name: ea_record.offender_name,
      address: build_full_address(ea_record),
      # Use county as local authority
      local_authority: ea_record.county,
      postcode: ea_record.postcode,
      main_activity: ea_record.industry_sector,
      industry: map_ea_industry_to_hse_category(ea_record.industry_sector),

      # EA-specific fields
      company_registration_number: ea_record.company_registration_number,
      town: ea_record.town,
      county: ea_record.county
    }

    # Add business type detection
    enhanced_attrs =
      base_attrs
      |> Map.put(:business_type, determine_and_normalize_business_type(ea_record.offender_name))

    # Remove nil values to keep attrs clean
    enhanced_attrs
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
  end

  defp build_notice_offender_attrs(ea_detail_record) do
    # Build offender attributes map from EA detail record
    # Clean up company registration number (remove "(opens in new tab)" text)
    company_reg =
      case Map.get(ea_detail_record, :company_registration_number) do
        nil ->
          nil

        reg when is_binary(reg) ->
          reg
          |> String.replace(~r/\s*\(opens in new tab\)/, "")
          |> String.trim()
          |> case do
            "" -> nil
            cleaned -> cleaned
          end

        _ ->
          nil
      end

    # Build address string from components
    address_parts =
      [
        Map.get(ea_detail_record, :address),
        Map.get(ea_detail_record, :town),
        Map.get(ea_detail_record, :county),
        Map.get(ea_detail_record, :postcode)
      ]
      |> Enum.filter(&(&1 != nil && &1 != ""))
      |> Enum.join(", ")

    offender_address = if address_parts == "", do: nil, else: address_parts

    %{
      offender_name: Map.get(ea_detail_record, :offender_name),
      offender_address: offender_address,
      company_registration_number: company_reg,
      industry_sector: Map.get(ea_detail_record, :industry_sector)
    }
  end

  defp build_full_address(%EaDetailRecord{} = ea_record) do
    [ea_record.address, ea_record.town, ea_record.county, ea_record.postcode]
    |> Enum.filter(&(&1 != nil and &1 != ""))
    |> Enum.join(", ")
  end

  defp map_ea_industry_to_hse_category(nil), do: "Unknown"

  defp map_ea_industry_to_hse_category(ea_industry) when is_binary(ea_industry) do
    ea_lower = String.downcase(ea_industry)

    cond do
      String.contains?(ea_lower, "manufacturing") ->
        "Manufacturing"

      String.contains?(ea_lower, "construction") ->
        "Construction"

      String.contains?(ea_lower, ["water", "supply", "utility"]) ->
        "Extractive and utility supply industries"

      String.contains?(ea_lower, ["agriculture", "farming", "forestry", "fishing"]) ->
        "Agriculture hunting forestry and fishing"

      String.contains?(ea_lower, ["service", "management", "transport", "retail"]) ->
        "Total service industries"

      true ->
        "Unknown"
    end
  end

  defp determine_and_normalize_business_type(offender_name) do
    offender_name
    |> BusinessTypeDetector.determine_business_type()
    |> BusinessTypeDetector.normalize_business_type()
  end
end
