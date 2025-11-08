defmodule EhsEnforcement.Agencies.Ea.OffenderMatcher do
  @moduledoc """
  Matches EA enforcement records to existing offenders or creates new ones.
  Handles company name variations and address normalization.
  """

  require Logger
  alias EhsEnforcement.Enforcement

  def find_or_create_offender(ea_case_data) do
    company_number = Map.get(ea_case_data, :company_registration_number)

    # 1. Try company registration number first (if available)
    # This is the most authoritative identifier - same number = same legal entity
    case find_by_company_number(company_number) do
      {:ok, offender} ->
        Logger.debug(
          "Found existing offender by company number #{company_number}: #{offender.name}"
        )

        {:ok, offender}

      {:error, :not_found} ->
        # 2. Fall back to exact name match
        case find_by_exact_name(ea_case_data.offender_name) do
          {:ok, offender} ->
            {:ok, offender}

          {:error, :not_found} ->
            # 3. Fall back to fuzzy name matching using pg_trgm
            case find_by_fuzzy_name(ea_case_data.offender_name) do
              {:ok, offender} ->
                {:ok, offender}

              {:error, :not_found} ->
                # 4. Create new offender with company number
                create_ea_offender(ea_case_data)
            end
        end

      {:error, :invalid_company_number} ->
        # No valid company number, skip to name matching
        case find_by_exact_name(ea_case_data.offender_name) do
          {:ok, offender} ->
            {:ok, offender}

          {:error, :not_found} ->
            case find_by_fuzzy_name(ea_case_data.offender_name) do
              {:ok, offender} ->
                {:ok, offender}

              {:error, :not_found} ->
                create_ea_offender(ea_case_data)
            end
        end
    end
  end

  defp find_by_company_number(nil), do: {:error, :invalid_company_number}
  defp find_by_company_number(""), do: {:error, :invalid_company_number}

  defp find_by_company_number(company_number) when is_binary(company_number) do
    # Clean the company number first
    alias EhsEnforcement.Integrations.CompaniesHouse
    cleaned_number = CompaniesHouse.clean_company_number(company_number)

    if cleaned_number == nil or cleaned_number == "" do
      {:error, :invalid_company_number}
    else
      # Query by company_registration_number using Ash
      require Ash.Query

      query =
        Enforcement.Offender
        |> Ash.Query.filter(company_registration_number == ^cleaned_number)
        |> Ash.Query.limit(1)

      case Ash.read(query) do
        {:ok, [offender | _]} ->
          {:ok, offender}

        {:ok, []} ->
          {:error, :not_found}

        {:error, error} ->
          Logger.error("Error querying by company number: #{inspect(error)}")
          {:error, :not_found}
      end
    end
  end

  defp find_by_company_number(_), do: {:error, :invalid_company_number}

  defp find_by_exact_name(name) do
    normalized_name = normalize_company_name(name)

    case Enforcement.get_offender_by_name_and_postcode(normalized_name, nil) do
      {:ok, offender} -> {:ok, offender}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, :not_found}
    end
  end

  defp find_by_fuzzy_name(name, similarity_threshold \\ 0.8) do
    case Enforcement.fuzzy_search_offenders(name,
           similarity_threshold: similarity_threshold,
           limit: 1
         ) do
      {:ok, [offender | _]} -> {:ok, offender}
      {:ok, []} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_ea_offender(ea_case_data) do
    offender_attrs = %{
      name: ea_case_data.offender_name,
      address: ea_case_data.offender_address,
      postcode: extract_postcode(ea_case_data.offender_address),
      # EA tracks companies (use :limited_company enum value)
      business_type: :limited_company,
      # Use agency name strings
      agencies: ["Environment Agency"],
      # EA-specific fields
      company_registration_number: Map.get(ea_case_data, :company_registration_number),
      industry: Map.get(ea_case_data, :industry_sector),
      main_activity: infer_business_activity(ea_case_data),
      local_authority: extract_local_authority(ea_case_data.offender_address)
    }

    case Enforcement.create_offender(offender_attrs) do
      {:ok, offender} ->
        Logger.info("Created new EA offender: #{offender.name}")
        {:ok, offender}

      {:error, reason} ->
        Logger.error("Failed to create EA offender: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp normalize_company_name(name) do
    # Standardize common company suffixes and formats
    name
    |> String.trim()
    |> String.upcase()
    |> String.replace(~r/\bLIMITED\b/, "LTD")
    |> String.replace(~r/\bCOMPANY\b/, "CO")
    |> String.replace(~r/\s+/, " ")
  end

  defp extract_postcode(nil), do: nil

  defp extract_postcode(address) when is_binary(address) do
    # UK postcode extraction regex
    case Regex.run(~r/([A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2})/i, address) do
      [_, postcode] -> String.upcase(String.replace(postcode, " ", ""))
      nil -> nil
    end
  end

  defp extract_local_authority(_address) do
    # TODO: Implement local authority extraction from address
    # Could use postcode lookup or address parsing
    nil
  end

  defp infer_business_activity(_ea_case_data) do
    # TODO: Infer business activity from agency function and offence type
    # e.g., "Water Quality" -> "Water Treatment/Supply"
    # e.g., "Waste" -> "Waste Management" 
    nil
  end
end
