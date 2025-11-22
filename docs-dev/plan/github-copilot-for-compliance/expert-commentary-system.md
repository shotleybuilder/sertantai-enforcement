# Sprint: Validated Expert Commentary System

**Sprint Duration**: 2 weeks
**Team Size**: 2-3 developers (1 backend, 1 frontend, 0.5 AI/ML)
**Prerequisites**: Full auth with SRA/FCA validation, reputation system, ElectricSQL sync

---

## 🎯 Sprint Goal

Build a Stack Overflow-style expert commentary platform where verified legal and compliance professionals can share analysis, precedents, and lessons learned on enforcement cases - creating a collaborative knowledge base validated by the professional community.

---

## 📋 User Stories

### Story 1: Commentary Creation (Markdown Editor)
**As a** verified professional
**I want** to write detailed analysis on enforcement cases
**So that** I can share expertise and build professional reputation

**Acceptance Criteria**:
- [ ] Rich markdown editor with formatting toolbar
- [ ] Preview mode before publishing
- [ ] Commentary types: legal_analysis, lessons_learned, precedent_link, risk_assessment
- [ ] Auto-save draft every 30 seconds (works offline)
- [ ] Minimum 100 characters, maximum 10,000 characters
- [ ] AI assistance for citation checking and summary generation
- [ ] Link to related cases automatically
- [ ] Tag system for categorization

**Story Points**: 8

---

### Story 2: AI Enhancement of Commentary
**As a** professional writing commentary
**I want** AI to help me structure and enhance my analysis
**So that** my contributions are more valuable and discoverable

**Acceptance Criteria**:
- [ ] AI generates TL;DR summary (3-5 sentences)
- [ ] AI extracts key points automatically
- [ ] AI validates regulation citations (checks Act/Section format)
- [ ] AI suggests related cases based on content
- [ ] Confidence scores for AI suggestions
- [ ] User can accept/edit/reject AI enhancements
- [ ] AI processing completes in <5 seconds

**Story Points**: 5

---

### Story 3: Community Voting System
**As a** verified professional
**I want** to upvote/downvote commentary based on quality
**So that** the most valuable insights rise to the top

**Acceptance Criteria**:
- [ ] Upvote/downvote buttons on each commentary
- [ ] Net vote score displayed prominently
- [ ] Vote history tracked per user
- [ ] Cannot vote on own commentary
- [ ] Can change vote (upvote → downvote)
- [ ] Voting triggers reputation point changes
- [ ] Real-time vote count updates (ElectricSQL)
- [ ] Voting restricted to verified professionals

**Story Points**: 5

---

### Story 4: Professional Endorsements
**As a** senior professional
**I want** to formally endorse high-quality commentary
**So that** I can highlight exceptional contributions

**Acceptance Criteria**:
- [ ] "Endorse" button with optional comment
- [ ] Endorser credentials displayed (SRA number, firm)
- [ ] Endorsement notifications sent to author
- [ ] Endorsements weighted by endorser reputation
- [ ] Limited to 5 endorsements per user per month
- [ ] "Endorsed by X professionals" badge
- [ ] Endorsement leaderboard for authors

**Story Points**: 5

---

### Story 5: Reputation System
**As a** professional contributor
**I want** to earn reputation points for helpful contributions
**So that** I can build credibility and unlock privileges

**Acceptance Criteria**:
- [ ] Reputation points awarded for:
  - Commentary upvotes: +10 points
  - Endorsements received: +50 points
  - "Helpful" flags: +5 points
  - Commentary accepted by experts: +25 points
- [ ] Reputation points deducted for:
  - Commentary downvotes: -2 points
  - Flagged as inaccurate: -25 points
- [ ] Reputation tiers unlock privileges:
  - 0-100: Can comment
  - 100-500: Can edit own commentary
  - 500-1000: Can endorse others
  - 1000+: Expert badge, featured profile
- [ ] Public reputation leaderboard
- [ ] Reputation history and breakdown

**Story Points**: 8

---

