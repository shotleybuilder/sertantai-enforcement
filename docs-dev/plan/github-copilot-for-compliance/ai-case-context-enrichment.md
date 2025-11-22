# Sprint: AI-Powered Case Context Enrichment

**Sprint Duration**: 2 weeks
**Team Size**: 2-3 developers (1 backend, 1 frontend, 1 AI/ML)
**Prerequisites**: Full-featured auth layer, ElectricSQL sync operational, TanStack DB integrated

---

## 🎯 Sprint Goal

Build an AI agent system that automatically enriches enforcement cases with contextual intelligence including regulation cross-references, industry benchmarks, historical patterns, and plain language summaries.

---

## 📋 User Stories

### Story 1: AI Context Generation (Backend)
**As a** system administrator
**I want** cases to be automatically enriched with AI-generated context
**So that** users receive valuable insights without manual research

**Acceptance Criteria**:
- [ ] Background job processes new cases within 5 minutes of creation
- [ ] AI generates regulation cross-references with 90%+ accuracy
- [ ] Benchmark analysis includes percentile ranking and average fines
- [ ] Pattern detection identifies similar historical cases
- [ ] Confidence scores provided for all AI-generated content
- [ ] Job failures are logged and retried with exponential backoff

**Story Points**: 8

---

### Story 2: Plain Language Summaries
**As a** SME owner (non-technical user)
**I want** cases explained in simple terms
**So that** I can understand enforcement actions without legal expertise

**Acceptance Criteria**:
- [ ] Layperson summary generated in clear, accessible language
- [ ] Professional summary provided for compliance officers/lawyers
- [ ] Reading level target: Grade 8-10 for layperson version
- [ ] Key facts highlighted (who, what, when, where, why)
- [ ] Technical terms defined inline with tooltips

**Story Points**: 5

---

### Story 3: Professional Validation Interface
**As a** verified professional (SRA/FCA)
**I want** to review and validate AI-generated context
**So that** the platform maintains high accuracy and credibility

**Acceptance Criteria**:
- [ ] Validation UI shows AI context alongside original data
- [ ] Professionals can rate accuracy (1-5 stars) per section
- [ ] Correction suggestions captured and stored
- [ ] Validation status badge shown on cases (0%, 50%, 100% validated)
- [ ] Top validators recognized with reputation points
- [ ] Validated corrections fed back to improve AI model

**Story Points**: 8

---

### Story 4: Real-time Context Display (Frontend)
**As a** user viewing a case
**I want** to see AI-generated context alongside official data
**So that** I can quickly understand the case's significance

**Acceptance Criteria**:
- [ ] AI context loads reactively from TanStack DB
- [ ] Expandable sections for each context type (regulations, benchmarks, patterns)
- [ ] Loading skeleton while AI processing in progress
- [ ] Confidence scores displayed with visual indicators
- [ ] "Was this helpful?" feedback mechanism
- [ ] Offline mode shows last cached AI context

**Story Points**: 5

---

### Story 5: Regulation Cross-Reference System
**As a** legal professional
**I want** relevant regulations automatically linked to cases
**So that** I can research applicable law without manual searching

**Acceptance Criteria**:
- [ ] AI identifies Acts and Regulations mentioned in case text
- [ ] Links to regulation database (UK.Regulation resources)
- [ ] Severity context provided (common/serious/unprecedented breach)
- [ ] Related sections suggested based on case facts
- [ ] Clickable links to full regulation text
- [ ] Historical enforcement data for each regulation

**Story Points**: 8

---

## 🏗️ Technical Architecture

### Backend Components

#### 1. AI Enrichment Worker (Oban Job)
```elixir
defmodule EhsEnforcement.Workers.EnrichCaseWorker do
  use Oban.Worker,
    queue: :ai_enrichment,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"case_id" => case_id}}) do
    case = EhsEnforcement.Enforcement.get_case!(case_id)

    # Call AI service
    enrichment = EhsEnforcement.AI.EnrichmentService.enrich_case(case)

    # Store results
    EhsEnforcement.Enforcement.update_case_enrichment(case, enrichment)

    :ok
  end
end
```

