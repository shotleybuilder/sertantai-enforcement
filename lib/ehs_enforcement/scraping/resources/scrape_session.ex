defmodule EhsEnforcement.Scraping.ScrapeSession do
  @moduledoc """
  Ash resource for tracking HSE scraping sessions with real-time progress updates.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Scraping,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "scrape_sessions"
    repo EhsEnforcement.Repo
  end

  pub_sub do
    module(EhsEnforcement.PubSub)
    prefix("scrape_session")
    
    publish(:create, ["created"])
    publish(:update, ["updated"])
  end

  attributes do
    uuid_primary_key :id

    attribute :session_id, :string do
      allow_nil? false
    end

    attribute :start_page, :integer do
      allow_nil? false
      default 1
    end

    attribute :max_pages, :integer do
      allow_nil? false
      default 10
    end

    attribute :database, :string do
      allow_nil? false
      default "convictions"
      constraints [allow_empty?: false]
    end

    attribute :status, :atom do
      allow_nil? false
      default :pending
      constraints one_of: [:pending, :running, :completed, :failed, :stopped]
    end

    attribute :current_page, :integer
    attribute :pages_processed, :integer, default: 0
    attribute :cases_found, :integer, default: 0
    attribute :cases_created, :integer, default: 0
    attribute :cases_exist_total, :integer, default: 0
    attribute :cases_exist_current_page, :integer, default: 0
    attribute :errors_count, :integer, default: 0

    timestamps()
  end

  actions do
    defaults [:read, :destroy]
    
    create :create do
      primary? true
      accept [
        :session_id, :start_page, :max_pages, :database, :status,
        :current_page, :pages_processed, :cases_found, :cases_created,
        :cases_exist_total, :errors_count
      ]
    end
    
    update :update do
      primary? true
      require_atomic? false
      accept [
        :status, :current_page, :pages_processed, :cases_found,
        :cases_created, :cases_exist_total, :cases_exist_current_page, :errors_count
      ]
    end
    
    read :active do
      description "Get currently active/running sessions"
      filter expr(status in [:pending, :running])
    end
  end

  validations do
    validate compare(:start_page, greater_than: 0)
    validate compare(:max_pages, greater_than: 0)
    validate compare(:max_pages, less_than_or_equal_to: 100)
    # TODO: Re-enable when Ash framework bug is fixed
    # validate attribute_in(:database, ["convictions", "notices"])
  end

  identities do
    identity :unique_session_id, [:session_id]
  end
end