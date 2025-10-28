defmodule EhsEnforcement.Scraping.ScrapedCase do
  @moduledoc """
  Ash resource for tracking individual scraped cases with processing status.

  Stores real-time case processing data for UI display during scraping.
  """

  use Ash.Resource,
    domain: EhsEnforcement.Scraping,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table("scraped_cases")
    repo(EhsEnforcement.Repo)
  end

  pub_sub do
    module(EhsEnforcement.PubSub)
    prefix("scraped_case")

    publish(:create, ["created"])
    publish(:update, ["updated"])
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:session_id, :string, allow_nil?: false)
    attribute(:regulator_id, :string, allow_nil?: false)
    attribute(:page, :integer, allow_nil?: false)

    # Case data
    attribute(:offender_name, :string)
    attribute(:offence_action_date, :date)
    attribute(:offence_fine, :decimal)
    attribute(:offence_result, :string)

    # Processing status tracking
    attribute :processing_status, :atom do
      constraints(one_of: [:scraping, :scraped, :ready_for_db, :error])
      default(:scraping)
    end

    attribute :database_status, :atom do
      constraints(one_of: [:pending, :created, :updated, :existing, :error])
      default(:pending)
    end

    timestamps()
  end

  actions do
    defaults([:create, :read, :update, :destroy])

    read :for_session do
      argument(:session_id, :string, allow_nil?: false)
      filter(expr(session_id == ^arg(:session_id)))
    end

    update :mark_scraped do
      accept([
        :offender_name,
        :offence_action_date,
        :offence_fine,
        :offence_result,
        :processing_status
      ])
    end

    update :set_database_status do
      accept([:database_status])
    end
  end

  validations do
    validate(compare(:page, greater_than: 0))
  end

  identities do
    identity(:unique_case_per_session, [:session_id, :regulator_id, :page])
  end
end
