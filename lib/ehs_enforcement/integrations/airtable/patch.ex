defmodule EhsEnforcement.Integrations.Airtable.Patch do
  @moduledoc """
  High-level PATCH operations for updating Airtable records.

  This module provides convenient functions for updating existing records
  in Airtable using the standardized ReqClient with proper error handling.
  """

  require Logger
  alias EhsEnforcement.Integrations.Airtable.{ReqClient, Url}

  @doc """
  Updates existing records in an Airtable table.

  ## Parameters
  - `base` - Airtable base ID
  - `table` - Airtable table ID
  - `data` - Data to update, can be a single record map or list of records
            Each record must include an "id" field

  ## Returns
  - `{:ok, updated_records}` - Successfully updated records
  - `{:error, error}` - Error details if the request fails

  ## Examples
      # Single record update
      iex> Patch.patch("appXXX", "tblYYY", %{"id" => "recABC", "fields" => %{"Name" => "Updated"}})
      {:ok, [%{"id" => "recABC", "fields" => %{"Name" => "Updated"}}]}
      
      # Multiple record updates
      iex> updates = [
      ...>   %{"id" => "recABC", "fields" => %{"Name" => "Updated 1"}},
      ...>   %{"id" => "recDEF", "fields" => %{"Name" => "Updated 2"}}
      ...> ]
      iex> Patch.patch("appXXX", "tblYYY", updates)
      {:ok, [%{"id" => "recABC", ...}, %{"id" => "recDEF", ...}]}
  """
  @spec patch(String.t(), String.t(), map() | list()) :: {:ok, list()} | {:error, map()}
  def patch(base, table, data) do
    with(
      {:ok, url} <- Url.url(base, table, %{}),
      formatted_data <- make_airtable_dataset(data),
      {:ok, response} <- ReqClient.patch(url, formatted_data)
    ) do
      case response do
        %{"records" => records} ->
          Logger.info("PATCH successful: updated #{Enum.count(records)} records")
          {:ok, records}

        _ ->
          Logger.warning("PATCH returned unexpected format: #{inspect(response)}")

          {:error,
           %{
             type: :unexpected_format,
             message: "Response did not contain records",
             details: response
           }}
      end
    else
      {:error, %{type: :validation_error} = error} ->
        Logger.error("PATCH validation failed: #{inspect(error)}")
        {:error, error}

      {:error, error} ->
        Logger.error("PATCH failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Updates a single record by ID with field updates.

  This is a convenience function for updating one record when you have
  the record ID and the fields to update.

  ## Examples
      iex> Patch.patch_record("appXXX", "tblYYY", "recABC", %{"Name" => "New Name"})
      {:ok, %{"id" => "recABC", "fields" => %{"Name" => "New Name"}}}
  """
  @spec patch_record(String.t(), String.t(), String.t(), map()) :: {:ok, map()} | {:error, map()}
  def patch_record(base, table, record_id, field_updates) do
    record_data = %{"id" => record_id, "fields" => field_updates}

    case patch(base, table, record_data) do
      {:ok, [updated_record]} ->
        {:ok, updated_record}

      {:ok, records} ->
        Logger.error("Expected single record update, got: #{inspect(records)}")
        {:error, %{type: :unexpected_response, message: "Expected single record response"}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Updates multiple records in batches, respecting Airtable's 10 record limit per request.

  Airtable limits PATCH requests to 10 records maximum. This function automatically
  chunks larger datasets and sends multiple requests.

  ## Examples
      iex> updates = Enum.map(1..25, fn i -> %{"id" => "rec\#{i}", "fields" => %{"Status" => "Updated"}} end)
      iex> Patch.patch_batch("appXXX", "tblYYY", updates)
      {:ok, [record1, record2, ...]}  # 25 records updated across 3 requests
  """
  @spec patch_batch(String.t(), String.t(), list()) :: {:ok, list()} | {:error, map()}
  def patch_batch(base, table, records) when is_list(records) do
    records
    # Airtable's limit is 10 records per request
    |> Enum.chunk_every(10)
    |> Enum.reduce_while({:ok, []}, fn batch, {:ok, accumulated_records} ->
      case patch(base, table, batch) do
        {:ok, updated_records} ->
          {:cont, {:ok, accumulated_records ++ updated_records}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
  end

  @doc """
  Updates records with debug output for development.

  This function logs the data being sent for debugging purposes.
  """
  @spec patch_debug(String.t(), String.t(), map() | list()) ::
          {:ok, list()}
          | {:error,
             %{
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
                 | :unexpected_format
                 | :unknown_error
             }}
  def patch_debug(base, table, data) do
    formatted_data = make_airtable_dataset(data)
    Logger.debug("PATCH DATA: #{inspect(formatted_data)}")
    patch(base, table, data)
  end

  @doc """
  Conditionally updates a record only if it exists.

  This first checks if the record exists, then updates it if found.
  Useful for safe updates when you're not sure if the record exists.
  """
  @spec patch_if_exists(String.t(), String.t(), String.t(), map()) ::
          {:ok, map()} | {:ok, nil} | {:error, map()}
  def patch_if_exists(base, table, record_id, field_updates) do
    # First, try to get the record to verify it exists
    alias EhsEnforcement.Integrations.Airtable.Get

    case Get.get_id(base, table, %{formula: "{RECORD_ID()} = '#{record_id}'"}) do
      {:ok, ^record_id} ->
        # Record exists, proceed with update
        patch_record(base, table, record_id, field_updates)

      {:ok, nil} ->
        # Record doesn't exist
        Logger.info("Record #{record_id} not found, skipping update")
        {:ok, nil}

      {:error, error} ->
        {:error, error}
    end
  end

  # Private helper functions

  @spec make_airtable_dataset(map() | list()) :: map()
  defp make_airtable_dataset(records) when is_list(records) do
    # Validate that all records have IDs for PATCH operations
    validated_records = Enum.map(records, &validate_record_for_patch/1)

    %{"records" => validated_records, "typecast" => true}
  end

  defp make_airtable_dataset(record) when is_map(record) do
    validated_record = validate_record_for_patch(record)

    %{"records" => [validated_record], "typecast" => true}
  end

  @spec validate_record_for_patch(map()) :: map()
  defp validate_record_for_patch(%{"id" => id, "fields" => _fields} = record)
       when is_binary(id) do
    # Already in correct format
    record
  end

  defp validate_record_for_patch(%{"id" => id} = record) when is_binary(id) do
    # Has ID but fields might be at top level
    {id_field, fields} = Map.pop(record, "id")
    %{"id" => id_field, "fields" => fields}
  end

  defp validate_record_for_patch(record) do
    Logger.error("PATCH record missing required 'id' field: #{inspect(record)}")
    raise ArgumentError, "PATCH operations require records to have an 'id' field"
  end
end
