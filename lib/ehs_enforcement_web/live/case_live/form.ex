defmodule EhsEnforcementWeb.CaseLive.Form do
  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement

  @impl true
  def mount(_params, _session, socket) do
    # For new case forms, create an AshPhoenix.Form for creation
    form = AshPhoenix.Form.for_create(EhsEnforcement.Enforcement.Case, :create, forms: [auto?: false]) |> to_form()
    
    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:case, nil)  # Explicitly set case to nil for new cases
     |> assign(:agencies, Enforcement.list_agencies!())
     |> assign(:existing_offenders, [])
     |> assign(:selected_offender, nil)
     |> assign(:offender_mode, :select)  # :select or :create
     |> assign(:offender_search_results, [])
     |> assign(:loading, false)
     |> assign(:page_title, "New Case")}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    # Edit mode
    try do
      case_record = Enforcement.get_case!(id, load: [:offender, :agency])
      form = AshPhoenix.Form.for_update(case_record, :update, forms: [auto?: false]) |> to_form()
      
      {:noreply,
       socket
       |> assign(:form, form)
       |> assign(:case, case_record)
       |> assign(:selected_offender, case_record.offender)
       |> assign(:page_title, "Edit Case #{case_record.regulator_id}")}
       
    rescue
      Ash.Error.Query.NotFound ->
        {:noreply,
         socket
         |> put_flash(:error, "Case not found")
         |> push_navigate(to: ~p"/cases")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    # New case mode
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"case" => case_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, case_params) |> to_form()
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"case" => case_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: case_params) do
      {:ok, case_record} ->
        {:noreply,
         socket
         |> put_flash(:info, if(socket.assigns[:case], do: "Case updated successfully", else: "Case created successfully"))
         |> push_navigate(to: ~p"/cases/#{case_record.id}")}
      
      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  @impl true
  def handle_event("search_offenders", %{"query" => query}, socket) do
    if String.length(query) >= 2 do
      search_results = search_offenders(query)
      
      {:noreply,
       socket
       |> assign(:offender_search_results, search_results)
       |> assign(:existing_offenders, search_results)}
    else
      {:noreply,
       socket
       |> assign(:offender_search_results, [])
       |> assign(:existing_offenders, [])}
    end
  end

  @impl true
  def handle_event("select_offender", %{"offender_id" => offender_id}, socket) do
    try do
      offender = Enforcement.get_offender!(offender_id)
      
      {:noreply,
       socket
       |> assign(:selected_offender, offender)
       |> assign(:offender_mode, :select)}
       
    rescue
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_offender_mode", %{"mode" => mode}, socket) do
    offender_mode = case mode do
      "select" -> :select
      "create" -> :create
      "new" -> :create  # Legacy test compatibility
      _ -> :select  # Default fallback for any unexpected input
    end
    
    {:noreply,
     socket
     |> assign(:offender_mode, offender_mode)
     |> assign(:selected_offender, if(offender_mode == :create, do: nil, else: socket.assigns.selected_offender))}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/cases")}
  end

  @impl true
  def handle_event("reset_form", _params, socket) do
    # Reset to a new create form
    form = AshPhoenix.Form.for_create(EhsEnforcement.Enforcement.Case, :create, forms: [auto?: false]) |> to_form()
    
    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:selected_offender, nil)
     |> assign(:offender_mode, :select)
     |> assign(:offender_search_results, [])
     |> assign(:existing_offenders, [])}
  end

  # Private functions

  defp save_case(socket, nil, case_params) do
    # Creating new case
    socket = assign(socket, :loading, true)
    
    try do
      case_attrs = prepare_case_attrs(case_params, socket.assigns.selected_offender, socket.assigns.offender_mode)
      
      case Enforcement.create_case(case_attrs) do
        {:ok, case_record} ->
          {:noreply,
           socket
           |> assign(:loading, false)
           |> put_flash(:info, "Case created successfully")
           |> push_navigate(to: ~p"/cases/#{case_record.id}")}
        
        {:error, error} ->
          require Logger
          Logger.error("Failed to create case: #{inspect(error)}")
          
          {:noreply,
           socket
           |> assign(:loading, false)
           |> put_flash(:error, "Failed to create case")}
      end
      
    rescue
      error ->
        require Logger
        Logger.error("Failed to create case: #{inspect(error)}")
        
        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, "Failed to create case. Please try again.")}
    end
  end

  defp save_case(socket, case_record, case_params) do
    # Updating existing case
    socket = assign(socket, :loading, true)
    
    try do
      case_attrs = prepare_case_attrs(case_params, socket.assigns.selected_offender, socket.assigns.offender_mode)
      
      case Enforcement.update_case(case_record, case_attrs) do
        {:ok, updated_case} ->
          {:noreply,
           socket
           |> assign(:loading, false)
           |> put_flash(:info, "Case updated successfully")
           |> push_navigate(to: ~p"/cases/#{updated_case.id}")}
        
        {:error, error} ->
          require Logger
          Logger.error("Failed to update case: #{inspect(error)}")
          
          {:noreply,
           socket
           |> assign(:loading, false)
           |> put_flash(:error, "Failed to update case")}
      end
      
    rescue
      error ->
        require Logger
        Logger.error("Failed to update case: #{inspect(error)}")
        
        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, "Failed to update case. Please try again.")}
    end
  end

  defp prepare_case_attrs(case_params, selected_offender, offender_mode) do
    base_attrs = %{
      regulator_id: case_params["regulator_id"],
      agency_id: case_params["agency_id"],
      offence_action_date: parse_date(case_params["offence_action_date"]),
      offence_fine: parse_decimal(case_params["offence_fine"]),
      offence_breaches: case_params["offence_breaches"],
      last_synced_at: DateTime.utc_now()
    }

    case {offender_mode, selected_offender} do
      {:select, %{id: offender_id}} ->
        Map.put(base_attrs, :offender_id, offender_id)
      
      {:create, _} ->
        offender_attrs = %{
          name: case_params["offender_name"],
          local_authority: case_params["offender_local_authority"],
          postcode: case_params["offender_postcode"]
        }
        
        # Use the agency_code + offender_attrs pattern from the tests
        agency_code = get_agency_code(case_params["agency_id"])
        
        base_attrs
        |> Map.delete(:agency_id)
        |> Map.put(:agency_code, agency_code)
        |> Map.put(:offender_attrs, offender_attrs)
      
      _ ->
        base_attrs
    end
  end

  defp search_offenders(query) do
    try do
      Enforcement.list_offenders!([
        filter: [name: [ilike: "%#{query}%"]],
        sort: [name: :asc],
        page: [limit: 10]
      ])
    rescue
      _ -> []
    end
  end

  defp get_agency_code(agency_id) do
    try do
      agency = Enforcement.get_agency!(agency_id)
      agency.code
    rescue
      _ -> :hse  # Default fallback
    end
  end

  defp parse_date(""), do: nil
  defp parse_date(nil), do: nil
  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_decimal(""), do: Decimal.new("0.00")
  defp parse_decimal(nil), do: Decimal.new("0.00")
  defp parse_decimal(decimal_string) when is_binary(decimal_string) do
    case Decimal.parse(decimal_string) do
      {decimal, _} -> decimal
      :error -> Decimal.new("0.00")
    end
  end

  # Unused functions commented out:
  # defp format_currency_input(amount) when is_struct(amount, Decimal) do
  #   Decimal.to_string(amount)
  # end
  # defp format_currency_input(_), do: ""
  # defp format_date_input(date) when is_struct(date, Date) do
  #   Date.to_iso8601(date)
  # end
  # defp format_date_input(_), do: ""
end