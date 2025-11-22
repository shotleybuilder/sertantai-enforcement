# Sprint: AI-Powered Regulator Scorecard System

**Sprint Duration**: 2 weeks
**Team Size**: 2-3 developers (1 backend, 1 frontend, 0.5 data analyst)
**Prerequisites**: Full auth with professional validation, expert commentary system, sufficient case data

---

## 🎯 Sprint Goal

Build a transparent, data-driven regulator scorecard system where verified professionals rate and review regulator performance across key dimensions (clarity, consistency, fairness, speed) - creating the first-ever accountability platform for UK enforcement agencies.

---

## 📋 User Stories

### Story 1: Regulator Rating System
**As a** verified professional with direct regulator experience
**I want** to rate a regulator across multiple dimensions
**So that** I can contribute to a comprehensive performance benchmark

**Acceptance Criteria**:
- [ ] Multi-dimensional 1-5 star rating system:
  - Clarity of guidance
  - Consistency of enforcement
  - Speed of process
  - Settlement openness
  - Procedural fairness
  - Communication quality
- [ ] Must be linked to actual case (verified experience)
- [ ] Optional written review (500 char limit)
- [ ] One rating per user per regulator per year
- [ ] Update previous rating if new experience
- [ ] Rating triggers AI aggregate analysis update

**Story Points**: 8

---

### Story 2: Experience Verification
**As a** platform administrator
**I want** to ensure ratings come from professionals with direct experience
**So that** scorecard data is credible and trustworthy

**Acceptance Criteria**:
- [ ] User must have case linked to regulator in system
- [ ] Verify user was involved party (org match)
- [ ] Check case is within last 3 years (recent experience)
- [ ] Display verified experience badge on rating
- [ ] Audit log of verification checks
- [ ] Admin override for manual verification

**Story Points**: 5

---

### Story 3: AI Aggregate Analysis
**As a** user viewing a regulator scorecard
**I want** to see AI-generated insights from aggregate ratings
**So that** I understand overall patterns and trends

**Acceptance Criteria**:
- [ ] AI analyzes all ratings for regulator
- [ ] Identifies strengths (highest-rated dimensions)
- [ ] Identifies areas for improvement (lowest-rated)
- [ ] Detects recent trends ("Improved 15% in last 6 months")
- [ ] Generates comparative ranking vs. other regulators
- [ ] Confidence scores based on sample size
- [ ] Updates automatically when new ratings added

**Story Points**: 8

---

### Story 4: Regulator Response Platform
**As a** regulator representative
**I want** to respond to scorecard feedback publicly
**So that** I can demonstrate accountability and announce improvements

**Acceptance Criteria**:
- [ ] Verified regulator accounts (email domain check)
- [ ] Official statement field (markdown, 2000 char limit)
- [ ] Improvements announced section (structured list)
- [ ] Response displayed prominently on scorecard
- [ ] Timestamp and responder name
- [ ] Community can react (helpful/unhelpful)
- [ ] Email notification to raters when response posted

**Story Points**: 5

---

### Story 5: Comparative Scorecard Dashboard
**As a** professional user
**I want** to compare regulators side-by-side
**So that** I can understand relative performance

**Acceptance Criteria**:
- [ ] Radar chart comparing all dimensions
- [ ] Sortable table by overall score or individual dimension
- [ ] Filter by sector, region, timeframe
- [ ] Percentile rankings displayed
- [ ] Export comparison as PDF/Excel
- [ ] Shareable comparison URLs
- [ ] Responsive design for mobile

**Story Points**: 8

---

### Story 6: Professional Review Showcase
**As a** user
**I want** to read detailed written reviews from professionals
**So that** I get qualitative insights beyond numbers

**Acceptance Criteria**:
- [ ] Written reviews displayed with ratings
- [ ] Author credentials shown (verified SRA/FCA)
- [ ] Case reference linked (if not confidential)
- [ ] Helpful/unhelpful voting on reviews
- [ ] Sort by helpfulness, recent, highest/lowest rating
- [ ] Pagination for many reviews
- [ ] Report inappropriate review option

