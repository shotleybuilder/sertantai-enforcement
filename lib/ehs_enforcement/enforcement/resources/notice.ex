defmodule EhsEnforcement.Enforcement.Notice do
  @moduledoc """
  Represents an enforcement notice issued to an offender.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "notices"
    repo EhsEnforcement.Repo
    
    identity_wheres_to_sql(unique_airtable_id: "airtable_id IS NOT NULL")

    custom_indexes do
      # Performance indexes for dashboard metrics calculations
      index [:offence_action_date], name: "notices_offence_action_date_index"
      index [:agency_id], name: "notices_agency_id_index"
      
      # Composite index for common query patterns (agency + date filtering)
      index [:agency_id, :offence_action_date], name: "notices_agency_date_index"
    end
  end

  pub_sub do
    # Use our PubSub module, not the Endpoint (match Cases pattern exactly)
    module(EhsEnforcement.PubSub)
    prefix("notice")

    # Broadcast when a notice is created
    # Topics: "notice:created" and "notice:created:<id>"
    publish(:create, ["created", :id])
    publish(:create, ["created"])
    
    # Broadcast when a notice is updated  
    # Topics: "notice:updated" and "notice:updated:<id>"
    publish(:update, ["updated", :id])
    publish(:update, ["updated"])
    publish(:destroy, ["deleted", :id])
  end

  attributes do
    uuid_primary_key :id
    
    attribute :airtable_id, :string
    attribute :regulator_id, :string
    attribute :regulator_ref_number, :string
    attribute :notice_date, :date
    attribute :operative_date, :date
    attribute :compliance_date, :date
    attribute :notice_body, :string
    attribute :offence_action_type, :string
    attribute :offence_action_date, :date
    attribute :offence_breaches, :string
    attribute :url, :string
    attribute :last_synced_at, :utc_datetime
    
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :agency, EhsEnforcement.Enforcement.Agency do
      allow_nil? false
    end
    
    belongs_to :offender, EhsEnforcement.Enforcement.Offender do
      allow_nil? false
    end
  end

  identities do
    identity :unique_airtable_id, [:airtable_id], where: expr(not is_nil(airtable_id))
  end

  actions do
    defaults [:read, :update, :destroy]
    
    create :create do
      primary? true
      accept [:airtable_id, :regulator_id, :regulator_ref_number,
              :notice_date, :operative_date, :compliance_date, :notice_body,
              :offence_action_type, :offence_action_date, :offence_breaches, :url,
              :last_synced_at]
      
      argument :agency_code, :atom
      argument :offender_attrs, :map
      argument :agency_id, :uuid
      argument :offender_id, :uuid
      
      change fn changeset, context ->
        cond do
          # Direct IDs provided
          Ash.Changeset.get_argument(changeset, :agency_id) && 
          Ash.Changeset.get_argument(changeset, :offender_id) ->
            agency_id = Ash.Changeset.get_argument(changeset, :agency_id)
            offender_id = Ash.Changeset.get_argument(changeset, :offender_id)
            
            changeset
            |> Ash.Changeset.force_change_attribute(:agency_id, agency_id)
            |> Ash.Changeset.force_change_attribute(:offender_id, offender_id)
          
          # Code and attrs provided
          Ash.Changeset.get_argument(changeset, :agency_code) &&
          Ash.Changeset.get_argument(changeset, :offender_attrs) ->
            agency_code = Ash.Changeset.get_argument(changeset, :agency_code)
            offender_attrs = Ash.Changeset.get_argument(changeset, :offender_attrs)
            
            # Look up agency by code
            case EhsEnforcement.Enforcement.get_agency_by_code(agency_code) do
              {:ok, agency} when not is_nil(agency) ->
                # Find or create offender
                case EhsEnforcement.Enforcement.Offender.find_or_create_offender(offender_attrs) do
                  {:ok, offender} ->
                    changeset
                    |> Ash.Changeset.force_change_attribute(:agency_id, agency.id)
                    |> Ash.Changeset.force_change_attribute(:offender_id, offender.id)
                  
                  {:error, _} -> 
                    Ash.Changeset.add_error(changeset, "Failed to create offender")
                end
              
              {:ok, nil} ->
                Ash.Changeset.add_error(changeset, "Agency not found: #{agency_code}")
              
              {:error, _} ->
                Ash.Changeset.add_error(changeset, "Error looking up agency: #{agency_code}")
            end
          
          true ->
            Ash.Changeset.add_error(changeset, "Must provide either agency_id/offender_id or agency_code/offender_attrs")
        end
      end
    end
  end

  code_interface do
    define :create
  end
end