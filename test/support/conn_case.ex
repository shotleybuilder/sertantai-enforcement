defmodule EhsEnforcementWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use EhsEnforcementWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint EhsEnforcementWeb.Endpoint

      use EhsEnforcementWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import EhsEnforcementWeb.ConnCase

      # Helper to call live/3 with on_error: :warn to suppress duplicate ID warnings
      # from Phoenix's flash components in the root layout
      defp live_no_warn(conn, path), do: Phoenix.LiveViewTest.live(conn, path, on_error: :warn)
    end
  end

  setup tags do
    EhsEnforcement.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Helper for testing authenticated LiveViews following AshAuthentication best practices.
  
  This creates a user and logs them in properly for LiveView tests.
  Based on official AshAuthentication documentation.
  """
  def register_and_log_in_user(%{conn: conn} = context) do
    email = "user@example.com"
    name = "Test User"
    github_login = "testuser"

    # Create user using Ash.Seed for testing
    user = Ash.Seed.seed!(EhsEnforcement.Accounts.User, %{
      email: email,
      name: name,
      github_login: github_login,
      is_admin: false,
      admin_checked_at: DateTime.utc_now()
    })

    # For OAuth2 strategies, we don't use password authentication
    # Instead, we directly store the user in the session
    new_conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> AshAuthentication.Plug.Helpers.store_in_session(user)

    %{context | conn: new_conn, user: user}
  end

  @doc """
  Helper for testing admin LiveViews.
  """
  def register_and_log_in_admin(%{conn: conn} = context) do
    email = "admin@example.com"
    name = "Admin User"
    github_login = "adminuser"

    # Create admin user using the proper OAuth2 registration action that generates tokens
    user_info = %{
      "email" => email,
      "name" => name,
      "login" => github_login,
      "id" => 12345,
      "avatar_url" => "https://github.com/images/avatars/#{github_login}",
      "html_url" => "https://github.com/#{github_login}"
    }
    
    oauth_tokens = %{
      "access_token" => "test_access_token",
      "token_type" => "Bearer"
    }

    {:ok, user} = Ash.create(EhsEnforcement.Accounts.User, %{
      user_info: user_info,
      oauth_tokens: oauth_tokens
    }, action: :register_with_github)
    
    # Update admin status after creation using the correct action
    {:ok, admin_user} = Ash.update(user, %{
      is_admin: true,
      admin_checked_at: DateTime.utc_now()
    }, action: :update_admin_status, actor: user)

    new_conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> AshAuthentication.Plug.Helpers.store_in_session(admin_user)

    %{context | conn: new_conn} |> Map.put(:user, admin_user)
  end

  @doc """
  Creates a test user with basic attributes (for direct use).
  """
  def create_test_user(attrs \\ %{}) do
    user_attrs = %{
      email: "test@example.com",
      name: "Test User",
      github_login: "testuser",
      is_admin: false,
      admin_checked_at: DateTime.utc_now()
    }
    |> Map.merge(attrs)

    {:ok, user} = Ash.create(EhsEnforcement.Accounts.User, user_attrs)
    Ash.load!(user, [:display_name])
  end

  @doc """
  Creates a test admin user (for direct use).
  """
  def create_test_admin(attrs \\ %{}) do
    admin_attrs = %{
      email: "admin@example.com",
      name: "Admin User",
      github_login: "adminuser",
      is_admin: true,
      admin_checked_at: DateTime.utc_now()
    }
    |> Map.merge(attrs)

    create_test_user(admin_attrs)
  end
end
