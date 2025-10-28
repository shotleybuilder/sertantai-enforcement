defmodule EhsEnforcement.Configuration do
  @moduledoc """
  Domain for managing application configuration and settings.

  This domain handles:
  - Scraping configuration profiles
  - Feature flags and toggles
  - System-wide settings
  - Rate limiting configurations
  """

  use Ash.Domain,
    extensions: [AshGraphql.Domain, AshJsonApi.Domain]

  resources do
    resource(EhsEnforcement.Configuration.ScrapingConfig)
  end

  graphql do
    authorize?(false)

    queries do
      get EhsEnforcement.Configuration.ScrapingConfig, :get_scraping_config, :read
      list(EhsEnforcement.Configuration.ScrapingConfig, :list_scraping_configs, :read)
      get EhsEnforcement.Configuration.ScrapingConfig, :active_scraping_config, :active
    end

    mutations do
      create(EhsEnforcement.Configuration.ScrapingConfig, :create_scraping_config, :create)
      update(EhsEnforcement.Configuration.ScrapingConfig, :update_scraping_config, :update)
      update(EhsEnforcement.Configuration.ScrapingConfig, :activate_scraping_config, :activate)

      update(
        EhsEnforcement.Configuration.ScrapingConfig,
        :deactivate_scraping_config,
        :deactivate
      )
    end
  end

  json_api do
    prefix("/api/configuration")

    routes do
      base_route "/scraping_configs", EhsEnforcement.Configuration.ScrapingConfig do
        get(:read)
        index(:read)
        post(:create)
        patch(:update)
        delete(:destroy)
      end
    end
  end
end
