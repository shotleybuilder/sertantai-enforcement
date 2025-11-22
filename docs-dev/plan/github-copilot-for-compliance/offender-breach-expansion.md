# Sprint: Offender Breach Description Expansion

**Sprint Duration**: 2 weeks
**Team Size**: 2-3 developers (1 backend, 1 frontend, 0.5 AI/ML)
**Prerequisites**: Full-featured auth layer with SRA/FCA validation, AI enrichment system operational

---

## 🎯 Sprint Goal

Build a platform feature allowing verified offender representatives to provide expanded, structured context around enforcement breaches including root cause analysis, corrective actions, and lessons learned - creating a unique "case study library" validated by the professional community.

---

## 📋 User Stories

### Story 1: Offender Context Submission Form
**As a** verified offender representative (validated company employee)
**I want** to submit detailed context about our enforcement case
**So that** we can provide transparency, demonstrate remediation efforts, and help others learn from our experience

**Acceptance Criteria**:
- [ ] Multi-step form with structured fields (what/why/how/preventive measures)
- [ ] Timeline builder for incident progression
- [ ] File upload for supporting documents (max 10MB per file)
- [ ] Auto-save draft functionality (works offline via TanStack DB)
- [ ] Preview mode before submission
- [ ] Markdown editor with formatting toolbar
- [ ] AI assistance for summarizing free-text input
- [ ] Character limits enforced (500-5000 words per section)
- [ ] Submission triggers moderation workflow

**Story Points**: 8

---

### Story 2: AI-Assisted Structuring
**As a** offender submitting context
**I want** AI to help me structure my free-text description
**So that** I can quickly provide high-quality, well-organized information

**Acceptance Criteria**:
- [ ] AI extracts key points from free-text input
- [ ] AI suggests timeline entries based on narrative
- [ ] AI identifies mentioned regulations and creates links
- [ ] AI generates compliance effectiveness rating (weak/moderate/strong)
- [ ] AI suggests relevant lessons learned based on similar cases
- [ ] User can accept/edit/reject AI suggestions
- [ ] AI processing completes in <10 seconds
- [ ] Confidence scores shown for AI suggestions

**Story Points**: 5

---

### Story 3: Moderation Workflow
**As a** platform moderator (verified professional)
**I want** to review offender submissions before publication
**So that** we prevent defamatory content, spam, and maintain platform quality

**Acceptance Criteria**:
- [ ] Moderation queue shows pending submissions
- [ ] AI pre-screening flags potentially problematic content
- [ ] Moderators can approve/reject/request changes
- [ ] Rejection requires explanation sent to submitter
- [ ] Three-strike system for repeat offenders
- [ ] Approved content published immediately via ElectricSQL sync
- [ ] Email notifications to submitter on status changes
- [ ] Moderation statistics dashboard (approval rate, avg review time)

**Story Points**: 8

---

### Story 4: Community Validation System
**As a** verified professional viewing offender context
**I want** to rate and comment on the quality/helpfulness
**So that** high-quality submissions rise to the top and low-quality ones are flagged

**Acceptance Criteria**:
- [ ] 5-star rating system per submission
- [ ] Optional written comment (500 char limit)
- [ ] "Helpful" upvote button (Stack Overflow style)
- [ ] Average rating displayed prominently
- [ ] Top-rated submissions get "Highly Rated" badge
- [ ] Low-rated submissions (<2.0 avg) require re-review
- [ ] Users can flag submissions as inaccurate/misleading
- [ ] Only verified professionals can rate (not general public)
- [ ] Users cannot rate their own submissions

**Story Points**: 5

---

### Story 5: Offender Verification System
**As a** platform administrator
**I want** to verify that submission authors are legitimate company representatives
**So that** we prevent fraudulent submissions and maintain credibility

**Acceptance Criteria**:
- [ ] Corporate email verification (domain check against Companies House)
- [ ] Manual identity verification for first submission
- [ ] LinkedIn profile cross-reference (optional)
- [ ] Company officer check via Companies House API
- [ ] "Verified Offender Representative" badge on profile
- [ ] Verification expires annually (re-verification required)
- [ ] Verification status visible on all submissions
- [ ] Audit log of verification checks