**Story Points**: 5

---

## 🏗️ Technical Architecture

### Backend Components

#### 1. Database Schema
```elixir
defmodule EhsEnforcement.Enforcement.RegulatorRating do
  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    # Rating dimensions (1-5 scale)
    attribute :clarity_of_guidance, :integer do
      constraints min: 1, max: 5
      allow_nil?: false
    end

    attribute :consistency_of_enforcement, :integer do
      constraints min: 1, max: 5
      allow_nil?: false
    end

    attribute :speed_of_process, :integer do
      constraints min: 1, max: 5
      allow_nil?: false
    end

    attribute :settlement_openness, :integer do
      constraints min: 1, max: 5
      allow_nil?: false
    end

    attribute :procedural_fairness, :integer do
      constraints min: 1, max: 5
      allow_nil?: false
    end

    attribute :communication_quality, :integer do
      constraints min: 1, max: 5
      allow_nil?: false
    end

    # Written review
    attribute :written_review, :string do
      constraints max_length: 500
    end

    # Experience verification
    attribute :verified_experience, :boolean, default: false
    attribute :verification_notes, :string

    # Engagement metrics
    attribute :helpful_votes, :integer, default: 0
    attribute :unhelpful_votes, :integer, default: 0

    timestamps()
  end

  relationships do
    belongs_to :regulator, EhsEnforcement.Enforcement.Agency
    belongs_to :rater, EhsEnforcement.Accounts.User
    belongs_to :case, EhsEnforcement.Enforcement.Case  # Proves direct experience
  end

  actions do
    defaults [:read]

    create :submit_rating do
      accept [:clarity_of_guidance, :consistency_of_enforcement, :speed_of_process,
              :settlement_openness, :procedural_fairness, :communication_quality,
              :written_review, :case_id]

      argument :regulator_id, :uuid, allow_nil?: false

      change relate_actor(:rater)
      change EhsEnforcement.Changes.VerifyRegulatorExperience
      change EhsEnforcement.Changes.UpdateRegulatorScorecard
      change EhsEnforcement.Changes.TriggerAIAnalysis
    end

    update :update_rating do
      accept [:clarity_of_guidance, :consistency_of_enforcement, :speed_of_process,
              :settlement_openness, :procedural_fairness, :communication_quality,
              :written_review]

      change EhsEnforcement.Changes.UpdateRegulatorScorecard
    end
  end

  calculations do
    calculate :overall_rating, :float do
      expr(
        (clarity_of_guidance + consistency_of_enforcement + speed_of_process +
         settlement_openness + procedural_fairness + communication_quality) / 6.0
      )
    end

    calculate :net_helpful_votes, :integer do
      expr(helpful_votes - unhelpful_votes)
    end
  end

  identities do
    # One rating per user per regulator per year
    identity :unique_rating_per_year, [:regulator_id, :rater_id, fragment("EXTRACT(YEAR FROM inserted_at)")]
  end

  policies do
    # Only verified professionals can rate
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:professional_tier, :professional)
      authorize_if actor_attribute_equals(:professional_tier, :expert)
    end

    # Must have case linked to regulator
    policy action_type(:create) do
      authorize_if EhsEnforcement.Policies.HasRegulatorExperience
    end

    # Can only edit own ratings
    policy action_type(:update) do
      authorize_if expr(rater_id == ^actor(:id))
    end
  end
end
```

