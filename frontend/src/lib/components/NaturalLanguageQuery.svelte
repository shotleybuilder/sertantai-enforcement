<script lang="ts">
  import { createMutation } from '@tanstack/svelte-query'

  // Props
  export let onQuerySuccess: (filters: any[], sort: any | null, columns?: string[], columnOrder?: string[]) => void
  export let placeholder = "Ask a question in plain English..."

  // State
  let query = ''
  let showExample = true

  // Example queries
  const examples = [
    "Show me HSE cases with fines over £50,000",
    "Find SEPA notices from 2024",
    "Cases with fines between £10,000 and £100,000",
    "Show me prosecutions from last year",
  ]

  // Natural language query mutation
  const nlQueryMutation = createMutation({
    mutationFn: async (userQuery: string) => {
      console.log('[NL Query] Mutation started for:', userQuery)
      const response = await fetch('http://localhost:4002/api/nl-query', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ query: userQuery }),
      })

      console.log('[NL Query] Response status:', response.status)

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to translate query')
      }

      return response.json()
    },
    onSuccess: (data) => {
      console.log('[NL Query] Translation successful:', data)
      onQuerySuccess(
        data.filters || [],
        data.sort || null,
        data.columns || [],
        data.columnOrder || []
      )
      showExample = false
    },
    onError: (error: any) => {
      console.error('[NL Query] Translation failed:', error)
    },
  })

  // Handle form submission
  function handleSubmit(event: Event) {
    event.preventDefault()
    if (!query.trim()) {
      console.log('[NL Query] Empty query, not submitting')
      return
    }

    console.log('[NL Query] Form submitted, query:', query)
    console.log('[NL Query] Calling mutation...')
    $nlQueryMutation.mutate(query)
  }

  // Handle example click
  function useExample(example: string) {
    console.log('[NL Query] Example clicked:', example)
    query = example
    // Directly call mutate instead of triggering form submit
    if (query.trim()) {
      console.log('[NL Query] Calling mutation for example...')
      $nlQueryMutation.mutate(query)
      showExample = false
    }
  }

  // Clear query
  function clearQuery() {
    query = ''
    showExample = true
    onQuerySuccess([], null, [], [])
  }
</script>

<div class="bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-200 rounded-lg p-6 mb-6">
  <div class="mb-4">
    <div class="flex items-center gap-2 mb-2">
      <svg
        class="w-6 h-6 text-blue-600"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z"
        ></path>
      </svg>
      <h2 class="text-lg font-semibold text-gray-900">Ask in Plain English</h2>
    </div>
    <p class="text-sm text-gray-600">
      Describe what you're looking for and we'll filter the data for you using AI
    </p>
  </div>

  <form on:submit={handleSubmit}>
    <div class="relative">
      <input
        type="text"
        bind:value={query}
        {placeholder}
        disabled={$nlQueryMutation.isPending}
        class="w-full px-4 py-3 pr-24 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-100 disabled:cursor-not-allowed text-base"
      />
      <div class="absolute right-2 top-1/2 -translate-y-1/2 flex items-center gap-2">
        {#if query}
          <button
            type="button"
            on:click={clearQuery}
            disabled={$nlQueryMutation.isPending}
            class="text-gray-400 hover:text-gray-600 p-1"
            title="Clear"
          >
            <svg
              class="w-5 h-5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12"
              ></path>
            </svg>
          </button>
        {/if}
        <button
          type="submit"
          disabled={!query.trim() || $nlQueryMutation.isPending}
          class="px-4 py-2 bg-blue-600 text-white rounded-md font-medium hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
        >
          {#if $nlQueryMutation.isPending}
            <div class="flex items-center gap-2">
              <div
                class="inline-block animate-spin rounded-full h-4 w-4 border-b-2 border-white"
              ></div>
              <span>Thinking...</span>
            </div>
          {:else}
            Search
          {/if}
        </button>
      </div>
    </div>
  </form>

  <!-- Examples -->
  {#if showExample && !$nlQueryMutation.isPending}
    <div class="mt-4">
      <p class="text-xs text-gray-500 mb-2">Try an example:</p>
      <div class="flex flex-wrap gap-2">
        {#each examples as example}
          <button
            type="button"
            on:click={() => useExample(example)}
            class="text-xs px-3 py-1.5 bg-white border border-gray-300 rounded-full text-gray-700 hover:bg-gray-50 hover:border-blue-300 transition-colors"
          >
            {example}
          </button>
        {/each}
      </div>
    </div>
  {/if}

  <!-- Success State -->
  {#if $nlQueryMutation.isSuccess && $nlQueryMutation.data}
    <div class="mt-4 p-3 bg-green-50 border border-green-200 rounded-md">
      <div class="flex items-start gap-2">
        <svg
          class="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
          ></path>
        </svg>
        <div class="flex-1">
          <p class="text-sm font-medium text-green-900">Query understood!</p>
          <p class="text-xs text-green-700 mt-1">
            Applied {$nlQueryMutation.data.filters?.length || 0} filter{$nlQueryMutation.data
              .filters?.length !== 1
              ? 's'
              : ''}
            {#if $nlQueryMutation.data.sort}
              , sorted by {$nlQueryMutation.data.sort.columnId}
            {/if}
            {#if $nlQueryMutation.data.columns && $nlQueryMutation.data.columns.length > 0}
              , showing {$nlQueryMutation.data.columns.length} column{$nlQueryMutation.data.columns.length !== 1 ? 's' : ''}
            {/if}
          </p>
        </div>
      </div>
    </div>
  {/if}

  <!-- Error State -->
  {#if $nlQueryMutation.isError}
    <div class="mt-4 p-3 bg-red-50 border border-red-200 rounded-md">
      <div class="flex items-start gap-2">
        <svg
          class="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
          ></path>
        </svg>
        <div class="flex-1">
          <p class="text-sm font-medium text-red-900">Couldn't understand that query</p>
          <p class="text-xs text-red-700 mt-1">
            {$nlQueryMutation.error?.message || 'Please try rephrasing or use the manual filters below'}
          </p>
        </div>
      </div>
    </div>
  {/if}
</div>