**Story Points**: 8

---

### Story 6: Expanded Context Display
**As a** user viewing a case
**I want** to see offender-provided context alongside official enforcement data
**So that** I get a complete picture of the incident and remediation

**Acceptance Criteria**:
- [ ] Expandable "Offender Perspective" section on case detail page
- [ ] Timeline visualization of incident progression
- [ ] Supporting documents displayed with preview
- [ ] Community rating shown prominently
- [ ] "Verified Representative" badge clearly visible
- [ ] Moderation status indicator (approved/pending/under review)
- [ ] AI-generated compliance analysis displayed
- [ ] Helpful/unhelpful vote counts
- [ ] Related case studies suggested

**Story Points**: 8

---

## 🏗️ Technical Architecture

### Backend Components

#### 1. Database Schema
```elixir
defmodule EhsEnforcement.Enforcement.OffenderContext do
  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    # Submission status
    attribute :status, :atom do
      constraints one_of: [:draft, :pending_review, :approved, :rejected, :under_review]
      default :draft
    end

    # Structured content
    attribute :what_happened, :string do
      constraints max_length: 10000
      allow_nil?: false
    end

    attribute :root_cause_analysis, :string do
      constraints max_length: 10000
      allow_nil?: false
    end

    attribute :corrective_actions_taken, :string do
      constraints max_length: 10000
      allow_nil?: false
    end

    attribute :preventive_measures, :string do
      constraints max_length: 10000
      allow_nil?: false
    end

    # Timeline
    attribute :timeline, {:array, :map} do
      description "Chronological incident events"
    end

    # AI analysis
    attribute :ai_summary, :string
    attribute :ai_compliance_analysis, :map

    # Moderation
    attribute :rejection_reason, :string
    attribute :moderation_notes, :string
    attribute :moderated_by, :uuid
    attribute :moderated_at, :utc_datetime_usec

    # Metrics
    attribute :view_count, :integer, default: 0
    attribute :helpful_votes, :integer, default: 0
    attribute :unhelpful_votes, :integer, default: 0

    timestamps()
  end

  relationships do
    belongs_to :case, EhsEnforcement.Enforcement.Case
    belongs_to :submitted_by, EhsEnforcement.Accounts.User
    belongs_to :organization, EhsEnforcement.Auth.Organization

    has_many :attachments, EhsEnforcement.Enforcement.OffenderContextAttachment
    has_many :ratings, EhsEnforcement.Enforcement.OffenderContextRating
  end

  actions do
    defaults [:read]

    create :submit do
      accept [:what_happened, :root_cause_analysis, :corrective_actions_taken,
              :preventive_measures, :timeline]

      argument :case_id, :uuid, allow_nil?: false

      change set_attribute(:status, :pending_review)
      change relate_actor(:submitted_by)
      change EhsEnforcement.Changes.TriggerModerationWorkflow
    end

    update :approve do
      require_atomic? false
      accept []

      argument :moderator_id, :uuid, allow_nil?: false

      change set_attribute(:status, :approved)
      change set_attribute(:moderated_at, &DateTime.utc_now/0)
      change EhsEnforcement.Changes.NotifySubmitter
    end

    update :reject do
      require_atomic? false
      accept [:rejection_reason]

      argument :moderator_id, :uuid, allow_nil?: false

      change set_attribute(:status, :rejected)
      change set_attribute(:moderated_at, &DateTime.utc_now/0)
      change EhsEnforcement.Changes.NotifySubmitter
    end

    update :save_draft do
      accept [:what_happened, :root_cause_analysis, :corrective_actions_taken,
              :preventive_measures, :timeline]
    end
  end

  policies do
    # Only offender org members can create
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:organization_id, :organization_id)
    end

    # Anyone can read approved contexts
    policy action_type(:read) do
      authorize_if always()
    end

    # Only moderators can approve/reject
    policy action_type([:approve, :reject]) do
      authorize_if actor_attribute_equals(:role, :moderator)
    end
  end
end
```