#### 2. Regulator Scorecard Resource
```elixir
defmodule EhsEnforcement.Enforcement.RegulatorScorecard do
  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    # Aggregate ratings
    attribute :avg_clarity_of_guidance, :float
    attribute :avg_consistency_of_enforcement, :float
    attribute :avg_speed_of_process, :float
    attribute :avg_settlement_openness, :float
    attribute :avg_procedural_fairness, :float
    attribute :avg_communication_quality, :float
    attribute :avg_overall, :float

    # Sample statistics
    attribute :total_ratings, :integer, default: 0
    attribute :verified_ratings, :integer, default: 0

    # AI-generated insights
    attribute :ai_strengths, {:array, :string}
    attribute :ai_areas_for_improvement, {:array, :string}
    attribute :ai_recent_trends, :string
    attribute :ai_comparative_ranking, :map

    # Percentile rankings
    attribute :clarity_percentile, :integer
    attribute :consistency_percentile, :integer
    attribute :speed_percentile, :integer
    attribute :overall_percentile, :integer

    # Last update
    attribute :last_calculated_at, :utc_datetime_usec

    timestamps()
  end

  relationships do
    belongs_to :regulator, EhsEnforcement.Enforcement.Agency
    has_many :ratings, EhsEnforcement.Enforcement.RegulatorRating
    has_one :official_response, EhsEnforcement.Enforcement.RegulatorResponse
  end

  actions do
    defaults [:read]

    create :initialize do
      accept []
      change set_attribute(:total_ratings, 0)
    end

    update :recalculate do
      accept []

      change fn changeset, _context ->
        regulator_id = Ash.Changeset.get_attribute(changeset, :regulator_id)

        aggregates = calculate_aggregates(regulator_id)
        ai_insights = generate_ai_insights(regulator_id, aggregates)
        percentiles = calculate_percentiles(regulator_id, aggregates)

        changeset
        |> Ash.Changeset.change_attributes(aggregates)
        |> Ash.Changeset.change_attributes(ai_insights)
        |> Ash.Changeset.change_attributes(percentiles)
        |> Ash.Changeset.change_attribute(:last_calculated_at, DateTime.utc_now())
      end
    end
  end

  calculations do
    calculate :confidence_level, :atom do
      expr(
        cond do
          total_ratings >= 50 -> :high
          total_ratings >= 20 -> :medium
          true -> :low
        end
      )
    end

    calculate :is_highly_rated, :boolean do
      expr(avg_overall >= 4.0 and total_ratings >= 20)
    end
  end
end
```

#### 3. Regulator Response Resource
```elixir
defmodule EhsEnforcement.Enforcement.RegulatorResponse do
  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :official_statement, :string do
      constraints max_length: 2000
      allow_nil?: false
    end

    attribute :improvements_announced, {:array, :map} do
      description "Structured list of improvements with timeline"
    end

    attribute :responder_name, :string
    attribute :responder_title, :string

    # Community feedback
    attribute :helpful_votes, :integer, default: 0
    attribute :unhelpful_votes, :integer, default: 0

    timestamps()
  end

  relationships do
    belongs_to :regulator, EhsEnforcement.Enforcement.Agency
    belongs_to :scorecard, EhsEnforcement.Enforcement.RegulatorScorecard
    belongs_to :submitted_by, EhsEnforcement.Accounts.User
  end

  actions do
    defaults [:read]

    create :submit_response do
      accept [:official_statement, :improvements_announced, :responder_name, :responder_title]

      argument :scorecard_id, :uuid, allow_nil?: false

      change relate_actor(:submitted_by)
      change EhsEnforcement.Changes.NotifyRaters
    end

    update :update_response do
      accept [:official_statement, :improvements_announced]
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end
  end

  policies do
    # Only verified regulator representatives can submit
    policy action_type([:create, :update]) do
      authorize_if EhsEnforcement.Policies.IsRegulatorRepresentative
    end
  end
end
```

