defmodule EhsEnforcement.Integrations.Airtable.Get do
  @moduledoc """
  High-level GET operations for Airtable records.

  This module provides convenient functions for getting records and IDs
  from Airtable tables using the standardized ReqClient.
  """

  require Logger
  alias EhsEnforcement.Integrations.Airtable.{ReqClient, Url}

  @doc """
  Gets records from a specific table with the given parameters.

  ## Parameters
  - `base` - Airtable base ID
  - `table` - Airtable table ID  
  - `params` - Query parameters (view, fields, formula, etc.)

  ## Returns
  - `{:ok, records}` - List of records from the table
  - `{:error, error}` - Error details if the request fails

  ## Examples
      iex> Get.get("appXXX", "tblYYY", %{view: "Grid view", max_records: "10"})
      {:ok, [%{"id" => "recXXX", "fields" => %{"Name" => "Test"}}, ...]}
  """
  def get(base, table, params \\ %{}) do
    with(
      {:ok, url} <- Url.url(base, table, params),
      {:ok, data} <- ReqClient.get(url)
    ) do
      case data do
        %{"records" => records} ->
          Logger.debug("GET successful: #{Enum.count(records)} records retrieved")
          {:ok, records}

        _ ->
          Logger.warning("GET returned unexpected format: #{inspect(data)}")

          {:error,
           %{type: :unexpected_format, message: "Response did not contain records", details: data}}
      end
    else
      {:error, error} ->
        Logger.error("GET failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Gets a single record ID based on search parameters.

  This is useful for finding existing records before creating or updating.

  ## Parameters
  - `base` - Airtable base ID
  - `table` - Airtable table ID
  - `params` - Query parameters, typically including a formula filter

  ## Returns
  - `{:ok, record_id}` - The ID of the found record
  - `{:ok, nil}` - No records found matching the criteria
  - `{:error, error}` - Error details if the request fails

  ## Examples
      iex> Get.get_id("appXXX", "tblYYY", %{formula: "{Name} = 'Test Record'"})
      {:ok, "recABC123"}
      
      iex> Get.get_id("appXXX", "tblYYY", %{formula: "{Name} = 'Nonexistent'"})
      {:ok, nil}
  """
  def get_id(base, table, params \\ %{}) do
    # Limit to 1 record since we only need the ID
    params_with_limit = Map.put(params, :max_records, "1")

    case get(base, table, params_with_limit) do
      {:ok, []} ->
        Logger.debug("get_id returned 0 records")
        {:ok, nil}

      {:ok, [%{"id" => record_id} | _]} ->
        Logger.debug("get_id found record: #{record_id}")
        {:ok, record_id}

      {:ok, records} when is_list(records) and length(records) > 1 ->
        Logger.warning("get_id returned #{length(records)} records, expected 1")
        # Return the first record ID but log the warning
        case List.first(records) do
          %{"id" => record_id} -> {:ok, record_id}
          _ -> {:error, %{type: :invalid_response, message: "Records missing ID field"}}
        end

      {:ok, records} ->
        Logger.error("get_id received unexpected records format: #{inspect(records)}")

        {:error,
         %{type: :invalid_response, message: "Unexpected records format", details: records}}

      {:error, error} ->
        Logger.error("get_id failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Gets all records from a table, handling pagination automatically.

  This is a convenience wrapper around ReqClient.get_all_records.

  ## Examples
      iex> Get.get_all("appXXX", "tblYYY", %{view: "Grid view"})
      {:ok, [record1, record2, ...]}
  """
  def get_all(base, table, params \\ %{}) do
    path = "/#{base}/#{table}"

    case ReqClient.get_all_records(path, params) do
      {:ok, %{"records" => records}} ->
        Logger.debug("get_all retrieved #{Enum.count(records)} total records")
        {:ok, records}

      {:error, error} ->
        Logger.error("get_all failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Gets records with custom error handling and logging.

  This is useful when you need specific error handling behavior.
  """
  def get_with_error_handling(base, table, params, error_handler \\ &default_error_handler/1)
      when is_function(error_handler, 1) do
    case get(base, table, params) do
      {:ok, records} ->
        {:ok, records}

      {:error, error} ->
        error_handler.(error)
    end
  end

  # Private helper functions

  @spec default_error_handler(map()) :: {:error, map()}
  defp default_error_handler(error) do
    Logger.error("Airtable GET operation failed: #{inspect(error)}")
    {:error, error}
  end
end
