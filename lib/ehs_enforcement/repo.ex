defmodule EhsEnforcement.Repo do
  use AshPostgres.Repo,
    otp_app: :ehs_enforcement,
    warn_on_missing_ash_functions?: false

  @doc """
  Multi-tenancy is not used in this application. This function is a stub
  that raises if called, as required by AshPostgres.Repo.
  """
  @spec all_tenants() :: no_return()
  def all_tenants do
    raise """
    Multi-tenancy is not configured for EhsEnforcement.Repo.
    The all_tenants/0 function should not be called.
    """
  end

  def min_pg_version do
    %Version{major: 14, minor: 0, patch: 0}
  end

  def installed_extensions do
    ["uuid-ossp", "citext", "pg_trgm"]
  end
end
