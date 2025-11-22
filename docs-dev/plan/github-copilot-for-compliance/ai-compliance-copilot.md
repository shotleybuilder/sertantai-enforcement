# Sprint: AI Compliance Co-Pilot (Chat Interface)

**Sprint Duration**: 3 weeks
**Team Size**: 3-4 developers (1 backend, 1 AI/ML, 1 frontend, 0.5 data engineer)
**Prerequisites**: Local-first stack operational, TanStack DB with case data, AI enrichment system

---

## 🎯 Sprint Goal

Build a ChatGPT-style AI assistant that runs on local enforcement data, enabling users to ask natural language questions, generate custom reports, draft risk assessments, and receive real-time insights - all powered by the local-first architecture for instant, privacy-preserving responses.

---

## 📋 User Stories

### Story 1: Local AI Query Engine
**As a** professional user
**I want** to ask questions about enforcement data in natural language
**So that** I can quickly find insights without complex database queries

**Acceptance Criteria**:
- [ ] Chat interface with message history
- [ ] AI understands queries like "average fine for asbestos in 2024"
- [ ] Queries run on local TanStack DB (sub-second response)
- [ ] Results include source case references
- [ ] Follow-up questions maintain context
- [ ] Works offline (uses local AI model or cached responses)
- [ ] Export conversation as markdown/PDF

**Story Points**: 13

---

### Story 2: Multi-Modal Query Support
**As a** user
**I want** to ask complex analytical questions across multiple dimensions
**So that** I can perform sophisticated analysis without SQL knowledge

**Acceptance Criteria**:
- [ ] Supports queries with filters (time, sector, geography, regulator)
- [ ] Handles aggregations (average, median, count, sum)
- [ ] Performs comparisons ("London vs Manchester enforcement")
- [ ] Generates trend analysis ("show asbestos cases over time")
- [ ] Creates benchmarks ("how does this compare to industry average")
- [ ] Validates query feasibility before execution
- [ ] Suggests related questions

**Story Points**: 13

---

### Story 3: Automated Report Generation
**As a** compliance officer
**I want** to generate custom reports via natural language prompts
**So that** I can quickly create stakeholder presentations

**Acceptance Criteria**:
- [ ] Prompt-based report generation ("create Q4 2024 enforcement summary")
- [ ] Report includes charts, tables, and narrative
- [ ] Customizable sections (executive summary, detailed analysis, recommendations)
- [ ] Export as PDF, Word, Excel
- [ ] Save report templates for reuse
- [ ] Schedule recurring reports (weekly, monthly)
- [ ] Report gallery with examples

**Story Points**: 13

---

### Story 4: Risk Assessment Draft Generation
**As a** consultant
**I want** AI to draft risk assessments based on enforcement history
**So that** I can accelerate client deliverables

**Acceptance Criteria**:
- [ ] Prompt: "draft risk assessment for asbestos removal in London"
- [ ] AI analyzes relevant cases and generates structured risk assessment
- [ ] Includes hazard identification, risk level, control measures
- [ ] Cites specific enforcement precedents
- [ ] Editable output (markdown/Word)
- [ ] Templates for different industries/hazards
- [ ] Disclaimer: "AI-generated, verify independently"

**Story Points**: 8

---

### Story 5: Custom Alert Creation
**As a** user
**I want** to create custom monitoring alerts via conversation
**So that** I can track emerging risks without manual setup

**Acceptance Criteria**:
- [ ] Natural language alert creation: "alert me when asbestos fines exceed £100k"
- [ ] AI translates to database query + threshold
- [ ] Preview alert matches before saving
- [ ] Email/push notifications when triggered
- [ ] Manage alerts via chat ("show my alerts", "delete alert #3")
- [ ] Alert history and performance stats
- [ ] Suggested alerts based on user profile

**Story Points**: 8

---

### Story 6: Local AI Model Integration (Optional)
**As a** privacy-conscious user
**I want** the option to use local AI models
**So that** my queries never leave my device

**Acceptance Criteria**:
- [ ] Support for local models (Ollama, llama.cpp)
- [ ] Model auto-download on first use
- [ ] Fallback to cloud API if local unavailable
- [ ] Settings to prefer local/cloud/hybrid
- [ ] Performance comparison (local vs cloud)
- [ ] Model size warnings (requires 8GB RAM)
- [ ] Offline mode fully functional with local model

