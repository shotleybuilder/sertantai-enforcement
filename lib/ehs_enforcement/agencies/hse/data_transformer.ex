defmodule EhsEnforcement.Agencies.Hse.DataTransformer do
  @moduledoc """
  Transforms raw HSE enforcement data into standardized format compatible 
  with Ash Case and Notice resource structures.

  Handles both case and notice data from HSE scrapers, providing consistent
  data transformation for Ash resource creation.
  """

  @doc """
  Transform HSE case record into standardized format for Case resource creation.

  Accepts raw HSE case data map from HSE case scraper.
  Returns standardized data map ready for Case resource creation.
  """
  def transform_hse_case(hse_case_data) when is_map(hse_case_data) do
    %{
      # Core identifiers
      regulator_id: hse_case_data.regulator_id,
      agency_code: :hse,

      # Company information  
      offender_name: clean_company_name(hse_case_data.offender_name),
      address: normalize_address(hse_case_data.offender_address),
      local_authority: hse_case_data.offender_local_authority,
      postcode: extract_postcode_from_address(hse_case_data.offender_address),
      main_activity: hse_case_data.offender_main_activity,
      industry: hse_case_data.offender_industry,
      sic_code: hse_case_data.offender_sic,
      business_type: determine_business_type(hse_case_data.offender_name),

      # Enforcement details
      action_date: parse_hse_date(hse_case_data.offence_action_date),
      hearing_date: parse_hse_date(hse_case_data.offence_hearing_date),
      action_type: normalize_hse_action_type(hse_case_data.offence_action_type),
      result: hse_case_data.offence_result,
      fine_amount: parse_fine_amount(hse_case_data.offence_fine),
      costs: parse_fine_amount(hse_case_data.offence_costs),
      description: hse_case_data.offence_description,
      breaches: format_breaches(hse_case_data.offence_breaches),
      breaches_clean: hse_case_data.offence_breaches_clean,
      regulator_function: normalize_hse_function(hse_case_data.regulator_function),
      regulator_url: hse_case_data.regulator_url,
      related_cases: hse_case_data.related_cases,

      # Metadata
      scraped_at: DateTime.utc_now(),
      last_synced_at: DateTime.utc_now()
    }
  end

  @doc """
  Transform HSE notice record into standardized format for Notice resource creation.

  Accepts raw HSE notice data map from HSE notice scraper.
  Returns standardized data map ready for Notice resource creation.
  """
  def transform_hse_notice(hse_notice_data) when is_map(hse_notice_data) do
    %{
      # Core identifiers
      regulator_id: hse_notice_data.regulator_id,
      agency_code: :hse,

      # Company information
      offender_name: clean_company_name(hse_notice_data.offender_name),
      local_authority: hse_notice_data.offender_local_authority,
      country: hse_notice_data.offender_country,
      sic_code: hse_notice_data.offender_sic,
      main_activity: hse_notice_data.offender_main_activity,
      industry: hse_notice_data.offender_industry,
      address: hse_notice_data.offender_address,
      business_type: determine_business_type(hse_notice_data.offender_name),

      # Notice details
      notice_date: parse_hse_date(hse_notice_data.offence_action_date),
      # HSE doesn't provide operative dates
      operative_date: nil,
      compliance_date: parse_hse_date(hse_notice_data.offence_compliance_date),
      revised_compliance_date: parse_hse_date(hse_notice_data.offence_revised_compliance_date),
      notice_type: normalize_hse_action_type(hse_notice_data.offence_action_type),
      notice_body: hse_notice_data.offence_description,
      breaches: format_breaches(hse_notice_data.offence_breaches),
      result: hse_notice_data.offence_result,
      regulator_function: normalize_hse_function(hse_notice_data.regulator_function),
      regulator_url: build_hse_notice_url(hse_notice_data.regulator_id),

      # Metadata
      scraped_at: DateTime.utc_now(),
      last_synced_at: DateTime.utc_now()
    }
  end

  # Private helper functions

  defp clean_company_name(nil), do: "Unknown"
  defp clean_company_name(""), do: "Unknown"

  defp clean_company_name(name) when is_binary(name) do
    name
    |> String.trim()
    # Normalize whitespace
    |> String.replace(~r/\s+/, " ")
  end

  defp normalize_address(nil), do: nil
  defp normalize_address(""), do: nil

  defp normalize_address(address) when is_binary(address) do
    address
    |> String.trim()
    # Normalize whitespace
    |> String.replace(~r/\s+/, " ")
    # Remove duplicate commas
    |> String.replace(~r/,\s*,/, ",")
  end

  defp extract_postcode_from_address(nil), do: nil
  defp extract_postcode_from_address(""), do: nil

  defp extract_postcode_from_address(address) when is_binary(address) do
    # Extract UK postcode pattern from address
    case Regex.run(~r/([A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2})$/i, address) do
      [_, postcode] -> String.upcase(postcode)
      _ -> nil
    end
  end

  defp determine_business_type(nil), do: :other
  defp determine_business_type(""), do: :other

  defp determine_business_type(company_name) when is_binary(company_name) do
    cond do
      Regex.match?(~r/\bLimited\b|\bLtd\.?\b/i, company_name) -> :limited_company
      Regex.match?(~r/\bPLC\b|\bplc\b/i, company_name) -> :plc
      Regex.match?(~r/\bLLP\b|\bllp\b/i, company_name) -> :partnership
      Regex.match?(~r/\bLLC\b|\bllc\b/i, company_name) -> :limited_company
      Regex.match?(~r/\bInc\.?\b|\bIncorporated\b/i, company_name) -> :limited_company
      Regex.match?(~r/\bCorp\.?\b|\bCorporation\b/i, company_name) -> :limited_company
      true -> :other
    end
  end

  defp parse_hse_date(nil), do: nil
  defp parse_hse_date(""), do: nil
  defp parse_hse_date(%Date{} = date), do: date

  defp parse_hse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> try_parse_other_formats(date_string)
    end
  end

  defp try_parse_other_formats(date_string) do
    # Try DD/MM/YYYY format
    case Regex.run(~r/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/, String.trim(date_string)) do
      [_, day, month, year] ->
        case Date.new(String.to_integer(year), String.to_integer(month), String.to_integer(day)) do
          {:ok, date} -> date
          {:error, _} -> nil
        end

      _ ->
        nil
    end
  end

  defp normalize_hse_action_type(nil), do: "Other"
  defp normalize_hse_action_type(""), do: "Other"

  defp normalize_hse_action_type(action_type) when is_binary(action_type) do
    case String.downcase(String.trim(action_type)) do
      "court case" -> "Court Case"
      "improvement notice" -> "Improvement Notice"
      "prohibition notice" -> "Prohibition Notice"
      "formal caution" -> "Formal Caution"
      action -> String.trim(action)
    end
  end

  defp parse_fine_amount(nil), do: Decimal.new(0)
  defp parse_fine_amount(""), do: Decimal.new(0)

  defp parse_fine_amount(amount) when is_binary(amount) do
    # Remove currency symbols and parse
    clean_amount =
      amount
      |> String.replace(~r/[£,$\s]/, "")
      |> String.trim()

    case Decimal.parse(clean_amount) do
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end

  defp parse_fine_amount(%Decimal{} = amount), do: amount
  defp parse_fine_amount(amount) when is_number(amount), do: Decimal.from_float(amount)

  defp format_breaches(nil), do: nil
  defp format_breaches([]), do: nil

  defp format_breaches(breaches) when is_list(breaches) do
    breaches
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] -> nil
      formatted -> Enum.join(formatted, "; ")
    end
  end

  defp format_breaches(breach) when is_binary(breach) do
    case String.trim(breach) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_hse_function(nil), do: "Health and Safety"
  defp normalize_hse_function(""), do: "Health and Safety"

  defp normalize_hse_function(function) when is_binary(function) do
    "HSE - #{String.trim(function)}"
  end

  defp build_hse_notice_url(nil), do: nil
  defp build_hse_notice_url(""), do: nil

  defp build_hse_notice_url(notice_id) when is_binary(notice_id) do
    "https://resources.hse.gov.uk/notices/notices/notice_details.asp?SF=CN&SV=#{notice_id}"
  end
end
