defmodule EhsEnforcement.Enforcement.EnrichmentValidation do
  @moduledoc """
  Professional validation records for AI-generated enrichment content.

  This resource allows verified professionals (SRA/FCA registered) to review,
  rate, and suggest corrections for AI-generated enrichment data. This validation
  process:
  - Maintains high accuracy and credibility of the platform
  - Provides feedback loop to improve AI model performance
  - Recognizes top validators with reputation points
  - Displays validation status on enriched cases/notices

  ## User Story (Story 3)

  **As a** verified professional (SRA/FCA)
  **I want** to review and validate AI-generated context
  **So that** the platform maintains high accuracy and credibility

  ## Validation Workflow

  1. Professional views enriched case/notice
  2. Sees "Validate AI Analysis" interface
  3. Rates accuracy (1-5 stars) for each section:
     - Regulation Links
     - Benchmark Analysis
     - Pattern Detection
     - Summaries
  4. Optionally provides correction suggestions
  5. Validation is saved and contributes to:
     - Enrichment validation percentage badge
     - Validator reputation score
     - AI model improvement feedback

  ## Example Usage

      # Create validation
      {:ok, validation} = Ash.create(EnrichmentValidation, %{
        enrichment_id: enrichment.id,
        user_id: professional_user.id,
        section: "regulation_links",
        rating: 5,
        corrections: "All regulation references are accurate",
        validated_at: DateTime.utc_now()
      })

      # Query validations for an enrichment
      {:ok, validations} = EnrichmentValidation.by_enrichment!(enrichment_id)

      # Calculate validation status
      validation_percentage = calculate_validation_percentage(enrichment_id)
  """

  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table("enrichment_validations")
    repo(EhsEnforcement.Repo)

    # Prevent duplicate validations for same section by same user
    identity_wheres_to_sql(
      unique_validation_per_section:
        "enrichment_id IS NOT NULL AND user_id IS NOT NULL AND section IS NOT NULL"
    )

    check_constraints do
      check_constraint(
        :rating_range,
        "rating >= 1 AND rating <= 5",
        message: "Rating must be between 1 and 5 stars"
      )
    end

    custom_indexes do
      # Performance indexes
      index([:enrichment_id], name: "enrichment_validations_enrichment_id_index")
      index([:user_id], name: "enrichment_validations_user_id_index")
      index([:section], name: "enrichment_validations_section_index")

      # Composite index for validation queries
      index([:enrichment_id, :section],
        name: "enrichment_validations_enrichment_section_index"
      )

      # Index for reputation leaderboard queries
      index([:user_id, :validated_at], name: "enrichment_validations_user_date_index")

      # Index for high-quality validations (4-5 stars)
      index([:rating],
        name: "enrichment_validations_high_rating_index",
        where: "rating >= 4"
      )
    end
  end

  pub_sub do
    module(EhsEnforcement.PubSub)
    prefix("enrichment_validation")

    publish(:create, ["created", :enrichment_id])
    publish(:create, ["created"])
    publish(:update, ["updated", :id])
  end

  attributes do
    uuid_primary_key(:id)

    # Section being validated
    attribute :section, :atom do
      description "Which enrichment section is being validated"

      constraints(
        one_of: [
          :regulation_links,
          :benchmark_analysis,
          :pattern_detection,
          :layperson_summary,
          :professional_summary,
          :auto_tags,
          :overall
        ]
      )

      allow_nil?(false)
    end

    # Rating (1-5 stars)
    attribute :rating, :integer do
      description "Accuracy rating (1-5 stars)"
      constraints(min: 1, max: 5)
      allow_nil?(false)
    end

    # Optional corrections/feedback
    attribute :corrections, :string do
      description "Optional correction suggestions or detailed feedback from professional"
    end

    # Validation timestamp
    attribute :validated_at, :utc_datetime_usec do
      description "When this validation was performed"
      default(&DateTime.utc_now/0)
      allow_nil?(false)
    end

    # Metadata
    attribute :validation_notes, :string do
      description "Internal notes about validation context (e.g., 'Validated during QA review')"
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :enrichment, EhsEnforcement.Enforcement.Enrichment do
      allow_nil?(false)
      description "The enrichment being validated"
    end

    belongs_to :user, EhsEnforcement.Accounts.User do
      allow_nil?(false)
      description "The professional who performed the validation"
    end
  end

  identities do
    # One validation per section per user per enrichment
    identity(:unique_validation_per_section, [:enrichment_id, :user_id, :section],
      where: expr(not is_nil(enrichment_id) and not is_nil(user_id) and not is_nil(section))
    )
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :enrichment_id,
        :user_id,
        :section,
        :rating,
        :corrections,
        :validated_at,
        :validation_notes
      ])

      # Validations
      validate(present(:enrichment_id))
      validate(present(:user_id))
      validate(present(:section))
      validate(present(:rating))

      # TODO: Add authorization check - only verified professionals can validate
      # This would be implemented in policies once auth is fully set up
    end

    update :update do
      primary?(true)

      accept([
        :rating,
        :corrections,
        :validation_notes
      ])

      # Note: Cannot change enrichment_id, user_id, or section after creation
    end

    # Query actions
    read :by_enrichment do
      description "Get all validations for a specific enrichment"
      argument(:enrichment_id, :uuid, allow_nil?: false)
      filter(expr(enrichment_id == ^arg(:enrichment_id)))

      prepare(fn query, _context ->
        Ash.Query.sort(query, validated_at: :desc)
      end)
    end

    read :by_user do
      description "Get all validations performed by a specific user"
      argument(:user_id, :uuid, allow_nil?: false)
      filter(expr(user_id == ^arg(:user_id)))

      prepare(fn query, _context ->
        Ash.Query.sort(query, validated_at: :desc)
      end)
    end

    read :by_section do
      description "Get all validations for a specific section type"
      argument(:section, :atom, allow_nil?: false)
      filter(expr(section == ^arg(:section)))

      prepare(fn query, _context ->
        Ash.Query.sort(query, validated_at: :desc)
      end)
    end

    read :high_quality do
      description "Get validations with 4-5 star ratings"
      filter(expr(rating >= 4))

      prepare(fn query, _context ->
        Ash.Query.sort(query, rating: :desc, validated_at: :desc)
      end)
    end

    read :needs_attention do
      description "Get validations with low ratings (1-2 stars) that need review"
      filter(expr(rating <= 2))

      prepare(fn query, _context ->
        Ash.Query.sort(query, rating: :asc, validated_at: :desc)
      end)
    end

    read :recent do
      description "Get recent validations (last 30 days)"
      filter(expr(validated_at > ago(30, :day)))

      prepare(fn query, _context ->
        Ash.Query.sort(query, validated_at: :desc)
      end)
    end
  end

  calculations do
    calculate :is_positive, :boolean do
      description "Whether this is a positive validation (4-5 stars)"
      calculation(expr(rating >= 4))
    end

    calculate :is_negative, :boolean do
      description "Whether this is a negative validation (1-2 stars)"
      calculation(expr(rating <= 2))
    end

    calculate :has_corrections, :boolean do
      description "Whether the validator provided correction suggestions"
      calculation(expr(not is_nil(corrections) and corrections != ""))
    end
  end

  code_interface do
    define(:create)
    define(:update)
    define(:by_enrichment, args: [:enrichment_id])
    define(:by_user, args: [:user_id])
    define(:by_section, args: [:section])
    define(:high_quality)
    define(:needs_attention)
    define(:recent)
  end

  @doc """
  Calculate validation percentage for an enrichment.

  Returns percentage of sections validated (0-100).

  ## Example

      validation_percentage = EnrichmentValidation.calculate_validation_percentage(enrichment_id)
      # => 75 (3 out of 4 sections validated)
  """
  def calculate_validation_percentage(enrichment_id) do
    require Ash.Query

    # Get count of distinct sections validated
    validated_sections =
      __MODULE__
      |> Ash.Query.filter(enrichment_id == ^enrichment_id)
      |> Ash.Query.select([:section])
      |> Ash.read!()
      |> Enum.map(& &1.section)
      |> Enum.uniq()
      |> length()

    # Total sections that can be validated (excluding :overall)
    total_sections = 5

    # Calculate percentage
    round(validated_sections / total_sections * 100)
  end

  @doc """
  Calculate average rating for an enrichment.

  Returns average rating across all validated sections (1.0-5.0).

  ## Example

      average_rating = EnrichmentValidation.calculate_average_rating(enrichment_id)
      # => 4.2
  """
  def calculate_average_rating(enrichment_id) do
    require Ash.Query

    validations =
      __MODULE__
      |> Ash.Query.filter(enrichment_id == ^enrichment_id)
      |> Ash.Query.select([:rating])
      |> Ash.read!()

    if Enum.empty?(validations) do
      nil
    else
      sum = Enum.reduce(validations, 0, fn v, acc -> acc + v.rating end)
      Float.round(sum / length(validations), 1)
    end
  end

  @doc """
  Calculate reputation score for a validator (user).

  Returns count of high-quality validations (4-5 stars) in the last 90 days.

  ## Example

      reputation_score = EnrichmentValidation.calculate_reputation_score(user_id)
      # => 42
  """
  def calculate_reputation_score(user_id) do
    require Ash.Query

    __MODULE__
    |> Ash.Query.filter(
      user_id == ^user_id and
        rating >= 4 and
        validated_at > ago(90, :day)
    )
    |> Ash.count!()
  end
end
