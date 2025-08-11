#!/usr/bin/env elixir

# Setup agencies needed for import
# Usage: docker compose exec -T app bin/ehs_enforcement eval "$(cat scripts/setup_agencies.exs)"

# Start all required applications in the correct order
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)
Application.ensure_all_started(:ecto_sql)
Application.ensure_all_started(:ash)
Application.ensure_all_started(:ash_postgres)

# Start the Ecto repo explicitly
{:ok, _} = EhsEnforcement.Repo.start_link()

alias EhsEnforcement.Enforcement.Agency
require Logger

defmodule SetupAgencies do
  def run do
    Logger.info("Setting up agencies for import...")
    
    # Create HSE agency
    case create_hse_agency() do
      {:ok, agency} ->
        Logger.info("✅ Created HSE agency: #{agency.name} (#{agency.code})")
        {:ok, :created}
      {:error, %Ash.Error.Invalid{errors: errors}} ->
        # Check if it's a duplicate error
        if Enum.any?(errors, fn error -> 
          error.field == :code and String.contains?(error.message || "", "already been taken")
        end) do
          Logger.info("✅ HSE agency already exists")
          {:ok, :exists}
        else
          Logger.error("❌ Failed to create HSE agency: #{inspect(errors)}")
          {:error, errors}
        end
      {:error, error} ->
        Logger.error("❌ Failed to create HSE agency: #{inspect(error)}")
        {:error, error}
    end
  end

  defp create_hse_agency do
    Ash.create(Agency, %{
      code: :hse,
      name: "Health and Safety Executive", 
      base_url: "https://www.hse.gov.uk",
      enabled: true
    })
  end
end

# Run the setup
case SetupAgencies.run() do
  {:ok, :created} ->
    IO.puts("Success: HSE agency created")
  {:ok, :exists} ->
    IO.puts("Success: HSE agency already exists")
  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
    System.halt(1)
end