defmodule EhsEnforcementWeb.Plugs.AuthHelpers do
  @moduledoc """
  Authentication helper plugs for Ash Authentication integration.
  """
  
  import Plug.Conn
  import Phoenix.Controller
  
  def init(opts), do: opts
  
  def call(conn, :load_current_user), do: load_current_user(conn, [])
  def call(conn, :require_authenticated_user), do: require_authenticated_user(conn, [])  
  def call(conn, :require_admin_user), do: require_admin_user(conn, [])
  def call(conn, opts), do: load_current_user(conn, opts)
  
  def load_current_user(conn, _opts) do
    # retrieve_from_session loads users and stores them in assigns with current_ prefix
    conn = AshAuthentication.Plug.Helpers.retrieve_from_session(conn, :ehs_enforcement)
    
    # The user should now be in conn.assigns.current_user
    case conn.assigns[:current_user] do
      nil ->
        conn
      user ->
        conn
        |> maybe_refresh_admin_status(user)
        |> AshAuthentication.Plug.Helpers.set_actor(:user)
    end
  end
  
  def require_authenticated_user(conn, _opts) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_flash(:info, "Please sign in to continue")
        |> redirect(to: "/sign-in")
        |> halt()
      _user ->
        conn
    end
  end
  
  def require_admin_user(conn, _opts) do
    user = conn.assigns[:current_user]
    
    case user do
      %{is_admin: true} ->
        conn
      _ ->
        conn
        |> put_status(:forbidden)
        |> put_flash(:error, "Admin privileges required")
        |> redirect(to: "/")
        |> halt()
    end
  end
  
  # Private helper functions
  
  defp maybe_refresh_admin_status(conn, user) do
    # Check if admin status needs refresh (older than 1 hour)
    needs_refresh = is_nil(user.admin_checked_at) or 
                   DateTime.diff(DateTime.utc_now(), user.admin_checked_at, :second) > 3600
    
    if needs_refresh do
      # Refresh admin status in the background
      Task.start(fn -> refresh_user_admin_status(user) end)
    end
    
    conn
  end
  
  defp refresh_user_admin_status(user) do
    is_admin = check_github_repository_permissions(user)
    
    case Ash.update(user, %{is_admin: is_admin}, action: :update_admin_status, actor: user) do
      {:ok, _updated_user} ->
        :ok
      {:error, error} ->
        require Logger
        Logger.error("Failed to update admin status for user #{user.id}: #{inspect(error)}")
    end
  end
  
  defp check_github_repository_permissions(user) do
    config = Application.get_env(:ehs_enforcement, :github_admin, %{})

    case config do
      config when is_list(config) ->
        owner = Keyword.get(config, :owner)
        repo = Keyword.get(config, :repo)
        access_token = Keyword.get(config, :access_token)
        allowed_users = Keyword.get(config, :allowed_users, [])

        cond do
          # Repository-based: all three must be present AND non-empty
          is_binary(access_token) and access_token != "" and
          is_binary(owner) and owner != "" and
          is_binary(repo) and repo != "" ->
            check_user_repository_access(user.github_login, owner, repo, access_token)

          # Allow list: must have at least one user
          is_list(allowed_users) and length(allowed_users) > 0 ->
            user.github_login in allowed_users

          true ->
            false
        end
      _ ->
        false
    end
  end
  
  defp check_user_repository_access(username, owner, repo, access_token) do
    url = "https://api.github.com/repos/#{owner}/#{repo}/collaborators/#{username}"
    
    headers = [
      {"Authorization", "token #{access_token}"},
      {"Accept", "application/vnd.github.v3+json"},
      {"User-Agent", "EHS-Enforcement-App"}
    ]
    
    case Req.get(url, headers: headers) do
      {:ok, %{status: 204}} -> true
      {:ok, %{status: 404}} -> false
      {:error, _reason} -> false
    end
  rescue
    _error -> false
  end
end