#### 4. AI Insights Service
```elixir
defmodule EhsEnforcement.AI.RegulatorInsightsService do
  @moduledoc """
  AI service for analyzing regulator scorecard data and generating insights
  """

  def generate_insights(regulator_id, aggregates) do
    ratings = fetch_all_ratings(regulator_id)

    %{
      ai_strengths: identify_strengths(aggregates),
      ai_areas_for_improvement: identify_weaknesses(aggregates),
      ai_recent_trends: analyze_trends(ratings),
      ai_comparative_ranking: compare_with_peers(regulator_id, aggregates)
    }
  end

  defp identify_strengths(aggregates) do
    dimensions = [
      {"Clarity of Guidance", aggregates.avg_clarity_of_guidance},
      {"Consistency", aggregates.avg_consistency_of_enforcement},
      {"Speed", aggregates.avg_speed_of_process},
      {"Settlement Openness", aggregates.avg_settlement_openness},
      {"Procedural Fairness", aggregates.avg_procedural_fairness},
      {"Communication", aggregates.avg_communication_quality}
    ]

    dimensions
    |> Enum.filter(fn {_, score} -> score >= 4.0 end)
    |> Enum.sort_by(fn {_, score} -> score end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {name, score} -> "#{name} (#{Float.round(score, 1)}/5.0)" end)
  end

  defp identify_weaknesses(aggregates) do
    dimensions = [
      {"Clarity of Guidance", aggregates.avg_clarity_of_guidance},
      {"Consistency", aggregates.avg_consistency_of_enforcement},
      {"Speed", aggregates.avg_speed_of_process},
      {"Settlement Openness", aggregates.avg_settlement_openness},
      {"Procedural Fairness", aggregates.avg_procedural_fairness},
      {"Communication", aggregates.avg_communication_quality}
    ]

    dimensions
    |> Enum.filter(fn {_, score} -> score < 3.5 end)
    |> Enum.sort_by(fn {_, score} -> score end, :asc)
    |> Enum.take(3)
    |> Enum.map(fn {name, score} -> "#{name} (#{Float.round(score, 1)}/5.0)" end)
  end

  defp analyze_trends(ratings) do
    # Compare last 6 months to previous 6 months
    recent = filter_by_date_range(ratings, -6..0)
    previous = filter_by_date_range(ratings, -12..-6)

    recent_avg = calculate_average_rating(recent)
    previous_avg = calculate_average_rating(previous)

    change_pct = ((recent_avg - previous_avg) / previous_avg) * 100

    cond do
      change_pct > 10 -> "Significantly improved (#{Float.round(change_pct, 1)}%) in last 6 months"
      change_pct > 5 -> "Moderately improved (#{Float.round(change_pct, 1)}%) in last 6 months"
      change_pct < -10 -> "Declined (#{Float.round(change_pct, 1)}%) in last 6 months"
      change_pct < -5 -> "Slightly declined (#{Float.round(change_pct, 1)}%) in last 6 months"
      true -> "Performance stable in last 6 months"
    end
  end

  defp compare_with_peers(regulator_id, aggregates) do
    all_regulators = fetch_all_scorecards()

    percentile = calculate_percentile(aggregates.avg_overall, all_regulators)
    rank = calculate_rank(aggregates.avg_overall, all_regulators)

    %{
      compared_to: "all_regulators",
      total_regulators: length(all_regulators),
      rank: rank,
      percentile: percentile,
      summary: generate_comparative_summary(rank, length(all_regulators), percentile)
    }
  end

  defp generate_comparative_summary(rank, total, percentile) do
    case percentile do
      p when p >= 90 -> "Ranked ##{rank} of #{total} - Top 10% of regulators"
      p when p >= 75 -> "Ranked ##{rank} of #{total} - Above average performance"
      p when p >= 50 -> "Ranked ##{rank} of #{total} - Average performance"
      p when p >= 25 -> "Ranked ##{rank} of #{total} - Below average performance"
      _ -> "Ranked ##{rank} of #{total} - Significant improvement needed"
    end
  end
end
```

### Frontend Components

