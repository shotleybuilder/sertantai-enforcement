defmodule EhsEnforcementWeb.CaseLive.CSVExport do
  @moduledoc """
  Handles CSV export functionality for case data
  """

  alias EhsEnforcement.Enforcement

  @csv_headers [
    "Case ID",
    "Regulator ID",
    "Agency",
    "Agency Code",
    "Offender Name",
    "Local Authority",
    "Postcode",
    "Offense Date",
    "Fine Amount",
    "Offense Breaches",
    "Total Notices",
    "Total Breaches",
    "Last Synced",
    "Created At"
  ]

  @detailed_csv_headers [
    "Case ID",
    "Regulator ID",
    "Agency",
    "Agency Code",
    "Offender Name",
    "Local Authority",
    "Postcode",
    "Offense Date",
    "Fine Amount",
    "Offense Breaches",
    "Total Notices",
    "Total Breaches",
    "Notice Types",
    "Notice Actions",
    "Last Synced",
    "Created At"
  ]

  @doc """
  Export cases to CSV format based on current filters
  """
  def export_cases(filters \\ %{}, sort_by \\ :offence_action_date, sort_dir \\ :desc) do
    # Build query options without pagination for full export
    query_opts = [
      filter: build_ash_filter(filters),
      sort: build_sort_options(sort_by, sort_dir),
      load: [:offender, :agency]
    ]

    try do
      cases = Enforcement.list_cases!(query_opts)
      generate_csv(cases)
    rescue
      error ->
        {:error, "Failed to export cases: #{inspect(error)}"}
    end
  end

  @doc """
  Export cases with detailed information including related notice data
  """
  def export_detailed_cases(filters \\ %{}, sort_by \\ :offence_action_date, sort_dir \\ :desc) do
    # Build query options without pagination for full export
    query_opts = [
      filter: build_ash_filter(filters),
      sort: build_sort_options(sort_by, sort_dir),
      load: [:offender, :agency]
    ]

    try do
      cases = Enforcement.list_cases!(query_opts)
      cases_with_notices = load_related_notices(cases)
      generate_detailed_csv(cases_with_notices)
    rescue
      error ->
        {:error, "Failed to export detailed cases: #{inspect(error)}"}
    end
  end

  @doc """
  Export a single case to CSV format
  """
  def export_case(case_id) do
    try do
      case_record = Enforcement.get_case!(case_id, load: [:offender, :agency])
      generate_csv([case_record])
    rescue
      Ash.Error.Query.NotFound ->
        {:error, "Case not found"}

      error ->
        {:error, "Failed to export case: #{inspect(error)}"}
    end
  end

  @doc """
  Generate CSV content from list of cases
  """
  def generate_csv(cases) when is_list(cases) do
    csv_content =
      [@csv_headers | Enum.map(cases, &case_to_csv_row/1)]
      |> Enum.map(&Enum.join(&1, ","))
      |> Enum.join("\n")

    {:ok, csv_content}
  end

  @doc """
  Generate detailed CSV content from list of cases with notice data
  """
  def generate_detailed_csv(cases_with_notices) when is_list(cases_with_notices) do
    csv_content =
      [@detailed_csv_headers | Enum.map(cases_with_notices, &case_to_detailed_csv_row/1)]
      |> Enum.map(&Enum.join(&1, ","))
      |> Enum.join("\n")

    {:ok, csv_content}
  end

  @doc """
  Generate filename for CSV export
  """
  def generate_filename(export_type \\ :all, identifier \\ nil) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic) |> String.slice(0, 8)

    case export_type do
      :single when identifier != nil ->
        "case_#{identifier}_#{timestamp}.csv"

      :filtered ->
        "cases_filtered_#{timestamp}.csv"

      _ ->
        "cases_export_#{timestamp}.csv"
    end
  end

  # Private functions

  defp load_related_notices(cases) do
    # For each case, find notices that have the same agency and offender
    Enum.map(cases, fn case_record ->
      notices =
        Enforcement.list_notices!(
          filter: [
            agency_id: case_record.agency_id,
            offender_id: case_record.offender_id
          ]
        )

      Map.put(case_record, :related_notices, notices)
    end)
  end

  defp case_to_detailed_csv_row(case_record) do
    # Get notice information
    notice_types = extract_notice_types(case_record.related_notices || [])
    notice_actions = extract_notice_actions(case_record.related_notices || [])

    [
      escape_csv_field(case_record.regulator_id || ""),
      # Also include as Regulator ID
      escape_csv_field(case_record.regulator_id || ""),
      escape_csv_field(case_record.agency.name || ""),
      escape_csv_field(to_string(case_record.agency.code)),
      escape_csv_field(case_record.offender.name || ""),
      escape_csv_field(case_record.offender.local_authority || ""),
      escape_csv_field(case_record.offender.postcode || ""),
      format_date_for_csv(case_record.offence_action_date),
      format_currency_for_csv(case_record.offence_fine),
      escape_csv_field(case_record.offence_breaches || ""),
      # actual notices count
      length(case_record.related_notices || []),
      # breaches count (not loaded)
      0,
      escape_csv_field(notice_types),
      escape_csv_field(notice_actions),
      format_datetime_for_csv(case_record.last_synced_at),
      format_datetime_for_csv(case_record.inserted_at)
    ]
  end

  defp extract_notice_types(notices) do
    notices
    |> Enum.map(& &1.offence_action_type)
    |> Enum.filter(&(&1 != nil))
    |> Enum.join("; ")
  end

  defp extract_notice_actions(notices) do
    notices
    |> Enum.map(fn notice ->
      action =
        cond do
          String.contains?(notice.notice_body || "", "improvement") -> "improvement"
          String.contains?(notice.notice_body || "", "prohibition") -> "prohibition"
          true -> notice.offence_action_type
        end

      # Add compliance status if available
      compliance_status =
        case notice.compliance_date do
          %Date{} = compliance_date ->
            if Date.compare(compliance_date, Date.utc_today()) in [:eq, :lt] do
              "complied"
            else
              "pending"
            end

          _ ->
            nil
        end

      if compliance_status do
        "#{action} (#{compliance_status})"
      else
        action
      end
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.join("; ")
  end

  defp case_to_csv_row(case_record) do
    [
      escape_csv_field(case_record.regulator_id || ""),
      # Also include as Regulator ID
      escape_csv_field(case_record.regulator_id || ""),
      escape_csv_field(case_record.agency.name || ""),
      escape_csv_field(to_string(case_record.agency.code)),
      escape_csv_field(case_record.offender.name || ""),
      escape_csv_field(case_record.offender.local_authority || ""),
      escape_csv_field(case_record.offender.postcode || ""),
      format_date_for_csv(case_record.offence_action_date),
      format_currency_for_csv(case_record.offence_fine),
      escape_csv_field(case_record.offence_breaches || ""),
      # notices count (not loaded)
      0,
      # breaches count (not loaded)
      0,
      format_datetime_for_csv(case_record.last_synced_at),
      format_datetime_for_csv(case_record.inserted_at)
    ]
  end

  defp escape_csv_field(field) when is_binary(field) do
    # Handle CSV injection prevention - remove dangerous prefixes completely
    sanitized = String.replace(field, ~r/^[=+@-]/, "_")

    if String.contains?(sanitized, [",", "\"", "\n", "\r"]) do
      "\"#{String.replace(sanitized, "\"", "\"\"")}\""
    else
      sanitized
    end
  end

  defp escape_csv_field(field), do: to_string(field)

  defp format_date_for_csv(date) when is_struct(date, Date) do
    Date.to_iso8601(date)
  end

  defp format_date_for_csv(_), do: ""

  defp format_datetime_for_csv(datetime) when is_struct(datetime, DateTime) do
    DateTime.to_iso8601(datetime)
  end

  defp format_datetime_for_csv(_), do: ""

  defp format_currency_for_csv(amount) when is_struct(amount, Decimal) do
    Decimal.to_string(amount)
  end

  defp format_currency_for_csv(_), do: "0.00"

  # Unused function commented out:
  # defp count_associations(associations) when is_list(associations) do
  #   length(associations)
  # end
  # defp count_associations(_), do: 0

  # Copy filter and sort building logic from Index module
  defp build_ash_filter(filters) do
    Enum.reduce(filters, [], fn
      {:agency_id, id}, acc when is_binary(id) and id != "" ->
        [{:agency_id, id} | acc]

      {:date_from, date}, acc when is_binary(date) and date != "" ->
        case Date.from_iso8601(date) do
          {:ok, parsed_date} ->
            [{:offence_action_date, [greater_than_or_equal_to: parsed_date]} | acc]

          _ ->
            acc
        end

      {:date_to, date}, acc when is_binary(date) and date != "" ->
        case Date.from_iso8601(date) do
          {:ok, parsed_date} ->
            [{:offence_action_date, [less_than_or_equal_to: parsed_date]} | acc]

          _ ->
            acc
        end

      {:min_fine, amount}, acc when is_binary(amount) and amount != "" ->
        case Decimal.parse(amount) do
          {decimal_amount, _} ->
            [{:offence_fine, [greater_than_or_equal_to: decimal_amount]} | acc]

          :error ->
            acc
        end

      {:max_fine, amount}, acc when is_binary(amount) and amount != "" ->
        case Decimal.parse(amount) do
          {decimal_amount, _} -> [{:offence_fine, [less_than_or_equal_to: decimal_amount]} | acc]
          :error -> acc
        end

      {:search, query}, acc when is_binary(query) and query != "" ->
        search_conditions = [
          [offender: [name: [ilike: "%#{query}%"]]],
          [regulator_id: [ilike: "%#{query}%"]],
          [offence_breaches: [ilike: "%#{query}%"]]
        ]

        [{:or, search_conditions} | acc]

      _, acc ->
        acc
    end)
  end

  defp build_sort_options(sort_by, sort_dir) do
    case {sort_by, sort_dir} do
      {:offender_name, dir} ->
        [offender: [name: dir]]

      {:agency_name, dir} ->
        [agency: [name: dir]]

      {field, dir} when field in [:offence_action_date, :offence_fine, :regulator_id] ->
        [{field, dir}]

      _ ->
        [offence_action_date: :desc]
    end
  end
end
