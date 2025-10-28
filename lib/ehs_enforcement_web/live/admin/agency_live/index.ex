defmodule EhsEnforcementWeb.Admin.AgencyLive.Index do
  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Agency Management")
     |> assign(:loading, true)
     |> load_agencies()}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_agency", %{"id" => id}, socket) do
    case Ash.get(EhsEnforcement.Enforcement.Agency, id) do
      {:ok, agency} ->
        case Ash.destroy(agency) do
          :ok ->
            {:noreply,
             socket
             |> put_flash(:info, "Agency #{agency.name} deleted successfully")
             |> load_agencies()}

          {:error, error} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to delete agency: #{inspect(error)}")}
        end

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Agency not found")}
    end
  end

  # Private functions

  defp load_agencies(socket) do
    try do
      agencies = Enforcement.list_agencies!()

      socket
      |> assign(:agencies, agencies)
      |> assign(:total_agencies, length(agencies))
      |> assign(:loading, false)
    rescue
      error ->
        require Logger
        Logger.error("Failed to load agencies: #{inspect(error)}")

        socket
        |> assign(:agencies, [])
        |> assign(:total_agencies, 0)
        |> assign(:loading, false)
        |> put_flash(:error, "Failed to load agencies")
    end
  end

  defp format_datetime(datetime) when is_struct(datetime, NaiveDateTime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end

  defp format_datetime(_), do: ""
end
