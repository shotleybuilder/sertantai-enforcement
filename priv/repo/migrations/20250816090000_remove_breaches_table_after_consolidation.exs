defmodule EhsEnforcement.Repo.Migrations.RemoveBreachesTableAfterConsolidation do
  use Ecto.Migration

  def up do
    # Check if breaches table exists first
    if table_exists?(:breaches) do
      IO.puts("Removing breaches table after schema consolidation...")
      drop table(:breaches)
      IO.puts("✅ Breaches table removed successfully")
    else
      IO.puts("ℹ️  Breaches table does not exist - nothing to remove")
    end
  end

  def down do
    # Recreate basic breaches table structure for rollback
    create table(:breaches, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :breach_description, :text
      add :legislation_reference, :text
      add :legislation_type, :text

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :case_id,
          references(:cases,
            column: :id,
            name: "breaches_case_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false
    end

    IO.puts("⚠️  Breaches table structure recreated for rollback")
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
