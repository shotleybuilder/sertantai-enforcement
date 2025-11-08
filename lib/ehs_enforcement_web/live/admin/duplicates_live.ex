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
     |> assign(:loading, false)
     |> push_patch(to: ~p"/admin/duplicates?tab=#{tab}")}
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

end
