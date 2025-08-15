defmodule EhsEnforcementWeb.Admin.OffenderLive.Edit do
  use EhsEnforcementWeb, :live_view
  
  alias EhsEnforcement.Enforcement.Offender

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Ash.get(Offender, id, actor: socket.assigns.current_user) do
      {:ok, offender_record} ->
        form = AshPhoenix.Form.for_update(offender_record, :update, forms: [auto?: false]) |> to_form()
        
        {:ok,
         socket
         |> assign(:offender, offender_record)
         |> assign(:form, form)
         |> assign(:page_title, "Edit Offender")
         |> assign(:loading, false)}
      
      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Offender not found")
         |> push_navigate(to: ~p"/offenders")}
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
      {:ok, offender_record} ->
        {:noreply,
         socket
         |> put_flash(:info, "Offender #{offender_record.name} updated successfully")
         |> push_navigate(to: ~p"/offenders")}
      
      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/offenders")}
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

  defp format_currency(amount) when is_struct(amount, Decimal) do
    amount
    |> Decimal.to_string(:normal)
    |> String.to_float()
    |> :erlang.float_to_binary(decimals: 2)
    |> then(&"£#{&1}")
  rescue
    _ -> "£0.00"
  end
  defp format_currency(_), do: "£0.00"

  defp field_description(field) do
    case field do
      :id -> "Unique identifier for this offender (system generated)"
      :name -> "Official name of the offender (company or individual)"
      :normalized_name -> "System-normalized name for duplicate detection (system managed)"
      :address -> "Primary address of the offender"
      :local_authority -> "Local authority area where offender is located"
      :country -> "Country of registration or operation"
      :postcode -> "Postal code for the offender's address"
      :main_activity -> "Primary business activity or occupation"
      :sic_code -> "Standard Industrial Classification code"
      :business_type -> "Type of business entity (company, individual, etc.)"
      :industry -> "Industry sector classification"
      :agencies -> "List of enforcement agencies that have taken action (system managed)"
      :company_registration_number -> "Companies House registration number"
      :town -> "Town from structured address data"
      :county -> "County from structured address data"
      :industry_sectors -> "Detailed industry sector classifications"
      :first_seen_date -> "Date of first enforcement action (system calculated)"
      :last_seen_date -> "Date of most recent enforcement action (system calculated)"
      :total_cases -> "Total number of enforcement cases (system calculated)"
      :total_notices -> "Total number of enforcement notices (system calculated)"
      :total_fines -> "Total value of fines imposed (system calculated)"
      :inserted_at -> "When this offender record was created (system managed)"
      :updated_at -> "When this offender record was last modified (system managed)"
      _ -> ""
    end
  end

  defp field_display_name(field) do
    case field do
      :id -> "ID"
      :name -> "Name"
      :normalized_name -> "Normalized Name"
      :address -> "Address"
      :local_authority -> "Local Authority"
      :country -> "Country"
      :postcode -> "Postcode"
      :main_activity -> "Main Activity"
      :sic_code -> "SIC Code"
      :business_type -> "Business Type"
      :industry -> "Industry"
      :agencies -> "Agencies"
      :company_registration_number -> "Company Registration Number"
      :town -> "Town"
      :county -> "County"
      :industry_sectors -> "Industry Sectors"
      :first_seen_date -> "First Seen Date"
      :last_seen_date -> "Last Seen Date"
      :total_cases -> "Total Cases"
      :total_notices -> "Total Notices"
      :total_fines -> "Total Fines"
      :inserted_at -> "Created At"
      :updated_at -> "Updated At"
      _ -> field |> to_string() |> String.replace("_", " ") |> String.capitalize()
    end
  end

  defp field_editable?(field) do
    case field do
      # Non-editable system fields
      :id -> false
      :normalized_name -> false
      :agencies -> false
      :first_seen_date -> false
      :last_seen_date -> false
      :total_cases -> false
      :total_notices -> false
      :total_fines -> false
      :inserted_at -> false
      :updated_at -> false
      # All other fields are editable
      _ -> true
    end
  end

  defp field_type(field) do
    case field do
      f when f in [:first_seen_date, :last_seen_date] -> :date
      f when f in [:address, :main_activity] -> :textarea
      f when f in [:business_type] -> :select
      _ -> :text
    end
  end

  defp select_options(field) do
    case field do
      :business_type -> [
        {"Limited Company", "limited_company"},
        {"Individual", "individual"},
        {"Partnership", "partnership"},
        {"Public Limited Company", "plc"},
        {"Other", "other"}
      ]
      _ -> []
    end
  end
end