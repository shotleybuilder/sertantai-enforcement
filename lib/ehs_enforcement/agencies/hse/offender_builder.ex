defmodule EhsEnforcement.Agencies.Hse.OffenderBuilder do
  @moduledoc """
  Builds offender attributes for HSE (Health and Safety Executive) enforcement data.

  This module consolidates offender attribute building logic that was previously
  duplicated across HSE.CaseProcessor and HSE.NoticeProcessor.

  ## Usage

  For case data:
      iex> case_data = %ScrapedCase{offender_name: "ABC Ltd", ...}
      iex> OffenderBuilder.build_offender_attrs(case_data, :case)
      %{name: "ABC Ltd", business_type: :limited_company, ...}

  For notice data:
      iex> notice_data = %{offender_name: "XYZ PLC", ...}
      iex> OffenderBuilder.build_offender_attrs(notice_data, :notice)
      %{name: "XYZ PLC", business_type: :plc, ...}

  ## Data Types

  - `:case` - HSE case data from conviction scraping
  - `:notice` - HSE notice data from notice scraping

  Both data types are transformed into a consistent offender attributes map
  suitable for use with `EhsEnforcement.Enforcement.Offender.find_or_create_offender/1`.
  """

  alias EhsEnforcement.Scraping.Shared.BusinessTypeDetector
  alias EhsEnforcement.Scraping.Hse.CaseScraper.ScrapedCase

  @doc """
  Builds offender attributes from HSE case or notice data.

  ## Parameters

  - `data` - Either a `%ScrapedCase{}` struct (for cases) or a map (for notices)
  - `data_type` - Either `:case` or `:notice` to indicate the data source

  ## Returns

  A map of offender attributes with:
  - Common fields: `:name`, `:business_type`
  - Case-specific fields: `:local_authority`, `:main_activity`, `:industry`
  - Notice-specific fields: `:local_authority`, `:sic_code`, `:main_activity`,
    `:industry`, `:address`, `:country`

  Nil and empty string values are automatically filtered out.

  ## Examples

      # Case data
      case_data = %ScrapedCase{
        offender_name: "ABC Ltd",
        offender_local_authority: "London",
        offender_main_activity: "Construction"
      }
      OffenderBuilder.build_offender_attrs(case_data, :case)
      # => %{
      #   name: "ABC Ltd",
      #   business_type: :limited_company,
      #   local_authority: "London",
      #   main_activity: "Construction"
      # }

      # Notice data
      notice_data = %{
        offender_name: "XYZ PLC",
        offender_local_authority: "Manchester",
        offender_sic: "1234",
        offender_address: "123 Main St"
      }
      OffenderBuilder.build_offender_attrs(notice_data, :notice)
      # => %{
      #   name: "XYZ PLC",
      #   business_type: :plc,
      #   local_authority: "Manchester",
      #   sic_code: "1234",
      #   address: "123 Main St"
      # }
  """
  def build_offender_attrs(data, :case) when is_struct(data, ScrapedCase) do
    build_case_offender_attrs(data)
  end

  def build_offender_attrs(data, :notice) when is_map(data) do
    build_notice_offender_attrs(data)
  end

  # Private Functions

  defp build_case_offender_attrs(%ScrapedCase{} = scraped_case) do
    base_attrs = %{
      name: scraped_case.offender_name,
      local_authority: scraped_case.offender_local_authority,
      main_activity: scraped_case.offender_main_activity,
      industry: scraped_case.offender_industry
    }

    # Add business type using shared BusinessTypeDetector
    enhanced_attrs = base_attrs
    |> Map.put(:business_type, determine_and_normalize_business_type(scraped_case.offender_name))

    # Remove nil values to keep attrs clean
    enhanced_attrs
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
  end

  defp build_notice_offender_attrs(notice_data) do
    base_attrs = %{
      name: notice_data[:offender_name] || notice_data.offender_name || "Unknown",
      local_authority: notice_data[:offender_local_authority],
      sic_code: notice_data[:offender_sic],
      main_activity: notice_data[:offender_main_activity],
      industry: notice_data[:offender_industry],
      address: notice_data[:offender_address],
      country: notice_data[:offender_country]
    }

    # Add business type using shared BusinessTypeDetector
    offender_name = notice_data[:offender_name] || notice_data.offender_name || ""
    enhanced_attrs = base_attrs
    |> Map.put(:business_type, determine_and_normalize_business_type(offender_name))

    # Remove nil values to keep attrs clean
    enhanced_attrs
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
  end

  defp determine_and_normalize_business_type(offender_name) do
    offender_name
    |> BusinessTypeDetector.determine_business_type()
    |> normalize_business_type()
  end

  defp normalize_business_type(business_type_string) do
    case business_type_string do
      "LTD" -> :limited_company
      "PLC" -> :plc
      "LLP" -> :partnership
      "LLC" -> :limited_company
      "INC" -> :limited_company
      "CORP" -> :limited_company
      "SOLE" -> :individual
      _ -> :other
    end
  end
end
