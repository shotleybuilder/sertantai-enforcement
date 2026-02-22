defmodule EhsEnforcement.Auth.JwksClient do
  @moduledoc """
  Fetches and caches the EdDSA public key from sertantai-auth's JWKS endpoint.
  """
  use GenServer
  require Logger

  @refresh_interval :timer.hours(1)
  @retry_interval :timer.seconds(30)

  # Client API

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec public_key() :: {:ok, JOSE.JWK.t()} | {:error, :no_key}
  def public_key, do: GenServer.call(__MODULE__, :public_key)

  @spec refresh() :: :ok
  def refresh, do: GenServer.cast(__MODULE__, :refresh)

  @spec set_test_key(JOSE.JWK.t() | nil) :: :ok
  def set_test_key(jwk), do: GenServer.call(__MODULE__, {:set_test_key, jwk})

  # Server callbacks

  @impl true
  def init(_opts) do
    if Application.get_env(:ehs_enforcement, :test_mode, false) do
      Logger.info("JWKS Client started in test mode (no HTTP fetch)")
      {:ok, %{key: nil}}
    else
      send(self(), :fetch)
      {:ok, %{key: nil}}
    end
  end

  @impl true
  def handle_call(:public_key, _from, state) do
    case state.key do
      nil -> {:reply, {:error, :no_key}, state}
      jwk -> {:reply, {:ok, jwk}, state}
    end
  end

  def handle_call({:set_test_key, jwk}, _from, state) do
    {:reply, :ok, %{state | key: jwk}}
  end

  @impl true
  def handle_cast(:refresh, state) do
    case fetch_jwks() do
      {:ok, jwk} ->
        schedule_refresh(@refresh_interval)
        {:noreply, %{state | key: jwk}}

      {:error, reason} ->
        Logger.warning("JWKS refresh failed: #{inspect(reason)}, keeping existing key")
        schedule_refresh(@retry_interval)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:fetch, state) do
    case fetch_jwks() do
      {:ok, jwk} ->
        Logger.info("JWKS public key fetched successfully")
        schedule_refresh(@refresh_interval)
        {:noreply, %{state | key: jwk}}

      {:error, reason} ->
        Logger.warning("JWKS fetch failed: #{inspect(reason)}, retrying in 30s")
        schedule_refresh(@retry_interval)
        {:noreply, state}
    end
  end

  defp fetch_jwks do
    auth_url = Application.get_env(:ehs_enforcement, :auth_url)
    unless auth_url, do: raise("auth_url not configured")

    url = "#{auth_url}/.well-known/jwks.json"

    case Req.get(url, receive_timeout: 10_000, retry: false, plug: req_plug()) do
      {:ok, %Req.Response{status: 200, body: %{"keys" => [key | _]}}} ->
        {:ok, JOSE.JWK.from_map(key)}

      {:ok, %Req.Response{status: 200, body: %{"keys" => []}}} ->
        {:error, :no_keys_in_jwks}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:unexpected_status, status}}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, {:transport, reason}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp schedule_refresh(interval), do: Process.send_after(self(), :fetch, interval)

  defp req_plug, do: Application.get_env(:ehs_enforcement, :jwks_req_plug)
end
