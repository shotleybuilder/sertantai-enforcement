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

  @doc """
  Update an existing agency via the API.

  PATCH /api/agencies/:id

  Expects JSON body with:
  - name: string (optional)
  - base_url: string (optional)
  - enabled: boolean (optional)

  Note: code cannot be changed after creation
  """
  def update(conn, %{"id" => id} = params) do
    require Ash.Query

    case Agency
         |> Ash.Query.filter(id == ^id)
         |> Ash.read() do
      {:ok, [agency]} ->
        # Build attributes for update (only include provided fields)
        attributes =
          %{}
          |> maybe_put(:name, params["name"])
          |> maybe_put(:base_url, params["base_url"])
          |> maybe_put(:enabled, params["enabled"])

        case agency
             |> Ash.Changeset.for_update(:update, attributes)
             |> Ash.update() do
          {:ok, updated_agency} ->
            conn
            |> json(%{
              success: true,
              data: %{
                id: updated_agency.id,
                code: updated_agency.code,
                name: updated_agency.name,
                base_url: updated_agency.base_url,
                enabled: updated_agency.enabled,
                inserted_at: updated_agency.inserted_at,
                updated_at: updated_agency.updated_at
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
              error: "Failed to update agency",
              details: Exception.message(error)
            })
        end

      {:ok, []} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Agency not found"
        })

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to fetch agency",
          details: Exception.message(error)
        })
    end
  end

  @doc """
  Delete an agency via the API.

  DELETE /api/agencies/:id
  """
  def delete(conn, %{"id" => id}) do
    require Ash.Query

    case Agency
         |> Ash.Query.filter(id == ^id)
         |> Ash.read() do
      {:ok, [agency]} ->
        case Ash.destroy(agency) do
          :ok ->
            conn
            |> json(%{
              success: true,
              message: "Agency deleted successfully"
            })

          {:error, error} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{
              success: false,
              error: "Failed to delete agency",
              details: Exception.message(error)
            })
        end

      {:ok, []} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Agency not found"
        })

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to fetch agency",
          details: Exception.message(error)
        })
    end
  end

  # Helper function to conditionally add fields to map
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
