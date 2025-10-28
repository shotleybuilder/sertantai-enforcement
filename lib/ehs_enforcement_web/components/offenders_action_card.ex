defmodule EhsEnforcementWeb.Components.OffendersActionCard do
  @moduledoc """
  Offenders Database action card component for the dashboard.

  Displays offender database statistics, provides filtered navigation for top offenders,
  and advanced search functionality. No create functionality - offenders are system-managed.
  Implements the offenders card specification from the dashboard action cards design document.
  """

  use Phoenix.Component

  import EhsEnforcementWeb.Components.DashboardActionCard
  alias EhsEnforcement.Enforcement

  @doc """
  Renders the Offenders Database action card with live metrics and actions.

  ## Examples

      <.offenders_action_card stats={@stats} />

  """
  attr :stats, :map, required: true, doc: "Pre-computed dashboard statistics from metrics table"
  attr :loading, :boolean, default: false, doc: "Show loading state"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def offenders_action_card(assigns) do
    # Use pre-computed metrics from stats
    # Note: Offender-specific metrics not yet in metrics table
    # Using placeholder values until Phase 6 adds offender metrics
    # TODO: Add total_offenders, repeat_offenders, average_fine to metrics table
    assigns =
      assigns
      |> assign(:total_offenders, 0)
      |> assign(:repeat_offenders_count, 0)
      |> assign(:repeat_offenders_percentage, 0.0)
      |> assign(:average_fine, Decimal.new(0))

    ~H"""
    <.dashboard_action_card
      title="OFFENDER DATABASE"
      icon="👥"
      theme="purple"
      loading={@loading}
      class={@class}
    >
      <:metrics>
        <.metric_item
          label="Total Organizations"
          value={format_number(@total_offenders)}
        />
        <.metric_item
          label="Repeat Offenders"
          value={"#{format_number(@repeat_offenders_count)} (#{@repeat_offenders_percentage}%)"}
        />
        <.metric_item
          label="Average Fine"
          value={format_currency(@average_fine)}
        />
      </:metrics>

      <:actions>
        <.card_action_button phx-click="browse_top_offenders">
          <div class="flex items-center justify-between w-full">
            <span>Browse Top 50</span>
            <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </div>
        </.card_action_button>

        <.card_secondary_button phx-click="search_offenders">
          <div class="flex items-center justify-between w-full">
            <span>Search Offenders</span>
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

  defp format_number(number) when is_float(number) do
    number
    |> :erlang.float_to_binary([{:decimals, 1}])
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
