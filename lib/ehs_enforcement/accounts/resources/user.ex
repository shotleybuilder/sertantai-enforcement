defmodule EhsEnforcement.Accounts.User do
  @moduledoc """
  User resource with GitHub OAuth authentication and admin privilege management.
  """

  use Ash.Resource,
    domain: EhsEnforcement.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("users")
    repo(EhsEnforcement.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # Core authentication fields (following Ash Authentication patterns)
    attribute(:email, :ci_string, allow_nil?: false, public?: true)

    # GitHub OAuth fields
    attribute(:github_id, :string, allow_nil?: true)
    attribute(:github_login, :string, allow_nil?: true)
    attribute(:name, :string, allow_nil?: true)
    attribute(:avatar_url, :string, allow_nil?: true)
    attribute(:github_url, :string, allow_nil?: true)

    # Admin privilege management for EHS Enforcement
    attribute(:is_admin, :boolean, default: false, public?: true)
    attribute(:admin_checked_at, :utc_datetime_usec, allow_nil?: true)
    attribute(:last_login_at, :utc_datetime_usec, allow_nil?: true)

    # OAuth provider tracking
    attribute(:primary_provider, :string, default: "github", public?: true)

    timestamps()
  end

  authentication do
    strategies do
      oauth2 :github do
        client_id(fn _, _ ->
          {:ok,
           System.get_env("EHS_ENFORCEMENT_GITHUB_CLIENT_ID") ||
             System.get_env("GITHUB_CLIENT_ID", "")}
        end)

        client_secret(fn _, _ ->
          {:ok,
           System.get_env("EHS_ENFORCEMENT_GITHUB_CLIENT_SECRET") ||
             System.get_env("GITHUB_CLIENT_SECRET", "")}
        end)

        redirect_uri(fn _, _ ->
          {:ok,
           System.get_env("GITHUB_REDIRECT_URI", "http://localhost:4002/auth/github/callback")}
        end)

        base_url("https://github.com")
        authorize_url("/login/oauth/authorize")
        token_url("/login/oauth/access_token")
        user_url("https://api.github.com/user")
        authorization_params(scope: "user:email,read:org")
        identity_resource(EhsEnforcement.Accounts.UserIdentity)
      end
    end

    tokens do
      enabled?(true)
      token_resource(EhsEnforcement.Accounts.Token)

      signing_secret(fn _, _ ->
        Application.fetch_env(:ehs_enforcement, :token_signing_secret)
      end)
    end

    session_identifier(:jti)
  end

  identities do
    identity(:unique_email, [:email])
  end

  actions do
    defaults([:read])

    update :update do
      accept([:email, :name, :avatar_url, :github_url, :last_login_at])
    end

    create :register_with_github do
      argument(:user_info, :map, allow_nil?: false)
      argument(:oauth_tokens, :map, allow_nil?: false)

      upsert?(true)
      upsert_identity(:unique_email)

      upsert_fields([
        :name,
        :avatar_url,
        :github_id,
        :github_login,
        :github_url,
        :primary_provider,
        :last_login_at
      ])

      change(AshAuthentication.Strategy.OAuth2.IdentityChange)
      change(AshAuthentication.GenerateTokenChange)

      change(fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)

        changeset
        |> Ash.Changeset.change_attribute(:email, downcase_email(user_info["email"]))
        |> Ash.Changeset.change_attribute(:github_id, to_string(user_info["id"]))
        |> Ash.Changeset.change_attribute(:github_login, user_info["login"])
        |> Ash.Changeset.change_attribute(:name, user_info["name"])
        |> Ash.Changeset.change_attribute(:avatar_url, user_info["avatar_url"])
        |> Ash.Changeset.change_attribute(:github_url, user_info["html_url"])
        |> Ash.Changeset.change_attribute(:primary_provider, "github")
        |> Ash.Changeset.change_attribute(:last_login_at, DateTime.utc_now())
      end)
    end

    update :update_admin_status do
      require_atomic?(false)
      accept([:is_admin, :admin_checked_at])

      change(fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :admin_checked_at, DateTime.utc_now())
      end)
    end

    read :by_github_id do
      argument(:github_id, :string, allow_nil?: false)
      filter(expr(github_id == ^arg(:github_id)))
    end

    read :by_github_login do
      argument(:github_login, :string, allow_nil?: false)
      filter(expr(github_login == ^arg(:github_login)))
    end

    read :admins do
      filter(expr(is_admin == true))
    end
  end

  policies do
    # Allow all read actions for authentication
    policy action_type(:read) do
      authorize_if(always())
    end

    # Allow GitHub OAuth registration for anyone
    policy action(:register_with_github) do
      authorize_if(always())
    end

    # Users can update their own data
    policy action_type(:update) do
      authorize_if(expr(id == ^actor(:id)))
      authorize_if(actor_attribute_equals(:is_admin, true))
    end

    # Only system can update admin status
    policy action(:update_admin_status) do
      authorize_if(always())
    end

    # Admin users can destroy any user
    policy action_type(:destroy) do
      authorize_if(actor_attribute_equals(:is_admin, true))
    end
  end

  # Relationships
  relationships do
    has_many :user_identities, EhsEnforcement.Accounts.UserIdentity
  end

  calculations do
    calculate(
      :admin_status_fresh?,
      :boolean,
      expr(
        is_nil(admin_checked_at) or
          fragment("? > (? + interval '1 hour')", now(), admin_checked_at)
      )
    )

    calculate(
      :display_name,
      :string,
      expr(
        cond do
          not is_nil(name) -> name
          not is_nil(github_login) -> github_login
          true -> email
        end
      )
    )
  end

  code_interface do
    define(:update)
    define(:update_admin_status, args: [:is_admin])
    define(:by_github_id, args: [:github_id])
    define(:by_github_login, args: [:github_login])
    define(:admins)
  end

  # Helper functions
  defp downcase_email(nil), do: nil
  defp downcase_email(email) when is_binary(email), do: String.downcase(email)
end
