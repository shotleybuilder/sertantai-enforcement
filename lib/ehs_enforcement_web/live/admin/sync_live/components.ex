defmodule EhsEnforcementWeb.Admin.SyncLive.Components do
  @moduledoc """
  Reusable UI components for sync interfaces.
  Designed with package-ready architecture for future extraction.
  
  These components are generic and can be used with any sync operation
  or resource type, making them suitable for package extraction.
  """

  use Phoenix.Component
  import EhsEnforcementWeb.CoreComponents

  attr :session, :map, required: true, doc: "Sync session data"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def session_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
      status_badge_classes(@session.status),
      @class
    ]}>
      <%= status_text(@session.status) %>
    </span>
    """
  end

  attr :session, :map, required: true
  attr :show_details, :boolean, default: false
  attr :class, :string, default: ""

  def sync_progress_bar(assigns) do
    progress_percentage = calculate_progress_percentage(assigns.session)
    
    assigns = assign(assigns, :progress_percentage, progress_percentage)
    
    ~H"""
    <div class={["space-y-3", @class]}>
      <!-- Progress Bar -->
      <div class="relative">
        <div class="flex mb-2 items-center justify-between">
          <div>
            <span class="text-xs font-semibold inline-block py-1 px-2 uppercase rounded-full text-blue-600 bg-blue-200">
              <%= @session.sync_type %>
            </span>
          </div>
          <div class="text-right">
            <span class="text-xs font-semibold inline-block text-blue-600">
              <%= Float.round(@progress_percentage, 1) %>%
            </span>
          </div>
        </div>
        <div class="overflow-hidden h-2 mb-4 text-xs flex rounded bg-blue-200">
          <div
            style={"width: #{@progress_percentage}%"}
            class="shadow-none flex flex-col text-center whitespace-nowrap text-white justify-center bg-blue-500 transition-all duration-500"
          />
        </div>
      </div>

      <!-- Progress Details -->
      <div :if={@show_details} class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4 text-sm">
        <div class="text-center">
          <div class="text-2xl font-bold text-gray-900"><%= @session.processed_records || 0 %></div>
          <div class="text-gray-500">Processed</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-bold text-green-600"><%= @session.created_records || 0 %></div>
          <div class="text-gray-500">Created</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-bold text-blue-600"><%= @session.updated_records || 0 %></div>
          <div class="text-gray-500">Updated</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-bold text-yellow-600"><%= @session.existing_records || 0 %></div>
          <div class="text-gray-500">Existing</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-bold text-red-600"><%= @session.error_records || 0 %></div>
          <div class="text-gray-500">Errors</div>
        </div>
      </div>

      <!-- Timing Information -->
      <div :if={@show_details and @session.started_at} class="text-xs text-gray-500 space-y-1">
        <div>Started: <%= format_datetime(@session.started_at) %></div>
        <div :if={@session.completed_at}>Completed: <%= format_datetime(@session.completed_at) %></div>
        <div :if={duration = calculate_duration(@session)}>Duration: <%= format_duration(duration) %></div>
      </div>
    </div>
    """
  end

  attr :config, :map, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :disabled, :boolean, default: false
  attr :class, :string, default: ""

  def sync_configuration_panel(assigns) do
    ~H"""
    <div class={["bg-white shadow rounded-lg p-6", @class]}>
      <h3 class="text-lg font-medium text-gray-900 mb-4">Sync Configuration</h3>
      
      <.form :let={f} for={@form} class="space-y-4">
        <!-- Sync Type Selection -->
        <div class="space-y-2">
          <.label for="sync_type">Import Type</.label>
          <.input 
            field={f[:sync_type]} 
            type="select" 
            options={sync_type_options()}
            disabled={@disabled}
            placeholder="Select import type"
          />
        </div>

        <!-- Batch Size -->
        <div class="space-y-2">
          <.label for="batch_size">Batch Size</.label>
          <.input 
            field={f[:batch_size]} 
            type="number" 
            min="1" 
            max="500" 
            disabled={@disabled}
            placeholder="100"
          />
          <p class="text-sm text-gray-500">Number of records to process per batch (1-500)</p>
        </div>

        <!-- Record Limit -->
        <div class="space-y-2">
          <.label for="limit">Record Limit</.label>
          <.input 
            field={f[:limit]} 
            type="number" 
            min="1" 
            max="10000" 
            disabled={@disabled}
            placeholder="1000"
          />
          <p class="text-sm text-gray-500">Maximum records to import (1-10,000)</p>
        </div>

        <!-- Dry Run Toggle -->
        <div class="flex items-start">
          <div class="flex items-center h-5">
            <.input 
              field={f[:dry_run]} 
              type="checkbox" 
              disabled={@disabled}
            />
          </div>
          <div class="ml-3 text-sm">
            <.label for="dry_run" class="font-medium text-gray-700">Dry Run Mode</.label>
            <p class="text-gray-500">Preview changes without actually importing data</p>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  attr :session, :map, required: true
  attr :on_start, :string, required: true
  attr :on_stop, :string, required: true
  attr :disabled, :boolean, default: false
  attr :class, :string, default: ""

  def sync_control_buttons(assigns) do
    ~H"""
    <div class={["flex space-x-3", @class]}>
      <button
        :if={can_start_sync?(@session)}
        phx-click={@on_start}
        disabled={@disabled}
        class="flex-1 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed text-white font-medium py-2 px-4 rounded-md transition-colors duration-200"
      >
        <.icon name="hero-play" class="w-4 h-4 inline mr-2" />
        Start Sync
      </button>

      <button
        :if={can_stop_sync?(@session)}
        phx-click={@on_stop}
        disabled={@disabled}
        class="flex-1 bg-red-600 hover:bg-red-700 disabled:bg-gray-300 disabled:cursor-not-allowed text-white font-medium py-2 px-4 rounded-md transition-colors duration-200"
      >
        <.icon name="hero-stop" class="w-4 h-4 inline mr-2" />
        Stop Sync
      </button>

      <div
        :if={is_sync_running?(@session)}
        class="flex-1 bg-yellow-100 border border-yellow-300 text-yellow-800 font-medium py-2 px-4 rounded-md text-center"
      >
        <.icon name="hero-clock" class="w-4 h-4 inline mr-2 animate-spin" />
        Sync Running...
      </div>
    </div>
    """
  end

  attr :batches, :list, required: true
  attr :class, :string, default: ""

  def batch_progress_list(assigns) do
    ~H"""
    <div class={["bg-white shadow rounded-lg", @class]}>
      <div class="px-6 py-4 border-b border-gray-200">
        <h3 class="text-lg font-medium text-gray-900">Batch Progress</h3>
      </div>
      
      <div class="divide-y divide-gray-200 max-h-96 overflow-y-auto">
        <div
          :for={batch <- @batches}
          class="px-6 py-4 hover:bg-gray-50 transition-colors duration-150"
        >
          <div class="flex justify-between items-start">
            <div class="flex-1">
              <div class="flex items-center space-x-3">
                <span class="text-sm font-medium text-gray-900">
                  Batch #<%= batch.batch_number %>
                </span>
                <.batch_status_badge status={batch.status} />
              </div>
              
              <div class="mt-2 text-sm text-gray-600">
                <span><%= batch.batch_size %> records</span>
                <span :if={batch.records_processed}>• <%= batch.records_processed %> processed</span>
                <span :if={batch.records_failed && batch.records_failed > 0} class="text-red-600">
                  • <%= batch.records_failed %> failed
                </span>
              </div>
            </div>
            
            <div class="text-right text-xs text-gray-500">
              <%= format_batch_timing(batch) %>
            </div>
          </div>
          
          <!-- Progress Bar for Individual Batch -->
          <div :if={batch.batch_size > 0} class="mt-3">
            <div class="w-full bg-gray-200 rounded-full h-1.5">
              <div
                class="bg-blue-600 h-1.5 rounded-full transition-all duration-300"
                style={"width: #{calculate_batch_progress(batch)}%"}
              />
            </div>
          </div>
        </div>
        
        <div :if={Enum.empty?(@batches)} class="px-6 py-8 text-center text-gray-500">
          No batch data available
        </div>
      </div>
    </div>
    """
  end

  attr :errors, :list, required: true
  attr :class, :string, default: ""

  def sync_error_panel(assigns) do
    ~H"""
    <div :if={not Enum.empty?(@errors)} class={["bg-red-50 border border-red-200 rounded-lg p-4", @class]}>
      <div class="flex">
        <div class="flex-shrink-0">
          <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-red-400" />
        </div>
        <div class="ml-3">
          <h3 class="text-sm font-medium text-red-800">
            Sync Errors (<%= length(@errors) %>)
          </h3>
          <div class="mt-2 text-sm text-red-700">
            <ul class="list-disc list-inside space-y-1">
              <li :for={error <- Enum.take(@errors, 5)}>
                <%= format_error(error) %>
              </li>
              <li :if={length(@errors) > 5} class="text-red-600">
                ... and <%= length(@errors) - 5 %> more errors
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :stats, :map, required: true
  attr :class, :string, default: ""

  def sync_stats_overview(assigns) do
    ~H"""
    <div class={["bg-white shadow rounded-lg p-6", @class]}>
      <h3 class="text-lg font-medium text-gray-900 mb-4">Sync Statistics</h3>
      
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <!-- Current Session Stats -->
        <div>
          <h4 class="text-sm font-medium text-gray-500 mb-3">Current Session</h4>
          <div class="space-y-2">
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">Status:</span>
              <.session_status_badge session={@stats} />
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">Progress:</span>
              <span class="text-sm font-medium"><%= Float.round(calculate_progress_percentage(@stats), 1) %>%</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">Duration:</span>
              <span class="text-sm font-medium"><%= format_duration(calculate_duration(@stats)) %></span>
            </div>
          </div>
        </div>

        <!-- Record Statistics -->
        <div>
          <h4 class="text-sm font-medium text-gray-500 mb-3">Record Statistics</h4>
          <div class="space-y-2">
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">Total:</span>
              <span class="text-sm font-medium"><%= @stats.total_records || 0 %></span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">Processed:</span>
              <span class="text-sm font-medium text-blue-600"><%= @stats.processed_records || 0 %></span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">Success Rate:</span>
              <span class="text-sm font-medium text-green-600"><%= calculate_success_rate(@stats) %>%</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Private helper functions

  defp status_badge_classes(status) do
    case status do
      :pending -> "bg-gray-100 text-gray-800"
      :running -> "bg-blue-100 text-blue-800"
      :completed -> "bg-green-100 text-green-800"
      :failed -> "bg-red-100 text-red-800"
      :cancelled -> "bg-yellow-100 text-yellow-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp status_text(status) do
    case status do
      :pending -> "Pending"
      :running -> "Running"
      :completed -> "Completed"
      :failed -> "Failed"
      :cancelled -> "Cancelled"
      _ -> "Unknown"
    end
  end

  defp batch_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2 py-1 rounded-full text-xs font-medium",
      batch_status_classes(@status)
    ]}>
      <%= batch_status_text(@status) %>
    </span>
    """
  end

  defp batch_status_classes(status) do
    case status do
      :pending -> "bg-gray-100 text-gray-700"
      :processing -> "bg-blue-100 text-blue-700"
      :completed -> "bg-green-100 text-green-700"
      :failed -> "bg-red-100 text-red-700"
      :retrying -> "bg-yellow-100 text-yellow-700"
      _ -> "bg-gray-100 text-gray-700"
    end
  end

  defp batch_status_text(status) do
    case status do
      :pending -> "Pending"
      :processing -> "Processing"
      :completed -> "Completed"
      :failed -> "Failed"
      :retrying -> "Retrying"
      _ -> "Unknown"
    end
  end

  defp sync_type_options do
    [
      {"Import Cases", "import_cases"},
      {"Import Notices", "import_notices"},
      {"Import All Data", "import_all"},
      {"Export Cases", "export_cases"},
      {"Export Notices", "export_notices"}
    ]
  end

  defp calculate_progress_percentage(session) do
    total = session.total_records || 0
    processed = session.processed_records || 0
    
    if total > 0 do
      (processed / total) * 100
    else
      0.0
    end
  end

  defp calculate_batch_progress(batch) do
    batch_size = batch.batch_size || 0
    processed = batch.records_processed || 0
    
    if batch_size > 0 do
      (processed / batch_size) * 100
    else
      0.0
    end
  end

  defp calculate_duration(session) do
    case {session.started_at, session.completed_at} do
      {%DateTime{} = started, %DateTime{} = completed} ->
        DateTime.diff(completed, started, :second)
      {%DateTime{} = started, nil} ->
        DateTime.diff(DateTime.utc_now(), started, :second)
      _ ->
        0
    end
  end

  defp calculate_success_rate(stats) do
    total = (stats.processed_records || 0)
    failed = (stats.error_records || 0)
    
    if total > 0 do
      success = total - failed
      Float.round((success / total) * 100, 1)
    else
      100.0
    end
  end

  defp format_datetime(datetime) do
    case datetime do
      %DateTime{} -> 
        datetime
        |> DateTime.shift_zone!("Etc/UTC")
        |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")
      _ -> 
        "N/A"
    end
  end

  defp format_duration(seconds) when is_integer(seconds) do
    cond do
      seconds < 60 -> "#{seconds}s"
      seconds < 3600 -> "#{div(seconds, 60)}m #{rem(seconds, 60)}s"
      true -> "#{div(seconds, 3600)}h #{div(rem(seconds, 3600), 60)}m"
    end
  end
  defp format_duration(_), do: "N/A"

  defp format_batch_timing(batch) do
    case {batch.started_at, batch.completed_at} do
      {%DateTime{} = started, %DateTime{} = completed} ->
        duration = DateTime.diff(completed, started, :second)
        "#{format_duration(duration)}"
      {%DateTime{} = started, nil} ->
        duration = DateTime.diff(DateTime.utc_now(), started, :second)
        "Running #{format_duration(duration)}"
      _ ->
        "N/A"
    end
  end

  defp format_error(error) when is_map(error) do
    Map.get(error, :message, Map.get(error, :error, "Unknown error"))
  end
  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)

  defp can_start_sync?(session) do
    session.status in [:pending, :failed, :cancelled]
  end

  defp can_stop_sync?(session) do
    session.status in [:running, :pending]
  end

  defp is_sync_running?(session) do
    session.status == :running
  end
end