#### 2. AI Service Integration
```elixir
defmodule EhsEnforcement.AI.EnrichmentService do
  @openai_client Application.compile_env(:ehs_enforcement, :ai_client)

  def enrich_case(case) do
    %{
      regulation_links: analyze_regulations(case),
      benchmark_analysis: generate_benchmarks(case),
      pattern_detection: find_patterns(case),
      layperson_summary: generate_summary(case, :layperson),
      professional_summary: generate_summary(case, :professional),
      auto_tags: generate_tags(case),
      confidence_scores: calculate_confidence()
    }
  end

  defp analyze_regulations(case) do
    prompt = build_regulation_prompt(case)
    @openai_client.chat_completion(prompt, model: "gpt-4-turbo")
    |> parse_regulation_response()
  end
end
```

#### 3. Database Schema
```elixir
defmodule EhsEnforcement.Enforcement.CaseEnrichment do
  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    # Regulation cross-references
    attribute :regulation_links, {:array, :map} do
      description "AI-identified regulation references"
    end

    # Benchmark analysis
    attribute :benchmark_analysis, :map do
      description "Industry benchmark comparisons"
    end

    # Pattern detection
    attribute :pattern_detection, :map do
      description "Historical pattern analysis"
    end

    # Summaries
    attribute :layperson_summary, :string
    attribute :professional_summary, :string

    # Auto-tags
    attribute :auto_tags, {:array, :string}

    # Confidence scores
    attribute :confidence_scores, :map

    # Metadata
    attribute :model_version, :string
    attribute :generated_at, :utc_datetime_usec
    attribute :processing_time_ms, :integer

    timestamps()
  end

  relationships do
    belongs_to :case, EhsEnforcement.Enforcement.Case
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:regulation_links, :benchmark_analysis, :pattern_detection,
              :layperson_summary, :professional_summary, :auto_tags,
              :confidence_scores, :model_version, :processing_time_ms]
    end

    update :update do
      accept [:regulation_links, :benchmark_analysis, :pattern_detection,
              :layperson_summary, :professional_summary, :auto_tags,
              :confidence_scores]
    end
  end
end
```

### Frontend Components

#### 1. Case Enrichment Display Component
```svelte
<!-- frontend/src/lib/components/CaseEnrichment.svelte -->
<script lang="ts">
  import { db } from '$lib/db'
  import ConfidenceBadge from './ConfidenceBadge.svelte'
  import RegulationLink from './RegulationLink.svelte'

  export let caseId: string

  // Reactive query for enrichment data
  $: enrichment = db.query((q) =>
    q.case_enrichments
      .where('case_id', caseId)
      .first()
  )

  $: isProcessing = !$enrichment && loading
  $: hasEnrichment = !!$enrichment

  let showProfessionalView = true
</script>

{#if isProcessing}
  <div class="animate-pulse">
    <p>AI analysis in progress...</p>
    <div class="w-full bg-gray-200 rounded-full h-2">
      <div class="bg-blue-600 h-2 rounded-full" style="width: 45%"></div>
    </div>
  </div>
{:else if hasEnrichment}
  <div class="ai-enrichment space-y-6">
    <!-- Summary Section -->
    <section>
      <h3>Summary</h3>
      <div class="tabs">
        <button on:click={() => showProfessionalView = false}>
          Plain Language
        </button>
        <button on:click={() => showProfessionalView = true}>
          Professional
        </button>
      </div>
      <p>
        {showProfessionalView
          ? $enrichment.professional_summary
          : $enrichment.layperson_summary}
      </p>
    </section>

    <!-- Regulation Links -->
    <section>
      <h3>Applicable Regulations</h3>
      <ConfidenceBadge score={$enrichment.confidence_scores.regulation_links} />
      <div class="space-y-2">
        {#each $enrichment.regulation_links as regulation}
          <RegulationLink {regulation} />
        {/each}
      </div>
    </section>

    <!-- Benchmark Analysis -->
    <section>
      <h3>Industry Benchmarks</h3>
      <ConfidenceBadge score={$enrichment.confidence_scores.benchmark_accuracy} />
      <div class="benchmark-grid">
        <div class="metric">
          <span class="label">This Fine</span>
          <span class="value">£{$enrichment.benchmark_analysis.fine.toLocaleString()}</span>
        </div>
        <div class="metric">
          <span class="label">Industry Average</span>
          <span class="value">£{$enrichment.benchmark_analysis.average_fine_for_similar.toLocaleString()}</span>
        </div>
        <div class="metric">
          <span class="label">Percentile</span>
          <span class="value">{$enrichment.benchmark_analysis.percentile_ranking}th</span>
        </div>
      </div>
    </section>

    <!-- Pattern Detection -->
    <section>
      <h3>Historical Patterns</h3>
      <p>Similar cases: {$enrichment.pattern_detection.similar_cases_count}</p>
      <p>Trend: <span class="badge">{$enrichment.pattern_detection.trend}</span></p>
      {#if $enrichment.pattern_detection.notable_precedents.length > 0}
        <h4>Notable Precedents:</h4>
        <ul>
          {#each $enrichment.pattern_detection.notable_precedents as precedent}
            <li>{precedent}</li>
          {/each}
        </ul>
      {/if}
    </section>

    <!-- Tags -->
    <section>
      <h3>AI Tags</h3>
      <div class="flex flex-wrap gap-2">
        {#each $enrichment.auto_tags as tag}
          <span class="badge">{tag}</span>
        {/each}
      </div>
    </section>

    <!-- Feedback -->
    <section>
      <button on:click={submitFeedback}>Was this helpful?</button>
    </section>
  </div>
{/if}
```

