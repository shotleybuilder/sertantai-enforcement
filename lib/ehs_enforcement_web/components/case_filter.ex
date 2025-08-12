defmodule EhsEnforcementWeb.Components.CaseFilter do
  use EhsEnforcementWeb, :live_component
  use Phoenix.Component

  @doc """
  Renders the case filter form component
  """
  def filter_form(assigns) do
    assigns = assign_new(assigns, :fuzzy_search, fn -> false end)
    ~H"""
    <div class="bg-white p-6 rounded-lg shadow-sm border border-gray-200 mb-6">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Filter Cases</h3>
        <button
          phx-click="clear_filters"
          phx-target={@target}
          class="text-sm text-gray-500 hover:text-gray-700 underline"
        >
          Clear All
        </button>
      </div>
      
      <.form for={%{}} phx-change="filter" phx-target={@target} data-testid="case-filters">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <!-- Agency Filter -->
          <div class="space-y-1">
            <label for="agency-filter" class="block text-sm font-medium text-gray-700">
              Agency
            </label>
            <select
              id="agency-filter"
              name="filters[agency_id]"
              value={@filters[:agency_id]}
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            >
              <option value="">All Agencies</option>
              <%= for agency <- @agencies do %>
                <%= if agency.enabled do %>
                  <option value={agency.id} selected={@filters[:agency_id] == agency.id}>
                    <%= agency.name %>
                  </option>
                <% else %>
                  <option value={agency.id} disabled selected={@filters[:agency_id] == agency.id}>
                    <%= agency.name %> (Disabled)
                  </option>
                <% end %>
              <% end %>
            </select>
          </div>

          <!-- Search Input -->
          <div class="space-y-1">
            <label for="search-filter" class="block text-sm font-medium text-gray-700">
              Search Cases
            </label>
            <div class="relative">
              <input
                id="search-filter"
                type="text"
                name="filters[search]"
                value={@filters[:search]}
                placeholder="Search by offender, case ID, or breach..."
                class="block w-full rounded-md border-gray-300 pl-10 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
              <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <.icon name="hero-magnifying-glass" class="h-4 w-4 text-gray-400" />
              </div>
            </div>
            
            <!-- Fuzzy Search Toggle -->
            <div class="mt-2 flex items-center">
              <input
                id="fuzzy-search-toggle"
                type="checkbox"
                checked={@fuzzy_search}
                phx-click="toggle_fuzzy_search"
                phx-target={@target}
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label for="fuzzy-search-toggle" class="ml-2 text-sm text-gray-600">
                Fuzzy search (finds similar matches)
              </label>
              <%= if @fuzzy_search do %>
                <.icon name="hero-sparkles" class="h-4 w-4 ml-1 text-blue-500" />
              <% end %>
            </div>
          </div>

          <!-- Date From -->
          <div class="space-y-1">
            <label for="date-from-filter" class="block text-sm font-medium text-gray-700">
              Date From
            </label>
            <input
              id="date-from-filter"
              type="date"
              name="filters[date_from]"
              value={@filters[:date_from]}
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            />
          </div>

          <!-- Date To -->
          <div class="space-y-1">
            <label for="date-to-filter" class="block text-sm font-medium text-gray-700">
              Date To
            </label>
            <input
              id="date-to-filter"
              type="date"
              name="filters[date_to]"
              value={@filters[:date_to]}
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            />
          </div>

          <!-- Min Fine -->
          <div class="space-y-1">
            <label for="min-fine-filter" class="block text-sm font-medium text-gray-700">
              Min Fine (£)
            </label>
            <input
              id="min-fine-filter"
              type="number"
              name="filters[min_fine]"
              value={@filters[:min_fine]}
              min="0"
              step="100"
              placeholder="0"
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            />
          </div>

          <!-- Max Fine -->
          <div class="space-y-1">
            <label for="max-fine-filter" class="block text-sm font-medium text-gray-700">
              Max Fine (£)
            </label>
            <input
              id="max-fine-filter"
              type="number"
              name="filters[max_fine]"
              value={@filters[:max_fine]}
              min="0"
              step="100"
              placeholder="No limit"
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            />
          </div>
        </div>

        <!-- Filter Actions -->
        <div class="mt-4 flex justify-between items-center">
          <div class="text-sm text-gray-500">
            <%= if map_size(@filters) > 0 do %>
              <%= Enum.count(Map.keys(@filters)) %> filter<%= if Enum.count(Map.keys(@filters)) != 1, do: "s" %> applied
            <% else %>
              No filters applied
            <% end %>
          </div>
          
          <div class="flex space-x-2">
            <button
              type="submit"
              class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <.icon name="hero-funnel" class="h-4 w-4 mr-1" />
              Apply Filters
            </button>
            
            <button
              type="button"
              phx-click="clear_filters"
              phx-target={@target}
              class="inline-flex items-center px-3 py-2 border border-gray-300 text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <.icon name="hero-x-mark" class="h-4 w-4 mr-1" />
              Clear
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  @doc """
  Renders filter status indicators
  """
  def filter_status(assigns) do
    ~H"""
    <div class="mb-4">
      <%= if map_size(@filters) > 0 do %>
        <div class="flex flex-wrap gap-2">
          <%= for {key, value} <- @filters do %>
            <.filter_tag key={key} value={value} target={@target} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders individual filter tag
  """
  def filter_tag(assigns) do
    ~H"""
    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
      <%= format_filter_label(@key) %>: <%= format_filter_value(@key, @value) %>
      <button
        type="button"
        phx-click="remove_filter"
        phx-value-key={@key}
        phx-target={@target}
        class="ml-1.5 inline-flex items-center justify-center w-4 h-4 rounded-full text-blue-400 hover:text-blue-600 hover:bg-blue-200 focus:outline-none focus:ring-1 focus:ring-blue-500"
      >
        <.icon name="hero-x-mark" class="h-3 w-3" />
      </button>
    </span>
    """
  end

  # Private helper functions

  defp format_filter_label(:agency_id), do: "Agency"
  defp format_filter_label(:search), do: "Search"
  defp format_filter_label(:date_from), do: "From Date"
  defp format_filter_label(:date_to), do: "To Date"
  defp format_filter_label(:min_fine), do: "Min Fine"
  defp format_filter_label(:max_fine), do: "Max Fine"
  defp format_filter_label(key), do: String.capitalize(to_string(key))

  defp format_filter_value(:agency_id, value) do
    # This would ideally look up the agency name, but for simplicity showing ID
    "Agency #{String.slice(value, 0, 8)}..."
  end

  defp format_filter_value(:min_fine, value), do: "£#{value}"
  defp format_filter_value(:max_fine, value), do: "£#{value}"
  defp format_filter_value(_key, value) when is_binary(value) do
    if String.length(value) > 20 do
      String.slice(value, 0, 17) <> "..."
    else
      value
    end
  end

  defp format_filter_value(_key, value), do: to_string(value)
end