defmodule EhsEnforcementWeb.Components.ProgressComponent do
  @moduledoc """
  Unified progress component for agency-specific scraping operations.
  
  This component replaces separate HSE and EA progress components with a single
  intelligent component that handles agency-specific display logic internally.
  
  ## Features
  
  - **Agency Detection**: Automatically detects HSE vs EA based on progress data
  - **Conditional Rendering**: Shows page-based progress for HSE, case-based for EA
  - **Unified Interface**: Single component call replaces template agency switching
  - **Progress Calculation**: Handles different progress calculation methods per agency
  
  ## Usage
  
  ```heex
  <!-- Before: Agency-specific components -->
  <%= if selected_agency in [:hse, "hse"] do %>
    <.hse_progress_component progress={@progress} />
  <% else %>
    <.ea_progress_component progress={@progress} />
  <% end %>
  
  <!-- After: Unified component -->
  <.unified_progress_component agency={@selected_agency} progress={@progress} />
  ```
  """
  
  use Phoenix.Component
  
  @doc """
  Unified progress component that handles both HSE and EA scraping progress display.
  
  ## Attributes
  
  - `agency` - The agency type (:hse, :ea, "hse", "ea")
  - `progress` - Progress map containing scraping session data
  
  ## Progress Data Structure
  
  Expected progress fields:
  - `status` - :idle, :running, :completed, :stopped
  - `current_page` - Current page being processed (HSE only)
  - `pages_processed` - Number of pages completed (HSE only)
  - `cases_found` - Total cases discovered
  - `cases_created` - New cases created
  - `cases_updated` - Existing cases updated (optional)
  - `cases_exist_total` - Cases that already existed
  - `start_page`, `end_page` - Page range for HSE scraping
  """
  attr :agency, :atom, required: true, doc: "Agency type (:hse or :ea)"
  attr :progress, :map, required: true, doc: "Progress data from scraping session"
  
  def unified_progress_component(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-xl font-semibold text-gray-900">
          <%= agency_display_name(@agency) %> Progress
        </h2>
        <%= if @progress.status in [:completed, :stopped] and (@progress.cases_created > 0 or Map.get(@progress, :cases_updated, 0) > 0) do %>
          <button
            type="button"
            phx-click="clear_progress"
            class="text-sm text-gray-500 hover:text-gray-700"
          >
            Clear Progress
          </button>
        <% end %>
      </div>
      
      <!-- Progress Bar -->
      <div class="mb-4">
        <div class="flex items-center justify-between text-sm text-gray-600 mb-2">
          <span><%= status_text(@progress.status) %></span>
          <span><%= trunc(calculate_progress_percentage(@agency, @progress)) %>%</span>
        </div>
        <div class="w-full bg-gray-200 rounded-full h-2">
          <div 
            class={"h-2 rounded-full transition-all duration-300 #{status_color(@progress.status)}"}
            style={"width: #{calculate_progress_percentage(@agency, @progress)}%"}
          ></div>
        </div>
      </div>
      
      <!-- Agency-specific progress display -->
      <%= if agency_uses_pagination?(@agency) do %>
        <%= render_page_based_progress(assigns) %>
      <% else %>
        <%= render_case_based_progress(assigns) %>
      <% end %>
      
      <!-- Common statistics -->
      <%= render_common_statistics(assigns) %>
    </div>
    """
  end
  
  # Agency detection and display logic
  
  defp agency_uses_pagination?(agency) when agency in [:hse, "hse"], do: true
  defp agency_uses_pagination?(_), do: false
  
  defp agency_display_name(:hse), do: "HSE"
  defp agency_display_name("hse"), do: "HSE"
  defp agency_display_name(:ea), do: "EA"
  defp agency_display_name("ea"), do: "EA"
  defp agency_display_name(agency), do: String.upcase(to_string(agency))
  
  # Progress calculation per agency
  
  defp calculate_progress_percentage(agency, progress) when agency in [:hse, "hse"] do
    hse_progress_percentage(progress)
  end
  
  defp calculate_progress_percentage(_agency, progress) do
    ea_progress_percentage(progress)
  end
  
  defp hse_progress_percentage(progress) do
    case progress.status do
      :idle -> 0
      :running when progress.pages_processed == 0 -> 5
      :running -> 
        # Calculate based on page range: (end_page - start_page) + 1
        start_page = Map.get(progress, :start_page, 1)
        end_page = Map.get(progress, :end_page, start_page + 9)
        total_pages_to_scrape = (end_page - start_page) + 1
        processed = Map.get(progress, :pages_processed, 0)
        # Ensure we don't exceed 95% until completed
        min(95, (processed / max(1, total_pages_to_scrape)) * 100)
      :completed -> 100
      :stopped -> Map.get(progress, :pages_processed, 0) * 10  # Rough estimate
      _ -> 0
    end
  end
  
  defp ea_progress_percentage(progress) do
    case progress.status do
      :idle -> 0
      :running -> 
        # Calculate based on cases processed vs cases found
        total_cases = max(1, progress.cases_found || 1)
        processed_cases = (progress.cases_created || 0) + 
                         (Map.get(progress, :cases_updated, 0)) + 
                         (progress.cases_exist_total || 0)
        # Ensure we don't exceed 95% until completed
        min(95, (processed_cases / total_cases) * 100)
      :completed -> 100
      :stopped -> 
        total_cases = max(1, progress.cases_found || 1)
        processed_cases = (progress.cases_created || 0) + 
                         (Map.get(progress, :cases_updated, 0)) + 
                         (progress.cases_exist_total || 0)
        (processed_cases / total_cases) * 100
      _ -> 0
    end
  end
  
  # Agency-specific progress displays
  
  defp render_page_based_progress(assigns) do
    ~H"""
    <!-- HSE Page-based Progress -->
    <%= if @progress.current_page do %>
      <div class="text-sm text-gray-600 mb-4">
        Currently processing page: <span class="font-medium"><%= @progress.current_page %></span>
      </div>
    <% end %>
    
    <!-- HSE-specific Statistics -->
    <div class="space-y-3">
      <div class="flex justify-between text-sm">
        <span class="text-gray-600">Pages Processed:</span>
        <span class="font-medium"><%= @progress.pages_processed %></span>
      </div>
    </div>
    """
  end
  
  defp render_case_based_progress(assigns) do
    ~H"""
    <!-- EA Case-based Progress -->
    <div class="text-sm text-gray-600 mb-4">
      Processing cases from EA enforcement data...
    </div>
    
    <!-- EA-specific Statistics -->
    <div class="space-y-3">
      <div class="flex justify-between text-sm">
        <span class="text-gray-600">Cases Processed:</span>
        <span class="font-medium">
          <%= (@progress.cases_created || 0) + 
              (Map.get(@progress, :cases_updated, 0)) + 
              (@progress.cases_exist_total || 0) %>
        </span>
      </div>
    </div>
    """
  end
  
  defp render_common_statistics(assigns) do
    ~H"""
    <!-- Common Statistics (shown for both agencies) -->
    <div class="space-y-3">
      <div class="flex justify-between text-sm">
        <span class="text-gray-600">Cases Found:</span>
        <span class="font-medium"><%= @progress.cases_found %></span>
      </div>
      <div class="flex justify-between text-sm">
        <span class="text-gray-600">Cases Created:</span>
        <span class="font-medium text-green-600"><%= @progress.cases_created %></span>
      </div>
      
      <%= if Map.get(@progress, :cases_updated, 0) > 0 do %>
        <div class="flex justify-between text-sm">
          <span class="text-gray-600">Cases Updated:</span>
          <span class="font-medium text-blue-600"><%= Map.get(@progress, :cases_updated, 0) %></span>
        </div>
      <% end %>
      
      <%= if (@progress.cases_exist_total || 0) > 0 do %>
        <div class="flex justify-between text-sm">
          <span class="text-gray-600">Cases Already Exist:</span>
          <span class="font-medium text-yellow-600"><%= @progress.cases_exist_total %></span>
        </div>
      <% end %>
      
      <%= if Map.get(@progress, :errors_count, 0) > 0 do %>
        <div class="flex justify-between text-sm">
          <span class="text-gray-600">Errors:</span>
          <span class="font-medium text-red-600"><%= Map.get(@progress, :errors_count, 0) %></span>
        </div>
      <% end %>
    </div>
    """
  end
  
  # Status and UI helper functions
  
  defp status_text(:idle), do: "Ready"
  defp status_text(:running), do: "Scraping in progress..."
  defp status_text(:completed), do: "Completed"
  defp status_text(:stopped), do: "Stopped"
  defp status_text(_), do: "Unknown"
  
  defp status_color(:idle), do: "bg-gray-300"
  defp status_color(:running), do: "bg-blue-500"
  defp status_color(:completed), do: "bg-green-500"
  defp status_color(:stopped), do: "bg-yellow-500"
  defp status_color(_), do: "bg-gray-300"
end