#### 2. Professional Validation Component
```svelte
<!-- frontend/src/lib/components/ValidationInterface.svelte -->
<script lang="ts">
  import { db } from '$lib/db'
  import { currentUser } from '$lib/stores/auth'

  export let enrichmentId: string

  // Only show for verified professionals
  $: canValidate = $currentUser?.professional_tier === 'professional'
    || $currentUser?.professional_tier === 'expert'

  async function submitValidation(section: string, rating: number, corrections?: string) {
    await db.mutate((m) =>
      m.enrichment_validations.create({
        enrichment_id: enrichmentId,
        user_id: $currentUser.id,
        section,
        rating,
        corrections,
        validated_at: new Date().toISOString()
      })
    )
  }
</script>

{#if canValidate}
  <div class="validation-panel">
    <h4>Validate AI Analysis</h4>
    <p class="text-sm">Help improve accuracy by rating this AI-generated content</p>

    <div class="validation-sections">
      <div class="section">
        <h5>Regulation Links</h5>
        <RatingStars onRate={(rating) => submitValidation('regulation_links', rating)} />
        <textarea placeholder="Suggest corrections (optional)"></textarea>
      </div>

      <div class="section">
        <h5>Benchmark Analysis</h5>
        <RatingStars onRate={(rating) => submitValidation('benchmark_analysis', rating)} />
        <textarea placeholder="Suggest corrections (optional)"></textarea>
      </div>
    </div>
  </div>
{/if}
```

---

## 🔧 Implementation Tasks

### Week 1: Backend Foundation

**Day 1-2: Database Schema & Migrations**
- [ ] Create `case_enrichments` table migration
- [ ] Create `enrichment_validations` table migration
- [ ] Add Ash resources for CaseEnrichment and EnrichmentValidation
- [ ] Define relationships between Case and CaseEnrichment
- [ ] Run `mix ash.codegen` and `mix ash.migrate`
- [ ] Write resource tests

**Day 3-4: AI Service Integration**
- [ ] Set up OpenAI API client (or Anthropic Claude)
- [ ] Create `EhsEnforcement.AI.EnrichmentService` module
- [ ] Implement `analyze_regulations/1` function
- [ ] Implement `generate_benchmarks/1` function
- [ ] Implement `find_patterns/1` function
- [ ] Implement `generate_summary/2` function (layperson + professional)
- [ ] Implement `generate_tags/1` function
- [ ] Add prompt engineering templates
- [ ] Write unit tests with mocked AI responses
- [ ] Add configuration for AI model selection (env vars)

**Day 5: Oban Worker & Background Processing**
- [ ] Create `EnrichCaseWorker` Oban worker
- [ ] Configure `:ai_enrichment` queue in config
- [ ] Add job scheduling on case creation (Ash after_action hook)
- [ ] Implement retry logic with exponential backoff
- [ ] Add error logging and monitoring
- [ ] Test worker with real cases
- [ ] Add admin interface to manually trigger enrichment

