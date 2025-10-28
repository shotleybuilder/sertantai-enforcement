defmodule EhsEnforcementWeb.OffenderTableComponent do
  use EhsEnforcementWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white shadow overflow-hidden sm:rounded-md">
      <table role="table" class="min-w-full divide-y divide-gray-200">
        <thead role="rowgroup" class="bg-gray-50">
          <tr>
            <th
              scope="col"
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >
              Offender
            </th>
            <th
              scope="col"
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >
              Location & Industry
            </th>
            <th
              scope="col"
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >
              Enforcement Statistics
            </th>
            <th
              scope="col"
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >
              Risk Level
            </th>
            <th scope="col" class="relative px-6 py-3">
              <span class="sr-only">Actions</span>
            </th>
          </tr>
        </thead>
        <tbody role="rowgroup" class="bg-white divide-y divide-gray-200">
          <%= for offender <- @offenders do %>
            <tr
              data-role="offender-row"
              data-offender-id={offender.id}
              data-repeat-offender={is_repeat_offender?(offender)}
              class="hover:bg-gray-50"
            >
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center">
                  <div>
                    <div class="text-sm font-medium text-gray-900">
                      {offender.name}
                      <%= if is_repeat_offender?(offender) do %>
                        <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                          Repeat Offender
                        </span>
                      <% end %>
                    </div>
                    <div class="text-sm text-gray-500">
                      {offender.postcode}
                    </div>
                  </div>
                </div>
              </td>

              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm text-gray-900">
                  {offender.local_authority}
                </div>
                <div class="text-sm text-gray-500">
                  {offender.industry}
                </div>
              </td>

              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm text-gray-900">
                  <span class="font-medium"><%= offender.total_cases || 0 %> Cases</span>,
                  <span class="font-medium">{offender.total_notices || 0} Notices</span>
                </div>
                <div class="text-sm text-gray-500">
                  Total Fines:
                  <span class="font-medium">{format_currency(offender.total_fines)}</span>
                </div>
              </td>

              <td class="px-6 py-4 whitespace-nowrap">
                {render_risk_indicator(offender)}
              </td>

              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <.link
                  patch={~p"/offenders/#{offender.id}"}
                  tabindex="0"
                  class="text-indigo-600 hover:text-indigo-900"
                >
                  View Details
                </.link>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp is_repeat_offender?(offender) do
    total_enforcement = (offender.total_cases || 0) + (offender.total_notices || 0)
    total_enforcement > 2
  end

  defp render_risk_indicator(offender) do
    risk_level = calculate_risk_level(offender)

    case risk_level do
      :high ->
        assigns = %{}

        ~H"""
        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
          High Risk
        </span>
        """

      :medium ->
        assigns = %{}

        ~H"""
        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
          Medium Risk
        </span>
        """

      :low ->
        assigns = %{}

        ~H"""
        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
          Low Risk
        </span>
        """
    end
  end

  defp calculate_risk_level(offender) do
    total_cases = offender.total_cases || 0
    total_notices = offender.total_notices || 0
    total_fines = Decimal.to_float(offender.total_fines || Decimal.new(0))

    # Simple risk calculation
    risk_score = 0

    # Multiple violations
    risk_score = if total_cases + total_notices > 5, do: risk_score + 30, else: risk_score

    # High fines
    risk_score = if total_fines > 100_000, do: risk_score + 25, else: risk_score

    # Recent activity (placeholder - would need last_seen_date)
    risk_score =
      if offender.last_seen_date do
        days_since = Date.diff(Date.utc_today(), offender.last_seen_date)
        if days_since < 365, do: risk_score + 20, else: risk_score
      else
        risk_score
      end

    cond do
      risk_score >= 50 -> :high
      risk_score >= 25 -> :medium
      true -> :low
    end
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
end
