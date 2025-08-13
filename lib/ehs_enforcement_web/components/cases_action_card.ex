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

      <.cases_action_card current_user={@current_user} />

  """
  attr :current_user, :map, default: nil, doc: "Current authenticated user"
  attr :loading, :boolean, default: false, doc: "Show loading state"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def cases_action_card(assigns) do
    # Calculate metrics
    assigns = assign_metrics(assigns)
    
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
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
            </svg>
          </div>
        </.card_action_button>
        
        <.card_secondary_button phx-click="search_cases">
          <div class="flex items-center justify-between w-full">
            <span>Search</span>
            <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
            </svg>
          </div>
        </.card_secondary_button>
      </:actions>
      
      <:admin_actions :if={is_admin?(@current_user)} visible={true}>
        <a
          href="/admin"
          class="w-full rounded-md px-4 py-2 text-sm font-medium transition-colors duration-200 border focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500 bg-white text-gray-700 border-gray-300 hover:bg-gray-50 active:bg-gray-100 relative"
        >
          <div class="flex items-center justify-between w-full">
            <span>Admin Tools</span>
            <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
            </svg>
          </div>
          <span class="absolute -top-1 -right-1 inline-flex items-center px-1.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
            ADMIN
          </span>
        </a>
      </:admin_actions>
    </.dashboard_action_card>
    """
  end

  # Private helper functions

  defp assign_metrics(assigns) do
    try do
      # Calculate date range (last 30 days)
      thirty_days_ago = Date.add(Date.utc_today(), -30)
      
      # Get all cases for total count
      all_cases = Enforcement.list_cases!()
      total_cases = length(all_cases)
      
      # Filter for recent cases (last 30 days)
      recent_cases = Enum.filter(all_cases, fn case_record ->
        case_record.offence_action_date && 
        Date.compare(case_record.offence_action_date, thirty_days_ago) != :lt
      end)
      
      recent_cases_count = length(recent_cases)
      
      # Calculate total fines from recent cases only
      total_recent_fines = recent_cases
      |> Enum.map(& &1.offence_fine || Decimal.new(0))
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
      
      assigns
      |> assign(:total_cases, total_cases)
      |> assign(:recent_cases_count, recent_cases_count)
      |> assign(:total_recent_fines, total_recent_fines)
      
    rescue
      error ->
        require Logger
        Logger.error("Failed to calculate cases metrics: #{inspect(error)}")
        
        assigns
        |> assign(:total_cases, 0)
        |> assign(:recent_cases_count, 0)
        |> assign(:total_recent_fines, Decimal.new(0))
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