---

### Week 2: Frontend & Validation

**Day 6-7: Frontend Components**
- [ ] Create `CaseEnrichment.svelte` component
- [ ] Create `RegulationLink.svelte` component
- [ ] Create `ConfidenceBadge.svelte` component
- [ ] Create `BenchmarkChart.svelte` component (optional visualization)
- [ ] Add loading skeleton for AI processing state
- [ ] Integrate with TanStack DB reactive queries
- [ ] Add toggle between layperson/professional summaries
- [ ] Style with TailwindCSS
- [ ] Add responsive design for mobile
- [ ] Write Vitest component tests

**Day 8-9: Validation Interface**
- [ ] Create `ValidationInterface.svelte` component
- [ ] Add rating stars component with 1-5 scale
- [ ] Add correction text input with markdown support
- [ ] Create backend API for validation submissions
- [ ] Integrate validation mutations with TanStack DB
- [ ] Display validation statistics (% validated, avg rating)
- [ ] Add reputation scoring for validators
- [ ] Show "Verified by X professionals" badge on cases
- [ ] Test validation workflow end-to-end

**Day 10: Integration & Polish**
- [ ] Integrate enrichment component into case detail page
- [ ] Add ElectricSQL sync for case_enrichments table
- [ ] Enable logical replication for new tables
- [ ] Test real-time sync (enrichment updates propagate to clients)
- [ ] Test offline mode (cached enrichment displays)
- [ ] Add analytics tracking (enrichment view rate, validation rate)
- [ ] Performance optimization (lazy load enrichment data)
- [ ] Accessibility audit (screen readers, keyboard navigation)
- [ ] Documentation (add to CLAUDE.md, create user guide)
- [ ] Sprint retrospective and demo preparation

---

## 🧪 Testing Strategy

### Unit Tests
```elixir
# test/ehs_enforcement/ai/enrichment_service_test.exs
defmodule EhsEnforcement.AI.EnrichmentServiceTest do
  use EhsEnforcement.DataCase

  alias EhsEnforcement.AI.EnrichmentService

  describe "enrich_case/1" do
    setup do
      case = build_case_fixture(%{
        offence_breaches: "Breach of Health and Safety at Work Act 1974, Section 2(1)",
        offence_fine: 50000,
        offence_action_date: ~D[2024-01-15]
      })

      {:ok, case: case}
    end

    test "identifies regulations correctly", %{case: case} do
      enrichment = EnrichmentService.enrich_case(case)

      assert length(enrichment.regulation_links) > 0
      assert Enum.any?(enrichment.regulation_links, fn reg ->
        reg.act == "Health and Safety at Work etc. Act 1974"
      end)
    end

    test "generates layperson and professional summaries", %{case: case} do
      enrichment = EnrichmentService.enrich_case(case)

      assert enrichment.layperson_summary != nil
      assert enrichment.professional_summary != nil
      assert String.length(enrichment.layperson_summary) > 50
    end

    test "calculates benchmark percentile", %{case: case} do
      enrichment = EnrichmentService.enrich_case(case)

      assert enrichment.benchmark_analysis.percentile_ranking >= 0
      assert enrichment.benchmark_analysis.percentile_ranking <= 100
    end
  end
end
```

### Integration Tests
```typescript
// frontend/src/lib/components/CaseEnrichment.test.ts
import { render, screen, waitFor } from '@testing-library/svelte'
import { describe, it, expect, vi } from 'vitest'
import CaseEnrichment from './CaseEnrichment.svelte'
import { db } from '$lib/db'

describe('CaseEnrichment', () => {
  it('displays loading state while processing', () => {
    render(CaseEnrichment, { props: { caseId: 'test-id' } })
    expect(screen.getByText(/AI analysis in progress/i)).toBeInTheDocument()
  })

  it('displays enrichment data when available', async () => {
    const mockEnrichment = {
      id: 'enrich-1',
      case_id: 'test-id',
      layperson_summary: 'A company was fined for safety violations',
      professional_summary: 'Breach of HSWA 1974 s2(1)',
      regulation_links: [
        { act: 'HSWA 1974', section: '2(1)', summary: 'Duty of care' }
      ],
      confidence_scores: { regulation_links: 0.95 }
    }

    // Mock TanStack DB query
    vi.spyOn(db, 'query').mockReturnValue(mockEnrichment)

    render(CaseEnrichment, { props: { caseId: 'test-id' } })

    await waitFor(() => {
      expect(screen.getByText(/A company was fined/i)).toBeInTheDocument()
      expect(screen.getByText(/HSWA 1974/i)).toBeInTheDocument()
    })
  })

  it('allows toggling between layperson and professional views', async () => {
    const { component } = render(CaseEnrichment, { props: { caseId: 'test-id' } })

    const plainLanguageBtn = screen.getByText(/Plain Language/i)
    await plainLanguageBtn.click()

    expect(screen.getByText(/A company was fined/i)).toBeInTheDocument()
  })
})
```