**Story Points**: 13

---

## 🏗️ Technical Architecture

### Backend Components

#### 1. Chat Session Management
```elixir
defmodule EhsEnforcement.AI.ChatSession do
  use Ash.Resource,
    domain: EhsEnforcement.AI,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      default "New Conversation"
    end

    attribute :model_used, :string  # "gpt-4-turbo", "llama3.1:8b", etc.
    attribute :total_messages, :integer, default: 0
    attribute :last_message_at, :utc_datetime_usec

    timestamps()
  end

  relationships do
    belongs_to :user, EhsEnforcement.Accounts.User
    has_many :messages, EhsEnforcement.AI.ChatMessage
  end

  actions do
    defaults [:read, :destroy]

    create :start_session do
      accept [:title, :model_used]
      change relate_actor(:user)
    end

    update :update_metadata do
      accept [:title, :last_message_at, :total_messages]
    end
  end
end
```

#### 2. Chat Message Storage
```elixir
defmodule EhsEnforcement.AI.ChatMessage do
  use Ash.Resource,
    domain: EhsEnforcement.AI,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :role, :atom do
      constraints one_of: [:user, :assistant, :system]
      allow_nil?: false
    end

    attribute :content, :string, allow_nil?: false

    # Query metadata (for assistant messages)
    attribute :query_metadata, :map do
      description "SQL query, execution time, result count, etc."
    end

    # Source citations
    attribute :cited_cases, {:array, :string}

    # Feedback
    attribute :helpful_vote, :boolean
    attribute :flagged_inaccurate, :boolean

    timestamps()
  end

  relationships do
    belongs_to :session, EhsEnforcement.AI.ChatSession
  end

  actions do
    defaults [:read]

    create :add_message do
      accept [:role, :content, :query_metadata, :cited_cases]

      argument :session_id, :uuid, allow_nil?: false

      change EhsEnforcement.Changes.IncrementSessionMessageCount
      change set_attribute(:session_id, arg(:session_id))
    end

    update :provide_feedback do
      accept [:helpful_vote, :flagged_inaccurate]
    end
  end
end
```

#### 3. Query Translation Service
```elixir
defmodule EhsEnforcement.AI.QueryTranslationService do
  @moduledoc """
  Translates natural language queries to TanStack DB queries
  """

  def translate_query(user_query, context \\ %{}) do
    # Use LLM to understand intent and generate query
    prompt = build_query_translation_prompt(user_query, context)

    response = OpenAI.chat_completion(prompt, model: "gpt-4-turbo")

    parsed = parse_query_intent(response)

    %{
      intent: parsed.intent,  # "aggregate", "filter", "compare", "trend"
      query_plan: parsed.query_plan,  # Structured query instructions
      filters: parsed.filters,
      aggregations: parsed.aggregations,
      confidence: parsed.confidence
    }
  end

  defp build_query_translation_prompt(user_query, context) do
    """
    You are a query translation assistant for an enforcement database.

    Schema:
    - cases: id, case_reference, regulator_id, offence_result, offence_fine, offence_costs,
             offence_action_date, offence_breaches, sector, geography, organization_id
    - agencies: id, name, type (regulator, enforcer)
    - offenders: id, name, sector

    User query: "#{user_query}"

    Previous context: #{inspect(context)}

    Translate this to a structured query plan. Return JSON with:
    {
      "intent": "aggregate|filter|compare|trend",
      "query_plan": {
        "table": "cases",
        "filters": [{"field": "sector", "operator": "eq", "value": "construction"}],
        "aggregations": [{"function": "avg", "field": "offence_fine"}],
        "groupBy": ["sector"],
        "orderBy": [{"field": "offence_fine", "direction": "desc"}],
        "limit": 10
      },
      "confidence": 0.95
    }

    If the query is ambiguous, set confidence < 0.7 and suggest clarifications.
    """
  end

  defp parse_query_intent(response) do
    # Parse LLM JSON response
    Jason.decode!(response, keys: :atoms)
  end
end
```