#### 2. Offender Verification Resource
```elixir
defmodule EhsEnforcement.Accounts.OffenderVerification do
  use Ash.Resource,
    domain: EhsEnforcement.Accounts,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :verification_type, :atom do
      constraints one_of: [:email, :companies_house, :linkedin, :manual]
    end

    attribute :status, :atom do
      constraints one_of: [:pending, :verified, :rejected, :expired]
      default :pending
    end

    # Verification data
    attribute :corporate_email, :string
    attribute :email_domain, :string
    attribute :companies_house_number, :string
    attribute :officer_name, :string
    attribute :linkedin_url, :string

    # Verification results
    attribute :domain_match, :boolean
    attribute :officer_match, :boolean
    attribute :manual_verification_notes, :string

    # Expiration
    attribute :verified_at, :utc_datetime_usec
    attribute :expires_at, :utc_datetime_usec

    timestamps()
  end

  relationships do
    belongs_to :user, EhsEnforcement.Accounts.User
    belongs_to :organization, EhsEnforcement.Auth.Organization
    belongs_to :verified_by, EhsEnforcement.Accounts.User
  end

  actions do
    defaults [:read]

    create :request_verification do
      accept [:corporate_email, :companies_house_number, :linkedin_url]

      change EhsEnforcement.Changes.VerifyCorporateEmail
      change EhsEnforcement.Changes.CheckCompaniesHouse
      change EhsEnforcement.Changes.ExtractLinkedInProfile
    end

    update :approve_manual do
      accept [:manual_verification_notes]

      change set_attribute(:status, :verified)
      change set_attribute(:verified_at, &DateTime.utc_now/0)
      change set_attribute(:expires_at, &one_year_from_now/0)
    end
  end

  calculations do
    calculate :is_verified, :boolean do
      expr(status == :verified and expires_at > now())
    end
  end
end
```

#### 3. AI Structuring Service
```elixir
defmodule EhsEnforcement.AI.ContextStructuringService do
  @moduledoc """
  AI service for helping offenders structure their free-text submissions
  """

  def assist_submission(free_text) do
    %{
      structured_extraction: extract_structure(free_text),
      timeline_suggestions: suggest_timeline(free_text),
      regulation_links: identify_regulations(free_text),
      compliance_effectiveness: assess_compliance(free_text),
      lessons_learned: suggest_lessons(free_text)
    }
  end

  defp extract_structure(text) do
    prompt = """
    Extract structured information from this incident description:

    #{text}

    Return JSON with:
    - what_happened: Brief factual description
    - root_cause: Why it happened
    - corrective_actions: What was done to fix it
    - preventive_measures: Long-term changes to prevent recurrence
    """

    OpenAI.chat_completion(prompt, model: "gpt-4-turbo")
    |> parse_json_response()
  end

  defp suggest_timeline(text) do
    prompt = """
    Extract timeline events from this narrative:

    #{text}

    Return JSON array of events with:
    - date: ISO date
    - event: Brief description
    - type: 'incident' | 'discovery' | 'notification' | 'action' | 'resolution'
    """

    OpenAI.chat_completion(prompt, model: "gpt-4-turbo")
    |> parse_json_response()
  end

  defp assess_compliance(text) do
    prompt = """
    Assess the effectiveness of compliance measures described:

    #{text}

    Return JSON with:
    - rating: 'weak' | 'moderate' | 'strong'
    - rationale: Brief explanation
    - improvements: Array of suggested improvements
    """

    OpenAI.chat_completion(prompt, model: "gpt-4-turbo")
    |> parse_json_response()
  end
end
```

### Frontend Components