### Story 6: Commentary Display & Discovery
**As a** user viewing a case
**I want** to see relevant expert commentary sorted by quality
**So that** I can quickly find the most valuable insights

**Acceptance Criteria**:
- [ ] Commentary section on case detail page
- [ ] Sort options: votes, recent, endorsed
- [ ] Author credentials displayed prominently
- [ ] Expand/collapse long commentary
- [ ] Related cases linked at bottom
- [ ] "Helpful" button for quick feedback
- [ ] Report inaccuracy option
- [ ] Pagination or infinite scroll for many comments

**Story Points**: 5

---

## 🏗️ Technical Architecture

### Backend Components

#### 1. Database Schema
```elixir
defmodule EhsEnforcement.Enforcement.ExpertCommentary do
  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :commentary_type, :atom do
      constraints one_of: [:legal_analysis, :lessons_learned, :precedent_link, :risk_assessment]
      allow_nil?: false
    end

    attribute :title, :string do
      constraints max_length: 200
      allow_nil?: false
    end

    attribute :content, :string do
      constraints min_length: 100, max_length: 10000
      allow_nil?: false
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :published, :flagged, :removed]
      default :draft
    end

    # AI enhancements
    attribute :ai_summary, :string
    attribute :ai_key_points, {:array, :string}
    attribute :ai_related_cases, {:array, :string}
    attribute :ai_regulation_citations, {:array, :string}

    # Engagement metrics
    attribute :upvotes, :integer, default: 0
    attribute :downvotes, :integer, default: 0
    attribute :helpful_flags, :integer, default: 0
    attribute :view_count, :integer, default: 0

    # Metadata
    attribute :edited_at, :utc_datetime_usec
    attribute :edit_count, :integer, default: 0

    timestamps()
  end

  relationships do
    belongs_to :case, EhsEnforcement.Enforcement.Case
    belongs_to :author, EhsEnforcement.Accounts.User

    has_many :votes, EhsEnforcement.Enforcement.CommentaryVote
    has_many :endorsements, EhsEnforcement.Enforcement.CommentaryEndorsement
    has_many :tags, EhsEnforcement.Enforcement.CommentaryTag
  end

  actions do
    defaults [:read]

    create :publish do
      accept [:commentary_type, :title, :content, :case_id]

      argument :case_id, :uuid, allow_nil?: false

      change relate_actor(:author)
      change set_attribute(:status, :published)
      change EhsEnforcement.Changes.EnhanceWithAI
      change EhsEnforcement.Changes.AwardReputationPoints
    end

    update :save_draft do
      accept [:commentary_type, :title, :content]
    end

    update :edit do
      accept [:title, :content]

      change set_attribute(:edited_at, &DateTime.utc_now/0)
      change increment_edit_count()
      change EhsEnforcement.Changes.UpdateAIEnhancements
    end

    update :flag_inaccurate do
      argument :reason, :string, allow_nil?: false

      change set_attribute(:status, :flagged)
      change EhsEnforcement.Changes.NotifyModerators
    end

    destroy :remove do
      change EhsEnforcement.Changes.DeductReputationPoints
    end
  end

  calculations do
    calculate :net_votes, :integer do
      expr(upvotes - downvotes)
    end

    calculate :is_highly_rated, :boolean do
      expr(net_votes >= 10 and helpful_flags >= 5)
    end
  end

  policies do
    # Only verified professionals can create
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:professional_tier, :professional)
      authorize_if actor_attribute_equals(:professional_tier, :expert)
    end

    # Anyone can read published commentary
    policy action_type(:read) do
      authorize_if expr(status == :published)
    end

    # Only author can edit (within reputation limits)
    policy action_type(:update) do
      authorize_if expr(author_id == ^actor(:id))
      authorize_if ReputationCheck.can_edit?(actor)
    end
  end
end
```