#### 4. Local Query Executor
```elixir
defmodule EhsEnforcement.AI.LocalQueryExecutor do
  @moduledoc """
  Executes queries on local TanStack DB via frontend
  """

  # This module generates JavaScript query code for TanStack DB
  # The actual execution happens on the frontend for local-first performance

  def generate_tanstack_query(query_plan) do
    case query_plan.intent do
      :aggregate -> generate_aggregate_query(query_plan)
      :filter -> generate_filter_query(query_plan)
      :compare -> generate_compare_query(query_plan)
      :trend -> generate_trend_query(query_plan)
    end
  end

  defp generate_aggregate_query(plan) do
    """
    db.query((q) => {
      let query = q.#{plan.table}

      #{generate_filters(plan.filters)}

      #{generate_aggregations(plan.aggregations)}

      return query
    })
    """
  end

  defp generate_filter_query(plan) do
    """
    db.query((q) => {
      return q.#{plan.table}
        #{Enum.map_join(plan.filters, "\n        ", &filter_to_code/1)}
        #{order_by_to_code(plan.orderBy)}
        .limit(#{plan.limit || 10})
    })
    """
  end

  defp filter_to_code(%{field: field, operator: "eq", value: value}) do
    ".where('#{field}', '#{value}')"
  end

  defp filter_to_code(%{field: field, operator: "gt", value: value}) do
    ".where('#{field}', '>', #{value})"
  end

  # ... more operators
end
```

#### 5. Report Generation Service
```elixir
defmodule EhsEnforcement.AI.ReportGenerationService do
  @moduledoc """
  AI-powered report generation from enforcement data
  """

  def generate_report(prompt, data, format \\ :markdown) do
    # Build comprehensive prompt with data
    report_prompt = build_report_prompt(prompt, data)

    # Generate report sections via LLM
    sections = %{
      executive_summary: generate_section(report_prompt, :executive_summary),
      key_findings: generate_section(report_prompt, :key_findings),
      detailed_analysis: generate_section(report_prompt, :detailed_analysis),
      trends: generate_section(report_prompt, :trends),
      recommendations: generate_section(report_prompt, :recommendations)
    }

    # Format report
    case format do
      :markdown -> format_as_markdown(sections, data)
      :pdf -> generate_pdf(sections, data)
      :word -> generate_docx(sections, data)
    end
  end

  defp build_report_prompt(user_prompt, data) do
    """
    Generate a professional compliance report based on this request:

    #{user_prompt}

    Data summary:
    - Total cases: #{length(data.cases)}
    - Date range: #{data.date_range.start} to #{data.date_range.end}
    - Sectors covered: #{Enum.join(data.sectors, ", ")}
    - Total fines: £#{data.total_fines}

    Detailed data:
    #{format_data_for_prompt(data)}

    Create a comprehensive report with:
    1. Executive summary (3-5 sentences)
    2. Key findings (5-7 bullet points)
    3. Detailed analysis (3-4 paragraphs with data citations)
    4. Trends (identify 2-3 significant patterns)
    5. Recommendations (actionable advice for compliance professionals)

    Use professional language suitable for board-level presentation.
    Cite specific case references where relevant.
    """
  end

  defp generate_section(prompt, section_type) do
    section_prompt = """
    #{prompt}

    Generate only the #{section_type} section.
    Return as plain text, not JSON.
    """

    OpenAI.chat_completion(section_prompt, model: "gpt-4-turbo")
  end

  defp format_as_markdown(sections, data) do
    """
    # #{data.title}

    *Generated: #{DateTime.utc_now() |> Calendar.strftime("%B %d, %Y")}*

    ## Executive Summary

    #{sections.executive_summary}

    ## Key Findings

    #{sections.key_findings}

    ## Detailed Analysis

    #{sections.detailed_analysis}

    ## Trends

    #{sections.trends}

    ## Recommendations

    #{sections.recommendations}

    ---

    *This report was generated using AI analysis of #{length(data.cases)} enforcement cases.
    All data sourced from verified enforcement records. Verify independently before use.*
    """
  end

  defp generate_pdf(sections, data) do
    # Use Phoenix PDF library or external service
    # Convert markdown to PDF with charts/tables
  end
end
```

