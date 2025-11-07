defmodule EhsEnforcement.Consent.ConsentSettings do
  use Ash.Resource,
    domain: EhsEnforcement.Consent,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("consent_settings")
    repo(EhsEnforcement.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :terms, :string do
      allow_nil?(false)
      description "Privacy policy version identifier"
    end

    attribute :groups, {:array, :string} do
      default([])
      description "List of consented cookie categories"
    end

    attribute :consented_at, :utc_datetime_usec do
      description "When user provided consent"
    end

    attribute :expires_at, :utc_datetime_usec do
      description "When consent expires (typically 365 days)"
    end

    timestamps()
  end

  relationships do
    belongs_to :user, EhsEnforcement.Accounts.User do
      allow_nil?(true)
      description "Optional link to authenticated user"
      attribute_writable?(true)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:terms, :groups, :consented_at, :expires_at, :user_id])

      change(fn changeset, _context ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        expires = DateTime.add(now, 365, :day) |> DateTime.truncate(:second)

        changeset
        |> Ash.Changeset.force_change_attribute(:consented_at, now)
        |> Ash.Changeset.force_change_attribute(:expires_at, expires)
      end)
    end

    update :update do
      primary?(true)
      require_atomic?(false)
      accept([:terms, :groups, :expires_at])
    end

    create :grant_consent do
      accept([:terms, :groups, :user_id])

      change(fn changeset, _context ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        expires = DateTime.add(now, 365, :day) |> DateTime.truncate(:second)

        changeset
        |> Ash.Changeset.force_change_attribute(:consented_at, now)
        |> Ash.Changeset.force_change_attribute(:expires_at, expires)
      end)
    end

    update :revoke_consent do
      require_atomic?(false)

      change(fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :groups, [])
      end)
    end

    read :active_consents do
      filter(
        expr(
          not is_nil(consented_at) and
            (is_nil(expires_at) or expires_at > now())
        )
      )
    end
  end

  validations do
    validate(present(:terms), message: "Privacy policy version must be specified")

    validate(fn changeset, _context ->
      case Ash.Changeset.get_attribute(changeset, :groups) do
        groups when is_list(groups) ->
          if Enum.all?(groups, &is_binary/1) do
            :ok
          else
            {:error, field: :groups, message: "All groups must be strings"}
          end

        _ ->
          {:error, field: :groups, message: "Groups must be a list"}
      end
    end)
  end

  code_interface do
    define(:create)
    define(:read)
    define(:update)
    define(:destroy)
    define(:grant_consent)
    define(:revoke_consent)
    define(:active_consents)
  end
end
