defmodule EhsEnforcement.Repo.Migrations.SimpleRemoveViolationsTable do
  use Ecto.Migration

  def up do
    # Check if violations table exists first
    if table_exists?(:violations) do
      IO.puts("Removing violations table...")
      drop table(:violations)
      IO.puts("✅ Violations table removed successfully")
    else
      IO.puts("ℹ️  Violations table does not exist - nothing to remove")
    end
  end

  def down do
    # Recreate basic violations table structure for rollback
    create table(:violations, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :violation_sequence, :bigint
      add :case_reference, :text
      add :individual_fine, :decimal
      add :offence_description, :text
      add :legal_act, :text
      add :legal_section, :text

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :case_id,
          references(:cases,
            column: :id,
            name: "violations_case_id_fkey",
            type: :uuid,
            prefix: "public"
          )
    end
  end

  defp table_exists?(table_name) do
    query = """
    SELECT EXISTS (
      SELECT FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = '#{table_name}'
    )
    """

    case Ecto.Adapters.SQL.query(EhsEnforcement.Repo, query, []) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end
end