### Frontend Components

#### 1. Chat Interface
```svelte
<!-- frontend/src/routes/copilot/+page.svelte -->
<script lang="ts">
  import { db } from '$lib/db'
  import { currentUser } from '$lib/stores/auth'
  import { onMount } from 'svelte'
  import ChatMessage from '$lib/components/ChatMessage.svelte'
  import QueryResultDisplay from '$lib/components/QueryResultDisplay.svelte'

  let sessionId: string | null = null
  let messages: ChatMessage[] = []
  let userInput = ''
  let isProcessing = false
  let queryResult: any = null

  // Query current session messages
  $: if (sessionId) {
    messages = db.query((q) =>
      q.chat_messages
        .where('session_id', sessionId)
        .orderBy('created_at', 'asc')
    )
  }

  onMount(async () => {
    // Create new session or load last session
    sessionId = await createSession()
  })

  async function createSession() {
    const result = await db.mutate((m) =>
      m.chat_sessions.start_session({
        title: 'New Conversation',
        model_used: 'gpt-4-turbo',
        user_id: $currentUser.id
      })
    )
    return result.id
  }

  async function sendMessage() {
    if (!userInput.trim() || isProcessing) return

    const userMessage = userInput
    userInput = ''
    isProcessing = true

    // Add user message to chat
    await db.mutate((m) =>
      m.chat_messages.add_message({
        session_id: sessionId,
        role: 'user',
        content: userMessage
      })
    )

    try {
      // Send to AI service
      const response = await fetch('/api/ai/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          session_id: sessionId,
          message: userMessage,
          context: messages.slice(-5)  // Last 5 messages for context
        })
      })

      const data = await response.json()

      // Execute query locally if provided
      if (data.query_plan) {
        queryResult = await executeLocalQuery(data.query_plan)
        data.query_result = queryResult
      }

      // Add assistant response
      await db.mutate((m) =>
        m.chat_messages.add_message({
          session_id: sessionId,
          role: 'assistant',
          content: data.response,
          query_metadata: data.query_metadata,
          cited_cases: data.cited_cases
        })
      )
    } catch (error) {
      console.error('Chat error:', error)
      alert('Failed to process message. Please try again.')
    } finally {
      isProcessing = false
    }
  }

  async function executeLocalQuery(queryPlan: any) {
    // Execute query on local TanStack DB
    // This is the "magic" - queries run locally at sub-ms speed!

    const queryFn = new Function('db', `
      return db.query((q) => {
        ${queryPlan.code}
      })
    `)

    const result = queryFn(db)
    return result
  }

  function handleKeyPress(event: KeyboardEvent) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      sendMessage()
    }
  }
</script>

<div class="copilot-page h-screen flex flex-col">
  <!-- Header -->
  <header class="border-b p-4 flex justify-between items-center">
    <div>
      <h1 class="text-2xl font-bold">AI Compliance Co-Pilot</h1>
      <p class="text-sm text-gray-600">Ask questions, generate reports, analyze trends</p>
    </div>

    <button on:click={createSession} class="btn-secondary">
      + New Chat
    </button>
  </header>

  <!-- Chat Messages -->
  <div class="messages-container flex-1 overflow-y-auto p-4 space-y-4">
    {#if $messages.length === 0}
      <div class="welcome-screen text-center py-12">
        <h2 class="text-3xl font-bold mb-4">Welcome to AI Co-Pilot</h2>
        <p class="text-gray-600 mb-6">Ask me anything about enforcement data</p>

        <div class="example-queries grid grid-cols-2 gap-4 max-w-2xl mx-auto">
          <button on:click={() => userInput = 'What is the average fine for asbestos violations in 2024?'} class="example-btn">
            📊 "Average fine for asbestos in 2024?"
          </button>
          <button on:click={() => userInput = 'Compare HSE enforcement in London vs Manchester'} class="example-btn">
            🔍 "Compare London vs Manchester enforcement"
          </button>
          <button on:click={() => userInput = 'Draft a risk assessment for construction asbestos removal'} class="example-btn">
            📝 "Draft asbestos removal risk assessment"
          </button>
          <button on:click={() => userInput = 'Generate a Q4 2024 enforcement summary report'} class="example-btn">
            📄 "Generate Q4 2024 report"
          </button>
        </div>
      </div>
    {:else}
      {#each $messages as message}
        <ChatMessage {message} />

        {#if message.role === 'assistant' && message.query_metadata}
          <QueryResultDisplay
            result={message.query_metadata.result}
            metadata={message.query_metadata}
          />
        {/if}
      {/each}
    {/if}

    {#if isProcessing}
      <div class="processing-indicator">
        <div class="flex items-center gap-2">
          <div class="spinner"></div>
          <span>Thinking...</span>
        </div>
      </div>
    {/if}
  </div>

  <!-- Input Area -->
  <div class="input-area border-t p-4">
    <div class="input-wrapper flex gap-2">
      <textarea
        bind:value={userInput}
        on:keypress={handleKeyPress}
        placeholder="Ask a question... (e.g., 'What are the most common asbestos breaches?')"
        rows="2"
        class="flex-1"
        disabled={isProcessing}
      ></textarea>

      <button
        on:click={sendMessage}
        disabled={!userInput.trim() || isProcessing}
        class="btn-primary"
      >
        Send
      </button>
    </div>

    <div class="input-footer text-xs text-gray-500 mt-2 flex justify-between">
      <span>💡 Tip: Press Enter to send, Shift+Enter for new line</span>
      <span>🔒 Queries run locally on your device</span>
    </div>
  </div>
</div>
```

