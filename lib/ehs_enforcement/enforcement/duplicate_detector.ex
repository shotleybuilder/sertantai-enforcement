defmodule EhsEnforcement.Enforcement.DuplicateDetector do
  @moduledoc """
  Handles duplicate detection logic for enforcement records.
  """

  alias EhsEnforcement.Enforcement.{Case, Notice, Offender}
  require Ash.Query

  @doc """
  Find duplicate cases using multiple strategies.
  """
  def find_duplicate_cases(current_user) do
    try do
      # Load cases with offender and agency relationships for display in UI
      query = Case |> Ash.Query.load([:offender, :agency])

      # Strategy 1: Find cases with exact regulator_id matches
      regulator_id_duplicates =
        case Ash.read(query, actor: current_user) do
          {:ok, cases} ->
            cases
            |> Enum.filter(fn case ->
              case.regulator_id && String.trim(case.regulator_id) != ""
            end)
            |> Enum.group_by(fn case -> String.trim(case.regulator_id) end)
            |> Enum.filter(fn {_regulator_id, cases} -> length(cases) > 1 end)
            |> Enum.map(fn {_regulator_id, cases} -> cases end)

          {:error, _error} ->
            []
        end

      # Strategy 2: Find cases with same offender + action date
      offender_date_duplicates =
        case Ash.read(query, actor: current_user) do
          {:ok, cases} ->
            cases
            |> Enum.filter(fn case -> case.offender_id && case.offence_action_date end)
            |> Enum.group_by(fn case -> {case.offender_id, case.offence_action_date} end)
            |> Enum.filter(fn {_key, cases} -> length(cases) > 1 end)
            |> Enum.map(fn {_key, cases} -> cases end)

          {:error, _error} ->
            []
        end

      # Strategy 3: Find cases with same offender + exact fine + costs amounts
      financial_duplicates =
        case Ash.read(query, actor: current_user) do
          {:ok, cases} ->
            cases
            |> Enum.filter(fn case ->
              case.offender_id && case.offence_fine && case.offence_costs &&
                Decimal.compare(case.offence_fine, Decimal.new(0)) == :gt
            end)
            |> Enum.group_by(fn case ->
              {case.offender_id, case.offence_fine, case.offence_costs}
            end)
            |> Enum.filter(fn {_key, cases} -> length(cases) > 1 end)
            |> Enum.map(fn {_key, cases} -> cases end)

          {:error, _error} ->
            []
        end

      # Combine all duplicate groups and remove overlaps
      all_duplicates = regulator_id_duplicates ++ offender_date_duplicates ++ financial_duplicates
      unique_groups = remove_overlapping_groups(all_duplicates)

      {:ok, unique_groups}
    rescue
      error ->
        {:error, error}
    end
  end

  @doc """
  Find duplicate notices using multiple strategies.
  """
  def find_duplicate_notices(current_user) do
    try do
      # Load notices with offender and agency relationships for display in UI
      query = Notice |> Ash.Query.load([:offender, :agency])

      # Strategy 1: Find notices with exact regulator_id matches
      regulator_id_duplicates =
        case Ash.read(query, actor: current_user) do
          {:ok, notices} ->
            notices
            |> Enum.filter(fn notice ->
              notice.regulator_id && String.trim(notice.regulator_id) != ""
            end)
            |> Enum.group_by(fn notice -> String.trim(notice.regulator_id) end)
            |> Enum.filter(fn {_regulator_id, notices} -> length(notices) > 1 end)
            |> Enum.map(fn {_regulator_id, notices} -> notices end)

          {:error, _error} ->
            []
        end

      # Strategy 2: Find notices with same offender + action date
      offender_date_duplicates =
        case Ash.read(query, actor: current_user) do
          {:ok, notices} ->
            notices
            |> Enum.filter(fn notice -> notice.offender_id && notice.offence_action_date end)
            |> Enum.group_by(fn notice -> {notice.offender_id, notice.offence_action_date} end)
            |> Enum.filter(fn {_key, notices} -> length(notices) > 1 end)
            |> Enum.map(fn {_key, notices} -> notices end)

          {:error, _error} ->
            []
        end

      # Strategy 3: Find notices with same regulator_ref_number (if available)
      ref_number_duplicates =
        case Ash.read(query, actor: current_user) do
          {:ok, notices} ->
            notices
            |> Enum.filter(fn notice ->
              notice.regulator_ref_number && String.trim(notice.regulator_ref_number) != ""
            end)
            |> Enum.group_by(fn notice -> String.trim(notice.regulator_ref_number) end)
            |> Enum.filter(fn {_ref, notices} -> length(notices) > 1 end)
            |> Enum.map(fn {_ref, notices} -> notices end)

          {:error, _error} ->
            []
        end

      # Combine all duplicate groups and remove overlaps
      all_duplicates =
        regulator_id_duplicates ++ offender_date_duplicates ++ ref_number_duplicates

      unique_groups = remove_overlapping_groups(all_duplicates)

      {:ok, unique_groups}
    rescue
      error ->
        {:error, error}
    end
  end

  @doc """
  Find duplicate offenders using multiple strategies.
  """
  def find_duplicate_offenders(current_user) do
    try do
      # Use a more efficient query with limit and timeout
      # Smaller limit for offenders
      query = Offender |> Ash.Query.limit(500)

      case Ash.read(query, actor: current_user, timeout: 15_000) do
        {:ok, offenders} ->
          # Strategy 1: Find offenders with exact name matches (case-insensitive)
          name_duplicates =
            offenders
            |> Enum.filter(fn offender -> offender.name && String.trim(offender.name) != "" end)
            |> Enum.group_by(fn offender -> String.downcase(String.trim(offender.name)) end)
            |> Enum.filter(fn {_key, group} -> length(group) > 1 end)
            |> Enum.map(fn {_key, group} -> group end)

          # Skip fuzzy matching for now as it's computationally expensive
          # Can be re-enabled later with better algorithms

          {:ok, name_duplicates}

        {:error, error} ->
          {:error, error}
      end
    rescue
      error -> {:error, error}
    end
  end

  # Private helper functions

  defp remove_overlapping_groups(groups) do
    # Remove duplicate groups where cases appear in multiple groups
    # Keep the largest group for each case
    case_to_group = %{}

    groups
    |> Enum.with_index()
    |> Enum.reduce(case_to_group, fn {group, index}, acc ->
      Enum.reduce(group, acc, fn case, inner_acc ->
        case_id = case.id

        existing_group_size =
          case Map.get(inner_acc, case_id) do
            {_, size} -> size
            nil -> 0
          end

        if length(group) > existing_group_size do
          Map.put(inner_acc, case_id, {index, length(group)})
        else
          inner_acc
        end
      end)
    end)
    |> Map.values()
    |> Enum.map(fn {index, _size} -> index end)
    |> Enum.uniq()
    |> Enum.map(fn index -> Enum.at(groups, index) end)
    |> Enum.filter(fn group -> group != nil end)
  end
end
