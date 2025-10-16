defmodule EhsEnforcementWeb.AuthController do
  @moduledoc """
  Handles Ash Authentication callbacks and user session management.
  """
  
  use EhsEnforcementWeb, :controller
  use AshAuthentication.Phoenix.Controller
  
  def success(conn, _activity, user, _token) do
    # Load the display_name calculation safely
    user_with_display_name = Ash.load!(user, [:display_name])
    display_name = Map.get(user_with_display_name, :display_name) || user.name || user.github_login || user.email
    
    conn
    |> store_in_session(user)
    |> assign(:current_user, user) 
    |> put_flash(:info, "Welcome #{display_name}!")
    |> redirect(to: "/")
  end

  def failure(conn, _activity, reason) do
    # Safely convert error to string
    error_message = case reason do
      %{message: msg} when is_binary(msg) -> msg
      error when is_binary(error) -> error
      error -> inspect(error)
    end
    
    conn
    |> put_flash(:error, "Authentication failed: #{error_message}")
    |> redirect(to: "/")
  end

  def sign_out(conn, _params) do
    # Clear session with error handling for token revocation failures
    conn =
      try do
        clear_session(conn, :ehs_enforcement)
      rescue
        error ->
          # Log the error but still allow logout to succeed
          require Logger
          Logger.error("Error during token revocation on logout: #{inspect(error)}")

          # Fallback to basic session clearing
          Plug.Conn.clear_session(conn)
      end

    conn
    |> put_flash(:info, "Successfully signed out")
    |> redirect(to: "/")
  end
end