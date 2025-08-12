defmodule EhsEnforcement.Enforcement.Metrics do
  @moduledoc """
  Cached dashboard metrics for performance optimization.
  
  Stores pre-computed statistics to avoid real-time calculations on dashboard page loads.
  Metrics are refreshed manually via admin interface or scheduled after scraping operations.
  """

  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table("metrics")
    repo(EhsEnforcement.Repo)
  end

  pub_sub do
    module(EhsEnforcement.PubSub)
    prefix("metrics")
    
    # Broadcast when metrics are refreshed
    publish(:refresh, ["refreshed"])
  end

  attributes do
    # Primary key and timestamps
    uuid_primary_key :id
    timestamps()

    # Time periods for the metrics
    attribute :period, :atom do
      allow_nil? false
      constraints one_of: [:week, :month, :year]
      description "Time period for the metrics (week, month, or year)"
    end
    
    attribute :period_label, :string do
      allow_nil? false
      description "Human readable period label (e.g., 'Last 30 Days')"
    end
    
    attribute :days_ago, :integer do
      allow_nil? false
      description "Number of days back from today for the period"
    end

    # Core counts
    attribute :recent_cases_count, :integer do
      allow_nil? false
      default 0
      description "Number of cases within the time period"
    end
    
    attribute :recent_notices_count, :integer do
      allow_nil? false
      default 0
      description "Number of notices within the time period"
    end
    
    attribute :total_cases_count, :integer do
      allow_nil? false
      default 0
      description "Total number of cases (all time)"
    end
    
    attribute :total_notices_count, :integer do
      allow_nil? false
      default 0
      description "Total number of notices (all time)"
    end

    # Financial metrics
    attribute :total_fines_amount, :decimal do
      allow_nil? false
      default Decimal.new(0)
      description "Total fines from cases within the time period"
    end

    # Agency metrics
    attribute :active_agencies_count, :integer do
      allow_nil? false
      default 0
      description "Number of enabled agencies"
    end

    # Agency statistics as JSON
    attribute :agency_stats, :map do
      allow_nil? false
      default %{}
      description "Per-agency statistics with enhanced breakdown for dashboard dropdown filtering"
    end

    # Metadata
    attribute :calculated_at, :utc_datetime_usec do
      allow_nil? false
      description "When these metrics were calculated"
    end
    
    attribute :calculated_by, :atom do
      allow_nil? false
      constraints one_of: [:admin, :automation]
      description "Whether metrics were calculated manually by admin or via automation"
    end
    
    attribute :cutoff_date, :date do
      allow_nil? false
      description "The cutoff date used for recent data filtering"
    end
  end

  actions do
    defaults [:read, :destroy]

    read :get_current do
      description "Get the most recent metrics for each time period"
      
      prepare fn query, _context ->
        # Get the latest metrics for each period
        query
        |> Ash.Query.sort(calculated_at: :desc)
      end
    end

    create :refresh do
      description "Refresh all dashboard metrics by recalculating from current data"
      
      # Accept all attributes for manual creation during refresh
      accept [
        :period, :period_label, :days_ago, :recent_cases_count, :recent_notices_count,
        :total_cases_count, :total_notices_count, :total_fines_amount, 
        :active_agencies_count, :agency_stats, :calculated_at, :calculated_by, :cutoff_date
      ]
    end
  end


  code_interface do
    define :get_current_metrics, action: :get_current
    define :refresh_metrics, action: :refresh
  end

  @doc """
  Refresh all dashboard metrics by recalculating from current data.
  
  This function:
  1. Clears existing metrics
  2. Calculates new metrics for all time periods (week, month, year)  
  3. Stores the results in the database
  4. Broadcasts refresh notification via PubSub
  
  ## Parameters
  - `calculated_by` (optional): :admin or :automation (defaults to :admin)
  """
  def refresh_all_metrics(calculated_by \\ :admin) do
    # Delete existing metrics to avoid duplicates
    EhsEnforcement.Enforcement.Metrics
    |> Ash.Query.for_read(:read)
    |> Ash.read!()
    |> Enum.each(&Ash.destroy!(&1))

    # Calculate metrics for all time periods
    periods = [
      %{period: :week, days_ago: 7, label: "Last 7 Days"},
      %{period: :month, days_ago: 30, label: "Last 30 Days"},
      %{period: :year, days_ago: 365, label: "Last 365 Days"}
    ]

    # Calculate and create new metrics for each period
    results = for period_config <- periods do
      calculate_and_create_metrics(period_config, calculated_by)
    end

    # Metrics refreshed - Ash PubSub will automatically broadcast

    {:ok, results}
  end

  defp calculate_and_create_metrics(%{period: period, days_ago: days_ago, label: label}, calculated_by) do
    cutoff_date = Date.add(Date.utc_today(), -days_ago)
    calculated_at = DateTime.utc_now()

    # Load all data (we'll optimize this later with database aggregations)
    all_cases = EhsEnforcement.Enforcement.list_cases_with_filters!([])
    all_notices = EhsEnforcement.Enforcement.list_notices_with_filters!([])
    all_agencies = EhsEnforcement.Enforcement.list_agencies!()

    # Filter for recent items
    recent_cases = Enum.filter(all_cases, fn case_record ->
      case_record.offence_action_date && Date.compare(case_record.offence_action_date, cutoff_date) != :lt
    end)

    recent_notices = Enum.filter(all_notices, fn notice_record ->
      notice_record.offence_action_date && Date.compare(notice_record.offence_action_date, cutoff_date) != :lt
    end)

    # Calculate totals
    recent_cases_count = length(recent_cases)
    recent_notices_count = length(recent_notices)
    total_cases_count = length(all_cases)
    total_notices_count = length(all_notices)

    # Calculate total fines
    total_fines_amount = recent_cases
    |> Enum.map(& &1.offence_fine || Decimal.new(0))
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    # Calculate agency stats with enhanced breakdown for dashboard filtering
    agency_stats = all_agencies
    |> Enum.map(fn agency ->
      agency_recent_cases = Enum.count(recent_cases, & &1.agency_id == agency.id)
      agency_recent_notices = Enum.count(recent_notices, & &1.agency_id == agency.id)
      
      # Calculate total fines for this agency
      agency_total_fines = recent_cases
      |> Enum.filter(& &1.agency_id == agency.id)
      |> Enum.map(& &1.offence_fine || Decimal.new(0))
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
      
      %{
        agency_id: agency.id,
        agency_code: agency.code,
        agency_name: agency.name,
        enabled: agency.enabled,
        case_count: agency_recent_cases,
        notice_count: agency_recent_notices,
        total_actions: agency_recent_cases + agency_recent_notices,
        total_fines: agency_total_fines,
        case_percentage: if(recent_cases_count > 0, do: Float.round(agency_recent_cases / recent_cases_count * 100, 1), else: 0),
        action_percentage: if((recent_cases_count + recent_notices_count) > 0, do: Float.round((agency_recent_cases + agency_recent_notices) / (recent_cases_count + recent_notices_count) * 100, 1), else: 0)
      }
    end)
    |> Enum.into(%{}, fn stat -> {stat.agency_id, stat} end)

    # Create metrics record
    attrs = %{
      period: period,
      period_label: label,
      days_ago: days_ago,
      recent_cases_count: recent_cases_count,
      recent_notices_count: recent_notices_count,
      total_cases_count: total_cases_count,
      total_notices_count: total_notices_count,
      total_fines_amount: total_fines_amount,
      active_agencies_count: Enum.count(all_agencies, & &1.enabled),
      agency_stats: agency_stats,
      calculated_at: calculated_at,
      calculated_by: calculated_by,
      cutoff_date: cutoff_date
    }

    EhsEnforcement.Enforcement.Metrics
    |> Ash.Changeset.for_create(:refresh, attrs)
    |> Ash.create!()
  end
end