#### 1. Submission Form Component
```svelte
<!-- frontend/src/lib/components/OffenderContextForm.svelte -->
<script lang="ts">
  import { db } from '$lib/db'
  import { currentUser } from '$lib/stores/auth'
  import AIAssistant from './AIAssistant.svelte'
  import TimelineBuilder from './TimelineBuilder.svelte'
  import FileUpload from './FileUpload.svelte'

  export let caseId: string

  let step = 1
  let formData = {
    what_happened: '',
    root_cause_analysis: '',
    corrective_actions_taken: '',
    preventive_measures: '',
    timeline: []
  }

  let isDraft = false
  let showAIAssistant = false

  // Auto-save draft every 30 seconds
  $: if (formData) {
    debounce(() => saveDraft(), 30000)
  }

  async function saveDraft() {
    isDraft = true
    await db.mutate((m) =>
      m.offender_contexts.update(draftId, {
        ...formData,
        status: 'draft'
      })
    )
  }

  async function submitForReview() {
    try {
      await db.mutate((m) =>
        m.offender_contexts.create({
          case_id: caseId,
          ...formData,
          status: 'pending_review',
          submitted_by: $currentUser.id,
          organization_id: $currentUser.organization_id
        })
      )

      // Navigate to success page
      goto(`/cases/${caseId}?submitted=true`)
    } catch (error) {
      console.error('Submission failed:', error)
      alert('Submission failed. Please try again.')
    }
  }

  async function requestAIAssistance() {
    showAIAssistant = true
    const suggestions = await fetch('/api/ai/structure-context', {
      method: 'POST',
      body: JSON.stringify({ text: formData.what_happened })
    }).then(r => r.json())

    // Show suggestions to user
    aiSuggestions = suggestions
  }
</script>

<div class="offender-context-form max-w-4xl mx-auto">
  <h2>Share Your Perspective</h2>
  <p class="text-gray-600">
    Provide context about this enforcement action to help others learn.
    Your submission will be reviewed by platform moderators before publication.
  </p>

  <!-- Progress Steps -->
  <div class="steps">
    <div class:active={step === 1}>1. What Happened</div>
    <div class:active={step === 2}>2. Root Cause</div>
    <div class:active={step === 3}>3. Actions Taken</div>
    <div class:active={step === 4}>4. Preventive Measures</div>
    <div class:active={step === 5}>5. Review & Submit</div>
  </div>

  <!-- Step 1: What Happened -->
  {#if step === 1}
    <section>
      <h3>What Happened?</h3>
      <p>Describe the incident in detail (500-5000 words)</p>

      <textarea
        bind:value={formData.what_happened}
        placeholder="On January 15, 2024, during roof renovation work..."
        rows="15"
        class="w-full"
      ></textarea>

      <div class="char-count">
        {formData.what_happened.length} / 5000 characters
      </div>

      <button on:click={requestAIAssistance} class="btn-secondary">
        🤖 Get AI Assistance
      </button>

      {#if showAIAssistant}
        <AIAssistant suggestions={aiSuggestions} onApply={applySuggestions} />
      {/if}

      <button on:click={() => step = 2} class="btn-primary">
        Next: Root Cause →
      </button>
    </section>
  {/if}

  <!-- Step 2: Root Cause -->
  {#if step === 2}
    <section>
      <h3>Root Cause Analysis</h3>
      <p>Why did this incident occur?</p>

      <textarea
        bind:value={formData.root_cause_analysis}
        placeholder="The incident occurred because..."
        rows="10"
      ></textarea>

      <div class="btn-group">
        <button on:click={() => step = 1} class="btn-secondary">
          ← Back
        </button>
        <button on:click={() => step = 3} class="btn-primary">
          Next: Corrective Actions →
        </button>
      </div>
    </section>
  {/if}

  <!-- Step 3: Corrective Actions -->
  {#if step === 3}
    <section>
      <h3>Corrective Actions Taken</h3>
      <p>What immediate steps did you take to resolve the issue?</p>

      <textarea
        bind:value={formData.corrective_actions_taken}
        placeholder="We immediately stopped work and..."
        rows="10"
      ></textarea>

      <h4>Timeline</h4>
      <TimelineBuilder bind:timeline={formData.timeline} />

      <div class="btn-group">
        <button on:click={() => step = 2} class="btn-secondary">
          ← Back
        </button>
        <button on:click={() => step = 4} class="btn-primary">
          Next: Preventive Measures →
        </button>
      </div>
    </section>
  {/if}

  <!-- Step 4: Preventive Measures -->
  {#if step === 4}
    <section>
      <h3>Preventive Measures</h3>
      <p>What long-term changes have you implemented?</p>

      <textarea
        bind:value={formData.preventive_measures}
        placeholder="To prevent recurrence, we have..."
        rows="10"
      ></textarea>

      <h4>Supporting Documents</h4>
      <FileUpload onUpload={handleFileUpload} maxFiles={5} />

      <div class="btn-group">
        <button on:click={() => step = 3} class="btn-secondary">
          ← Back
        </button>
        <button on:click={() => step = 5} class="btn-primary">
          Review & Submit →
        </button>
      </div>
    </section>
  {/if}

  <!-- Step 5: Review & Submit -->
  {#if step === 5}
    <section>
      <h3>Review Your Submission</h3>

      <div class="preview">
        <h4>What Happened</h4>
        <p>{formData.what_happened}</p>

        <h4>Root Cause</h4>
        <p>{formData.root_cause_analysis}</p>

        <h4>Corrective Actions</h4>
        <p>{formData.corrective_actions_taken}</p>

        <h4>Preventive Measures</h4>
        <p>{formData.preventive_measures}</p>

        <h4>Timeline</h4>
        <TimelineVisualization timeline={formData.timeline} />
      </div>

      <div class="terms">
        <label>
          <input type="checkbox" bind:checked={agreedToTerms} />
          I confirm this information is accurate and I am authorized to share it on behalf of my organization.
        </label>
      </div>

      <div class="btn-group">
        <button on:click={() => step = 4} class="btn-secondary">
          ← Back
        </button>
        <button on:click={saveDraft} class="btn-secondary">
          Save Draft
        </button>
        <button
          on:click={submitForReview}
          disabled={!agreedToTerms}
          class="btn-primary"
        >
          Submit for Review
        </button>
      </div>
    </section>
  {/if}

  <!-- Auto-save indicator -->
  {#if isDraft}
    <div class="auto-save-indicator">
      ✓ Draft saved
    </div>
  {/if}
</div>
```

