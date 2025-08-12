defmodule EhsEnforcement.Repo do
  use AshPostgres.Repo,
    otp_app: :ehs_enforcement,
    warn_on_missing_ash_functions?: false

  def min_pg_version do
    %Version{major: 14, minor: 0, patch: 0}
  end

  def installed_extensions do
    ["uuid-ossp", "citext", "pg_trgm"]
  end
end
