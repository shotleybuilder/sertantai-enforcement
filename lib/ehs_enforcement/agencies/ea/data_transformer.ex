defmodule EhsEnforcement.Agencies.Ea.DataTransformer do
  @moduledoc """
  Transforms raw EA enforcement data into standardized format compatible 
  with existing HSE data structures and new EA Case resource extensions.

  Handles both EaDetailRecord structs from CaseScraper and raw EA data maps.
  """

  alias EhsEnforcement.Scraping.Ea.CaseScraper.EaDetailRecord

  @doc """
  Transform EA record into standardized format for Case resource creation.

  Accepts either %EaDetailRecord{} from CaseScraper or raw EA data map.
  Returns standardized data map ready for Case resource creation.
  """
  def transform_ea_record(%EaDetailRecord{} = ea_record) do
    # Handle offence deduplication - EA may show same offence multiple times in UI
    offence_unique_hash =
      generate_offence_unique_hash(
        ea_record.offence_description || "",
        ea_record.act || "",
        ea_record.section || ""
      )

    %{
      # Core identifiers
      ea_record_id: ea_record.ea_record_id,
      event_reference: ea_record.event_reference,

      # Company information
      offender_name: clean_company_name(ea_record.offender_name),
      company_registration_number: ea_record.company_registration_number,
      industry_sector: ea_record.industry_sector,
      address: normalize_address(ea_record.address),
      town: ea_record.town,
      county: ea_record.county,
      postcode: ea_record.postcode,

      # Enforcement details
      # Already parsed by CaseScraper
      action_date: ea_record.action_date,
      # Already normalized
      action_type: ea_record.action_type,
      total_fine: ea_record.total_fine || Decimal.new(0),
      offence_description: ea_record.offence_description,
      offence_unique_hash: offence_unique_hash,
      agency_function: normalize_agency_function(ea_record.agency_function),

      # Environmental impact
      water_impact: ea_record.water_impact,
      land_impact: ea_record.land_impact,
      air_impact: ea_record.air_impact,

      # Legal framework
      act: ea_record.act,
      section: ea_record.section,
      legal_reference:
        ea_record.legal_reference || build_legal_reference(ea_record.act, ea_record.section),

      # Metadata
      scraped_at: ea_record.scraped_at || DateTime.utc_now(),

      # Integration mapping (use existing HSE schema fields)
      agency_code: :ea,
      # Use EA record ID from URL as unique identifier
      regulator_id: ea_record.ea_record_id,
      # Store EA case reference separately (not unique)
      case_reference: ea_record.case_reference,
      # Maps to existing regulator_url column
      regulator_url: ea_record.detail_url,
      offence_action_type: map_to_hse_action_type(ea_record.action_type)
    }
  end

  def transform_ea_record(raw_ea_data) when is_map(raw_ea_data) do
    # Handle raw EA data map (legacy support)
    # Handle offence deduplication - EA may show same offence multiple times in UI
    offence_unique_hash =
      generate_offence_unique_hash(
        raw_ea_data.offence_description || "",
        raw_ea_data.act || "",
        raw_ea_data.section || ""
      )

    %{
      # Core identifiers
      ea_record_id: generate_ea_record_id(raw_ea_data),
      event_reference: raw_ea_data.event_reference,

      # Company information
      offender_name: clean_company_name(raw_ea_data.offender_name),
      company_registration_number: raw_ea_data.company_registration_number,
      industry_sector: raw_ea_data.industry_sector,
      address: normalize_address(raw_ea_data.address),
      town: raw_ea_data.town,
      county: raw_ea_data.county,
      postcode: raw_ea_data.postcode,

      # Enforcement details
      action_date: parse_ea_date(raw_ea_data.action_date),
      action_type: normalize_action_type(raw_ea_data.action_type),
      total_fine: parse_fine_amount(raw_ea_data.total_fine),
      offence_description: raw_ea_data.offence_description,
      offence_unique_hash: offence_unique_hash,
      agency_function: normalize_agency_function(raw_ea_data.agency_function),
      offence_type: raw_ea_data.offence_type,

      # Environmental impact
      water_impact: raw_ea_data.water_impact,
      land_impact: raw_ea_data.land_impact,
      air_impact: raw_ea_data.air_impact,

      # Legal framework
      act: raw_ea_data.act,
      section: raw_ea_data.section,
      legal_reference: build_legal_reference(raw_ea_data.act, raw_ea_data.section),

      # Metadata
      scraped_at: DateTime.utc_now(),

      # Integration mapping (use existing HSE schema fields)
      agency_code: :ea,
      # Use EA record ID from URL as unique identifier
      regulator_id: generate_ea_record_id(raw_ea_data),
      # Store EA case reference separately (not unique)
      case_reference: raw_ea_data.case_reference,
      # Maps to existing regulator_url column
      regulator_url: build_record_url(raw_ea_data),
      offence_action_type: map_to_hse_action_type(raw_ea_data.action_type)
    }
  end

  defp generate_ea_record_id(data) do
    # Create stable ID from offender name, date, and action type
    identifier = "#{data.offender_name}|#{data.action_date}|#{data.action_type}"
    :crypto.hash(:sha256, identifier) |> Base.encode16() |> String.slice(0, 16)
  end

  defp generate_offence_unique_hash(offence_description, act, section) do
    # Generate unique hash to prevent duplicate offence storage
    # EA UI may show same offence multiple times, but we store once
    content =
      "#{String.trim(offence_description)}|#{String.trim(act || "")}|#{String.trim(section || "")}"

    :crypto.hash(:sha256, content) |> Base.encode16() |> String.slice(0, 12)
  end

  defp clean_company_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  defp clean_company_name(nil), do: nil

  defp normalize_address(address) when is_binary(address) do
    address
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  defp normalize_address(nil), do: nil

  defp parse_ea_date(date_string) when is_binary(date_string) do
    # TODO: Handle various EA date formats
    # Common formats: "DD/MM/YYYY", "YYYY-MM-DD", etc.
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        date

      {:error, _} ->
        # Try other date formats
        parse_alternative_date_formats(date_string)
    end
  end

  defp parse_ea_date(date) when is_struct(date, Date), do: date
  defp parse_ea_date(_), do: nil

  defp parse_alternative_date_formats(_date_string) do
    # TODO: Handle DD/MM/YYYY and other formats
    nil
  end

  defp parse_fine_amount(fine_string) when is_binary(fine_string) do
    # Parse fine amounts like "£5000" -> 5000.00
    fine_string
    |> String.replace(~r/[£,\s]/, "")
    |> case do
      "" ->
        Decimal.new(0)

      amount_str ->
        case Decimal.cast(amount_str) do
          {:ok, decimal} -> decimal
          :error -> Decimal.new(0)
        end
    end
  end

  defp parse_fine_amount(amount) when is_number(amount), do: Decimal.new(amount)
  defp parse_fine_amount(_), do: Decimal.new(0)

  defp normalize_action_type(action_type_url) do
    cond do
      is_binary(action_type_url) and String.contains?(action_type_url, "court-case") ->
        :court_case

      is_binary(action_type_url) and String.contains?(action_type_url, "caution") ->
        :caution

      is_binary(action_type_url) and String.contains?(action_type_url, "enforcement-notice") ->
        :enforcement_notice

      is_atom(action_type_url) ->
        action_type_url

      true ->
        :unknown
    end
  end

  defp normalize_agency_function(function) when is_binary(function) do
    function
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_agency_function(_), do: nil

  defp build_record_url(data) do
    # Build EA enforcement detail page URL
    # Format: https://environment.data.gov.uk/public-register/enforcement-action/registration/{record_id}
    record_id = data.ea_record_id || extract_record_id_from_url(data.enforcement_page_url)
    "https://environment.data.gov.uk/public-register/enforcement-action/registration/#{record_id}"
  end

  defp extract_record_id_from_url(url) when is_binary(url) do
    # Extract record ID from URLs like: registration/10000368?__pageState=result-enforcement-action
    case Regex.run(~r/registration\/(\d+)/, url) do
      [_, record_id] -> record_id
      _ -> "unknown"
    end
  end

  defp extract_record_id_from_url(_), do: "unknown"

  defp build_legal_reference(act, section) when is_binary(act) and is_binary(section) do
    "#{String.trim(act)} - #{String.trim(section)}"
  end

  defp build_legal_reference(act, _) when is_binary(act), do: String.trim(act)
  defp build_legal_reference(_, _), do: nil

  defp generate_regulator_id_from_detail(%EaDetailRecord{} = ea_record) do
    # Generate EA-style regulator ID from EaDetailRecord
    date_part =
      case ea_record.action_date do
        %Date{} = date -> date |> Date.to_string() |> String.replace("-", "")
        _ -> "00000000"
      end

    action_code =
      case ea_record.action_type do
        :court_case -> "CC"
        :caution -> "CA"
        :enforcement_notice -> "EN"
        _ -> "XX"
      end

    record_id_part = String.slice(ea_record.ea_record_id || "0000", 0, 4)
    "EA-#{date_part}-#{action_code}-#{record_id_part}"
  end

  defp generate_regulator_id(data) do
    # Generate EA-style regulator ID similar to HSE format
    date_part = data.action_date |> Date.to_string() |> String.replace("-", "")

    action_code =
      case data.action_type do
        :court_case -> "CC"
        :caution -> "CA"
        :enforcement_notice -> "EN"
        _ -> "XX"
      end

    "EA-#{date_part}-#{action_code}-#{String.slice(data.ea_record_id, 0, 4)}"
  end

  defp map_to_hse_action_type(ea_action_type) do
    # Map EA action types to existing HSE action type taxonomy
    case ea_action_type do
      :court_case -> "Court Case"
      :caution -> "Formal Caution"
      :enforcement_notice -> "Enforcement Notice"
      _ -> "Other"
    end
  end
end
