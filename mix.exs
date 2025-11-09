defmodule EhsEnforcement.MixProject do
  use Mix.Project

  def project do
    [
      app: :ehs_enforcement,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],

      # Dialyzer configuration
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:ex_unit, :mix],
        flags: [:error_handling, :underspecs, :unmatched_returns],
        ignore_warnings: ".dialyzer_ignore.exs",
        list_unused_filters: true
      ],

      # ExDoc configuration
      docs: [
        main: "EhsEnforcement",
        output: "docs-dev/exdoc",
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
          Configuration: [
            ~r/EhsEnforcement.Configuration/
          ],
          "Web Interface": [
            ~r/EhsEnforcementWeb/
          ],
          Authentication: [
            ~r/EhsEnforcement.Accounts/
          ],
          Utilities: [
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
      {:phoenix, "~> 1.8.0"},
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
      {:ash, "~> 3.7"},
      {:ash_phoenix, "~> 2.3"},
      {:ash_postgres, "~> 2.6"},
      {:ash_graphql, "~> 1.8"},
      {:ash_json_api, "~> 1.4"},
      {:ash_admin, "~> 0.13"},
      {:ash_rate_limiter, "~> 0.2"},
      {:hammer, "~> 7.0"},
      # Additional dependencies from original project
      {:req, "~> 0.5"},
      {:tesla, "~> 1.4"},
      {:hackney, "~> 1.18"},
      {:csv, "~> 3.0"},
      {:number, "~> 1.0"},
      {:ex_prompt, "~> 0.2.0"},
      {:dotenv, "~> 3.1.0", only: [:dev, :test]},
      {:lazy_html, ">= 0.1.0", only: :test},
      # Ash Authentication
      {:ash_authentication, "~> 4.12"},
      {:ash_authentication_phoenix, "~> 2.12"},
      # SAT solver for Ash policies - PicoSAT for optimal performance
      {:picosat_elixir, "~> 0.2"},
      # Backup pure Elixir SAT solver (can be removed if PicoSAT works)
      {:simple_sat, "~> 0.1"},
      # Background job processing for Ash
      {:ash_oban, "~> 0.5"},
      {:oban, "~> 2.20"},
      # Event tracking for Ash
      {:ash_events, "~> 0.5"},
      # Documentation generation
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      # Diagram generation for Ash resources (dev-only, brings in ex_cmd ~> 0.16.0)
      {:ash_diagram, "~> 0.1.0", only: :dev, runtime: false},
      # Code quality tools
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      # Cookie consent management
      {:ash_cookie_consent, "~> 0.1.0"}
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
