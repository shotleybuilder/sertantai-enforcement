defmodule EhsEnforcement.Sync.AirtableImporter do
  @moduledoc """
  One-time import tool to migrate existing Airtable data using Ash.
  Can be removed after successful migration to PostgreSQL.
  """

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Integrations.Airtable.ReqClient
  require Logger

  @batch_size 100
  @airtable_base_id "appq5OQW9bTHC1zO5"
  @airtable_table_id "tbl6NZm9bLU2ijivf"

  # Allow dependency injection for testing
  @client Application.compile_env(:ehs_enforcement, :airtable_client, ReqClient)

  @doc """
  Imports all data from Airtable in batches.
  """
  def import_all_data do
    Logger.info("Starting Airtable data import...")

    try do
      import_pages_with_error_handling(nil)
    rescue
      error ->
        Logger.error("Import failed: #{inspect(error)}")
        {:error, error}
    catch
      {:airtable_error, error} ->
        Logger.error("Import failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Imports a single batch of records.
  """
  def import_batch(records) when is_list(records) do
    Logger.info("Importing batch of #{length(records)} records...")

    # Group records by type
    {cases, notices} = partition_records(records)

    # Import cases
    case_results = import_cases_batch(cases)

    # Import notices
    notice_results = import_notices_batch(notices)

    # Log results
    Logger.info(
      "Batch import complete. Cases: #{length(case_results)}, Notices: #{length(notice_results)}"
    )

    :ok
  end

  @doc """
  Partitions records into cases and notices based on their fields.
  """
  def partition_records(records) do
    Enum.reduce(records, {[], []}, fn record, {cases, notices} ->
      fields = record["fields"] || %{}
      offence_action_type = fields["offence_action_type"] || ""

      cond do
        offence_action_type in ["Court Case", "Caution"] ->
          {[record | cases], notices}

        # All other types are notices (Improvement Notice, Prohibition Notice, etc.)
        offence_action_type != "" ->
          {cases, [record | notices]}

        true ->
          # Skip records without offence_action_type
          {cases, notices}
      end
    end)
  end

  @doc """
  Creates a lazy stream of all Airtable records.
  """
  def stream_airtable_records do
    Stream.unfold(nil, &fetch_next_page/1)
    |> Stream.flat_map(fn records -> records end)
  end

  # Private functions

  defp import_pages_with_error_handling(offset) do
    path = "/#{@airtable_base_id}/#{@airtable_table_id}"

    params =
      case offset do
        nil -> %{}
        offset -> %{offset: offset}
      end

    case client().get(path, params) do
      {:ok, %{"records" => records, "offset" => next_offset}} ->
        # Process current batch
        records
        |> Enum.chunk_every(@batch_size)
        |> Enum.each(&import_batch/1)

        # Continue with next page
        import_pages_with_error_handling(next_offset)

      {:ok, %{"records" => records}} ->
        # Last page - process and finish
        records
        |> Enum.chunk_every(@batch_size)
        |> Enum.each(&import_batch/1)

        :ok

      {:error, error} ->
        Logger.error("Failed to fetch Airtable page: #{inspect(error)}")
        {:error, error}
    end
  end

  defp fetch_next_page(:done), do: nil

  defp fetch_next_page(offset) do
    path = "/#{@airtable_base_id}/#{@airtable_table_id}"

    params =
      case offset do
        nil -> %{}
        offset -> %{offset: offset}
      end

    case client().get(path, params) do
      {:ok, %{"records" => records, "offset" => next_offset}} ->
        {records, next_offset}

      {:ok, %{"records" => records}} ->
        # No more pages
        {records, :done}

      {:error, error} ->
        Logger.error("Failed to fetch Airtable page: #{inspect(error)}")
        throw({:airtable_error, error})

      _ ->
        throw({:airtable_error, :unexpected_response})
    end
  end

  defp import_cases_batch([]), do: []

  defp import_cases_batch(cases) do
    Enum.map(cases, fn record ->
      fields = record["fields"] || %{}

      attrs = %{
        agency_code: String.to_atom(fields["agency_code"] || "hse"),
        regulator_id: to_string(fields["regulator_id"]),
        offender_attrs: %{
          name: fields["offender_name"],
          postcode: fields["offender_postcode"],
          local_authority: fields["offender_local_authority"],
          main_activity: fields["offender_main_activity"]
        },
        offence_action_date: parse_date(fields["offence_action_date"]),
        offence_action_type: fields["offence_action_type"],
        offence_fine: parse_decimal(fields["offence_fine"]),
        offence_breaches: fields["offence_breaches"]
      }

      case Enforcement.create_case(attrs) do
        {:ok, case_record} ->
          case_record

        {:error, error} ->
          Logger.error("Failed to import case #{fields["regulator_id"]}: #{inspect(error)}")
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp import_notices_batch([]), do: []

  defp import_notices_batch(notices) do
    Enum.map(notices, fn record ->
      fields = record["fields"] || %{}

      attrs = %{
        agency_code: String.to_atom(fields["agency_code"] || "hse"),
        regulator_id: to_string(fields["regulator_id"]),
        offender_attrs: %{
          name: fields["offender_name"],
          postcode: fields["offender_postcode"],
          local_authority: fields["offender_local_authority"],
          main_activity: fields["offender_main_activity"]
        },
        offence_action_type: fields["offence_action_type"],
        offence_action_date: parse_date(fields["offence_action_date"]),
        notice_date: parse_date(fields["notice_date"]),
        operative_date: parse_date(fields["operative_date"]),
        compliance_date: parse_date(fields["compliance_date"]),
        notice_body: fields["notice_body"],
        offence_breaches: fields["offence_breaches"]
      }

      case Enforcement.create_notice(attrs) do
        {:ok, notice_record} ->
          notice_record

        {:error, error} ->
          Logger.error("Failed to import notice #{fields["regulator_id"]}: #{inspect(error)}")
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_decimal(nil), do: Decimal.new("0")

  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> Decimal.new("0")
    end
  end

  defp parse_decimal(value) when is_number(value) do
    Decimal.new(to_string(value))
  end

  # Get the client module - allows override for testing
  defp client do
    Application.get_env(:ehs_enforcement, :airtable_client, @client)
  end
end
