defmodule EhsEnforcement.Consent.StorageTest do
  use EhsEnforcement.DataCase

  alias EhsEnforcement.Consent.Storage
  alias EhsEnforcement.Consent.ConsentSettings
  import EhsEnforcementWeb.ConnCase, only: [create_test_user: 1]
  require Ash.Query

  describe "get_consent/2" do
    test "returns nil when no consent exists" do
      conn = %Plug.Conn{assigns: %{}}
      opts = [resource: ConsentSettings, user_id_key: :current_user]

      assert Storage.get_consent(conn, opts) == nil
    end

    test "loads consent from database for authenticated user" do
      # Create a user
      user =
        create_test_user(%{
          email: "test-consent-#{System.unique_integer([:positive])}@example.com"
        })

      # Create consent record in database
      consent_params = %{
        user_id: user.id,
        terms: "v1.0",
        groups: ["essential", "analytics"],
        consented_at: DateTime.utc_now() |> DateTime.truncate(:second),
        expires_at: DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.truncate(:second)
      }

      {:ok, _record} =
        ConsentSettings
        |> Ash.Changeset.for_create(:create, consent_params)
        |> Ash.create()

      # Simulate authenticated conn (no cookie, should load from DB)
      conn = %Plug.Conn{assigns: %{current_user: user}}
      opts = [resource: ConsentSettings, user_id_key: :current_user]

      consent = Storage.get_consent(conn, opts)

      assert consent["terms"] == "v1.0"
      assert consent["groups"] == ["essential", "analytics"]
      assert consent["consented_at"] != nil
      assert consent["expires_at"] != nil
    end

    test "returns nil for anonymous user with no cookie" do
      conn = %Plug.Conn{assigns: %{current_user: nil}}
      opts = [resource: ConsentSettings, user_id_key: :current_user]

      assert Storage.get_consent(conn, opts) == nil
    end

    test "prefers newer database consent over older cookie consent" do
      user =
        create_test_user(%{
          email: "test-newer-#{System.unique_integer([:positive])}@example.com"
        })

      # Old cookie consent (30 days ago)
      old_time = DateTime.utc_now() |> DateTime.add(-30, :day) |> DateTime.truncate(:second)

      cookie_consent = %{
        "terms" => "v1.0",
        "groups" => ["essential"],
        "consented_at" => old_time,
        "expires_at" =>
          DateTime.utc_now() |> DateTime.add(335, :day) |> DateTime.truncate(:second)
      }

      # Newer database consent (today)
      new_time = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _record} =
        ConsentSettings
        |> Ash.Changeset.for_create(:create, %{
          user_id: user.id,
          terms: "v1.0",
          groups: ["essential", "analytics", "marketing"],
          consented_at: new_time,
          expires_at: DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.truncate(:second)
        })
        |> Ash.create()

      # Mock conn with cookie (via assigns) and authenticated user
      conn = %Plug.Conn{assigns: %{current_user: user, consent: cookie_consent}}
      opts = [resource: ConsentSettings, user_id_key: :current_user]

      # Should get DB consent because it's newer
      consent = Storage.get_consent(conn, opts)
      assert consent["groups"] == ["essential", "analytics", "marketing"]
      assert DateTime.compare(consent["consented_at"], cookie_consent["consented_at"]) == :gt
    end
  end

  describe "put_consent/3" do
    test "saves consent to database for authenticated user" do
      user =
        create_test_user(%{
          email: "test-save-#{System.unique_integer([:positive])}@example.com"
        })

      consent = %{
        "terms" => "v1.0",
        "groups" => ["essential", "analytics"],
        "consented_at" => DateTime.utc_now() |> DateTime.truncate(:second),
        "expires_at" =>
          DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.truncate(:second)
      }

      conn = %Plug.Conn{assigns: %{current_user: user}}
      opts = [resource: ConsentSettings, user_id_key: :current_user]

      _updated_conn = Storage.put_consent(conn, consent, opts)

      # Verify record was created in database
      records =
        ConsentSettings
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read!()

      assert length(records) == 1
      [record] = records
      assert record.terms == "v1.0"
      assert record.groups == ["essential", "analytics"]
      assert record.user_id == user.id
    end

    test "does not save to database for anonymous user" do
      consent = %{
        "terms" => "v1.0",
        "groups" => ["essential"],
        "consented_at" => DateTime.utc_now() |> DateTime.truncate(:second),
        "expires_at" =>
          DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.truncate(:second)
      }

      conn = %Plug.Conn{assigns: %{current_user: nil}}
      opts = [resource: ConsentSettings, user_id_key: :current_user]

      _updated_conn = Storage.put_consent(conn, consent, opts)

      # Verify no records were created in database
      records =
        ConsentSettings
        |> Ash.Query.filter(is_nil(user_id))
        |> Ash.read!()

      # Should be no records (anonymous consent stays in cookie only)
      assert records == []
    end

    test "creates new consent record each time (audit trail)" do
      user =
        create_test_user(%{
          email: "test-audit-#{System.unique_integer([:positive])}@example.com"
        })

      # First consent
      consent1 = %{
        "terms" => "v1.0",
        "groups" => ["essential"],
        "consented_at" => DateTime.utc_now() |> DateTime.truncate(:second),
        "expires_at" =>
          DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.truncate(:second)
      }

      conn = %Plug.Conn{assigns: %{current_user: user}}
      opts = [resource: ConsentSettings, user_id_key: :current_user]

      Storage.put_consent(conn, consent1, opts)

      # Wait a moment to ensure different timestamps
      :timer.sleep(100)

      # Second consent (user changes preferences)
      consent2 = %{
        "terms" => "v1.0",
        "groups" => ["essential", "analytics", "marketing"],
        "consented_at" => DateTime.utc_now() |> DateTime.truncate(:second),
        "expires_at" =>
          DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.truncate(:second)
      }

      Storage.put_consent(conn, consent2, opts)

      # Should have 2 records (audit trail)
      records =
        ConsentSettings
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.Query.sort(consented_at: :asc)
        |> Ash.read!()

      assert length(records) == 2
      assert Enum.at(records, 0).groups == ["essential"]
      assert Enum.at(records, 1).groups == ["essential", "analytics", "marketing"]
    end
  end

  describe "delete_consent/2" do
    test "deletes all consent records for authenticated user" do
      user =
        create_test_user(%{
          email: "test-delete-#{System.unique_integer([:positive])}@example.com"
        })

      # Create multiple consent records
      for groups <- [["essential"], ["essential", "analytics"]] do
        {:ok, _} =
          ConsentSettings
          |> Ash.Changeset.for_create(:create, %{
            user_id: user.id,
            terms: "v1.0",
            groups: groups,
            consented_at: DateTime.utc_now() |> DateTime.truncate(:second),
            expires_at:
              DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.truncate(:second)
          })
          |> Ash.create()
      end

      # Verify records exist
      records_before =
        ConsentSettings
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read!()

      assert length(records_before) == 2

      # Delete consent
      conn = %Plug.Conn{assigns: %{current_user: user}}
      opts = [resource: ConsentSettings, user_id_key: :current_user]

      Storage.delete_consent(conn, opts)

      # Verify records deleted
      records_after =
        ConsentSettings
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read!()

      assert records_after == []
    end

    test "does not error for anonymous user" do
      conn = %Plug.Conn{assigns: %{current_user: nil}}
      opts = [resource: ConsentSettings, user_id_key: :current_user]

      # Should not raise error
      assert Storage.delete_consent(conn, opts)
    end
  end
end
