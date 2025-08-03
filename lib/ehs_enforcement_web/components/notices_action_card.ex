defmodule EhsEnforcementWeb.Components.NoticesActionCard do
  @moduledoc """
  Notices Management action card component for the dashboard.
  
  Displays notices metrics, provides filtered navigation, and admin-controlled create functionality.
  Implements the notices card specification from the dashboard action cards design document.
  """
  
  use Phoenix.Component
  
  import EhsEnforcementWeb.Components.DashboardActionCard
  alias EhsEnforcement.Enforcement

  @doc """
  Renders the Notices Management action card with live metrics and actions.

  ## Examples

      <.notices_action_card current_user={@current_user} />

  """
  attr :current_user, :map, default: nil, doc: "Current authenticated user"
  attr :loading, :boolean, default: false, doc: "Show loading state"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def notices_action_card(assigns) do
    # Calculate metrics
    assigns = assign_metrics(assigns)
    
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
        <.card_action_button phx-click="browse_active_notices">
          <div class="flex items-center justify-between w-full">
            <span>Browse Active</span>
            <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
            </svg>
          </div>
        </.card_action_button>
        
        <.card_secondary_button phx-click="search_notices">
          <div class="flex items-center justify-between w-full">
            <span>Search Database</span>
            <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
            </svg>
          </div>
        </.card_secondary_button>
      </:actions>
      
      <:admin_actions :if={is_admin?(@current_user)} visible={true}>
        <.card_secondary_button 
          phx-click="add_new_notice" 
          admin_only={true}
          disabled={false}
        >
          <div class="flex items-center justify-between w-full">
            <span>Add New Notice</span>
            <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
            </svg>
          </div>
        </.card_secondary_button>
      </:admin_actions>
    </.dashboard_action_card>
    """
  end

  # Private helper functions

  defp assign_metrics(assigns) do
    try do
      # Calculate date range (last 30 days)
      thirty_days_ago = Date.add(Date.utc_today(), -30)
      
      # Get all notices for total count
      all_notices = Enforcement.list_notices!()
      total_notices = length(all_notices)
      
      # Filter for recent notices (last 30 days)
      recent_notices = Enum.filter(all_notices, fn notice_record ->
        notice_record.offence_action_date && 
        Date.compare(notice_record.offence_action_date, thirty_days_ago) != :lt
      end)
      
      recent_notices_count = length(recent_notices)
      
      # Calculate compliance required count (notices without compliance date or future compliance date)
      today = Date.utc_today()
      compliance_required_count = Enum.count(all_notices, fn notice ->
        is_nil(notice.compliance_date) || 
        (notice.compliance_date && Date.compare(notice.compliance_date, today) == :gt)
      end)
      
      assigns
      |> assign(:total_notices, total_notices)
      |> assign(:recent_notices_count, recent_notices_count)
      |> assign(:compliance_required_count, compliance_required_count)
      
    rescue
      error ->
        require Logger
        Logger.error("Failed to calculate notices metrics: #{inspect(error)}")
        
        assigns
        |> assign(:total_notices, 0)
        |> assign(:recent_notices_count, 0)
        |> assign(:compliance_required_count, 0)
    end
  end

  defp is_admin?(nil), do: false
  defp is_admin?(%{is_admin: true}), do: true
  defp is_admin?(_), do: false

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