<script lang="ts">
  import type { ScrapingProgress, ScrapingPhase } from '$lib/types/scraping'

  export let progress: ScrapingProgress

  const phaseLabels: Record<ScrapingPhase, string> = {
    idle: 'Idle',
    scraping_pages: 'Scraping Pages',
    filtering: 'Filtering Records',
    processing_records: 'Processing Records',
    saving: 'Saving to Database',
    completed: 'Completed',
    failed: 'Failed',
  }

  const phaseColors: Record<ScrapingPhase, string> = {
    idle: 'bg-gray-100 text-gray-800',
    scraping_pages: 'bg-blue-100 text-blue-800',
    filtering: 'bg-yellow-100 text-yellow-800',
    processing_records: 'bg-purple-100 text-purple-800',
    saving: 'bg-indigo-100 text-indigo-800',
    completed: 'bg-green-100 text-green-800',
    failed: 'bg-red-100 text-red-800',
  }

  $: isActive = !['idle', 'completed', 'failed'].includes(progress.phase)
</script>

<div class="bg-white shadow-sm rounded-lg border border-gray-200">
  <div class="px-4 py-3 border-b border-gray-200 flex items-center justify-between">
    <h2 class="text-base font-semibold text-gray-900">Scraping Progress</h2>
    <span
      class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {phaseColors[
        progress.phase
      ]}"
    >
      {#if isActive}
        <svg class="animate-spin -ml-0.5 mr-1.5 h-3 w-3" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
          <path
            class="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
          />
        </svg>
      {/if}
      {phaseLabels[progress.phase]}
    </span>
  </div>

  <div class="p-4">
    <!-- Phase 1: Scraping Pages -->
    {#if progress.phase === 'scraping_pages'}
      <div class="mb-4">
        <div class="flex justify-between text-sm mb-1.5">
          <span class="text-gray-600">Pages Scraped</span>
          <span class="font-medium text-gray-900">
            {progress.pagesScraped} / {progress.totalPages}
          </span>
        </div>
        <div class="w-full bg-gray-200 rounded-full h-1.5">
          <div
            class="bg-blue-600 h-1.5 rounded-full transition-all duration-300"
            style="width: {(progress.pagesScraped / progress.totalPages) * 100}%"
          />
        </div>
      </div>
    {/if}

    <!-- Phase 2: Filtering -->
    {#if progress.phase === 'filtering'}
      <div class="space-y-2 mb-4">
        <div class="flex justify-between text-sm">
          <span class="text-gray-600">Records Found</span>
          <span class="font-medium text-gray-900">{progress.recordsFound}</span>
        </div>
        <div class="flex justify-between text-sm">
          <span class="text-gray-600">Existing (Skip)</span>
          <span class="font-medium text-gray-500">{progress.recordsExisting}</span>
        </div>
        <div class="flex justify-between text-sm">
        <span class="text-gray-600">To Process</span>
        <span class="font-medium text-blue-600">{progress.recordsToProcess}</span>
      </div>
    </div>
  {/if}

    <!-- Phase 3: Processing Records -->
    {#if progress.phase === 'processing_records'}
      <div class="mb-4">
        <div class="flex justify-between text-sm mb-1.5">
          <span class="text-gray-600">Records Processed</span>
          <span class="font-medium text-gray-900">
            {progress.recordsProcessed} / {progress.recordsToProcess}
          </span>
        </div>
        <div class="w-full bg-gray-200 rounded-full h-1.5">
          <div
            class="bg-purple-600 h-1.5 rounded-full transition-all duration-300"
            style="width: {progress.recordsToProcess > 0 ? (progress.recordsProcessed / progress.recordsToProcess) * 100 : 0}%"
          />
        </div>
      </div>
    {/if}

    <!-- Summary Stats (Always Visible) -->
    <div class="grid grid-cols-4 gap-3">
      <div class="bg-gray-50 rounded-lg p-3">
        <div class="text-xs text-gray-600 mb-0.5">Created</div>
        <div class="text-xl font-bold text-green-600">{progress.recordsCreated}</div>
      </div>

      <div class="bg-gray-50 rounded-lg p-3">
        <div class="text-xs text-gray-600 mb-0.5">Updated</div>
        <div class="text-xl font-bold text-blue-600">{progress.recordsUpdated}</div>
      </div>

      <div class="bg-gray-50 rounded-lg p-3">
        <div class="text-xs text-gray-600 mb-0.5">Skipped</div>
        <div class="text-xl font-bold text-gray-500">{progress.recordsExisting}</div>
      </div>

      <div class="bg-gray-50 rounded-lg p-3">
        <div class="text-xs text-gray-600 mb-0.5">Errors</div>
        <div class="text-xl font-bold text-red-600">{progress.errorsCount}</div>
      </div>
    </div>
  </div>
</div>
