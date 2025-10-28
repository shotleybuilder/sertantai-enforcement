defmodule EhsEnforcement.Repo.Migrations.StandardizeOffenceActionTypeFields do
  use Ecto.Migration

  def change do
    # Rename notice_type to offence_action_type in notices table
    rename table(:notices), :notice_type, to: :offence_action_type

    # Add missing fields to notices table
    alter table(:notices) do
      add :offence_action_date, :date
      add :offence_breaches, :text
      add :url, :text
    end

    # Add missing fields to cases table
    alter table(:cases) do
      add :offence_action_type, :text
      add :url, :text
    end
  end
end
