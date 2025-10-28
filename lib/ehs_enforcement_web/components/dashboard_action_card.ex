defmodule EhsEnforcementWeb.Components.DashboardActionCard do
  @moduledoc """
  Base dashboard action card component with customizable slots for metrics, actions, and admin indicators.

  This component provides a reusable foundation for all dashboard action cards with:
  - Configurable themes (blue, yellow, purple, green)
  - Responsive 1x4 grid layout
  - Loading, error, and hover states
  - Admin privilege indicators
  - Accessibility features
  """

  use Phoenix.Component

  @doc """
  Renders a dashboard action card with metrics, actions, and optional admin controls.

  ## Examples

      <.dashboard_action_card title="Cases Management" icon="📁" theme="blue">
        <:metrics>
          <div class="text-2xl font-bold text-gray-900">1,003</div>
          <div class="text-sm text-gray-500">Total Cases</div>
        </:metrics>
        <:actions>
          <button class="btn-primary">Browse Recent</button>
        </:actions>
        <:admin_actions>
          <button class="btn-secondary">[ADMIN] Add New Case</button>
        </:admin_actions>
      </.dashboard_action_card>

  """
  attr :title, :string, required: true, doc: "Card title"
  attr :icon, :string, required: true, doc: "Card icon (emoji or HTML)"
  attr :theme, :string, default: "blue", doc: "Card theme: blue, yellow, purple, green"
  attr :loading, :boolean, default: false, doc: "Show loading state"
  attr :error, :string, default: nil, doc: "Error message to display"
  attr :class, :string, default: "", doc: "Additional CSS classes"
  attr :rest, :global, doc: "Additional HTML attributes"

  slot :metrics, doc: "Metrics display area" do
    attr :class, :string, doc: "Additional CSS classes for metrics"
  end

  slot :actions, doc: "Primary action buttons" do
    attr :class, :string, doc: "Additional CSS classes for actions"
  end

  slot :admin_actions, doc: "Admin-only action buttons" do
    attr :class, :string, doc: "Additional CSS classes for admin actions"
    attr :visible, :boolean, doc: "Whether admin actions are visible"
  end

  def dashboard_action_card(assigns) do
    ~H"""
    <div
      class={[
        "relative rounded-lg border-2 transition-all duration-200 hover:shadow-lg group",
        "min-h-[180px] p-5 flex flex-col justify-between",
        theme_classes(@theme),
        loading_classes(@loading),
        error_classes(@error),
        @class
      ]}
      role="article"
      aria-labelledby={"card-title-#{String.replace(@title, " ", "-") |> String.downcase()}"}
      {@rest}
    >
      <!-- Loading Overlay -->
      <%= if @loading do %>
        <div class="absolute inset-0 bg-white bg-opacity-75 rounded-lg flex items-center justify-center z-10">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
        </div>
      <% end %>
      
    <!-- Error Overlay -->
      <%= if @error do %>
        <div class="absolute inset-0 bg-red-50 border-2 border-red-200 rounded-lg flex items-center justify-center z-10">
          <div class="text-center">
            <div class="text-red-600 text-2xl mb-2">⚠️</div>
            <div class="text-red-800 text-sm font-medium">{@error}</div>
          </div>
        </div>
      <% end %>
      
    <!-- Card Header -->
      <div class="flex-shrink-0 mb-4">
        <div class="flex items-center space-x-3">
          <div class="text-2xl" aria-hidden="true">{@icon}</div>
          <h3
            id={"card-title-#{String.replace(@title, " ", "-") |> String.downcase()}"}
            class="text-lg font-semibold text-gray-900 leading-tight"
          >
            {@title}
          </h3>
        </div>
      </div>
      
    <!-- Metrics Section -->
      <div class="flex-grow mb-6">
        <%= for metrics <- @metrics do %>
          <div class={["space-y-2", Map.get(metrics, :class, "")]}>
            {render_slot(metrics)}
          </div>
        <% end %>
      </div>
      
    <!-- Actions Section -->
      <div class="flex-shrink-0 space-y-3">
        <!-- Primary Actions -->
        <%= for action <- @actions do %>
          <div class={["w-full", Map.get(action, :class, "")]}>
            {render_slot(action)}
          </div>
        <% end %>
        
    <!-- Admin Actions -->
        <%= for admin_action <- @admin_actions do %>
          <div class={[
            "w-full",
            if(Map.get(admin_action, :visible, true), do: "block", else: "hidden"),
            Map.get(admin_action, :class, "")
          ]}>
            {render_slot(admin_action)}
          </div>
        <% end %>
      </div>
      
    <!-- Hover Enhancement -->
      <div class="absolute inset-0 rounded-lg ring-2 ring-transparent group-hover:ring-current opacity-20 pointer-events-none transition-all duration-200">
      </div>
    </div>
    """
  end

  @doc """
  Renders a 1x4 responsive grid layout for dashboard action cards.

  ## Examples

      <.dashboard_card_grid>
        <.dashboard_action_card title="Card 1" icon="📁" theme="blue">
          <!-- content -->
        </.dashboard_action_card>
        <.dashboard_action_card title="Card 2" icon="🔔" theme="yellow">
          <!-- content -->
        </.dashboard_action_card>
      </.dashboard_card_grid>

  """
  attr :class, :string, default: "", doc: "Additional CSS classes"
  attr :rest, :global, doc: "Additional HTML attributes"
  slot :inner_block, required: true, doc: "Card content"

  def dashboard_card_grid(assigns) do
    ~H"""
    <div
      class={
        [
          # Desktop: 1x4 horizontal row
          "grid gap-4 lg:grid-cols-4 lg:gap-6",
          # Tablet: 2x2 grid
          "md:grid-cols-2",
          # Mobile: 1x4 vertical stack
          "grid-cols-1",
          @class
        ]
      }
      role="region"
      aria-label="Dashboard action cards"
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a metric item with label and value.

  ## Examples

      <.metric_item label="Total Cases" value="1,003" />
      <.metric_item label="Recent Cases" value="0" sublabel="Last 30 Days" />

  """
  attr :label, :string, required: true, doc: "Metric label"
  attr :value, :string, required: true, doc: "Metric value"
  attr :sublabel, :string, default: nil, doc: "Optional sublabel"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def metric_item(assigns) do
    ~H"""
    <div class={["text-center lg:text-left", @class]}>
      <div class="text-2xl font-bold text-gray-900">{@value}</div>
      <div class="text-sm text-gray-600">{@label}</div>
      <%= if @sublabel do %>
        <div class="text-xs text-gray-500 mt-1">{@sublabel}</div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a primary action button for cards.

  ## Examples

      <.card_action_button phx-click="browse_recent">
        Browse Recent
      </.card_action_button>

  """
  attr :class, :string, default: "", doc: "Additional CSS classes"
  attr :disabled, :boolean, default: false, doc: "Whether button is disabled"

  attr :rest, :global,
    include: ~w(phx-click phx-value-* type href target),
    doc: "Additional HTML attributes"

  slot :inner_block, required: true, doc: "Button content"

  def card_action_button(assigns) do
    ~H"""
    <button
      class={[
        "w-full rounded-md px-4 py-2 text-sm font-medium transition-colors duration-200",
        "focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500",
        if(@disabled,
          do: "bg-gray-100 text-gray-400 cursor-not-allowed",
          else: "bg-indigo-600 text-white hover:bg-indigo-700 active:bg-indigo-800"
        ),
        @class
      ]}
      disabled={@disabled}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders a secondary action button for cards (admin or less prominent actions).

  ## Examples

      <.card_secondary_button phx-click="search_cases">
        Search Cases
      </.card_secondary_button>

  """
  attr :class, :string, default: "", doc: "Additional CSS classes"
  attr :disabled, :boolean, default: false, doc: "Whether button is disabled"
  attr :admin_only, :boolean, default: false, doc: "Whether this is an admin-only button"

  attr :rest, :global,
    include: ~w(phx-click phx-value-* type href target),
    doc: "Additional HTML attributes"

  slot :inner_block, required: true, doc: "Button content"

  def card_secondary_button(assigns) do
    ~H"""
    <button
      class={[
        "w-full rounded-md px-4 py-2 text-sm font-medium transition-colors duration-200",
        "border focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500",
        if(@disabled,
          do: "bg-gray-50 text-gray-400 border-gray-200 cursor-not-allowed",
          else: "bg-white text-gray-700 border-gray-300 hover:bg-gray-50 active:bg-gray-100"
        ),
        if(@admin_only, do: "relative", else: ""),
        @class
      ]}
      disabled={@disabled}
      {@rest}
    >
      {render_slot(@inner_block)}
      <%= if @admin_only do %>
        <span class="absolute -top-1 -right-1 inline-flex items-center px-1.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
          ADMIN
        </span>
      <% end %>
    </button>
    """
  end

  # Private helper functions

  defp theme_classes("blue") do
    "bg-blue-50 border-blue-200 hover:border-blue-300 text-blue-700"
  end

  defp theme_classes("yellow") do
    "bg-yellow-50 border-yellow-200 hover:border-yellow-300 text-yellow-700"
  end

  defp theme_classes("purple") do
    "bg-purple-50 border-purple-200 hover:border-purple-300 text-purple-700"
  end

  defp theme_classes("green") do
    "bg-green-50 border-green-200 hover:border-green-300 text-green-700"
  end

  defp theme_classes(_), do: "bg-gray-50 border-gray-200 hover:border-gray-300 text-gray-700"

  defp loading_classes(true), do: "pointer-events-none"
  defp loading_classes(false), do: ""

  defp error_classes(nil), do: ""
  defp error_classes(_error), do: "pointer-events-none"
end
