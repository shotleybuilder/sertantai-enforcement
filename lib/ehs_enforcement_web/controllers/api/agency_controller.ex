defmodule EhsEnforcementWeb.Api.AgencyController do
  use EhsEnforcementWeb, :controller

  alias EhsEnforcement.Enforcement.Agency

  @doc """
  Create a new agency via the API.

  Expects JSON body with:
  - code: one of [:hse, :onr, :orr, :ea]
  - name: string (required)
  - base_url: string (optional)
  - enabled: boolean (optional, defaults to true)
  """
  def create(conn, params) do
    # Convert string code to atom (safe because we validate against a fixed set)
    code_atom = String.to_existing_atom(params["code"])

    # Build attributes for Ash create action
    attributes = %{
      code: code_atom,
      name: params["name"],
      base_url: params["base_url"],
      enabled: params["enabled"] || true
    }

    # Use proper Ash changeset pattern
    case Agency
         |> Ash.Changeset.for_create(:create, attributes)
         |> Ash.create() do
      {:ok, agency} ->
        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          data: %{
            id: agency.id,
            code: agency.code,
            name: agency.name,
            base_url: agency.base_url,
            enabled: agency.enabled,
            inserted_at: agency.inserted_at,
            updated_at: agency.updated_at
          }
        })

      {:error, %Ash.Error.Invalid{} = error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Validation failed",
          details: Exception.message(error)
        })

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to create agency",
          details: Exception.message(error)
        })
    end
  rescue
    ArgumentError ->
      # Invalid code atom
      conn
      |> put_status(:bad_request)
      |> json(%{
        success: false,
        error: "Invalid agency code. Must be one of: hse, onr, orr, ea"
      })
  end

  @doc """
  List all agencies via the API.
  """
  def index(conn, _params) do
    case Ash.read(Agency) do
      {:ok, agencies} ->
        conn
        |> json(%{
          success: true,
          data:
            Enum.map(agencies, fn agency ->
              %{
                id: agency.id,
                code: agency.code,
                name: agency.name,
                base_url: agency.base_url,
                enabled: agency.enabled,
                inserted_at: agency.inserted_at,
                updated_at: agency.updated_at
              }
            end)
        })

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to fetch agencies",
          details: Exception.message(error)
        })
    end
  end
end
