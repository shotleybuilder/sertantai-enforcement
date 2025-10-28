defmodule EhsEnforcementWeb.Admin.CaseLive.Edit do
  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement.Case

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Ash.get(Case, id, actor: socket.assigns.current_user, load: [:agency, :offender]) do
      {:ok, case_record} ->
        form =
          AshPhoenix.Form.for_update(case_record, :update, forms: [auto?: false]) |> to_form()

        {:ok,
         socket
         |> assign(:case, case_record)
         |> assign(:form, form)
         |> assign(:page_title, "Edit Case")
         |> assign(:loading, false)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Case not found")
         |> push_navigate(to: ~p"/admin/cases")}
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
      {:ok, case_record} ->
        {:noreply,
         socket
         |> put_flash(:info, "Case #{case_record.regulator_id} updated successfully")
         |> push_navigate(to: ~p"/admin/cases")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/cases")}
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
      :id -> "Unique identifier for this case (system generated)"
      :regulator_id -> "Case reference from the regulatory agency"
      :offence_result -> "Outcome of the enforcement action"
      :offence_fine -> "Fine amount imposed (in GBP)"
      :offence_costs -> "Legal costs awarded (in GBP)"
      :offence_action_date -> "Date when the enforcement action was taken"
      :offence_hearing_date -> "Date of any court hearing"
      :offence_breaches -> "Description of the regulatory breaches"
      :offence_breaches_clean -> "Cleaned version of breach description"
      :regulator_function -> "Regulatory function under which action was taken"
      :regulator_url -> "URL to case details on agency website"
      :related_cases -> "References to related enforcement cases"
      :offence_action_type -> "Type of enforcement action (e.g., court case, caution)"
      :url -> "Direct URL to case details"
      :airtable_id -> "Legacy Airtable record ID (system managed)"
      :agency_id -> "Associated enforcement agency (cannot be changed)"
      :offender_id -> "Associated offender (cannot be changed)"
      :inserted_at -> "When this case record was created (system managed)"
      :updated_at -> "When this case record was last modified (system managed)"
      :last_synced_at -> "Last sync with external systems (system managed)"
      # EA-specific fields
      :ea_event_reference -> "Environment Agency event reference number"
      :ea_total_violation_count -> "Number of violations in this EA case"
      :environmental_impact -> "Environmental impact level (none, minor, major)"
      :environmental_receptor -> "Environmental receptor affected (land, water, air)"
      :is_ea_multi_violation -> "Whether this case has multiple distinct violations"
      _ -> ""
    end
  end

  defp field_display_name(field) do
    case field do
      :id -> "ID"
      :regulator_id -> "Regulator ID"
      :offence_result -> "Offence Result"
      :offence_fine -> "Fine (£)"
      :offence_costs -> "Costs (£)"
      :offence_action_date -> "Action Date"
      :offence_hearing_date -> "Hearing Date"
      :offence_breaches -> "Breaches"
      :offence_breaches_clean -> "Breaches (Clean)"
      :regulator_function -> "Regulator Function"
      :regulator_url -> "Regulator URL"
      :related_cases -> "Related Cases"
      :offence_action_type -> "Action Type"
      :url -> "URL"
      :airtable_id -> "Airtable ID"
      :agency_id -> "Agency"
      :offender_id -> "Offender"
      :inserted_at -> "Created At"
      :updated_at -> "Updated At"
      :last_synced_at -> "Last Synced"
      # EA-specific fields
      :ea_event_reference -> "EA Event Reference"
      :ea_total_violation_count -> "Total Violations"
      :environmental_impact -> "Environmental Impact"
      :environmental_receptor -> "Environmental Receptor"
      :is_ea_multi_violation -> "Multi-Violation"
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
      f when f in [:offence_fine, :offence_costs] -> :decimal
      f when f in [:offence_action_date, :offence_hearing_date] -> :date
      f when f in [:ea_total_violation_count] -> :integer
      f when f in [:is_ea_multi_violation] -> :boolean
      f when f in [:environmental_impact] -> :select
      f when f in [:environmental_receptor] -> :select
      f when f in [:offence_action_type] -> :select
      f when f in [:offence_breaches, :offence_breaches_clean, :regulator_function] -> :textarea
      _ -> :text
    end
  end

  defp select_options(field) do
    case field do
      :environmental_impact ->
        [
          {"None", "none"},
          {"Minor", "minor"},
          {"Major", "major"}
        ]

      :environmental_receptor ->
        [
          {"Land", "land"},
          {"Water", "water"},
          {"Air", "air"}
        ]

      :offence_action_type ->
        [
          {"Court Case", "Court Case"},
          {"Caution", "Caution"},
          {"Enforcement Notice", "Enforcement Notice"},
          {"Prohibition Notice", "Prohibition Notice"},
          {"Improvement Notice", "Improvement Notice"},
          {"Simple Caution", "Simple Caution"},
          {"Formal Caution", "Formal Caution"}
        ]

      _ ->
        []
    end
  end
end
