defmodule EhsEnforcement.Integrations.Airtable.Records do
  @moduledoc """
  Functions for working on the records retrieved from Airtable.

  This module provides a higher-level interface for getting Airtable records
  with automatic pagination handling. Updated to use the new ReqClient.
  """

  require Logger
  alias EhsEnforcement.Integrations.Airtable.{ReqClient, Url}

  @doc """
  Gets base metadata from Airtable.

  ## Examples
      iex> Records.get_bases()
      {:ok, %{"bases" => [...]}}
  """
  def get_bases do
    ReqClient.get("/meta")
  end

  @doc """
  Action: get data from Airtable with automatic pagination.

  This function handles Airtable's pagination automatically by following
  offset tokens until all records are retrieved.

  ## Parameters
  - `{jsonset, recordset}` - Accumulator tuple for building results
  - `params` - Map containing:
    - `:base` - Airtable base ID
    - `:table` - Airtable table ID  
    - `:options` - Query options (view, fields, formula, etc.)
    - `:atom?` - Whether to decode JSON with atom keys (default: false)

  ## Returns
  - `{:ok, {json_string, records_list}}` - Success with all records
  - `{:error, error_map}` - Error from API or processing

  ## Examples
      iex> params = %{
      ...>   base: "appXXX",
      ...>   table: "tblYYY", 
      ...>   options: %{view: "Grid view"},
      ...>   atom?: false
      ...> }
      iex> Records.get_records({[], []}, params)
      {:ok, {json_string, [record1, record2, ...]}}
  """
  def get_records({jsonset, recordset}, params) when is_list(recordset) do
    params = Map.put_new(params, :atom?, false)

    with(
      {:ok, url} <- Url.url(params.base, params.table, params.options),
      {:ok, data} <- ReqClient.get(url),
      processed_data <- process_response_data(data, params.atom?),
      result <- set_params(processed_data, processed_data)
    ) do
      case result do
        %{"records" => records, "offset" => offset} ->
          Logger.debug("Call to Airtable returned #{Enum.count(records)} records with offset")

          # Continue pagination
          options = Map.put(params.options, :offset, offset)
          new_params = Map.put(params, :options, options)

          # Accumulate results and continue
          json_string = Jason.encode!(data)
          get_records({jsonset ++ [json_string], recordset ++ records}, new_params)

        %{"records" => records} ->
          # Final page - no more offset
          Logger.debug("Call to Airtable returned #{Enum.count(records)} records (final page)")

          all_records = recordset ++ records
          final_json = Jason.encode!(%{"records" => all_records})
          {:ok, {final_json, all_records}}

        {:error, error} ->
          {:error, error}
      end
    else
      {:error, error} ->
        Logger.error("Failed to get Airtable records: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Simplified interface to get all records from a table.

  This is a convenience function that uses the ReqClient's built-in
  pagination handling.

  ## Examples
      iex> Records.get_all_records("appXXX", "tblYYY", %{view: "Grid view"})
      {:ok, [record1, record2, ...]}
  """
  def get_all_records(base, table, options \\ %{}) do
    path = "/#{base}/#{table}"

    case ReqClient.get_all_records(path, options) do
      {:ok, %{"records" => records}} ->
        {:ok, records}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get records as a stream for very large datasets.

  This function returns a Stream that yields records in pages,
  allowing for memory-efficient processing of large datasets.
  """
  def get_records_stream(base, table, options \\ %{}) do
    Stream.unfold(nil, fn offset ->
      current_options =
        case offset do
          nil -> options
          offset -> Map.put(options, :offset, offset)
        end

      path = "/#{base}/#{table}"

      case ReqClient.get(path, current_options) do
        {:ok, %{"records" => records, "offset" => next_offset}} ->
          {records, next_offset}

        {:ok, %{"records" => records}} ->
          # Final page
          {records, nil}

        {:error, _error} ->
          # End stream on error
          nil
      end
    end)
    |> Stream.take_while(&(&1 != nil))
    |> Stream.flat_map(& &1)
  end

  # Internal helper functions

  @spec process_response_data(map(), boolean()) :: map()
  defp process_response_data(data, true = _atom_keys?) do
    # Data is already decoded by ReqClient, but we need atom keys
    case Jason.encode(data) do
      {:ok, json_string} ->
        Jason.decode!(json_string, keys: :atoms)

      {:error, _} ->
        # Fallback to original data
        data
    end
  end

  defp process_response_data(data, false = _atom_keys?) do
    # Data is already in the format we want (string keys)
    data
  end

  @spec set_params(map(), map()) :: %{required(String.t()) => term()} | {:error, term()}
  defp set_params(%{records: records, offset: offset}, _original) do
    %{"records" => records, "offset" => offset}
  end

  defp set_params(%{"records" => records, "offset" => offset}, _original) do
    %{"records" => records, "offset" => offset}
  end

  defp set_params(%{records: records}, _original) do
    %{"records" => records}
  end

  defp set_params(%{"records" => records}, _original) do
    %{"records" => records}
  end

  defp set_params(%{error: error}, _original) do
    {:error, error}
  end

  defp set_params(%{"error" => error}, _original) do
    {:error, error}
  end

  defp set_params(data, _original) do
    # Fallback - assume the data contains records directly
    %{"records" => data}
  end

  # Legacy compatibility functions

  @doc """
  Legacy get function for backwards compatibility.

  This maintains the old interface while using the new ReqClient internally.
  """
  def get(url) when is_binary(url) do
    # Extract path from full URL for ReqClient
    path = String.replace(url, ~r/^https?:\/\/[^\/]+/, "")

    case ReqClient.get(path) do
      {:ok, data} ->
        json_string = Jason.encode!(data)
        {:ok, json_string}

      {:error, error} ->
        {:error, error}
    end
  end
end
