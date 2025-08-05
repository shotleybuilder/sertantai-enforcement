defmodule EhsEnforcement.Sync.Generic.SourceAdapter do
  @moduledoc """
  Behaviour and utilities for generic source adapters.
  
  This module defines the interface that all source adapters must implement
  to work with the generic sync engine. Source adapters are responsible for
  streaming records from external data sources (Airtable, CSV, APIs, etc.).
  
  ## Adapter Implementation
  
  Adapters must implement the `SourceAdapter` behaviour:
  
      defmodule MyApp.Sync.Adapters.CsvAdapter do
        @behaviour EhsEnforcement.Sync.Generic.SourceAdapter
        
        @impl true
        def initialize(config) do
          # Setup CSV reader, validate file path, etc.
          {:ok, %{csv_path: config.file_path, headers: config.headers}}
        end
        
        @impl true
        def stream_records(adapter_state) do
          adapter_state.csv_path
          |> File.stream!()
          |> CSV.decode!(headers: adapter_state.headers)
          |> Stream.map(&normalize_record/1)
        end
        
        @impl true
        def validate_connection(adapter_state) do
          if File.exists?(adapter_state.csv_path) do
            :ok
          else
            {:error, :file_not_found}
          end
        end
        
        @impl true
        def get_total_count(adapter_state) do
          # Count lines in CSV file
          count = adapter_state.csv_path
          |> File.stream!()
          |> Enum.count()
          |> Kernel.-(1)  # Subtract header row
          
          {:ok, count}
        end
        
        defp normalize_record(csv_row) do
          # Convert CSV row to standard record format
          %{
            "fields" => csv_row,
            "id" => Map.get(csv_row, "id"),
            "created_at" => Map.get(csv_row, "created_at")
          }
        end
      end
  """
  
  @type adapter_config :: map()
  @type adapter_state :: any()
  @type record :: map()
  
  @doc """
  Initialize the adapter with the provided configuration.
  
  This function is called once during sync engine initialization.
  It should validate the configuration, establish connections, and
  return the adapter state that will be passed to other callbacks.
  
  ## Parameters
  
  * `config` - Adapter-specific configuration map
  
  ## Returns
  
  * `{:ok, adapter_state}` - Success with initialized adapter state
  * `{:error, reason}` - Initialization failed
  """
  @callback initialize(adapter_config()) :: {:ok, adapter_state()} | {:error, any()}
  
  @doc """
  Stream records from the data source.
  
  This function should return a stream of records that can be processed
  by the sync engine. Records should be normalized to a consistent format
  with at minimum an "id" field and a "fields" map containing the data.
  
  ## Parameters
  
  * `adapter_state` - State returned from initialize/1
  
  ## Returns
  
  * `Stream.t()` - Stream of normalized records
  """
  @callback stream_records(adapter_state()) :: Stream.t()
  
  @doc """
  Validate the connection to the data source.
  
  This function should test whether the adapter can successfully
  connect to and read from the data source. It's called during
  sync initialization to ensure the source is available.
  
  ## Parameters
  
  * `adapter_state` - State returned from initialize/1
  
  ## Returns
  
  * `:ok` - Connection is valid
  * `{:error, reason}` - Connection failed
  """
  @callback validate_connection(adapter_state()) :: :ok | {:error, any()}
  
  @doc """
  Get the total count of records available from the source.
  
  This is used for progress tracking and estimation. If the source
  doesn't support efficient counting, return an estimate or {:error, :not_supported}.
  
  ## Parameters
  
  * `adapter_state` - State returned from initialize/1
  
  ## Returns
  
  * `{:ok, count}` - Total record count
  * `{:error, reason}` - Count unavailable or failed
  """
  @callback get_total_count(adapter_state()) :: {:ok, non_neg_integer()} | {:error, any()}
  
  @optional_callbacks [get_total_count: 1]

  @doc """
  Normalize a record to the standard format expected by the sync engine.
  
  This utility function helps adapters convert source-specific record
  formats to the standard format used by the sync engine.
  
  ## Standard Format
  
      %{
        "id" => "unique_record_id",
        "fields" => %{
          "field1" => "value1",
          "field2" => "value2"
        },
        "created_at" => "2023-01-01T00:00:00Z",
        "updated_at" => "2023-01-01T00:00:00Z"
      }
  """
  @spec normalize_record(any(), keyword()) :: record()
  def normalize_record(source_record, opts \\ []) do
    id_field = Keyword.get(opts, :id_field, :id)
    fields_mapping = Keyword.get(opts, :fields_mapping, %{})
    
    # Extract ID
    record_id = extract_field(source_record, id_field)
    
    # Extract and map fields
    fields = if map_size(fields_mapping) > 0 do
      map_fields_with_mapping(source_record, fields_mapping)
    else
      extract_all_fields(source_record)
    end
    
    # Build normalized record
    %{
      "id" => record_id,
      "fields" => fields,
      "created_at" => extract_field(source_record, :created_at),
      "updated_at" => extract_field(source_record, :updated_at)
    }
    |> remove_nil_values()
  end

  @doc """
  Create a test adapter for development and testing purposes.
  
  This adapter generates synthetic records for testing the sync engine
  without requiring external data sources.
  """
  @spec create_test_adapter(keyword()) :: {:ok, atom()}
  def create_test_adapter(opts \\ []) do
    record_count = Keyword.get(opts, :record_count, 100)
    record_template = Keyword.get(opts, :record_template, &default_test_record/1)
    
    # Create a unique module name based on options
    module_name = String.to_atom("Elixir.TestAdapter#{:crypto.strong_rand_bytes(8) |> Base.encode16()}")
    
    module_code = quote do
      @behaviour EhsEnforcement.Sync.Generic.SourceAdapter
      
      def initialize(config) do
        {:ok, Map.merge(%{
          record_count: unquote(record_count),
          record_template: unquote(record_template)
        }, config)}
      end
      
      def stream_records(state) do
        1..state.record_count
        |> Stream.map(state.record_template)
      end
      
      def validate_connection(_state) do
        :ok
      end
      
      def get_total_count(state) do
        {:ok, state.record_count}
      end
    end
    
    # Create the module dynamically
    Module.create(module_name, module_code, Macro.Env.location(__ENV__))
    {:ok, module_name}
  end

  # Private utility functions

  defp extract_field(record, field) when is_map(record) do
    case field do
      field when is_atom(field) ->
        Map.get(record, field) || Map.get(record, to_string(field))
      field when is_binary(field) ->
        Map.get(record, field) || Map.get(record, String.to_atom(field))
      [:fields, subfield] ->
        get_in(record, ["fields", subfield]) || get_in(record, [:fields, subfield])
      path when is_list(path) ->
        get_in(record, path)
      _ ->
        nil
    end
  end
  defp extract_field(_record, _field), do: nil

  defp extract_all_fields(record) when is_map(record) do
    # If record has a "fields" key, use that; otherwise use the entire record
    case Map.get(record, "fields") || Map.get(record, :fields) do
      nil -> 
        # Remove metadata fields and use the rest as fields
        Map.drop(record, ["id", :id, "created_at", :created_at, "updated_at", :updated_at])
      fields when is_map(fields) ->
        fields
      _ ->
        %{}
    end
  end
  defp extract_all_fields(_record), do: %{}

  defp map_fields_with_mapping(record, fields_mapping) do
    Enum.reduce(fields_mapping, %{}, fn {target_field, source_path}, acc ->
      value = extract_field(record, source_path)
      if value != nil do
        Map.put(acc, to_string(target_field), value)
      else
        acc
      end
    end)
  end

  defp remove_nil_values(map) when is_map(map) do
    map
    |> Enum.reject(fn {_k, v} -> v == nil end)
    |> Map.new()
  end

  defp default_test_record(index) do
    %{
      "id" => "test_record_#{index}",
      "fields" => %{
        "name" => "Test Record #{index}",
        "description" => "Generated test record number #{index}",
        "status" => Enum.random(["active", "inactive", "pending"]),
        "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "sequence_number" => index
      }
    }
  end
end