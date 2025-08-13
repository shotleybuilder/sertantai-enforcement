defmodule EhsEnforcement.Enforcement.Violation do
  @moduledoc """
  Represents an individual violation within an EA enforcement case.
  
  This resource handles EA multi-offence scenarios where a single EA enforcement 
  page contains multiple distinct violations with separate case references.
  
  Example: EA Record 3206 has 18 violations, each with individual fines of £2,750
  and distinct case references like SW/A/2010/2051079/01, SW/A/2010/2051080/01, etc.
  """

  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table("violations")
    repo(EhsEnforcement.Repo)

    custom_indexes do
      # Performance indexes for violation queries
      index [:case_id], name: "violations_case_id_index"
      index [:case_reference], name: "violations_case_reference_index"
      index [:violation_sequence], name: "violations_sequence_index"
      
      # Composite index for case + sequence ordering
      index [:case_id, :violation_sequence], name: "violations_case_sequence_index"
      
      # Unique constraint on case_reference (each EA case reference should be unique)
      index [:case_reference], name: "violations_case_reference_unique", unique: true
    end
  end

  pub_sub do
    module(EhsEnforcement.PubSub)
    prefix("violation")
    
    # Broadcast when a violation is created
    publish(:create, ["created", :id])
    publish(:create, ["created"])
    
    # Broadcast when a violation is updated
    publish(:update, ["updated", :id])
    publish(:update, ["updated"])
    
    # Broadcast when a violation is destroyed
    publish(:destroy, ["deleted", :id])
  end

  attributes do
    uuid_primary_key(:id)

    # Core violation details
    attribute(:violation_sequence, :integer, description: "Order within case (1, 2, 3...)")
    attribute(:case_reference, :string, description: "EA case reference (e.g., 'SW/A/2010/2051079/01')")
    attribute(:individual_fine, :decimal, description: "Fine amount for this specific violation")
    attribute(:offence_description, :string, description: "Description of this specific violation")
    
    # Legal framework details
    attribute(:legal_act, :string, description: "Legal act for this violation")
    attribute(:legal_section, :string, description: "Legal section for this violation")

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :case, EhsEnforcement.Enforcement.Case do
      allow_nil?(false)
      description("Links to parent Case record")
    end
  end

  identities do
    identity(:unique_case_reference, [:case_reference])
    identity(:unique_case_sequence, [:case_id, :violation_sequence])
  end

  events do
    # Reference the centralized event log resource
    event_log EhsEnforcement.Events.Event
    
    # Track current action versions for schema evolution during replay
    current_action_versions create: 1, update: 1, bulk_create: 1
    
    # Track core data operations
    only_actions [:create, :update, :bulk_create]
  end

  actions do
    defaults([:read, :update, :destroy])

    create :create do
      primary?(true)

      accept([
        :violation_sequence,
        :case_reference,
        :individual_fine,
        :offence_description,
        :legal_act,
        :legal_section,
        :case_id
      ])

      validate(present(:case_reference))
      validate(present(:violation_sequence))
      validate(present(:case_id))
    end

    read :by_case do
      argument(:case_id, :uuid, allow_nil?: false)
      
      filter(expr(case_id == ^arg(:case_id)))
      
      prepare(fn query, _context ->
        Ash.Query.sort(query, [:violation_sequence])
      end)
    end

    read :by_case_reference do
      argument(:case_reference, :string, allow_nil?: false)
      
      filter(expr(case_reference == ^arg(:case_reference)))
    end

    create :bulk_create do
      description("Batch processing for creating multiple violations efficiently")

      argument(:violations_data, {:array, :map}, allow_nil?: false)
      argument(:case_id, :uuid, allow_nil?: false)

      change(fn changeset, _context ->
        violations_data = Ash.Changeset.get_argument(changeset, :violations_data)
        case_id = Ash.Changeset.get_argument(changeset, :case_id)

        # Validate case exists
        case EhsEnforcement.Enforcement.get_case(case_id) do
          {:ok, _case} ->
            results = %{created: 0, errors: []}

            final_results = Enum.reduce(violations_data, results, fn violation_data, acc ->
              violation_with_case = Map.put(violation_data, :case_id, case_id)
              
              case Ash.create(__MODULE__, violation_with_case, domain: EhsEnforcement.Enforcement) do
                {:ok, _violation} ->
                  %{acc | created: acc.created + 1}
                
                {:error, error} ->
                  error_msg = "Failed to create violation: #{inspect(error)}"
                  %{acc | errors: [error_msg | acc.errors]}
              end
            end)

            success_msg = "Bulk create completed: #{final_results.created} violations created"
            
            if length(final_results.errors) > 0 do
              error_msg = "#{success_msg}, #{length(final_results.errors)} errors"
              Ash.Changeset.add_error(changeset, field: :bulk_errors, message: error_msg)
            else
              Ash.Changeset.add_error(changeset, field: :bulk_result, message: success_msg)
            end

          {:error, _} ->
            Ash.Changeset.add_error(changeset, 
              field: :case_id, 
              message: "Case not found: #{case_id}")
        end
      end)
    end
  end

  calculations do
    calculate :legal_reference, :string do
      description("Combined legal act and section reference")
      calculation(expr(legal_act <> " - " <> legal_section))
    end
  end

  code_interface do
    define(:create)
    define(:by_case)
    define(:by_case_reference)
    define(:bulk_create)
  end
end