#### 1. Regulator Scorecard Page
```svelte
<!-- frontend/src/routes/regulators/[id]/scorecard/+page.svelte -->
<script lang="ts">
  import { page } from '$app/stores'
  import { db } from '$lib/db'
  import RadarChart from '$lib/components/charts/RadarChart.svelte'
  import RatingStars from '$lib/components/RatingStars.svelte'
  import RegulatorResponse from '$lib/components/RegulatorResponse.svelte'
  import RatingList from '$lib/components/RatingList.svelte'

  const regulatorId = $page.params.id

  // Query scorecard
  $: scorecard = db.query((q) =>
    q.regulator_scorecards
      .where('regulator_id', regulatorId)
      .first()
  )

  $: regulator = db.query((q) =>
    q.agencies
      .where('id', regulatorId)
      .first()
  )

  $: ratings = db.query((q) =>
    q.regulator_ratings
      .where('regulator_id', regulatorId)
      .where('verified_experience', true)
      .orderBy('net_helpful_votes', 'desc')
      .limit(20)
  )

  $: radarData = {
    labels: [
      'Clarity',
      'Consistency',
      'Speed',
      'Settlement',
      'Fairness',
      'Communication'
    ],
    values: [
      $scorecard?.avg_clarity_of_guidance || 0,
      $scorecard?.avg_consistency_of_enforcement || 0,
      $scorecard?.avg_speed_of_process || 0,
      $scorecard?.avg_settlement_openness || 0,
      $scorecard?.avg_procedural_fairness || 0,
      $scorecard?.avg_communication_quality || 0
    ]
  }

  function getConfidenceBadge(level: string) {
    const badges = {
      high: { text: 'High Confidence', class: 'bg-green-100 text-green-800' },
      medium: { text: 'Medium Confidence', class: 'bg-yellow-100 text-yellow-800' },
      low: { text: 'Low Confidence', class: 'bg-orange-100 text-orange-800' }
    }
    return badges[level] || badges.low
  }
</script>

<div class="scorecard-page max-w-6xl mx-auto">
  <!-- Header -->
  <header class="mb-8">
    <h1 class="text-3xl font-bold">{$regulator?.name} Scorecard</h1>
    <p class="text-gray-600 mt-2">
      Independent performance ratings from verified professionals
    </p>

    <div class="flex items-center gap-4 mt-4">
      <div class="overall-rating">
        <span class="text-5xl font-bold">{$scorecard?.avg_overall.toFixed(1)}</span>
        <span class="text-2xl text-gray-500">/5.0</span>
      </div>

      <div>
        <RatingStars rating={$scorecard?.avg_overall} size="large" />
        <p class="text-sm text-gray-600 mt-1">
          Based on {$scorecard?.verified_ratings} verified ratings
        </p>
        <span class="badge {getConfidenceBadge($scorecard?.confidence_level).class}">
          {getConfidenceBadge($scorecard?.confidence_level).text}
        </span>
      </div>

      <div class="ml-auto">
        <a href="/regulators/{regulatorId}/rate" class="btn-primary">
          Rate This Regulator
        </a>
      </div>
    </div>
  </header>

  <!-- Performance Radar Chart -->
  <section class="radar-section mb-8">
    <h2 class="text-2xl font-semibold mb-4">Performance Overview</h2>
    <div class="grid grid-cols-2 gap-8">
      <div>
        <RadarChart data={radarData} />
      </div>
      <div class="dimension-breakdown">
        <h3 class="font-semibold mb-3">Dimension Scores</h3>
        <div class="space-y-3">
          {#each [
            ['Clarity of Guidance', $scorecard?.avg_clarity_of_guidance, $scorecard?.clarity_percentile],
            ['Consistency', $scorecard?.avg_consistency_of_enforcement, $scorecard?.consistency_percentile],
            ['Speed of Process', $scorecard?.avg_speed_of_process, $scorecard?.speed_percentile],
            ['Settlement Openness', $scorecard?.avg_settlement_openness, null],
            ['Procedural Fairness', $scorecard?.avg_procedural_fairness, null],
            ['Communication Quality', $scorecard?.avg_communication_quality, null]
          ] as [label, score, percentile]}
            <div class="dimension-item">
              <div class="flex justify-between items-center mb-1">
                <span class="text-sm font-medium">{label}</span>
                <span class="text-sm font-bold">{score?.toFixed(1)}/5.0</span>
              </div>
              <div class="progress-bar">
                <div class="progress-fill" style="width: {(score / 5) * 100}%"></div>
              </div>
              {#if percentile}
                <p class="text-xs text-gray-500 mt-1">
                  {percentile}th percentile
                </p>
              {/if}
            </div>
          {/each}
        </div>
      </div>
    </div>
  </section>

  <!-- AI Insights -->
  <section class="insights-section mb-8">
    <h2 class="text-2xl font-semibold mb-4">AI-Generated Insights</h2>

    <div class="grid grid-cols-2 gap-6">
      <!-- Strengths -->
      <div class="insight-card bg-green-50 border border-green-200 rounded p-4">
        <h3 class="font-semibold text-green-800 mb-2">✓ Strengths</h3>
        <ul class="list-disc list-inside text-sm space-y-1">
          {#each $scorecard?.ai_strengths || [] as strength}
            <li>{strength}</li>
          {/each}
        </ul>
      </div>

      <!-- Areas for Improvement -->
      <div class="insight-card bg-orange-50 border border-orange-200 rounded p-4">
        <h3 class="font-semibold text-orange-800 mb-2">⚠ Areas for Improvement</h3>
        <ul class="list-disc list-inside text-sm space-y-1">
          {#each $scorecard?.ai_areas_for_improvement || [] as area}
            <li>{area}</li>
          {/each}
        </ul>
      </div>
    </div>

    <!-- Recent Trends -->
    {#if $scorecard?.ai_recent_trends}
      <div class="mt-4 p-4 bg-blue-50 border border-blue-200 rounded">
        <h3 class="font-semibold text-blue-800 mb-2">📈 Recent Trends</h3>
        <p class="text-sm">{$scorecard.ai_recent_trends}</p>
      </div>
    {/if}

    <!-- Comparative Ranking -->
    {#if $scorecard?.ai_comparative_ranking}
      <div class="mt-4 p-4 bg-purple-50 border border-purple-200 rounded">
        <h3 class="font-semibold text-purple-800 mb-2">📊 Comparative Ranking</h3>
        <p class="text-sm">{$scorecard.ai_comparative_ranking.summary}</p>
      </div>
    {/if}
  </section>

  <!-- Official Regulator Response -->
  {#if $scorecard?.official_response}
    <section class="response-section mb-8">
      <h2 class="text-2xl font-semibold mb-4">Official Response</h2>
      <RegulatorResponse response={$scorecard.official_response} />
    </section>
  {/if}

  <!-- Professional Reviews -->
  <section class="reviews-section">
    <h2 class="text-2xl font-semibold mb-4">
      Professional Reviews ({$ratings?.length || 0})
    </h2>
    <RatingList {ratings} />
  </section>
</div>
```

