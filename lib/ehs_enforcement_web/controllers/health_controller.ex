defmodule EhsEnforcementWeb.HealthController do
  use EhsEnforcementWeb, :controller

  def check(conn, _params) do
    # Emit telemetry for health check request
    :telemetry.execute([:ehs_enforcement, :health_check], %{requests: 1})

    # Basic health checks
    health_status = %{
      status: "ok",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      version: Application.spec(:ehs_enforcement, :vsn) |> to_string(),
      environment: Application.get_env(:ehs_enforcement, :environment, :unknown)
    }

    # Check database connectivity  
    case check_database() do
      :ok ->
        :telemetry.execute([:ehs_enforcement, :health_check], %{success: 1})

        conn
        |> put_status(:ok)
        |> json(Map.put(health_status, :database, "connected"))

      {:error, reason} ->
        :telemetry.execute([:ehs_enforcement, :health_check], %{failure: 1})

        conn
        |> put_status(:service_unavailable)
        |> json(
          Map.merge(health_status, %{
            status: "error",
            database: "disconnected",
            error: to_string(reason)
          })
        )
    end
  end

  defp check_database do
    try do
      EhsEnforcement.Repo.query!("SELECT 1", [])
      :ok
    rescue
      error -> {:error, error}
    end
  end
end
