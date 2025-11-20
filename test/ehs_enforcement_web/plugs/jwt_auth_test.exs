defmodule EhsEnforcementWeb.Plugs.JwtAuthTest do
  use EhsEnforcementWeb.ConnCase, async: true
  import Ash.Expr

  alias EhsEnforcementWeb.Plugs.JwtAuth

  describe "JWT authentication" do
    setup do
      # Generate a valid JWT for testing
      secret = System.get_env("SERTANTAI_SHARED_TOKEN_SECRET") || "test_secret_key"
      user_id = Ash.UUID.generate()
      org_id = Ash.UUID.generate()

      claims = %{
        "sub" => "user?id=#{user_id}",
        "org_id" => org_id,
        "role" => "admin",
        "exp" => System.system_time(:second) + 3600,
        "iat" => System.system_time(:second)
      }

      signer = Joken.Signer.create("HS256", secret)
      {:ok, token, _claims} = Joken.generate_and_sign(%{}, claims, signer)

      %{token: token, user_id: user_id, org_id: org_id, secret: secret}
    end

    test "accepts valid JWT and sets assigns", %{
      conn: conn,
      token: token,
      user_id: user_id,
      org_id: org_id
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> JwtAuth.call([])

      assert conn.assigns.current_jwt_user_id == user_id
      assert conn.assigns.current_org_id == org_id
      assert conn.assigns.current_role == :admin
      refute conn.halted
    end

    test "rejects request without authorization header", %{conn: conn} do
      conn = JwtAuth.call(conn, [])

      assert conn.halted
      assert conn.status == 401
      assert json_response(conn, 401)["error"] == "Missing or invalid authorization header"
    end

    test "rejects invalid JWT token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid_token")
        |> JwtAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert json_response(conn, 401)["error"] == "Invalid or expired token"
    end

    test "rejects JWT with wrong signature", %{conn: conn, user_id: user_id, org_id: org_id} do
      # Generate token with different secret
      wrong_secret = "wrong_secret_key"

      claims = %{
        "sub" => "user?id=#{user_id}",
        "org_id" => org_id,
        "role" => "admin",
        "exp" => System.system_time(:second) + 3600,
        "iat" => System.system_time(:second)
      }

      signer = Joken.Signer.create("HS256", wrong_secret)
      {:ok, token, _claims} = Joken.generate_and_sign(%{}, claims, signer)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> JwtAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects expired JWT", %{conn: conn, user_id: user_id, org_id: org_id, secret: secret} do
      # Generate expired token
      claims = %{
        "sub" => "user?id=#{user_id}",
        "org_id" => org_id,
        "role" => "admin",
        # Expired 1 hour ago
        "exp" => System.system_time(:second) - 3600,
        "iat" => System.system_time(:second) - 7200
      }

      signer = Joken.Signer.create("HS256", secret)
      {:ok, token, _claims} = Joken.generate_and_sign(%{}, claims, signer)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> JwtAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects JWT with missing org_id claim", %{conn: conn, user_id: user_id, secret: secret} do
      claims = %{
        "sub" => "user?id=#{user_id}",
        # Missing org_id
        "role" => "admin",
        "exp" => System.system_time(:second) + 3600,
        "iat" => System.system_time(:second)
      }

      signer = Joken.Signer.create("HS256", secret)
      {:ok, token, _claims} = Joken.generate_and_sign(%{}, claims, signer)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> JwtAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert json_response(conn, 401)["error"] == "Invalid token: missing_org_id"
    end

    test "rejects JWT with invalid sub format", %{conn: conn, org_id: org_id, secret: secret} do
      claims = %{
        # Wrong format
        "sub" => "invalid_format",
        "org_id" => org_id,
        "role" => "admin",
        "exp" => System.system_time(:second) + 3600,
        "iat" => System.system_time(:second)
      }

      signer = Joken.Signer.create("HS256", secret)
      {:ok, token, _claims} = Joken.generate_and_sign(%{}, claims, signer)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> JwtAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert json_response(conn, 401)["error"] == "Invalid token: invalid_user_id"
    end

    test "handles different role values", %{
      conn: conn,
      user_id: user_id,
      org_id: org_id,
      secret: secret
    } do
      roles = ["owner", "admin", "member", "viewer"]

      Enum.each(roles, fn role ->
        claims = %{
          "sub" => "user?id=#{user_id}",
          "org_id" => org_id,
          "role" => role,
          "exp" => System.system_time(:second) + 3600,
          "iat" => System.system_time(:second)
        }

        signer = Joken.Signer.create("HS256", secret)
        {:ok, token, _claims} = Joken.generate_and_sign(%{}, claims, signer)

        conn =
          build_conn()
          |> put_req_header("authorization", "Bearer #{token}")
          |> JwtAuth.call([])

        refute conn.halted
        assert conn.assigns.current_role == String.to_existing_atom(role)
      end)
    end

    test "sets RLS tenant context in database", %{conn: conn, token: token, org_id: org_id} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> JwtAuth.call([])

      refute conn.halted

      # Verify RLS context was set by querying the database function
      query = "SELECT get_current_org_id()"
      {:ok, result} = Ecto.Adapters.SQL.query(EhsEnforcement.Repo, query, [])

      # Result format: %Postgrex.Result{rows: [[uuid_value]]}
      # Convert binary UUID back to string for comparison
      [[db_org_id_binary]] = result.rows
      {:ok, db_org_id} = Ecto.UUID.load(db_org_id_binary)
      assert db_org_id == org_id
    end
  end
end
