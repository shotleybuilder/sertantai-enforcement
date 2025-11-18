<script lang="ts">
  import type { RecordProcessedEvent, ErrorEvent } from '$lib/types/scraping'

  export let records: RecordProcessedEvent[] = []
  export let errors: ErrorEvent[] = []
  export let maxRecords = 10

  // Tab state
  type TabType = 'records' | 'errors'
  let activeTab: TabType = 'records'

  // Keep only recent records (newest first)
  $: recentRecords = records.slice(-maxRecords).reverse()
  $: recentErrors = errors.slice(-maxRecords).reverse()

  function switchTab(tab: TabType) {
    activeTab = tab
  }
</script>

<div class="bg-white shadow rounded-lg overflow-hidden">
  <!-- Tabs -->
  <div class="border-b border-gray-200">
    <nav class="-mb-px flex">
      <button
        on:click={() => switchTab('records')}
        class="w-1/2 py-4 px-1 text-center border-b-2 font-medium text-sm transition-colors {activeTab ===
        'records'
          ? 'border-blue-500 text-blue-600'
          : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
      >
        Recent Records ({recentRecords.length})
      </button>
      <button
        on:click={() => switchTab('errors')}
        class="w-1/2 py-4 px-1 text-center border-b-2 font-medium text-sm transition-colors {activeTab ===
        'errors'
          ? 'border-red-500 text-red-600'
          : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
      >
        Errors ({recentErrors.length})
      </button>
    </nav>
  </div>

  <!-- Panel Content -->
  <div class="p-4 max-h-96 overflow-y-auto">
    {#if activeTab === 'records'}
      <!-- Recent Records Panel -->
      {#if recentRecords.length === 0}
        <div class="text-center py-8 text-gray-500 text-sm">
          <svg
            class="mx-auto h-12 w-12 text-gray-400 mb-2"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
            />
          </svg>
          No records processed yet
        </div>
      {:else}
        <div class="space-y-2">
          {#each recentRecords as record (record.regulator_id)}
            <div
              class="flex items-start space-x-3 p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
            >
              <!-- Icon -->
              <div class="flex-shrink-0 mt-1">
                <svg
                  class="h-5 w-5 text-green-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              </div>

              <!-- Content -->
              <div class="flex-1 min-w-0">
                <div class="flex items-start justify-between">
                  <div class="flex-1">
                    <p class="text-sm font-medium text-gray-900 truncate">
                      {record.offender_name || 'Unknown Offender'}
                    </p>
                    <p class="text-xs text-gray-500 mt-1">
                      {record.notice_type || 'Notice'}
                    </p>
                  </div>
                  <span class="text-xs font-mono text-gray-400 ml-2">
                    #{record.regulator_id.slice(0, 8)}
                  </span>
                </div>
              </div>
            </div>
          {/each}
        </div>
      {/if}
    {:else if activeTab === 'errors'}
      <!-- Errors Panel -->
      {#if recentErrors.length === 0}
        <div class="text-center py-8 text-gray-500 text-sm">
          <svg
            class="mx-auto h-12 w-12 text-gray-400 mb-2"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          No errors encountered
        </div>
      {:else}
        <div class="space-y-2">
          {#each recentErrors as error, index (error.timestamp || index)}
            <div
              class="flex items-start space-x-3 p-3 bg-red-50 rounded-lg border border-red-100"
            >
              <!-- Error Icon -->
              <div class="flex-shrink-0 mt-1">
                <svg
                  class="h-5 w-5 text-red-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              </div>

              <!-- Error Content -->
              <div class="flex-1 min-w-0">
                <div class="flex items-start justify-between mb-2">
                  <p class="text-sm font-medium text-red-900">
                    {error.message}
                  </p>
                </div>

                <!-- Error Details -->
                <div class="flex flex-wrap gap-3 text-xs text-gray-600">
                  {#if error.regulator_id}
                    <span class="flex items-center">
                      <svg
                        class="h-3 w-3 mr-1 text-gray-400"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
                        />
                      </svg>
                      ID: {error.regulator_id.slice(0, 12)}...
                    </span>
                  {/if}

                  {#if error.page}
                    <span class="flex items-center">
                      <svg
                        class="h-3 w-3 mr-1 text-gray-400"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                        />
                      </svg>
                      Page: {error.page}
                    </span>
                  {/if}

                  {#if error.timestamp}
                    <span class="flex items-center">
                      <svg
                        class="h-3 w-3 mr-1 text-gray-400"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                        />
                      </svg>
                      {new Date(error.timestamp).toLocaleTimeString()}
                    </span>
                  {/if}
                </div>
              </div>
            </div>
          {/each}
        </div>
      {/if}
    {/if}
  </div>
</div>
