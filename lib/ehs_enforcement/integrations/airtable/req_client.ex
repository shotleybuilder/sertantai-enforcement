defmodule EhsEnforcement.Integrations.Airtable.ReqClient do
  @moduledoc """
  Modern Req-based Airtable API client with rate limiting and error handling.

  This client provides a unified interface for all Airtable operations with:
  - Consistent error handling
  - Rate limiting (5 requests/second)
  - Automatic retry with exponential backoff
  - Request/response logging
  - Standardized response format
  """

  require Logger
  alias EhsEnforcement.Integrations.Airtable.{Endpoint, Headers}

  @rate_limit_per_second 5
  @timeout 30_000
  @retry_attempts 3
  # 1 second
  @retry_base_delay 1000

  @type response ::
          {:ok, map()}
          | {:error,
             %{
               code: String.t(),
               details: term(),
               message: String.t(),
               type:
                 :bad_request
                 | :forbidden
                 | :network_error
                 | :not_found
                 | :rate_limit
                 | :server_error
                 | :timeout
                 | :unauthorized
                 | :unknown_error
                 | :validation_error
             }}
  @type http_method :: :get | :post | :patch | :delete

  @doc """
  Performs a GET request to the Airtable API.

  ## Examples
      iex> ReqClient.get("/appId/tableId", %{view: "Grid view"})
      {:ok, %{records: [...], offset: "..."}}
      
      iex> ReqClient.get("/invalid", %{})
      {:error, %{type: :not_found, code: "NOT_FOUND", message: "..."}}
  """
  @spec get(String.t(), map(), keyword()) :: response()
  def get(path, params \\ %{}, opts \\ []) do
    make_request(:get, path, nil, opts ++ [params: params])
  end

  @doc """
  Performs a POST request to the Airtable API.

  ## Examples
      iex> ReqClient.post("/appId/tableId", %{records: [...]})
      {:ok, %{records: [...]}}
  """
  @spec post(String.t(), map(), keyword()) :: response()
  def post(path, data, opts \\ []) do
    make_request(:post, path, data, opts)
  end

  @doc """
  Performs a PATCH request to the Airtable API.

  ## Examples
      iex> ReqClient.patch("/appId/tableId", %{records: [...]})
      {:ok, %{records: [...]}}
  """
  @spec patch(String.t(), map(), keyword()) :: response()
  def patch(path, data, opts \\ []) do
    make_request(:patch, path, data, opts)
  end

  @doc """
  Performs a DELETE request to the Airtable API.

  ## Examples
      iex> ReqClient.delete("/appId/tableId/recordId")
      {:ok, %{deleted: true, id: "recordId"}}
  """
  @spec delete(String.t(), keyword()) :: response()
  def delete(path, opts \\ []) do
    make_request(:delete, path, nil, opts)
  end

  @doc """
  Gets records with automatic pagination handling.

  Returns all records by following offset pagination automatically.
  """
  @spec get_all_records(String.t(), map(), keyword()) :: response()
  def get_all_records(path, params \\ %{}, opts \\ []) do
    get_all_records_recursive(path, params, opts, [], nil)
  end

  # Internal implementation

  @spec make_request(http_method(), String.t(), map() | nil, keyword()) :: response()
  defp make_request(method, path, data, opts, attempt \\ 1) do
    rate_limit_delay()

    req_opts = build_request_opts(method, path, data, opts)

    Logger.debug("Airtable API #{String.upcase(to_string(method))}: #{path}")

    case Req.request(req_opts) do
      {:ok, response} ->
        handle_response(response)

      {:error, error} when attempt < @retry_attempts ->
        if should_retry?(error, attempt) do
          delay = calculate_retry_delay(attempt)

          Logger.warning(
            "Airtable request failed (attempt #{attempt}/#{@retry_attempts}), retrying in #{delay}ms: #{inspect(error)}"
          )

          Process.sleep(delay)
          make_request(method, path, data, opts, attempt + 1)
        else
          handle_error(error)
        end

      {:error, error} ->
        Logger.error(
          "Airtable request failed after #{@retry_attempts} attempts: #{inspect(error)}"
        )

        handle_error(error)
    end
  end

  @spec build_request_opts(http_method(), String.t(), map() | nil, keyword()) :: keyword()
  defp build_request_opts(method, path, data, opts) do
    base_opts = [
      method: method,
      base_url: Endpoint.base_url(),
      url: path,
      headers: Headers.headers(),
      receive_timeout: @timeout,
      # We handle retries manually
      retry: false
    ]

    # Add JSON body for POST/PATCH requests
    body_opts =
      case {method, data} do
        {method, data} when method in [:post, :patch] and not is_nil(data) ->
          [json: data]

        _ ->
          []
      end

    # Add query parameters for GET requests
    param_opts =
      case Keyword.get(opts, :params) do
        params when is_map(params) and map_size(params) > 0 ->
          [params: params]

        _ ->
          []
      end

    base_opts ++ body_opts ++ param_opts ++ Keyword.drop(opts, [:params])
  end

  @spec handle_response(Req.Response.t()) :: response()
  defp handle_response(%{status: status, body: body}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response(%{status: 400, body: body}) do
    {:error,
     %{
       type: :bad_request,
       code: "BAD_REQUEST",
       message: extract_error_message(body),
       details: body
     }}
  end

  defp handle_response(%{status: 401, body: body}) do
    {:error,
     %{
       type: :unauthorized,
       code: "UNAUTHORIZED",
       message: "Invalid API key or insufficient permissions",
       details: body
     }}
  end

  defp handle_response(%{status: 403, body: body}) do
    {:error,
     %{
       type: :forbidden,
       code: "FORBIDDEN",
       message: "Access forbidden to this resource",
       details: body
     }}
  end

  defp handle_response(%{status: 404, body: body}) do
    {:error,
     %{
       type: :not_found,
       code: "NOT_FOUND",
       message: "Resource not found",
       details: body
     }}
  end

  defp handle_response(%{status: 422, body: body}) do
    {:error,
     %{
       type: :validation_error,
       code: "UNPROCESSABLE_ENTITY",
       message: extract_error_message(body),
       details: body
     }}
  end

  defp handle_response(%{status: 429, body: body}) do
    {:error,
     %{
       type: :rate_limit,
       code: "RATE_LIMITED",
       message: "Rate limit exceeded, please slow down",
       details: body
     }}
  end

  defp handle_response(%{status: status, body: body}) when status >= 500 do
    {:error,
     %{
       type: :server_error,
       code: "SERVER_ERROR",
       message: "Airtable server error (#{status})",
       details: body
     }}
  end

  defp handle_response(%{status: status, body: body}) do
    {:error,
     %{
       type: :unknown_error,
       code: "UNKNOWN_ERROR",
       message: "Unexpected response status: #{status}",
       details: body
     }}
  end

  @spec handle_error(term()) ::
          {:error,
           %{
             code: String.t(),
             details: %{original_error: map(), timeout: 30_000},
             message: String.t(),
             type: :network_error | :timeout
           }}
  defp handle_error(%{reason: :timeout}) do
    {:error,
     %{
       type: :timeout,
       code: "TIMEOUT",
       message: "Request timed out. Please try again.",
       details: %{timeout: @timeout}
     }}
  end

  defp handle_error(%{reason: :nxdomain}) do
    {:error,
     %{
       type: :network_error,
       code: "DNS_ERROR",
       message: "Could not resolve Airtable API hostname",
       details: %{}
     }}
  end

  defp handle_error(%{reason: :econnrefused}) do
    {:error,
     %{
       type: :network_error,
       code: "CONNECTION_REFUSED",
       message: "Connection to Airtable API was refused",
       details: %{}
     }}
  end

  defp handle_error(error) do
    {:error,
     %{
       type: :network_error,
       code: "NETWORK_ERROR",
       message: "Network error occurred: #{inspect(error)}",
       details: %{original_error: error}
     }}
  end

  @spec should_retry?(Exception.t(), 1 | 2) :: boolean()
  defp should_retry?(%{reason: :timeout}, _attempt), do: true
  defp should_retry?(%{reason: :econnrefused}, _attempt), do: true
  defp should_retry?(%{reason: :nxdomain}, _attempt), do: false
  defp should_retry?(_, _), do: false

  @spec calculate_retry_delay(1 | 2) :: integer()
  defp calculate_retry_delay(attempt) do
    # Exponential backoff: 1s, 2s, 4s, 8s...
    (@retry_base_delay * :math.pow(2, attempt - 1)) |> round()
  end

  @spec rate_limit_delay() :: :ok
  defp rate_limit_delay do
    # Simple rate limiting - wait between requests
    # In production, this could be more sophisticated (token bucket, etc.)
    delay_ms = div(1000, @rate_limit_per_second)
    Process.sleep(delay_ms)
  end

  @spec extract_error_message(map() | binary()) :: String.t()
  defp extract_error_message(%{"error" => %{"message" => message}}), do: message
  defp extract_error_message(%{"error" => message}) when is_binary(message), do: message
  defp extract_error_message(body) when is_binary(body), do: body
  defp extract_error_message(_), do: "Unknown error occurred"

  @spec get_all_records_recursive(String.t(), map(), keyword(), list(), String.t() | nil) ::
          response()
  defp get_all_records_recursive(path, params, opts, accumulated_records, offset) do
    # Add offset to params if we have one
    current_params =
      case offset do
        nil -> params
        offset -> Map.put(params, :offset, offset)
      end

    case get(path, current_params, opts) do
      {:ok, %{"records" => records, "offset" => next_offset}} ->
        new_accumulated = accumulated_records ++ records
        get_all_records_recursive(path, params, opts, new_accumulated, next_offset)

      {:ok, %{"records" => records}} ->
        # No more pages
        {:ok, %{"records" => accumulated_records ++ records}}

      {:error, error} ->
        {:error, error}
    end
  end

  # Development helpers

  @doc false
  def debug_url do
    fn request ->
      Logger.debug("Airtable URL: #{request.url}")
      request
    end
  end

  @doc false
  def debug_body do
    fn request ->
      if request.body do
        Logger.debug("Airtable Body: #{inspect(request.body)}")
      end

      request
    end
  end
end
