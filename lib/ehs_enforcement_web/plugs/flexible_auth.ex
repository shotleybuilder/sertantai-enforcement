defmodule EhsEnforcementWeb.Plugs.FlexibleAuth do
  @moduledoc """
  Flexible authentication plug that supports multiple authentication methods.

  ## Authentication Methods (in order of precedence)

  1. **Tenant JWT Token** (Bearer Authorization header)
     - Used by tenant users from sertantai-auth
     - Verified with EdDSA (Ed25519) via JwksClient
     - Sets `:current_jwt_user_id`, `:current_org_id`, `:current_role`

  2. **Admin OAuth JWT Token** (Bearer Authorization header)
     - Used by admin users from GitHub OAuth
     - Verified with TOKEN_SIGNING_SECRET
     - Sets `:current_user` (full Ash user struct loaded from token)

  3. **Session Cookie** (Phoenix session)
     - Used by admin users via GitHub OAuth (fallback)
     - Sets `:current_user` (full Ash user struct)

  ## Usage

  Add to pipeline in router:
  ```elixir
  pipeline :api_flexible do
    plug :accepts, ["json"]
    plug EhsEnforcementWeb.LoadFromCookie
    plug EhsEnforcementWeb.Plugs.FlexibleAuth
  end
  ```

  ## Assigns

  After successful authentication, assigns ONE of:
  - `:current_user` - Full Ash user struct (OAuth JWT or session auth)
  - `:current_jwt_user_id`, `:current_org_id`, `:current_role` (tenant JWT auth)
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> _token] ->
        try_jwt_auth(conn)

      _ ->
        try_session_auth(conn)
    end
  end

  # Try JWT authentication - first tenant EdDSA JWT, then admin OAuth JWT
  defp try_jwt_auth(conn) do
    ["Bearer " <> token] = get_req_header(conn, "authorization")

    case verify_tenant_jwt(token) do
      {:ok, claims} ->
        set_tenant_context(conn, claims)

      {:error, _reason} ->
        Logger.debug("Tenant JWT verification failed, trying OAuth JWT")
        try_oauth_jwt_auth(conn)
    end
  end

  # Verify tenant JWT with EdDSA via JwksClient
  defp verify_tenant_jwt(token) do
    with {:ok, jwk} <- EhsEnforcement.Auth.JwksClient.public_key() do
      case JOSE.JWT.verify_strict(jwk, ["EdDSA"], token) do
        {true, %JOSE.JWT{fields: claims}, _jws} ->
          now = System.system_time(:second)

          cond do
            not is_integer(claims["exp"]) -> {:error, :missing_expiry}
            claims["exp"] < now -> {:error, :token_expired}
            true -> {:ok, claims}
          end

        {false, _, _} ->
          {:error, :invalid_signature}
      end
    end
  rescue
    _ -> {:error, :malformed_token}
  end

  # Set up tenant context from verified EdDSA JWT claims
  defp set_tenant_context(conn, claims) do
    with {:ok, user_id} <- extract_user_id(claims),
         {:ok, org_id} <- extract_org_id(claims["org_id"]),
         {:ok, role} <- extract_role(claims["role"]) do
      Logger.debug("Tenant EdDSA JWT auth succeeded for user: #{user_id}")

      conn
      |> assign(:current_jwt_user_id, user_id)
      |> assign(:current_org_id, org_id)
      |> assign(:current_role, role)
    else
      {:error, reason} ->
        Logger.warning("Tenant JWT claims invalid: #{inspect(reason)}, trying OAuth JWT")
        try_oauth_jwt_auth(conn)
    end
  end

  defp extract_user_id(%{"sub" => "user?id=" <> user_id}), do: {:ok, user_id}
  defp extract_user_id(%{"sub" => sub}) when is_binary(sub), do: {:ok, sub}
  defp extract_user_id(_), do: {:error, :invalid_user_id}

  defp extract_org_id(org_id) when is_binary(org_id), do: {:ok, org_id}
  defp extract_org_id(_), do: {:error, :missing_org_id}

  defp extract_role(role) when role in ["owner", "admin", "member", "viewer"],
    do: {:ok, String.to_existing_atom(role)}

  defp extract_role(_), do: {:error, :invalid_role}

  # Try admin OAuth JWT authentication (TOKEN_SIGNING_SECRET) — unchanged from HS256
  defp try_oauth_jwt_auth(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        verify_oauth_token(conn, token)

      _ ->
        try_session_auth(conn)
    end
  end

  # Verify OAuth token with TOKEN_SIGNING_SECRET and load user
  defp verify_oauth_token(conn, token) do
    secret = Application.get_env(:ehs_enforcement, :token_signing_secret)

    if is_nil(secret) do
      Logger.error("TOKEN_SIGNING_SECRET not configured")
      try_session_auth(conn)
    else
      signer = Joken.Signer.create("HS256", secret)

      case Joken.verify(token, signer) do
        {:ok, claims} ->
          now = System.system_time(:second)
          exp = claims["exp"]

          if exp && exp < now do
            Logger.warning("OAuth JWT token expired")
            try_session_auth(conn)
          else
            case Regex.run(~r/user\?id=([a-f0-9-]+)/, claims["sub"]) do
              [_, user_id] ->
                load_user_from_token(conn, user_id)

              _ ->
                Logger.warning("Invalid subject format in OAuth token: #{claims["sub"]}")
                try_session_auth(conn)
            end
          end

        {:error, reason} ->
          Logger.warning("OAuth JWT verification failed: #{inspect(reason)}")
          try_session_auth(conn)
      end
    end
  rescue
    e ->
      Logger.warning("OAuth JWT verification error: #{inspect(e)}")
      try_session_auth(conn)
  end

  # Load user from database using user ID from token
  defp load_user_from_token(conn, user_id) do
    case Ash.get(EhsEnforcement.Accounts.User, user_id) do
      {:ok, user} ->
        Logger.debug("Admin OAuth JWT auth succeeded for user: #{user.email}")
        assign(conn, :current_user, user)

      {:error, reason} ->
        Logger.warning("Failed to load user #{user_id}: #{inspect(reason)}")
        try_session_auth(conn)
    end
  rescue
    e ->
      Logger.warning("Error loading user: #{inspect(e)}")
      try_session_auth(conn)
  end

  # Try session-based authentication (GitHub OAuth)
  defp try_session_auth(conn) do
    conn = AshAuthentication.Plug.Helpers.retrieve_from_session(conn, :ehs_enforcement)

    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Not authenticated"})
        |> halt()

      user ->
        Logger.debug("Session auth succeeded for user: #{inspect(user.email)}")
        conn
    end
  end
end
