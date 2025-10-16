#!/usr/bin/env elixir

# Development Database Cleanup Script
# Removes duplicate legislation records and normalizes data
# 
# IMPORTANT: This is for DEVELOPMENT ONLY - legislation table not in production
# 
# Usage: mix run scripts/cleanup_legislation_duplicates.exs

# Running within Mix project - dependencies already available

defmodule LegislationCleanup do
  @moduledoc """
  Development database cleanup for legislation duplicates.
  
  Since the legislation table has NOT been deployed to production,
  this script safely cleans up the development database by:
  
  1. Identifying duplicate legislation records
  2. Choosing canonical versions (with proper title, year, number)
  3. Updating foreign key references in offences table
  4. Removing duplicate records
  5. Normalizing remaining titles
  """

  require Logger

  def run do
    Logger.info("Starting legislation duplicate cleanup...")
    
    # Check if we're in development
    unless Application.get_env(:ehs_enforcement, :environment) == :dev do
      Logger.error("This script is for DEVELOPMENT ONLY!")
      System.halt(1)
    end
    
    # Start the application to get database connection
    Application.ensure_all_started(:ehs_enforcement)
    
    try do
      stats_before = get_legislation_stats()
      Logger.info("Before cleanup: #{stats_before}")
      
      # Step 1: Find and process duplicates
      duplicates = find_duplicate_groups()
      Logger.info("Found #{length(duplicates)} duplicate groups")
      
      # Step 2: Process each duplicate group
      Enum.each(duplicates, &process_duplicate_group/1)
      
      # Step 3: Normalize all remaining titles
      normalize_all_titles()
      
      # Step 4: Validate results
      stats_after = get_legislation_stats()
      Logger.info("After cleanup: #{stats_after}")
      
      Logger.info("Legislation cleanup completed successfully!")
      
    rescue
      error ->
        Logger.error("Cleanup failed: #{inspect(error)}")
        System.halt(1)
    end
  end

  defp get_legislation_stats do
    query = """
    SELECT 
      COUNT(*) as total_count,
      COUNT(CASE WHEN legislation_year IS NULL THEN 1 END) as missing_year,
      COUNT(CASE WHEN legislation_number IS NULL THEN 1 END) as missing_number,
      COUNT(DISTINCT legislation_title) as unique_titles
    FROM legislation
    """
    
    case Ecto.Adapters.SQL.query(EhsEnforcement.Repo, query) do
      {:ok, %{rows: [[total, missing_year, missing_number, unique_titles]]}} ->
        %{
          total: total,
          missing_year: missing_year,
          missing_number: missing_number,
          unique_titles: unique_titles
        }
      error ->
        Logger.error("Failed to get stats: #{inspect(error)}")
        %{}
    end
  end

  defp find_duplicate_groups do
    # Find groups of legislation that are likely duplicates
    # Group by normalized title to identify semantic duplicates
    query = """
    WITH normalized_titles AS (
      SELECT 
        id,
        legislation_title,
        legislation_year,
        legislation_number,
        legislation_type,
        LOWER(TRIM(legislation_title)) as normalized_title
      FROM legislation
    ),
    duplicate_groups AS (
      SELECT 
        normalized_title,
        COUNT(*) as count,
        ARRAY_AGG(id ORDER BY 
          CASE WHEN legislation_year IS NOT NULL AND legislation_number IS NOT NULL THEN 1
               WHEN legislation_year IS NOT NULL THEN 2
               ELSE 3 END,
          char_length(legislation_title) DESC
        ) as ids
      FROM normalized_titles
      GROUP BY normalized_title
      HAVING COUNT(*) > 1
    )
    SELECT * FROM duplicate_groups
    """
    
    case Ecto.Adapters.SQL.query(EhsEnforcement.Repo, query) do
      {:ok, result} ->
        Enum.map(result.rows, fn [normalized_title, count, ids] ->
          %{
            normalized_title: normalized_title,
            count: count,
            ids: ids
          }
        end)
      error ->
        Logger.error("Failed to find duplicates: #{inspect(error)}")
        []
    end
  end

  defp process_duplicate_group(%{normalized_title: title, ids: ids, count: count}) do
    Logger.info("Processing duplicate group: '#{title}' (#{count} records)")
    
    # Get full details for each record in the group
    records = get_legislation_records(ids)
    
    # Choose the canonical record (best quality data)
    canonical = choose_canonical_record(records)
    
    # Get non-canonical records to remove
    duplicates = Enum.reject(records, & &1.id == canonical.id)
    
    Logger.info("  Canonical: #{canonical.legislation_title} (#{canonical.legislation_year}, #{canonical.legislation_number})")
    Logger.info("  Removing #{length(duplicates)} duplicates")
    
    # Update foreign key references
    update_foreign_key_references(duplicates, canonical.id)
    
    # Remove duplicate records
    remove_duplicate_records(duplicates)
    
    # Normalize the canonical record title
    normalize_canonical_record(canonical)
  end

  defp get_legislation_records(ids) do
    query = """
    SELECT id, legislation_title, legislation_year, legislation_number, legislation_type
    FROM legislation
    WHERE id = ANY($1)
    """
    
    case Ecto.Adapters.SQL.query(EhsEnforcement.Repo, query, [ids]) do
      {:ok, result} ->
        Enum.map(result.rows, fn [id, title, year, number, type] ->
          %{
            id: id,
            legislation_title: title,
            legislation_year: year,
            legislation_number: number,
            legislation_type: String.to_atom(type)
          }
        end)
      error ->
        Logger.error("Failed to get records: #{inspect(error)}")
        []
    end
  end

  defp choose_canonical_record(records) do
    # Score records by data quality (higher score = better)
    scored_records = Enum.map(records, fn record ->
      score = calculate_quality_score(record)
      {record, score}
    end)
    
    # Choose the record with the highest score
    {canonical, _score} = Enum.max_by(scored_records, fn {_record, score} -> score end)
    canonical
  end

  defp calculate_quality_score(record) do
    base_score = 0
    
    # Prefer records with both year and number
    score = if record.legislation_year && record.legislation_number do
      base_score + 100
    else
      base_score
    end
    
    # Prefer records with year
    score = if record.legislation_year do
      score + 50
    else
      score
    end
    
    # Prefer records with proper title case and "etc." 
    score = if String.contains?(record.legislation_title, "etc.") do
      score + 25
    else
      score
    end
    
    # Prefer longer, more descriptive titles
    score = score + String.length(record.legislation_title)
    
    score
  end

  defp update_foreign_key_references(duplicates, canonical_id) do
    duplicate_ids = Enum.map(duplicates, & &1.id)
    
    if length(duplicate_ids) > 0 do
      # Update offences table to point to canonical legislation
      query = """
      UPDATE offences 
      SET legislation_id = $1 
      WHERE legislation_id = ANY($2)
      """
      
      case Ecto.Adapters.SQL.query(EhsEnforcement.Repo, query, [canonical_id, duplicate_ids]) do
        {:ok, %{num_rows: updated_count}} ->
          Logger.info("  Updated #{updated_count} offence references")
        error ->
          Logger.error("  Failed to update foreign keys: #{inspect(error)}")
      end
    end
  end

  defp remove_duplicate_records(duplicates) do
    duplicate_ids = Enum.map(duplicates, & &1.id)
    
    if length(duplicate_ids) > 0 do
      query = """
      DELETE FROM legislation 
      WHERE id = ANY($1)
      """
      
      case Ecto.Adapters.SQL.query(EhsEnforcement.Repo, query, [duplicate_ids]) do
        {:ok, %{num_rows: deleted_count}} ->
          Logger.info("  Deleted #{deleted_count} duplicate records")
        error ->
          Logger.error("  Failed to delete duplicates: #{inspect(error)}")
      end
    end
  end

  defp normalize_canonical_record(canonical) do
    # Apply title normalization to the canonical record
    normalized_title = normalize_title(canonical.legislation_title)
    
    if normalized_title != canonical.legislation_title do
      query = """
      UPDATE legislation 
      SET legislation_title = $1 
      WHERE id = $2
      """
      
      case Ecto.Adapters.SQL.query(EhsEnforcement.Repo, query, [normalized_title, canonical.id]) do
        {:ok, _} ->
          Logger.info("  Normalized title: '#{canonical.legislation_title}' -> '#{normalized_title}'")
        error ->
          Logger.error("  Failed to normalize title: #{inspect(error)}")
      end
    end
  end

  defp normalize_all_titles do
    Logger.info("Normalizing all remaining legislation titles...")
    
    # Get all legislation records
    query = "SELECT id, legislation_title FROM legislation"
    
    case Ecto.Adapters.SQL.query(EhsEnforcement.Repo, query) do
      {:ok, result} ->
        updates = Enum.reduce(result.rows, [], fn [id, title], acc ->
          normalized = normalize_title(title)
          if normalized != title do
            [{id, title, normalized} | acc]
          else
            acc
          end
        end)
        
        Logger.info("Normalizing #{length(updates)} titles")
        
        Enum.each(updates, fn {id, old_title, new_title} ->
          update_query = "UPDATE legislation SET legislation_title = $1 WHERE id = $2"
          case Ecto.Adapters.SQL.query(EhsEnforcement.Repo, update_query, [new_title, id]) do
            {:ok, _} ->
              Logger.debug("  '#{old_title}' -> '#{new_title}'")
            error ->
              Logger.error("  Failed to update title for ID #{id}: #{inspect(error)}")
          end
        end)
        
      error ->
        Logger.error("Failed to get legislation for normalization: #{inspect(error)}")
    end
  end

  defp normalize_title(title) when is_binary(title) do
    title
    |> String.trim()
    |> String.downcase()
    # Convert to proper title case
    |> String.split(" ")
    |> Enum.map(&title_case_word/1)
    |> Enum.join(" ")
    |> clean_common_patterns()
  end

  # Words that should remain lowercase in title case (except at start)
  @small_words ~w[at of and the in on for with to by under from]

  defp title_case_word(word) when word in @small_words, do: word
  defp title_case_word(word), do: String.capitalize(word)

  # Clean up common patterns and abbreviations
  defp clean_common_patterns(title) do
    title
    # Fix "etc." placement
    |> String.replace(~r/\betc\b/, "etc.")
    # Standardize "H&S" vs "health and safety"
    |> String.replace(~r/\bh&s\b/i, "Health and Safety")
    # Fix common abbreviations
    |> String.replace(~r/\bcdm\b/i, "Construction (Design and Management)")
    |> String.replace(~r/\bcoshh\b/i, "Control of Substances Hazardous to Health")
    |> String.replace(~r/\bpuwer\b/i, "Provision and Use of Work Equipment")
    |> String.replace(~r/\bdsear\b/i, "Dangerous Substances and Explosive Atmospheres")
    |> String.replace(~r/\bloler\b/i, "Lifting Operations and Lifting Equipment")
    |> String.replace(~r/\bcomah\b/i, "Control of Major Accident Hazards")
    # Ensure proper spacing
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end

# Run the cleanup
LegislationCleanup.run()