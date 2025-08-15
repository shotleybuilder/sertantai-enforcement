defmodule EhsEnforcement.Scraping.Ea.NoticeProcessor do
  @moduledoc """
  EA Notice processing pipeline - transforms scraped enforcement notice data for Ash resource creation.
  
  Handles:
  - Data transformation from EA enforcement notice format to Ash Notice resource format
  - Environmental impact and legal framework data processing
  - Integration with EA.DataTransformer for consistent EA data patterns
  - Integration with EA.OffenderMatcher for offender matching/creation
  - Validation and error handling following Ash patterns
  
  ## EA Notice Characteristics
  
  EA enforcement notices include environmental-specific data not present in HSE notices:
  - Environmental impact assessment
  - Environmental receptor information (water, land, air)
  - Legal framework (acts and sections)
  - Agency function (waste, water quality, etc.)
  - Event reference numbers
  """
  
  require Logger
  alias EhsEnforcement.Agencies.Ea.DataTransformer
  alias EhsEnforcement.Agencies.Ea.OffenderMatcher
  
  @ea_agency_code :environment_agency
  
  defmodule ProcessedEaNotice do
    @moduledoc """
    Struct representing an EA enforcement notice ready for Ash resource creation.
    
    Extends the standard notice format with EA-specific environmental data.
    """
    
    @derive Jason.Encoder
    defstruct [
      # Core notice fields (standard across agencies)
      :regulator_id,
      :agency_code,
      :offender_attrs,
      :notice_date,
      :operative_date,
      :compliance_date,
      :notice_body,
      :offence_action_type,
      :offence_action_date,
      :offence_breaches,
      :regulator_url,
      :source_metadata,
      
      # EA-specific environmental fields
      :regulator_event_reference,
      :environmental_impact,
      :environmental_receptor,
      :legal_act,
      :legal_section,
      :regulator_function
    ]
  end
  
  @doc """
  Process a single scraped EA enforcement notice into format ready for Ash resource creation.
  
  Takes an EaDetailRecord struct from the EA scraper and transforms it into
  a ProcessedEaNotice struct ready for Notice resource creation.
  
  ## Parameters
  
  - `ea_detail_record` - EaDetailRecord struct from EA.CaseScraper
  
  ## Returns
  
  - `{:ok, %ProcessedEaNotice{}}` - Successfully processed notice
  - `{:error, reason}` - Processing error
  
  ## Examples
  
      {:ok, processed} = NoticeProcessor.process_notice(ea_detail_record)
      {:ok, notice} = create_notice_from_processed(processed, actor)
  """
  def process_notice(ea_detail_record) when is_map(ea_detail_record) do
    Logger.debug("EA NoticeProcessor: Processing enforcement notice: #{ea_detail_record.ea_record_id}")
    
    try do
      # Transform EA record using the standard EA DataTransformer
      # This gives us the common case/notice fields in standard format
      transformed_data = DataTransformer.transform_ea_record(ea_detail_record)
      
      # Verify this is actually an enforcement notice
      if not enforcement_notice?(ea_detail_record) do
        Logger.warning("EA NoticeProcessor: Record #{ea_detail_record.ea_record_id} is not an enforcement notice")
        {:error, {:invalid_notice_type, ea_detail_record.offence_action_type}}
      else
        # Extract EA-specific environmental data
        environmental_data = extract_environmental_data(ea_detail_record)
        
        # Build processed notice struct
        processed = %ProcessedEaNotice{
          # Core notice fields (from transformed data)
          regulator_id: transformed_data[:regulator_id],
          agency_code: @ea_agency_code,
          offender_attrs: transformed_data[:offender_attrs],
          notice_date: transformed_data[:offence_action_date],  # EA uses action_date as notice_date
          operative_date: parse_operative_date(ea_detail_record),
          compliance_date: parse_compliance_date(ea_detail_record),
          notice_body: transformed_data[:offence_description],
          offence_action_type: "Enforcement Notice",  # Normalize to standard notice type
          offence_action_date: transformed_data[:offence_action_date],
          offence_breaches: transformed_data[:offence_description],
          regulator_url: build_ea_notice_url(ea_detail_record.ea_record_id),
          source_metadata: build_source_metadata(ea_detail_record),
          
          # EA-specific environmental fields
          regulator_event_reference: environmental_data[:event_reference],
          environmental_impact: environmental_data[:impact],
          environmental_receptor: environmental_data[:receptor],
          legal_act: environmental_data[:legal_act],
          legal_section: environmental_data[:legal_section],
          regulator_function: environmental_data[:agency_function]
        }
        
        Logger.debug("EA NoticeProcessor: Successfully processed enforcement notice: #{ea_detail_record.ea_record_id}")
        {:ok, processed}
      end
      
    rescue
      error ->
        Logger.error("EA NoticeProcessor: Failed to process notice #{ea_detail_record.ea_record_id}: #{inspect(error)}")
        {:error, {:processing_error, error}}
    end
  end
  
  @doc """
  Process multiple scraped EA enforcement notices in batch.
  
  ## Returns
  
  - `{:ok, [%ProcessedEaNotice{}]}` - All notices processed successfully
  - `{:ok, [%ProcessedEaNotice{}], errors: errors}` - Some notices processed with errors
  """
  def process_notices(ea_detail_records) when is_list(ea_detail_records) do
    Logger.info("EA NoticeProcessor: Processing #{length(ea_detail_records)} enforcement notices")
    
    results = Enum.reduce(ea_detail_records, {[], []}, fn record, {processed, errors} ->
      case process_notice(record) do
        {:ok, processed_notice} -> {[processed_notice | processed], errors}
        {:error, reason} -> {processed, [{record.ea_record_id, reason} | errors]}
      end
    end)
    
    case results do
      {processed_notices, []} ->
        Logger.info("EA NoticeProcessor: Successfully processed all #{length(processed_notices)} notices")
        {:ok, Enum.reverse(processed_notices)}
      
      {processed_notices, errors} ->
        Logger.warning("EA NoticeProcessor: Processed #{length(processed_notices)} notices with #{length(errors)} errors")
        {:ok, Enum.reverse(processed_notices), errors: errors}
    end
  end
  
  @doc """
  Process and create a single EA enforcement notice directly using Ash patterns.
  
  Combines processing and Notice resource creation into a single operation.
  
  ## Returns
  
  - `{:ok, %Notice{}, :created}` - Notice created successfully
  - `{:ok, %Notice{}, :updated}` - Existing notice updated
  - `{:ok, %Notice{}, :existing}` - Notice already exists, no changes
  - `{:error, reason}` - Processing or creation failed
  """
  def process_and_create_notice(ea_detail_record, actor) do
    case process_notice(ea_detail_record) do
      {:ok, processed_notice} ->
        create_notice_from_processed(processed_notice, actor)
      
      {:error, reason} ->
        Logger.error("EA NoticeProcessor: Failed to process notice #{ea_detail_record.ea_record_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Process and create a notice with unified status reporting for UI display.
  
  This provides the same status interface as the unified case processor
  for consistent UI progress display.
  """
  def process_and_create_notice_with_status(ea_detail_record, actor) do
    case process_and_create_notice(ea_detail_record, actor) do
      {:ok, notice, status} ->
        {:ok, notice, status}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Create a notice from processed EA data using Ash patterns.
  
  Handles offender matching, agency lookup, and Notice resource creation
  with proper error handling and duplicate detection.
  """
  def create_notice_from_processed(%ProcessedEaNotice{} = processed, actor) do
    Logger.debug("EA NoticeProcessor: Creating notice from processed data: #{processed.regulator_id}")
    
    # Get EA agency
    case EhsEnforcement.Enforcement.get_agency_by_code(processed.agency_code) do
      {:ok, agency} when not is_nil(agency) ->
        # Find or create offender using EA offender matcher
        case OffenderMatcher.find_or_create_offender(processed.offender_attrs) do
          {:ok, offender} ->
            # Check for existing notice to avoid duplicates
            case check_for_existing_notice(processed.regulator_id, agency.id) do
              {:ok, nil} ->
                # Create new notice
                create_new_notice(processed, agency.id, offender.id, actor)
                
              {:ok, existing_notice} ->
                # Update existing notice with any new data
                update_existing_notice(existing_notice, processed, actor)
                
              {:error, reason} ->
                Logger.error("EA NoticeProcessor: Failed to check for existing notice: #{inspect(reason)}")
                {:error, {:duplicate_check_error, reason}}
            end
          
          {:error, reason} ->
            Logger.error("EA NoticeProcessor: Failed to find/create offender for notice #{processed.regulator_id}: #{inspect(reason)}")
            {:error, {:offender_error, reason}}
        end
      
      {:ok, nil} ->
        {:error, "Agency not found: #{processed.agency_code}"}
      
      {:error, reason} ->
        {:error, {:agency_error, reason}}
    end
  end
  
  # Private Functions
  
  defp enforcement_notice?(ea_detail_record) do
    action_type = Map.get(ea_detail_record, :offence_action_type, "")
    
    action_type
    |> String.downcase()
    |> String.contains?("enforcement")
  end
  
  defp extract_environmental_data(ea_detail_record) do
    %{
      event_reference: Map.get(ea_detail_record, :ea_event_reference),
      impact: normalize_environmental_impact(Map.get(ea_detail_record, :environmental_impact)),
      receptor: normalize_environmental_receptor(Map.get(ea_detail_record, :environmental_receptor)),
      legal_act: extract_legal_act(ea_detail_record),
      legal_section: extract_legal_section(ea_detail_record),
      agency_function: Map.get(ea_detail_record, :agency_function)
    }
  end
  
  defp normalize_environmental_impact(nil), do: "none"
  defp normalize_environmental_impact(""), do: "none"
  defp normalize_environmental_impact(impact) when is_binary(impact) do
    impact
    |> String.downcase()
    |> String.trim()
    |> case do
      impact when impact in ["major", "significant", "high"] -> "major"
      impact when impact in ["minor", "low", "minimal"] -> "minor"
      impact when impact in ["none", "nil", "no impact"] -> "none"
      _ -> "unknown"
    end
  end
  defp normalize_environmental_impact(_), do: "unknown"
  
  defp normalize_environmental_receptor(nil), do: nil
  defp normalize_environmental_receptor(""), do: nil
  defp normalize_environmental_receptor(receptor) when is_binary(receptor) do
    cleaned_receptor = receptor
    |> String.downcase()
    |> String.trim()
    
    cond do
      String.contains?(cleaned_receptor, "water") -> "water"
      String.contains?(cleaned_receptor, "land") -> "land"
      String.contains?(cleaned_receptor, "air") -> "air"
      String.contains?(cleaned_receptor, "soil") -> "land"
      String.contains?(cleaned_receptor, "groundwater") -> "water"
      true -> cleaned_receptor
    end
  end
  defp normalize_environmental_receptor(_), do: nil
  
  defp extract_legal_act(ea_detail_record) do
    # EA records may have legal framework in various fields
    legal_framework = Map.get(ea_detail_record, :legal_framework) ||
                     Map.get(ea_detail_record, :regulation_act) ||
                     Map.get(ea_detail_record, :offence_legislation)
    
    case legal_framework do
      nil -> nil
      "" -> nil
      framework when is_binary(framework) ->
        # Extract act name (everything before "section" or "regulation")
        case Regex.run(~r/^([^,]+?)(?:\s+(?:section|regulation|s\.|reg\.)).*$/i, String.trim(framework)) do
          [_, act] -> String.trim(act)
          _ -> String.trim(framework)
        end
      _ -> nil
    end
  end
  
  defp extract_legal_section(ea_detail_record) do
    legal_framework = Map.get(ea_detail_record, :legal_framework) ||
                     Map.get(ea_detail_record, :regulation_act) ||
                     Map.get(ea_detail_record, :offence_legislation)
    
    case legal_framework do
      nil -> nil
      "" -> nil
      framework when is_binary(framework) ->
        # Extract section/regulation number
        case Regex.run(~r/(?:section|regulation|s\.|reg\.)\s*(\d+[a-z]?)/i, String.trim(framework)) do
          [_, section] -> String.trim(section)
          _ -> nil
        end
      _ -> nil
    end
  end
  
  defp parse_operative_date(_ea_detail_record) do
    # EA enforcement notices typically don't have separate operative dates
    # They become operative when issued (notice_date)
    nil
  end
  
  defp parse_compliance_date(_ea_detail_record) do
    # EA enforcement notices may include compliance deadlines
    # This would need to be extracted from notice text/description
    # For now, return nil - can be enhanced later
    nil
  end
  
  defp build_ea_notice_url(ea_record_id) when is_binary(ea_record_id) do
    "https://environment.data.gov.uk/public-register/enforcement-action/registration/#{ea_record_id}?__pageState=result-enforcement-action"
  end
  defp build_ea_notice_url(_), do: nil
  
  defp build_source_metadata(ea_detail_record) do
    %{
      scraped_at: DateTime.utc_now(),
      scraper_version: "1.0",
      ea_source: "environment.data.gov.uk",
      raw_data_keys: Map.keys(ea_detail_record),
      action_type: "enforcement_notice"
    }
  end
  
  defp check_for_existing_notice(regulator_id, agency_id) do
    import Ash.Query
    
    try do
      case EhsEnforcement.Enforcement.Notice
           |> filter(regulator_id == ^regulator_id and agency_id == ^agency_id)
           |> Ash.read_one() do
        {:ok, notice} -> {:ok, notice}  # May be nil if not found
        {:error, reason} -> {:error, reason}
      end
    rescue
      error ->
        Logger.error("EA NoticeProcessor: Error checking for existing notice: #{inspect(error)}")
        {:error, error}
    end
  end
  
  defp create_new_notice(processed, agency_id, offender_id, actor) do
    notice_attrs = %{
      regulator_id: processed.regulator_id,
      notice_date: processed.notice_date,
      operative_date: processed.operative_date,
      compliance_date: processed.compliance_date,
      notice_body: processed.notice_body,
      offence_action_type: processed.offence_action_type,
      offence_action_date: processed.offence_action_date,
      offence_breaches: processed.offence_breaches,
      url: processed.regulator_url,
      
      # EA-specific fields
      regulator_event_reference: processed.regulator_event_reference,
      environmental_impact: processed.environmental_impact,
      environmental_receptor: processed.environmental_receptor,
      legal_act: processed.legal_act,
      legal_section: processed.legal_section,
      regulator_function: processed.regulator_function,
      
      # Relationships
      agency_id: agency_id,
      offender_id: offender_id
    }
    
    case Ash.create(EhsEnforcement.Enforcement.Notice, notice_attrs, actor: actor) do
      {:ok, notice} ->
        Logger.info("EA NoticeProcessor: Created new notice: #{notice.regulator_id}")
        {:ok, notice, :created}
        
      {:error, reason} ->
        Logger.error("EA NoticeProcessor: Failed to create notice: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp update_existing_notice(existing_notice, processed, actor) do
    # Check if any fields need updating
    updates = build_notice_updates(existing_notice, processed)
    
    if map_size(updates) > 0 do
      case Ash.update(existing_notice, updates, actor: actor) do
        {:ok, updated_notice} ->
          Logger.info("EA NoticeProcessor: Updated existing notice: #{updated_notice.regulator_id}")
          {:ok, updated_notice, :updated}
          
        {:error, reason} ->
          Logger.error("EA NoticeProcessor: Failed to update notice: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.debug("EA NoticeProcessor: Notice already up to date: #{existing_notice.regulator_id}")
      {:ok, existing_notice, :existing}
    end
  end
  
  defp build_notice_updates(existing, processed) do
    potential_updates = %{
      notice_body: processed.notice_body,
      offence_breaches: processed.offence_breaches,
      environmental_impact: processed.environmental_impact,
      environmental_receptor: processed.environmental_receptor,
      legal_act: processed.legal_act,
      legal_section: processed.legal_section,
      regulator_function: processed.regulator_function,
      url: processed.regulator_url
    }
    
    # Only include fields that have actually changed
    potential_updates
    |> Enum.filter(fn {field, new_value} ->
      current_value = Map.get(existing, field)
      current_value != new_value and not is_nil(new_value)
    end)
    |> Map.new()
  end
end