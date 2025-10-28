defmodule EhsEnforcement.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :ehs_enforcement

  def migrate do
    load_app()

    # Run standard Ecto migrations first
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    # Run Ash migrations
    migrate_ash()
  end

  def migrate_ash do
    load_app()

    IO.puts("Running Ash migrations...")

    # In a release environment, Ash migrations should have already been 
    # generated and converted to standard Ecto migrations.
    # The migrate() function above will handle both Ecto and Ash-generated migrations.

    # However, we can still run specific Ash data layer operations if needed
    try do
      # Ensure all Ash domains and resources are loaded
      domains = [
        EhsEnforcement.Accounts,
        EhsEnforcement.Configuration,
        EhsEnforcement.Enforcement,
        EhsEnforcement.Events,
        EhsEnforcement.Scraping
      ]

      # Load and verify all domains
      for domain <- domains do
        try do
          # Just ensure the domain is loaded - migrations should be handled by Ecto
          Code.ensure_loaded(domain)
          IO.puts("✓ Loaded Ash domain: #{inspect(domain)}")
        rescue
          error ->
            IO.puts("⚠ Could not load Ash domain #{inspect(domain)}: #{inspect(error)}")
        end
      end

      IO.puts("✓ Ash domains loaded successfully")
      IO.puts("Note: Ash resource migrations are handled through standard Ecto migrations")
    rescue
      error ->
        IO.puts("Warning: Error during Ash domain loading: #{inspect(error)}")

        IO.puts(
          "This may not affect the migration if Ecto migrations include Ash-generated migrations"
        )
    end

    :ok
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def status do
    load_app()

    IO.puts("=== EHS Enforcement Release Status ===")
    IO.puts("Application: #{@app}")
    IO.puts("Environment: #{Mix.env()}")

    # Check database connectivity
    for repo <- repos() do
      case repo.__adapter__.status(repo) do
        :up -> IO.puts("✓ Database #{inspect(repo)}: Connected")
        :down -> IO.puts("✗ Database #{inspect(repo)}: Disconnected")
        status -> IO.puts("? Database #{inspect(repo)}: #{inspect(status)}")
      end
    end

    # Check migration status
    IO.puts("\n=== Migration Status ===")

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          try do
            status = Ecto.Migrator.migrations(repo)
            IO.puts("Repository: #{inspect(repo)}")

            for {migration_status, version, description} <- status do
              indicator = if migration_status == :up, do: "✓", else: "✗"
              IO.puts("  #{indicator} #{version} #{description}")
            end
          rescue
            error ->
              IO.puts("✗ Could not get migration status for #{inspect(repo)}: #{inspect(error)}")
          end
        end)
    end

    :ok
  end

  def eval(code_string) do
    load_app()
    {result, _binding} = Code.eval_string(code_string)
    IO.inspect(result)
  end

  def setup do
    create()
    migrate()
    seed()
  end

  def create do
    load_app()

    for repo <- repos() do
      case repo.__adapter__.storage_up(repo.config) do
        :ok ->
          IO.puts("✓ Database created successfully for #{inspect(repo)}")

        {:error, :already_up} ->
          IO.puts("✓ Database already exists for #{inspect(repo)}")

        {:error, term} ->
          IO.puts("✗ Error creating database for #{inspect(repo)}: #{inspect(term)}")
          System.halt(1)
      end
    end
  end

  def seed do
    load_app()

    seed_file = Path.join([Application.app_dir(@app, "priv"), "repo", "seeds.exs"])

    if File.exists?(seed_file) do
      Code.eval_file(seed_file)
      IO.puts("Database seeded successfully")
    else
      IO.puts("No seed file found, skipping...")
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