#### 2. Rating Submission Form
```svelte
<!-- frontend/src/routes/regulators/[id]/rate/+page.svelte -->
<script lang="ts">
  import { page } from '$app/stores'
  import { db } from '$lib/db'
  import { currentUser } from '$lib/stores/auth'
  import { goto } from '$app/navigation'
  import RatingInput from '$lib/components/RatingInput.svelte'

  const regulatorId = $page.params.id

  let formData = {
    clarity_of_guidance: 0,
    consistency_of_enforcement: 0,
    speed_of_process: 0,
    settlement_openness: 0,
    procedural_fairness: 0,
    communication_quality: 0,
    written_review: '',
    case_id: ''
  }

  // Query user's cases with this regulator
  $: userCases = db.query((q) =>
    q.cases
      .where('regulator_id', regulatorId)
      .where('organization_id', $currentUser?.organization_id)
  )

  let canSubmit = false
  $: canSubmit = Object.values(formData).slice(0, 6).every(v => v > 0)

  async function submitRating() {
    try {
      await db.mutate((m) =>
        m.regulator_ratings.submit_rating({
          regulator_id: regulatorId,
          ...formData,
          rater_id: $currentUser.id
        })
      )

      goto(`/regulators/${regulatorId}/scorecard?submitted=true`)
    } catch (error) {
      console.error('Rating submission failed:', error)
      alert('Failed to submit rating. Please try again.')
    }
  }
</script>

<div class="rating-form max-w-3xl mx-auto">
  <h1 class="text-3xl font-bold mb-4">Rate Regulator</h1>

  <p class="text-gray-600 mb-6">
    Share your experience to help others understand this regulator's performance.
    Your rating will be linked to your verified professional credentials.
  </p>

  <!-- Experience Verification -->
  <div class="verification-section mb-8 p-4 border rounded">
    <h3 class="font-semibold mb-2">Verify Your Experience</h3>
    <p class="text-sm text-gray-600 mb-3">
      To ensure credibility, your rating must be linked to an actual case.
    </p>

    <select bind:value={formData.case_id} class="w-full" required>
      <option value="">Select a case...</option>
      {#each $userCases as case}
        <option value={case.id}>
          {case.case_reference} - {new Date(case.offence_action_date).toLocaleDateString()}
        </option>
      {/each}
    </select>

    {#if $userCases?.length === 0}
      <p class="text-sm text-orange-600 mt-2">
        You must have a case linked to this regulator to submit a rating.
      </p>
    {/if}
  </div>

  <!-- Rating Dimensions -->
  <div class="dimensions space-y-6">
    <RatingInput
      label="Clarity of Guidance"
      description="How clear and understandable were the regulator's requirements and guidance?"
      bind:value={formData.clarity_of_guidance}
    />

    <RatingInput
      label="Consistency of Enforcement"
      description="How consistent was the regulator in applying rules compared to similar cases?"
      bind:value={formData.consistency_of_enforcement}
    />

    <RatingInput
      label="Speed of Process"
      description="How quickly did the regulator handle your case from start to finish?"
      bind:value={formData.speed_of_process}
    />

    <RatingInput
      label="Settlement Openness"
      description="How open was the regulator to negotiation and settlement discussions?"
      bind:value={formData.settlement_openness}
    />

    <RatingInput
      label="Procedural Fairness"
      description="How fair and transparent was the enforcement process?"
      bind:value={formData.procedural_fairness}
    />

    <RatingInput
      label="Communication Quality"
      description="How effective and responsive was the regulator's communication?"
      bind:value={formData.communication_quality}
    />
  </div>

  <!-- Written Review -->
  <div class="form-group mt-8">
    <label class="block font-semibold mb-2">
      Written Review (Optional)
    </label>
    <textarea
      bind:value={formData.written_review}
      placeholder="Share specific insights about your experience..."
      rows="5"
      maxlength="500"
      class="w-full"
    ></textarea>
    <div class="char-count text-sm text-gray-500">
      {formData.written_review.length} / 500
    </div>
  </div>

  <!-- Submit -->
  <div class="form-actions mt-8">
    <button on:click={() => goto(`/regulators/${regulatorId}/scorecard`)} class="btn-secondary">
      Cancel
    </button>
    <button
      on:click={submitRating}
      disabled={!canSubmit || !formData.case_id}
      class="btn-primary"
    >
      Submit Rating
    </button>
  </div>
</div>
```

