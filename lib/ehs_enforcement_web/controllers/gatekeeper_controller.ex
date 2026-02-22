defmodule EhsEnforcementWeb.GatekeeperController do
  @moduledoc """
  Electric SQL Gatekeeper endpoint for shape authorization.

  This controller implements Electric's Gatekeeper pattern:
  1. Electric calls this endpoint to authorize shape requests
  2. We verify the JWT (via JwtAuth plug) and check permissions
  3. We generate a short-lived shape token (60s)
  4. Electric uses the shape token to access data
  5. RLS policies provide defense-in-depth at database level

  ## Public Data Tables

  EHS Enforcement data is PUBLIC (cases, notices, offenders, legislation, agencies).
  All users can read this data regardless of organization.

  Authentication is only required for:
  - Future features (bookmarks, annotations, alerts, reports)
  - Admin operations (data management)

  ## Authorization Strategy

  For now, all authenticated users can access all public tables.
  Future: Add RLS for user-specific features overlaying public data.

  See: https://electric-sql.com/docs/guides/auth
  """

  use EhsEnforcementWeb, :controller
  require Logger

  @doc """
  Authorizes Electric shape requests and returns short-lived shape tokens.

  Electric calls this endpoint with:
  - Authorization header with JWT (verified by JwtAuth plug)
  - Request body with table and shape parameters

  ## Request Body
  ```json
  {
    "table": "cases",
    "where": "offence_action_date > '2024-01-01'"
  }
  ```
  """
  def authorize_shape(conn, params) do
    org_id = conn.assigns[:current_org_id]
    user_id = conn.assigns[:current_jwt_user_id]
    role = conn.assigns[:current_role]

    table = params["table"]
    where = params["where"]

    Logger.info("Gatekeeper request - User: #{user_id}, Org: #{org_id}, Table: #{table}")

    with :ok <- validate_table(table),
         :ok <- authorize_table_access(table, role),
         {:ok, shape_token} <- generate_shape_token(conn, table, org_id, where) do
      Logger.debug("Shape token generated for table: #{table}, org: #{org_id}")
      json(conn, %{token: shape_token})
    else
      {:error, :missing_table} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Bad Request", message: "Missing 'table' parameter"})

      {:error, :unauthorized_table} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Forbidden", message: "Access to this table is not allowed"})

      {:error, reason} ->
        Logger.error("Gatekeeper authorization failed: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Internal Server Error", message: "Failed to generate shape token"})
    end
  end

  defp validate_table(nil), do: {:error, :missing_table}
  defp validate_table(""), do: {:error, :missing_table}
  defp validate_table(table) when is_binary(table), do: :ok

  # All authenticated users can access public tables
  defp authorize_table_access(table, _role) do
    public_tables = [:cases, :notices, :offenders, :legislation, :agencies]
    table_atom = String.to_existing_atom(table)

    if table_atom in public_tables do
      :ok
    else
      {:error, :unauthorized_table}
    end
  rescue
    ArgumentError -> {:error, :unauthorized_table}
  end

  # Generate a short-lived shape token using Phoenix.Token (signed with secret_key_base)
  defp generate_shape_token(conn, table, org_id, where) do
    ttl = Application.get_env(:ehs_enforcement, :shape_token_ttl, 60)

    data = %{
      "table" => table,
      "org_id" => org_id,
      "where" => where,
      "type" => "shape_token"
    }

    token = Phoenix.Token.sign(conn, "shape_token", data, max_age: ttl)
    {:ok, token}
  end
end
