defmodule EhsEnforcement.Enforcement.Offender do
  @moduledoc """
  Represents a company or individual subject to enforcement action.
  Normalized to eliminate duplication between cases and notices.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "offenders"
    repo EhsEnforcement.Repo
    
    custom_indexes do
      # pg_trgm GIN indexes for fuzzy text search on offender fields
      index [:name], name: "offenders_name_gin_trgm", using: "GIN"
      index [:normalized_name], name: "offenders_normalized_name_gin_trgm", using: "GIN"
      index [:local_authority], name: "offenders_local_authority_gin_trgm", using: "GIN"
      index [:main_activity], name: "offenders_main_activity_gin_trgm", using: "GIN"
      index [:postcode], name: "offenders_postcode_gin_trgm", using: "GIN"
    end
  end

  pub_sub do
    module(EhsEnforcementWeb.Endpoint)
    prefix("offender")

    publish(:create, ["created", :id])
    publish(:update, ["updated", :id])
    publish(:update_statistics, ["stats_updated", :id])
  end

  attributes do
    uuid_primary_key :id
    
    attribute :name, :string, allow_nil?: false
    attribute :normalized_name, :string
    attribute :address, :string
    attribute :local_authority, :string
    attribute :country, :string
    attribute :postcode, :string
    attribute :main_activity, :string
    attribute :sic_code, :string
    attribute :business_type, :atom do
      constraints [one_of: [:limited_company, :individual, :partnership, :plc, :other]]
    end
    attribute :industry, :string
    
    # Aggregated statistics
    attribute :first_seen_date, :date
    attribute :last_seen_date, :date
    attribute :total_cases, :integer, default: 0
    attribute :total_notices, :integer, default: 0
    attribute :total_fines, :decimal, default: 0
    
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :cases, EhsEnforcement.Enforcement.Case
    has_many :notices, EhsEnforcement.Enforcement.Notice
  end

  identities do
    identity :unique_name_postcode, [:normalized_name, :postcode]
  end

  actions do
    defaults [:read]
    
    create :create do
      primary? true
      accept [:name, :address, :local_authority, :country, :postcode, :main_activity, :sic_code, :business_type, :industry,
              :first_seen_date, :last_seen_date, :total_cases, :total_notices, :total_fines]
      
      change fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :name) do
          nil -> changeset
          name -> 
            # Keep original name, but add normalized version for matching
            normalized_name = normalize_company_name(name)
            Ash.Changeset.force_change_attribute(changeset, :normalized_name, normalized_name)
        end
      end
    end
    
    update :update do
      primary? true
      require_atomic? false
      accept [:name, :address, :local_authority, :country, :main_activity, :sic_code, :business_type, :industry]
      
      change fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :name) do
          nil -> changeset
          name -> 
            # Update normalized name when name changes
            normalized_name = normalize_company_name(name)
            Ash.Changeset.force_change_attribute(changeset, :normalized_name, normalized_name)
        end
      end
    end
    
    update :update_statistics do
      require_atomic? false
      accept []
      argument :fine_amount, :decimal
      
      change fn changeset, _context ->
        fine_amount = Ash.Changeset.get_argument(changeset, :fine_amount) || Decimal.new("0")
        
        # Get current values from the database record, defaulting to 0 if nil
        current_cases = changeset.data.total_cases || 0
        current_notices = changeset.data.total_notices || 0  
        current_fines = changeset.data.total_fines || Decimal.new("0")
        
        new_fines = Decimal.add(current_fines, fine_amount)
        
        # Set new values by incrementing
        changeset
        |> Ash.Changeset.force_change_attribute(:total_cases, current_cases + 1)
        |> Ash.Changeset.force_change_attribute(:total_notices, current_notices + 1)
        |> Ash.Changeset.force_change_attribute(:total_fines, new_fines)
      end
    end
    
    read :search do
      argument :query, :string, allow_nil?: false
      
      filter expr(
        ilike(name, "%" <> ^arg(:query) <> "%") or
        ilike(normalized_name, "%" <> ^arg(:query) <> "%") or
        ilike(local_authority, "%" <> ^arg(:query) <> "%") or
        ilike(postcode, "%" <> ^arg(:query) <> "%")
      )
    end
  end

  calculations do
    calculate :enforcement_count, :integer do
      calculation expr(total_cases + total_notices)
    end
  end

  code_interface do
    define :create, args: [:name]
    define :update_statistics
    define :search, args: [:query]
  end

  @doc """
  Finds or creates an offender with deduplication logic.
  
  This function handles finding existing offenders by name and postcode,
  with fuzzy matching fallback to prevent duplicates.
  """
  def find_or_create_offender(attrs) do
    normalized_attrs = normalize_attrs(attrs)
    
    # Check if name is empty or only whitespace
    name = String.trim(normalized_attrs[:name] || "")
    if name == "" do
      {:error, %Ash.Error.Invalid{errors: [%{message: "Name cannot be empty"}]}}
    else
      # Use Ash to find existing offender by name and postcode
      case EhsEnforcement.Enforcement.get_offender_by_name_and_postcode(
        name,
        normalized_attrs[:postcode]
      ) do
        {:ok, offender} -> 
          {:ok, offender}
        
        {:error, %Ash.Error.Query.NotFound{}} ->
          # Try fuzzy search - only if name has content
          if String.length(name) > 2 do
            # Normalize the search query for better matching
            normalized_search = normalize_company_name(name)
            case EhsEnforcement.Enforcement.search_offenders(normalized_search) do
              {:ok, []} -> 
                # Create new offender using Ash
                create_offender_with_retry(Map.put(normalized_attrs, :name, name))
                
              {:ok, similar_offenders} ->
                # Return best match or create new
                best_match = find_best_match(similar_offenders, Map.put(normalized_attrs, :name, name))
                if best_match do
                  {:ok, best_match}
                else
                  create_offender_with_retry(Map.put(normalized_attrs, :name, name))
                end
                
              {:error, %Ash.Error.Invalid{}} ->
                # Handle case where search query is invalid (empty, etc.)
                create_offender_with_retry(Map.put(normalized_attrs, :name, name))
                
              error -> error
            end
          else
            # Name too short for fuzzy search, just create
            create_offender_with_retry(Map.put(normalized_attrs, :name, name))
          end
        
        error -> error
      end
    end
  end

  @doc """
  Normalize company names to standard format for matching.
  """
  def normalize_company_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.downcase()
    # Remove common punctuation that could interfere with matching
    |> String.replace(~r/[\.,:;!@#$%^&*()]+/, "")
    # Normalize company suffixes
    |> String.replace(~r/\s+(limited|ltd\.?)$/i, " limited")
    |> String.replace(~r/\s+(plc|p\.l\.c\.?)$/i, " plc")
    # Replace multiple spaces with single space
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  def normalize_company_name(name), do: name

  # Private helper functions for find_or_create_offender

  defp normalize_attrs(attrs) when is_map(attrs) do
    # Convert string keys to atom keys for consistent processing
    normalized_attrs = attrs
    |> convert_string_keys_to_atoms()
    |> Map.update(:postcode, nil, &normalize_postcode/1)
    |> normalize_business_type()
    
    # Ensure we have a name field
    name = String.trim(normalized_attrs[:name] || "")
    Map.put(normalized_attrs, :name, name)
  end
  
  defp convert_string_keys_to_atoms(attrs) do
    # Convert common string keys to atoms to ensure consistency
    key_mappings = %{
      "name" => :name,
      "postcode" => :postcode,
      "local_authority" => :local_authority,
      "main_activity" => :main_activity,
      "business_type" => :business_type,
      "industry" => :industry
    }
    
    Enum.reduce(key_mappings, attrs, fn {string_key, atom_key}, acc ->
      case Map.get(acc, string_key) do
        nil -> acc
        value -> 
          acc
          |> Map.put(atom_key, value)
          |> Map.delete(string_key)
      end
    end)
  end
  
  defp normalize_business_type(attrs) do
    case Map.get(attrs, :business_type) do
      nil -> attrs
      :limited_company -> attrs
      :individual -> attrs
      :partnership -> attrs
      :plc -> attrs
      :other -> attrs
      _invalid_type -> 
        # Remove invalid business types
        Map.delete(attrs, :business_type)
    end
  end
  
  defp normalize_postcode(nil), do: nil
  defp normalize_postcode(postcode) when is_binary(postcode) do
    postcode |> String.trim() |> String.upcase()
  end
  
  defp create_offender_with_retry(attrs) do
    require Logger
    Logger.info("Creating offender: #{attrs[:name]} (#{attrs[:postcode] || "no postcode"})")
    
    case EhsEnforcement.Enforcement.create_offender(attrs) do
      {:ok, offender} ->
        Logger.info("✅ Created offender: #{offender.name} (ID: #{offender.id})")
        {:ok, offender}
        
      {:error, %Ash.Error.Invalid{} = error} ->
        Logger.warning("❌ Offender creation failed: #{attrs[:name]} - #{extract_error_message(error)}")
        # Handle race condition - try to find again
        case EhsEnforcement.Enforcement.get_offender_by_name_and_postcode(attrs.name, attrs[:postcode]) do
          {:ok, offender} -> 
            Logger.info("♻️ Found existing offender after race condition: #{offender.name} (ID: #{offender.id})")
            {:ok, offender}
          error -> 
            Logger.error("❌ Failed to find offender after creation error: #{inspect(error)}")
            error
        end
        
      error ->
        Logger.error("❌ Offender creation failed with unexpected error: #{inspect(error)}")
        error
    end
  end
  
  defp find_best_match([], _attrs), do: nil
  
  defp find_best_match(candidates, attrs) do
    search_postcode = normalize_postcode(attrs[:postcode])
    
    # Calculate similarity scores and postcode matches
    scored_candidates = candidates
    |> Enum.map(fn candidate ->
      # Calculate similarity if not already present
      similarity = case Map.get(candidate, :similarity) do
        nil -> calculate_similarity(get_name(candidate), attrs[:name] || "")
        existing -> existing
      end
      
      # Check if postcode matches
      candidate_postcode = normalize_postcode(get_postcode(candidate))
      postcode_match = candidate_postcode == search_postcode
      
      # If we have a search postcode and the candidate has a different postcode,
      # and they're both non-nil, then don't match (treat as different entities)
      postcode_conflict = search_postcode != nil && 
                         candidate_postcode != nil && 
                         candidate_postcode != search_postcode
      
      # Don't match if there's a postcode conflict (same name, different locations)
      if postcode_conflict do
        Map.put(candidate, :similarity, 0.0)  # Force no match
      else
        # Only boost similarity if it was calculated (not pre-provided)
        adjusted_similarity = case Map.get(candidate, :similarity) do
          nil -> 
            # We calculated it, so boost for postcode match
            if postcode_match && similarity > 0.6 do
              min(similarity + 0.15, 1.0)  # Boost by 0.15, but cap at 1.0
            else
              similarity
            end
          existing -> 
            # Pre-provided similarity score, don't modify it
            existing
        end
        
        candidate
        |> Map.put(:similarity, adjusted_similarity)
        |> Map.put(:postcode_match, postcode_match)
      end
    end)
    |> Enum.filter(fn candidate -> Map.get(candidate, :similarity, 0) > 0.7 end)
    |> Enum.sort_by(fn candidate ->
      # Sort by similarity desc, then postcode match desc
      similarity = Map.get(candidate, :similarity, 0)
      postcode_match = Map.get(candidate, :postcode_match, false)
      {similarity, if(postcode_match, do: 1, else: 0)}
    end, :desc)
    
    case scored_candidates do
      [] -> nil
      [best | _] -> best
    end
  end
  
  # Get name from candidate (works with both Offender structs and plain maps)
  defp get_name(%{name: name}), do: name
  defp get_name(candidate), do: Map.get(candidate, :name, "")
  
  # Get postcode from candidate (works with both Offender structs and plain maps)  
  defp get_postcode(%{postcode: postcode}), do: postcode
  defp get_postcode(candidate), do: Map.get(candidate, :postcode)
  
  defp calculate_similarity(str1, str2) do
    # Normalize both strings for comparison
    norm1 = normalize_company_name(str1 || "")
    norm2 = normalize_company_name(str2 || "")
    
    if norm1 == norm2 do
      1.0
    else
      # Use a combination of Jaccard similarity and length ratio
      jaccard = jaccard_similarity(norm1, norm2)
      
      # Boost score for very similar names (accounting for common variations)
      if String.jaro_distance(norm1, norm2) > 0.85 do
        max(jaccard, 0.9)
      else
        jaccard
      end
    end
  end
  
  defp jaccard_similarity(str1, str2) do
    # Split into normalized tokens for better matching
    tokens1 = str1 |> String.split(~r/\s+/) |> MapSet.new()
    tokens2 = str2 |> String.split(~r/\s+/) |> MapSet.new()
    
    intersection = MapSet.intersection(tokens1, tokens2) |> MapSet.size()
    union = MapSet.union(tokens1, tokens2) |> MapSet.size()
    
    if union == 0, do: 0.0, else: intersection / union
  end
  
  defp extract_error_message(%Ash.Error.Invalid{errors: errors}) when is_list(errors) do
    errors
    |> Enum.map(fn error -> "#{error.field || "unknown"}: #{error.message || inspect(error)}" end)
    |> Enum.join(", ")
  end
  defp extract_error_message(error), do: inspect(error)
end