#### 2. Moderation Queue Component
```svelte
<!-- frontend/src/lib/components/ModerationQueue.svelte -->
<script lang="ts">
  import { db } from '$lib/db'
  import { currentUser } from '$lib/stores/auth'

  // Query pending submissions
  $: pendingSubmissions = db.query((q) =>
    q.offender_contexts
      .where('status', 'pending_review')
      .orderBy('created_at', 'asc')
  )

  let selectedSubmission = null
  let rejectionReason = ''

  async function approveSubmission(submissionId: string) {
    await db.mutate((m) =>
      m.offender_contexts.approve({
        id: submissionId,
        moderator_id: $currentUser.id
      })
    )

    selectedSubmission = null
  }

  async function rejectSubmission(submissionId: string) {
    await db.mutate((m) =>
      m.offender_contexts.reject({
        id: submissionId,
        rejection_reason: rejectionReason,
        moderator_id: $currentUser.id
      })
    )

    selectedSubmission = null
    rejectionReason = ''
  }
</script>

<div class="moderation-queue">
  <h2>Moderation Queue</h2>
  <p>Pending submissions: {$pendingSubmissions?.length || 0}</p>

  <div class="grid grid-cols-2 gap-6">
    <!-- Submission List -->
    <div class="submission-list">
      {#each $pendingSubmissions as submission}
        <div
          class="submission-card"
          class:selected={selectedSubmission?.id === submission.id}
          on:click={() => selectedSubmission = submission}
        >
          <h4>Case: {submission.case.case_reference}</h4>
          <p class="text-sm text-gray-600">
            Submitted by: {submission.submitted_by.email}
          </p>
          <p class="text-sm">
            {new Date(submission.created_at).toLocaleDateString()}
          </p>

          <!-- AI Pre-screening Flags -->
          {#if submission.ai_flags?.length > 0}
            <div class="flags">
              {#each submission.ai_flags as flag}
                <span class="badge badge-warning">{flag}</span>
              {/each}
            </div>
          {/if}
        </div>
      {/each}
    </div>

    <!-- Submission Detail -->
    <div class="submission-detail">
      {#if selectedSubmission}
        <h3>Review Submission</h3>

        <div class="content-review">
          <section>
            <h4>What Happened</h4>
            <p>{selectedSubmission.what_happened}</p>
          </section>

          <section>
            <h4>Root Cause Analysis</h4>
            <p>{selectedSubmission.root_cause_analysis}</p>
          </section>

          <section>
            <h4>Corrective Actions</h4>
            <p>{selectedSubmission.corrective_actions_taken}</p>
          </section>

          <section>
            <h4>Preventive Measures</h4>
            <p>{selectedSubmission.preventive_measures}</p>
          </section>

          <!-- AI Analysis -->
          <section>
            <h4>AI Compliance Analysis</h4>
            <p>Effectiveness: {selectedSubmission.ai_compliance_analysis.rating}</p>
            <p>{selectedSubmission.ai_compliance_analysis.rationale}</p>
          </section>
        </div>

        <!-- Moderation Actions -->
        <div class="moderation-actions">
          <button
            on:click={() => approveSubmission(selectedSubmission.id)}
            class="btn-success"
          >
            ✓ Approve
          </button>

          <div class="reject-section">
            <textarea
              bind:value={rejectionReason}
              placeholder="Reason for rejection..."
              rows="3"
            ></textarea>
            <button
              on:click={() => rejectSubmission(selectedSubmission.id)}
              disabled={!rejectionReason}
              class="btn-danger"
            >
              ✗ Reject
            </button>
          </div>
        </div>
      {:else}
        <p class="text-gray-500 text-center">
          Select a submission to review
        </p>
      {/if}
    </div>
  </div>
</div>
```

