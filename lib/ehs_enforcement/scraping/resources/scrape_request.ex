defmodule EhsEnforcement.Scraping.ScrapeRequest do
  @moduledoc """
  Simple resource for manual HSE scraping form parameters.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Scraping

  attributes do
    uuid_primary_key :id

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
    end

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  validations do
    validate compare(:start_page, greater_than: 0)
    validate compare(:max_pages, greater_than: 0)
    validate compare(:max_pages, less_than_or_equal_to: 100)
    validate attribute_in(:database, ["convictions", "notices"])
  end
end