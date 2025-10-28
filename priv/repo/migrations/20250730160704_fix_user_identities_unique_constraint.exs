defmodule EhsEnforcement.Repo.Migrations.FixUserIdentitiesUniqueConstraint do
  use Ecto.Migration

  def change do
    # Drop the old unique index
    drop unique_index("user_identities", [:uid, :strategy])

    # Create the proper unique constraint that AshAuthentication expects
    create unique_index("user_identities", [:strategy, :uid, :user_id])
  end
end
