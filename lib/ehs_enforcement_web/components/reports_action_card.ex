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

      <.reports_action_card stats={@stats} />

  """
  attr :stats, :map, required: true, doc: "Pre-computed dashboard statistics from metrics table"
  attr :loading, :boolean, default: false, doc: "Show loading state"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def reports_action_card(assigns) do
    # Calculate metrics using pre-computed stats
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
        <.card_action_button phx-click="generate_report">
          <div class="flex items-center justify-between w-full">
            <span>Generate Report</span>
            <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>
          </div>
        </.card_action_button>
        
        <.card_secondary_button disabled={true}>
          <div class="flex items-center justify-between w-full">
            <span>Export Data</span>
            <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-4a2 2 0 00-2-2H6a2 2 0 00-2 2v4a2 2 0 002 2zm10-12a4 4 0 00-8 0v2a2 2 0 002 2h4a2 2 0 002-2v-2z"/>
            </svg>
          </div>
        </.card_secondary_button>
      </:actions>
    </.dashboard_action_card>
    """
  end

  # Calculate metrics for the reports card using pre-computed stats
  defp assign_metrics(assigns) do
    try do
      # Calculate saved reports count (placeholder for now)
      saved_reports_count = calculate_saved_reports_count()

      # Calculate last export timestamp
      last_export_display = calculate_last_export_display()

      # Calculate available data size using pre-computed stats (no DB queries!)
      data_available_display = calculate_data_available(assigns.stats)

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

  # Calculate available data size using pre-computed stats from metrics table
  defp calculate_data_available(stats) do
    try do
      # Get total records from pre-computed metrics (no database queries!)
      total_cases = Map.get(stats, :total_cases, 0)
      total_notices = Map.get(stats, :total_notices, 0)
      # Note: Offenders count not yet in metrics, using placeholder
      total_offenders = 0

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


end