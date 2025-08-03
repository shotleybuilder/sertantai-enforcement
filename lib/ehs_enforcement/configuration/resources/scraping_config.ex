defmodule EhsEnforcement.Configuration.ScrapingConfig do
  @moduledoc """
  Configuration resource for HSE case scraping operations.
  
  Manages all configurable aspects of the scraping system:
  - HSE endpoints and database targets
  - Rate limiting and timeout settings
  - Scraping schedules and feature flags
  - Error handling thresholds
  """
  
  require Logger
  
  use Ash.Resource,
    domain: EhsEnforcement.Configuration,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "scraping_configs"
    repo EhsEnforcement.Repo
  end

  json_api do
    type "scraping_config"
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      description "Configuration profile name (e.g., 'hse_production', 'hse_development')"
    end

    attribute :is_active, :boolean do
      allow_nil? false
      default true
      description "Whether this configuration profile is currently active"
    end

    # HSE Endpoint Configuration
    attribute :hse_base_url, :string do
      allow_nil? false
      default "https://www.hse.gov.uk"
      constraints match: ~r/^https?:\/\/.+/
      description "Base URL for HSE website"
    end

    attribute :hse_database, :string do
      allow_nil? false
      default "convictions"
      description "HSE database to scrape (convictions, enforcement, notices)"
    end

    # Rate Limiting Configuration
    attribute :requests_per_minute, :integer do
      allow_nil? false
      default 10
      description "Maximum HTTP requests per minute to HSE website"
    end

    attribute :network_timeout_ms, :integer do
      allow_nil? false
      default 30_000
      description "HTTP request timeout in milliseconds"
    end

    attribute :pause_between_pages_ms, :integer do
      allow_nil? false
      default 3_000
      description "Pause between page requests in milliseconds"
    end

    # Scraping Behavior Configuration
    attribute :consecutive_existing_threshold, :integer do
      allow_nil? false
      default 10
      description "Stop scraping after this many consecutive existing records"
    end

    attribute :max_pages_per_session, :integer do
      allow_nil? false
      default 100
      description "Maximum pages to process in a single scraping session"
    end

    attribute :max_consecutive_errors, :integer do
      allow_nil? false
      default 3
      description "Stop scraping after this many consecutive errors"
    end

    attribute :batch_size, :integer do
      allow_nil? false
      default 50
      description "Number of cases to process in each batch"
    end

    # Feature Flags
    attribute :scheduled_scraping_enabled, :boolean do
      allow_nil? false
      default true
      description "Enable or disable scheduled automatic scraping"
    end

    attribute :manual_scraping_enabled, :boolean do
      allow_nil? false
      default true
      description "Enable or disable manual admin-triggered scraping"
    end

    attribute :real_time_progress_enabled, :boolean do
      allow_nil? false
      default true
      description "Enable real-time progress updates via PubSub"
    end

    attribute :admin_notifications_enabled, :boolean do
      allow_nil? false
      default true
      description "Enable admin notifications for critical errors"
    end

    # Schedule Configuration (cron expressions)
    attribute :daily_scrape_cron, :string do
      allow_nil? true
      default "0 2 * * *"
      description "Cron expression for daily scraping (default: 2 AM daily)"
    end

    attribute :weekly_scrape_cron, :string do
      allow_nil? true
      default "0 1 * * 0"
      description "Cron expression for weekly comprehensive scraping (default: 1 AM Sunday)"
    end

    # Metadata
    attribute :description, :string do
      allow_nil? true
      description "Optional description of this configuration profile"
    end

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :description, :is_active, :hse_base_url, :hse_database, :requests_per_minute, 
              :network_timeout_ms, :pause_between_pages_ms, :consecutive_existing_threshold,
              :max_pages_per_session, :max_consecutive_errors, :batch_size,
              :scheduled_scraping_enabled, :manual_scraping_enabled, 
              :real_time_progress_enabled, :admin_notifications_enabled,
              :daily_scrape_cron, :weekly_scrape_cron]
    end

    update :update do
      primary? true
      accept [:description, :is_active, :hse_base_url, :hse_database, :requests_per_minute, 
              :network_timeout_ms, :pause_between_pages_ms, :consecutive_existing_threshold,
              :max_pages_per_session, :max_consecutive_errors, :batch_size,
              :scheduled_scraping_enabled, :manual_scraping_enabled, 
              :real_time_progress_enabled, :admin_notifications_enabled,
              :daily_scrape_cron, :weekly_scrape_cron]
    end

    update :activate do
      description "Activate this configuration profile and deactivate others"
      accept []
      require_atomic? false
      
      change fn changeset, context ->
        # Deactivate all other profiles first
        case Ash.read(EhsEnforcement.Configuration.ScrapingConfig, actor: context[:actor]) do
          {:ok, configs} ->
            Enum.each(configs, fn config ->
              if config.id != Ash.Changeset.get_attribute(changeset, :id) do
                Ash.update!(config, %{is_active: false}, actor: context[:actor])
              end
            end)
          _ -> :ok
        end
        
        Ash.Changeset.change_attribute(changeset, :is_active, true)
      end
    end

    update :deactivate do
      description "Deactivate this configuration profile"
      accept []
      
      change set_attribute(:is_active, false)
    end

    read :active do
      description "Get the currently active configuration profile"
      filter expr(is_active == true)
    end

    read :by_name do
      description "Find configuration by name"
      argument :name, :string, allow_nil?: false
      filter expr(name == ^arg(:name))
    end
  end

  validations do
    validate compare(:requests_per_minute, greater_than: 0),
      message: "Requests per minute must be greater than 0"

    validate compare(:network_timeout_ms, greater_than: 5000),
      message: "Network timeout must be at least 5 seconds"

    validate compare(:consecutive_existing_threshold, greater_than: 2),
      message: "Consecutive existing threshold must be at least 3"

    validate compare(:max_pages_per_session, greater_than: 4),
      message: "Max pages per session must be at least 5"

    validate compare(:batch_size, greater_than: 9),
      message: "Batch size must be at least 10"

    validate match(:hse_base_url, ~r/^https?:\/\/.+/),
      message: "HSE base URL must be a valid HTTP/HTTPS URL"

    validate attribute_in(:hse_database, ["convictions", "enforcement", "notices"]),
      message: "HSE database must be one of: convictions, enforcement, notices"

    # TODO: Add cron validation functions later
  end

  identities do
    identity :unique_name, [:name] do
      message "Configuration name must be unique"
    end
  end

  preparations do
    prepare build(sort: [name: :asc])
  end

  # Configuration helper functions
  def get_active_config(opts \\ []) do
    actor = Keyword.get(opts, :actor)
    
    case Ash.read(__MODULE__, action: :active, actor: actor) do
      {:ok, [config]} -> {:ok, config}
      {:ok, []} -> {:error, :no_active_config}
      {:ok, configs} when length(configs) > 1 -> 
        Logger.warning("Multiple active configurations found, using first one")
        {:ok, List.first(configs)}
      {:error, error} -> {:error, error}
    end
  end

  def get_config_by_name(name, opts \\ []) do
    actor = Keyword.get(opts, :actor)
    
    case Ash.read(__MODULE__, action: :by_name, name: name, actor: actor) do
      {:ok, [config]} -> {:ok, config}
      {:ok, []} -> {:error, :config_not_found}
      {:error, error} -> {:error, error}
    end
  end

  def create_default_config(opts \\ []) do
    actor = Keyword.get(opts, :actor)
    
    params = %{
      name: "hse_default",
      description: "Default HSE scraping configuration",
      is_active: true,
      hse_base_url: "https://www.hse.gov.uk",
      hse_database: "convictions",
      requests_per_minute: 10,
      network_timeout_ms: 30_000,
      pause_between_pages_ms: 3_000,
      consecutive_existing_threshold: 10,
      max_pages_per_session: 100,
      max_consecutive_errors: 3,
      batch_size: 50,
      scheduled_scraping_enabled: true,
      manual_scraping_enabled: true,
      real_time_progress_enabled: true,
      admin_notifications_enabled: true,
      daily_scrape_cron: "0 2 * * *",
      weekly_scrape_cron: "0 1 * * 0"
    }
    
    Ash.create(__MODULE__, params, actor: actor)
  end
end