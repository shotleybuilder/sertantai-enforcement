defmodule EhsEnforcement.Scraping.CaseProcessingLog do
  @moduledoc """
  Ash resource for tracking detailed case processing events during scraping sessions.
  
  Stores page-level processing details for real-time UI updates.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Scraping,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "case_processing_logs"
    repo EhsEnforcement.Repo
  end

  pub_sub do
    module(EhsEnforcement.PubSub)
    prefix("case_processing_log")
    
    publish(:create, ["created"])
  end

  attributes do
    uuid_primary_key :id

    attribute :session_id, :string, allow_nil?: false
    attribute :page, :integer, allow_nil?: false
    attribute :cases_scraped, :integer, default: 0
    attribute :cases_created, :integer, default: 0
    attribute :cases_existing, :integer, default: 0
    attribute :creation_errors, {:array, :string}, default: []
    attribute :scraped_case_summary, {:array, :map}, default: []

    timestamps()
  end

  actions do
    defaults [:create, :read, :destroy]
    
    read :for_session do
      argument :session_id, :string, allow_nil?: false
      filter expr(session_id == ^arg(:session_id))
    end
  end

  validations do
    validate compare(:page, greater_than: 0)
    validate compare(:cases_scraped, greater_than_or_equal_to: 0)
  end
end