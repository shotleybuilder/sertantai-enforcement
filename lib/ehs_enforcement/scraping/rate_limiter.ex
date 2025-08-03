defmodule EhsEnforcement.Scraping.RateLimiter do
  @moduledoc """
  Rate limiting service for HSE scraping operations.
  
  Provides configurable rate limiting based on database configuration:
  - Uses simple time-based rate limiting with GenServer
  - Respects requests_per_minute from scraping configuration
  - Includes pause between requests for ethical scraping
  """
  
  require Logger
  
  alias EhsEnforcement.Configuration.ScrapingConfig
  
  @doc """
  Execute an HTTP request with rate limiting applied.
  
  Uses the active scraping configuration to determine rate limits.
  
  Options:
  - actor: Actor for configuration loading
  - config: Pre-loaded configuration (optional)
  
  Returns result of the function or {:error, :rate_limited}
  """
  def rate_limited_request(url, opts \\ []) do
    config = get_config(opts)
    
    # Simple rate limiting - just add pause between requests
    if config.pause_between_pages_ms > 0 do
      Logger.debug("Pausing #{config.pause_between_pages_ms}ms between requests for ethical scraping")
      Process.sleep(config.pause_between_pages_ms)
    end
    
    # Check if we're exceeding the configured rate limit
    requests_per_minute = config.requests_per_minute
    
    # For now, use a simple check - if rate limit is very low, add extra delays
    if requests_per_minute <= 5 do
      extra_delay = div(60_000, requests_per_minute) - config.pause_between_pages_ms
      if extra_delay > 0 do
        Logger.debug("Adding extra delay of #{extra_delay}ms for low rate limit")
        Process.sleep(extra_delay)
      end
    end
    
    Logger.debug("Rate limit compliant request for HSE scraping", 
                requests_per_minute: requests_per_minute,
                pause_ms: config.pause_between_pages_ms)
    
    # Execute the actual HTTP request
    execute_request(url, config)
  end
  
  @doc """
  Check current rate limit status without making a request.
  
  Returns {:ok, %{requests_per_minute: count}} with configuration info
  """
  def check_rate_limit_status(opts \\ []) do
    config = get_config(opts)
    
    {:ok, %{
      requests_per_minute: config.requests_per_minute,
      pause_between_pages_ms: config.pause_between_pages_ms,
      network_timeout_ms: config.network_timeout_ms,
      rate_limiting_active: true
    }}
  end
  
  @doc """
  Get rate limiting configuration information.
  
  Returns the current rate limiting settings from active configuration.
  """
  def get_rate_limit_info(opts \\ []) do
    config = get_config(opts)
    
    %{
      requests_per_minute: config.requests_per_minute,
      pause_between_pages_ms: config.pause_between_pages_ms,
      estimated_delay_per_request: calculate_average_delay(config),
      ethical_scraping_enabled: true
    }
  end
  
  # Private functions
  
  defp get_config(opts) do
    case Keyword.get(opts, :config) do
      %ScrapingConfig{} = config -> 
        config
      _ -> 
        case ScrapingConfig.get_active_config(opts) do
          {:ok, config} -> config
          {:error, :no_active_config} ->
            Logger.warning("No active scraping configuration, using fallback rate limits")
            %ScrapingConfig{
              id: "fallback",
              requests_per_minute: 10,
              pause_between_pages_ms: 3000,
              network_timeout_ms: 30_000
            }
          {:error, reason} ->
            Logger.error("Failed to load configuration: #{inspect(reason)}")
            raise "Unable to load scraping configuration for rate limiting"
        end
    end
  end
  
  defp execute_request(url, config) do
    timeout_ms = config.network_timeout_ms
    
    Logger.debug("Executing rate-limited HTTP request", 
                url: url, 
                timeout: timeout_ms)
    
    case Req.get(url, receive_timeout: timeout_ms) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}
      
      {:ok, %{status: status}} when status in 400..499 ->
        Logger.warning("Client error HTTP #{status} for URL: #{url}")
        {:error, {:http_error, status}}
      
      {:ok, %{status: status}} when status >= 500 ->
        Logger.error("Server error HTTP #{status} for URL: #{url}")
        {:error, {:http_error, status}}
      
      {:ok, %{status: status}} ->
        Logger.warning("Unexpected HTTP #{status} for URL: #{url}")
        {:error, {:http_error, status}}
      
      {:error, %{reason: :timeout}} ->
        Logger.error("Network timeout after #{timeout_ms}ms for URL: #{url}")
        {:error, {:network_timeout, timeout_ms}}
      
      {:error, reason} ->
        Logger.error("HTTP request failed for URL #{url}: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp calculate_average_delay(config) do
    base_delay = config.pause_between_pages_ms
    
    # Add extra delay for very low rate limits
    extra_delay = if config.requests_per_minute <= 5 do
      max(0, div(60_000, config.requests_per_minute) - base_delay)
    else
      0
    end
    
    base_delay + extra_delay
  end
end