---

## 🔧 Implementation Tasks

### Week 1: Backend & Verification

**Day 1-2: Database Schema & Ash Resources**
- [ ] Create `offender_contexts` table migration
- [ ] Create `offender_context_attachments` table migration
- [ ] Create `offender_context_ratings` table migration
- [ ] Create `offender_verifications` table migration
- [ ] Define Ash resources with relationships
- [ ] Add policies for authorization
- [ ] Run migrations and resource tests

**Day 3-4: Offender Verification System**
- [ ] Implement corporate email verification (domain check)
- [ ] Integrate Companies House API for officer lookup
- [ ] Build LinkedIn profile extraction (optional)
- [ ] Create admin panel for manual verification
- [ ] Add verification badge to user profiles
- [ ] Write verification workflow tests
- [ ] Set up annual re-verification reminders

**Day 5: AI Structuring Service**
- [ ] Create `ContextStructuringService` module
- [ ] Implement structured extraction from free text
- [ ] Implement timeline suggestion algorithm
- [ ] Implement compliance effectiveness assessment
- [ ] Add prompt engineering templates
- [ ] Test with sample submissions
- [ ] Optimize for cost (use GPT-4 Turbo)

---

### Week 2: Frontend & Moderation

**Day 6-7: Submission Form**
- [ ] Create multi-step form component
- [ ] Build timeline builder UI
- [ ] Add file upload with drag-and-drop
- [ ] Implement auto-save draft (every 30s)
- [ ] Add character counters and validation
- [ ] Integrate AI assistance modal
- [ ] Style with TailwindCSS
- [ ] Add responsive design
- [ ] Write component tests

**Day 8-9: Moderation & Rating System**
- [ ] Create moderation queue component
- [ ] Build submission detail view for moderators
- [ ] Add approve/reject actions with TanStack DB mutations
- [ ] Create community rating component (5-star)
- [ ] Build "helpful" voting system
- [ ] Add badge system (Highly Rated, Verified Representative)
- [ ] Create email notification templates
- [ ] Test moderation workflow end-to-end

**Day 10: Integration & Polish**
- [ ] Integrate offender context display into case detail page
- [ ] Add ElectricSQL sync for all new tables
- [ ] Enable PostgreSQL logical replication
- [ ] Test real-time sync (submission → moderation → publication)
- [ ] Test offline mode (draft saving without internet)
- [ ] Add analytics (submission rate, approval rate)
- [ ] Performance optimization
- [ ] Documentation and user guides
- [ ] Sprint demo preparation

