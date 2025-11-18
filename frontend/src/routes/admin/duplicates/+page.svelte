<script lang="ts">
  import { browser } from '$app/environment'
  import {
    useDuplicatesQuery,
    useDeleteDuplicatesMutation,
    type DuplicateType,
    type DuplicateRecord,
  } from '$lib/query/duplicates'

  // Active tab state
  let activeTab: DuplicateType = 'cases'

  // TanStack queries
  $: duplicatesQuery = browser ? useDuplicatesQuery(activeTab) : null
  const deleteMutation = browser ? useDeleteDuplicatesMutation() : null

  // Navigation and selection state
  let currentGroupIndex = 0
  let selectedRecords = new Set<string>()

  // Current duplicate groups and group
  $: duplicateGroups = $duplicatesQuery?.data || []
  $: currentGroup = duplicateGroups[currentGroupIndex] || []
  $: totalGroups = duplicateGroups.length

  // Reset selection and index when tab changes or data reloads
  $: if (activeTab || $duplicatesQuery?.data) {
    currentGroupIndex = 0
    selectedRecords = new Set()
  }

  // Switch tab
  function switchTab(tab: DuplicateType) {
    activeTab = tab
  }

  // Navigate between duplicate groups
  function navigateGroup(direction: 'prev' | 'next') {
    if (direction === 'prev') {
      currentGroupIndex = Math.max(0, currentGroupIndex - 1)
    } else {
      currentGroupIndex = Math.min(totalGroups - 1, currentGroupIndex + 1)
    }
    selectedRecords = new Set()
  }

  // Toggle record selection
  function toggleRecord(id: string) {
    const newSelected = new Set(selectedRecords)
    if (newSelected.has(id)) {
      newSelected.delete(id)
    } else {
      newSelected.add(id)
    }
    selectedRecords = newSelected
  }

  // Delete selected records
  function handleDelete() {
    if (selectedRecords.size === 0) {
      alert('Please select at least one record to delete')
      return
    }

    const count = selectedRecords.size
    if (!confirm(`Are you sure you want to delete ${count} record${count > 1 ? 's' : ''}? This action cannot be undone.`)) {
      return
    }

    deleteMutation?.mutate({
      type: activeTab,
      ids: Array.from(selectedRecords),
    })
  }

  // Refresh duplicates
  function handleRefresh() {
    duplicatesQuery?.refetch()
  }

  // Format date for display
  function formatDate(dateStr: string | null): string {
    if (!dateStr) return '—'
    const date = new Date(dateStr)
    return date.toLocaleDateString('en-GB', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    })
  }
</script>

