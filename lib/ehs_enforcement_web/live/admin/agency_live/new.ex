defmodule EhsEnforcementWeb.Admin.AgencyLive.New do
  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement.Agency

  @impl true
  def mount(_params, _session, socket) do
    form = AshPhoenix.Form.for_create(Agency, :create, forms: [auto?: false]) |> to_form()

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:page_title, "New Agency")
     |> assign(:loading, false)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, agency} ->
        {:noreply,
         socket
         |> put_flash(:info, "Agency #{agency.name} created successfully")
         |> push_navigate(to: ~p"/admin/agencies")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/agencies")}
  end

  # Private functions

  defp field_description(field) do
    case field do
      :code -> "Agency code used throughout the application (choose: hse, onr, orr, ea)"
      :name -> "Display name for this enforcement agency"
      :base_url -> "Base URL for this agency's enforcement data source"
      :enabled -> "Whether this agency should be active in the system"
      _ -> ""
    end
  end

  defp field_display_name(field) do
    case field do
      :code -> "Code"
      :name -> "Name"
      :base_url -> "Base URL"
      :enabled -> "Enabled"
      _ -> to_string(field)
    end
  end
end
