defmodule EhsEnforcement.MixProject do
  use Mix.Project

  def project do
    [
      app: :ehs_enforcement,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      
      # ExDoc configuration
      docs: [
        main: "EhsEnforcement",
        output: "docs_dev/exdoc",
        extras: ["README.md"],
        groups_for_modules: [
          "Enforcement Domain": [
            ~r/EhsEnforcement.Enforcement/
          ],
          "Scraping System": [
            ~r/EhsEnforcement.Scraping/,
            ~r/EhsEnforcement.Agencies/
          ],
          "Integration & Sync": [
            ~r/EhsEnforcement.Integrations/,
            ~r/EhsEnforcement.Sync/
          ],
          "Configuration": [
            ~r/EhsEnforcement.Configuration/
          ],
          "Web Interface": [
            ~r/EhsEnforcementWeb/
          ],
          "Authentication": [
            ~r/EhsEnforcement.Accounts/
          ],
          "Utilities": [
            ~r/EhsEnforcement.Logger/,
            ~r/EhsEnforcement.Telemetry/,
            ~r/EhsEnforcement.Utility/
          ]
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {EhsEnforcement.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:usage_rules, "~> 0.1", only: [:dev]},
      {:phoenix, "~> 1.7.21"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, ">= 0.30.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:tidewave, "~> 0.1", only: [:dev]},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      # Ash framework dependencies
      {:ash, "~> 3.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_graphql, "~> 1.0"},
      {:ash_json_api, "~> 1.0"},
      {:ash_admin, "~> 0.11"},
      {:ash_rate_limiter, "~> 0.1"},
      {:hammer, "~> 7.0"},
      # Additional dependencies from original project
      {:req, "~> 0.5"},
      {:tesla, "~> 1.4"},
      {:hackney, "~> 1.18"},
      {:csv, "~> 3.0"},
      {:number, "~> 1.0"},
      {:ex_prompt, "~> 0.2.0"},
      {:dotenv, "~> 3.1.0", only: [:dev, :test]},
      # Ash Authentication
      {:ash_authentication, "~> 4.0"},
      {:ash_authentication_phoenix, "~> 2.0"},
      # SAT solver for Ash policies
      {:picosat_elixir, "~> 0.2"},
      # Background job processing for Ash
      {:ash_oban, "~> 0.2"},
      {:oban, "~> 2.17"},
      # Event tracking for Ash
      {:ash_events, "~> 0.1"},
      # Documentation generation
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind ehs_enforcement", "esbuild ehs_enforcement"],
      "assets.deploy": [
        "tailwind ehs_enforcement --minify",
        "esbuild ehs_enforcement --minify",
        "phx.digest"
      ]
    ]
  end
end
