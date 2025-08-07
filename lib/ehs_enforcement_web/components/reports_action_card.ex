defmodule EhsEnforcementWeb.Components.ReportsActionCard do
  @moduledoc """
  Reports & Analytics action card component for the dashboard.
  
  Displays export statistics, provides filtered report generation,
  and multi-format export functionality. Open access implementation with
  database protection through mandatory filtering and date constraints.
  Implements the reports card specification from the dashboard action cards design document.
  """
  
  use Phoenix.Component
  
  import EhsEnforcementWeb.Components.DashboardActionCard

  @doc """
  Renders the Reports & Analytics action card with live metrics and actions.

  ## Examples

      <.reports_action_card />

  """
  attr :loading, :boolean, default: false, doc: "Show loading state"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def reports_action_card(assigns) do
    # Calculate metrics
    assigns = assign_metrics(assigns)
    
    ~H"""
    <.dashboard_action_card 
      title="REPORTS & ANALYTICS" 
      icon="📊" 
      theme="green" 
      loading={@loading}
      class={@class}
    >
      <:metrics>
        <.metric_item 
          label="Saved Reports" 
          value={format_number(@saved_reports_count)} 
        />
        <.metric_item 
          label="Last Export" 
          value={@last_export_display} 
        />
        <.metric_item 
          label="Data Available" 
          value={@data_available_display} 
        />
      </:metrics>

      <:actions>
        <.action_button 
          phx-click="generate_report" 
          class="bg-green-600 hover:bg-green-700 text-white"
          aria_label="Generate custom report with filtering options"
        >
          <span class="block text-sm font-medium">Generate</span>
          <span class="block text-xs">Report</span>
        </.action_button>
        
        <.action_button 
          phx-click="export_data" 
          class="bg-gray-600 hover:bg-gray-700 text-white"
          aria_label="Export data with multiple format options"
        >
          <span class="block text-sm font-medium">Export</span>
          <span class="block text-xs">Data</span>
        </.action_button>
      </:actions>
    </.dashboard_action_card>
    """
  end

  # Calculate metrics for the reports card
  defp assign_metrics(assigns) do
    try do
      # Calculate saved reports count (placeholder for now)
      saved_reports_count = calculate_saved_reports_count()
      
      # Calculate last export timestamp
      last_export_display = calculate_last_export_display()
      
      # Calculate available data size
      data_available_display = calculate_data_available()
      
      assigns
      |> assign(:saved_reports_count, saved_reports_count)
      |> assign(:last_export_display, last_export_display)
      |> assign(:data_available_display, data_available_display)
    rescue
      error ->
        require Logger
        Logger.error("Error calculating reports metrics: #{inspect(error)}")
        
        assigns
        |> assign(:saved_reports_count, 0)
        |> assign(:last_export_display, "Never")
        |> assign(:data_available_display, "Unknown")
    end
  end

  # Calculate number of saved reports (placeholder implementation)
  defp calculate_saved_reports_count do
    # For now, return a placeholder count
    # In a real implementation, this would query a reports table or user preferences
    5
  end

  # Calculate last export display
  defp calculate_last_export_display do
    # Check for recent CSV exports or other export files
    # This is a placeholder implementation
    case get_last_export_timestamp() do
      nil -> "Never"
      timestamp -> format_time_ago(timestamp)
    end
  end

  # Get the last export timestamp (placeholder)
  defp get_last_export_timestamp do
    # In a real implementation, this would check:
    # - Export file timestamps
    # - User export history
    # - System logs
    # For now, simulate an export from 2 days ago
    DateTime.add(DateTime.utc_now(), -2, :day)
  end

  # Format timestamp as "X days ago"
  defp format_time_ago(timestamp) do
    now = DateTime.utc_now()
    diff_in_seconds = DateTime.diff(now, timestamp, :second)
    
    cond do
      diff_in_seconds < 3600 -> 
        minutes = div(diff_in_seconds, 60)
        "#{minutes} min ago"
        
      diff_in_seconds < 86400 -> 
        hours = div(diff_in_seconds, 3600)
        "#{hours} hours ago"
        
      diff_in_seconds < 604800 -> 
        days = div(diff_in_seconds, 86400)
        "#{days} days ago"
        
      true -> 
        weeks = div(diff_in_seconds, 604800)
        "#{weeks} weeks ago"
    end
  end

  # Calculate available data size
  defp calculate_data_available do
    try do
      # Get total records from all data sources
      total_cases = EhsEnforcement.Enforcement.list_cases!() |> length()
      total_notices = EhsEnforcement.Enforcement.list_notices!() |> length()
      total_offenders = EhsEnforcement.Enforcement.list_offenders!() |> length()
      
      # Estimate data size (rough calculation)
      # Assume ~1KB per case, ~0.8KB per notice, ~0.5KB per offender
      estimated_size_kb = (total_cases * 1.0) + (total_notices * 0.8) + (total_offenders * 0.5)
      
      format_data_size(estimated_size_kb)
    rescue
      error ->
        require Logger
        Logger.error("Error calculating data size: #{inspect(error)}")
        "Unknown"
    end
  end

  # Format data size in appropriate units
  defp format_data_size(size_kb) when size_kb < 1024, do: "#{Float.round(size_kb, 1)}KB"
  defp format_data_size(size_kb) when size_kb < 1_048_576 do
    size_mb = size_kb / 1024
    "#{Float.round(size_mb, 1)}MB"
  end
  defp format_data_size(size_kb) do
    size_gb = size_kb / 1_048_576
    "#{Float.round(size_gb, 1)}GB"
  end

  # Format numbers with comma separators
  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/.{3}(?=.)/, "\\0,")
    |> String.reverse()
  end
  
  defp format_number(number), do: to_string(number)


  # Helper component for action buttons
  attr :class, :string, required: true
  attr :aria_label, :string, required: true
  attr :rest, :global
  slot :inner_block, required: true
  
  defp action_button(assigns) do
    ~H"""
    <button 
      type="button"
      class={"px-4 py-3 rounded-lg font-medium transition-colors duration-200 #{@class}"}
      aria-label={@aria_label}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end
end