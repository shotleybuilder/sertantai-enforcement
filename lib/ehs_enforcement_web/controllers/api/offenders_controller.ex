defmodule EhsEnforcementWeb.Api.OffendersController do
  use EhsEnforcementWeb, :controller

  alias EhsEnforcement.Enforcement.Offender

  @doc """
  Get a single offender by ID for editing.

  GET /api/offenders/:id
  """
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    case Ash.get(Offender, id, actor: current_user) do
      {:ok, offender_record} ->
        conn
        |> json(%{
          success: true,
          data: serialize_offender(offender_record)
        })

      {:error, %Ash.Error.Query.NotFound{}} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Offender not found"
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to load offender",
          details: inspect(reason)
        })
    end
  end

  @doc """
  Update an offender.

  PATCH /api/offenders/:id
  Body: %{...update fields...}
  """
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with {:ok, offender_record} <- Ash.get(Offender, id, actor: current_user),
         {:ok, updated_offender} <-
           Ash.update(offender_record, Map.drop(params, ["id"]), actor: current_user) do
      conn
      |> json(%{
        success: true,
        message: "Offender updated successfully",
        data: serialize_offender(updated_offender)
      })
    else
      {:error, %Ash.Error.Query.NotFound{}} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Offender not found"
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Failed to update offender",
          details: inspect(reason)
        })
    end
  end

  # Private serialization function

  defp serialize_offender(offender_record) do
    %{
      id: offender_record.id,
      name: offender_record.name,
      address: offender_record.address,
      local_authority: offender_record.local_authority,
      country: offender_record.country,
      postcode: offender_record.postcode,
      town: offender_record.town,
      county: offender_record.county,
      main_activity: offender_record.main_activity,
      sic_code: offender_record.sic_code,
      business_type: offender_record.business_type,
      industry: offender_record.industry,
      agencies: offender_record.agencies,
      industry_sectors: offender_record.industry_sectors,
      company_registration_number: offender_record.company_registration_number,
      total_cases: offender_record.total_cases,
      total_notices: offender_record.total_notices,
      total_fines: offender_record.total_fines,
      first_seen_date: offender_record.first_seen_date,
      last_seen_date: offender_record.last_seen_date,
      inserted_at: offender_record.inserted_at,
      updated_at: offender_record.updated_at
    }
  end
end
