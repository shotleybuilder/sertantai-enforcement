defmodule EhsEnforcementWeb.Admin.DuplicatesLive do
  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement.{Case, Notice, Offender}

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Duplicate Management")
     |> assign(:loading, true)
     |> assign(:active_tab, :cases)
     |> assign(:case_duplicates, [])
     |> assign(:notice_duplicates, [])
     |> assign(:offender_duplicates, [])
     |> assign(:current_group_index, 0)
     |> assign(:selected_records, MapSet.new())
     |> assign(:action_confirmation, nil)
     |> load_all_duplicates()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    # Allow navigation with a specific tab (e.g., /admin/duplicates?tab=notices)
    active_tab =
      case params["tab"] do
        "cases" -> :cases
        "notices" -> :notices
        "offenders" -> :offenders
        _ -> socket.assigns.active_tab
      end

    {:noreply, assign(socket, :active_tab, active_tab)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    active_tab = String.to_existing_atom(tab)

    {:noreply,
     socket
     |> assign(:active_tab, active_tab)
     |> assign(:current_group_index, 0)
     |> assign(:selected_records, MapSet.new())
     |> assign(:loading, true)
     |> load_active_tab_duplicates()
     |> assign(:loading, false)}
  end

  @impl true
  def handle_event("navigate_group", %{"direction" => direction}, socket) do
    current_groups = get_current_duplicates(socket.assigns)
    current_index = socket.assigns.current_group_index
    total_groups = length(current_groups)

    new_index =
      case direction do
        "prev" -> max(0, current_index - 1)
        "next" -> min(total_groups - 1, current_index + 1)
      end

    {:noreply,
     socket
     |> assign(:current_group_index, new_index)
     |> assign(:selected_records, MapSet.new())}
  end

  @impl true
  def handle_event("toggle_record", %{"id" => record_id}, socket) do
    selected = socket.assigns.selected_records

    new_selected =
      if MapSet.member?(selected, record_id) do
        MapSet.delete(selected, record_id)
      else
        MapSet.put(selected, record_id)
      end

    {:noreply, assign(socket, :selected_records, new_selected)}
  end

  @impl true
  def handle_event("confirm_action", %{"action" => action}, socket) do
    if MapSet.size(socket.assigns.selected_records) == 0 do
      {:noreply, put_flash(socket, :error, "Please select at least one record")}
    else
      confirmation_data = %{
        action: action,
        count: MapSet.size(socket.assigns.selected_records),
        records: MapSet.to_list(socket.assigns.selected_records)
      }

      {:noreply, assign(socket, :action_confirmation, confirmation_data)}
    end
  end

  @impl true
  def handle_event("execute_action", _params, socket) do
    case socket.assigns.action_confirmation do
      %{action: "delete", records: record_ids} ->
        execute_delete_action(socket, record_ids)

      %{action: "merge", records: record_ids} ->
        execute_merge_action(socket, record_ids)

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid action")}
    end
  end

  @impl true
  def handle_event("cancel_action", _params, socket) do
    {:noreply, assign(socket, :action_confirmation, nil)}
  end

  @impl true
  def handle_event("refresh_duplicates", _params, socket) do
    {:noreply,
     socket
     |> assign(:loading, true)
     |> assign(:selected_records, MapSet.new())
     |> load_active_tab_duplicates()
     |> assign(:loading, false)}
  end

  # Template helper functions

  defp get_current_duplicates(assigns) do
    case assigns.active_tab do
      :cases -> assigns.case_duplicates
      :notices -> assigns.notice_duplicates
      :offenders -> assigns.offender_duplicates
    end
  end

  defp get_current_group(assigns) do
    current_groups = get_current_duplicates(assigns)
    current_index = assigns.current_group_index

    if current_index < length(current_groups) do
      Enum.at(current_groups, current_index)
    else
      []
    end
  end

  # Private functions

  defp load_all_duplicates(socket) do
    # Load duplicates synchronously to avoid timeout issues
    # Start with empty state and load on demand
    socket
    |> assign(:case_duplicates, [])
    |> assign(:notice_duplicates, [])
    |> assign(:offender_duplicates, [])
    |> assign(:loading, false)
    |> load_active_tab_duplicates()
  end

  defp load_active_tab_duplicates(socket) do
    # Only load duplicates for the active tab to improve performance
    current_user = socket.assigns.current_user
    active_tab = socket.assigns.active_tab

    try do
      case active_tab do
        :cases ->
          case EhsEnforcement.Enforcement.DuplicateDetector.find_duplicate_cases(current_user) do
            {:ok, duplicates} ->
              # Reduced limit
              assign(socket, :case_duplicates, Enum.take(duplicates, 20))

            {:error, _} ->
              assign(socket, :case_duplicates, [])
          end

        :notices ->
          case EhsEnforcement.Enforcement.DuplicateDetector.find_duplicate_notices(current_user) do
            {:ok, duplicates} ->
              assign(socket, :notice_duplicates, Enum.take(duplicates, 20))

            {:error, _} ->
              assign(socket, :notice_duplicates, [])
          end

        :offenders ->
          case EhsEnforcement.Enforcement.DuplicateDetector.find_duplicate_offenders(current_user) do
            {:ok, duplicates} ->
              assign(socket, :offender_duplicates, Enum.take(duplicates, 20))

            {:error, _} ->
              assign(socket, :offender_duplicates, [])
          end
      end
    catch
      :exit, {:timeout, _} ->
        socket
        |> assign(:loading, false)
        |> put_flash(
          :error,
          "Duplicate detection timed out. Please try again with a smaller dataset."
        )
    end
  end

  defp execute_delete_action(socket, record_ids) do
    current_user = socket.assigns.current_user
    resource = get_resource_for_tab(socket.assigns.active_tab)

    results =
      Enum.map(record_ids, fn record_id ->
        case Ash.get(resource, record_id, actor: current_user) do
          {:ok, record} ->
            case Ash.destroy(record, actor: current_user) do
              :ok -> {:ok, record_id}
              {:error, error} -> {:error, {record_id, error}}
            end

          {:error, error} ->
            {:error, {record_id, error}}
        end
      end)

    successes = Enum.count(results, fn result -> match?({:ok, _}, result) end)
    failures = Enum.count(results, fn result -> match?({:error, _}, result) end)

    socket =
      if successes > 0 do
        put_flash(socket, :info, "Successfully deleted #{successes} records")
      else
        socket
      end

    socket =
      if failures > 0 do
        put_flash(socket, :error, "Failed to delete #{failures} records")
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:action_confirmation, nil)
     |> assign(:selected_records, MapSet.new())
     |> assign(:loading, true)
     |> load_all_duplicates()}
  end

  defp execute_merge_action(socket, _record_ids) do
    # For now, merge is not implemented - would need complex business logic
    {:noreply,
     socket
     |> assign(:action_confirmation, nil)
     |> put_flash(
       :info,
       "Merge functionality coming soon - please manually review and delete unwanted records"
     )}
  end

  defp get_resource_for_tab(tab) do
    case tab do
      :cases -> Case
      :notices -> Notice
      :offenders -> Offender
    end
  end

  # Duplicate detection functions (optimized for performance)
  defp find_duplicate_cases(current_user) do
    try do
      # Use a more efficient query with limit and timeout
      query = Case |> Ash.Query.limit(1000) |> Ash.Query.load([:agency, :offender])

      case Ash.read(query, actor: current_user, timeout: 15_000) do
        {:ok, cases} ->
          # Strategy 1: Find cases with exact regulator_id matches
          regulator_id_duplicates =
            cases
            |> Enum.filter(fn case ->
              case.regulator_id && String.trim(case.regulator_id) != ""
            end)
            |> Enum.group_by(fn case -> String.trim(case.regulator_id) end)
            |> Enum.filter(fn {_key, group} -> length(group) > 1 end)
            |> Enum.map(fn {_key, group} -> group end)

          # Strategy 2: Find cases with same offender + action date (limited subset)
          offender_date_duplicates =
            cases
            |> Enum.filter(fn case -> case.offender_id && case.offence_action_date end)
            |> Enum.group_by(fn case -> {case.offender_id, case.offence_action_date} end)
            |> Enum.filter(fn {_key, group} -> length(group) > 1 end)
            |> Enum.map(fn {_key, group} -> group end)

          # Combine and remove overlaps
          all_duplicates = regulator_id_duplicates ++ offender_date_duplicates
          unique_groups = remove_overlapping_groups(all_duplicates)

          {:ok, unique_groups}

        {:error, error} ->
          {:error, error}
      end
    rescue
      error -> {:error, error}
    end
  end

  defp find_duplicate_notices(current_user) do
    try do
      # Use a more efficient query with limit and timeout
      query = Notice |> Ash.Query.limit(1000) |> Ash.Query.load([:agency, :offender])

      case Ash.read(query, actor: current_user, timeout: 15_000) do
        {:ok, notices} ->
          # Strategy 1: Find notices with exact regulator_id matches
          regulator_id_duplicates =
            notices
            |> Enum.filter(fn notice ->
              notice.regulator_id && String.trim(notice.regulator_id) != ""
            end)
            |> Enum.group_by(fn notice -> String.trim(notice.regulator_id) end)
            |> Enum.filter(fn {_key, group} -> length(group) > 1 end)
            |> Enum.map(fn {_key, group} -> group end)

          # Strategy 2: Find notices with same offender + action date
          offender_date_duplicates =
            notices
            |> Enum.filter(fn notice -> notice.offender_id && notice.offence_action_date end)
            |> Enum.group_by(fn notice -> {notice.offender_id, notice.offence_action_date} end)
            |> Enum.filter(fn {_key, group} -> length(group) > 1 end)
            |> Enum.map(fn {_key, group} -> group end)

          # Combine and remove overlaps
          all_duplicates = regulator_id_duplicates ++ offender_date_duplicates
          unique_groups = remove_overlapping_groups(all_duplicates)

          {:ok, unique_groups}

        {:error, error} ->
          {:error, error}
      end
    rescue
      error -> {:error, error}
    end
  end

  defp find_duplicate_offenders(current_user) do
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

  defp find_fuzzy_name_duplicates(offenders) do
    # Simple fuzzy matching - find names that are very similar
    offenders
    |> Enum.with_index()
    |> Enum.flat_map(fn {offender1, i} ->
      offenders
      |> Enum.drop(i + 1)
      |> Enum.filter(fn offender2 ->
        names_similar?(offender1.name, offender2.name)
      end)
      |> Enum.map(fn offender2 -> [offender1, offender2] end)
    end)
  end

  defp names_similar?(name1, name2) when is_binary(name1) and is_binary(name2) do
    # Normalize names
    norm1 = name1 |> String.downcase() |> String.trim() |> String.replace(~r/\s+/, " ")
    norm2 = name2 |> String.downcase() |> String.trim() |> String.replace(~r/\s+/, " ")

    # Check for very high similarity (> 80%)
    similarity = string_similarity(norm1, norm2)
    similarity > 0.8 and norm1 != norm2
  end

  defp names_similar?(_, _), do: false

  defp string_similarity(str1, str2) do
    # Simple Jaro-Winkler approximation
    len1 = String.length(str1)
    len2 = String.length(str2)

    if len1 == 0 and len2 == 0 do
      1.0
    else
      max_len = max(len1, len2)
      common_chars = count_common_characters(str1, str2)
      common_chars / max_len
    end
  end

  defp count_common_characters(str1, str2) do
    chars1 = String.graphemes(str1)
    chars2 = String.graphemes(str2)

    chars1
    |> Enum.filter(fn char -> char in chars2 end)
    |> length()
  end

  defp remove_overlapping_groups(groups) do
    # Remove duplicate groups where records appear in multiple groups
    # Keep the largest group for each record

    groups_with_index = Enum.with_index(groups)

    # Build map of record ID -> group index
    record_to_group =
      groups_with_index
      |> Enum.reduce(%{}, fn {group, index}, acc ->
        group
        |> Enum.reduce(acc, fn record, inner_acc ->
          Map.update(inner_acc, record.id, [index], fn existing ->
            [index | existing]
          end)
        end)
      end)

    # For each record that appears in multiple groups, keep only the largest group
    kept_groups =
      groups_with_index
      |> Enum.map(fn {group, index} ->
        if Enum.all?(group, fn record ->
             group_indices = Map.get(record_to_group, record.id, [])

             largest_group_index =
               group_indices
               |> Enum.max_by(fn group_idx -> length(Enum.at(groups, group_idx)) end)

             largest_group_index == index
           end) do
          group
        else
          nil
        end
      end)
      |> Enum.filter(fn group -> group != nil end)

    kept_groups
  end
end
