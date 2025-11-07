defmodule EhsEnforcementWeb.LegislationLive.Show do
  use EhsEnforcementWeb, :live_view

  require Ash.Query
  import Ash.Expr

  alias EhsEnforcement.Enforcement

  @impl true
  def mount(_params, _session, socket) do
    :ok = Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "legislation_updates")

    {:ok,
     socket
     |> assign(:legislation, nil)
     |> assign(:related_cases, [])
     |> assign(:related_notices, [])
     |> assign(:loading, true)
     |> assign(:error, nil)
     |> assign(:cases_page, 1)
     |> assign(:notices_page, 1)
     |> assign(:page_size, 10)}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    try do
      # Load legislation
      case Enforcement.get_legislation(id, actor: socket.assigns.current_user) do
        {:ok, legislation} ->
          # Load related cases and notices through offences
          {related_cases, related_notices} =
            load_related_data(
              legislation.id,
              socket.assigns.cases_page,
              socket.assigns.notices_page,
              socket.assigns.page_size
            )

          # Subscribe to updates for this specific legislation
          :ok = Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "legislation:#{id}")

          {:noreply,
           socket
           |> assign(:legislation, legislation)
           |> assign(:related_cases, related_cases)
           |> assign(:related_notices, related_notices)
           |> assign(:loading, false)
           |> assign(:error, nil)
           |> assign(:page_title, "#{legislation.legislation_title}")}

        {:error, %Ash.Error.Query.NotFound{}} ->
          {:noreply,
           socket
           |> assign(:loading, false)
           |> assign(:error, :not_found)
           |> put_flash(:error, "Legislation not found")}

        {:error, error} ->
          require Logger
          Logger.error("Failed to load legislation #{id}: #{inspect(error)}")

          {:noreply,
           socket
           |> assign(:loading, false)
           |> assign(:error, :server_error)
           |> put_flash(:error, "Unable to load legislation details")}
      end
    rescue
      error ->
        require Logger
        Logger.error("Failed to load legislation #{id}: #{inspect(error)}")

        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error, :server_error)
         |> put_flash(:error, "Unable to load legislation details")}
    end
  end

  @impl true
  def handle_event("delete_legislation", _params, socket) do
    case socket.assigns.legislation do
      nil ->
        {:noreply, socket}

      legislation_record ->
        try do
          case Ash.destroy(legislation_record, actor: socket.assigns.current_user) do
            :ok ->
              {:noreply,
               socket
               |> put_flash(:info, "Legislation deleted successfully")
               |> push_navigate(to: ~p"/legislation")}

            {:error, error} ->
              require Logger
              Logger.error("Failed to delete legislation: #{inspect(error)}")

              {:noreply,
               socket
               |> put_flash(:error, "Unable to delete legislation")}
          end
        rescue
          error ->
            require Logger
            Logger.error("Failed to delete legislation: #{inspect(error)}")

            {:noreply,
             socket
             |> put_flash(:error, "Unable to delete legislation")}
        end
    end
  end

  @impl true
  def handle_event("paginate_cases", %{"page" => page_str}, socket) do
    case Integer.parse(page_str) do
      {page, _} when page > 0 ->
        {related_cases, _related_notices} =
          load_related_data(
            socket.assigns.legislation.id,
            page,
            socket.assigns.notices_page,
            socket.assigns.page_size
          )

        {:noreply,
         socket
         |> assign(:cases_page, page)
         |> assign(:related_cases, related_cases)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("paginate_notices", %{"page" => page_str}, socket) do
    case Integer.parse(page_str) do
      {page, _} when page > 0 ->
        {_related_cases, related_notices} =
          load_related_data(
            socket.assigns.legislation.id,
            socket.assigns.cases_page,
            page,
            socket.assigns.page_size
          )

        {:noreply,
         socket
         |> assign(:notices_page, page)
         |> assign(:related_notices, related_notices)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("export_legislation", _params, socket) do
    case socket.assigns.legislation do
      nil ->
        {:noreply, socket}

      legislation_record ->
        csv_data =
          generate_legislation_csv(
            legislation_record,
            socket.assigns.related_cases,
            socket.assigns.related_notices
          )

        filename = "legislation_#{legislation_record.id}_#{Date.to_string(Date.utc_today())}.csv"

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
  def handle_event("share_legislation", %{"method" => method}, socket) do
    case socket.assigns.legislation do
      nil ->
        {:noreply, socket}

      legislation_record ->
        case method do
          "url" ->
            legislation_url = url(socket, ~p"/legislation/#{legislation_record.id}")

            {:noreply,
             socket
             |> push_event("copy_to_clipboard", %{text: legislation_url})
             |> put_flash(:info, "Legislation URL copied to clipboard")}

          "email" ->
            subject = "UK Legislation: #{legislation_record.legislation_title}"
            body = generate_legislation_summary(legislation_record)
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
  def handle_info({:legislation_updated, updated_legislation}, socket) do
    if socket.assigns.legislation && socket.assigns.legislation.id == updated_legislation.id do
      {:noreply, assign(socket, :legislation, updated_legislation)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:legislation_deleted, deleted_legislation}, socket) do
    if socket.assigns.legislation && socket.assigns.legislation.id == deleted_legislation.id do
      {:noreply,
       socket
       |> put_flash(:info, "This legislation has been deleted")
       |> push_navigate(to: ~p"/legislation")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  # Private helper functions

  defp load_related_data(legislation_id, cases_page, notices_page, page_size) do
    try do
      # Get offences that reference this legislation
      offences_result = Enforcement.list_offences_by_legislation(legislation_id, actor: nil)

      case offences_result do
        {:ok, offences} ->
          # Extract case and notice IDs from offences
          case_ids =
            offences
            |> Enum.filter(& &1.case_id)
            |> Enum.map(& &1.case_id)
            |> Enum.uniq()

          notice_ids =
            offences
            |> Enum.filter(& &1.notice_id)
            |> Enum.map(& &1.notice_id)
            |> Enum.uniq()

          # Load related cases with pagination
          cases =
            if Enum.empty?(case_ids) do
              []
            else
              case_offset = (cases_page - 1) * page_size

              case_query =
                Enforcement.Case
                |> Ash.Query.filter(expr(id in ^case_ids))
                |> Ash.Query.load([:offender, :agency])
                |> Ash.Query.sort(offence_action_date: :desc)
                |> Ash.Query.offset(case_offset)
                |> Ash.Query.limit(page_size)

              case Ash.read(case_query) do
                {:ok, cases} -> cases
                {:error, _} -> []
              end
            end

          # Load related notices with pagination
          notices =
            if Enum.empty?(notice_ids) do
              []
            else
              notice_offset = (notices_page - 1) * page_size

              notice_query =
                Enforcement.Notice
                |> Ash.Query.filter(expr(id in ^notice_ids))
                |> Ash.Query.load([:offender, :agency])
                |> Ash.Query.sort(offence_action_date: :desc)
                |> Ash.Query.offset(notice_offset)
                |> Ash.Query.limit(page_size)

              case Ash.read(notice_query) do
                {:ok, notices} -> notices
                {:error, _} -> []
              end
            end

          {cases, notices}

        {:error, _} ->
          {[], []}
      end
    rescue
      _error ->
        {[], []}
    end
  end

  defp generate_legislation_csv(legislation, related_cases, related_notices) do
    headers = [
      "Legislation Title",
      "Type",
      "Year",
      "Number",
      "Related Cases Count",
      "Related Notices Count",
      "Created At"
    ]

    data = [
      legislation.legislation_title,
      format_legislation_type(legislation.legislation_type),
      legislation.legislation_year || "",
      legislation.legislation_number || "",
      length(related_cases),
      length(related_notices),
      format_datetime(legislation.created_at)
    ]

    [headers, data]
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end

  defp generate_legislation_summary(legislation) do
    """
    UK Legislation Summary

    Title: #{legislation.legislation_title}
    Type: #{format_legislation_type(legislation.legislation_type)}
    Year: #{legislation.legislation_year || "N/A"}
    Number: #{legislation.legislation_number || "N/A"}

    View full details: #{url(~p"/legislation/#{legislation.id}")}
    """
  end

  defp format_legislation_type(:act), do: "Act"
  defp format_legislation_type(:regulation), do: "Regulation"
  defp format_legislation_type(:order), do: "Order"
  defp format_legislation_type(:acop), do: "ACOP"
  defp format_legislation_type(type) when is_atom(type), do: String.capitalize(to_string(type))
  defp format_legislation_type(_), do: "Unknown"

  defp format_date(date) when is_struct(date, Date) do
    Calendar.strftime(date, "%B %d, %Y")
  end

  defp format_date(_), do: ""

  defp format_datetime(datetime) when is_struct(datetime, DateTime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_datetime(_), do: ""

  defp format_currency(amount) when is_struct(amount, Decimal) do
    amount
    |> Decimal.to_float()
    |> :erlang.float_to_binary([{:decimals, 2}])
    |> then(&"£#{format_number(&1)}")
  end

  defp format_currency(_), do: "£0.00"

  defp format_number(number_str) do
    number_str
    |> String.split(".")
    |> case do
      [integer_part, decimal_part] ->
        formatted_integer =
          integer_part
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

  defp truncate_text(text, max_length) when is_binary(text) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "..."
    else
      text
    end
  end

  defp truncate_text(nil, _), do: ""
  defp truncate_text(text, _) when not is_binary(text), do: ""
end
