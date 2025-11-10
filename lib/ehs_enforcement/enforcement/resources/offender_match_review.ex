defmodule EhsEnforcement.Enforcement.OffenderMatchReview do
  @moduledoc """
  Represents a manual review record for medium-confidence Companies House matches.

  When the automatic matching process finds 2-3 potential Companies House candidates
  for an offender (medium confidence), a review record is created for manual approval
  by an admin user.

  ## Workflow

  1. **Pending** - Initial state when review record is created
  2. **Approved** - Admin selected a company number, applied to offender
  3. **Skipped** - Admin rejected all candidates, no match
  4. **Needs Review** - Admin flagged for later review (requires more info)

  ## Fields

  - `offender_id` - The offender requiring review
  - `searched_at` - When the Companies House search was performed
  - `candidate_companies` - JSONB array of top 3 Companies House candidates
  - `reviewed_at` - When admin reviewed this record (nil if pending)
  - `reviewed_by_id` - User who performed the review (nil if pending)
  - `status` - Current status (:pending, :approved, :skipped, :needs_review)
  - `selected_company_number` - The company number admin selected (nil if not approved)
  - `confidence_score` - Highest similarity score from candidates (for sorting)

  ## Candidate Company Format

  Each candidate in `candidate_companies` array contains:
  ```
  %{
    "company_number" => "12345678",
    "company_name" => "Example Ltd",
    "company_status" => "active",
    "company_type" => "ltd",
    "address" => "123 Main St, London",
    "similarity_score" => 0.87
  }
  ```
  """

  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("offender_match_reviews")
    repo(EhsEnforcement.Repo)

    custom_indexes do
      # Unique constraint: only one review per offender
      # Prevents duplicate review records for the same offender
      index([:offender_id], unique: true, name: "offender_match_reviews_offender_id_index")

      # Index for finding pending reviews
      index([:status], where: "status = 'pending'")

      # Index for finding reviews by reviewer
      index([:reviewed_by_id], where: "reviewed_by_id IS NOT NULL")

      # Composite index for admin list view queries
      index([:status, :confidence_score, :searched_at])
    end
  end

  attributes do
    uuid_primary_key(:id)

    # Review metadata
    attribute :searched_at, :utc_datetime_usec do
      allow_nil?(false)
      default(&DateTime.utc_now/0)
    end

    attribute :confidence_score, :float do
      allow_nil?(false)
      description("Highest similarity score from candidate companies (0.0-1.0)")
    end

    # Candidate company data (JSONB array)
    attribute :candidate_companies, {:array, :map} do
      allow_nil?(false)
      default([])

      description("""
      Array of top 3 Companies House candidate matches.
      Each entry contains: company_number, company_name, company_status,
      company_type, address, similarity_score
      """)
    end

    # Review status
    attribute :status, :atom do
      allow_nil?(false)
      default(:pending)
      constraints(one_of: [:pending, :approved, :skipped, :needs_review])
    end

    # Review results
    attribute :reviewed_at, :utc_datetime_usec do
      allow_nil?(true)
    end

    attribute :selected_company_number, :string do
      allow_nil?(true)

      description(
        "The company registration number selected by admin (only set when status = approved)"
      )
    end

    # Admin notes
    attribute :review_notes, :string do
      allow_nil?(true)
      description("Optional notes from admin about the review decision")
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :offender, EhsEnforcement.Enforcement.Offender do
      allow_nil?(false)
      attribute_writable?(true)
    end

    belongs_to :reviewed_by, EhsEnforcement.Accounts.User do
      allow_nil?(true)
      attribute_writable?(true)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :offender_id,
        :searched_at,
        :candidate_companies,
        :confidence_score,
        :status
      ])

      validate(attribute_does_not_equal(:status, :approved),
        message: "Cannot create review with approved status"
      )
    end

    update :update do
      primary?(true)
      accept([:review_notes])
    end

    update :approve_match do
      require_atomic?(false)

      accept([
        :selected_company_number,
        :review_notes
      ])

      argument :reviewed_by_id, :uuid do
        allow_nil?(false)
      end

      validate(present(:selected_company_number),
        message: "Company number required when approving match"
      )

      change(fn changeset, _context ->
        reviewed_by_id = Ash.Changeset.get_argument(changeset, :reviewed_by_id)

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :approved)
        |> Ash.Changeset.force_change_attribute(:reviewed_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(:reviewed_by_id, reviewed_by_id)
      end)

      # After approval, update the related offender with the selected company number
      change(
        after_action(fn changeset, result, _context ->
          offender_id = result.offender_id
          company_number = result.selected_company_number

          case Ash.get(EhsEnforcement.Enforcement.Offender, offender_id) do
            {:ok, offender} ->
              case Ash.update(offender, %{company_registration_number: company_number}) do
                {:ok, _updated_offender} ->
                  {:ok, result}

                {:error, error} ->
                  {:error, error}
              end

            {:error, error} ->
              {:error, error}
          end
        end)
      )
    end

    update :skip_match do
      require_atomic?(false)
      accept([:review_notes])

      argument :reviewed_by_id, :uuid do
        allow_nil?(false)
      end

      change(fn changeset, _context ->
        reviewed_by_id = Ash.Changeset.get_argument(changeset, :reviewed_by_id)

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :skipped)
        |> Ash.Changeset.force_change_attribute(:reviewed_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(:reviewed_by_id, reviewed_by_id)
      end)
    end

    update :flag_for_later do
      require_atomic?(false)
      accept([:review_notes])

      argument :reviewed_by_id, :uuid do
        allow_nil?(false)
      end

      change(fn changeset, _context ->
        reviewed_by_id = Ash.Changeset.get_argument(changeset, :reviewed_by_id)

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :needs_review)
        |> Ash.Changeset.force_change_attribute(:reviewed_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(:reviewed_by_id, reviewed_by_id)
      end)
    end

    read :pending_reviews do
      filter(expr(status == :pending))
    end

    read :by_offender do
      argument(:offender_id, :uuid, allow_nil?: false)
      filter(expr(offender_id == ^arg(:offender_id)))
    end

    read :by_status do
      argument(:status, :atom, allow_nil?: false)
      filter(expr(status == ^arg(:status)))
    end

    read :reviewed_by_user do
      argument(:user_id, :uuid, allow_nil?: false)
      filter(expr(reviewed_by_id == ^arg(:user_id)))
    end
  end

  calculations do
    calculate :is_pending, :boolean do
      calculation(expr(status == :pending))
    end

    calculate :candidate_count, :integer do
      calculation(expr(fragment("array_length(?, 1)", candidate_companies)))
    end

    calculate :days_pending, :integer do
      calculation(
        expr(
          fragment(
            "EXTRACT(DAY FROM AGE(NOW(), ?))",
            searched_at
          )
        )
      )
    end
  end

  code_interface do
    define(:create)
    define(:approve_match, args: [:reviewed_by_id, :selected_company_number])
    define(:skip_match, args: [:reviewed_by_id])
    define(:flag_for_later, args: [:reviewed_by_id])
    define(:pending_reviews)
    define(:by_offender, args: [:offender_id])
    define(:by_status, args: [:status])
    define(:reviewed_by_user, args: [:user_id])
  end
end