#### 2. Chat Message Component
```svelte
<!-- frontend/src/lib/components/ChatMessage.svelte -->
<script lang="ts">
  import { marked } from 'marked'
  import type { ChatMessage } from '$lib/types/chat'

  export let message: ChatMessage

  function formatTimestamp(timestamp: string) {
    return new Date(timestamp).toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit'
    })
  }
</script>

<div class="chat-message" class:user={message.role === 'user'} class:assistant={message.role === 'assistant'}>
  <div class="message-header">
    {#if message.role === 'user'}
      <div class="avatar">👤</div>
      <span class="font-semibold">You</span>
    {:else}
      <div class="avatar">🤖</div>
      <span class="font-semibold">AI Co-Pilot</span>
    {/if}
    <span class="timestamp text-xs text-gray-500 ml-auto">
      {formatTimestamp(message.created_at)}
    </span>
  </div>

  <div class="message-content">
    {#if message.role === 'user'}
      <p>{message.content}</p>
    {:else}
      <div class="prose">
        {@html marked(message.content)}
      </div>

      {#if message.cited_cases && message.cited_cases.length > 0}
        <div class="cited-cases mt-3">
          <p class="text-sm font-semibold text-gray-600 mb-1">📎 Sources:</p>
          <div class="flex flex-wrap gap-2">
            {#each message.cited_cases as caseId}
              <a href="/cases/{caseId}" class="badge badge-link" target="_blank">
                View Case
              </a>
            {/each}
          </div>
        </div>
      {/if}
    {/if}
  </div>

  {#if message.role === 'assistant'}
    <div class="message-actions mt-2 flex gap-2">
      <button class="action-btn" title="Helpful">
        👍
      </button>
      <button class="action-btn" title="Not helpful">
        👎
      </button>
      <button class="action-btn" title="Copy">
        📋 Copy
      </button>
      <button class="action-btn" title="Regenerate">
        🔄 Regenerate
      </button>
    </div>
  {/if}
</div>

<style>
  .chat-message {
    @apply border rounded-lg p-4;
  }

  .chat-message.user {
    @apply bg-blue-50 border-blue-200 ml-12;
  }

  .chat-message.assistant {
    @apply bg-white border-gray-200 mr-12;
  }

  .message-header {
    @apply flex items-center gap-2 mb-2;
  }

  .avatar {
    @apply w-8 h-8 rounded-full flex items-center justify-center text-lg;
  }

  .chat-message.user .avatar {
    @apply bg-blue-500 text-white;
  }

  .chat-message.assistant .avatar {
    @apply bg-gray-700 text-white;
  }

  .action-btn {
    @apply text-sm px-2 py-1 rounded hover:bg-gray-100 transition;
  }
</style>
```

