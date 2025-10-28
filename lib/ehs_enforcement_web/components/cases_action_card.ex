defmodule EhsEnforcementWeb.Components.CasesActionCard do
  @moduledoc """
  Cases Management action card component for the dashboard.

  Displays cases metrics, provides filtered navigation, and admin-controlled create functionality.
  Implements the cases card specification from the dashboard action cards design document.
  """

  use Phoenix.Component

  import EhsEnforcementWeb.Components.DashboardActionCard
  alias EhsEnforcement.Enforcement

  @doc """
  Renders the Cases Management action card with live metrics and actions.

  ## Examples

      <.cases_action_card current_user={@current_user} stats={@stats} />

  """
  attr :current_user, :map, default: nil, doc: "Current authenticated user"
  attr :stats, :map, required: true, doc: "Pre-computed dashboard statistics from metrics table"
  attr :loading, :boolean, default: false, doc: "Show loading state"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def cases_action_card(assigns) do
    # Use pre-computed metrics from stats
    assigns =
      assigns
      |> assign(:total_cases, Map.get(assigns.stats, :total_cases, 0))
      |> assign(:recent_cases_count, Map.get(assigns.stats, :recent_cases, 0))
      |> assign(:total_recent_fines, Map.get(assigns.stats, :total_fines, Decimal.new(0)))

    ~H"""
    <.dashboard_action_card
      title="ENFORCEMENT CASES"
      icon="⚖️"
      theme="blue"
      loading={@loading}
      class={@class}
    >
      <:metrics>
        <.metric_item
          label="Total Cases"
          value={format_number(@total_cases)}
        />
        <.metric_item
          label="Recent (Last 30 Days)"
          value={format_number(@recent_cases_count)}
        />
        <.metric_item
          label="Total Fines"
          value={format_currency(@total_recent_fines)}
        />
      </:metrics>

      <:actions>
        <.card_action_button phx-click="browse_recent_cases">
          <div class="flex items-center justify-between w-full">
            <span>Browse Recent</span>
            <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </div>
        </.card_action_button>

        <.card_secondary_button phx-click="search_cases">
          <div class="flex items-center justify-between w-full">
            <span>Search</span>
            <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
              />
            </svg>
          </div>
        </.card_secondary_button>
      </:actions>
    </.dashboard_action_card>
    """
  end

  # Private helper functions

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> format_number_string()
  end

  defp format_number(number) when is_binary(number) do
    format_number_string(number)
  end

  defp format_number(_), do: "0"

  defp format_number_string(number_str) do
    number_str
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp format_currency(amount) when is_struct(amount, Decimal) do
    amount
    |> Decimal.to_string()
    |> String.to_float()
    |> :erlang.float_to_binary([{:decimals, 2}])
    |> then(&"£#{format_number_string(&1)}")
  rescue
    _ -> "£0.00"
  end

  defp format_currency(_), do: "£0.00"
end
