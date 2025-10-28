defmodule EhsEnforcementWeb.Components.LegislationActionCard do
  @moduledoc """
  Legislation action card component for the dashboard.
  """

  use Phoenix.Component

  import EhsEnforcementWeb.Components.DashboardActionCard

  @doc """
  Renders a legislation action card with quick statistics and action buttons.
  """
  attr :total_legislation, :integer, default: 0, doc: "Total legislation count"
  attr :acts_count, :integer, default: 0, doc: "Acts count"
  attr :regulations_count, :integer, default: 0, doc: "Regulations count"
  attr :orders_count, :integer, default: 0, doc: "Orders count"
  attr :acops_count, :integer, default: 0, doc: "ACOPs count"
  attr :loading, :boolean, default: false, doc: "Show loading state"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def legislation_action_card(assigns) do
    ~H"""
    <.dashboard_action_card
      title="LEGISLATION DATABASE"
      icon="🪶"
      theme="purple"
      loading={@loading}
      class={@class}
    >
      <:metrics>
        <.metric_item
          label="Total Legislation"
          value={format_number(@total_legislation)}
        />
        <.metric_item
          label="Recent (Last 30 Days)"
          value="0"
          sublabel="(0.0%)"
        />
        <.metric_item
          label="Average Fine"
          value="£0.00"
        />
      </:metrics>

      <:actions>
        <.card_action_button phx-click="browse_legislation">
          <div class="flex items-center justify-between w-full">
            <span>Browse Recent</span>
            <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </div>
        </.card_action_button>

        <.card_secondary_button phx-click="search_legislation">
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
end