---

## 🧪 Testing Strategy

### Unit Tests
```elixir
# test/ehs_enforcement/ai/context_structuring_service_test.exs
defmodule EhsEnforcement.AI.ContextStructuringServiceTest do
  use EhsEnforcement.DataCase

  alias EhsEnforcement.AI.ContextStructuringService

  describe "assist_submission/1" do
    test "extracts structured data from free text" do
      text = """
      On January 15, we had an asbestos incident during renovation.
      The root cause was inadequate survey before work commenced.
      We immediately stopped work and engaged licensed contractor.
      We have now implemented mandatory surveys for all projects.
      """

      result = ContextStructuringService.assist_submission(text)

      assert result.structured_extraction.what_happened =~ "asbestos incident"
      assert result.structured_extraction.root_cause =~ "inadequate survey"
      assert length(result.timeline_suggestions) > 0
    end

    test "assesses compliance effectiveness correctly" do
      strong_text = "Comprehensive safety management system implemented with quarterly audits"
      weak_text = "We put up a sign"

      strong_result = ContextStructuringService.assist_submission(strong_text)
      weak_result = ContextStructuringService.assist_submission(weak_text)

      assert strong_result.compliance_effectiveness.rating == "strong"
      assert weak_result.compliance_effectiveness.rating == "weak"
    end
  end
end
```

### Integration Tests
```elixir
# test/ehs_enforcement/enforcement/offender_context_test.exs
defmodule EhsEnforcement.Enforcement.OffenderContextTest do
  use EhsEnforcement.DataCase

  alias EhsEnforcement.Enforcement

  describe "submission workflow" do
    setup do
      case = create_case_fixture()
      user = create_verified_offender_fixture()

      {:ok, case: case, user: user}
    end

    test "verified offender can submit context", %{case: case, user: user} do
      {:ok, context} = Enforcement.submit_offender_context(
        case.id,
        %{
          what_happened: "Incident description...",
          root_cause_analysis: "Root cause...",
          corrective_actions_taken: "Actions...",
          preventive_measures: "Prevention..."
        },
        actor: user
      )

      assert context.status == :pending_review
      assert context.submitted_by.id == user.id
    end

    test "unverified user cannot submit context", %{case: case} do
      unverified_user = create_unverified_user_fixture()

      assert {:error, %Ash.Error.Forbidden{}} = Enforcement.submit_offender_context(
        case.id,
        %{what_happened: "Test"},
        actor: unverified_user
      )
    end

    test "moderator can approve submission", %{case: case, user: user} do
      {:ok, context} = create_pending_context_fixture(case, user)
      moderator = create_moderator_fixture()

      {:ok, approved} = Enforcement.approve_offender_context(
        context.id,
        actor: moderator
      )

      assert approved.status == :approved
      assert approved.moderated_by == moderator.id
    end
  end
end
```

### E2E Tests
```typescript
// frontend/tests/e2e/offender-context.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Offender Context Submission', () => {
  test('complete submission workflow', async ({ page }) => {
    // Login as verified offender
    await page.goto('/login')
    await page.fill('input[name="email"]', 'offender@company.co.uk')
    await page.fill('input[name="password"]', 'password')
    await page.click('button[type="submit"]')

    // Navigate to case
    await page.goto('/cases/test-case-id')

    // Click "Share Your Perspective" button
    await page.click('button:has-text("Share Your Perspective")')

    // Fill multi-step form
    await page.fill('textarea[placeholder*="What happened"]',
      'On January 15, 2024, we experienced an asbestos incident...')
    await page.click('button:has-text("Next: Root Cause")')

    await page.fill('textarea[placeholder*="root cause"]',
      'The incident occurred because we did not conduct adequate survey...')
    await page.click('button:has-text("Next: Corrective Actions")')

    await page.fill('textarea[placeholder*="corrective actions"]',
      'We immediately stopped work and engaged licensed contractor...')
    await page.click('button:has-text("Next: Preventive Measures")')

    await page.fill('textarea[placeholder*="preventive measures"]',
      'We have implemented mandatory asbestos surveys for all projects...')
    await page.click('button:has-text("Review & Submit")')

    // Review and submit
    await page.check('input[type="checkbox"]')
    await page.click('button:has-text("Submit for Review")')

    // Check for success message
    await expect(page.locator('text=/submitted for review/i')).toBeVisible()
  })

  test('AI assistance works correctly', async ({ page }) => {
    await page.goto('/cases/test-case-id/submit-context')

    await page.fill('textarea[placeholder*="What happened"]',
      'We had asbestos problem on roof job. Didnt do survey. Got fined.')

    await page.click('button:has-text("Get AI Assistance")')

    // Wait for AI suggestions
    await expect(page.locator('[data-testid="ai-suggestions"]')).toBeVisible()

    // Apply suggestions
    await page.click('button:has-text("Apply Suggestions")')

    // Check that textarea is updated with structured content
    const textareaValue = await page.inputValue('textarea')
    expect(textareaValue.length).toBeGreaterThan(100)
  })
})
```