<div class="min-h-screen bg-gray-50">
  <!-- Header -->
  <div class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="py-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">Duplicate Management</h1>
            <p class="mt-2 text-sm text-gray-700">
              Detect and resolve duplicate records across the system
            </p>
          </div>

          <div class="flex space-x-3">
            <a
              href="/admin"
              class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
            >
              <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
              </svg>
              Back to Admin
            </a>

            <button
              on:click={handleRefresh}
              disabled={$duplicatesQuery?.isFetching}
              class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50"
            >
              <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
              {$duplicatesQuery?.isFetching ? 'Refreshing...' : 'Refresh'}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Main Content -->
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">

    <!-- Tabs -->
    <div class="border-b border-gray-200 mb-6">
      <nav class="-mb-px flex space-x-8">
        <button
          on:click={() => switchTab('cases')}
          class="py-4 px-1 border-b-2 font-medium text-sm {activeTab === 'cases' ? 'border-blue-500 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
        >
          Cases
          {#if activeTab === 'cases' && duplicateGroups.length > 0}
            <span class="ml-2 py-0.5 px-2 rounded-full text-xs bg-blue-100 text-blue-800">{duplicateGroups.length}</span>
          {/if}
        </button>

        <button
          on:click={() => switchTab('notices')}
          class="py-4 px-1 border-b-2 font-medium text-sm {activeTab === 'notices' ? 'border-blue-500 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
        >
          Notices
          {#if activeTab === 'notices' && duplicateGroups.length > 0}
            <span class="ml-2 py-0.5 px-2 rounded-full text-xs bg-blue-100 text-blue-800">{duplicateGroups.length}</span>
          {/if}
        </button>

        <button
          on:click={() => switchTab('offenders')}
          class="py-4 px-1 border-b-2 font-medium text-sm {activeTab === 'offenders' ? 'border-blue-500 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
        >
          Offenders
          {#if activeTab === 'offenders' && duplicateGroups.length > 0}
            <span class="ml-2 py-0.5 px-2 rounded-full text-xs bg-blue-100 text-blue-800">{duplicateGroups.length}</span>
          {/if}
        </button>
      </nav>
    </div>

    <!-- Loading State -->
    {#if !duplicatesQuery || $duplicatesQuery.isLoading}
      <div class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-sm text-gray-500">Detecting duplicates...</p>
      </div>
    {:else if $duplicatesQuery.isError}
      <!-- Error State -->
      <div class="bg-red-50 border border-red-200 rounded-md p-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-red-800">Error</h3>
            <p class="mt-2 text-sm text-red-700">{$duplicatesQuery.error?.message || 'Failed to load duplicates'}</p>
          </div>
        </div>
      </div>
    {:else if totalGroups === 0}
      <!-- No Duplicates Found -->
      <div class="text-center py-12 bg-white rounded-lg shadow">
        <svg class="mx-auto h-12 w-12 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No Duplicates Found</h3>
        <p class="mt-1 text-sm text-gray-500">
          All {activeTab} records are unique. No duplicates detected.
        </p>
      </div>
    {:else}
      <!-- Duplicate Groups Display -->
      <div class="space-y-6">
        <!-- Group Navigation -->
        <div class="flex items-center justify-between bg-white px-4 py-3 rounded-lg shadow">
          <div class="text-sm text-gray-700">
            Group <span class="font-medium">{currentGroupIndex + 1}</span> of <span class="font-medium">{totalGroups}</span>
            <span class="ml-2 text-gray-500">({currentGroup.length} records in this group)</span>
          </div>

          <div class="flex items-center space-x-2">
            <button
              on:click={() => navigateGroup('prev')}
              disabled={currentGroupIndex === 0}
              class="px-3 py-1 border border-gray-300 text-sm rounded-md text-gray-700 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Previous
            </button>
            <button
              on:click={() => navigateGroup('next')}
              disabled={currentGroupIndex >= totalGroups - 1}
              class="px-3 py-1 border border-gray-300 text-sm rounded-md text-gray-700 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Next
            </button>
          </div>
        </div>

        <!-- Actions Bar -->
        {#if selectedRecords.size > 0}
          <div class="bg-blue-50 border border-blue-200 rounded-lg px-4 py-3 flex items-center justify-between">
            <div class="text-sm text-blue-700">
              {selectedRecords.size} record{selectedRecords.size > 1 ? 's' : ''} selected
            </div>
            <button
              on:click={handleDelete}
              disabled={$deleteMutation?.isPending}
              class="px-4 py-2 bg-red-600 text-white text-sm rounded-md hover:bg-red-700 disabled:opacity-50"
            >
              {$deleteMutation?.isPending ? 'Deleting...' : 'Delete Selected'}
            </button>
          </div>
        {/if}

        <!-- Records Table -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-12">
                  Select
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  ID
                </th>
                {#if activeTab === 'cases'}
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Regulator ID</th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Offender</th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Result</th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Fine Amount</th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Sentence Date</th>
                {:else if activeTab === 'notices'}
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Regulator ID</th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Ref Number</th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Offender</th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Type</th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Issued Date</th>
                {:else}
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Company Number</th>
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Inserted At</th>
                {/if}
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              {#each currentGroup as record}
                <tr class="hover:bg-gray-50 {selectedRecords.has(record.id) ? 'bg-blue-50' : ''}">
                  <td class="px-6 py-4">
                    <input
                      type="checkbox"
                      checked={selectedRecords.has(record.id)}
                      on:change={() => toggleRecord(record.id)}
                      class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                    />
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-500">
                    {record.id.slice(0, 8)}...
                  </td>
                  {#if activeTab === 'cases'}
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{record.regulator_id || '—'}</td>
                    <td class="px-6 py-4 text-sm text-gray-900">{record.offender_name || '—'}</td>
                    <td class="px-6 py-4 text-sm text-gray-900">{record.case_result || '—'}</td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{record.fine_amount ? `£${record.fine_amount.toLocaleString()}` : '—'}</td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{formatDate(record.sentence_date)}</td>
                  {:else if activeTab === 'notices'}
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{record.regulator_id || '—'}</td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{record.regulator_ref_number || '—'}</td>
                    <td class="px-6 py-4 text-sm text-gray-900">{record.offender_name || '—'}</td>
                    <td class="px-6 py-4 text-sm text-gray-900">{record.notice_type || '—'}</td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{formatDate(record.issued_date)}</td>
                  {:else}
                    <td class="px-6 py-4 text-sm text-gray-900">{record.name || '—'}</td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{record.company_number || '—'}</td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{formatDate(record.inserted_at)}</td>
                  {/if}
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </div>
    {/if}

  </div>
</div>