#### 2. Voting System
```elixir
defmodule EhsEnforcement.Enforcement.CommentaryVote do
  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :vote_type, :atom do
      constraints one_of: [:upvote, :downvote]
      allow_nil?: false
    end

    timestamps()
  end

  relationships do
    belongs_to :commentary, EhsEnforcement.Enforcement.ExpertCommentary
    belongs_to :voter, EhsEnforcement.Accounts.User
  end

  actions do
    create :cast_vote do
      accept [:vote_type]

      argument :commentary_id, :uuid, allow_nil?: false

      change relate_actor(:voter)
      change EhsEnforcement.Changes.UpdateCommentaryVoteCount
      change EhsEnforcement.Changes.AwardAuthorReputation
    end

    update :change_vote do
      accept [:vote_type]

      change EhsEnforcement.Changes.UpdateCommentaryVoteCount
      change EhsEnforcement.Changes.AdjustAuthorReputation
    end

    destroy :remove_vote do
      change EhsEnforcement.Changes.UpdateCommentaryVoteCount
      change EhsEnforcement.Changes.DeductAuthorReputation
    end
  end

  identities do
    identity :unique_vote_per_user, [:commentary_id, :voter_id]
  end

  policies do
    # Cannot vote on own commentary
    policy action_type([:create, :update]) do
      forbid_if expr(commentary.author_id == ^actor(:id))
    end

    # Only verified professionals can vote
    policy action_type([:create, :update]) do
      authorize_if actor_attribute_equals(:professional_tier, :professional)
      authorize_if actor_attribute_equals(:professional_tier, :expert)
    end
  end
end
```

#### 3. Reputation System
```elixir
defmodule EhsEnforcement.Accounts.Reputation do
  use Ash.Resource,
    domain: EhsEnforcement.Accounts,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :points, :integer, default: 0

    attribute :earned_from_upvotes, :integer, default: 0
    attribute :earned_from_endorsements, :integer, default: 0
    attribute :earned_from_helpful_flags, :integer, default: 0
    attribute :lost_from_downvotes, :integer, default: 0
    attribute :lost_from_flags, :integer, default: 0

    timestamps()
  end

  relationships do
    belongs_to :user, EhsEnforcement.Accounts.User

    has_many :transactions, EhsEnforcement.Accounts.ReputationTransaction
  end

  actions do
    defaults [:read]

    create :initialize do
      accept []
      change set_attribute(:points, 0)
    end

    update :award_points do
      accept []

      argument :amount, :integer, allow_nil?: false
      argument :reason, :string, allow_nil?: false
      argument :source_type, :string, allow_nil?: false

      change fn changeset, context ->
        amount = Ash.Changeset.get_argument(changeset, :amount)
        current_points = Ash.Changeset.get_attribute(changeset, :points)

        changeset
        |> Ash.Changeset.change_attribute(:points, current_points + amount)
        |> record_transaction(context)
      end
    end

    update :deduct_points do
      accept []

      argument :amount, :integer, allow_nil?: false
      argument :reason, :string, allow_nil?: false

      change fn changeset, context ->
        amount = Ash.Changeset.get_argument(changeset, :amount)
        current_points = Ash.Changeset.get_attribute(changeset, :points)

        new_points = max(0, current_points - amount)

        changeset
        |> Ash.Changeset.change_attribute(:points, new_points)
        |> record_transaction(context)
      end
    end
  end

  calculations do
    calculate :tier, :atom do
      expr(
        cond do
          points >= 1000 -> :expert
          points >= 500 -> :senior
          points >= 100 -> :established
          true -> :newcomer
        end
      )
    end

    calculate :can_endorse, :boolean do
      expr(points >= 500)
    end

    calculate :can_edit_others, :boolean do
      expr(points >= 1000)
    end
  end
end
```

