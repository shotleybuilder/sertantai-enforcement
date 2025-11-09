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
     |> assign(:company_number_duplicates, [])
     |> assign(:current_group_index, 0)
     |> assign(:selected_records, MapSet.new())
     |> assign(:selected_master_id, nil)
     |> assign(:merge_preview, nil)
     |> assign(:action_confirmation, nil)
     |> assign(:detection_task, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    require Logger

    # Allow navigation with a specific tab (e.g., /admin/duplicates?tab=notices)
    active_tab =
      case params["tab"] do
        "cases" -> :cases
        "notices" -> :notices
        "offenders" -> :offenders
        _ -> socket.assigns.active_tab
      end

    # Only reload if tab actually changed
    socket =
      if active_tab != socket.assigns.active_tab do
        Logger.info("Duplicate detection: Tab changed to #{active_tab}, starting async detection")

        # Cancel any existing task
        if socket.assigns.detection_task do
          _ = Task.shutdown(socket.assigns.detection_task, :brutal_kill)
        end

        # Start async detection task
        task =
          Task.async(fn ->
            load_duplicates_for_tab(active_tab, socket.assigns.current_user)
          end)

        socket
        |> assign(:active_tab, active_tab)
        |> assign(:current_group_index, 0)
        |> assign(:selected_records, MapSet.new())
        |> assign(:loading, true)
        |> assign(:detection_task, task)
      else
        assign(socket, :active_tab, active_tab)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    # Use push_patch to trigger handle_params which has the async logic
    {:noreply, push_patch(socket, to: ~p"/admin/duplicates?tab=#{tab}")}
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
    # Start async reload
    task =
      Task.async(fn ->
        load_duplicates_for_tab(socket.assigns.active_tab, socket.assigns.current_user)
      end)

    {:noreply,
     socket
     |> assign(:loading, true)
     |> assign(:selected_records, MapSet.new())
     |> assign(:detection_task, task)}
  end

  @impl true
  def handle_event("select_master", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_master_id, id)}
  end

  @impl true
  def handle_event(
        "sync_and_merge",
        %{"id" => master_id, "duplicates" => duplicate_ids_json},
        socket
      ) do
    duplicate_ids = Jason.decode!(duplicate_ids_json)

    # Call preview function to get validation and merge preview
    case EhsEnforcement.Enforcement.preview_offender_merge(master_id, duplicate_ids) do
      {:ok, preview} ->
        {:noreply,
         socket
         |> assign(:merge_preview, Map.put(preview, :master_id, master_id))
         |> assign(
           :merge_preview,
           Map.put(socket.assigns.merge_preview, :duplicate_ids, duplicate_ids)
         )}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Preview failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("execute_merge", _params, socket) do
    case socket.assigns.merge_preview do
      %{master_id: master_id, duplicate_ids: duplicate_ids} ->
        case EhsEnforcement.Enforcement.sync_and_merge_offenders(master_id, duplicate_ids) do
          {:ok, _merged} ->
            # Reload duplicates asynchronously after merge
            task =
              Task.async(fn ->
                load_duplicates_for_tab(socket.assigns.active_tab, socket.assigns.current_user)
              end)

            {:noreply,
             socket
             |> assign(:merge_preview, nil)
             |> assign(:selected_master_id, nil)
             |> put_flash(:info, "Successfully merged offenders!")
             |> assign(:loading, true)
             |> assign(:detection_task, task)}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Merge failed: #{inspect(reason)}")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "No merge preview available")}
    end
  end

  @impl true
  def handle_event("cancel_merge", _params, socket) do
    {:noreply, assign(socket, :merge_preview, nil)}
  end

  # Handle async task completion
  @impl true
  def handle_info({ref, result}, socket) do
    require Logger
    # Task completed successfully
    Process.demonitor(ref, [:flush])

    socket =
      case result do
        {:ok, duplicates, tab} ->
          Logger.info(
            "Duplicate detection: Completed for #{tab} - found #{length(duplicates)} groups"
          )

          case tab do
            :cases ->
              assign(socket, :case_duplicates, duplicates)

            :notices ->
              assign(socket, :notice_duplicates, duplicates)

            :offenders ->
              socket
              |> assign(:company_number_duplicates, duplicates)
              |> assign(:offender_duplicates, [])
          end
          |> assign(:loading, false)
          |> assign(:detection_task, nil)

        {:error, reason, tab} ->
          Logger.error("Duplicate detection: Failed for #{tab} - #{inspect(reason)}")

          socket
          |> assign(:loading, false)
          |> assign(:detection_task, nil)
          |> put_flash(:error, "Failed to load duplicates: #{inspect(reason)}")
      end

    {:noreply, socket}
  end

  # Handle task DOWN message (task crashed)
  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, socket) do
    require Logger
    Logger.error("Duplicate detection: Task crashed - #{inspect(reason)}")

    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:detection_task, nil)
     |> put_flash(:error, "Duplicate detection failed unexpectedly")}
  end

  # Template helper functions

  defp get_validation_display(similarity) do
    cond do
      similarity >= 0.9 ->
        {
          "bg-green-50",
          "border-green-200",
          "text-green-800",
          "hero-check-circle",
          "Excellent Match!",
          "Everything looks perfect. The company name matches Companies House records with high confidence."
        }

      similarity >= 0.7 ->
        {
          "bg-yellow-50",
          "border-yellow-200",
          "text-yellow-800",
          "hero-exclamation-triangle",
          "Warning: Possible Name Change",
          "The company name similarity is lower than ideal. This could indicate a company rename or name variation. Please verify the Companies House details before proceeding."
        }

      true ->
        {
          "bg-red-50",
          "border-red-200",
          "text-red-800",
          "hero-x-circle",
          "Danger: Low Match Confidence",
          "The validation confidence is very low. Please carefully verify this is the correct company before merging."
        }
    end
  end

  defp get_current_duplicates(assigns) do
    case assigns.active_tab do
      :cases -> assigns.case_duplicates
      :notices -> assigns.notice_duplicates
      :offenders -> assigns.offender_duplicates
    end
  end

  defp get_duplicates_for_tab(assigns, tab) do
    case tab do
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

  # Run duplicate detection in background task (does not block LiveView)
  defp load_duplicates_for_tab(tab, current_user) do
    try do
      case tab do
        :cases ->
          case EhsEnforcement.Enforcement.DuplicateDetector.find_duplicate_cases(current_user) do
            {:ok, duplicates} ->
              {:ok, duplicates, :cases}

            {:error, reason} ->
              {:error, reason, :cases}
          end

        :notices ->
          case EhsEnforcement.Enforcement.DuplicateDetector.find_duplicate_notices(current_user) do
            {:ok, duplicates} ->
              {:ok, duplicates, :notices}

            {:error, reason} ->
              {:error, reason, :notices}
          end

        :offenders ->
          case EhsEnforcement.Enforcement.find_duplicate_offenders_by_company_number() do
            {:ok, company_duplicates} ->
              {:ok, company_duplicates, :offenders}

            {:error, reason} ->
              {:error, reason, :offenders}
          end
      end
    catch
      :exit, {:timeout, _} ->
        {:error, :timeout, tab}
    end
  end

  defp execute_delete_action(socket, record_ids) do
    require Logger
    current_user = socket.assigns.current_user
    resource = get_resource_for_tab(socket.assigns.active_tab)
    resource_name = resource |> Module.split() |> List.last()

    Logger.info(
      "Duplicate deletion: Attempting to delete #{length(record_ids)} #{resource_name} records for user #{current_user.email}"
    )

    results =
      Enum.map(record_ids, fn record_id ->
        case Ash.get(resource, record_id, actor: current_user) do
          {:ok, record} ->
            case Ash.destroy(record, actor: current_user) do
              :ok ->
                Logger.info(
                  "Duplicate deletion: Successfully deleted #{resource_name} #{record_id}"
                )

                {:ok, record_id}

              {:error, error} ->
                Logger.error(
                  "Duplicate deletion: Failed to delete #{resource_name} #{record_id}: #{inspect(error)}"
                )

                {:error, {record_id, error}}
            end

          {:error, error} ->
            Logger.error(
              "Duplicate deletion: Failed to fetch #{resource_name} #{record_id}: #{inspect(error)}"
            )

            {:error, {record_id, error}}
        end
      end)

    successes = Enum.count(results, fn result -> match?({:ok, _}, result) end)
    failures = Enum.count(results, fn result -> match?({:error, _}, result) end)

    Logger.info(
      "Duplicate deletion: Completed - #{successes} succeeded, #{failures} failed (#{resource_name})"
    )

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

    # Reload duplicates asynchronously after deletion
    task =
      Task.async(fn ->
        load_duplicates_for_tab(socket.assigns.active_tab, socket.assigns.current_user)
      end)

    {:noreply,
     socket
     |> assign(:action_confirmation, nil)
     |> assign(:selected_records, MapSet.new())
     |> assign(:current_group_index, 0)
     |> assign(:loading, true)
     |> assign(:detection_task, task)}
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
