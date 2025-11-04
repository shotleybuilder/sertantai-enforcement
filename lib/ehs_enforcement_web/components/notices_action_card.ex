defmodule EhsEnforcementWeb.Components.NoticesActionCard do
  @moduledoc """
  Notices Management action card component for the dashboard.

  Displays notices metrics, provides filtered navigation, and admin-controlled create functionality.
  Implements the notices card specification from the dashboard action cards design document.
  """

  use Phoenix.Component

  import EhsEnforcementWeb.Components.DashboardActionCard

  @doc """
  Renders the Notices Management action card with live metrics and actions.

  ## Examples

      <.notices_action_card current_user={@current_user} stats={@stats} />

  """
  attr :current_user, :map, default: nil, doc: "Current authenticated user"
  attr :stats, :map, required: true, doc: "Pre-computed dashboard statistics from metrics table"
  attr :loading, :boolean, default: false, doc: "Show loading state"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def notices_action_card(assigns) do
    # Use pre-computed metrics from stats
    # Note: compliance_required_count is not yet in metrics table, using 0 as placeholder
    assigns =
      assigns
      |> assign(:total_notices, Map.get(assigns.stats, :total_notices, 0))
      |> assign(:recent_notices_count, Map.get(assigns.stats, :recent_notices, 0))
      |> assign(:compliance_required_count, 0)

    ~H"""
    <.dashboard_action_card
      title="ENFORCEMENT NOTICES"
      icon="📄"
      theme="yellow"
      loading={@loading}
      class={@class}
    >
      <:metrics>
        <.metric_item
          label="Total Notices"
          value={format_number(@total_notices)}
        />
        <.metric_item
          label="Recent (Last 30 Days)"
          value={format_number(@recent_notices_count)}
        />
        <.metric_item
          label="Compliance Required"
          value={format_number(@compliance_required_count)}
        />
      </:metrics>

      <:actions>
        <.card_action_button phx-click="browse_recent_notices">
          <div class="flex items-center justify-between w-full">
            <span>Browse Recent</span>
            <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </div>
        </.card_action_button>

        <.card_secondary_button phx-click="search_notices">
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
