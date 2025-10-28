defmodule EhsEnforcementWeb.OffenderCardComponent do
  use EhsEnforcementWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class={[
      "bg-white overflow-hidden shadow rounded-lg border-l-4",
      risk_border_color(@offender)
    ]}>
      <div class="px-4 py-5 sm:p-6">
        <div class="flex items-center justify-between">
          <div class="flex-1 min-w-0">
            <h3 class="text-lg font-medium text-gray-900 truncate">
              {@offender.name}
            </h3>
            <div class="mt-1 flex items-center text-sm text-gray-500">
              <svg
                class="flex-shrink-0 mr-1.5 h-4 w-4 text-gray-400"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z"
                  clip-rule="evenodd"
                />
              </svg>
              {@offender.local_authority}
            </div>
            <%= if @offender.industry do %>
              <div class="mt-1 text-sm text-gray-500">
                <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800">
                  {@offender.industry}
                </span>
              </div>
            <% end %>
          </div>

          <div class="flex-shrink-0 ml-4">
            {render_risk_badge(@offender)}
          </div>
        </div>
        
    <!-- Statistics Grid -->
        <div class="mt-5 grid grid-cols-3 gap-3">
          <div class="text-center">
            <div class="text-2xl font-bold text-gray-900">
              {@offender.total_cases || 0}
            </div>
            <div class="text-xs text-gray-500">Cases</div>
          </div>

          <div class="text-center">
            <div class="text-2xl font-bold text-gray-900">
              {@offender.total_notices || 0}
            </div>
            <div class="text-xs text-gray-500">Notices</div>
          </div>

          <div class="text-center">
            <div class="text-lg font-bold text-gray-900">
              {format_currency_compact(@offender.total_fines)}
            </div>
            <div class="text-xs text-gray-500">Total Fines</div>
          </div>
        </div>
        
    <!-- Repeat Offender Indicator -->
        <%= if is_repeat_offender?(@offender) do %>
          <div class="mt-4 flex items-center justify-center">
            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
              <svg class="-ml-0.5 mr-1.5 h-2 w-2 text-red-400" fill="currentColor" viewBox="0 0 8 8">
                <circle cx="4" cy="4" r="3" />
              </svg>
              Repeat Offender
            </span>
          </div>
        <% end %>
        
    <!-- Action Button -->
        <div class="mt-5">
          <.link
            patch={~p"/offenders/#{@offender.id}"}
            class="w-full flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-indigo-700 bg-indigo-100 hover:bg-indigo-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            View Details
            <svg class="ml-2 -mr-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </.link>
        </div>
        
    <!-- Optional: Last Activity -->
        <%= if @offender.last_seen_date do %>
          <div class="mt-3 text-xs text-gray-500 text-center">
            Last activity: {format_date(@offender.last_seen_date)}
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp is_repeat_offender?(offender) do
    total_enforcement = (offender.total_cases || 0) + (offender.total_notices || 0)
    total_enforcement > 2
  end

  defp risk_border_color(offender) do
    case calculate_risk_level(offender) do
      :high -> "border-red-400"
      :medium -> "border-yellow-400"
      :low -> "border-green-400"
    end
  end

  defp render_risk_badge(offender) do
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

    # Recent activity
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

  defp format_currency_compact(nil), do: "£0"

  defp format_currency_compact(amount) do
    amount_float =
      case amount do
        %Decimal{} ->
          Decimal.to_float(amount)

        binary when is_binary(binary) ->
          case Decimal.parse(binary) do
            {decimal, _} -> Decimal.to_float(decimal)
            :error -> 0
          end

        num when is_number(num) ->
          num

        _ ->
          0
      end

    cond do
      amount_float >= 1_000_000 ->
        "£#{Float.round(amount_float / 1_000_000, 1)}M"

      amount_float >= 1_000 ->
        "£#{Float.round(amount_float / 1_000)}K"

      true ->
        "£#{round(amount_float)}"
    end
  end

  defp format_date(nil), do: "N/A"
  defp format_date(date), do: Date.to_string(date)
end