#### 4. AI Enhancement Service
```elixir
defmodule EhsEnforcement.AI.CommentaryEnhancementService do
  @moduledoc """
  AI service for enhancing expert commentary with summaries and insights
  """

  def enhance_commentary(commentary) do
    %{
      ai_summary: generate_summary(commentary.content),
      ai_key_points: extract_key_points(commentary.content),
      ai_related_cases: find_related_cases(commentary.content),
      ai_regulation_citations: validate_citations(commentary.content)
    }
  end

  defp generate_summary(content) do
    prompt = """
    Generate a concise 3-5 sentence summary of this legal commentary:

    #{content}

    Focus on the main argument and key takeaways.
    """

    OpenAI.chat_completion(prompt, model: "gpt-4-turbo")
    |> extract_text_response()
  end

  defp extract_key_points(content) do
    prompt = """
    Extract 3-5 key points from this commentary:

    #{content}

    Return as JSON array of strings.
    """

    OpenAI.chat_completion(prompt, model: "gpt-4-turbo")
    |> parse_json_response()
  end

  defp validate_citations(content) do
    # Extract regulation references (e.g., "HSWA 1974 s2(1)")
    regex = ~r/([A-Z]{2,})\s+(\d{4})\s+[sS]?\.?(\d+)/

    Regex.scan(regex, content)
    |> Enum.map(fn [full, act, year, section] ->
      %{
        citation: full,
        act: act,
        year: year,
        section: section,
        validated: check_regulation_exists(act, year, section)
      }
    end)
  end

  defp find_related_cases(content) do
    # Use semantic search to find similar cases
    embedding = generate_embedding(content)

    EhsEnforcement.Enforcement.Case
    |> semantic_search(embedding, limit: 5)
    |> Enum.map(& &1.id)
  end
end
```

### Frontend Components

#### 1. Commentary Editor
```svelte
<!-- frontend/src/lib/components/CommentaryEditor.svelte -->
<script lang="ts">
  import { db } from '$lib/db'
  import { currentUser } from '$lib/stores/auth'
  import { marked } from 'marked'
  import MarkdownToolbar from './MarkdownToolbar.svelte'

  export let caseId: string

  let mode: 'write' | 'preview' = 'write'
  let formData = {
    commentary_type: 'legal_analysis',
    title: '',
    content: ''
  }

  let draftId: string | null = null
  let showAIAssistance = false
  let aiSuggestions = null

  // Auto-save draft every 30 seconds
  $: if (formData.content) {
    debounce(saveDraft, 30000)
  }

  async function saveDraft() {
    if (!draftId) {
      const result = await db.mutate((m) =>
        m.expert_commentaries.create({
          case_id: caseId,
          ...formData,
          status: 'draft',
          author_id: $currentUser.id
        })
      )
      draftId = result.id
    } else {
      await db.mutate((m) =>
        m.expert_commentaries.save_draft(draftId, formData)
      )
    }
  }

  async function publish() {
    try {
      await db.mutate((m) =>
        m.expert_commentaries.publish({
          case_id: caseId,
          ...formData,
          author_id: $currentUser.id
        })
      )

      // Navigate back to case page
      goto(`/cases/${caseId}#commentary`)
    } catch (error) {
      console.error('Publish failed:', error)
      alert('Failed to publish commentary. Please try again.')
    }
  }

  async function requestAIEnhancement() {
    showAIAssistance = true

    const response = await fetch('/api/ai/enhance-commentary', {
      method: 'POST',
      body: JSON.stringify({ content: formData.content })
    })

    aiSuggestions = await response.json()
  }

  function applySuggestions() {
    // AI generates summary and key points
    // User decides whether to include them
    formData.content += `\n\n## Summary\n${aiSuggestions.summary}\n\n`
    formData.content += `## Key Points\n${aiSuggestions.key_points.map(p => `- ${p}`).join('\n')}`
  }
</script>

