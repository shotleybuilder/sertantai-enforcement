defmodule EhsEnforcement.Sync.ProgressSupervisor do
  @moduledoc """
  Supervisor for progress streaming processes.
  Manages multiple concurrent progress streamers for different sync sessions.
  """
  
  use DynamicSupervisor
  
  alias EhsEnforcement.Sync.ProgressStreamer
  require Logger
  
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
  
  @doc """
  Start a progress streamer for a sync session.
  """
  def start_streamer(session_id, opts \\ []) do
    child_spec = {ProgressStreamer, Keyword.put(opts, :session_id, session_id)}
    
    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        Logger.info("Started progress streamer for session #{session_id}")
        {:ok, pid}
        
      {:error, {:already_started, pid}} ->
        Logger.info("Progress streamer already running for session #{session_id}")
        {:ok, pid}
        
      error ->
        Logger.error("Failed to start progress streamer for session #{session_id}: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Stop a progress streamer for a sync session.
  """
  def stop_streamer(session_id) do
    case ProgressStreamer.stop_streaming(session_id) do
      :ok -> 
        Logger.info("Stopped progress streamer for session #{session_id}")
        :ok
      error -> 
        Logger.warning("Failed to stop progress streamer for session #{session_id}: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Get all running progress streamers.
  """
  def list_streamers do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.filter(&Process.alive?/1)
  end
  
  @doc """
  Get count of active streamers.
  """
  def streamer_count do
    DynamicSupervisor.count_children(__MODULE__).active
  end
end