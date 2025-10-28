defmodule EhsEnforcementWeb.TestLiveSession do
  @moduledoc """
  Test-specific LiveSession module that allows setting current_user from connection assigns.

  This is used in tests to bypass the complex AshAuthentication session handling
  and simply use users assigned to the connection.
  """

  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    # In tests, pick up current_user from the connection if available
    current_user =
      Phoenix.LiveView.get_connect_info(socket, :user) ||
        Phoenix.LiveView.get_connect_params(socket)["current_user"]

    socket =
      if current_user do
        assign(socket, :current_user, current_user)
      else
        assign(socket, :current_user, nil)
      end

    {:cont, socket}
  end
end
