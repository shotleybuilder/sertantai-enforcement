defmodule EhsEnforcementWeb.EnforcementTimelineComponent do
  use EhsEnforcementWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg">
      <div class="px-6 py-4 border-b border-gray-200">
        <div class="flex justify-between items-center">
          <h3 class="text-lg font-medium text-gray-900">Enforcement Timeline</h3>
          <span class="text-sm text-gray-500">
            {total_actions(@timeline)} enforcement actions
          </span>
        </div>
      </div>

      <div class="p-6">
        <%= if length(@timeline) > 0 do %>
          <div data-role="timeline" role="list" class="space-y-8">
            <%= for {year, actions} <- @timeline do %>
              <div data-year={year} class="relative">
                <!-- Year Header -->
                <div class="relative flex items-center">
                  <div class="flex-shrink-0">
                    <span class="h-8 w-8 rounded-full bg-indigo-500 flex items-center justify-center ring-8 ring-white">
                      <svg class="h-4 w-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                        <path
                          fill-rule="evenodd"
                          d="M6 2a1 1 0 00-1 1v1H4a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-1V3a1 1 0 10-2 0v1H7V3a1 1 0 00-1-1zm0 5a1 1 0 000 2h8a1 1 0 100-2H6z"
                          clip-rule="evenodd"
                        />
                      </svg>
                    </span>
                  </div>
                  <div class="ml-4">
                    <h4 class="text-lg font-medium text-gray-900">{year}</h4>
                    <p class="text-sm text-gray-500">
                      {length(actions)} enforcement actions in {year}
                    </p>
                  </div>
                </div>
                
    <!-- Timeline Items -->
                <div class="ml-4 pl-8 border-l border-gray-200 space-y-6 mt-4">
                  <%= for action <- actions do %>
                    {render_timeline_item(assigns, action)}
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-8">
            <svg
              class="mx-auto h-12 w-12 text-gray-400"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
              />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No enforcement actions</h3>
            <p class="mt-1 text-sm text-gray-500">No enforcement history available.</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_timeline_item(assigns, action) do
    case action.action_type do
      :case -> render_case_item(assigns, action)
      :notice -> render_notice_item(assigns, action)
    end
  end

  defp render_case_item(assigns, case_action) do
    assigns = assign(assigns, :case_action, case_action)

    ~H"""
    <div
      data-role="timeline-item"
      role="listitem"
      tabindex="0"
      class="relative bg-red-50 p-4 rounded-lg border border-red-200 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-red-500"
    >
      <div class="flex justify-between items-start">
        <div class="flex-1">
          <div class="flex items-center">
            <svg class="h-5 w-5 text-red-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path
                fill-rule="evenodd"
                d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
                clip-rule="evenodd"
              />
            </svg>
            <div class="text-sm font-medium text-gray-900">
              Enforcement Case: {@case_action.regulator_id}
            </div>
          </div>

          <div class="mt-1 text-xs text-gray-500">
            Action Date: {Date.to_string(@case_action.offence_action_date)}
          </div>

          <%= if @case_action.offence_breaches do %>
            <div class="mt-2 text-sm text-gray-700">
              <strong>Breach:</strong> {@case_action.offence_breaches}
            </div>
          <% end %>
        </div>

        <div class="text-right ml-4">
          <div class="text-lg font-bold text-red-600">
            {format_currency(@case_action.offence_fine)}
          </div>
          <%= if @case_action.agency do %>
            <div class="text-xs text-gray-500 mt-1">
              {get_agency_name(@case_action.agency)}
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_notice_item(assigns, notice_action) do
    assigns = assign(assigns, :notice_action, notice_action)

    ~H"""
    <div
      data-role="timeline-item"
      role="listitem"
      tabindex="0"
      data-notice-id={@notice_action.id}
      class="relative bg-yellow-50 p-4 rounded-lg border border-yellow-200 hover:bg-yellow-100 focus:outline-none focus:ring-2 focus:ring-yellow-500"
    >
      <div class="flex justify-between items-start">
        <div class="flex-1">
          <div class="flex items-center">
            <svg class="h-5 w-5 text-yellow-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path
                fill-rule="evenodd"
                d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
                clip-rule="evenodd"
              />
            </svg>
            <div class="text-sm font-medium text-gray-900">
              {format_notice_type(@notice_action.notice_type)}: {@notice_action.regulator_id}
            </div>
          </div>

          <div class="mt-1 text-xs text-gray-500 space-x-4">
            <span>Notice Date: {Date.to_string(@notice_action.notice_date)}</span>
            <%= if @notice_action.compliance_date do %>
              <span>Compliance Date: {Date.to_string(@notice_action.compliance_date)}</span>
            <% end %>
          </div>

          <%= if @notice_action.compliance_date do %>
            <div class="mt-1 text-xs">
              <span class="text-gray-500">Compliance period: </span>
              <span class="font-medium">
                {Date.diff(@notice_action.compliance_date, @notice_action.notice_date)} days
              </span>
            </div>
          <% end %>

          <%= if @notice_action.notice_body do %>
            <div class="mt-2 text-sm text-gray-700">
              {@notice_action.notice_body}
            </div>
          <% end %>
        </div>

        <div class="text-right ml-4">
          <%= if @notice_action.agency do %>
            <div class="text-xs text-gray-500">
              {get_agency_name(@notice_action.agency)}
            </div>
          <% end %>
          
    <!-- Compliance Status -->
          <div class="mt-2">
            {render_compliance_status(@notice_action)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_compliance_status(notice) do
    if notice.compliance_date do
      if Date.compare(notice.compliance_date, Date.utc_today()) == :lt do
        # Past compliance date
        assigns = %{}

        ~H"""
        <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
          Compliance Status: Completed
        </span>
        """
      else
        # Future compliance date
        days_remaining = Date.diff(notice.compliance_date, Date.utc_today())

        if days_remaining <= 7 do
          assigns = %{days_remaining: days_remaining}

          ~H"""
          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
            Urgent: {@days_remaining} days left
          </span>
          """
        else
          assigns = %{days_remaining: days_remaining}

          ~H"""
          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
            {@days_remaining} days remaining
          </span>
          """
        end
      end
    else
      assigns = %{}

      ~H"""
      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
        No compliance date
      </span>
      """
    end
  end

  defp format_notice_type(nil), do: "Notice"

  defp format_notice_type(type) do
    type
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp total_actions(timeline) do
    Enum.reduce(timeline, 0, fn {_year, actions}, acc ->
      acc + length(actions)
    end)
  end

  defp format_currency(nil), do: "£0"

  defp format_currency(amount) when is_binary(amount) do
    case Decimal.parse(amount) do
      {decimal, _} -> format_currency(decimal)
      :error -> "£0"
    end
  end

  defp format_currency(%Decimal{} = amount) do
    amount
    |> Decimal.to_string()
    |> String.to_integer()
    |> Number.Currency.number_to_currency(unit: "£")
  end

  defp format_currency(amount) when is_integer(amount) do
    Number.Currency.number_to_currency(amount, unit: "£")
  end

  defp get_agency_name(%{name: name}), do: name
  defp get_agency_name(_), do: "Unknown Agency"
end
