<script lang="ts">
  import { onMount } from 'svelte'
  import { browser } from '$app/environment'
  import {
    initNoticesSync,
    searchNotices,
    noticesSyncProgress,
    cachedNotices,
    getNoticesCacheState,
    type NoticesSearchParams,
  } from '$lib/electric/sync-notices'
  import { checkElectricHealth } from '$lib/electric/sync'
  import {
    createSvelteTable,
    getCoreRowModel,
    getSortedRowModel,
    getFilteredRowModel,
    getPaginationRowModel,
    flexRender,
  } from '@tanstack/svelte-table'
  import type { ColumnDef, SortingState, PaginationState } from '@tanstack/svelte-table'
  import type { Notice } from '$lib/db/schema'

  // Svelte stores for notices data
  const cacheState = browser ? getNoticesCacheState() : null

  // State
  let loading = true
  let electricHealthy = false

  // Table state
  let sorting: SortingState = [{ id: 'notice_date', desc: true }]
  let pagination: PaginationState = {
    pageIndex: 0,
    pageSize: 20,
  }

  // Search/filter state
  let searchTerm = ''
  let searchDebounceTimer: ReturnType<typeof setTimeout> | null = null
  let agencyFilter = ''
  let noticeTypeFilter = ''
  let dateFrom = ''
  let dateTo = ''

  // Initialize sync on mount
  onMount(async () => {
    try {
      electricHealthy = await checkElectricHealth()
      console.log('[Notices Page] Electric health:', electricHealthy)

      if (!electricHealthy) {
        console.warn('[Notices Page] Electric service unavailable, working offline')
      }

      // Initialize query-based sync (baseline + changes-only)
      if (electricHealthy) {
        await initNoticesSync()
        console.log('[Notices Page] Query-based sync initialized')
      }

      loading = false
    } catch (err) {
      console.error('[Notices Page] Initialization error:', err)
      loading = false
    }
  })

  // Column definitions
  const columns: ColumnDef<Notice>[] = [
    {
      accessorKey: 'regulator_id',
      header: 'Regulator ID',
      cell: (info) => info.getValue() || 'N/A',
      enableSorting: true,
    },
    {
      accessorKey: 'notice_date',
      header: 'Notice Date',
      cell: (info) => formatDate(info.getValue() as string),
      enableSorting: true,
      sortingFn: 'datetime',
    },
    {
      accessorKey: 'operative_date',
      header: 'Operative Date',
      cell: (info) => formatDate(info.getValue() as string),
      enableSorting: true,
      sortingFn: 'datetime',
    },
    {
      accessorKey: 'compliance_date',
      header: 'Compliance Date',
      cell: (info) => formatDate(info.getValue() as string),
      enableSorting: true,
      sortingFn: 'datetime',
    },
    {
      accessorKey: 'offence_action_type',
      header: 'Notice Type',
      cell: (info) => {
        const type = info.getValue() as string
        if (!type) return 'N/A'
        // Display as badge
        return `<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">${type}</span>`
      },
      enableSorting: true,
    },
    {
      accessorKey: 'offence_breaches',
      header: 'Breaches',
      cell: (info) => {
        const breaches = info.getValue() as string
        if (!breaches) return 'N/A'
        return breaches.length > 80 ? breaches.substring(0, 80) + '...' : breaches
      },
    },
    {
      accessorKey: 'environmental_impact',
      header: 'Environmental Impact',
      cell: (info) => {
        const impact = info.getValue() as string
        if (!impact) return '—'
        return impact.length > 50 ? impact.substring(0, 50) + '...' : impact
      },
    },
    {
      id: 'agency',
      header: 'Agency',
      accessorFn: (row) => row.agency_id,
      cell: (info) => {
        const id = info.getValue() as string
        return id ? id.substring(0, 8) + '...' : 'N/A'
      },
    },
    {
      id: 'actions',
      header: 'Actions',
      cell: (info) => {
        const noticeId = info.row.original.id
        return `<a href="/notices/${noticeId}" class="text-blue-600 hover:text-blue-800 font-medium">View</a>`
      },
    },
  ]

  // Reactive table data from Svelte store
  $: data = $cachedNotices || []

  // Client-side filtering
  $: filteredData = data.filter((notice) => {
    // Agency filter
    if (agencyFilter && notice.agency_id !== agencyFilter) {
      return false
    }

    // Notice type filter
    if (noticeTypeFilter && notice.offence_action_type !== noticeTypeFilter) {
      return false
    }

    // Date range
    if (dateFrom && notice.notice_date && notice.notice_date < dateFrom) {
      return false
    }
    if (dateTo && notice.notice_date && notice.notice_date > dateTo) {
      return false
    }

    // Search term (already filtered by server via searchNotices, but apply here too)
    if (searchTerm) {
      const term = searchTerm.toLowerCase()
      const searchable = [
        notice.regulator_id,
        notice.notice_body,
        notice.offence_breaches,
        notice.regulator_ref_number,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase()

      if (!searchable.includes(term)) {
        return false
      }
    }

    return true
  })

  // TanStack Table instance
  $: table = createSvelteTable({
    data: filteredData,
    columns,
    state: {
      sorting,
      pagination,
    },
    onSortingChange: (updater) => {
      sorting = typeof updater === 'function' ? updater(sorting) : updater
    },
    onPaginationChange: (updater) => {
      pagination = typeof updater === 'function' ? updater(pagination) : updater
    },
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
  })

  // Handle search with debounce
  function handleSearchInput(event: Event) {
    const input = event.target as HTMLInputElement
    searchTerm = input.value

    // Clear existing timer
    if (searchDebounceTimer) {
      clearTimeout(searchDebounceTimer)
    }

    // Debounce search (500ms)
    searchDebounceTimer = setTimeout(() => {
      if (searchTerm.trim()) {
        triggerSearch()
      }
    }, 500)
  }

  // Trigger search (calls ElectricSQL sync)
  async function triggerSearch() {
    if (!searchTerm.trim() && !agencyFilter && !noticeTypeFilter && !dateFrom && !dateTo) {
      // No search params - just show baseline
      return
    }

    const params: NoticesSearchParams = {
      searchTerm: searchTerm.trim() || undefined,
      agencyId: agencyFilter || undefined,
      noticeType: noticeTypeFilter || undefined,
      dateFrom: dateFrom || undefined,
      dateTo: dateTo || undefined,
    }

    try {
      await searchNotices(params)
      // Results automatically update via cachedNotices store
    } catch (error) {
      console.error('[Notices Page] Search failed:', error)
    }
  }

  // Clear all filters
  function clearFilters() {
    searchTerm = ''
    agencyFilter = ''
    noticeTypeFilter = ''
    dateFrom = ''
    dateTo = ''
    if (searchDebounceTimer) {
      clearTimeout(searchDebounceTimer)
    }
  }

  // Format date
  function formatDate(dateString: string | null): string {
    if (!dateString) return 'N/A'
    try {
      const date = new Date(dateString)
      return date.toLocaleDateString('en-GB', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
      })
    } catch {
      return 'Invalid date'
    }
  }