### E2E Tests
```typescript
// frontend/tests/e2e/case-enrichment.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Case Enrichment', () => {
  test('displays AI enrichment on case detail page', async ({ page }) => {
    await page.goto('/cases/test-case-id')

    // Wait for enrichment to load
    await expect(page.locator('[data-testid="ai-enrichment"]')).toBeVisible()

    // Check regulation links
    await expect(page.locator('[data-testid="regulation-link"]').first()).toBeVisible()

    // Check benchmark analysis
    await expect(page.locator('text=/Industry Average/i')).toBeVisible()

    // Toggle to plain language
    await page.click('text=/Plain Language/i')
    await expect(page.locator('[data-testid="layperson-summary"]')).toBeVisible()
  })

  test('allows verified professionals to validate enrichment', async ({ page }) => {
    // Login as verified professional
    await page.goto('/login')
    await page.fill('input[name="email"]', 'verified@law.co.uk')
    await page.fill('input[name="password"]', 'password')
    await page.click('button[type="submit"]')

    // Navigate to case
    await page.goto('/cases/test-case-id')

    // Validation interface should be visible
    await expect(page.locator('[data-testid="validation-panel"]')).toBeVisible()

    // Submit validation
    await page.click('[data-testid="rating-star-5"]')
    await page.fill('textarea[placeholder*="corrections"]', 'Looks accurate')
    await page.click('button:has-text("Submit Validation")')

    // Check for success message
    await expect(page.locator('text=/Thank you for validating/i')).toBeVisible()
  })
})
```

---

## 📊 Success Metrics

### Performance Metrics
- [ ] AI enrichment completes within 30 seconds for 95% of cases
- [ ] Enrichment data syncs to clients within 2 seconds
- [ ] Frontend renders enrichment in <100ms after data loads
- [ ] Validation submission completes in <500ms

### Quality Metrics
- [ ] Regulation identification accuracy >90% (validated by professionals)
- [ ] Benchmark calculations within 10% of actual average
- [ ] At least 20% of cases validated by professionals within first month
- [ ] User satisfaction rating >4.0/5.0 for enrichment helpfulness

### Business Metrics
- [ ] 60%+ of users view AI enrichment on case detail pages
- [ ] 10%+ of verified professionals submit validations
- [ ] Enrichment feature increases user session time by 25%+
- [ ] Feature referenced in 50%+ of user feedback as "most valuable"

---

## 🚧 Risks & Mitigations

