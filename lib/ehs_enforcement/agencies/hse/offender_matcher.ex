defmodule EhsEnforcement.Agencies.Hse.OffenderMatcher do
  @moduledoc """
  Matches HSE enforcement records to existing offenders or creates new ones.
  Handles company name variations, address normalization, and HSE-specific business logic.
  """

  require Logger
  alias EhsEnforcement.Enforcement

  @doc """
  Find or create offender from HSE case/notice data.
  
  Uses hierarchical matching strategy:
  1. Exact name + postcode match (highest confidence)
  2. Exact name match (high confidence)
  3. Fuzzy name matching using pg_trgm (medium confidence)
  4. Create new offender (fallback)
  """
  def find_or_create_offender(hse_data) when is_map(hse_data) do
    normalized_name = normalize_company_name(hse_data.offender_name || hse_data[:offender_name])
    postcode = extract_postcode_from_hse_data(hse_data)
    
    Logger.debug("HSE: Finding/creating offender for #{normalized_name}, postcode: #{postcode}")
    
    # 1. Exact name + postcode match (highest confidence)
    case find_by_exact_name_and_postcode(normalized_name, postcode) do
      {:ok, offender} -> 
        Logger.debug("HSE: Found exact name+postcode match for #{normalized_name}")
        update_offender_agencies(offender, :hse)
        
      {:error, :not_found} ->
        # 2. Exact name match (high confidence)
        case find_by_exact_name(normalized_name) do
          {:ok, offender} -> 
            Logger.debug("HSE: Found exact name match for #{normalized_name}")
            update_offender_agencies(offender, :hse)
            
          {:error, :not_found} ->
            # 3. Fuzzy name matching using pg_trgm (medium confidence)
            case find_by_fuzzy_name(normalized_name) do
              {:ok, offender} -> 
                Logger.debug("HSE: Found fuzzy name match for #{normalized_name}")
                update_offender_agencies(offender, :hse)
                
              {:error, :not_found} ->
                # 4. Create new offender
                Logger.debug("HSE: Creating new offender for #{normalized_name}")
                create_hse_offender(hse_data)
            end
        end
    end
  end

  defp find_by_exact_name_and_postcode(normalized_name, postcode) when is_binary(postcode) do
    case Enforcement.get_offender_by_name_and_postcode(normalized_name, postcode) do
      {:ok, offender} -> {:ok, offender}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end
  defp find_by_exact_name_and_postcode(normalized_name, nil) do
    # No postcode available, skip to name-only matching
    find_by_exact_name(normalized_name)
  end
  
  defp find_by_exact_name(normalized_name) do
    case Enforcement.get_offender_by_name_and_postcode(normalized_name, nil) do
      {:ok, offender} -> {:ok, offender}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp find_by_fuzzy_name(normalized_name, similarity_threshold \\ 0.85) do
    case Enforcement.fuzzy_search_offenders(normalized_name, similarity_threshold: similarity_threshold, limit: 1) do
      {:ok, [offender | _]} -> {:ok, offender}
      {:ok, []} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_hse_offender(hse_data) do
    offender_attrs = %{
      name: hse_data.offender_name || hse_data[:offender_name],
      normalized_name: normalize_company_name(hse_data.offender_name || hse_data[:offender_name]),
      address: normalize_address(hse_data.offender_address || hse_data[:offender_address]),
      postcode: extract_postcode_from_hse_data(hse_data),
      local_authority: hse_data.offender_local_authority || hse_data[:offender_local_authority],
      country: hse_data.offender_country || hse_data[:offender_country] || "England",
      main_activity: hse_data.offender_main_activity || hse_data[:offender_main_activity],
      industry: normalize_hse_industry(hse_data.offender_industry || hse_data[:offender_industry]),
      sic_code: hse_data.offender_sic || hse_data[:offender_sic],
      business_type: determine_business_type(hse_data.offender_name || hse_data[:offender_name]),
      agencies: [:hse]
    }
    
    # Remove nil values to keep attrs clean
    clean_attrs = offender_attrs
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
    
    case Enforcement.create_offender(clean_attrs) do
      {:ok, offender} -> 
        Logger.info("HSE: Created new offender: #{offender.name}")
        {:ok, offender}
      {:error, reason} -> 
        Logger.error("HSE: Failed to create offender: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp update_offender_agencies(offender, agency) do
    current_agencies = offender.agencies || []
    
    if agency in current_agencies do
      {:ok, offender}  # Agency already tracked
    else
      updated_agencies = [agency | current_agencies] |> Enum.uniq()
      
      case Enforcement.update_offender(offender, %{agencies: updated_agencies}) do
        {:ok, updated_offender} ->
          Logger.debug("HSE: Updated offender agencies for #{offender.name}")
          {:ok, updated_offender}
        {:error, reason} ->
          Logger.warning("HSE: Failed to update offender agencies: #{inspect(reason)}")
          {:ok, offender}  # Return original offender, don't fail the match
      end
    end
  end

  # Private helper functions

  defp normalize_company_name(nil), do: "Unknown Company"
  defp normalize_company_name(""), do: "Unknown Company"
  defp normalize_company_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.upcase()
    |> String.replace(~r/\bLIMITED\b/, "LTD")
    |> String.replace(~r/\bCOMPANY\b/, "CO")  
    |> String.replace(~r/\bAND\b/, "&")
    |> String.replace(~r/\s+/, " ")  # Normalize whitespace
  end

  defp normalize_address(nil), do: nil
  defp normalize_address(""), do: nil
  defp normalize_address(address) when is_binary(address) do
    address
    |> String.trim()
    |> String.replace(~r/\s+/, " ")  # Normalize whitespace
    |> String.replace(~r/,\s*,/, ",")  # Remove duplicate commas
  end

  defp extract_postcode_from_hse_data(hse_data) do
    # Try specific postcode field first, then extract from address
    case hse_data.postcode || hse_data[:postcode] do
      nil -> extract_postcode_from_address(hse_data.offender_address || hse_data[:offender_address])
      "" -> extract_postcode_from_address(hse_data.offender_address || hse_data[:offender_address])
      postcode -> normalize_postcode(postcode)
    end
  end

  defp extract_postcode_from_address(nil), do: nil
  defp extract_postcode_from_address(""), do: nil
  defp extract_postcode_from_address(address) when is_binary(address) do
    # UK postcode pattern extraction
    case Regex.run(~r/([A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2})$/i, address) do
      [_, postcode] -> normalize_postcode(postcode)
      _ -> nil
    end
  end

  defp normalize_postcode(postcode) when is_binary(postcode) do
    postcode
    |> String.trim()
    |> String.upcase()
    |> String.replace(~r/\s+/, " ")  # Normalize internal spacing
  end

  defp normalize_hse_industry(nil), do: "Unknown"
  defp normalize_hse_industry(""), do: "Unknown"
  defp normalize_hse_industry(industry) when is_binary(industry) do
    # Map HSE industry categories to standard classifications
    case String.downcase(String.trim(industry)) do
      "agriculture hunting forestry and fishing" -> "Agriculture hunting forestry and fishing"
      "construction" -> "Construction"
      "extractive and utility supply industries" -> "Extractive and utility supply industries"
      "manufacturing" -> "Manufacturing"
      "total service industries" -> "Total service industries"
      industry_string -> String.trim(industry_string)
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
      # Check for individual indicators
      Regex.match?(~r/\bMr\.?\b|\bMs\.?\b|\bMrs\.?\b|\bMiss\.?\b/i, company_name) -> :individual
      # If no business indicators, assume other
      true -> :other
    end
  end
end