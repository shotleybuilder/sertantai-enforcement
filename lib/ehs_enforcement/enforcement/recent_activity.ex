defmodule EhsEnforcement.Enforcement.RecentActivity do
  @moduledoc """
  Context for fetching and managing recent enforcement activity data.
  Combines court cases and enforcement notices for Recent Activity table.
  """

  # import Ash.Query  # Unused import removed
  require Ash.Query

  # Unused aliases removed:
  # alias EhsEnforcement.Enforcement
  # alias EhsEnforcement.Enforcement.Case
  # alias EhsEnforcement.Enforcement.Notice

  @doc """
  Fetches recent enforcement activity combining cases and notices.
  """
  def list_recent_activity(opts \\ []) do
    filter_type = Keyword.get(opts, :filter_type, :all)
    limit = Keyword.get(opts, :limit, 20)

    case filter_type do
      :cases -> list_recent_cases(limit)
      :notices -> list_recent_notices(limit)
      :all -> list_all_recent_activity(limit)
    end
  end

  @doc """
  Fetches recent court cases.
  """
  def list_recent_cases(_limit \\ 20) do
    # For now, return sample data until proper Ash queries are implemented
    get_sample_cases()
  end

  @doc """
  Fetches recent enforcement notices.
  """
  def list_recent_notices(_limit \\ 20) do
    # For now, return sample data until proper Ash queries are implemented
    get_sample_notices()
  end

  @doc """
  Returns sample court cases for testing and development.
  """
  def get_sample_cases do
    [
      %{
        id: "case-1",
        type: "Court Case",
        date: ~D[2024-01-15],
        organization: "Test Company Ltd",
        description: "Health and safety violations leading to court proceedings",
        fine_amount: Decimal.new("25000.00"),
        agency_link: "https://www.hse.gov.uk/prosecutions/case-123",
        is_case: true
      },
      %{
        id: "case-2",
        type: "Court Case",
        date: ~D[2024-01-10],
        organization: "XYZ Construction plc",
        description: "Breach of health and safety regulations on construction site",
        fine_amount: Decimal.new("120000.00"),
        agency_link: "https://www.hse.gov.uk/prosecutions/case-xyz-construction",
        is_case: true
      }
    ]
  end

  @doc """
  Returns sample enforcement notices for testing and development.
  """
  def get_sample_notices do
    [
      %{
        id: "notice-1",
        type: "Improvement Notice",
        date: ~D[2024-01-20],
        organization: "Example Corp",
        description: "Workplace safety improvements required",
        fine_amount: nil,
        agency_link: "https://www.hse.gov.uk/notices/notice-456",
        is_case: false
      },
      %{
        id: "notice-2",
        type: "Prohibition Notice",
        date: ~D[2024-01-18],
        organization: "GHI Industries",
        description: "Immediate cessation of dangerous work activities",
        fine_amount: nil,
        agency_link: "https://www.hse.gov.uk/notices/prohibition-ghi-industries",
        is_case: false
      },
      %{
        id: "notice-3",
        type: "Crown Notice",
        date: ~D[2024-01-16],
        organization: "JKL Public Sector",
        description: "Crown body enforcement action for regulatory compliance",
        fine_amount: nil,
        agency_link: "https://www.hse.gov.uk/notices/crown-jkl-public",
        is_case: false
      }
    ]
  end

  @doc """
  Fetches all recent activity (cases and notices combined).
  """
  def list_all_recent_activity(limit \\ 20) do
    cases = list_recent_cases(div(limit, 2))
    notices = list_recent_notices(div(limit, 2))

    (cases ++ notices)
    |> Enum.sort_by(& &1.date, {:desc, Date})
    |> Enum.take(limit)
  end

  # These will be used when actual Ash queries are implemented
  # defp format_activity_item(%Case{} = case_record) do
  #   %{
  #     id: case_record.id,
  #     type: case_record.offence_action_type || "Court Case",
  #     date: case_record.offence_action_date,
  #     organization: case_record.offender.name,
  #     description: case_record.offence_breaches || "Court case proceeding",
  #     fine_amount: case_record.offence_fine,
  #     agency_link: case_record.url,
  #     is_case: true
  #   }
  # end

  # defp format_activity_item(%Notice{} = notice_record) do
  #   %{
  #     id: notice_record.id,
  #     type: notice_record.offence_action_type || "Enforcement Notice",
  #     date: notice_record.offence_action_date,
  #     organization: notice_record.offender.name,
  #     description: notice_record.offence_breaches || "Enforcement notice issued",
  #     fine_amount: nil,
  #     agency_link: notice_record.url,
  #     is_case: false
  #   }
  # end

  @doc """
  Returns whether an activity item represents a court case.
  """
  def court_case?(%{type: "Court Case"}), do: true
  def court_case?(_), do: false

  @doc """
  Returns whether an activity item represents an enforcement notice.
  """
  def enforcement_notice?(%{is_case: false}), do: true
  def enforcement_notice?(_), do: false

  @doc """
  Formats fine amount for display.
  """
  def format_fine_amount(nil), do: "N/A"

  def format_fine_amount(%Decimal{} = amount) do
    "£#{Decimal.to_string(amount, :normal) |> add_commas()}"
  end

  def format_fine_amount(amount) when is_binary(amount) do
    case Decimal.parse(amount) do
      {decimal_amount, ""} -> "£#{Decimal.to_string(decimal_amount, :normal) |> add_commas()}"
      _ -> amount
    end
  end

  def format_fine_amount(amount) when is_integer(amount) do
    "£#{Integer.to_string(amount) |> add_commas()}"
  end

  def format_fine_amount(amount) when is_float(amount) do
    "£#{Float.to_string(amount) |> add_commas()}"
  end

  defp add_commas(string) do
    string
    |> String.reverse()
    |> String.split("", trim: true)
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end
end
