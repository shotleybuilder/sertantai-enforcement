defmodule EhsEnforcementWeb.Api.NoticesController do
  use EhsEnforcementWeb, :controller

  alias EhsEnforcement.Enforcement.Notice

  @doc """
  Get a single notice by ID for editing.

  GET /api/notices/:id
  """
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    case Ash.get(Notice, id, actor: current_user, load: [:agency, :offender]) do
      {:ok, notice_record} ->
        conn
        |> json(%{
          success: true,
          data: serialize_notice(notice_record)
        })

      {:error, %Ash.Error.Query.NotFound{}} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Notice not found"
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to load notice",
          details: inspect(reason)
        })
    end
  end

  @doc """
  Update a notice.

  PATCH /api/notices/:id
  Body: %{...update fields...}
  """
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with {:ok, notice_record} <- Ash.get(Notice, id, actor: current_user),
         {:ok, updated_notice} <-
           Ash.update(notice_record, Map.drop(params, ["id"]), actor: current_user) do
      conn
      |> json(%{
        success: true,
        message: "Notice updated successfully",
        data: serialize_notice(updated_notice)
      })
    else
      {:error, %Ash.Error.Query.NotFound{}} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Notice not found"
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Failed to update notice",
          details: inspect(reason)
        })
    end
  end

  # Private serialization function

  defp serialize_notice(notice_record) do
    %{
      id: notice_record.id,
      regulator_id: notice_record.regulator_id,
      regulator_ref_number: notice_record.regulator_ref_number,
      notice_date: notice_record.notice_date,
      operative_date: notice_record.operative_date,
      compliance_date: notice_record.compliance_date,
      notice_body: notice_record.notice_body,
      offence_action_type: notice_record.offence_action_type,
      offence_action_date: notice_record.offence_action_date,
      url: notice_record.url,
      offence_breaches: notice_record.offence_breaches,
      environmental_impact: notice_record.environmental_impact,
      environmental_receptor: notice_record.environmental_receptor,
      agency_id: notice_record.agency_id,
      offender_id: notice_record.offender_id,
      agency: serialize_agency(notice_record.agency),
      offender: serialize_offender(notice_record.offender),
      inserted_at: notice_record.inserted_at,
      updated_at: notice_record.updated_at
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
