defmodule EhsEnforcement.Scraping.Shared.EnvironmentalHelpers do
  @moduledoc """
  Shared utilities for processing EA environmental impact data.

  This module consolidates environmental impact and receptor detection logic
  that was previously duplicated across EA case and notice processors.

  ## Usage

      iex> EnvironmentalHelpers.assess_environmental_impact("major", "minor", nil)
      "major"

      iex> EnvironmentalHelpers.detect_primary_receptor("major", nil, "minor")
      "water"

      iex> EnvironmentalHelpers.build_environmental_impact_string("major", "minor", nil)
      "major; minor"
  """

  @doc """
  Assesses overall environmental impact severity from water, land, and air impacts.

  Returns the highest severity level found:
  - "major" if any impact is major
  - "minor" if any impact is minor (and none are major)
  - "none" if no impacts detected

  ## Parameters
  - `water_impact` - Water impact level (string or nil)
  - `land_impact` - Land impact level (string or nil)
  - `air_impact` - Air impact level (string or nil)

  ## Returns
  - String: "major", "minor", or "none"
  """
  def assess_environmental_impact(water_impact, land_impact, air_impact) do
    impacts = [water_impact, land_impact, air_impact]

    cond do
      Enum.any?(impacts, &(&1 == "major")) -> "major"
      Enum.any?(impacts, &(&1 == "minor")) -> "minor"
      true -> "none"
    end
  end

  @doc """
  Detects the primary environmental receptor affected.

  Prioritizes by severity (major over minor) then by order (water > land > air).
  Returns "land" as default for general environmental cases.

  ## Parameters
  - `water_impact` - Water impact level (string or nil)
  - `land_impact` - Land impact level (string or nil)
  - `air_impact` - Air impact level (string or nil)

  ## Returns
  - String: "water", "land", or "air"
  """
  def detect_primary_receptor(water_impact, land_impact, air_impact) do
    case {water_impact, land_impact, air_impact} do
      {"major", _, _} -> "water"
      {_, "major", _} -> "land"
      {_, _, "major"} -> "air"
      {"minor", _, _} -> "water"
      {_, "minor", _} -> "land"
      {_, _, "minor"} -> "air"
      # Default to land for general environmental cases
      _ -> "land"
    end
  end

  @doc """
  Builds a combined string of all environmental impacts.

  Joins non-empty impact values with "; " separator.
  Returns nil if no impacts found.

  Useful for storing all impact details in a single field.

  ## Parameters
  - `water_impact` - Water impact level (string or nil)
  - `land_impact` - Land impact level (string or nil)
  - `air_impact` - Air impact level (string or nil)

  ## Returns
  - String of joined impacts (e.g., "major; minor") or nil if no impacts
  """
  def build_environmental_impact_string(water_impact, land_impact, air_impact) do
    impacts =
      [water_impact, land_impact, air_impact]
      |> Enum.filter(&(&1 != nil && &1 != ""))
      |> Enum.join("; ")

    case impacts do
      "" -> nil
      impact_str -> impact_str
    end
  end

  @doc """
  Detects any environmental receptor that has an impact.

  Returns the first receptor with a non-empty impact value, checking in order:
  water > land > air. Returns nil if no impacts found.

  ## Parameters
  - `water_impact` - Water impact level (string or nil)
  - `land_impact` - Land impact level (string or nil)
  - `air_impact` - Air impact level (string or nil)

  ## Returns
  - String: "water", "land", "air", or nil
  """
  def detect_environmental_receptor(water_impact, land_impact, air_impact) do
    cond do
      water_impact not in [nil, ""] -> "water"
      land_impact not in [nil, ""] -> "land"
      air_impact not in [nil, ""] -> "air"
      true -> nil
    end
  end
end
