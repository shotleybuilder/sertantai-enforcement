defmodule EhsEnforcementWeb.Components.DashboardActionCardTest do
  use EhsEnforcementWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component
  import EhsEnforcementWeb.Components.DashboardActionCard

  describe "dashboard_action_card/1" do
    test "renders basic card with title and icon" do
      assigns = %{
        title: "Test Card",
        icon: "📁",
        theme: "blue",
        loading: false,
        error: nil,
        class: "",
        metrics: [],
        actions: [],
        admin_actions: []
      }

      html =
        rendered_to_string(~H"""
        <.dashboard_action_card title={@title} icon={@icon} theme={@theme}></.dashboard_action_card>
        """)

      assert html =~ "Test Card"
      assert html =~ "📁"
      assert html =~ "bg-blue-50"
      assert html =~ "border-blue-200"
      assert html =~ "text-blue-700"
    end

    test "applies correct theme classes" do
      themes = [
        {"blue", "bg-blue-50 border-blue-200 hover:border-blue-300 text-blue-700"},
        {"yellow", "bg-yellow-50 border-yellow-200 hover:border-yellow-300 text-yellow-700"},
        {"purple", "bg-purple-50 border-purple-200 hover:border-purple-300 text-purple-700"},
        {"green", "bg-green-50 border-green-200 hover:border-green-300 text-green-700"}
      ]

      for {theme, expected_classes} <- themes do
        assigns = %{
          title: "Theme Test",
          icon: "🎨",
          theme: theme,
          loading: false,
          error: nil,
          class: "",
          metrics: [],
          actions: [],
          admin_actions: []
        }

        html =
          rendered_to_string(~H"""
          <.dashboard_action_card title={@title} icon={@icon} theme={@theme}></.dashboard_action_card>
          """)

        for class <- String.split(expected_classes, " ") do
          assert html =~ class, "Expected #{class} for theme #{theme}"
        end
      end
    end

    test "renders loading state" do
      assigns = %{
        title: "Loading Card",
        icon: "⏳",
        theme: "blue",
        loading: true,
        error: nil,
        class: "",
        metrics: [],
        actions: [],
        admin_actions: []
      }

      html =
        rendered_to_string(~H"""
        <.dashboard_action_card title={@title} icon={@icon} theme={@theme} loading={@loading}>
        </.dashboard_action_card>
        """)

      assert html =~ "animate-spin"
      assert html =~ "pointer-events-none"
      assert html =~ "bg-white bg-opacity-75"
    end

    test "renders error state" do
      assigns = %{
        title: "Error Card",
        icon: "❌",
        theme: "blue",
        loading: false,
        error: "Something went wrong",
        class: "",
        metrics: [],
        actions: [],
        admin_actions: []
      }

      html =
        rendered_to_string(~H"""
        <.dashboard_action_card title={@title} icon={@icon} theme={@theme} error={@error}>
        </.dashboard_action_card>
        """)

      assert html =~ "Something went wrong"
      assert html =~ "bg-red-50"
      assert html =~ "border-2 border-red-200"
      assert html =~ "text-red-800"
      assert html =~ "⚠️"
    end

    test "renders metrics slot" do
      assigns = %{
        title: "Metrics Card",
        icon: "📊",
        theme: "green",
        loading: false,
        error: nil,
        class: "",
        metrics: [%{}],
        actions: [],
        admin_actions: []
      }

      html =
        rendered_to_string(~H"""
        <.dashboard_action_card title={@title} icon={@icon} theme={@theme}>
          <:metrics>
            <div class="metric-content">Test Metric</div>
          </:metrics>
        </.dashboard_action_card>
        """)

      assert html =~ "Test Metric"
      assert html =~ "metric-content"
    end

    test "renders actions slot" do
      assigns = %{
        title: "Actions Card",
        icon: "🔄",
        theme: "purple",
        loading: false,
        error: nil,
        class: "",
        metrics: [],
        actions: [%{}],
        admin_actions: []
      }

      html =
        rendered_to_string(~H"""
        <.dashboard_action_card title={@title} icon={@icon} theme={@theme}>
          <:actions>
            <button class="test-action">Test Action</button>
          </:actions>
        </.dashboard_action_card>
        """)

      assert html =~ "Test Action"
      assert html =~ "test-action"
    end

    test "renders admin actions slot when visible" do
      assigns = %{
        title: "Admin Card",
        icon: "🔐",
        theme: "yellow",
        loading: false,
        error: nil,
        class: "",
        metrics: [],
        actions: [],
        admin_actions: [%{visible: true}]
      }

      html =
        rendered_to_string(~H"""
        <.dashboard_action_card title={@title} icon={@icon} theme={@theme}>
          <:admin_actions visible={true}>
            <button class="admin-action">Admin Action</button>
          </:admin_actions>
        </.dashboard_action_card>
        """)

      assert html =~ "Admin Action"
      assert html =~ "admin-action"
      assert html =~ "block"
    end

    test "hides admin actions slot when not visible" do
      assigns = %{
        title: "Admin Card",
        icon: "🔐",
        theme: "yellow",
        loading: false,
        error: nil,
        class: "",
        metrics: [],
        actions: [],
        admin_actions: [%{visible: false}]
      }

      html =
        rendered_to_string(~H"""
        <.dashboard_action_card title={@title} icon={@icon} theme={@theme}>
          <:admin_actions visible={false}>
            <button class="admin-action">Admin Action</button>
          </:admin_actions>
        </.dashboard_action_card>
        """)

      assert html =~ "hidden"
    end

    test "includes accessibility attributes" do
      assigns = %{
        title: "Accessible Card",
        icon: "♿",
        theme: "blue",
        loading: false,
        error: nil,
        class: "",
        metrics: [],
        actions: [],
        admin_actions: []
      }

      html =
        rendered_to_string(~H"""
        <.dashboard_action_card title={@title} icon={@icon} theme={@theme}></.dashboard_action_card>
        """)

      assert html =~ ~r/role="article"/
      assert html =~ ~r/aria-labelledby="card-title-accessible-card"/
      assert html =~ ~r/id="card-title-accessible-card"/
      assert html =~ ~r/aria-hidden="true"/
    end

    test "applies custom CSS classes" do
      assigns = %{
        title: "Custom Card",
        icon: "🎨",
        theme: "blue",
        loading: false,
        error: nil,
        class: "custom-class another-class",
        metrics: [],
        actions: [],
        admin_actions: []
      }

      html =
        rendered_to_string(~H"""
        <.dashboard_action_card title={@title} icon={@icon} theme={@theme} class={@class}>
        </.dashboard_action_card>
        """)

      assert html =~ "custom-class"
      assert html =~ "another-class"
    end
  end

  describe "dashboard_card_grid/1" do
    test "renders grid layout with responsive classes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dashboard_card_grid>
          <div>Card 1</div>
          <div>Card 2</div>
        </.dashboard_card_grid>
        """)

      assert html =~ "grid"
      assert html =~ "lg:grid-cols-4"
      assert html =~ "md:grid-cols-2"
      assert html =~ "grid-cols-1"
      assert html =~ "gap-4"
      assert html =~ "lg:gap-6"
      assert html =~ ~r/role="region"/
      assert html =~ ~r/aria-label="Dashboard action cards"/
      assert html =~ "Card 1"
      assert html =~ "Card 2"
    end

    test "applies custom CSS classes to grid" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dashboard_card_grid class="custom-grid">
          <div>Card</div>
        </.dashboard_card_grid>
        """)

      assert html =~ "custom-grid"
    end
  end

  describe "metric_item/1" do
    test "renders basic metric with label and value" do
      assigns = %{
        label: "Total Cases",
        value: "1,003",
        sublabel: nil,
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <.metric_item label={@label} value={@value} />
        """)

      assert html =~ "Total Cases"
      assert html =~ "1,003"
      assert html =~ "text-2xl font-bold text-gray-900"
      assert html =~ "text-sm text-gray-600"
    end

    test "renders metric with sublabel" do
      assigns = %{
        label: "Recent Cases",
        value: "42",
        sublabel: "Last 30 Days",
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <.metric_item label={@label} value={@value} sublabel={@sublabel} />
        """)

      assert html =~ "Recent Cases"
      assert html =~ "42"
      assert html =~ "Last 30 Days"
      assert html =~ "text-xs text-gray-500"
    end

    test "applies custom CSS classes" do
      assigns = %{
        label: "Custom Metric",
        value: "999",
        sublabel: nil,
        class: "custom-metric-class"
      }

      html =
        rendered_to_string(~H"""
        <.metric_item label={@label} value={@value} class={@class} />
        """)

      assert html =~ "custom-metric-class"
    end
  end

  describe "card_action_button/1" do
    test "renders enabled primary button" do
      assigns = %{
        class: "",
        disabled: false
      }

      html =
        rendered_to_string(~H"""
        <.card_action_button phx-click="test_action">
          Test Button
        </.card_action_button>
        """)

      assert html =~ "Test Button"
      assert html =~ "bg-indigo-600"
      assert html =~ "text-white"
      assert html =~ "hover:bg-indigo-700"
      assert html =~ ~r/phx-click="test_action"/
      refute html =~ "disabled"
      refute html =~ "cursor-not-allowed"
    end

    test "renders disabled primary button" do
      assigns = %{
        class: "",
        disabled: true
      }

      html =
        rendered_to_string(~H"""
        <.card_action_button disabled={true}>
          Disabled Button
        </.card_action_button>
        """)

      assert html =~ "Disabled Button"
      assert html =~ "bg-gray-100"
      assert html =~ "text-gray-400"
      assert html =~ "cursor-not-allowed"
      assert html =~ ~r/disabled/
    end

    test "applies focus styles" do
      assigns = %{
        class: "",
        disabled: false
      }

      html =
        rendered_to_string(~H"""
        <.card_action_button>Focus Test</.card_action_button>
        """)

      assert html =~ "focus:outline-none"
      assert html =~ "focus:ring-2"
      assert html =~ "focus:ring-offset-2"
      assert html =~ "focus:ring-indigo-500"
    end
  end

  describe "card_secondary_button/1" do
    test "renders enabled secondary button" do
      assigns = %{
        class: "",
        disabled: false,
        admin_only: false
      }

      html =
        rendered_to_string(~H"""
        <.card_secondary_button phx-click="secondary_action">
          Secondary Button
        </.card_secondary_button>
        """)

      assert html =~ "Secondary Button"
      assert html =~ "bg-white"
      assert html =~ "text-gray-700"
      assert html =~ "border-gray-300"
      assert html =~ "hover:bg-gray-50"
      assert html =~ ~r/phx-click="secondary_action"/
      refute html =~ "disabled"
    end

    test "renders disabled secondary button" do
      assigns = %{
        class: "",
        disabled: true,
        admin_only: false
      }

      html =
        rendered_to_string(~H"""
        <.card_secondary_button disabled={true}>
          Disabled Secondary
        </.card_secondary_button>
        """)

      assert html =~ "bg-gray-50"
      assert html =~ "text-gray-400"
      assert html =~ "border-gray-200"
      assert html =~ "cursor-not-allowed"
      assert html =~ ~r/disabled/
    end

    test "renders admin-only button with badge" do
      assigns = %{
        class: "",
        disabled: false,
        admin_only: true
      }

      html =
        rendered_to_string(~H"""
        <.card_secondary_button admin_only={true}>
          Admin Button
        </.card_secondary_button>
        """)

      assert html =~ "Admin Button"
      assert html =~ "ADMIN"
      assert html =~ "bg-yellow-100"
      assert html =~ "text-yellow-800"
      assert html =~ "absolute -top-1 -right-1"
      assert html =~ "relative"
    end

    test "applies focus styles for secondary button" do
      assigns = %{
        class: "",
        disabled: false,
        admin_only: false
      }

      html =
        rendered_to_string(~H"""
        <.card_secondary_button>Focus Test</.card_secondary_button>
        """)

      assert html =~ "focus:outline-none"
      assert html =~ "focus:ring-2"
      assert html =~ "focus:ring-offset-2"
      assert html =~ "focus:ring-gray-500"
    end
  end

  describe "component integration" do
    test "renders complete card with all slots and components" do
      assigns = %{
        title: "Complete Card",
        icon: "🎯",
        theme: "green",
        loading: false,
        error: nil,
        class: "",
        metrics: [%{}],
        actions: [%{}],
        admin_actions: [%{visible: true}]
      }

      html =
        rendered_to_string(~H"""
        <.dashboard_action_card title={@title} icon={@icon} theme={@theme}>
          <:metrics>
            <.metric_item label="Total Items" value="100" sublabel="All time" />
          </:metrics>
          <:actions>
            <.card_action_button phx-click="primary_action">
              Primary Action
            </.card_action_button>
          </:actions>
          <:admin_actions visible={true}>
            <.card_secondary_button admin_only={true} phx-click="admin_action">
              Admin Action
            </.card_secondary_button>
          </:admin_actions>
        </.dashboard_action_card>
        """)

      # Card structure
      assert html =~ "Complete Card"
      assert html =~ "🎯"
      assert html =~ "bg-green-50"

      # Metrics
      assert html =~ "Total Items"
      assert html =~ "100"
      assert html =~ "All time"

      # Actions
      assert html =~ "Primary Action"
      assert html =~ "bg-indigo-600"

      # Admin actions
      assert html =~ "Admin Action"
      assert html =~ "ADMIN"
      assert html =~ "bg-yellow-100"

      # Accessibility
      assert html =~ ~r/role="article"/
      assert html =~ ~r/aria-labelledby/
    end

    test "grid layout with multiple themed cards" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dashboard_card_grid>
          <.dashboard_action_card title="Blue Card" icon="🔵" theme="blue">
            <:metrics><.metric_item label="Blue Metric" value="1" /></:metrics>
          </.dashboard_action_card>
          <.dashboard_action_card title="Yellow Card" icon="🟡" theme="yellow">
            <:metrics><.metric_item label="Yellow Metric" value="2" /></:metrics>
          </.dashboard_action_card>
          <.dashboard_action_card title="Purple Card" icon="🟣" theme="purple">
            <:metrics><.metric_item label="Purple Metric" value="3" /></:metrics>
          </.dashboard_action_card>
          <.dashboard_action_card title="Green Card" icon="🟢" theme="green">
            <:metrics><.metric_item label="Green Metric" value="4" /></:metrics>
          </.dashboard_action_card>
        </.dashboard_card_grid>
        """)

      # Grid structure
      assert html =~ "lg:grid-cols-4"
      assert html =~ ~r/role="region"/

      # All four cards
      assert html =~ "Blue Card"
      assert html =~ "Yellow Card"
      assert html =~ "Purple Card"
      assert html =~ "Green Card"

      # Theme colors
      assert html =~ "bg-blue-50"
      assert html =~ "bg-yellow-50"
      assert html =~ "bg-purple-50"
      assert html =~ "bg-green-50"

      # Metrics
      assert html =~ "Blue Metric"
      assert html =~ "Yellow Metric"
      assert html =~ "Purple Metric"
      assert html =~ "Green Metric"
    end
  end

  describe "responsive behavior" do
    test "card grid includes all responsive breakpoints" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dashboard_card_grid>
          <div>Test Card</div>
        </.dashboard_card_grid>
        """)

      # Mobile: 1 column
      assert html =~ "grid-cols-1"

      # Tablet: 2 columns
      assert html =~ "md:grid-cols-2"

      # Desktop: 4 columns
      assert html =~ "lg:grid-cols-4"

      # Gap variations
      assert html =~ "gap-4"
      assert html =~ "lg:gap-6"
    end

    test "metric items have responsive text alignment" do
      assigns = %{
        label: "Responsive Metric",
        value: "42",
        sublabel: nil,
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <.metric_item label={@label} value={@value} />
        """)

      assert html =~ "text-center lg:text-left"
    end
  end
end
