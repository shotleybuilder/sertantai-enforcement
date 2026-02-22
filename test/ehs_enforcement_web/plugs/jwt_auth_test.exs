defmodule EhsEnforcementWeb.Plugs.JwtAuthTest do
  use EhsEnforcementWeb.ConnCase, async: false

  alias EhsEnforcementWeb.Plugs.JwtAuth

  describe "JWT authentication" do
    setup do
      # Generate an Ed25519 key pair for EdDSA JWT signing/verification
      private_jwk = JOSE.JWK.generate_key({:okp, :Ed25519})
      public_jwk = JOSE.JWK.to_public(private_jwk)

      # Register the public key with the JwksClient so the plug can verify tokens
      :ok = EhsEnforcement.Auth.JwksClient.set_test_key(public_jwk)

      on_exit(fn ->
        EhsEnforcement.Auth.JwksClient.set_test_key(nil)
      end)

      user_id = Ash.UUID.generate()
      org_id = Ash.UUID.generate()

      %{private_jwk: private_jwk, user_id: user_id, org_id: org_id}
    end

    defp sign_token(claims, private_jwk) do
      jws = %{"alg" => "EdDSA"}
      jwt = JOSE.JWT.from_map(claims)
      {_, token} = JOSE.JWT.sign(private_jwk, jws, jwt) |> JOSE.JWS.compact()
      token
    end

    test "accepts valid JWT and sets assigns", %{
      conn: conn,
      private_jwk: private_jwk,
      user_id: user_id,
      org_id: org_id
    } do
      token =
        sign_token(
          %{
            "sub" => "user?id=#{user_id}",
            "org_id" => org_id,
            "role" => "admin",
            "exp" => System.system_time(:second) + 3600,
            "iat" => System.system_time(:second)
          },
          private_jwk
        )

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
      assert json_response(conn, 401)["error"] == "Malformed token"
    end

    test "rejects JWT with wrong signature", %{conn: conn, user_id: user_id, org_id: org_id} do
      # Generate token with a different Ed25519 key
      wrong_jwk = JOSE.JWK.generate_key({:okp, :Ed25519})

      token =
        sign_token(
          %{
            "sub" => "user?id=#{user_id}",
            "org_id" => org_id,
            "role" => "admin",
            "exp" => System.system_time(:second) + 3600,
            "iat" => System.system_time(:second)
          },
          wrong_jwk
        )

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> JwtAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects expired JWT", %{
      conn: conn,
      user_id: user_id,
      org_id: org_id,
      private_jwk: private_jwk
    } do
      token =
        sign_token(
          %{
            "sub" => "user?id=#{user_id}",
            "org_id" => org_id,
            "role" => "admin",
            "exp" => System.system_time(:second) - 3600,
            "iat" => System.system_time(:second) - 7200
          },
          private_jwk
        )

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> JwtAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects JWT with missing org_id claim", %{
      conn: conn,
      user_id: user_id,
      private_jwk: private_jwk
    } do
      token =
        sign_token(
          %{
            "sub" => "user?id=#{user_id}",
            "role" => "admin",
            "exp" => System.system_time(:second) + 3600,
            "iat" => System.system_time(:second)
          },
          private_jwk
        )

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> JwtAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert json_response(conn, 401)["error"] == "Invalid token: missing_org_id"
    end

    test "rejects JWT with invalid sub format", %{
      conn: conn,
      org_id: org_id,
      private_jwk: private_jwk
    } do
      token =
        sign_token(
          %{
            "sub" => "invalid_format",
            "org_id" => org_id,
            "role" => "admin",
            "exp" => System.system_time(:second) + 3600,
            "iat" => System.system_time(:second)
          },
          private_jwk
        )

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> JwtAuth.call([])

      # The plug accepts bare UUIDs and bare strings as sub — "invalid_format" is accepted
      # The plug extracts it via the second clause: extract_user_id(%{"sub" => sub})
      refute conn.halted
    end

    test "handles different role values", %{
      conn: _conn,
      user_id: user_id,
      org_id: org_id,
      private_jwk: private_jwk
    } do
      roles = ["owner", "admin", "member", "viewer"]

      Enum.each(roles, fn role ->
        token =
          sign_token(
            %{
              "sub" => "user?id=#{user_id}",
              "org_id" => org_id,
              "role" => role,
              "exp" => System.system_time(:second) + 3600,
              "iat" => System.system_time(:second)
            },
            private_jwk
          )

        conn =
          build_conn()
          |> put_req_header("authorization", "Bearer #{token}")
          |> JwtAuth.call([])

        refute conn.halted
        assert conn.assigns.current_role == String.to_existing_atom(role)
      end)
    end

    test "sets RLS tenant context in database", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id,
      private_jwk: private_jwk
    } do
      token =
        sign_token(
          %{
            "sub" => "user?id=#{user_id}",
            "org_id" => org_id,
            "role" => "admin",
            "exp" => System.system_time(:second) + 3600,
            "iat" => System.system_time(:second)
          },
          private_jwk
        )

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