---

## 📊 Success Metrics

### Engagement Metrics
- [ ] 10%+ of offenders submit context within 6 months of case
- [ ] 80%+ submission approval rate (indicates good quality)
- [ ] Average 4.0+ star rating on approved submissions
- [ ] 50%+ of users find offender context "helpful"

### Quality Metrics
- [ ] AI structuring accepted by users 70%+ of the time
- [ ] <5% of approved content flagged as inaccurate by community
- [ ] Average moderation time <24 hours
- [ ] <3% three-strike violations (low spam/abuse)

### Business Metrics
- [ ] Offender context feature increases session time by 30%+
- [ ] 25%+ of professional users rate/comment on submissions
- [ ] Feature cited in 40%+ user feedback as "valuable"
- [ ] Premium tier conversions increase 15% (for expanded case studies)

---

## 🚧 Risks & Mitigations

### Risk 1: Defamation Liability
**Impact**: Critical - Legal exposure
**Probability**: Medium
**Mitigation**:
- AI pre-screening for defamatory language
- Mandatory moderator review before publication
- Clear T&Cs requiring factual accuracy
- "Report Inaccuracy" button for flagging
- Legal review of submission guidelines
- Platform moderator training on defamation law

### Risk 2: Low Offender Participation
**Impact**: High - Feature underutilized
**Probability**: Medium
**Mitigation**:
- Direct outreach to recent offenders
- Highlight reputation benefits ("demonstrate remediation")
- Partner with industry associations
- Showcase top-rated submissions
- Email campaigns to verified companies
- Incentive: "Verified Contributor" badge improves company image

### Risk 3: Gaming/Fake Submissions
**Impact**: Medium - Damages credibility
**Probability**: Low (due to verification)
**Mitigation**:
- Rigorous offender verification (Companies House, email domain)
- Community validation (ratings, helpful votes)
- Moderator oversight
- Three-strike system for abuse
- Audit trail of all submissions

---

## 🎓 Learning Objectives

By the end of this sprint:
1. **Multi-step Forms**: Build complex form workflows with auto-save
2. **Verification Systems**: Implement corporate identity verification
3. **Moderation Workflows**: Queue-based content review patterns
4. **Community Validation**: Rating and voting systems
5. **AI Content Structuring**: Using LLMs to help users create better content
6. **File Uploads**: Handle document attachments securely
7. **Real-time Collaboration**: Moderator actions sync to submitters instantly

---

## 📚 Resources

- [Companies House API Documentation](https://developer-specs.company-information.service.gov.uk/)
- [Content Moderation Best Practices](https://www.nngroup.com/articles/content-moderation/)
- [Online Safety Act 2023 Guidance](https://www.gov.uk/government/collections/online-safety-act)
- [UK Defamation Act 2013](https://www.legislation.gov.uk/ukpga/2013/26/contents)

---

**Sprint Owner**: [Name]
**Stakeholders**: Product Manager, Legal Counsel, Community Manager
**Sprint Start Date**: [Date]
**Sprint End Date**: [Date + 2 weeks]
