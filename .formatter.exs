[
  import_deps: [:oban, :ash_oban, :ecto, :ecto_sql, :phoenix, :ash_rate_limiter],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
]