#### 3. Query Result Display
```svelte
<!-- frontend/src/lib/components/QueryResultDisplay.svelte -->
<script lang="ts">
  import { Chart } from '$lib/components/charts'

  export let result: any[]
  export let metadata: any

  let viewMode: 'table' | 'chart' = 'table'

  function exportCSV() {
    // Convert result to CSV and download
    const csv = convertToCSV(result)
    downloadFile(csv, 'query-result.csv')
  }
</script>

<div class="query-result border rounded p-4 mt-3 bg-gray-50">
  <div class="result-header flex justify-between items-center mb-3">
    <div>
      <span class="text-sm font-semibold">Query Results</span>
      <span class="text-xs text-gray-500 ml-2">
        ({result.length} rows, {metadata.execution_time_ms}ms)
      </span>
    </div>

    <div class="view-controls flex gap-2">
      <button
        class:active={viewMode === 'table'}
        on:click={() => viewMode = 'table'}
        class="view-btn"
      >
        📊 Table
      </button>
      <button
        class:active={viewMode === 'chart'}
        on:click={() => viewMode = 'chart'}
        class="view-btn"
      >
        📈 Chart
      </button>
      <button on:click={exportCSV} class="view-btn">
        💾 Export CSV
      </button>
    </div>
  </div>

  {#if viewMode === 'table'}
    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b">
            {#each Object.keys(result[0] || {}) as key}
              <th class="text-left p-2">{key}</th>
            {/each}
          </tr>
        </thead>
        <tbody>
          {#each result.slice(0, 10) as row}
            <tr class="border-b hover:bg-white">
              {#each Object.values(row) as value}
                <td class="p-2">{value}</td>
              {/each}
            </tr>
          {/each}
        </tbody>
      </table>

      {#if result.length > 10}
        <p class="text-xs text-gray-500 mt-2">
          Showing first 10 of {result.length} rows
        </p>
      {/if}
    </div>
  {:else}
    <Chart data={result} type={metadata.suggested_chart_type || 'bar'} />
  {/if}
</div>
```

---

## 🔧 Implementation Tasks

### Week 1: Backend Query System

**Day 1-2: Database Schema**
- [ ] Create chat sessions and messages tables
- [ ] Define Ash resources
- [ ] Add indexes for performance
- [ ] Write resource tests

**Day 3-4: Query Translation Service**
- [ ] Build natural language → query translation
- [ ] Implement query plan generation
- [ ] Add confidence scoring
- [ ] Test with common query patterns

**Day 5: Local Query Executor**
- [ ] Generate TanStack DB query code
- [ ] Build filter/aggregate/compare helpers
- [ ] Test query execution performance

---

### Week 2: AI Features

**Day 6-7: Report Generation**
- [ ] Implement section generation
- [ ] Add markdown formatting
- [ ] Create PDF export
- [ ] Build report templates

**Day 8-9: Risk Assessment Generation**
- [ ] Build risk assessment prompts
- [ ] Create structured output format
- [ ] Add precedent citations
- [ ] Test accuracy

**Day 10: Alert System**
- [ ] Natural language alert creation
- [ ] Query translation for alerts
- [ ] Alert preview functionality

---

### Week 3: Frontend & Integration

**Day 11-13: Chat Interface**
- [ ] Build chat UI component
- [ ] Implement message streaming
- [ ] Add query result display
- [ ] Create example queries
- [ ] Style with TailwindCSS

**Day 14-15: Local AI Integration (Optional)**
- [ ] Integrate Ollama/llama.cpp
- [ ] Add model download UI
- [ ] Implement hybrid mode (local + cloud)
- [ ] Performance testing

**Day 16-17: Testing & Polish**
- [ ] E2E tests for chat flow
- [ ] Performance optimization
- [ ] Accessibility audit
- [ ] Documentation
- [ ] Sprint demo

---

## 📊 Success Metrics

- [ ] 30%+ of users try AI co-pilot within first month
- [ ] Average 10+ messages per chat session
- [ ] 80%+ of queries execute in <1 second (local queries)
- [ ] 70%+ helpful vote rate on AI responses
- [ ] 50%+ of report exports used in actual work

---

**Sprint Owner**: [Name]
**Sprint Duration**: 3 weeks