<div class="commentary-editor max-w-4xl mx-auto">
  <h2>Share Your Expert Analysis</h2>

  <!-- Commentary Type -->
  <div class="form-group">
    <label>Commentary Type</label>
    <select bind:value={formData.commentary_type}>
      <option value="legal_analysis">Legal Analysis</option>
      <option value="lessons_learned">Lessons Learned</option>
      <option value="precedent_link">Precedent Link</option>
      <option value="risk_assessment">Risk Assessment</option>
    </select>
  </div>

  <!-- Title -->
  <div class="form-group">
    <label>Title</label>
    <input
      type="text"
      bind:value={formData.title}
      placeholder="Summarize your commentary in one sentence"
      maxlength="200"
    />
    <div class="char-count">{formData.title.length} / 200</div>
  </div>

  <!-- Content Editor -->
  <div class="form-group">
    <div class="editor-tabs">
      <button
        class:active={mode === 'write'}
        on:click={() => mode = 'write'}
      >
        Write
      </button>
      <button
        class:active={mode === 'preview'}
        on:click={() => mode = 'preview'}
      >
        Preview
      </button>
    </div>

    {#if mode === 'write'}
      <MarkdownToolbar on:insert={insertMarkdown} />
      <textarea
        bind:value={formData.content}
        placeholder="Write your analysis using Markdown..."
        rows="20"
        class="font-mono"
      ></textarea>
      <div class="char-count">{formData.content.length} / 10,000</div>
    {:else}
      <div class="preview prose">
        {@html marked(formData.content)}
      </div>
    {/if}
  </div>

  <!-- AI Assistance -->
  <div class="ai-section">
    <button on:click={requestAIEnhancement} class="btn-secondary">
      🤖 Get AI Assistance
    </button>

    {#if aiSuggestions}
      <div class="ai-suggestions border rounded p-4 mt-4">
        <h4>AI Suggestions</h4>

        <div class="suggestion">
          <h5>Summary</h5>
          <p>{aiSuggestions.summary}</p>
        </div>

        <div class="suggestion">
          <h5>Key Points</h5>
          <ul>
            {#each aiSuggestions.key_points as point}
              <li>{point}</li>
            {/each}
          </ul>
        </div>

        <div class="suggestion">
          <h5>Related Cases</h5>
          {#each aiSuggestions.related_cases as caseId}
            <a href="/cases/{caseId}">View Case</a>
          {/each}
        </div>

        <div class="suggestion">
          <h5>Citations Validated</h5>
          {#each aiSuggestions.regulation_citations as citation}
            <span class="badge" class:validated={citation.validated}>
              {citation.citation}
              {citation.validated ? '✓' : '✗'}
            </span>
          {/each}
        </div>

        <button on:click={applySuggestions} class="btn-primary mt-4">
          Apply Suggestions
        </button>
      </div>
    {/if}
  </div>

  <!-- Actions -->
  <div class="form-actions">
    <button on:click={() => goto(`/cases/${caseId}`)} class="btn-secondary">
      Cancel
    </button>
    <button on:click={saveDraft} class="btn-secondary">
      Save Draft
    </button>
    <button
      on:click={publish}
      disabled={formData.title.length < 10 || formData.content.length < 100}
      class="btn-primary"
    >
      Publish Commentary
    </button>
  </div>
</div>
```

#### 2. Commentary Display Component
```svelte
<!-- frontend/src/lib/components/CommentaryList.svelte -->
<script lang="ts">
  import { db } from '$lib/db'
  import { currentUser } from '$lib/stores/auth'
  import CommentaryCard from './CommentaryCard.svelte'

  export let caseId: string

  let sortBy: 'votes' | 'recent' | 'endorsed' = 'votes'

  // Query commentaries for this case
  $: commentaries = db.query((q) => {
    let query = q.expert_commentaries
      .where('case_id', caseId)
      .where('status', 'published')

    if (sortBy === 'votes') {
      query = query.orderBy('net_votes', 'desc')
    } else if (sortBy === 'recent') {
      query = query.orderBy('created_at', 'desc')
    } else if (sortBy === 'endorsed') {
      query = query.orderBy('endorsement_count', 'desc')
    }

    return query.limit(20)
  })

  async function voteCommentary(commentaryId: string, voteType: 'upvote' | 'downvote') {
    await db.mutate((m) =>
      m.commentary_votes.cast_vote({
        commentary_id: commentaryId,
        vote_type: voteType,
        voter_id: $currentUser.id
      })
    )
  }
</script>

<div class="commentary-section">
  <div class="section-header">
    <h3>Expert Commentary ({$commentaries?.length || 0})</h3>

    <a href="/cases/{caseId}/add-commentary" class="btn-primary">
      + Add Your Analysis
    </a>
  </div>

  <!-- Sort Controls -->
  <div class="sort-controls">
    <button
      class:active={sortBy === 'votes'}
      on:click={() => sortBy = 'votes'}
    >
      Most Helpful
    </button>
    <button
      class:active={sortBy === 'recent'}
      on:click={() => sortBy = 'recent'}
    >
      Recent
    </button>
    <button
      class:active={sortBy === 'endorsed'}
      on:click={() => sortBy = 'endorsed'}
    >
      Endorsed
    </button>
  </div>

  <!-- Commentary List -->
  <div class="commentary-list space-y-6">
    {#each $commentaries as commentary}
      <CommentaryCard
        {commentary}
        onVote={(type) => voteCommentary(commentary.id, type)}
        canVote={$currentUser?.professional_tier !== 'basic'}
      />
    {/each}

    {#if $commentaries?.length === 0}
      <div class="empty-state">
        <p>No commentary yet. Be the first to share your expert analysis!</p>
      </div>
    {/if}
  </div>
</div>
```

#### 3. Commentary Card Component
```svelte
<!-- frontend/src/lib/components/CommentaryCard.svelte -->
<script lang="ts">
  import { marked } from 'marked'
  import type { ExpertCommentary } from '$lib/types/commentary'

  export let commentary: ExpertCommentary
  export let onVote: (type: 'upvote' | 'downvote') => void
  export let canVote: boolean

  let expanded = false
  let showEndorseModal = false

  function getCommentaryTypeLabel(type: string) {
    const labels = {
      legal_analysis: 'Legal Analysis',
      lessons_learned: 'Lessons Learned',
      precedent_link: 'Precedent Link',
      risk_assessment: 'Risk Assessment'
    }
    return labels[type] || type
  }
</script>

<div class="commentary-card border rounded-lg p-6">
  <!-- Author Info -->
  <div class="author-info flex items-center gap-3 mb-4">
    <div class="avatar">
      {commentary.author.name.charAt(0)}
    </div>
    <div>
      <div class="flex items-center gap-2">
        <span class="font-semibold">{commentary.author.name}</span>
        {#if commentary.author.credentials?.sra_number}
          <span class="badge badge-verified">SRA Verified</span>
        {/if}
        {#if commentary.author.reputation?.tier === 'expert'}
          <span class="badge badge-expert">Expert</span>
        {/if}
      </div>
      <div class="text-sm text-gray-600">
        {commentary.author.company_name} • {commentary.author.reputation.points} reputation
      </div>
      <div class="text-xs text-gray-500">
        {new Date(commentary.created_at).toLocaleDateString()}
        {#if commentary.edited_at}
          • Edited {commentary.edit_count} times
        {/if}
      </div>
    </div>
  </div>

  <!-- Commentary Type Badge -->
  <div class="mb-2">
    <span class="badge">{getCommentaryTypeLabel(commentary.commentary_type)}</span>
  </div>

  <!-- Title -->
  <h4 class="text-lg font-semibold mb-3">{commentary.title}</h4>

  <!-- AI Summary (if available) -->
  {#if commentary.ai_summary}
    <div class="ai-summary bg-blue-50 border-l-4 border-blue-500 p-3 mb-4">
      <p class="text-sm"><strong>AI Summary:</strong> {commentary.ai_summary}</p>
    </div>
  {/if}

  <!-- Content (expandable) -->
  <div class="content prose">
    {#if !expanded && commentary.content.length > 500}
      <div>
        {@html marked(commentary.content.slice(0, 500))}...
      </div>
      <button on:click={() => expanded = true} class="text-blue-600 hover:underline">
        Read more
      </button>
    {:else}
      {@html marked(commentary.content)}
    {/if}
  </div>

  <!-- Key Points (if available) -->
  {#if commentary.ai_key_points?.length > 0}
    <div class="key-points mt-4">
      <h5 class="text-sm font-semibold mb-2">Key Points:</h5>
      <ul class="list-disc list-inside text-sm">
        {#each commentary.ai_key_points as point}
          <li>{point}</li>
        {/each}
      </ul>
    </div>
  {/if}

  <!-- Related Cases (if available) -->
  {#if commentary.ai_related_cases?.length > 0}
    <div class="related-cases mt-4">
      <h5 class="text-sm font-semibold mb-2">Related Cases:</h5>
      <div class="flex flex-wrap gap-2">
        {#each commentary.ai_related_cases as relatedId}
          <a href="/cases/{relatedId}" class="badge badge-link">
            View Case
          </a>
        {/each}
      </div>
    </div>
  {/if}

  <!-- Endorsements -->
  {#if commentary.endorsements?.length > 0}
    <div class="endorsements mt-4 bg-yellow-50 border border-yellow-200 rounded p-3">
      <p class="text-sm font-semibold mb-2">
        🏆 Endorsed by {commentary.endorsements.length} professional{commentary.endorsements.length > 1 ? 's' : ''}
      </p>
      {#each commentary.endorsements.slice(0, 3) as endorsement}
        <div class="text-xs text-gray-700">
          <strong>{endorsement.endorser.name}</strong>
          ({endorsement.endorser.company_name})
          {#if endorsement.comment}
            - "{endorsement.comment}"
          {/if}
        </div>
      {/each}
    </div>
  {/if}

  <!-- Actions -->
  <div class="actions mt-4 flex items-center gap-4">
    <!-- Voting -->
    {#if canVote}
      <div class="voting flex items-center gap-2">
        <button on:click={() => onVote('upvote')} class="vote-btn">
          ▲
        </button>
        <span class="vote-count font-semibold" class:positive={commentary.net_votes > 0}>
          {commentary.net_votes}
        </span>
        <button on:click={() => onVote('downvote')} class="vote-btn">
          ▼
        </button>
      </div>
    {/if}

    <!-- Helpful Button -->
    <button class="btn-sm">
      👍 Helpful ({commentary.helpful_flags})
    </button>

    <!-- Endorse Button (if eligible) -->
    {#if canEndorse}
      <button on:click={() => showEndorseModal = true} class="btn-sm">
        🏆 Endorse
      </button>
    {/if}

    <!-- Report -->
    <button class="btn-sm text-red-600">
      🚩 Report Inaccuracy
    </button>

    <!-- Share -->
    <button class="btn-sm">
      🔗 Share
    </button>
  </div>
</div>
```

---

## 🔧 Implementation Tasks

### Week 1: Backend & Reputation

**Day 1-2: Database Schema**
- [ ] Create migrations for all tables
- [ ] Define Ash resources with relationships
- [ ] Add policies for authorization
- [ ] Write resource tests

**Day 3-4: Reputation System**
- [ ] Implement reputation tracking
- [ ] Create reputation transaction log
- [ ] Build tier calculation logic
- [ ] Add reputation point awards/deductions
- [ ] Create leaderboard queries
- [ ] Test reputation calculations

**Day 5: Voting System**
- [ ] Implement vote creation/update/deletion
- [ ] Add vote count aggregation
- [ ] Build real-time vote sync
- [ ] Prevent self-voting
- [ ] Test vote integrity

---

### Week 2: Frontend & AI

**Day 6-8: Commentary Editor**
- [ ] Build markdown editor component
- [ ] Add formatting toolbar
- [ ] Implement preview mode
- [ ] Add auto-save functionality
- [ ] Create AI assistance modal
- [ ] Style with TailwindCSS
- [ ] Write component tests

**Day 9-10: Display & Engagement**
- [ ] Create commentary list component
- [ ] Build commentary card component
- [ ] Add voting UI
- [ ] Implement endorsement modal
- [ ] Add sorting and filtering
- [ ] Create reputation badges
- [ ] Test real-time updates
- [ ] Sprint demo

---

## 📊 Success Metrics

- [ ] 20%+ verified professionals contribute commentary
- [ ] Average 4.5+ net votes per commentary
- [ ] 30%+ of users view commentary section
- [ ] 10%+ endorsement rate on high-quality commentary

---

**Sprint Owner**: [Name]
**Sprint Duration**: 2 weeks
