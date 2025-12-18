defmodule EhsEnforcement.Scraping.Backfill.BackfillBreachData do
  @moduledoc """
  Oban worker to backfill breach data for HSE cases.

  This worker fetches breach details from the HSE website for cases that
  are missing `offence_breaches` data, then:
  1. Updates the case with `offence_breaches` text
  2. Creates Legislation records via TieredMatcher
  3. Creates Offence records linking case → legislation

  ## Usage

  Enqueue a single case:

      %{case_id: "uuid-here"}
      |> BackfillBreachData.new()
      |> Oban.insert()

  Enqueue a batch of cases:

      BackfillBreachData.enqueue_batch(limit: 100)

  Enqueue all HSE cases missing breach data:

      BackfillBreachData.enqueue_all_missing()

  ## Options

  - `:database` - HSE database to use (default: "prosecution")
  - `:delay_ms` - Delay between requests in ms (default: 1000)
  """

  use Oban.Worker,
    queue: :backfill,
    max_attempts: 3,
    priority: 3

  require Logger
  require Ash.Query

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Enforcement.BreachParser
  alias EhsEnforcement.Legislation.TieredMatcher
  alias EhsEnforcement.Scraping.Hse.CaseScraper

  @default_database "prosecution"
  @default_delay_ms 1000

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"case_id" => case_id} = args}) do
    database = Map.get(args, "database", @default_database)
    delay_ms = Map.get(args, "delay_ms", @default_delay_ms)

    Logger.info("BackfillBreachData: Processing case #{case_id}")

    with {:ok, case} <- get_case(case_id),
         {:ok, _} <- backfill_case(case, database, delay_ms) do
      Logger.info("BackfillBreachData: Successfully processed case #{case_id}")
      :ok
    else
      {:error, :case_not_found} ->
        Logger.warning("BackfillBreachData: Case not found: #{case_id}")
        {:error, :case_not_found}

      {:error, :already_has_breaches} ->
        Logger.debug("BackfillBreachData: Case already has breaches: #{case_id}")
        :ok

      {:error, reason} = error ->
        Logger.error("BackfillBreachData: Failed to process case #{case_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Enqueue a batch of HSE cases that are missing breach data.

  Options:
  - `:limit` - Maximum number of cases to enqueue (default: 100)
  - `:database` - HSE database to use (default: "prosecution")
  - `:delay_ms` - Delay between requests in ms (default: 1000)
  """
  def enqueue_batch(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    database = Keyword.get(opts, :database, @default_database)
    delay_ms = Keyword.get(opts, :delay_ms, @default_delay_ms)

    case get_cases_missing_breaches(limit) do
      {:ok, cases} ->
        Logger.info("BackfillBreachData: Enqueueing #{length(cases)} cases for backfill")

        results =
          Enum.map(cases, fn case ->
            job =
              %{case_id: case.id, database: database, delay_ms: delay_ms}
              |> new()
              |> Oban.insert()

            {case.regulator_id, job}
          end)

        success_count = Enum.count(results, fn {_, result} -> match?({:ok, _}, result) end)
        Logger.info("BackfillBreachData: Enqueued #{success_count}/#{length(cases)} jobs")

        {:ok, %{enqueued: success_count, total: length(cases)}}

      {:error, reason} ->
        Logger.error("BackfillBreachData: Failed to get cases: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Enqueue all HSE cases that are missing breach data.
  """
  def enqueue_all_missing(opts \\ []) do
    database = Keyword.get(opts, :database, @default_database)
    delay_ms = Keyword.get(opts, :delay_ms, @default_delay_ms)

    case get_cases_missing_breaches(:all) do
      {:ok, cases} ->
        Logger.info("BackfillBreachData: Enqueueing all #{length(cases)} cases for backfill")

        # Stagger jobs to avoid overwhelming the HSE website
        results =
          cases
          |> Enum.with_index()
          |> Enum.map(fn {case, index} ->
            # Schedule jobs with increasing delays to spread load
            scheduled_at = DateTime.add(DateTime.utc_now(), index * 2, :second)

            job =
              %{case_id: case.id, database: database, delay_ms: delay_ms}
              |> new(scheduled_at: scheduled_at)
              |> Oban.insert()

            {case.regulator_id, job}
          end)

        success_count = Enum.count(results, fn {_, result} -> match?({:ok, _}, result) end)
        Logger.info("BackfillBreachData: Enqueued #{success_count}/#{length(cases)} jobs")

        {:ok, %{enqueued: success_count, total: length(cases)}}

      {:error, reason} ->
        Logger.error("BackfillBreachData: Failed to get cases: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get count of HSE cases missing breach data.
  """
  def count_missing do
    case get_cases_missing_breaches(:all) do
      {:ok, cases} -> {:ok, length(cases)}
      error -> error
    end
  end

  # Private functions

  defp get_case(case_id) do
    case Ash.get(Enforcement.Case, case_id) do
      {:ok, nil} -> {:error, :case_not_found}
      {:ok, case} -> {:ok, case}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_cases_missing_breaches(limit) do
    # Get HSE agency ID
    hse_query =
      Enforcement.Agency
      |> Ash.Query.filter(name == "Health and Safety Executive")

    case Ash.read_one(hse_query) do
      {:ok, nil} ->
        {:error, :hse_agency_not_found}

      {:ok, hse_agency} ->
        # Get cases without breach data
        query =
          Enforcement.Case
          |> Ash.Query.filter(
            agency_id == ^hse_agency.id and
              (is_nil(offence_breaches) or offence_breaches == "")
          )
          |> Ash.Query.sort(regulator_id: :asc)

        query =
          case limit do
            :all -> query
            n when is_integer(n) -> Ash.Query.limit(query, n)
          end

        Ash.read(query)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp backfill_case(case, database, delay_ms) do
    # Skip if already has breach data
    if case.offence_breaches && case.offence_breaches != "" do
      {:error, :already_has_breaches}
    else
      # Add delay to be respectful to HSE servers
      Process.sleep(delay_ms)

      # Fetch breach details from HSE website
      case CaseScraper.scrape_case_details(case.regulator_id, database) do
        {:ok, details} ->
          process_breach_details(case, details)

        {:error, reason} ->
          {:error, {:scrape_failed, reason}}
      end
    end
  end

  defp process_breach_details(case, details) do
    # Extract breach text from details
    breach_text = extract_breach_text(details)

    if breach_text && breach_text != "" do
      # Update case with breach text
      case update_case_breaches(case, breach_text) do
        {:ok, updated_case} ->
          # Create offence records
          create_offences_from_breaches(updated_case, breach_text)

        {:error, reason} ->
          {:error, {:update_failed, reason}}
      end
    else
      Logger.debug("BackfillBreachData: No breach data found for case #{case.regulator_id}")
      {:ok, :no_breach_data}
    end
  end

  defp extract_breach_text(details) do
    # Details may contain breach info in various formats
    cond do
      is_map(details) && Map.has_key?(details, :offence_breaches) ->
        details.offence_breaches

      is_map(details) && Map.has_key?(details, "offence_breaches") ->
        details["offence_breaches"]

      is_map(details) && Map.has_key?(details, :breaches) ->
        format_breaches(details.breaches)

      is_map(details) && Map.has_key?(details, "breaches") ->
        format_breaches(details["breaches"])

      true ->
        nil
    end
  end

  defp format_breaches(breaches) when is_list(breaches) do
    breaches
    |> Enum.map(&breach_to_string/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.join("; ")
  end

  defp format_breaches(breach) when is_binary(breach), do: breach
  defp format_breaches(_), do: nil

  defp breach_to_string(breach) when is_map(breach) do
    act = breach[:act] || breach["act"]
    section = breach[:section] || breach["section"]
    mode = breach[:mode] || breach["mode"]

    cond do
      act && section -> "#{act}, #{section}"
      act -> act
      true -> nil
    end
    |> maybe_append_mode(mode)
  end

  defp breach_to_string(breach) when is_binary(breach), do: breach
  defp breach_to_string(_), do: nil

  defp maybe_append_mode(nil, _), do: nil
  defp maybe_append_mode(text, nil), do: text
  defp maybe_append_mode(text, ""), do: text
  defp maybe_append_mode(text, mode), do: "#{text} (#{mode})"

  defp update_case_breaches(case, breach_text) do
    Ash.update(case, %{offence_breaches: breach_text}, action: :update)
  end

  defp create_offences_from_breaches(case, breach_text) do
    # Parse breach text to extract individual breaches
    parsed_breaches = BreachParser.parse_breaches(breach_text)

    if Enum.empty?(parsed_breaches) do
      # Try parsing as single breach
      parsed = BreachParser.parse_breach(breach_text)

      if parsed.act_name do
        create_single_offence(case, parsed, breach_text, 1)
      else
        {:ok, :no_parseable_breaches}
      end
    else
      # Create offence for each parsed breach
      results =
        parsed_breaches
        |> Enum.with_index(1)
        |> Enum.map(fn {parsed, index} ->
          create_single_offence(case, parsed, nil, index)
        end)

      success_count = Enum.count(results, &match?({:ok, _}, &1))
      error_count = Enum.count(results, &match?({:error, _}, &1))

      Logger.info(
        "BackfillBreachData: Created #{success_count} offences for case #{case.regulator_id} (#{error_count} errors)"
      )

      {:ok, %{created: success_count, errors: error_count}}
    end
  end

  defp create_single_offence(case, parsed, description, sequence) do
    # Find or create legislation using TieredMatcher
    case TieredMatcher.find_or_create(%{
           title: parsed.act_name,
           year: parsed.act_year
         }) do
      {:ok, legislation} ->
        # Create offence record
        offence_attrs = %{
          case_id: case.id,
          legislation_id: legislation.id,
          legislation_part: parsed.legislation_part,
          offence_description: description,
          sequence_number: sequence
        }

        case Ash.create(Enforcement.Offence, offence_attrs) do
          {:ok, offence} ->
            {:ok, offence}

          {:error, reason} ->
            Logger.warning(
              "BackfillBreachData: Failed to create offence for case #{case.regulator_id}: #{inspect(reason)}"
            )

            {:error, reason}
        end

      {:error, reason} ->
        Logger.warning(
          "BackfillBreachData: Failed to find/create legislation for #{parsed.act_name}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end
end