</script>

<svelte:head>
  <title>Enforcement Notices | EHS Enforcement</title>
  <meta name="description" content="Browse enforcement notices and improvement notices" />
</svelte:head>

<div class="container mx-auto px-4 py-8">
  <!-- Header -->
  <div class="mb-8">
    <div class="flex items-center justify-between mb-2">
      <h1 class="text-4xl font-bold text-gray-900">Enforcement Notices</h1>
      <a href="/" class="text-blue-600 hover:text-blue-800 font-medium"> ← Back to Dashboard </a>
    </div>
    <p class="text-gray-600">Browse enforcement notices and improvement notices</p>
  </div>

  <!-- Sync Status Banner -->
  <div
    class="mb-6 p-4 rounded-lg {$noticesSyncProgress.phase === 'baseline_ready'
      ? 'bg-green-50 border border-green-200'
      : $noticesSyncProgress.searchInProgress
        ? 'bg-blue-50 border border-blue-200'
        : 'bg-yellow-50 border border-yellow-200'}"
  >
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <div
          class="w-3 h-3 rounded-full {$noticesSyncProgress.phase === 'baseline_ready'
            ? 'bg-green-500'
            : $noticesSyncProgress.searchInProgress
              ? 'bg-blue-500 animate-pulse'
              : 'bg-yellow-500'}"
        ></div>
        <span class="font-medium text-gray-900">
          {#if $noticesSyncProgress.searchInProgress}
            Searching... ({$noticesSyncProgress.currentSearch})
          {:else if $noticesSyncProgress.phase === 'baseline_ready'}
            ✓ Baseline loaded ({$noticesSyncProgress.baselineCount} recent notices) • Search to
            load more
          {:else if $noticesSyncProgress.phase === 'initializing'}
            Loading baseline...
          {:else}
            Offline Mode
          {/if}
        </span>
      </div>
      {#if $cacheState && $cacheState.totalShapes > 0}
        <span class="text-sm text-gray-600">
          {$cacheState.totalShapes} cached search{$cacheState.totalShapes !== 1 ? 'es' : ''}
        </span>
      {/if}
    </div>
    {#if $noticesSyncProgress.phase === 'baseline_ready' && !$noticesSyncProgress.searchInProgress}
      <p class="mt-2 text-sm text-gray-600">
        💡 Search to load more notices. Your search results are cached for offline access.
      </p>
    {/if}
  </div>

  <!-- SSR or Loading State -->
  {#if loading}
    <div class="flex items-center justify-center py-12">
      <div class="text-center">
        <div
          class="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mb-4"
        ></div>
        <p class="text-gray-600">Loading notices...</p>
      </div>
    </div>

    <!-- Error State -->
  {:else if $noticesSyncProgress.error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-6">
      <h3 class="text-red-900 font-semibold mb-2">Sync Error</h3>
      <p class="text-red-700">{$noticesSyncProgress.error}</p>
    </div>

    <!-- Empty State (Baseline only) -->
  {:else if !$cachedNotices || $cachedNotices.length === 0}
    <div class="bg-gray-50 border border-gray-200 rounded-lg p-12 text-center">
      <h3 class="text-gray-900 font-semibold text-lg mb-2">No Notices Found</h3>
      <p class="text-gray-600 mb-4">
        {#if electricHealthy}
          Baseline is loading... Search to find specific notices.
        {:else}
          No cached data available. Electric service is offline.
        {/if}
      </p>
    </div>

    <!-- Notices Table -->
  {:else}
    <!-- Stats Card -->
    <div class="bg-white border border-gray-200 rounded-lg p-4 mb-6">
      <div class="text-sm text-gray-600 mb-1">Total Notices</div>
      <div class="text-2xl font-bold text-gray-900">{filteredData.length.toLocaleString()}</div>
      <div class="text-xs text-gray-500 mt-1">
        {#if $noticesSyncProgress.baselineLoaded}
          Showing baseline + search results
        {:else}
          Loading...
        {/if}
      </div>
    </div>

    <!-- Search & Filters Panel -->
    <div class="bg-white border border-gray-200 rounded-lg p-6 mb-6">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-semibold text-gray-900">Search & Filters</h2>
        <button onclick={clearFilters} class="text-sm text-blue-600 hover:text-blue-800 font-medium">
          Clear All
        </button>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <!-- Search Input -->
        <div class="md:col-span-2">
          <label for="search" class="block text-sm font-medium text-gray-700 mb-1">
            🔍 Search (regulator ID, body, breaches)
          </label>
          <input
            id="search"
            type="text"
            value={searchTerm}
            oninput={handleSearchInput}
            placeholder="Search notices..."
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <p class="mt-1 text-xs text-gray-500">
            Type to search (debounced 500ms) • Triggers server sync on enter
          </p>
        </div>

        <!-- Date From -->
        <div>
          <label for="dateFrom" class="block text-sm font-medium text-gray-700 mb-1">
            Notice Date From
          </label>
          <input
            id="dateFrom"
            type="date"
            bind:value={dateFrom}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <!-- Date To -->
        <div>
          <label for="dateTo" class="block text-sm font-medium text-gray-700 mb-1">
            Notice Date To
          </label>
          <input
            id="dateTo"
            type="date"
            bind:value={dateTo}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <!-- Search Button -->
        <div class="md:col-span-2">
          <button
            onclick={triggerSearch}
            disabled={$noticesSyncProgress.searchInProgress}
            class="w-full px-4 py-2 bg-blue-600 text-white font-medium rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {#if $noticesSyncProgress.searchInProgress}
              Searching...
            {:else}
              Search Notices
            {/if}
          </button>
        </div>
      </div>

      <div class="mt-4 text-sm text-gray-600">
        Showing {filteredData.length} of {$cachedNotices.length} notices
      </div>
    </div>

    <!-- Cached Searches Display -->
    {#if $cacheState && $cacheState.totalShapes > 0}
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
        <h3 class="text-sm font-semibold text-blue-900 mb-2">
          💾 Cached Searches (Available Offline)
        </h3>
        <div class="flex flex-wrap gap-2">
          {#each Array.from($cacheState.cacheDescriptions.entries()) as [key, description]}
            <span
              class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800"
            >
              {description}
            </span>
          {/each}
        </div>
        <p class="mt-2 text-xs text-blue-700">
          These {$cacheState.totalShapes} search{$cacheState.totalShapes !== 1 ? 'es' : ''} are cached
          for offline use
        </p>
      </div>
    {/if}

    <!-- Table -->
    <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            {#each $table.getHeaderGroups() as headerGroup}
              <tr>
                {#each headerGroup.headers as header}
                  <th
                    scope="col"
                    class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100 select-none"
                    onclick={() => {
                      if (header.column.getCanSort()) {
                        header.column.getToggleSortingHandler()?.()
                      }
                    }}
                  >
                    <div class="flex items-center gap-2">
                      {#if !header.isPlaceholder}
                        {#if typeof header.column.columnDef.header === 'function'}
                          {header.column.columnDef.header(header.getContext())}
                        {:else}
                          {header.column.columnDef.header}
                        {/if}
                      {/if}
                      {#if header.column.getIsSorted()}
                        <span class="text-blue-600">
                          {header.column.getIsSorted() === 'asc' ? '↑' : '↓'}
                        </span>
                      {/if}
                    </div>
                  </th>
                {/each}
              </tr>
            {/each}
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each $table.getRowModel().rows as row}
              <tr class="hover:bg-gray-50">
                {#each row.getVisibleCells() as cell}
                  <td class="px-6 py-4 text-sm text-gray-900">
                    {#if typeof cell.column.columnDef.cell === 'function'}
                      {@html cell.column.columnDef.cell(cell.getContext())}
                    {:else}
                      {cell.getValue()}
                    {/if}
                  </td>
                {/each}
              </tr>
            {/each}
          </tbody>
        </table>
      </div>

      <!-- Pagination -->
      <div class="bg-gray-50 px-6 py-4 flex items-center justify-between border-t border-gray-200">
        <div class="flex items-center gap-2">
          <span class="text-sm text-gray-700">Rows per page:</span>
          <select
            bind:value={pagination.pageSize}
            onchange={() => {
              pagination = { ...pagination, pageIndex: 0 }
            }}
            class="border border-gray-300 rounded-md px-2 py-1 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value={20}>20</option>
            <option value={50}>50</option>
            <option value={100}>100</option>
          </select>
        </div>

        <div class="flex items-center gap-2">
          <span class="text-sm text-gray-700">
            Page {$table.getState().pagination.pageIndex + 1} of {$table.getPageCount()}
          </span>
          <button
            onclick={() => $table.previousPage()}
            disabled={!$table.getCanPreviousPage()}
            class="px-3 py-1 border border-gray-300 rounded-md text-sm font-medium text-gray-700 hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Previous
          </button>
          <button
            onclick={() => $table.nextPage()}
            disabled={!$table.getCanNextPage()}
            class="px-3 py-1 border border-gray-300 rounded-md text-sm font-medium text-gray-700 hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Next
          </button>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .container {
    max-width: 1400px;
  }
</style>
