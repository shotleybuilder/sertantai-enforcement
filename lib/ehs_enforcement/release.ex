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
    
    # Run Ash migrations using the mix task functionality
    try do
      Mix.Tasks.Ash.Migrate.run([])
    rescue
      # If Mix.Tasks.Ash.Migrate is not available, skip silently
      UndefinedFunctionError -> 
        IO.puts("Ash migrate task not available, skipping Ash migrations...")
        :ok
      error -> 
        IO.puts("Error running Ash migrations: #{inspect(error)}")
        :ok
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
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
        :ok -> IO.puts("Database created successfully")
        {:error, :already_up} -> IO.puts("Database already exists")
        {:error, term} -> 
          IO.puts("Error creating database: #{inspect(term)}")
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
