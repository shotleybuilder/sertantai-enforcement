defmodule EhsEnforcement.Scraping.Backfill.BackfillNoticeOffences do
  @moduledoc """
  Backfill offences for notices that have legal_section data but no linked offences.

  This is for EA/SEPA/NRW notices that already have legislation information stored
  in the `legal_section` field but haven't had Offence records created.

  ## Usage

  Process all notices with legal_section data:

      BackfillNoticeOffences.process_all()

  Process a batch:

      BackfillNoticeOffences.process_batch(limit: 100)

  Process a single notice:

      BackfillNoticeOffences.process_notice(notice)
  """

  require Logger
  require Ash.Query

  alias EhsEnforcement.Enforcement.Notice
  alias EhsEnforcement.Enforcement.Offence
  alias EhsEnforcement.Legislation.TieredMatcher

  @doc """
  Process all notices that have legal_section data but no offences.
  """
  def process_all do
    case get_notices_needing_offences() do
      {:ok, notices} ->
        Logger.info("BackfillNoticeOffences: Processing #{length(notices)} notices")
        results = Enum.map(notices, &process_notice/1)

        success_count = Enum.count(results, &match?({:ok, _}, &1))
        error_count = Enum.count(results, &match?({:error, _}, &1))
        skip_count = Enum.count(results, &match?(:skip, &1))

        Logger.info(
          "BackfillNoticeOffences: Completed - #{success_count} created, #{skip_count} skipped, #{error_count} errors"
        )

        {:ok, %{created: success_count, skipped: skip_count, errors: error_count}}

      {:error, reason} ->
        Logger.error("BackfillNoticeOffences: Failed to get notices: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Process a batch of notices.
  """
  def process_batch(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    case get_notices_needing_offences(limit) do
      {:ok, notices} ->
        Logger.info("BackfillNoticeOffences: Processing batch of #{length(notices)} notices")
        results = Enum.map(notices, &process_notice/1)

        success_count = Enum.count(results, &match?({:ok, _}, &1))
        error_count = Enum.count(results, &match?({:error, _}, &1))
        skip_count = Enum.count(results, &match?(:skip, &1))

        {:ok, %{created: success_count, skipped: skip_count, errors: error_count}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Process a single notice to create offence records from legal_section data.
  """
  def process_notice(%Notice{} = notice) do
    Logger.debug("BackfillNoticeOffences: Processing notice #{notice.id}")

    # Check if notice already has offences
    case Ash.read(Offence |> Ash.Query.filter(notice_id == ^notice.id) |> Ash.Query.limit(1)) do
      {:ok, [_ | _]} ->
        Logger.debug("BackfillNoticeOffences: Notice #{notice.id} already has offences, skipping")
        :skip

      _ ->
        create_offence_from_legal_section(notice)
    end
  end

  # Get notices with legal_section but potentially no offences
  defp get_notices_needing_offences(limit \\ nil) do
    query =
      Notice
      |> Ash.Query.filter(not is_nil(legal_section) and legal_section != "")

    query = if limit, do: Ash.Query.limit(query, limit), else: query

    Ash.read(query)
  end

  # Create offence from notice's legal_section field
  defp create_offence_from_legal_section(notice) do
    legal_section = notice.legal_section

    if is_nil(legal_section) or legal_section == "" do
      Logger.debug("BackfillNoticeOffences: No legal_section for notice #{notice.id}")
      :skip
    else
      # Parse the legal_section to extract components
      parsed = parse_legal_section(legal_section)

      # Try to find or create legislation
      case find_or_create_legislation(parsed, notice) do
        {:ok, legislation} ->
          # Create the offence
          create_offence(notice, legislation, parsed)

        {:error, reason} ->
          Logger.warning(
            "BackfillNoticeOffences: Failed to find/create legislation for notice #{notice.id}: #{inspect(reason)}"
          )

          {:error, reason}
      end
    end
  end

  # Parse legal_section text to extract act/regulation and section
  defp parse_legal_section(legal_section) do
    # Examples from data:
    # "Reg 26(1)(a) - Suspension of reprocessor/exporter accreditation breach of Schedule 5"
    # "S34(5) - Furnish written descriptions / transfer Notes"
    # "Regulation 38(2)"

    # Try to extract act name from common patterns
    act_patterns = [
      # Environmental Permitting Regulations patterns
      ~r/Reg(?:ulation)?\s+\d+/i,
      # Various Acts
      ~r/S(?:ection)?\s*\d+/i
    ]

    section =
      Enum.find_value(act_patterns, fn pattern ->
        case Regex.run(pattern, legal_section) do
          [match] -> match
          _ -> nil
        end
      end)

    # Extract description (after the dash)
    description =
      case String.split(legal_section, " - ", parts: 2) do
        [_, desc] -> String.trim(desc)
        _ -> nil
      end

    # Determine likely act based on content
    act_name = infer_act_from_context(legal_section)

    %{
      act_name: act_name,
      section: section || extract_section_number(legal_section),
      description: description,
      full_text: legal_section
    }
  end

  # Infer the act name from keywords in the legal_section
  defp infer_act_from_context(legal_section) do
    cond do
      String.contains?(legal_section, ["Schedule 5", "reprocessor", "exporter", "accreditation"]) ->
        "Producer Responsibility (Packaging Waste) Regulations 2007"

      String.contains?(legal_section, ["transfer Note", "Furnish written"]) ->
        "Environmental Protection Act 1990"

      String.contains?(legal_section, ["permit", "Permitting"]) ->
        "Environmental Permitting (England and Wales) Regulations 2016"

      String.contains?(legal_section, ["waste", "Waste"]) ->
        "Waste (England and Wales) Regulations 2011"

      String.contains?(legal_section, ["pollution", "discharge"]) ->
        "Environmental Permitting (England and Wales) Regulations 2016"

      String.contains?(legal_section, ["illegally deposited"]) ->
        "Environmental Protection Act 1990"

      true ->
        # Default to EPR for most EA notices
        "Environmental Permitting (England and Wales) Regulations 2016"
    end
  end

  # Extract section number from text
  defp extract_section_number(text) do
    case Regex.run(
           ~r/(?:Reg(?:ulation)?|S(?:ection)?|Para(?:graph)?)\s*(\d+(?:\(\d+\))*(?:\([a-z]\))*)/i,
           text
         ) do
      [_, section] -> section
      _ -> nil
    end
  end

  # Find or create legislation using TieredMatcher
  defp find_or_create_legislation(parsed, notice) do
    # Build data for TieredMatcher - it expects :title, :year, :number, :type_code, :url, :type
    legislation_data = %{
      title: parsed.act_name
    }

    case TieredMatcher.find_or_create(legislation_data) do
      {:ok, legislation} ->
        {:ok, legislation}

      {:error, _reason} ->
        # If TieredMatcher fails, try creating basic legislation
        Logger.debug(
          "BackfillNoticeOffences: TieredMatcher failed for #{notice.id}, trying direct creation"
        )

        create_basic_legislation(parsed)
    end
  end

  # Create basic legislation if TieredMatcher fails
  defp create_basic_legislation(parsed) do
    alias EhsEnforcement.Enforcement.Legislation

    # First try to find existing legislation by title
    case Ash.read(
           Legislation
           |> Ash.Query.filter(contains(legislation_title, ^parsed.act_name))
           |> Ash.Query.limit(1)
         ) do
      {:ok, [existing | _]} ->
        Logger.debug("BackfillNoticeOffences: Found existing legislation: #{existing.id}")
        {:ok, existing}

      _ ->
        # Create with only accepted attributes
        attrs = %{
          legislation_title: parsed.act_name,
          legislation_type: :regulation
        }

        case Ash.create(Legislation, attrs) do
          {:ok, legislation} ->
            Logger.debug("BackfillNoticeOffences: Created basic legislation: #{legislation.id}")
            {:ok, legislation}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # Create offence record linking notice to legislation
  defp create_offence(notice, legislation, parsed) do
    attrs = %{
      notice_id: notice.id,
      legislation_id: legislation.id,
      offence_description: parsed.description || parsed.full_text,
      legislation_part: parsed.section,
      sequence_number: 1
    }

    case Ash.create(Offence, attrs) do
      {:ok, offence} ->
        Logger.info(
          "BackfillNoticeOffences: Created offence #{offence.id} for notice #{notice.id}"
        )

        {:ok, offence}

      {:error, reason} ->
        Logger.error(
          "BackfillNoticeOffences: Failed to create offence for notice #{notice.id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end
end
