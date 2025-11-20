defmodule EhsEnforcementWeb.GatekeeperController do
  @moduledoc """
  Electric SQL Gatekeeper endpoint for shape authorization.

  This controller implements Electric's Gatekeeper pattern:
  1. Electric calls this endpoint to authorize shape requests
  2. We verify the JWT and check permissions
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
  - Authorization header with JWT
  - Request body with table and shape parameters

  ## Request Body
  ```json
  {
    "table": "cases",
    "where": "offence_action_date > '2024-01-01'"
  }
  ```

  ## Response (Success)
  ```json
  {
    "token": "eyJhbGc..."
  }
  ```

  ## Response (Error)
  ```json
  {
    "error": "Unauthorized",
    "message": "Insufficient permissions"
  }
  ```
  """
  def authorize_shape(conn, params) do
    # Extract context from JWT (set by JwtAuth plug)
    org_id = conn.assigns[:current_org_id]
    user_id = conn.assigns[:current_jwt_user_id]
    role = conn.assigns[:current_role]

    table = params["table"]
    where = params["where"]

    Logger.info("Gatekeeper request - User: #{user_id}, Org: #{org_id}, Table: #{table}")

    with :ok <- validate_table(table),
         :ok <- authorize_table_access(table, role),
         {:ok, shape_token} <- generate_shape_token(table, org_id, where) do
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

  # Validate that table parameter is present
  defp validate_table(nil), do: {:error, :missing_table}
  defp validate_table(""), do: {:error, :missing_table}
  defp validate_table(table) when is_binary(table), do: :ok

  # Authorize access to the requested table based on user role
  # For EHS Enforcement, all public tables are accessible to all authenticated users
  defp authorize_table_access(table, _role) do
    # Define which tables are public (accessible to all authenticated users)
    public_tables = [
      :cases,
      :notices,
      :offenders,
      :legislation,
      :agencies
    ]

    # Define which tables require specific roles (future: user-specific features)
    # restricted_tables = [
    #   :user_bookmarks,    # User's bookmarks
    #   :user_annotations,  # User's notes
    #   :user_alerts,       # User's alerts
    #   :user_reports       # User's custom reports
    # ]

    table_atom = String.to_existing_atom(table)

    if table_atom in public_tables do
      Logger.debug("Public table access granted: #{table}")
      :ok
    else
      Logger.warning("Access denied to table: #{table}")
      {:error, :unauthorized_table}
    end
  rescue
    ArgumentError ->
      # Table name is not a known atom
      Logger.warning("Unknown table requested: #{table}")
      {:error, :unauthorized_table}
  end

  # Generate a short-lived shape token for Electric
  defp generate_shape_token(table, org_id, where) do
    # Get shape token TTL from config (default 60 seconds)
    ttl = Application.get_env(:ehs_enforcement, :shape_token_ttl, 60)

    # Get signing secret
    secret = System.get_env("SERTANTAI_SHARED_TOKEN_SECRET")

    if is_nil(secret) do
      Logger.error("SERTANTAI_SHARED_TOKEN_SECRET not configured")
      {:error, :missing_secret}
    else
      # Build token payload
      now = System.system_time(:second)

      claims = %{
        "table" => table,
        "org_id" => org_id,
        "where" => where,
        "iat" => now,
        "exp" => now + ttl,
        "type" => "shape_token"
      }

      # Sign the token
      signer = Joken.Signer.create("HS256", secret)

      case Joken.generate_and_sign(%{}, claims, signer) do
        {:ok, token, _claims} ->
          {:ok, token}

        {:error, reason} ->
          Logger.error("Failed to generate shape token: #{inspect(reason)}")
          {:error, :token_generation_failed}
      end
    end
  end
end
