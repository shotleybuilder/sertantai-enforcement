defmodule EhsEnforcementWeb.Admin.NoticeLive.Edit do
  use EhsEnforcementWeb, :live_view
  
  alias EhsEnforcement.Enforcement.Notice

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Ash.get(Notice, id, actor: socket.assigns.current_user, load: [:agency, :offender]) do
      {:ok, notice_record} ->
        form = AshPhoenix.Form.for_update(notice_record, :update, forms: [auto?: false]) |> to_form()
        
        {:ok,
         socket
         |> assign(:notice, notice_record)
         |> assign(:form, form)
         |> assign(:page_title, "Edit Notice")
         |> assign(:loading, false)}
      
      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Notice not found")
         |> push_navigate(to: ~p"/notices")}
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
      {:ok, notice_record} ->
        {:noreply,
         socket
         |> put_flash(:info, "Notice #{notice_record.regulator_id} updated successfully")
         |> push_navigate(to: ~p"/notices")}
      
      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/notices")}
  end

  # Private functions

  defp format_datetime(datetime) when is_struct(datetime, NaiveDateTime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
  defp format_datetime(datetime) when is_struct(datetime, DateTime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
  defp format_datetime(_), do: "—"

  defp format_date(date) when is_struct(date, Date) do
    Calendar.strftime(date, "%Y-%m-%d")
  end
  defp format_date(_), do: ""

  defp field_description(field) do
    case field do
      :id -> "Unique identifier for this notice (system generated)"
      :regulator_id -> "Notice reference from the regulatory agency"
      :regulator_ref_number -> "Additional reference number from regulator"
      :notice_date -> "Date when the notice was issued"
      :operative_date -> "Date when the notice becomes operative"
      :compliance_date -> "Date by which compliance must be achieved"
      :notice_body -> "Full text content of the notice"
      :offence_action_type -> "Type of enforcement action (e.g., improvement notice, prohibition notice)"
      :offence_action_date -> "Date when the enforcement action was taken"
      :offence_breaches -> "Description of the regulatory breaches"
      :url -> "Direct URL to notice details on agency website"
      :airtable_id -> "Legacy Airtable record ID (system managed)"
      :agency_id -> "Associated enforcement agency (cannot be changed)"
      :offender_id -> "Associated offender (cannot be changed)"
      :inserted_at -> "When this notice record was created (system managed)"
      :updated_at -> "When this notice record was last modified (system managed)"
      :last_synced_at -> "Last sync with external systems (system managed)"
      _ -> ""
    end
  end

  defp field_display_name(field) do
    case field do
      :id -> "ID"
      :regulator_id -> "Regulator ID"
      :regulator_ref_number -> "Reference Number"
      :notice_date -> "Notice Date"
      :operative_date -> "Operative Date"
      :compliance_date -> "Compliance Date"
      :notice_body -> "Notice Body"
      :offence_action_type -> "Action Type"
      :offence_action_date -> "Action Date"
      :offence_breaches -> "Breaches"
      :url -> "URL"
      :airtable_id -> "Airtable ID"
      :agency_id -> "Agency"
      :offender_id -> "Offender"
      :inserted_at -> "Created At"
      :updated_at -> "Updated At"
      :last_synced_at -> "Last Synced"
      _ -> field |> to_string() |> String.replace("_", " ") |> String.capitalize()
    end
  end

  defp field_editable?(field) do
    case field do
      # Non-editable system fields
      :id -> false
      :airtable_id -> false
      :agency_id -> false
      :offender_id -> false
      :inserted_at -> false
      :updated_at -> false
      :last_synced_at -> false
      # All other fields are editable
      _ -> true
    end
  end

  defp field_type(field) do
    case field do
      f when f in [:notice_date, :operative_date, :compliance_date, :offence_action_date] -> :date
      f when f in [:notice_body, :offence_breaches] -> :textarea
      f when f in [:offence_action_type] -> :select
      _ -> :text
    end
  end

  defp select_options(field) do
    case field do
      :offence_action_type -> [
        {"Improvement Notice", "Improvement Notice"},
        {"Prohibition Notice", "Prohibition Notice"},
        {"Enforcement Notice", "Enforcement Notice"},
        {"Formal Caution", "Formal Caution"},
        {"Simple Caution", "Simple Caution"},
        {"Court Case", "Court Case"},
        {"Caution", "Caution"}
      ]
      _ -> []
    end
  end
end