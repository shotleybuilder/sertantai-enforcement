defmodule EhsEnforcementWeb.Components.AgencyCard do
  use Phoenix.Component

  def agency_card(assigns) do
    ~H"""
    <div
      class="agency-card bg-white rounded-lg shadow p-6"
      data-testid="agency-card"
      data-agency-code={@agency.code}
    >
      <div class="flex justify-between items-start mb-4">
        <div>
          <h3 class="text-lg font-semibold text-gray-900">{@agency.name}</h3>
          <span class={[
            "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium mt-2",
            @agency.enabled && "bg-green-100 text-green-800",
            !@agency.enabled && "bg-gray-100 text-gray-800"
          ]}>
            {if @agency.enabled, do: "Active", else: "Inactive"}
          </span>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <p class="text-sm text-gray-500">Total Cases</p>
          <p class="text-2xl font-semibold text-gray-900" data-testid={"case-count-#{@agency.code}"}>
            {@stats[:case_count] || 0}
          </p>
        </div>
        <div>
          <p class="text-sm text-gray-500">Percentage</p>
          <p class="text-2xl font-semibold text-gray-900">
            {@stats[:percentage] || 0}%
          </p>
        </div>
      </div>

      <%= if @stats[:last_sync] do %>
        <div class="mt-4 pt-4 border-t border-gray-200">
          <p class="text-sm text-gray-500">
            Last synced: <span class="text-gray-700">{format_datetime(@stats[:last_sync])}</span>
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_datetime(nil), do: "Never"

  defp format_datetime(datetime) do
    # Simple formatting - in production you'd use a proper date formatting library
    case DateTime.from_naive(datetime, "Etc/UTC") do
      {:ok, dt} ->
        "#{dt.day}/#{dt.month}/#{dt.year} #{String.pad_leading(to_string(dt.hour), 2, "0")}:#{String.pad_leading(to_string(dt.minute), 2, "0")}"

      _ ->
        "Invalid date"
    end
  end
end
