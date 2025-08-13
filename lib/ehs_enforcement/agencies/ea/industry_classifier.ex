defmodule EhsEnforcement.Agencies.Ea.IndustryClassifier do
  @moduledoc """
  Handles mapping of EA industry sectors to HSE high-level categories.
  Supports automated classification with confidence scoring and admin overrides.
  """

  require Logger
  # alias EhsEnforcement.Enforcement  # Unused for now

  # Default classification rules - can be overridden by admin-configured mappings
  @default_classification_rules [
    # Manufacturing patterns
    {~r/manufacturing/i, "Manufacturing", 0.95},
    {~r/production/i, "Manufacturing", 0.85},
    {~r/processing/i, "Manufacturing", 0.80},
    {~r/chemical/i, "Manufacturing", 0.90},
    {~r/engineering/i, "Manufacturing", 0.85},
    {~r/food.*processing/i, "Manufacturing", 0.90},
    
    # Construction patterns
    {~r/construction/i, "Construction", 0.95},
    {~r/building/i, "Construction", 0.85},
    {~r/infrastructure/i, "Construction", 0.80},
    {~r/civil.*engineering/i, "Construction", 0.85},
    
    # Extractive and utility patterns
    {~r/water.*treatment/i, "Extractive and utility supply industries", 0.90},
    {~r/water.*supply/i, "Extractive and utility supply industries", 0.90},
    {~r/mining/i, "Extractive and utility supply industries", 0.95},
    {~r/quarrying/i, "Extractive and utility supply industries", 0.95},
    {~r/utility/i, "Extractive and utility supply industries", 0.85},
    {~r/power.*generation/i, "Extractive and utility supply industries", 0.90},
    
    # Agriculture patterns
    {~r/agriculture/i, "Agriculture hunting forestry and fishing", 0.95},
    {~r/farming/i, "Agriculture hunting forestry and fishing", 0.90},
    {~r/forestry/i, "Agriculture hunting forestry and fishing", 0.95},
    {~r/fishing/i, "Agriculture hunting forestry and fishing", 0.95},
    {~r/crop.*production/i, "Agriculture hunting forestry and fishing", 0.90},
    
    # Service patterns
    {~r/waste.*management/i, "Total service industries", 0.90},
    {~r/transport/i, "Total service industries", 0.80},
    {~r/logistics/i, "Total service industries", 0.80},
    {~r/retail/i, "Total service industries", 0.75},
    {~r/wholesale/i, "Total service industries", 0.75},
    {~r/distribution/i, "Total service industries", 0.75},
    {~r/services/i, "Total service industries", 0.70}
  ]

  def classify_ea_sector(ea_sector_name, opts \\ []) do
    # 1. Try exact match from admin-configured mappings first
    case get_admin_configured_mapping(ea_sector_name) do
      {:error, :not_found} ->
        # 2. Fall back to pattern-based classification
        classify_by_patterns(ea_sector_name, opts)
    end
  end
  
  defp get_admin_configured_mapping(_ea_sector_name) do
    # TODO: Query IndustrySubcategory resource for exact match
    # For now, return not found to use pattern matching
    {:error, :not_found}
  end
  
  defp classify_by_patterns(ea_sector_name, opts) do
    confidence_threshold = opts[:confidence_threshold] || 0.60
    
    # Find best matching rule
    best_match = @default_classification_rules
    |> Enum.map(fn {pattern, category, base_confidence} ->
      if Regex.match?(pattern, ea_sector_name) do
        # Adjust confidence based on match quality
        adjusted_confidence = calculate_adjusted_confidence(ea_sector_name, pattern, base_confidence)
        {pattern, category, adjusted_confidence}
      else
        nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.max_by(fn {_pattern, _category, confidence} -> confidence end, fn -> nil end)
    
    case best_match do
      {_pattern, category, confidence} when confidence >= confidence_threshold ->
        {:ok, category, confidence, :pattern_match}
        
      {_pattern, category, confidence} ->
        # Low confidence - flag for manual review
        Logger.warning("Low confidence industry classification: '#{ea_sector_name}' → #{category} (#{confidence})")
        {:ok, category, confidence, :low_confidence}
        
      nil ->
        # No pattern matches
        {:ok, "Unknown", 0.0, :no_match}
    end
  end
  
  defp calculate_adjusted_confidence(ea_sector_name, _pattern, base_confidence) do
    # Adjust confidence based on pattern match quality
    sector_length = String.length(ea_sector_name)
    
    # Boost confidence for longer, more specific sector names
    length_multiplier = case sector_length do
      len when len > 40 -> 1.1  # Very detailed sector names
      len when len > 25 -> 1.05 # Detailed sector names
      len when len > 15 -> 1.0  # Standard sector names
      _ -> 0.95             # Short/generic sector names
    end
    
    # Cap at 1.0
    min(base_confidence * length_multiplier, 1.0)
  end
  
  def bulk_classify_sectors(ea_sectors) when is_list(ea_sectors) do
    ea_sectors
    |> Enum.map(fn sector ->
      case classify_ea_sector(sector) do
        {:ok, category, confidence, method} ->
          %{
            ea_sector: sector,
            hse_category: category,
            confidence: confidence,
            method: method,
            needs_review: confidence < 0.80
          }
      end
    end)
  end
  
  def suggest_new_mapping(ea_sector_name) do
    # Use LLM or advanced pattern matching to suggest classification
    # This would integrate with OpenAI API or similar for intelligent suggestions
    
    case classify_ea_sector(ea_sector_name) do
      {:ok, category, confidence, method} ->
        %{
          suggested_category: category,
          confidence: confidence,
          reasoning: build_reasoning(ea_sector_name, category, method),
          alternative_categories: suggest_alternatives(ea_sector_name, category)
        }
    end
  end
  
  defp build_reasoning(ea_sector_name, category, method) do
    case method do
      :pattern_match ->
        "Matched industry keywords in '#{ea_sector_name}' to #{category}"
      :low_confidence ->
        "Weak pattern match - manual review recommended"
      :no_match ->
        "No clear pattern matches found"
      _ ->
        "Classified using #{method} method"
    end
  end
  
  defp suggest_alternatives(ea_sector_name, primary_category) do
    # Return other possible categories with lower confidence
    @default_classification_rules
    |> Enum.filter(fn {pattern, category, _conf} ->
      category != primary_category && Regex.match?(pattern, ea_sector_name)
    end)
    |> Enum.map(fn {_pattern, category, confidence} -> {category, confidence * 0.8} end)
    |> Enum.sort_by(fn {_cat, conf} -> conf end, :desc)
    |> Enum.take(2)
  end
  
  def validate_mapping_accuracy(mappings) do
    # Analyze classification accuracy and suggest improvements
    total_count = length(mappings)
    high_confidence = Enum.count(mappings, & &1.confidence >= 0.85)
    needs_review = Enum.count(mappings, & &1.needs_review)
    
    %{
      total_sectors: total_count,
      high_confidence_count: high_confidence,
      accuracy_rate: high_confidence / total_count,
      manual_review_needed: needs_review,
      review_percentage: needs_review / total_count,
      recommendations: generate_accuracy_recommendations(mappings)
    }
  end
  
  defp generate_accuracy_recommendations(mappings) do
    low_confidence_sectors = mappings
    |> Enum.filter(& &1.confidence < 0.70)
    |> Enum.map(& &1.ea_sector)
    
    recommendations = []
    
    recommendations = if length(low_confidence_sectors) > 0 do
      ["Consider manual review for #{length(low_confidence_sectors)} low-confidence sectors" | recommendations]
    else
      recommendations
    end
    
    recommendations = if Enum.any?(mappings, & &1.method == :no_match) do
      ["Add new classification patterns for unmatched sectors" | recommendations]
    else
      recommendations
    end
    
    recommendations
  end
end