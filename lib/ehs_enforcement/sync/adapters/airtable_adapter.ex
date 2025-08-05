defmodule EhsEnforcement.Sync.Adapters.AirtableAdapter do
  @moduledoc """
  Airtable source adapter implementation for the generic sync engine.
  
  This adapter provides a bridge between the generic sync engine and Airtable,
  implementing the SourceAdapter behaviour. It handles Airtable-specific
  authentication, API calls, pagination, rate limiting, and record normalization.
  
  ## Configuration
  
      config = %{
        api_key: "keyXXXXXXXXXXXXXX",
        base_id: "appXXXXXXXXXXXXXX",
        table_id: "tblXXXXXXXXXXXXXX",
        view: "Grid view",              # Optional
        formula: "NOT({Status} = 'Deleted')",  # Optional filter
        fields: ["Name", "Status", "Created"],  # Optional field subset
        sort: [%{field: "Created", direction: "desc"}],  # Optional sorting
        max_records: nil,               # Optional limit (nil = no limit)
        page_size: 100,                 # Records per API call
        rate_limit_delay_ms: 200,       # Delay between API calls
        timeout_ms: 30_000,             # Request timeout
        retry_attempts: 3,              # Failed request retries
        retry_delay_ms: 1000            # Retry delay
      }
  
  ## Features
  
  - Automatic pagination through large datasets
  - Rate limiting to respect Airtable API limits
  - Configurable field selection and filtering
  - Robust error handling and retries
  - Record normalization to generic format
  - Connection validation and health checks
  - Progress-friendly streaming interface
  
  ## Example Usage
  
      # Initialize adapter
      {:ok, adapter_state} = AirtableAdapter.initialize(config)
      
      # Stream records
      adapter_state
      |> AirtableAdapter.stream_records()
      |> Enum.take(10)
      |> IO.inspect()
      
      # Validate connection
      :ok = AirtableAdapter.validate_connection(adapter_state)
  """
  
  @behaviour EhsEnforcement.Sync.Generic.SourceAdapter
  
  alias EhsEnforcement.Integrations.Airtable.ReqClient
  alias EhsEnforcement.Sync.Generic.SourceAdapter
  require Logger

  @type adapter_config :: %{
    required(:api_key) => String.t(),
    required(:base_id) => String.t(),
    required(:table_id) => String.t(),
    optional(atom()) => any()
  }

  @type adapter_state :: %{
    config: adapter_config(),
    base_url: String.t(),
    table_path: String.t(),
    request_params: map(),
    rate_limiter: pid() | nil
  }

  @default_page_size 100
  @default_rate_limit_delay_ms 200
  @default_timeout_ms 30_000
  @default_retry_attempts 3
  @default_retry_delay_ms 1000

  @impl true
  def initialize(config) do
    Logger.debug("🔧 Initializing Airtable adapter")
    
    with :ok <- validate_required_config(config),
         {:ok, normalized_config} <- normalize_config(config),
         {:ok, rate_limiter} <- initialize_rate_limiter(normalized_config),
         {:ok, request_params} <- build_request_params(normalized_config) do
      
      base_url = build_base_url(normalized_config.base_id)
      table_path = "/#{normalized_config.base_id}/#{normalized_config.table_id}"
      
      adapter_state = %{
        config: normalized_config,
        base_url: base_url,
        table_path: table_path,
        request_params: request_params,
        rate_limiter: rate_limiter
      }
      
      Logger.debug("✅ Airtable adapter initialized successfully")
      {:ok, adapter_state}
    else
      {:error, reason} ->
        Logger.error("❌ Airtable adapter initialization failed: #{inspect(reason)}")
        {:error, {:airtable_init_failed, reason}}
    end
  end

  @impl true
  def stream_records(adapter_state) do
    Logger.debug("📡 Starting Airtable record stream")
    
    Stream.resource(
      fn ->
        # Initialize streaming state
        %{
          adapter_state: adapter_state,
          offset: nil,
          page_count: 0,
          record_count: 0,
          has_more: true
        }
      end,
      fn stream_state ->
        if stream_state.has_more do
          case fetch_page(stream_state.adapter_state, stream_state.offset) do
            {:ok, page_result} ->
              # Process the page
              records = page_result.records
              normalized_records = Enum.map(records, &normalize_airtable_record/1)
              
              # Update streaming state
              new_state = %{
                stream_state | 
                offset: page_result.offset,
                page_count: stream_state.page_count + 1,
                record_count: stream_state.record_count + length(records),
                has_more: page_result.offset != nil
              }
              
              Logger.debug("📦 Fetched page #{new_state.page_count}: #{length(records)} records")
              
              # Apply rate limiting
              apply_rate_limit(stream_state.adapter_state)
              
              {normalized_records, new_state}
              
            {:error, error} ->
              Logger.error("❌ Failed to fetch Airtable page: #{inspect(error)}")
              
              # Handle error based on configuration
              if should_retry_error?(error, stream_state.adapter_state.config) do
                Logger.info("🔄 Retrying after error: #{inspect(error)}")
                Process.sleep(stream_state.adapter_state.config.retry_delay_ms)
                {[], stream_state}  # Continue with same state to retry
              else
                # Stop streaming on unrecoverable error
                {:halt, stream_state}
              end
          end
        else
          # No more pages
          Logger.debug("✅ Airtable streaming completed: #{stream_state.record_count} records")
          {:halt, stream_state}
        end
      end,
      fn stream_state ->
        # Cleanup
        cleanup_rate_limiter(stream_state.adapter_state.rate_limiter)
        Logger.debug("🧹 Airtable stream cleanup completed")
        :ok
      end
    )
    |> Stream.flat_map(& &1)  # Flatten pages into individual records
  end

  @impl true
  def validate_connection(adapter_state) do
    Logger.debug("🔍 Validating Airtable connection")
    
    # Test connection with a minimal request
    test_params = Map.merge(adapter_state.request_params, %{maxRecords: 1})
    
    case ReqClient.get(adapter_state.table_path, test_params) do
      {:ok, response} ->
        if Map.has_key?(response, "records") do
          Logger.debug("✅ Airtable connection validated successfully")
          :ok
        else
          Logger.error("❌ Airtable response missing 'records' field")
          {:error, :invalid_response_format}
        end
        
      {:error, error} ->
        Logger.error("❌ Airtable connection validation failed: #{inspect(error)}")
        {:error, {:connection_failed, error}}
    end
  end

  @impl true
  def get_total_count(adapter_state) do
    Logger.debug("🔢 Getting total record count from Airtable")
    
    # Use a minimal request to get record count
    count_params = Map.merge(adapter_state.request_params, %{
      maxRecords: 1,
      fields: []  # Don't fetch field data, just count
    })
    
    case count_all_records(adapter_state, count_params, 0) do
      {:ok, total_count} ->
        Logger.debug("✅ Total Airtable records: #{total_count}")
        {:ok, total_count}
        
      {:error, error} ->
        Logger.warn("⚠️ Could not get total count: #{inspect(error)}")
        {:error, :count_unavailable}
    end
  end

  # Private functions

  defp validate_required_config(config) do
    required_fields = [:api_key, :base_id, :table_id]
    
    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(config, field) or is_nil(Map.get(config, field))
    end)
    
    if length(missing_fields) == 0 do
      :ok
    else
      {:error, {:missing_required_fields, missing_fields}}
    end
  end

  defp normalize_config(config) do
    normalized = %{
      api_key: Map.get(config, :api_key),
      base_id: Map.get(config, :base_id),
      table_id: Map.get(config, :table_id),
      view: Map.get(config, :view),
      formula: Map.get(config, :formula),
      fields: Map.get(config, :fields),
      sort: Map.get(config, :sort),
      max_records: Map.get(config, :max_records),
      page_size: Map.get(config, :page_size, @default_page_size),
      rate_limit_delay_ms: Map.get(config, :rate_limit_delay_ms, @default_rate_limit_delay_ms),
      timeout_ms: Map.get(config, :timeout_ms, @default_timeout_ms),
      retry_attempts: Map.get(config, :retry_attempts, @default_retry_attempts),
      retry_delay_ms: Map.get(config, :retry_delay_ms, @default_retry_delay_ms)
    }
    
    {:ok, normalized}
  end

  defp initialize_rate_limiter(config) do
    # Simple rate limiter - could be enhanced with token bucket or more sophisticated algorithms
    if config.rate_limit_delay_ms > 0 do
      {:ok, spawn(fn -> rate_limiter_loop(config.rate_limit_delay_ms) end)}
    else
      {:ok, nil}
    end
  end

  defp rate_limiter_loop(delay_ms) do
    receive do
      :rate_limit ->
        Process.sleep(delay_ms)
        rate_limiter_loop(delay_ms)
      :stop ->
        :ok
    after
      60_000 ->  # Auto-stop after 1 minute of inactivity
        :ok
    end
  end

  defp cleanup_rate_limiter(nil), do: :ok
  defp cleanup_rate_limiter(rate_limiter_pid) do
    if Process.alive?(rate_limiter_pid) do
      send(rate_limiter_pid, :stop)
    end
    :ok
  end

  defp build_request_params(config) do
    params = %{
      pageSize: config.page_size
    }
    
    # Add optional parameters if specified
    params = if config.view, do: Map.put(params, :view, config.view), else: params
    params = if config.formula, do: Map.put(params, :filterByFormula, config.formula), else: params
    params = if config.fields, do: Map.put(params, :fields, config.fields), else: params
    params = if config.sort, do: Map.put(params, :sort, config.sort), else: params
    params = if config.max_records, do: Map.put(params, :maxRecords, config.max_records), else: params
    
    {:ok, params}
  end

  defp build_base_url(base_id) do
    "https://api.airtable.com/v0/#{base_id}"
  end

  defp fetch_page(adapter_state, offset \\ nil) do
    params = if offset do
      Map.put(adapter_state.request_params, :offset, offset)
    else
      adapter_state.request_params
    end
    
    case ReqClient.get(adapter_state.table_path, params) do
      {:ok, response} ->
        records = Map.get(response, "records", [])
        next_offset = Map.get(response, "offset")
        
        {:ok, %{
          records: records,
          offset: next_offset
        }}
        
      {:error, error} ->
        {:error, error}
    end
  end

  defp normalize_airtable_record(airtable_record) do
    # Use the generic normalization from SourceAdapter
    SourceAdapter.normalize_record(airtable_record, [
      id_field: "id",
      fields_mapping: %{}  # Keep all fields as-is
    ])
  end

  defp apply_rate_limit(adapter_state) do
    if adapter_state.rate_limiter do
      send(adapter_state.rate_limiter, :rate_limit)
    end
    :ok
  end

  defp should_retry_error?(error, config) do
    # Determine if error is retryable based on error type and configuration
    case error do
      %{status: status} when status in [429, 500, 502, 503, 504] ->
        # Retryable HTTP errors
        true
        
      {:timeout, _} ->
        # Network timeout
        true
        
      {:connection_error, _} ->
        # Connection issues
        true
        
      _ ->
        # Other errors are not retryable
        false
    end
  end

  defp count_all_records(adapter_state, params, current_count) do
    case ReqClient.get(adapter_state.table_path, params) do
      {:ok, response} ->
        records = Map.get(response, "records", [])
        new_count = current_count + length(records)
        
        case Map.get(response, "offset") do
          nil ->
            # No more pages
            {:ok, new_count}
            
          next_offset ->
            # Continue counting with next page
            next_params = Map.put(params, :offset, next_offset)
            apply_rate_limit(adapter_state)
            count_all_records(adapter_state, next_params, new_count)
        end
        
      {:error, error} ->
        {:error, error}
    end
  end
end