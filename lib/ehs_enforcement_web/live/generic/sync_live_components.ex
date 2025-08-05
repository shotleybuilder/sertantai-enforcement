defmodule EhsEnforcementWeb.Live.Generic.SyncLiveComponents do
  @moduledoc """
  Reusable LiveView components for generic sync interfaces.
  
  This module provides a comprehensive set of LiveView components that can be
  used in any Phoenix application to build sync management interfaces. The components
  are designed to be framework-agnostic and work with any sync engine implementation.
  
  ## Components
  
  - `sync_status_panel` - Real-time sync status display
  - `sync_progress_bar` - Animated progress visualization  
  - `sync_statistics_cards` - Statistics display cards
  - `sync_configuration_form` - Sync configuration interface
  - `sync_batch_list` - Batch processing status list
  - `sync_error_panel` - Error display and recovery interface
  - `sync_history_table` - Historical sync sessions table
  - `sync_control_buttons` - Action buttons (start, stop, cancel)
  
  ## Features
  
  - Real-time updates via Phoenix LiveView
  - Responsive design with Tailwind CSS
  - Accessibility-compliant markup
  - Configurable themes and styling
  - Event-driven architecture
  - Package-ready for extraction
  
  ## Usage
  
      # In your LiveView template
      <.sync_status_panel 
        session_id={@session_id} 
        status={@sync_status} 
        theme={@theme} 
      />
      
      <.sync_progress_bar 
        progress={@progress} 
        total={@total} 
        animated={true} 
      />
      
      <.sync_configuration_form 
        config={@sync_config} 
        on_submit="configure_sync" 
        disabled={@sync_running} 
      />
  """
  
  use Phoenix.Component
  import Phoenix.HTML.Form
  alias Phoenix.LiveView.JS

  @doc """
  Sync status panel with real-time status updates.
  
  Displays current sync session status, progress information, and key metrics.
  Updates automatically via LiveView events.
  
  ## Attributes
  
  * `session_id` - Current sync session ID
  * `status` - Current sync status (:pending, :running, :completed, :failed, :cancelled)
  * `progress` - Current progress information map
  * `theme` - UI theme (:default, :dark, :minimal) 
  * `class` - Additional CSS classes
  * `rest` - Additional HTML attributes
  
  ## Examples
  
      <.sync_status_panel 
        session_id="sync_abc123"
        status={:running}
        progress={%{processed: 150, total: 1000, errors: 2}}
        theme={:default}
      />
  """
  attr :session_id, :string, required: true
  attr :status, :atom, required: true
  attr :progress, :map, default: %{}
  attr :theme, :atom, default: :default
  attr :class, :string, default: ""
  attr :rest, :global

  def sync_status_panel(assigns) do
    ~H"""
    <div class={[
      "sync-status-panel rounded-lg border p-6",
      theme_classes(@theme, :panel),
      @class
    ]} {@rest}>
      <!-- Header -->
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100">
          Sync Status
        </h3>
        <div class="flex items-center space-x-2">
          <.sync_status_badge status={@status} />
          <span class="text-sm text-gray-500 dark:text-gray-400">
            Session: <%= String.slice(@session_id, -8..-1) %>
          </span>
        </div>
      </div>
      
      <!-- Progress Overview -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
        <.sync_stat_card 
          title="Processed" 
          value={Map.get(@progress, :processed, 0)} 
          theme={@theme} 
        />
        <.sync_stat_card 
          title="Remaining" 
          value={Map.get(@progress, :total, 0) - Map.get(@progress, :processed, 0)} 
          theme={@theme} 
        />
        <.sync_stat_card 
          title="Errors" 
          value={Map.get(@progress, :errors, 0)} 
          theme={@theme}
          alert={Map.get(@progress, :errors, 0) > 0} 
        />
      </div>
      
      <!-- Progress Bar -->
      <.sync_progress_bar 
        progress={Map.get(@progress, :processed, 0)}
        total={Map.get(@progress, :total, 1)}
        animated={@status == :running}
        theme={@theme}
      />
      
      <!-- Status Details -->
      <div class="mt-4 text-sm text-gray-600 dark:text-gray-400">
        <div class="flex justify-between items-center">
          <span>Status: <%= format_status(@status) %></span>
          <span>
            <%= if Map.get(@progress, :processing_time_ms) do %>
              Duration: <%= format_duration(Map.get(@progress, :processing_time_ms, 0)) %>
            <% end %>
          </span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Animated progress bar with customizable styling.
  
  Shows sync progress with optional animation and status-based coloring.
  
  ## Attributes
  
  * `progress` - Current progress value
  * `total` - Total target value  
  * `animated` - Enable animation (boolean)
  * `theme` - UI theme (:default, :dark, :minimal)
  * `show_percentage` - Show percentage text (default: true)
  * `class` - Additional CSS classes
  """
  attr :progress, :integer, required: true
  attr :total, :integer, required: true
  attr :animated, :boolean, default: false
  attr :theme, :atom, default: :default
  attr :show_percentage, :boolean, default: true
  attr :class, :string, default: ""

  def sync_progress_bar(assigns) do
    assigns = assign(assigns, :percentage, calculate_percentage(assigns.progress, assigns.total))
    
    ~H"""
    <div class={["sync-progress-bar", @class]}>
      <div class="flex justify-between items-center mb-2">
        <span class="text-sm font-medium text-gray-700 dark:text-gray-300">Progress</span>
        <%= if @show_percentage do %>
          <span class="text-sm text-gray-500 dark:text-gray-400">
            <%= @percentage %>% (<%= @progress %>/<%= @total %>)
          </span>
        <% end %>
      </div>
      
      <div class={[
        "w-full bg-gray-200 rounded-full h-2.5 dark:bg-gray-700",
        theme_classes(@theme, :progress_bg)
      ]}>
        <div 
          class={[
            "h-2.5 rounded-full transition-all duration-300 ease-out",
            progress_bar_color(@percentage),
            (@animated && "animate-pulse") || ""
          ]}
          style={"width: #{@percentage}%"}
        >
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Sync configuration form with validation and real-time updates.
  
  Provides a comprehensive form for configuring sync operations with
  validation, help text, and conditional field display.
  
  ## Attributes
  
  * `config` - Current configuration map
  * `on_submit` - Submit event handler
  * `disabled` - Disable form (boolean)
  * `theme` - UI theme
  * `show_advanced` - Show advanced options (default: false)
  """
  attr :config, :map, required: true
  attr :on_submit, :string, required: true
  attr :disabled, :boolean, default: false
  attr :theme, :atom, default: :default
  attr :show_advanced, :boolean, default: false
  attr :class, :string, default: ""

  def sync_configuration_form(assigns) do
    ~H"""
    <div class={["sync-configuration-form", @class]}>
      <form phx-submit={@on_submit} class="space-y-6">
        <!-- Basic Configuration -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Resource Type
            </label>
            <select 
              name="resource_type" 
              class={form_input_classes(@theme)}
              disabled={@disabled}
            >
              <option value="cases" selected={Map.get(@config, :resource_type) == :cases}>
                Cases
              </option>
              <option value="notices" selected={Map.get(@config, :resource_type) == :notices}>
                Notices
              </option>
              <option value="all" selected={Map.get(@config, :resource_type) == :all}>
                All Records
              </option>
            </select>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Batch Size
            </label>
            <input 
              type="number" 
              name="batch_size"
              value={Map.get(@config, :batch_size, 100)}
              min="1" 
              max="1000"
              class={form_input_classes(@theme)}
              disabled={@disabled}
            />
            <p class="mt-1 text-xs text-gray-500">Records per batch (1-1000)</p>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Record Limit
            </label>
            <input 
              type="number" 
              name="limit"
              value={Map.get(@config, :limit, 1000)}
              min="1" 
              max="100000"
              class={form_input_classes(@theme)}
              disabled={@disabled}
            />
            <p class="mt-1 text-xs text-gray-500">Maximum records to sync (1-100,000)</p>
          </div>
          
          <div class="flex items-center">
            <input 
              type="checkbox" 
              name="enable_error_recovery"
              checked={Map.get(@config, :enable_error_recovery, true)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              disabled={@disabled}
            />
            <label class="ml-2 block text-sm text-gray-700 dark:text-gray-300">
              Enable Error Recovery
            </label>
          </div>
        </div>
        
        <!-- Advanced Configuration (Collapsible) -->
        <%= if @show_advanced do %>
          <div class="border-t pt-6">
            <h4 class="text-md font-medium text-gray-900 dark:text-gray-100 mb-4">
              Advanced Options
            </h4>
            
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div class="flex items-center">
                <input 
                  type="checkbox" 
                  name="enable_integrity_monitoring"
                  checked={Map.get(@config, :enable_integrity_monitoring, true)}
                  class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  disabled={@disabled}
                />
                <label class="ml-2 block text-sm text-gray-700 dark:text-gray-300">
                  Enable Integrity Monitoring
                </label>
              </div>
              
              <div class="flex items-center">
                <input 
                  type="checkbox" 
                  name="enable_circuit_breaker"
                  checked={Map.get(@config, :enable_circuit_breaker, true)}
                  class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  disabled={@disabled}
                />
                <label class="ml-2 block text-sm text-gray-700 dark:text-gray-300">
                  Enable Circuit Breaker
                </label>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Max Recovery Attempts
                </label>
                <input 
                  type="number" 
                  name="max_recovery_attempts"
                  value={Map.get(@config, :max_recovery_attempts, 3)}
                  min="1" 
                  max="10"
                  class={form_input_classes(@theme)}
                  disabled={@disabled}
                />
              </div>
              
              <div class="flex items-center">
                <input 
                  type="checkbox" 
                  name="generate_integrity_report"
                  checked={Map.get(@config, :generate_integrity_report, true)}
                  class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  disabled={@disabled}
                />
                <label class="ml-2 block text-sm text-gray-700 dark:text-gray-300">
                  Generate Integrity Report
                </label>
              </div>
            </div>
          </div>
        <% end %>
        
        <!-- Form Actions -->
        <div class="flex justify-between items-center pt-6">
          <button 
            type="button"
            phx-click={JS.toggle(to: ".advanced-options")}
            class="text-sm text-blue-600 hover:text-blue-500"
          >
            <%= if @show_advanced, do: "Hide", else: "Show" %> Advanced Options
          </button>
          
          <div class="flex space-x-3">
            <button 
              type="button"
              phx-click="reset_config"
              class={[
                "px-4 py-2 text-sm font-medium rounded-md",
                "text-gray-700 bg-gray-100 hover:bg-gray-200",
                "dark:text-gray-300 dark:bg-gray-700 dark:hover:bg-gray-600",
                "disabled:opacity-50 disabled:cursor-not-allowed"
              ]}
              disabled={@disabled}
            >
              Reset
            </button>
            
            <button 
              type="submit"
              class={[
                "px-4 py-2 text-sm font-medium rounded-md",
                "text-white bg-blue-600 hover:bg-blue-700",
                "focus:ring-2 focus:ring-blue-500 focus:ring-offset-2",
                "disabled:opacity-50 disabled:cursor-not-allowed"
              ]}
              disabled={@disabled}
            >
              Update Configuration
            </button>
          </div>
        </div>
      </form>
    </div>
    """
  end

  @doc """
  Sync control buttons with real-time state management.
  
  Provides start, stop, cancel, and other action buttons with appropriate
  state-based enabling/disabling and visual feedback.
  
  ## Attributes
  
  * `sync_status` - Current sync status
  * `session_id` - Current session ID (if any)
  * `theme` - UI theme
  * `actions` - List of available actions
  * `class` - Additional CSS classes
  """
  attr :sync_status, :atom, required: true
  attr :session_id, :string, default: nil
  attr :theme, :atom, default: :default
  attr :actions, :list, default: [:start, :stop, :cancel]
  attr :class, :string, default: ""

  def sync_control_buttons(assigns) do
    ~H"""
    <div class={["sync-control-buttons flex space-x-3", @class]}>
      <%= if :start in @actions do %>
        <button 
          phx-click="start_sync"
          class={[
            "flex items-center px-4 py-2 text-sm font-medium rounded-md",
            button_classes(:primary, @theme),
            "disabled:opacity-50 disabled:cursor-not-allowed"
          ]}
          disabled={@sync_status in [:running, :cancelling]}
        >
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1m4 0h1m-6 4h1m4 0h1m-6-8h1m4 0h1M10 6V4a2 2 0 012-2h0a2 2 0 012 2v2m-4 6V6"></path>
          </svg>
          Start Sync
        </button>
      <% end %>
      
      <%= if :stop in @actions and @sync_status == :running do %>
        <button 
          phx-click="stop_sync"
          phx-value-session-id={@session_id}
          class={[
            "flex items-center px-4 py-2 text-sm font-medium rounded-md",
            button_classes(:warning, @theme)
          ]}
        >
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 10h6v4H9z"></path>
          </svg>
          Stop Sync
        </button>
      <% end %>
      
      <%= if :cancel in @actions and @sync_status in [:running, :pending] do %>
        <button 
          phx-click="cancel_sync"
          phx-value-session-id={@session_id}
          class={[
            "flex items-center px-4 py-2 text-sm font-medium rounded-md",
            button_classes(:danger, @theme)
          ]}
        >
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
          Cancel
        </button>
      <% end %>
      
      <%= if :refresh in @actions do %>
        <button 
          phx-click="refresh_status"
          class={[
            "flex items-center px-4 py-2 text-sm font-medium rounded-md",
            button_classes(:secondary, @theme)
          ]}
        >
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
          </svg>
          Refresh
        </button>
      <% end %>
    </div>
    """
  end

  @doc """
  Statistics display card for sync metrics.
  
  Shows individual sync statistics with optional alert styling.
  """
  attr :title, :string, required: true
  attr :value, :any, required: true  
  attr :theme, :atom, default: :default
  attr :alert, :boolean, default: false
  attr :class, :string, default: ""

  def sync_stat_card(assigns) do
    ~H"""
    <div class={[
      "sync-stat-card p-4 rounded-lg border",
      theme_classes(@theme, :stat_card),
      (@alert && "border-red-300 bg-red-50 dark:border-red-600 dark:bg-red-900/20") || "",
      @class
    ]}>
      <div class="flex items-center justify-between">
        <div>
          <p class={[
            "text-sm font-medium", 
            (@alert && "text-red-800 dark:text-red-200") || "text-gray-600 dark:text-gray-400"
          ]}>
            <%= @title %>
          </p>
          <p class={[
            "text-2xl font-bold",
            (@alert && "text-red-900 dark:text-red-100") || "text-gray-900 dark:text-gray-100"
          ]}>
            <%= format_stat_value(@value) %>
          </p>
        </div>
        <%= if @alert do %>
          <svg class="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
          </svg>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Status badge with color coding.
  
  Shows sync status with appropriate colors and icons.
  """
  attr :status, :atom, required: true
  attr :size, :atom, default: :default

  def sync_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
      status_badge_classes(@status),
      size_classes(@size)
    ]}>
      <svg class={[
        "mr-1.5",
        (@size == :small && "w-2 h-2") || "w-2 h-2"
      ]} fill="currentColor" viewBox="0 0 8 8">
        <circle cx="4" cy="4" r="3"/>
      </svg>
      <%= format_status(@status) %>
    </span>
    """
  end

  # Private helper functions

  defp calculate_percentage(progress, total) when total > 0 do
    Float.round(progress / total * 100, 1)
  end
  defp calculate_percentage(_progress, _total), do: 0.0

  defp format_status(:pending), do: "Pending"
  defp format_status(:running), do: "Running"  
  defp format_status(:completed), do: "Completed"
  defp format_status(:failed), do: "Failed"
  defp format_status(:cancelled), do: "Cancelled"
  defp format_status(status), do: status |> to_string() |> String.capitalize()

  defp format_stat_value(value) when is_integer(value) do
    Number.Delimit.number_to_delimited(value, delimiter: ",")
  rescue
    _ -> to_string(value)
  end
  defp format_stat_value(value), do: to_string(value)

  defp format_duration(ms) when is_integer(ms) do
    seconds = div(ms, 1000)
    minutes = div(seconds, 60)
    hours = div(minutes, 60)
    
    cond do
      hours > 0 -> "#{hours}h #{rem(minutes, 60)}m"
      minutes > 0 -> "#{minutes}m #{rem(seconds, 60)}s"
      true -> "#{seconds}s"
    end
  end
  defp format_duration(_), do: "0s"

  defp theme_classes(:dark, :panel), do: "bg-gray-800 border-gray-700"
  defp theme_classes(:minimal, :panel), do: "bg-white border-gray-200 shadow-sm"
  defp theme_classes(_, :panel), do: "bg-white border-gray-300 shadow"

  defp theme_classes(:dark, :progress_bg), do: "bg-gray-600"
  defp theme_classes(_, :progress_bg), do: "bg-gray-200"

  defp theme_classes(:dark, :stat_card), do: "bg-gray-700 border-gray-600"
  defp theme_classes(:minimal, :stat_card), do: "bg-gray-50 border-gray-200"
  defp theme_classes(_, :stat_card), do: "bg-white border-gray-300"

  defp progress_bar_color(percentage) when percentage >= 90, do: "bg-green-600"
  defp progress_bar_color(percentage) when percentage >= 70, do: "bg-blue-600"
  defp progress_bar_color(percentage) when percentage >= 40, do: "bg-yellow-600"
  defp progress_bar_color(_), do: "bg-red-600"

  defp status_badge_classes(:pending), do: "bg-yellow-100 text-yellow-800"
  defp status_badge_classes(:running), do: "bg-blue-100 text-blue-800"
  defp status_badge_classes(:completed), do: "bg-green-100 text-green-800"
  defp status_badge_classes(:failed), do: "bg-red-100 text-red-800"
  defp status_badge_classes(:cancelled), do: "bg-gray-100 text-gray-800"
  defp status_badge_classes(_), do: "bg-gray-100 text-gray-800"

  defp size_classes(:small), do: "text-xs px-2 py-1"
  defp size_classes(_), do: "text-sm px-2.5 py-0.5"

  defp button_classes(:primary, :dark), do: "text-white bg-blue-600 hover:bg-blue-700 focus:ring-blue-500"
  defp button_classes(:primary, _), do: "text-white bg-blue-600 hover:bg-blue-700 focus:ring-2 focus:ring-blue-500"

  defp button_classes(:secondary, :dark), do: "text-gray-300 bg-gray-600 hover:bg-gray-700 focus:ring-gray-500"
  defp button_classes(:secondary, _), do: "text-gray-700 bg-gray-100 hover:bg-gray-200 focus:ring-2 focus:ring-gray-500"

  defp button_classes(:warning, :dark), do: "text-white bg-yellow-600 hover:bg-yellow-700 focus:ring-yellow-500"
  defp button_classes(:warning, _), do: "text-white bg-yellow-600 hover:bg-yellow-700 focus:ring-2 focus:ring-yellow-500"

  defp button_classes(:danger, :dark), do: "text-white bg-red-600 hover:bg-red-700 focus:ring-red-500"
  defp button_classes(:danger, _), do: "text-white bg-red-600 hover:bg-red-700 focus:ring-2 focus:ring-red-500"

  defp form_input_classes(:dark) do
    "block w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-md text-gray-100 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
  end
  defp form_input_classes(_) do
    "block w-full px-3 py-2 bg-white border border-gray-300 rounded-md text-gray-900 placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
  end
end