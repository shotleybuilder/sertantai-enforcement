defmodule EhsEnforcementWeb.Components.LegislationActionCard do
  @moduledoc """
  Legislation action card component for the dashboard.
  """
  
  use Phoenix.Component

  @doc """
  Renders a legislation action card with quick statistics and action buttons.
  """
  def legislation_action_card(assigns) do
    ~H"""
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="h-6 w-6 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">
                Legislation
              </dt>
              <dd>
                <div class="text-lg font-medium text-gray-900">
                  <%= @total_legislation || 0 %> acts, regulations & orders
                </div>
              </dd>
            </dl>
          </div>
        </div>
      </div>
      
      <div class="bg-gray-50 px-5 py-3">
        <div class="text-sm">
          <div class="flex justify-between items-center">
            <div class="space-y-1">
              <div class="flex items-center text-gray-500">
                <span class="flex items-center">
                  <span class="w-2 h-2 bg-blue-400 rounded-full mr-2"></span>
                  <%= @acts_count || 0 %> Acts
                </span>
                <span class="flex items-center ml-4">
                  <span class="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                  <%= @regulations_count || 0 %> Regulations
                </span>
              </div>
              <div class="flex items-center text-gray-500">
                <span class="flex items-center">
                  <span class="w-2 h-2 bg-yellow-400 rounded-full mr-2"></span>
                  <%= @orders_count || 0 %> Orders
                </span>
                <span class="flex items-center ml-4">
                  <span class="w-2 h-2 bg-purple-400 rounded-full mr-2"></span>
                  <%= @acops_count || 0 %> ACOPs
                </span>
              </div>
            </div>
            
            <div class="flex space-x-2">
              <button
                phx-click="browse_legislation"
                class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded text-indigo-700 bg-indigo-100 hover:bg-indigo-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                Browse
              </button>
              
              <button
                phx-click="search_legislation"
                class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                Search
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end