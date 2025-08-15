defmodule EhsEnforcementWeb.Components.OffenderFilter do
  use EhsEnforcementWeb, :live_component
  use Phoenix.Component

  @doc """
  Renders the offender filter form component
  """
  def filter_form(assigns) do
    assigns = assign_new(assigns, :fuzzy_search, fn -> false end)
    assigns = assign_new(assigns, :agencies, fn -> [] end)
    ~H"""
    <div class="bg-white p-6 rounded-lg shadow-sm border border-gray-200 mb-6">
      <div class="mb-4">
        <h3 class="text-lg font-medium text-gray-900">Filter Offenders</h3>
      </div>
      
      <.form for={%{}} phx-change="filter_change" phx-target={@target} data-testid="offender-filters">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
          <!-- Agency Filter (Position 1) -->
          <div class="space-y-1">
            <label for="agency-filter" class="block text-sm font-medium text-gray-700">
              Agency
            </label>
            <select
              id="agency-filter"
              name="filters[agency]"
              value={@filters[:agency]}
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            >
              <option value="">All Agencies</option>
              <%= for agency <- @agencies do %>
                <option value={agency.name} selected={@filters[:agency] == agency.name}>
                  <%= agency.name %>
                </option>
              <% end %>
            </select>
          </div>

          <!-- Industry Filter (Position 2) -->
          <div class="space-y-1">
            <label for="industry-filter" class="block text-sm font-medium text-gray-700">
              Industry
            </label>
            <select
              id="industry-filter"
              name="filters[industry]"
              value={@filters[:industry]}
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            >
              <option value="">All Industries</option>
              <option value="Agriculture hunting forestry and fishing" selected={@filters[:industry] == "Agriculture hunting forestry and fishing"}>
                Agriculture, Hunting, Forestry & Fishing
              </option>
              <option value="Construction" selected={@filters[:industry] == "Construction"}>
                Construction
              </option>
              <option value="Extractive and utility supply industries" selected={@filters[:industry] == "Extractive and utility supply industries"}>
                Extractive & Utility Supply
              </option>
              <option value="Manufacturing" selected={@filters[:industry] == "Manufacturing"}>
                Manufacturing
              </option>
              <option value="Total service industries" selected={@filters[:industry] == "Total service industries"}>
                Service Industries
              </option>
              <option value="Unknown" selected={@filters[:industry] == "Unknown"}>
                Unknown
              </option>
            </select>
          </div>

          <!-- Search Input -->
          <div class="space-y-1">
            <label for="search-filter" class="block text-sm font-medium text-gray-700">
              Search Offenders
            </label>
            <div class="relative">
              <input
                id="search-filter"
                type="text"
                name="search[query]"
                value={@search_query}
                placeholder="Search by name, postcode, or activity..."
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

          <!-- Local Authority -->
          <div class="space-y-1">
            <label for="authority-filter" class="block text-sm font-medium text-gray-700">
              Local Authority
            </label>
            <input
              id="authority-filter"
              type="text"
              name="filters[local_authority]"
              value={@filters[:local_authority]}
              placeholder="e.g., Manchester"
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            />
          </div>

          <!-- Business Type -->
          <div class="space-y-1">
            <label for="business-type-filter" class="block text-sm font-medium text-gray-700">
              Business Type
            </label>
            <select
              id="business-type-filter"
              name="filters[business_type]"
              value={@filters[:business_type]}
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            >
              <option value="">All Types</option>
              <option value="limited_company" selected={@filters[:business_type] == "limited_company"}>
                Limited Company
              </option>
              <option value="individual" selected={@filters[:business_type] == "individual"}>
                Individual
              </option>
              <option value="partnership" selected={@filters[:business_type] == "partnership"}>
                Partnership
              </option>
              <option value="plc" selected={@filters[:business_type] == "plc"}>
                PLC
              </option>
              <option value="other" selected={@filters[:business_type] == "other"}>
                Other
              </option>
            </select>
          </div>
        </div>

        <!-- Second Row - Additional Filters -->
        <div class="mt-4 grid grid-cols-1 md:grid-cols-3 gap-4">
          <!-- Repeat Offenders Only -->
          <div class="space-y-1">
            <div class="flex items-center">
              <input
                id="repeat-offenders-only"
                type="checkbox"
                name="filters[repeat_only]"
                checked={@filters[:repeat_only]}
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label for="repeat-offenders-only" class="ml-2 text-sm text-gray-700">
                Repeat offenders only
              </label>
            </div>
            <p class="text-xs text-gray-500">More than 2 enforcement actions</p>
          </div>

          <!-- Sort By -->
          <div class="space-y-1">
            <label for="sort-by" class="block text-sm font-medium text-gray-700">
              Sort By
            </label>
            <select
              id="sort-by"
              name="sort_by"
              phx-change="sort"
              value={@sort_by}
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            >
              <option value="total_fines" selected={@sort_by == "total_fines"}>Total Fines</option>
              <option value="name" selected={@sort_by == "name"}>Name</option>
              <option value="total_cases" selected={@sort_by == "total_cases"}>Total Cases</option>
              <option value="total_notices" selected={@sort_by == "total_notices"}>Total Notices</option>
              <option value="first_seen_date" selected={@sort_by == "first_seen_date"}>First Seen</option>
              <option value="last_seen_date" selected={@sort_by == "last_seen_date"}>Last Seen</option>
            </select>
          </div>

          <!-- Sort Order -->
          <div class="space-y-1">
            <label for="sort-order" class="block text-sm font-medium text-gray-700">
              Order
            </label>
            <select
              id="sort-order"
              name="sort_order"
              phx-change="sort"
              value={@sort_order}
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            >
              <option value="desc" selected={@sort_order == "desc"}>High to Low</option>
              <option value="asc" selected={@sort_order == "asc"}>Low to High</option>
            </select>
          </div>
        </div>
        
        <!-- Filter Count and Action Buttons -->
        <div class="mt-4 flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <!-- Real-time Filter Count -->
            <%= if assigns[:counting_filters] && @counting_filters do %>
              <div class="flex items-center text-sm text-gray-600">
                <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600 mr-2"></div>
                Counting...
              </div>
            <% else %>
              <%= if (assigns[:filters] && map_size(@filters) > 0) || (assigns[:search_query] && @search_query != "") do %>
                <div class="flex items-center text-sm">
                  <span class="text-gray-600">Found:</span>
                  <span class={"ml-1 font-semibold #{if assigns[:filter_count] && @filter_count > 1000, do: "text-red-600", else: "text-blue-600"}"}>
                    <%= assigns[:filter_count] || 0 %> offenders
                  </span>
                  <%= if assigns[:filter_count] && @filter_count > 1000 do %>
                    <span class="ml-2 text-xs text-red-600 font-medium">(Too many)</span>
                  <% end %>
                </div>
              <% end %>
            <% end %>
          </div>
          
          <div class="flex items-center space-x-3">
            <!-- Apply Filter Button -->
            <%= if ((assigns[:filters] && map_size(@filters) > 0) || (assigns[:search_query] && @search_query != "")) && !(assigns[:filters_applied] && @filters_applied) do %>
              <%= if !assigns[:filter_count] || @filter_count <= 1000 do %>
                <button
                  type="button"
                  phx-click="apply_filters"
                  phx-target={@target}
                  class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  <.icon name="hero-funnel" class="h-4 w-4 mr-2" />
                  Apply Filters
                </button>
              <% else %>
                <button
                  type="button"
                  disabled
                  class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-400 bg-gray-100 cursor-not-allowed opacity-75"
                  title="Too many records found. Please refine your filters to 1,000 or fewer records."
                >
                  <.icon name="hero-funnel" class="h-4 w-4 mr-2" />
                  Apply Filters
                </button>
              <% end %>
            <% end %>
            
            <!-- Clear Filters Button -->
            <%= if (assigns[:filters] && map_size(@filters) > 0) || (assigns[:search_query] && @search_query != "") do %>
              <button
                type="button"
                phx-click="clear_filters"
                phx-target={@target}
                class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <.icon name="hero-x-mark" class="h-4 w-4 mr-2" />
                Clear Filters
              </button>
            <% end %>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end