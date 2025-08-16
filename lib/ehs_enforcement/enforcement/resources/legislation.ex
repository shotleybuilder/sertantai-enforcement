defmodule EhsEnforcement.Enforcement.Legislation do
  @moduledoc """
  Represents legislation that can be referenced in enforcement actions.
  
  This is a lookup/reference table for normalizing legislation data across
  cases, notices, and offences. Contains core legislation information like
  Acts, Regulations, and Orders.
  
  Examples:
  - Health and Safety at Work etc. Act 1974
  - The Construction (Design and Management) Regulations 2015
  - The Work at Height Regulations 2005
  """

  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "legislation"
    repo EhsEnforcement.Repo

    custom_indexes do
      # Unique constraint for legislation identification
      index [:legislation_title, :legislation_year, :legislation_number], 
        name: "legislation_title_year_number_unique", 
        unique: true

      # Performance indexes for filtering and search
      index [:legislation_type], name: "legislation_type_index"
      index [:legislation_year], name: "legislation_year_index"
      
      # pg_trgm GIN index for fuzzy text search on legislation titles
      index [:legislation_title], name: "legislation_title_gin_trgm", using: "GIN"
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :legislation_title, :string do
      allow_nil? false
      description "Full title of the legislation (e.g., 'Health and Safety at Work etc. Act')"
    end

    attribute :legislation_year, :integer do
      description "Year the legislation was enacted (e.g., 1974)"
      constraints [min: 1800, max: 2100]
    end

    attribute :legislation_number, :integer do
      description "Official number/chapter of the legislation (e.g., 33)"
      constraints [min: 1]
    end

    attribute :legislation_type, :atom do
      allow_nil? false
      description "Type of legislation"
      constraints [one_of: [:act, :regulation, :order, :acop]]
      default :act
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_legislation, [:legislation_title, :legislation_year, :legislation_number]
  end

  actions do
    defaults [:read, :update, :destroy]

    create :create do
      primary? true
      accept [:legislation_title, :legislation_year, :legislation_number, :legislation_type]

      validate present(:legislation_title)
      validate present(:legislation_type)
    end

    read :by_type do
      argument :legislation_type, :atom, allow_nil?: false
      filter expr(legislation_type == ^arg(:legislation_type))
    end

    read :by_year_range do
      argument :start_year, :integer, allow_nil?: false
      argument :end_year, :integer, allow_nil?: false
      
      filter expr(legislation_year >= ^arg(:start_year) and legislation_year <= ^arg(:end_year))
    end

    read :search_title do
      argument :search_term, :string, allow_nil?: false
      
      filter expr(fragment("? % ?", legislation_title, ^arg(:search_term)))
    end
  end

  calculations do
    calculate :full_reference, :string do
      description "Complete legislation reference including year and number"
      calculation expr(
        cond do
          is_nil(legislation_year) and is_nil(legislation_number) ->
            legislation_title
          is_nil(legislation_number) ->
            legislation_title <> " " <> to_string(legislation_year)
          is_nil(legislation_year) ->
            legislation_title <> " No. " <> to_string(legislation_number)
          true ->
            legislation_title <> " " <> to_string(legislation_year) <> " No. " <> to_string(legislation_number)
        end
      )
    end
  end

  code_interface do
    define :create
    define :by_type
    define :by_year_range
    define :search_title
  end
end