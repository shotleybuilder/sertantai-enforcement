defmodule EhsEnforcementWeb.Api.CasesController do
  use EhsEnforcementWeb, :controller

  alias EhsEnforcement.Enforcement.Case

  @doc """
  Get a single case by ID for editing.

  GET /api/cases/:id
  """
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    case Ash.get(Case, id, actor: current_user, load: [:agency, :offender]) do
      {:ok, case_record} ->
        conn
        |> json(%{
          success: true,
          data: serialize_case(case_record)
        })

      {:error, %Ash.Error.Query.NotFound{}} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Case not found"
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to load case",
          details: inspect(reason)
        })
    end
  end

  @doc """
  Update a case.

  PATCH /api/cases/:id
  Body: %{...update fields...}
  """
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with {:ok, case_record} <- Ash.get(Case, id, actor: current_user),
         {:ok, updated_case} <-
           Ash.update(case_record, Map.drop(params, ["id"]), actor: current_user) do
      conn
      |> json(%{
        success: true,
        message: "Case updated successfully",
        data: serialize_case(updated_case)
      })
    else
      {:error, %Ash.Error.Query.NotFound{}} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Case not found"
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Failed to update case",
          details: inspect(reason)
        })
    end
  end

  # Private serialization function

  defp serialize_case(case_record) do
    %{
      id: case_record.id,
      regulator_id: case_record.regulator_id,
      offence_result: case_record.offence_result,
      offence_fine: case_record.offence_fine,
      offence_costs: case_record.offence_costs,
      offence_action_date: case_record.offence_action_date,
      offence_hearing_date: case_record.offence_hearing_date,
      offence_breaches: case_record.offence_breaches,
      offence_action_type: case_record.offence_action_type,
      regulator_function: case_record.regulator_function,
      url: case_record.url,
      related_cases: case_record.related_cases,
      agency_id: case_record.agency_id,
      offender_id: case_record.offender_id,
      agency: serialize_agency(case_record.agency),
      offender: serialize_offender(case_record.offender),
      inserted_at: case_record.inserted_at,
      updated_at: case_record.updated_at
    }
  end

  defp serialize_agency(nil), do: nil

  defp serialize_agency(agency) do
    %{
      id: agency.id,
      code: agency.code,
      name: agency.name
    }
  end

  defp serialize_offender(nil), do: nil

  defp serialize_offender(offender) do
    %{
      id: offender.id,
      name: offender.name
    }
  end
end
