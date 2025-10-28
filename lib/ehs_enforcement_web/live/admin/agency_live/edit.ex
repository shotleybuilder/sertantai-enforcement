defmodule EhsEnforcementWeb.Admin.AgencyLive.Edit do
  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement.Agency

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Ash.get(Agency, id) do
      {:ok, agency} ->
        form = AshPhoenix.Form.for_update(agency, :update, forms: [auto?: false]) |> to_form()

        {:ok,
         socket
         |> assign(:agency, agency)
         |> assign(:form, form)
         |> assign(:page_title, "Edit Agency")
         |> assign(:loading, false)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Agency not found")
         |> push_navigate(to: ~p"/admin/agencies")}
    end
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
         |> put_flash(:info, "Agency #{agency.name} updated successfully")
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

  defp format_datetime(datetime) when is_struct(datetime, NaiveDateTime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  defp format_datetime(_), do: "—"

  defp field_description(field) do
    case field do
      :id -> "Unique identifier for this agency (system generated)"
      :code -> "Agency code used throughout the application (cannot be changed)"
      :name -> "Display name for this enforcement agency"
      :base_url -> "Base URL for this agency's enforcement data source"
      :enabled -> "Whether this agency is currently active in the system"
      :inserted_at -> "When this agency record was created (system managed)"
      :updated_at -> "When this agency record was last modified (system managed)"
      _ -> ""
    end
  end

  defp field_display_name(field) do
    case field do
      :id -> "ID"
      :code -> "Code"
      :name -> "Name"
      :base_url -> "Base URL"
      :enabled -> "Enabled"
      :inserted_at -> "Created At"
      :updated_at -> "Updated At"
      _ -> to_string(field)
    end
  end
end
