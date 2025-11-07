defmodule EhsEnforcementWeb.NoticeLive.Show do
  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :loading, true)}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    if connected?(socket) do
      :ok = PubSub.subscribe(EhsEnforcement.PubSub, "notice:#{id}")
    end

    case Enforcement.get_notice(id, load: [:agency, :offender]) do
      {:ok, notice} ->
        {:noreply,
         socket
         |> assign(:page_title, "Notice Details")
         |> assign(:notice, notice)
         |> assign(:related_notices, [])
         |> assign(:compliance_status, calculate_compliance_status(notice))
         |> assign(:timeline_data, build_timeline_data(notice))
         |> assign(:loading, false)}

      {:error, _error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Notice not found")
         |> push_navigate(to: ~p"/notices")}
    end
  rescue
    error ->
      require Logger
      Logger.error("Failed to load notice #{id}: #{inspect(error)}")

      {:noreply,
       socket
       |> put_flash(:error, "Notice not found")
       |> push_navigate(to: ~p"/notices")}
  end

  @impl true
  def handle_event("export", %{"format" => _format}, socket) do
    # TODO: Implement export functionality
    {:noreply, put_flash(socket, :info, "Export functionality coming soon")}
  end

  @impl true
  def handle_event("share", _params, socket) do
    # TODO: Implement share functionality
    {:noreply, put_flash(socket, :info, "Share functionality coming soon")}
  end

  @impl true
  def handle_info({:notice_updated, notice}, socket) do
    {:noreply,
     socket
     |> assign(:notice, notice)
     |> assign(:compliance_status, calculate_compliance_status(notice))
     |> assign(:timeline_data, build_timeline_data(notice))
     |> put_flash(:info, "Notice updated")}
  end

  # Private functions

  defp calculate_compliance_status(notice) do
    today = Date.utc_today()

    cond do
      is_nil(notice.compliance_date) ->
        %{
          status: "N/A",
          class: "text-gray-600",
          badge_class: "bg-gray-100 text-gray-800",
          days_remaining: nil,
          days_overdue: nil
        }

      notice.compliance_date && Date.compare(notice.compliance_date, today) == :gt ->
        days_remaining = Date.diff(notice.compliance_date, today)

        status =
          cond do
            days_remaining <= 7 -> "urgent"
            days_remaining <= 14 -> "immediate"
            true -> "pending"
          end

        %{
          status: status,
          class: status_to_class(status),
          badge_class: status_to_badge_class(status),
          days_remaining: days_remaining,
          days_overdue: nil
        }

      true ->
        days_overdue = Date.diff(today, notice.compliance_date)

        %{
          status: "overdue",
          class: "text-red-600",
          badge_class: "bg-red-100 text-red-800",
          days_remaining: nil,
          days_overdue: days_overdue
        }
    end
  end

  defp status_to_class("urgent"), do: "text-orange-600"
  defp status_to_class("immediate"), do: "text-yellow-600"
  defp status_to_class("pending"), do: "text-green-600"
  defp status_to_class(_), do: "text-gray-600"

  defp status_to_badge_class("urgent"), do: "bg-orange-100 text-orange-800"
  defp status_to_badge_class("immediate"), do: "bg-yellow-100 text-yellow-800"
  defp status_to_badge_class("pending"), do: "bg-green-100 text-green-800"
  defp status_to_badge_class(_), do: "bg-gray-100 text-gray-800"

  defp build_timeline_data(notice) do
    today = Date.utc_today()

    timeline = [
      %{
        date: notice.notice_date,
        label: "Notice Issued",
        status:
          if(notice.notice_date && Date.compare(today, notice.notice_date) != :lt,
            do: "completed",
            else: "future"
          ),
        description: "Notice #{notice.regulator_id} issued"
      }
    ]

    timeline =
      if notice.operative_date do
        timeline ++
          [
            %{
              date: notice.operative_date,
              label: "Operative Date",
              status:
                if(notice.operative_date && Date.compare(today, notice.operative_date) != :lt,
                  do: "completed",
                  else: "future"
                ),
              description: "Notice becomes legally enforceable"
            }
          ]
      else
        timeline
      end

    timeline =
      if notice.compliance_date do
        timeline ++
          [
            %{
              date: notice.compliance_date,
              label: "Compliance Due",
              status:
                if(notice.compliance_date && Date.compare(today, notice.compliance_date) != :lt,
                  do: "completed",
                  else: "future"
                ),
              description: "All required actions must be completed"
            }
          ]
      else
        timeline
      end

    timeline
  end

  defp format_date(nil), do: ""
  defp format_date(date), do: Calendar.strftime(date, "%B %d, %Y")

  defp format_short_date(nil), do: ""
  defp format_short_date(date), do: Calendar.strftime(date, "%d %b %Y")

  defp days_between(nil, _), do: nil
  defp days_between(_, nil), do: nil
  defp days_between(date1, date2), do: Date.diff(date2, date1)

  defp notice_type_class(type) do
    case type do
      "Improvement Notice" -> "bg-yellow-100 text-yellow-800"
      "Prohibition Notice" -> "bg-red-100 text-red-800"
      "Enforcement Notice" -> "bg-blue-100 text-blue-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp timeline_status_class("completed"), do: "bg-green-500"
  defp timeline_status_class("current"), do: "bg-blue-500"
  defp timeline_status_class(_), do: "bg-gray-300"

  defp format_notice_body(nil), do: []

  defp format_notice_body(body) do
    body
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
