defmodule EhsEnforcement.Integrations.Airtable.Post do
  @moduledoc """
  High-level POST operations for creating Airtable records.

  This module provides convenient functions for posting data to Airtable
  using the standardized ReqClient with proper error handling.
  """

  require Logger
  alias EhsEnforcement.Integrations.Airtable.{ReqClient, Url}

  @doc """
  Posts data to create new records in an Airtable table.

  ## Parameters
  - `base` - Airtable base ID
  - `table` - Airtable table ID
  - `data` - Data to post, can be a single record map or list of records

  ## Returns
  - `{:ok, created_records}` - Successfully created records with IDs
  - `{:error, error}` - Error details if the request fails

  ## Examples
      # Single record
      iex> Post.post("appXXX", "tblYYY", %{"Name" => "Test Record"})
      {:ok, [%{"id" => "recABC", "fields" => %{"Name" => "Test Record"}}]}
      
      # Multiple records
      iex> Post.post("appXXX", "tblYYY", [%{"Name" => "Record 1"}, %{"Name" => "Record 2"}])
      {:ok, [%{"id" => "recABC", ...}, %{"id" => "recDEF", ...}]}
  """
  @spec post(String.t(), String.t(), map() | list()) :: {:ok, list()} | {:error, map()}
  def post(base, table, data) do
    with(
      {:ok, url} <- Url.url(base, table, %{}),
      formatted_data <- make_airtable_dataset(data),
      {:ok, response} <- ReqClient.post(url, formatted_data)
    ) do
      case response do
        %{"records" => records} ->
          Logger.info("POST successful: created #{Enum.count(records)} records")
          {:ok, records}

        _ ->
          Logger.warning("POST returned unexpected format: #{inspect(response)}")

          {:error,
           %{
             type: :unexpected_format,
             message: "Response did not contain records",
             details: response
           }}
      end
    else
      {:error, %{type: :validation_error} = error} ->
        Logger.error("POST validation failed: #{inspect(error)}")
        {:error, error}

      {:error, error} ->
        Logger.error("POST failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Posts data with debug output for development.

  This function logs the data being sent for debugging purposes.
  """
  @spec post_debug(String.t(), String.t(), map() | list()) :: {:ok, list()} | {:error, map()}
  def post_debug(base, table, data) do
    formatted_data = make_airtable_dataset(data)
    Logger.debug("POST DATA: #{inspect(formatted_data)}")
    post(base, table, data)
  end

  @doc """
  Posts multiple batches of records, respecting Airtable's 10 record limit per request.

  Airtable limits POST requests to 10 records maximum. This function automatically
  chunks larger datasets and sends multiple requests.

  ## Examples
      iex> large_dataset = Enum.map(1..25, fn i -> %{"Name" => "Record \#{i}"} end)
      iex> Post.post_batch("appXXX", "tblYYY", large_dataset)
      {:ok, [record1, record2, ...]}  # 25 records created across 3 requests
  """
  @spec post_batch(String.t(), String.t(), list()) :: {:ok, list()} | {:error, map()}
  def post_batch(base, table, records) when is_list(records) do
    records
    # Airtable's limit is 10 records per request
    |> Enum.chunk_every(10)
    |> Enum.reduce_while({:ok, []}, fn batch, {:ok, accumulated_records} ->
      case post(base, table, batch) do
        {:ok, created_records} ->
          {:cont, {:ok, accumulated_records ++ created_records}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
  end

  @doc """
  Posts a single record and returns just the record ID.

  This is a convenience function for when you only need the ID of the created record.
  """
  @spec post_single(String.t(), String.t(), map()) :: {:ok, String.t()} | {:error, map()}
  def post_single(base, table, record_data) do
    case post(base, table, record_data) do
      {:ok, [%{"id" => record_id} | _]} ->
        {:ok, record_id}

      {:ok, records} ->
        Logger.error("Expected single record, got: #{inspect(records)}")
        {:error, %{type: :unexpected_response, message: "Expected single record response"}}

      {:error, error} ->
        {:error, error}
    end
  end

  # Private helper functions

  @spec make_airtable_dataset(map() | list()) :: map()
  defp make_airtable_dataset(records) when is_list(records) do
    formatted_records =
      Enum.map(records, fn record ->
        case record do
          # Already in Airtable format
          %{"fields" => _} -> record
          # Wrap in fields object
          fields -> %{"fields" => fields}
        end
      end)

    %{"records" => formatted_records, "typecast" => true}
  end

  defp make_airtable_dataset(record) when is_map(record) do
    formatted_record =
      case record do
        # Already in Airtable format
        %{"fields" => _} -> record
        # Wrap in fields object
        fields -> %{"fields" => fields}
      end

    %{"records" => [formatted_record], "typecast" => true}
  end
end
