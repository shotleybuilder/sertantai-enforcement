defmodule EhsEnforcementWeb.CaseLive.Show do
  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to real-time updates for this case
    Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case_updates")
    
    {:ok, 
     socket
     |> assign(:case, nil)
     |> assign(:loading, true)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    try do
      # Load case with all related data
      case = Enforcement.get_case!(id, load: [:offender, :agency, :computed_breaches_summary])
      
      # Subscribe to updates for this specific case
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case:#{id}")
      
      {:noreply,
       socket
       |> assign(:case, case)
       |> assign(:loading, false)
       |> assign(:error, nil)
       |> assign(:page_title, "Case #{case.regulator_id}")}
      
    rescue
      Ash.Error.Query.NotFound ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error, :not_found)
         |> put_flash(:error, "Case not found")}
      
      error ->
        require Logger
        Logger.error("Failed to load case #{id}: #{inspect(error)}")
        
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error, :server_error)
         |> put_flash(:error, "Unable to load case details")}
    end
  end

  @impl true
  def handle_event("delete_case", _params, socket) do
    case socket.assigns.case do
      nil ->
        {:noreply, socket}
      
      case_record ->
        try do
          Enforcement.destroy_case!(case_record)
          
          {:noreply,
           socket
           |> put_flash(:info, "Case deleted successfully")
           |> push_navigate(to: ~p"/cases")}
          
        rescue
          error ->
            require Logger
            Logger.error("Failed to delete case: #{inspect(error)}")
            
            {:noreply,
             socket
             |> put_flash(:error, "Unable to delete case")}
        end
    end
  end

  @impl true
  def handle_event("export_case", _params, socket) do
    case socket.assigns.case do
      nil ->
        {:noreply, socket}
      
      case_record ->
        # Generate CSV data for single case
        csv_data = generate_case_csv(case_record)
        filename = "case_#{case_record.regulator_id}_#{Date.to_string(Date.utc_today())}.csv"
        
        {:noreply,
         socket
         |> push_event("download", %{
           filename: filename,
           content: csv_data,
           mime_type: "text/csv"
         })}
    end
  end

  @impl true
  def handle_event("share_case", %{"method" => method}, socket) do
    case socket.assigns.case do
      nil ->
        {:noreply, socket}
      
      case_record ->
        case method do
          "url" ->
            case_url = url(socket, ~p"/cases/#{case_record.id}")
            
            {:noreply,
             socket
             |> push_event("copy_to_clipboard", %{text: case_url})
             |> put_flash(:info, "Case URL copied to clipboard")}
          
          "email" ->
            subject = "EHS Enforcement Case: #{case_record.regulator_id}"
            body = generate_case_summary(case_record)
            mailto_url = "mailto:?subject=#{URI.encode(subject)}&body=#{URI.encode(body)}"
            
            {:noreply,
             socket
             |> push_event("open_url", %{url: mailto_url})}
          
          _ ->
            {:noreply, socket}
        end
    end
  end

  # Handle real-time updates
  @impl true
  def handle_info({:case_updated, updated_case}, socket) do
    if socket.assigns.case && socket.assigns.case.id == updated_case.id do
      # Reload the case with full associations
      try do
        refreshed_case = Enforcement.get_case!(updated_case.id, load: [:offender, :agency, :computed_breaches_summary])
        {:noreply, assign(socket, :case, refreshed_case)}
      rescue
        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:case_deleted, deleted_case}, socket) do
    if socket.assigns.case && socket.assigns.case.id == deleted_case.id do
      {:noreply,
       socket
       |> put_flash(:info, "This case has been deleted")
       |> push_navigate(to: ~p"/cases")}
    else
      {:noreply, socket}
    end
  end

  # Notice handlers removed - there is no direct case-notice relationship
  # Notices belong to agency and offender, not directly to cases

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  # Private helper functions

  defp generate_case_csv(case_record) do
    headers = [
      "Regulator ID",
      "Agency",
      "Offender Name", 
      "Local Authority",
      "Postcode",
      "Offense Date",
      "Fine Amount",
      "Offense Breaches",
      "Notices Count",
      "Breaches Count",
      "Last Synced"
    ]

    data = [
      case_record.regulator_id,
      case_record.agency.name,
      case_record.offender.name,
      case_record.offender.local_authority || "",
      case_record.offender.postcode || "",
      format_date(case_record.offence_action_date),
      format_currency_for_csv(case_record.offence_fine),
      escape_csv_field(case_record.offence_breaches || ""),
      0, # notice count (no direct case-notice relationship)
      length(case_record.breaches || []),
      format_datetime(case_record.last_synced_at)
    ]

    [headers, data]
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end

  defp generate_case_summary(case_record) do
    """
    EHS Enforcement Case Summary
    
    Case ID: #{case_record.regulator_id}
    Agency: #{case_record.agency.name}
    Offender: #{case_record.offender.name}
    Date: #{format_date(case_record.offence_action_date)}
    Fine: #{format_currency(case_record.offence_fine)}
    
    Offense Details:
    #{case_record.offence_breaches || "N/A"}
    
    View full details: #{url(~p"/cases/#{case_record.id}")}
    """
  end

  defp format_currency(amount) when is_struct(amount, Decimal) do
    amount
    |> Decimal.to_float()
    |> :erlang.float_to_binary([{:decimals, 2}])
    |> then(&"£#{format_number(&1)}")
  end

  defp format_currency(_), do: "£0.00"

  defp format_currency_for_csv(amount) when is_struct(amount, Decimal) do
    amount
    |> Decimal.to_string()
    |> String.to_float()
    |> :erlang.float_to_binary([{:decimals, 2}])
  end

  defp format_currency_for_csv(_), do: "0.00"

  defp format_number(number_str) do
    number_str
    |> String.split(".")
    |> case do
      [integer_part, decimal_part] ->
        formatted_integer = integer_part
        |> String.reverse()
        |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
        |> String.reverse()
        
        "#{formatted_integer}.#{decimal_part}"
      
      [integer_part] ->
        integer_part
        |> String.reverse()
        |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
        |> String.reverse()
    end
  end

  defp format_date(date) when is_struct(date, Date) do
    Calendar.strftime(date, "%B %d, %Y")
  end

  defp format_date(_), do: ""

  defp format_datetime(datetime) when is_struct(datetime, DateTime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_datetime(_), do: ""

  defp escape_csv_field(field) do
    if String.contains?(field, [",", "\"", "\n", "\r"]) do
      "\"#{String.replace(field, "\"", "\"\"")}\""
    else
      field
    end
  end

  defp format_compliance_status("complied"), do: "Complied"
  defp format_compliance_status("pending"), do: "Pending"
  defp format_compliance_status("overdue"), do: "Overdue"
  defp format_compliance_status("not_applicable"), do: "Not Applicable"
  defp format_compliance_status(status) when is_binary(status), do: String.capitalize(status)
  defp format_compliance_status(_), do: "Unknown"

  defp format_notice_type("improvement"), do: "Improvement Notice"
  defp format_notice_type("prohibition"), do: "Prohibition Notice"
  defp format_notice_type("prosecution"), do: "Prosecution Notice"
  defp format_notice_type(type) when is_binary(type), do: String.capitalize(type)
  defp format_notice_type(_), do: "Unknown"

  defp format_severity("high"), do: "High"
  defp format_severity("medium"), do: "Medium"
  defp format_severity("low"), do: "Low"
  defp format_severity(severity) when is_binary(severity), do: String.capitalize(severity)
  defp format_severity(_), do: "Unknown"

  defp compliance_status_class("complied"), do: "text-green-600 bg-green-100"
  defp compliance_status_class("pending"), do: "text-yellow-600 bg-yellow-100"
  defp compliance_status_class("overdue"), do: "text-red-600 bg-red-100"
  defp compliance_status_class(_), do: "text-gray-600 bg-gray-100"

  defp severity_class("high"), do: "text-red-600 bg-red-100"
  defp severity_class("medium"), do: "text-yellow-600 bg-yellow-100"
  defp severity_class("low"), do: "text-green-600 bg-green-100"
  defp severity_class(_), do: "text-gray-600 bg-gray-100"

  defp build_case_timeline(case_record) do
    events = []
    
    # Add case creation event
    events = [%{
      type: :case_created,
      date: case_record.offence_action_date,
      title: "Enforcement Action",
      description: "Case #{case_record.regulator_id} created",
      icon: "gavel"
    } | events]
    
    # Add hearing date event if present
    events = if case_record.offence_hearing_date do
      [%{
        type: :hearing_scheduled,
        date: case_record.offence_hearing_date,
        title: "Court Hearing",
        description: "Hearing scheduled for #{case_record.regulator_id}",
        icon: "calendar"
      } | events]
    else
      events
    end
    
    # Add breach events from loaded breaches
    breach_events = (case_record.breaches || [])
    |> Enum.map(fn breach ->
      %{
        type: :breach_identified,
        date: case_record.offence_action_date, # Use case date as breach discovery date
        title: "Breach Identified",
        description: breach.breach_description,
        icon: "exclamation-triangle"
      }
    end)
    
    events = events ++ breach_events
    
    # Sort by date descending (handle nil dates)
    Enum.sort_by(events, fn event -> 
      event.date || ~D[1900-01-01]
    end, {:desc, Date})
  end
end