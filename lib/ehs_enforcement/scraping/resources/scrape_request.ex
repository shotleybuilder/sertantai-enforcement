defmodule EhsEnforcement.Scraping.ScrapeRequest do
  @moduledoc """
  Simple resource for manual HSE scraping form parameters.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Scraping

  attributes do
    uuid_primary_key :id

    # Agency Selection
    attribute :agency, :atom do
      allow_nil? false
      default :hse
      description "Which agency to scrape: :hse or :ea"
    end

    # HSE-specific fields (page-based scraping)
    attribute :start_page, :integer do
      allow_nil? true
      default 1
      description "Start page for HSE scraping (ignored for EA)"
    end

    attribute :end_page, :integer do
      allow_nil? true
      default 10
      description "End page for HSE scraping (ignored for EA)"
    end

    attribute :database, :string do
      allow_nil? false
      default "convictions"
      description "Database type for HSE scraping"
    end

    attribute :country, :string do
      allow_nil? true
      default "All"
      description "Country filter for HSE scraping"
    end

    # EA-specific fields (date-based scraping)
    attribute :date_from, :date do
      allow_nil? true
      description "Start date for EA scraping (required when agency = :ea)"
    end

    attribute :date_to, :date do
      allow_nil? true
      description "End date for EA scraping (required when agency = :ea)"
    end


    timestamps()
  end

  actions do
    defaults [:read, :update, :destroy]
    
    create :create do
      accept [:agency, :start_page, :end_page, :database, :country, :date_from, :date_to]
      primary? true
    end
  end

  validations do
    # HSE validations (when agency = :hse)
    validate compare(:start_page, greater_than: 0) do
      where(attribute_equals(:agency, :hse))
    end
    validate compare(:end_page, greater_than: 0) do
      where(attribute_equals(:agency, :hse))
    end
    validate compare(:end_page, less_than_or_equal_to: 100) do
      where(attribute_equals(:agency, :hse))
    end
    
    # EA validations (when agency = :ea)
    validate present(:date_from) do
      where(attribute_equals(:agency, :ea))
    end
    validate present(:date_to) do
      where(attribute_equals(:agency, :ea))
    end
    validate compare(:date_to, greater_than_or_equal_to: :date_from) do
      where(attribute_equals(:agency, :ea))
    end
    
    # General validations
    validate attribute_in(:agency, [:hse, :ea])
    validate attribute_in(:database, ["convictions", "notices"])
    validate attribute_in(:country, ["All", "England", "Scotland", "Wales"])
  end
end