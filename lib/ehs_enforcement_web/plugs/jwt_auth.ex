defmodule EhsEnforcementWeb.Plugs.JwtAuth do
  @moduledoc """
  Plug to verify EdDSA JWT tokens from sertantai-auth and set up request context.

  Uses JOSE to verify EdDSA (Ed25519) JWT signature against the public key
  fetched from sertantai-auth's JWKS endpoint via `EhsEnforcement.Auth.JwksClient`.

  Extracts user_id from 'sub' claim, org_id and role from custom claims.
  Sets up tenant context for Row-Level Security (RLS).

  ## Usage

  Add to pipeline in router:
  ```elixir
  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug EhsEnforcementWeb.LoadFromCookie
    plug EhsEnforcementWeb.Plugs.JwtAuth
  end
  ```

  ## Assigns

  On successful verification, assigns the following to conn:
  - `:current_jwt_user_id` - The user's UUID from JWT
  - `:current_org_id` - The user's organization UUID
  - `:current_role` - The user's role atom (:owner, :admin, :member, :viewer)

  ## Token Format

  Expected JWT claims:
  - `sub`: "user?id=<uuid>" (AshAuthentication format) or bare UUID
  - `org_id`: "<uuid>" (organization identifier)
  - `role`: "owner" | "admin" | "member" | "viewer"
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        verify_token_and_set_context(conn, token)

      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Missing or invalid authorization header"})
        |> halt()
    end
  end

  defp verify_token_and_set_context(conn, token) do
    case verify_token(token) do
      {:ok, claims} ->
        set_context(conn, claims)

      {:error, reason} ->
        Logger.warning("JWT verification failed: #{reason}")

        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: reason})
        |> halt()
    end
  end

  defp verify_token(token) do
    with {:ok, jwk} <- EhsEnforcement.Auth.JwksClient.public_key() do
      case JOSE.JWT.verify_strict(jwk, ["EdDSA"], token) do
        {true, %JOSE.JWT{fields: claims}, _jws} ->
          validate_claims(claims)

        {false, _, _} ->
          {:error, "Invalid token signature"}
      end
    else
      {:error, :no_key} ->
        {:error, "Auth service unavailable (no signing key)"}
    end
  rescue
    _ -> {:error, "Malformed token"}
  end

  defp validate_claims(claims) do
    now = System.system_time(:second)

    cond do
      not is_integer(claims["exp"]) -> {:error, "Token missing expiry"}
      claims["exp"] < now -> {:error, "Token expired"}
      true -> {:ok, claims}
    end
  end

  defp set_context(conn, claims) do
    with {:ok, user_id} <- extract_user_id(claims),
         {:ok, org_id} <- extract_org_id(claims["org_id"]),
         {:ok, role} <- extract_role(claims["role"]),
         :ok <- set_tenant_context(org_id) do
      Logger.debug("JWT verified - User: #{user_id}, Org: #{org_id}, Role: #{inspect(role)}")

      conn
      |> assign(:current_jwt_user_id, user_id)
      |> assign(:current_org_id, org_id)
      |> assign(:current_role, role)
    else
      {:error, reason} ->
        Logger.warning("Token claims invalid: #{inspect(reason)}")

        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Invalid token: #{reason}"})
        |> halt()
    end
  end

  # Parse AshAuthentication's "user?id=<uuid>" format or bare UUID
  defp extract_user_id(%{"sub" => "user?id=" <> user_id}), do: {:ok, user_id}
  defp extract_user_id(%{"sub" => sub}) when is_binary(sub), do: {:ok, sub}

  defp extract_user_id(_claims) do
    Logger.warning("Missing or invalid sub claim")
    {:error, "invalid_user_id"}
  end

  defp extract_org_id(org_id) when is_binary(org_id), do: {:ok, org_id}
  defp extract_org_id(nil), do: {:error, "missing_org_id"}
  defp extract_org_id(_), do: {:error, "invalid_org_id"}

  # Ensure role atoms exist at compile time for String.to_existing_atom/1
  @valid_roles %{
    "owner" => :owner,
    "admin" => :admin,
    "member" => :member,
    "viewer" => :viewer
  }

  defp extract_role(role) when is_map_key(@valid_roles, role),
    do: {:ok, @valid_roles[role]}

  defp extract_role(nil), do: {:error, "missing_role"}
  defp extract_role(_), do: {:error, "invalid_role"}

  # Set tenant context in database session for RLS policies
  defp set_tenant_context(org_id) when is_binary(org_id) do
    with {:ok, uuid_binary} <- Ecto.UUID.dump(org_id),
         query = "SELECT set_current_org_id($1::uuid)",
         {:ok, _result} <- Ecto.Adapters.SQL.query(EhsEnforcement.Repo, query, [uuid_binary]) do
      :ok
    else
      :error ->
        Logger.error("Invalid UUID format: #{org_id}")
        {:error, "invalid_uuid_format"}

      {:error, error} ->
        Logger.error("Failed to set tenant context: #{inspect(error)}")
        {:error, "failed_to_set_tenant_context"}
    end
  end
end
