defmodule EhsEnforcement.Enforcement.UnifiedCaseProcessor do
  @moduledoc """
  Unified case processor that handles case creation/updates for all agencies.

  This module provides the common logic for:
  1. Creating new cases
  2. Updating existing cases when data changes
  3. Returning existing cases when data is identical (no timestamp update)
  4. Proper status reporting for consistent UI display
  """

  require Logger
  require Ash.Query
  alias EhsEnforcement.Enforcement

  @doc """
  Process a case with unified status logic for consistent UI display.

  This function ensures that:
  - New cases get :created status (inserted_at = today)
  - Changed existing cases get :updated status (updated_at = today)
  - Identical existing cases get :existing status (no timestamp change)
  """
  def process_and_create_case_with_status(case_attrs, actor \\ nil) do
    create_opts = if actor, do: [actor: actor], else: []

    case Enforcement.create_case(case_attrs, create_opts) do
      {:ok, case_record} ->
        Logger.info("Successfully created case: #{case_record.regulator_id}")
        {:ok, case_record, :created}

      {:error, ash_error} ->
        # Handle duplicate by checking if update is needed
        if is_duplicate_error?(ash_error) do
          handle_duplicate_case(case_attrs, ash_error, actor)
        else
          Logger.error("Failed to create case #{case_attrs.regulator_id}: #{inspect(ash_error)}")
          {:error, ash_error}
        end
    end
  end

  defp handle_duplicate_case(case_attrs, original_error, actor) do
    Logger.debug("Case already exists, checking if update needed: #{case_attrs.regulator_id}")

    # Find the existing case
    query_opts = if actor, do: [actor: actor], else: []

    case Enforcement.Case
         |> Ash.Query.filter(regulator_id == ^case_attrs.regulator_id)
         |> Ash.read_one(query_opts) do
      {:ok, existing_case} when not is_nil(existing_case) ->
        # Check if any fields actually need updating
        update_attrs = build_update_attrs(case_attrs)

        if needs_update?(existing_case, update_attrs) do
          # Actually update the case with changed data
          update_opts = if actor, do: [actor: actor], else: []

          case Enforcement.update_case_from_scraping(existing_case, update_attrs, update_opts) do
            {:ok, updated_case} ->
              Logger.info("Successfully updated existing case: #{updated_case.regulator_id}")
              {:ok, updated_case, :updated}

            {:error, update_error} ->
              Logger.error(
                "Failed to update existing case #{case_attrs.regulator_id}: #{inspect(update_error)}"
              )

              {:error, original_error}
          end
        else
          # For cases with identical data, manually trigger PubSub event without updating record
          Logger.debug(
            "Case already exists with identical data, manually triggering PubSub for UI: #{existing_case.regulator_id}"
          )

          # Manually broadcast PubSub with actual processing status
          notification = %Ash.Notifier.Notification{
            resource: EhsEnforcement.Enforcement.Case,
            action: %{name: :update_from_scraping, type: :update},
            actor: actor,
            data: existing_case,
            changeset: nil,
            # ← Pass the real DB result
            metadata: %{processing_status: :existing}
          }

          _ =
            Phoenix.PubSub.broadcast(
              EhsEnforcement.PubSub,
              "case:scraped:updated",
              %Phoenix.Socket.Broadcast{
                topic: "case:scraped:updated",
                event: "scraped:updated",
                payload: notification
              }
          )

          Logger.info(
            "Successfully triggered PubSub for existing case (UI): #{existing_case.regulator_id}"
          )

          {:ok, existing_case, :existing}
        end

      {:ok, nil} ->
        Logger.warning("Case marked as duplicate but not found: #{case_attrs.regulator_id}")
        {:error, original_error}

      {:error, query_error} ->
        Logger.error(
          "Failed to query existing case #{case_attrs.regulator_id}: #{inspect(query_error)}"
        )

        {:error, original_error}
    end
  end

  defp build_update_attrs(case_attrs) do
    %{
      offence_result: case_attrs.offence_result,
      offence_fine: case_attrs.offence_fine,
      offence_costs: case_attrs.offence_costs,
      offence_hearing_date: case_attrs.offence_hearing_date,
      url: Map.get(case_attrs, :regulator_url) || Map.get(case_attrs, :url),
      related_cases: case_attrs.related_cases
    }
  end

  defp needs_update?(existing_case, update_attrs) do
    Enum.any?(update_attrs, fn {field, new_value} ->
      existing_value =
        case field do
          # Handle field name mapping
          :url -> existing_case.regulator_url
          _ -> Map.get(existing_case, field)
        end

      # Compare values, handling nil cases
      normalize_value(existing_value) != normalize_value(new_value)
    end)
  end

  defp normalize_value(nil), do: nil
  defp normalize_value(value) when is_binary(value), do: String.trim(value)
  defp normalize_value(value), do: value

  defp is_duplicate_error?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %{field: :regulator_id, message: message} ->
        String.contains?(message, "already been taken") or
          String.contains?(message, "already exists")

      _ ->
        false
    end)
  end

  defp is_duplicate_error?(_), do: false
end
