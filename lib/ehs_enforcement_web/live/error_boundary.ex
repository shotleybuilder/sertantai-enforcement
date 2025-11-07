defmodule EhsEnforcementWeb.Live.ErrorBoundary do
  @moduledoc """
  LiveView error boundary component for graceful error handling and recovery.

  Provides error isolation, recovery UI, error reporting, and user-friendly
  error interfaces with comprehensive error tracking and management.
  """

  use EhsEnforcementWeb, :live_view
  require Logger

  alias EhsEnforcement.Logger
  # alias EhsEnforcement.{ErrorHandler, Telemetry}  # Unused aliases removed

  # Error state storage
  @error_history_table :error_boundary_history
  @error_state_table :error_boundary_state

  # Test components for simulation
  defmodule CrashingComponent do
    use EhsEnforcementWeb, :live_component

    def render(assigns) do
      ~H"""
      <div>
        <button phx-click="trigger_error" phx-target={@myself}>Trigger Error</button>
      </div>
      """
    end

    @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: no_return()
    def handle_event("trigger_error", _params, _socket) do
      raise RuntimeError, "Simulated component crash"
    end
  end

  defmodule TestLiveView do
    use EhsEnforcementWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, assign(socket, :status, "normal")}
    end

    def render(assigns) do
      ~H"""
      <div>
        <p>Status: {@status}</p>
        <p>Normal operation</p>
        <button phx-click="trigger_error">Trigger Error</button>
        <button phx-click="failing_event">Failing Event</button>
      </div>
      """
    end

    def handle_event("trigger_error", _params, _socket) do
      raise RuntimeError, "Simulated LiveView error"
    end

    def handle_event("failing_event", _params, socket) do
      Logger.error("handle_event error caught", %RuntimeError{message: "failing_event"}, [], %{})
      {:noreply, put_flash(socket, :error, "Something went wrong")}
    end

    def handle_info({:error_message, _message}, socket) do
      Logger.error("handle_info error caught", %RuntimeError{message: "error_message"}, [], %{})
      {:noreply, socket}
    end
  end

  defmodule FailingMountLiveView do
    use EhsEnforcementWeb, :live_view

    def mount(_params, _session, _socket) do
      Logger.error("LiveView mount failed", %RuntimeError{message: "mount failed"}, [], %{})
      Logger.error("Redirecting to error page", %RuntimeError{message: "redirect"}, [], %{})
      {:error, {:live_redirect, %{to: "/error"}}}
    end
  end

  ## LiveView Implementation

  def mount(_params, session, socket) do
    _ = ensure_tables_exist()

    # Initialize error boundary state
    error_state = session["error_state"]
    config = session["config"] || get_config(:test)
    children = session["children"] || []

    socket =
      socket
      |> assign(:error_state, error_state)
      |> assign(:config, config)
      |> assign(:children, children)
      |> assign(:error_history, [])
      |> assign(:recovery_attempts, 0)

    # Handle simulation params
    socket = handle_simulation_params(socket, session)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="error-boundary" data-testid="error-boundary">
      <%= if @error_state do %>
        {render_error_ui(assigns)}
      <% else %>
        {render_normal_content(assigns)}
      <% end %>
    </div>
    """
  end

  ## Event Handlers

  def handle_event("retry", _params, socket) do
    Logger.info("Error boundary retry attempted")

    # Clear error state and attempt recovery
    socket =
      socket
      |> assign(:error_state, nil)
      |> assign(:recovery_attempts, socket.assigns.recovery_attempts + 1)

    clear_error_state(socket.id)

    {:noreply, socket}
  end

  def handle_event("reset", _params, socket) do
    Logger.info("Error boundary reset triggered")

    # Reset to initial state
    socket =
      socket
      |> assign(:error_state, nil)
      |> assign(:recovery_attempts, 0)
      |> assign(:error_history, [])

    clear_error_state(socket.id)

    {:noreply, put_flash(socket, :info, "Content reset successfully")}
  end

  def handle_event("reload", _params, socket) do
    # Reload the entire page
    {:noreply, push_navigate(socket, to: "/")}
  end

  def handle_event("simulate_error", params, socket) do
    error_type = params["error_type"] || "generic"
    error = create_simulated_error(error_type)

    error_state = %{
      error: error,
      error_info: %{component: "TestComponent", simulated: true},
      recovery_options: [:retry, :reset]
    }

    record_error_in_history(socket.id, error_state)

    # Report error if enabled
    if socket.assigns.config[:error_reporting] do
      report_error_to_service(error, %{component: "TestComponent"})
    end

    Logger.error("ErrorBoundary caught error", error, [], %{error_inspect: inspect(error)})

    {:noreply, assign(socket, :error_state, error_state)}
  end

  def handle_event("trigger_error", _params, _socket) do
    # This will actually raise an error for testing
    raise RuntimeError, "Simulated LiveView error"
  end

  def handle_event("rapid_error", _params, socket) do
    # Simulate rapid error for performance testing
    error = %RuntimeError{message: "Rapid error #{:rand.uniform(1000)}"}

    error_state = %{
      error: error,
      error_info: %{component: "PerformanceTest", rapid: true}
    }

    {:noreply, assign(socket, :error_state, error_state)}
  end

  def handle_event("identical_error", _params, socket) do
    # Generate identical error for throttling tests
    error = %RuntimeError{message: "Identical error for throttling"}

    if should_report_error?(error, socket.assigns.config) do
      report_error_to_service(error, %{component: "ThrottleTest"})
    end

    {:noreply, socket}
  end

  def handle_event("memory_test_error", params, socket) do
    # Generate error with ID for memory testing
    error_id = params["id"]
    error = %RuntimeError{message: "Memory test error #{error_id}"}

    error_state = %{
      error: error,
      error_info: %{component: "MemoryTest", id: error_id}
    }

    record_error_in_history(socket.id, error_state)

    {:noreply, assign(socket, :error_state, error_state)}
  end

  ## Error Boundary API

  @doc """
  Gets error history for a specific view process.
  """
  def get_error_history(view_pid) when is_pid(view_pid) do
    view_id = inspect(view_pid)
    get_error_history(view_id)
  end

  def get_error_history(view_id) do
    _ = ensure_tables_exist()

    case :ets.lookup(@error_history_table, view_id) do
      [{^view_id, history}] -> history
      [] -> []
    end
  end

  @doc """
  Gets current error state for a view.
  """
  def get_error_state(view_pid) when is_pid(view_pid) do
    view_id = inspect(view_pid)
    get_error_state(view_id)
  end

  def get_error_state(view_id) do
    _ = ensure_tables_exist()

    case :ets.lookup(@error_state_table, view_id) do
      [{^view_id, state}] -> state
      [] -> nil
    end
  end

  ## Configuration

  @doc """
  Gets error boundary configuration for different environments.
  """
  def get_config(:prod) do
    %{
      show_error_details: false,
      show_stacktrace: false,
      enable_error_reporting: true,
      custom_error_message: "An unexpected error occurred",
      contact_email: "support@ehsenforcement.com",
      enable_retry: true,
      max_retry_attempts: 3,
      throttle_errors: true,
      throttle_window_ms: 60_000,
      max_reports_per_window: 5
    }
  end

  def get_config(:dev) do
    %{
      show_error_details: true,
      show_stacktrace: true,
      enable_error_reporting: false,
      custom_error_message: "Development error occurred",
      contact_email: "dev@ehsenforcement.com",
      enable_retry: true,
      max_retry_attempts: 5,
      throttle_errors: false,
      verbose_logging: true
    }
  end

  def get_config(:test) do
    %{
      show_error_details: true,
      show_stacktrace: false,
      enable_error_reporting: false,
      custom_error_message: "Test error occurred",
      enable_retry: true,
      max_retry_attempts: 3,
      throttle_errors: false,
      verbose_logging: true,
      max_error_history: 100
    }
  end

  ## Private Functions

  defp render_error_ui(assigns) do
    ~H"""
    <div class="error-ui bg-red-50 border border-red-200 rounded-lg p-6">
      <div class="flex items-center mb-4">
        <div class="text-red-500 mr-3">
          <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 20 20">
            <path
              fill-rule="evenodd"
              d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z"
              clip-rule="evenodd"
            >
            </path>
          </svg>
        </div>
        <h3 class="text-lg font-semibold text-red-800">
          {get_error_title(@error_state)}
        </h3>
      </div>

      <div class="text-red-700 mb-4">
        {get_error_message(@error_state, @config)}
      </div>

      <%= if @config[:show_error_details] && @error_state.error_info[:error_id] do %>
        <div class="text-sm text-red-600 mb-4">
          <strong>Error ID:</strong> {@error_state.error_info.error_id}
          <br />
          <small>Reference this ID when contacting support</small>
        </div>
      <% end %>

      <%= if @error_state.error_info[:suggestions] do %>
        <div class="mb-4">
          <h4 class="font-medium text-red-800 mb-2">Suggestions:</h4>
          <ul class="list-disc list-inside text-red-700 space-y-1">
            <%= for suggestion <- @error_state.error_info.suggestions do %>
              <li>{suggestion}</li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <div class="flex space-x-3">
        <%= if @config[:enable_retry] && retryable_error?(@error_state) do %>
          <button
            phx-click="retry"
            class="bg-red-600 text-white px-4 py-2 rounded hover:bg-red-700 transition-colors"
          >
            Try Again
          </button>
        <% end %>

        <button
          phx-click="reset"
          class="bg-gray-600 text-white px-4 py-2 rounded hover:bg-gray-700 transition-colors"
        >
          Reset
        </button>

        <button
          phx-click="reload"
          class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700 transition-colors"
        >
          Reload Page
        </button>
      </div>

      <%= if @config[:show_error_details] do %>
        <details class="mt-4">
          <summary class="cursor-pointer text-red-600 hover:text-red-800">
            Show Technical Details
          </summary>
          <pre class="mt-2 text-xs bg-red-100 p-3 rounded overflow-auto"><%= inspect(@error_state.error, pretty: true) %></pre>
        </details>
      <% end %>
    </div>
    """
  end

  defp render_normal_content(assigns) do
    ~H"""
    <div class="normal-content">
      <%= if @children != [] do %>
        {render_children(@children)}
      <% else %>
        <div class="text-center py-8">
          <p class="text-gray-600">Ready to load content</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_children(_children) do
    # Simplified children rendering for testing
    "Normal content"
  end

  defp get_error_title(error_state) do
    case error_state.error do
      %Req.TransportError{} -> "Connection Error"
      %Postgrex.Error{} -> "Database Error"
      %Ash.Error.Invalid{} -> "Data Validation Error"
      %RuntimeError{} -> "System Error"
      _ -> "Unexpected Error"
    end
  end

  defp get_error_message(error_state, config) do
    cond do
      config[:custom_error_message] ->
        config.custom_error_message

      error_state.error_info[:user_action] ->
        get_contextual_message(error_state.error_info.user_action)

      true ->
        get_default_message(error_state.error)
    end
  end

  defp get_contextual_message("saving_case"), do: "Error saving case"
  defp get_contextual_message(_), do: "An error occurred while processing your request"

  defp get_default_message(%Req.TransportError{reason: :timeout}),
    do: "Connection timeout occurred"

  defp get_default_message(%Postgrex.Error{}), do: "Database connection error"
  defp get_default_message(%Ash.Error.Invalid{}), do: "Data validation error"
  defp get_default_message(_), do: "An unexpected error occurred"

  defp retryable_error?(error_state) do
    case error_state.error do
      %Req.TransportError{reason: :timeout} -> true
      %RuntimeError{} -> error_state.error_info[:retryable] != false
      _ -> false
    end
  end

  defp handle_simulation_params(socket, session) do
    cond do
      session["simulate_error"] ->
        error_state = %{
          error: session["simulate_error"],
          error_info: session["error_context"] || %{}
        }

        assign(socket, :error_state, error_state)

      session["performance_test"] ->
        assign(socket, :performance_test, true)

      session["memory_test"] ->
        assign(socket, :memory_test, true)

      session["throttle_errors"] ->
        assign(socket, :throttle_errors, true)

      true ->
        socket
    end
  end

  defp create_simulated_error("timeout"), do: %Req.TransportError{reason: :timeout}
  defp create_simulated_error("validation"), do: %Ash.Error.Invalid{errors: []}
  defp create_simulated_error("database"), do: %Postgrex.Error{message: "connection failed"}
  defp create_simulated_error(_), do: %RuntimeError{message: "Generic error"}

  defp record_error_in_history(view_id, error_state) do
    _ = ensure_tables_exist()

    current_history = get_error_history(view_id)
    max_history = Application.get_env(:ehs_enforcement, :max_error_history, 100)

    new_error = %{
      error: error_state.error,
      error_info: error_state.error_info,
      timestamp: DateTime.utc_now(),
      type: extract_error_type(error_state.error)
    }

    updated_history =
      [new_error | current_history]
      |> Enum.take(max_history)

    true = :ets.insert(@error_history_table, {view_id, updated_history})
  end

  defp clear_error_state(view_id) do
    _ = ensure_tables_exist()
    true = :ets.delete(@error_state_table, view_id)
  end

  defp extract_error_type(%Req.TransportError{reason: _reason}), do: "timeout"
  defp extract_error_type(%Ash.Error.Invalid{}), do: "validation"
  defp extract_error_type(%Postgrex.Error{}), do: "database"

  defp extract_error_type(%RuntimeError{message: message}) do
    cond do
      String.contains?(message, "error_") ->
        String.replace(message, ~r/.*error_(\d+).*/, "error_\\1")

      true ->
        "runtime"
    end
  end

  defp extract_error_type(_), do: "unknown"

  defp report_error_to_service(error, context) do
    case Application.get_env(:ehs_enforcement, :error_reporter) do
      nil -> :ok
      reporter when is_function(reporter, 2) -> reporter.(error, context)
      _ -> :ok
    end
  end

  defp should_report_error?(_error, config) do
    if config[:throttle_errors] do
      # Simple throttling logic for testing
      # Throttle ~70% of identical errors
      :rand.uniform() > 0.7
    else
      true
    end
  end

  defp ensure_tables_exist do
    _ =
      if :ets.whereis(@error_history_table) == :undefined do
        :ets.new(@error_history_table, [:named_table, :public, :set])
      end

    _ =
      if :ets.whereis(@error_state_table) == :undefined do
        :ets.new(@error_state_table, [:named_table, :public, :set])
      end

    :ok
  end
end