### Risk 1: AI Costs Too High
**Impact**: High - Could make feature uneconomical
**Probability**: Medium
**Mitigation**:
- Start with GPT-4 Turbo (cheaper than GPT-4)
- Consider open-source models (Llama 3.1) for some tasks
- Cache enrichment results (don't re-process same case)
- Rate limit enrichment to N cases/day for free users
- Premium tier gets unlimited enrichment

### Risk 2: Low Validation Participation
**Impact**: Medium - Reduces credibility of AI content
**Probability**: Medium
**Mitigation**:
- Gamification (reputation points, leaderboards)
- Incentives (validated cases show up higher in search)
- Email campaigns to verified professionals
- Highlight top validators in monthly newsletter
- Offer referral rewards for active validators

### Risk 3: AI Hallucinations/Inaccuracies
**Impact**: High - Damages trust and credibility
**Probability**: Medium
**Mitigation**:
- Require professional validation before high-confidence display
- Show confidence scores prominently
- Add "AI-generated, verify independently" disclaimers
- Allow users to flag inaccurate enrichment
- Human review of flagged content within 24 hours
- Feedback loop improves model over time

### Risk 4: Performance Issues with Background Jobs
**Impact**: Medium - Slow enrichment frustrates users
**Probability**: Low
**Mitigation**:
- Horizontal scaling of Oban workers
- Priority queue (new cases enriched first)
- Progress indicators ("Enrichment 45% complete")
- Partial results (show summary first, benchmarks later)
- Monitor job queue depth and add alerts

---

## 🎓 Learning Objectives

By the end of this sprint, the team will have learned:

1. **AI Integration Patterns**: How to integrate LLM APIs into Elixir/Phoenix backend
2. **Prompt Engineering**: Effective prompts for structured data extraction
3. **Background Job Processing**: Oban worker patterns for long-running AI tasks
4. **Real-time Sync**: ElectricSQL sync of AI-generated content
5. **Professional Validation UX**: Building trust through community validation
6. **Reactive Queries**: TanStack DB patterns for complex data relationships
7. **Error Handling**: Graceful degradation when AI services unavailable

---

## 📚 Resources

### AI/ML Resources
- [OpenAI API Documentation](https://platform.openai.com/docs)
- [Anthropic Claude API](https://docs.anthropic.com/)
- [Prompt Engineering Guide](https://www.promptingguide.ai/)
- [LangChain.js](https://js.langchain.com/) - For advanced AI workflows

### Elixir/Phoenix Resources
- [Oban Documentation](https://hexdocs.pm/oban/)
- [Ash Framework Guides](https://hexdocs.pm/ash/)
- [Tesla HTTP Client](https://hexdocs.pm/tesla/) - For API requests

### Frontend Resources
- [TanStack DB Mutations Guide](https://tanstack.com/db/latest/docs/guides/mutations)
- [Svelte Testing Library](https://testing-library.com/docs/svelte-testing-library/intro)
- [Playwright E2E Testing](https://playwright.dev/)

---

## 🎬 Sprint Ceremonies

### Daily Standup (15 min)
- What did I complete yesterday?
- What am I working on today?
- Any blockers?

### Mid-Sprint Check-in (Day 5, 1 hour)
- Demo backend AI enrichment working
- Review AI accuracy on sample cases
- Adjust prompt engineering if needed
- Confirm frontend design with stakeholders

### Sprint Review (Day 10, 1 hour)
- Demo full feature to stakeholders
- Show real-time enrichment sync
- Demonstrate validation workflow
- Gather feedback for iteration

### Sprint Retrospective (Day 10, 45 min)
- What went well?
- What could be improved?
- Action items for next sprint

---

## ✅ Definition of Done

A story is "Done" when:
- [ ] Code is written and follows project standards (Credo, Dialyzer pass)
- [ ] Unit tests written and passing (>90% coverage)
- [ ] Integration tests written and passing
- [ ] E2E test covers happy path
- [ ] Code reviewed and approved by 1+ team member
- [ ] Documentation updated (inline docs, CLAUDE.md, user guide)
- [ ] Feature deployed to staging environment
- [ ] QA tested on staging
- [ ] Accessibility checked (WCAG 2.1 AA)
- [ ] Performance benchmarked (meets sprint goals)
- [ ] Product owner accepts feature

---

## 🚀 Post-Sprint: Iteration Ideas

Features to consider for future sprints:
1. **Custom AI Models**: Fine-tune Llama 3.1 on enforcement data for better accuracy
2. **Batch Enrichment**: Admin tool to enrich all historical cases
3. **Multilingual Summaries**: Generate summaries in Welsh, Gaelic, etc.
4. **Audio Summaries**: Text-to-speech for accessibility
5. **AI Chat Interface**: Ask questions about enriched cases
6. **Enrichment API**: Expose AI analysis via public API for enterprise customers
7. **Validation Gamification**: Leaderboards, badges, rewards for top validators
8. **Confidence Improvement**: Track validation feedback to improve AI accuracy over time

---

**Sprint Owner**: [Name]
**Stakeholders**: Product Manager, CTO, Lead Compliance Officer
**Sprint Start Date**: [Date]
**Sprint End Date**: [Date + 2 weeks]
