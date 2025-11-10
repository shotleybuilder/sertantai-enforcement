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

  ## Companies House Matching

  HSE data does not include Companies House registration numbers directly.
  This module provides `match_companies_house_number/1` to automatically
  search and match companies using the Companies House API.
  """

  require Logger

  alias EhsEnforcement.Scraping.Shared.BusinessTypeDetector
  alias EhsEnforcement.Scraping.Hse.CaseScraper.ScrapedCase
  alias EhsEnforcement.Integrations.CompaniesHouse

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

  @doc """
  Attempts to match an HSE offender to a Companies House registration number.

  Uses a hybrid 3-tier matching strategy:
  - High confidence: Auto-match and return company_registration_number
  - Medium confidence: Return candidates for manual review
  - Low confidence: Skip matching

  ## Parameters

  - `offender_attrs` - Map of offender attributes from `build_offender_attrs/2`

  ## Returns

  - `{:ok, enhanced_attrs}` - Attrs with company_registration_number added if high-confidence match
  - `{:ok, original_attrs, :needs_review, candidates}` - Medium confidence, needs manual review
  - `{:ok, original_attrs}` - No match or low confidence
  - `{:error, reason}` - Error during matching (original attrs still usable)

  ## High Confidence Criteria

  - Exactly 1 active company found in search results
  - Name similarity ≥ 0.90 (stricter than default 0.85)
  - Business type matches (if determinable)
  - Company status is "active"

  ## Examples

      iex> attrs = %{name: "Ford Windows Limited", business_type: :limited_company}
      iex> OffenderBuilder.match_companies_house_number(attrs)
      {:ok, %{name: "Ford Windows Limited", business_type: :limited_company,
              company_registration_number: "03353423"}}

      iex> attrs = %{name: "John Smith", business_type: :individual}
      iex> OffenderBuilder.match_companies_house_number(attrs)
      {:ok, %{name: "John Smith", business_type: :individual}}
      # Skips matching for individuals
  """
  def match_companies_house_number(offender_attrs) when is_map(offender_attrs) do
    # Skip matching for individuals and sole traders
    case offender_attrs[:business_type] do
      :individual ->
        Logger.debug("Skipping Companies House match for individual: #{offender_attrs[:name]}")
        {:ok, offender_attrs}

      _other ->
        # Check if offender already has a pending review to avoid duplicate API calls
        case check_existing_review(offender_attrs) do
          {:existing_review, _review} ->
            Logger.info(
              "Skipping Companies House API call - review already exists for: #{offender_attrs[:name]}"
            )

            {:ok, offender_attrs}

          :no_review ->
            perform_companies_house_match(offender_attrs)
        end
    end
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
    enhanced_attrs =
      base_attrs
      |> Map.put(
        :business_type,
        determine_and_normalize_business_type(scraped_case.offender_name)
      )

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

    enhanced_attrs =
      base_attrs
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

  # Companies House Matching Private Functions

  defp check_existing_review(offender_attrs) do
    company_name = offender_attrs[:name]

    if company_name == nil or company_name == "" do
      :no_review
    else
      # Try to find existing offender by name (same logic as find_or_create_offender)
      normalized_name = String.trim(company_name)

      case EhsEnforcement.Enforcement.get_offender_by_name_and_postcode(
             normalized_name,
             offender_attrs[:postcode]
           ) do
        {:ok, offender} ->
          # Offender exists, check if review record exists
          check_review_for_offender(offender)

        {:error, %Ash.Error.Query.NotFound{}} ->
          # No offender found, so no review either
          :no_review

        {:error, _other} ->
          # Other errors, treat as no review
          :no_review
      end
    end
  end

  defp check_review_for_offender(offender) do
    # Check if a review record exists for this offender
    case Ash.read(EhsEnforcement.Enforcement.OffenderMatchReview,
           filter: [offender_id: offender.id]
         ) do
      {:ok, [review | _]} ->
        # Review exists
        {:existing_review, review}

      {:ok, []} ->
        # No review found
        :no_review

      {:error, _error} ->
        # Error reading reviews, treat as no review to be safe
        :no_review
    end
  end

  defp perform_companies_house_match(offender_attrs) do
    company_name = offender_attrs[:name]

    if company_name == nil or company_name == "" do
      Logger.warning("Cannot match Companies House: missing company name")
      {:ok, offender_attrs}
    else
      Logger.info("Searching Companies House for: #{company_name}")

      case CompaniesHouse.search_companies(company_name, items_per_page: 5) do
        {:ok, companies} ->
          evaluate_match_candidates(companies, offender_attrs)

        {:error, :rate_limited} ->
          Logger.warning(
            "Companies House rate limit reached, skipping match for: #{company_name}"
          )

          {:error, :rate_limited}

        {:error, reason} ->
          Logger.warning("Companies House search failed for #{company_name}: #{inspect(reason)}")

          {:error, reason}
      end
    end
  end

  defp prepare_candidates_for_review(active_companies) do
    # Take top 3 candidates and format for review record
    active_companies
    |> Enum.take(3)
    |> Enum.map(fn candidate ->
      %{
        "company_number" => candidate.company_number,
        "company_name" => candidate.company_name,
        "company_status" => candidate.company_status,
        "company_type" => candidate.company_type,
        "address" => format_candidate_address(candidate),
        "similarity_score" => calculate_similarity_score(candidate)
      }
    end)
  end

  defp format_candidate_address(candidate) do
    # Companies House search API provides address_snippet (string)
    # Full address map is only available from company detail API
    cond do
      Map.has_key?(candidate, :address_snippet) ->
        candidate.address_snippet

      Map.has_key?(candidate, :address) ->
        # If we have full address details (from company lookup API)
        address = candidate.address

        [
          address["address_line_1"],
          address["address_line_2"],
          address["locality"],
          address["region"],
          address["postal_code"]
        ]
        |> Enum.filter(&(&1 != nil and &1 != ""))
        |> Enum.join(", ")

      true ->
        "Address not available"
    end
  end

  defp calculate_similarity_score(_candidate) do
    # Placeholder - actual similarity will be calculated based on offender name
    # This will be properly calculated in create_medium_confidence_review/3
    0.85
  end

  @doc """
  Creates a review record for medium-confidence Companies House matches.

  This function should be called AFTER the offender has been created.

  ## Parameters

  - `offender` - The created offender Ash struct
  - `candidates` - List of candidate company maps from prepare_candidates_for_review/1

  ## Returns

  - `{:ok, review}` - Successfully created review record
  - `{:error, reason}` - Failed to create review record

  ## Examples

      iex> offender = %Offender{id: "uuid", name: "Example Ltd"}
      iex> candidates = [%{"company_number" => "12345678", ...}, ...]
      iex> OffenderBuilder.create_medium_confidence_review(offender, candidates)
      {:ok, %OffenderMatchReview{...}}
  """
  def create_medium_confidence_review(offender, candidates) when is_list(candidates) do
    # Calculate confidence score from candidates (use highest similarity)
    confidence_score =
      candidates
      |> Enum.map(fn candidate ->
        similarity =
          calculate_name_similarity(offender.name, candidate["company_name"])

        Map.put(candidate, "similarity_score", similarity)
      end)
      |> Enum.max_by(fn candidate -> candidate["similarity_score"] end)
      |> Map.get("similarity_score")

    # Update candidates with actual similarity scores
    updated_candidates =
      Enum.map(candidates, fn candidate ->
        similarity = calculate_name_similarity(offender.name, candidate["company_name"])
        Map.put(candidate, "similarity_score", similarity)
      end)

    # Create review record
    review_attrs = %{
      offender_id: offender.id,
      searched_at: DateTime.utc_now(),
      candidate_companies: updated_candidates,
      confidence_score: confidence_score,
      status: :pending
    }

    case EhsEnforcement.Enforcement.create_review(review_attrs) do
      {:ok, review} ->
        Logger.info(
          "✓ Created review record for offender #{offender.name} (#{offender.id}) " <>
            "with #{length(candidates)} candidates, confidence=#{Float.round(confidence_score, 3)}"
        )

        {:ok, review}

      {:error, error} ->
        # Check if this is a duplicate constraint violation
        error_message = inspect(error)

        if String.contains?(error_message, "unique constraint") or
             String.contains?(error_message, "offender_match_reviews_offender_id_index") do
          Logger.info(
            "⊘ Skipped duplicate review - record already exists for offender #{offender.name} (#{offender.id})"
          )
        else
          Logger.error(
            "✗ Failed to create review record for offender #{offender.name} (#{offender.id}): #{error_message}"
          )
        end

        {:error, error}
    end
  end

  defp evaluate_match_candidates(companies, offender_attrs) do
    company_name = offender_attrs[:name]

    # Filter to active companies only
    active_companies = Enum.filter(companies, &(&1.company_status == "active"))

    case length(active_companies) do
      0 ->
        Logger.info("No active companies found for: #{company_name}")
        {:ok, offender_attrs}

      1 ->
        # Exactly one active company - check if high confidence match
        [candidate] = active_companies
        check_high_confidence_match(candidate, offender_attrs)

      count when count in 2..3 ->
        # Medium confidence - review record will be created after offender is persisted
        Logger.info(
          "Medium confidence: #{count} active companies found for #{company_name}. " <>
            "Will create review record after offender is created. " <>
            "Candidates: #{inspect(Enum.map(active_companies, & &1.company_number))}"
        )

        # Phase 2: Create review record instead of just logging
        # Return original attrs without company_registration_number
        # Review record will be created AFTER offender is created (see create_medium_confidence_review/2)
        {:ok, offender_attrs, :needs_review, prepare_candidates_for_review(active_companies)}

      count ->
        # Low confidence - too many matches
        Logger.info(
          "Low confidence: #{count} active companies found for #{company_name}, skipping"
        )

        {:ok, offender_attrs}
    end
  end

  defp check_high_confidence_match(candidate, offender_attrs) do
    company_name = offender_attrs[:name]
    business_type = offender_attrs[:business_type]

    # Calculate similarity score
    similarity = calculate_name_similarity(company_name, candidate.company_name)

    # Check business type compatibility
    type_matches = business_type_compatible?(business_type, candidate.company_type)

    # High confidence threshold: similarity >= 0.90 AND types compatible
    is_high_confidence = similarity >= 0.90 and type_matches

    if is_high_confidence do
      Logger.info(
        "HIGH CONFIDENCE MATCH for #{company_name}: " <>
          "company_number=#{candidate.company_number}, " <>
          "canonical_name=#{candidate.company_name}, " <>
          "similarity=#{Float.round(similarity, 3)}, " <>
          "type_match=#{type_matches}"
      )

      enhanced_attrs =
        Map.put(offender_attrs, :company_registration_number, candidate.company_number)

      {:ok, enhanced_attrs}
    else
      Logger.info(
        "Match below high confidence threshold for #{company_name}: " <>
          "similarity=#{Float.round(similarity, 3)} (need ≥0.90), " <>
          "type_match=#{type_matches}, " <>
          "candidate=#{candidate.company_name}"
      )

      {:ok, offender_attrs}
    end
  end

  defp calculate_name_similarity(name1, name2) do
    # Normalize both names for comparison
    norm1 = normalize_company_name(name1)
    norm2 = normalize_company_name(name2)

    # Use Jaro-Winkler distance
    String.jaro_distance(norm1, norm2)
  end

  defp normalize_company_name(nil), do: ""

  defp normalize_company_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.downcase()
    # Remove common punctuation
    |> String.replace(~r/[\.,:;!@#$%^&*()]+/, "")
    # Normalize company suffixes
    |> String.replace(~r/\s+(limited|ltd\.?)$/i, " limited")
    |> String.replace(~r/\s+(plc|p\.l\.c\.?)$/i, " plc")
    |> String.replace(~r/\s+(llp|l\.l\.p\.?)$/i, " llp")
    # Replace multiple spaces with single space
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  # Fallback for unexpected types (integers, atoms, etc.)
  defp normalize_company_name(name), do: to_string(name) |> normalize_company_name()

  defp business_type_compatible?(_offender_type, companies_house_type)
       when is_nil(companies_house_type) do
    # If Companies House doesn't specify type, accept the match
    true
  end

  defp business_type_compatible?(offender_type, companies_house_type) do
    # Map our business types to Companies House company types
    # See: https://developer-specs.company-information.service.gov.uk/companies-house-public-data-api/resources/companysearch?v=latest
    case offender_type do
      :limited_company ->
        companies_house_type in [
          "ltd",
          "private-limited-guarant-nsc-limited-exemption",
          "private-limited-guarant-nsc",
          "private-limited-shares-section-30-exemption"
        ]

      :plc ->
        companies_house_type in ["plc", "public-limited-company"]

      :partnership ->
        companies_house_type in ["llp", "limited-partnership", "scottish-partnership"]

      :other ->
        # Accept any type for "other" category
        true

      _ ->
        # Unknown offender type, be permissive
        true
    end
  end
end