---

## 🔧 Implementation Tasks

### Week 1: Backend & Analytics

**Day 1-2: Database Schema**
- [ ] Create all table migrations
- [ ] Define Ash resources
- [ ] Add policies for verification
- [ ] Write resource tests

**Day 3-4: AI Insights Service**
- [ ] Implement aggregate calculations
- [ ] Build trend analysis
- [ ] Create comparative ranking logic
- [ ] Add percentile calculations
- [ ] Test AI insights accuracy

**Day 5: Experience Verification**
- [ ] Build case linkage verification
- [ ] Add org matching logic
- [ ] Create verification audit log
- [ ] Test verification workflow

---

### Week 2: Frontend & Integration

**Day 6-8: Scorecard Dashboard**
- [ ] Create scorecard page
- [ ] Build radar chart component
- [ ] Add dimension breakdown
- [ ] Display AI insights
- [ ] Style with TailwindCSS
- [ ] Test responsive design

**Day 9-10: Rating Form & Reviews**
- [ ] Create rating submission form
- [ ] Build rating input components
- [ ] Add review list component
- [ ] Create regulator response display
- [ ] Test real-time updates
- [ ] Sprint demo

---

## 📊 Success Metrics

- [ ] 15%+ of professionals with regulator experience submit ratings
- [ ] Average 4.0+ overall scorecard rating across all regulators
- [ ] 80%+ of ratings have verified experience
- [ ] 25%+ of scorecards receive official regulator responses

---

**Sprint Owner**: [Name]
**Sprint Duration**: 2 weeks
