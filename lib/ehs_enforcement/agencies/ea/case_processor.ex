defmodule EhsEnforcement.Agencies.Ea.CaseProcessor do
  @moduledoc """
  EA case processing pipeline - transforms scraped EA data for Ash resource creation.
  
  Handles:
  - EA data transformation from EaDetailRecord to Ash Case resource format
  - Multi-violation scenario detection and Violation resource creation
  - Integration with existing DataTransformer for field mapping
  - Offender matching/creation using company registration numbers
  - Environmental impact and legal framework processing
  """
  
  require Logger
  require Ash.Query
  
  alias EhsEnforcement.Scraping.Ea.CaseScraper.EaDetailRecord
  alias EhsEnforcement.Agencies.Ea.DataTransformer
  alias EhsEnforcement.Enforcement
  
  @ea_agency_code :environment_agency
  
  defmodule ProcessedEaCase do
    @moduledoc "Struct representing an EA case ready for Ash resource creation"
    
    @derive Jason.Encoder
    defstruct [
      # Core identifiers (mapped from EA data)
      :regulator_id,
      :agency_code,
      :offender_attrs,
      
      # Enforcement details
      :offence_result,
      :offence_fine,
      :offence_costs,
      :offence_action_date,
      :offence_hearing_date,
      :offence_breaches,
      :offence_breaches_clean,
      :regulator_function,
      :regulator_url,
      :related_cases,
      :offence_action_type,
      
      # EA-specific fields (new schema extensions)
      :ea_event_reference,
      :ea_total_violation_count,
      :environmental_impact,
      :environmental_receptor,
      :is_ea_multi_violation,
      
      # Source metadata
      :source_metadata,
      
      # Multi-violation data (for Violation resources)
      :violations_data
    ]
  end
  
  @doc """
  Process a single EA detail record into format ready for Ash Case resource creation.
  
  Returns {:ok, %ProcessedEaCase{}} or {:error, reason}
  """
  def process_ea_case(%EaDetailRecord{} = ea_record) do
    Logger.debug("Processing EA case: #{ea_record.ea_record_id}")
    
    try do
      # Transform EA record using existing DataTransformer
      transformed_data = DataTransformer.transform_ea_record(ea_record)
      
      processed = %ProcessedEaCase{
        regulator_id: transformed_data.regulator_id,
        agency_code: @ea_agency_code,
        offender_attrs: build_ea_offender_attrs(ea_record),
        offence_result: map_ea_action_to_result(ea_record.action_type),
        offence_fine: ea_record.total_fine || Decimal.new(0),
        offence_costs: Decimal.new(0),  # EA doesn't separate costs
        offence_action_date: ea_record.action_date,
        offence_hearing_date: nil,  # EA doesn't provide hearing dates
        offence_breaches: ea_record.offence_description,
        offence_breaches_clean: build_legal_reference(ea_record),
        regulator_function: normalize_ea_function(ea_record.agency_function),
        regulator_url: ea_record.detail_url,
        related_cases: nil,  # Could be enhanced later
        offence_action_type: map_ea_action_to_hse_type(ea_record.action_type),
        
        # EA-specific extensions
        ea_event_reference: ea_record.event_reference,
        ea_total_violation_count: detect_violation_count(ea_record),
        environmental_impact: assess_environmental_impact(ea_record),
        environmental_receptor: detect_primary_receptor(ea_record),
        is_ea_multi_violation: is_multi_violation_case?(ea_record),
        
        source_metadata: build_ea_source_metadata(ea_record),
        violations_data: build_violations_data(ea_record)
      }
      
      Logger.debug("Successfully processed EA case: #{ea_record.ea_record_id}")
      {:ok, processed}
    rescue
      error ->
        Logger.error("Failed to process EA case #{ea_record.ea_record_id}: #{inspect(error)}")
        {:error, {:processing_error, error}}
    end
  end
  
  @doc """
  Process multiple EA detail records in batch.
  
  Returns {:ok, [%ProcessedEaCase{}]} or {:error, reason}
  """
  def process_ea_cases(ea_records) when is_list(ea_records) do
    Logger.info("Processing #{length(ea_records)} EA records")
    
    try do
      processed_cases = Enum.reduce_while(ea_records, [], fn ea_record, acc ->
        case process_ea_case(ea_record) do
          {:ok, processed_case} -> {:cont, [processed_case | acc]}
          {:error, reason} -> 
            Logger.warning("Skipping EA record #{ea_record.ea_record_id}: #{inspect(reason)}")
            {:cont, acc} # Continue processing other records
        end
      end)
      
      successful_count = length(processed_cases)
      Logger.info("Successfully processed #{successful_count}/#{length(ea_records)} EA cases")
      
      {:ok, Enum.reverse(processed_cases)}
      
    rescue
      error -> {:error, {:batch_processing_error, error}}
    end
  end
  
  @doc """
  Process a single EA record and create Ash Case resource immediately.
  
  Handles multi-violation scenarios by creating both Case and Violation resources.
  Returns {:ok, case} or {:error, reason}
  """
  def process_and_create_case(ea_record_or_transformed, actor \\ nil)
  def process_and_create_case(%EaDetailRecord{} = ea_record, actor) do
    Logger.debug("🔄 Processing and creating EA case: #{ea_record.ea_record_id}")
    
    with {:ok, processed_case} <- (
           Logger.debug("📝 About to process EA case: #{ea_record.ea_record_id}")
           result = process_ea_case(ea_record)
           Logger.debug("📝 Process EA case result: #{inspect(result)}")
           result
         ),
         {:ok, case_record} <- (
           Logger.debug("💾 About to create EA case: #{processed_case.regulator_id}")
           result = create_ea_case(processed_case, actor)
           Logger.debug("💾 Create EA case result: #{inspect(result)}")
           result
         ),
         {:ok, _violations} <- (
           Logger.debug("🔗 About to create violations for case: #{case_record.id}")
           result = create_case_violations(case_record, processed_case.violations_data, actor)
           Logger.debug("🔗 Create violations result: #{inspect(result)}")
           result
         ) do
      Logger.info("✅ Successfully processed and created EA case: #{case_record.regulator_id}")
      {:ok, case_record}
    else
      {:error, reason} = error ->
        # Only log as error if it's not a duplicate case
        unless is_duplicate_error?(reason) do
          Logger.error("❌ Failed to process and create EA case #{ea_record.ea_record_id}: #{inspect(reason)}")
        end
        error
    end
  end

  def process_and_create_case(transformed_case, actor) when is_map(transformed_case) do
    Logger.debug("🔄 Processing pre-transformed EA case data")
    
    # Handle case where we receive transformed data from DataTransformer
    case create_case_from_transformed_data(transformed_case, actor) do
      {:ok, case_record} ->
        Logger.info("✅ Successfully created EA case from transformed data")
        {:ok, case_record}
        
      {:error, reason} = error ->
        unless is_duplicate_error?(reason) do
          Logger.error("❌ Failed to create EA case from transformed data: #{inspect(reason)}")
        end
        error
    end
  end

  @doc """
  Create Ash Case resource from processed EA case data.
  
  Returns {:ok, case} or {:error, ash_error}
  """
  def create_ea_case(%ProcessedEaCase{} = processed_case, actor \\ nil) do
    Logger.debug("Creating Ash Case resource for EA case: #{processed_case.regulator_id}")
    
    case_attrs = %{
      agency_code: processed_case.agency_code,
      regulator_id: processed_case.regulator_id,
      offender_attrs: processed_case.offender_attrs,
      offence_result: processed_case.offence_result,
      offence_fine: processed_case.offence_fine,
      offence_costs: processed_case.offence_costs,
      offence_action_date: processed_case.offence_action_date,
      offence_hearing_date: processed_case.offence_hearing_date,
      offence_breaches: processed_case.offence_breaches,
      offence_breaches_clean: processed_case.offence_breaches_clean,
      regulator_function: processed_case.regulator_function,
      regulator_url: processed_case.regulator_url,
      related_cases: processed_case.related_cases,
      offence_action_type: processed_case.offence_action_type,
      
      # EA-specific fields
      ea_event_reference: processed_case.ea_event_reference,
      ea_total_violation_count: processed_case.ea_total_violation_count,
      environmental_impact: processed_case.environmental_impact,
      environmental_receptor: processed_case.environmental_receptor,
      is_ea_multi_violation: processed_case.is_ea_multi_violation
    }
    
    # Add actor context if provided
    create_opts = if actor, do: [actor: actor], else: []
    
    case Enforcement.create_case(case_attrs, create_opts) do
      {:ok, case_record} ->
        Logger.info("Successfully created EA case: #{case_record.regulator_id}")
        {:ok, case_record}
      
      {:error, ash_error} ->
        # Handle duplicate by updating existing case with new EA data
        if is_duplicate_error?(ash_error) do
          Logger.debug("EA case already exists, updating with :update_from_scraping: #{processed_case.regulator_id}")
          
          # Find the existing case and update it
          query_opts = if actor, do: [actor: actor], else: []
          case Enforcement.Case 
               |> Ash.Query.filter(regulator_id == ^processed_case.regulator_id)
               |> Ash.read_one(query_opts) do
            {:ok, existing_case} when not is_nil(existing_case) ->
              # Update with the new EA data using our scraping action
              update_attrs = %{
                offence_result: case_attrs.offence_result,
                offence_fine: case_attrs.offence_fine,
                offence_costs: case_attrs.offence_costs,
                offence_hearing_date: case_attrs.offence_hearing_date,
                url: case_attrs.regulator_url,
                related_cases: case_attrs.related_cases
              }
              
              update_opts = if actor, do: [actor: actor], else: []
              case Enforcement.update_case_from_scraping(existing_case, update_attrs, update_opts) do
                {:ok, updated_case} ->
                  Logger.info("Successfully updated existing EA case via :update_from_scraping: #{updated_case.regulator_id}")
                  # Still return the original duplicate error to preserve existing counting logic
                  {:error, ash_error}
                {:error, update_error} ->
                  Logger.error("Failed to update existing EA case #{processed_case.regulator_id}: #{inspect(update_error)}")
                  {:error, ash_error}
              end
            
            {:ok, nil} ->
              Logger.warning("EA case marked as duplicate but not found: #{processed_case.regulator_id}")
              {:error, ash_error}
            
            {:error, query_error} ->
              Logger.error("Failed to query existing EA case #{processed_case.regulator_id}: #{inspect(query_error)}")
              {:error, ash_error}
          end
        else
          Logger.error("Failed to create EA case #{processed_case.regulator_id}: #{inspect(ash_error)}")
          {:error, ash_error}
        end
    end
  end
  
  @doc """
  Create Violation resources for EA multi-violation cases.
  
  Returns {:ok, violations} or {:error, reason}
  """
  def create_case_violations(case_record, violations_data, _actor \\ nil) do
    if is_list(violations_data) and length(violations_data) > 0 do
      Logger.debug("Creating #{length(violations_data)} violations for EA case: #{case_record.regulator_id}")
      
      # Use bulk_create action for efficient violation creation
      case Enforcement.Violation.bulk_create(
             violations_data: violations_data,
             case_id: case_record.id
           ) do
        {:ok, _bulk_result} ->
          Logger.info("Successfully created violations for EA case: #{case_record.regulator_id}")
          {:ok, violations_data}
        
        {:error, error} ->
          Logger.error("Failed to create violations for EA case #{case_record.regulator_id}: #{inspect(error)}")
          {:error, error}
      end
    else
      # No violations to create
      {:ok, []}
    end
  end
  
  # Private helper functions
  
  defp build_ea_offender_attrs(%EaDetailRecord{} = ea_record) do
    base_attrs = %{
      name: ea_record.offender_name,
      address: build_full_address(ea_record),
      local_authority: ea_record.county,  # Use county as local authority
      postcode: ea_record.postcode,
      main_activity: ea_record.industry_sector,
      industry: map_ea_industry_to_hse_category(ea_record.industry_sector),
      
      # EA-specific fields
      company_registration_number: ea_record.company_registration_number,
      town: ea_record.town,
      county: ea_record.county
    }
    
    # Add business type detection
    enhanced_attrs = base_attrs
    |> Map.put(:business_type, normalize_business_type(determine_business_type(ea_record.offender_name)))
    
    # Remove nil values to keep attrs clean
    enhanced_attrs
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
  end
  
  defp build_full_address(%EaDetailRecord{} = ea_record) do
    [ea_record.address, ea_record.town, ea_record.county, ea_record.postcode]
    |> Enum.filter(&(&1 != nil and &1 != ""))
    |> Enum.join(", ")
  end
  
  defp build_legal_reference(%EaDetailRecord{} = ea_record) do
    case {ea_record.act, ea_record.section} do
      {act, section} when is_binary(act) and is_binary(section) ->
        "#{String.trim(act)} - #{String.trim(section)}"
      {act, _} when is_binary(act) -> String.trim(act)
      _ -> ea_record.offence_description
    end
  end
  
  defp build_ea_source_metadata(%EaDetailRecord{} = ea_record) do
    %{
      scraped_at: ea_record.scraped_at,
      source: "ea_website",
      scraper_version: "2.0",
      ea_record_id: ea_record.ea_record_id,
      detail_url: ea_record.detail_url
    }
  end
  
  # EA-specific field mapping functions
  
  defp map_ea_action_to_result(action_type) do
    case action_type do
      :court_case -> "Court Action"
      :caution -> "Formal Caution"
      :enforcement_notice -> "Enforcement Notice Issued"
      _ -> "Regulatory Action"
    end
  end
  
  defp map_ea_action_to_hse_type(action_type) do
    case action_type do
      :court_case -> "Court Case"
      :caution -> "Formal Caution"
      :enforcement_notice -> "Enforcement Notice"
      _ -> "Other"
    end
  end
  
  defp normalize_ea_function(agency_function) when is_binary(agency_function) do
    "Environmental - #{String.trim(agency_function)}"
  end
  defp normalize_ea_function(_), do: "Environmental"
  
  defp assess_environmental_impact(%EaDetailRecord{} = ea_record) do
    impacts = [ea_record.water_impact, ea_record.land_impact, ea_record.air_impact]
    
    cond do
      Enum.any?(impacts, &(&1 == "major")) -> "major"
      Enum.any?(impacts, &(&1 == "minor")) -> "minor"
      true -> "none"
    end
  end
  
  defp detect_primary_receptor(%EaDetailRecord{} = ea_record) do
    case {ea_record.water_impact, ea_record.land_impact, ea_record.air_impact} do
      {"major", _, _} -> "water"
      {_, "major", _} -> "land"
      {_, _, "major"} -> "air"
      {"minor", _, _} -> "water"
      {_, "minor", _} -> "land"
      {_, _, "minor"} -> "air"
      _ -> "land"  # Default to land for general environmental cases
    end
  end
  
  defp detect_violation_count(%EaDetailRecord{} = ea_record) do
    # For now, assume single violation per EA record
    # This could be enhanced to detect multiple case references
    if is_multi_violation_case?(ea_record), do: length(build_violations_data(ea_record)), else: 1
  end
  
  defp is_multi_violation_case?(%EaDetailRecord{} = ea_record) do
    # Check if case reference suggests multiple violations
    # EA multi-violation cases often have numbered case references
    case_ref = ea_record.case_reference || ""
    String.contains?(case_ref, "/01") or String.contains?(case_ref, "/02")
  end
  
  defp build_violations_data(%EaDetailRecord{} = ea_record) do
    if is_multi_violation_case?(ea_record) do
      # For now, create single violation - this could be enhanced
      # to parse multiple violations from EA detail pages
      [%{
        violation_sequence: 1,
        case_reference: ea_record.case_reference,
        individual_fine: ea_record.total_fine || Decimal.new(0),
        offence_description: ea_record.offence_description,
        legal_act: ea_record.act,
        legal_section: ea_record.section
      }]
    else
      []  # Single violation cases don't need Violation resources
    end
  end
  
  # Industry classification mapping
  
  defp map_ea_industry_to_hse_category(nil), do: "Unknown"
  defp map_ea_industry_to_hse_category(ea_industry) when is_binary(ea_industry) do
    ea_lower = String.downcase(ea_industry)
    
    cond do
      String.contains?(ea_lower, "manufacturing") -> "Manufacturing"
      String.contains?(ea_lower, "construction") -> "Construction"
      String.contains?(ea_lower, ["water", "supply", "utility"]) -> "Extractive and utility supply industries"
      String.contains?(ea_lower, ["agriculture", "farming", "forestry", "fishing"]) -> "Agriculture hunting forestry and fishing"
      String.contains?(ea_lower, ["service", "management", "transport", "retail"]) -> "Total service industries"
      true -> "Unknown"
    end
  end
  
  # Business type detection (reused from HSE patterns)
  
  defp determine_business_type(offender_name) do
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
  
  # Error handling helpers
  
  defp is_duplicate_error?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %{field: :regulator_id, message: message} ->
        String.contains?(message, "already been taken") or
        String.contains?(message, "already exists")
      _ -> false
    end)
  end
  
  defp is_duplicate_error?(_), do: false
  
  # Alternative creation method for pre-transformed data
  
  defp create_case_from_transformed_data(transformed_case, actor) do
    case_attrs = %{
      agency_code: :environment_agency,
      regulator_id: transformed_case[:regulator_id] || transformed_case.regulator_id,
      offender_attrs: build_offender_attrs_from_transformed(transformed_case),
      offence_result: transformed_case[:offence_result] || "Regulatory Action",
      offence_fine: transformed_case[:total_fine] || Decimal.new(0),
      offence_costs: Decimal.new(0),
      offence_action_date: transformed_case[:action_date],
      offence_hearing_date: nil,
      offence_breaches: transformed_case[:offence_description],
      offence_breaches_clean: transformed_case[:legal_reference],
      regulator_function: transformed_case[:agency_function] || "Environmental",
      regulator_url: transformed_case[:regulator_url],
      related_cases: nil,
      offence_action_type: transformed_case[:offence_action_type] || "Other"
    }
    
    create_opts = if actor, do: [actor: actor], else: []
    Enforcement.create_case(case_attrs, create_opts)
  end
  
  defp build_offender_attrs_from_transformed(transformed_case) do
    %{
      name: transformed_case[:offender_name],
      address: transformed_case[:address],
      local_authority: transformed_case[:county],
      postcode: transformed_case[:postcode],
      main_activity: transformed_case[:industry_sector],
      industry: "Unknown",  # Would need additional mapping
      company_registration_number: transformed_case[:company_registration_number],
      town: transformed_case[:town],
      county: transformed_case[:county]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
  end
end