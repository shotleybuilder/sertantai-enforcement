<script lang="ts">
  import { onMount } from 'svelte'
  import { browser } from '$app/environment'
  import {
    initOffendersSync,
    searchOffenders,
    offendersSyncProgress,
    cachedOffenders,
    getOffendersCacheState,
    type OffendersSearchParams,
  } from '$lib/electric/sync-offenders'
  import { checkElectricHealth } from '$lib/electric/sync'
  import {
    createSvelteTable,
    getCoreRowModel,
    getSortedRowModel,
    getFilteredRowModel,
    getPaginationRowModel,
  } from '@tanstack/svelte-table'
  import type { ColumnDef, SortingState, PaginationState } from '@tanstack/svelte-table'
  import type { Offender } from '$lib/db/schema'

  // Svelte stores for offenders data
  const cacheState = browser ? getOffendersCacheState() : null

  // State
  let loading = true
  let electricHealthy = false
  let hasSearched = false

  // Table state
  let sorting: SortingState = [{ id: 'name', desc: false }]
  let pagination: PaginationState = {
    pageIndex: 0,
    pageSize: 20,
  }

  // Search/filter state
  let searchTerm = ''
  let searchDebounceTimer: ReturnType<typeof setTimeout> | null = null
  let companyNumber = ''
  let location = ''
  let industry = ''
  let businessType = ''

  // Initialize sync on mount (NO baseline)
  onMount(async () => {
    try {
      electricHealthy = await checkElectricHealth()
      console.log('[Offenders Page] Electric health:', electricHealthy)

      if (!electricHealthy) {
        console.warn('[Offenders Page] Electric service unavailable, working offline')
      }

      // Initialize (no baseline - search-first)
      if (electricHealthy) {
        await initOffendersSync()
        console.log('[Offenders Page] Search-first sync initialized (no baseline)')
      }

      loading = false
    } catch (err) {
      console.error('[Offenders Page] Initialization error:', err)
      loading = false
    }
  })

  // Column definitions
  const columns: ColumnDef<Offender>[] = [
    {
      accessorKey: 'name',
      header: 'Company Name',
      cell: (info) => info.getValue() || 'N/A',
      enableSorting: true,
    },
    {
      accessorKey: 'company_registration_number',
      header: 'Company Number',
      cell: (info) => info.getValue() || '—',
      enableSorting: true,
    },
    {
      accessorKey: 'business_type',
      header: 'Type',
      cell: (info) => {
        const type = info.getValue() as string
        if (!type) return '—'
        // Format business type
        return type
          .split('_')
          .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
          .join(' ')
      },
      enableSorting: true,
    },
    {
      accessorKey: 'local_authority',
      header: 'Location',
      cell: (info) => {
        const row = info.row.original
        const parts = [row.local_authority, row.town, row.postcode].filter(Boolean)
        return parts.length > 0 ? parts.join(', ') : '—'
      },
    },
    {
      accessorKey: 'industry',
      header: 'Industry',
      cell: (info) => {
        const ind = info.getValue() as string
        const activity = info.row.original.main_activity
        return ind || activity || '—'
      },
    },
    {
      accessorKey: 'total_cases',
      header: 'Cases',
      cell: (info) => {
        const total = info.getValue() as number
        return total > 0 ? total : '0'
      },
      enableSorting: true,
    },
    {
      accessorKey: 'total_notices',
      header: 'Notices',
      cell: (info) => {
        const total = info.getValue() as number
        return total > 0 ? total : '0'
      },
      enableSorting: true,
    },
    {
      accessorKey: 'total_fines',
      header: 'Total Fines',
      cell: (info) => {
        const fines = info.getValue() as number
        return fines > 0 ? `£${fines.toLocaleString()}` : '£0'
      },
      enableSorting: true,
    },
    {
      id: 'actions',
      header: 'Actions',
      cell: (info) => {
        const offenderId = info.row.original.id
        return `<a href="/offenders/${offenderId}" class="text-blue-600 hover:text-blue-800 font-medium">View</a>`
      },
    },
  ]

  // Reactive table data from Svelte store
  $: data = $cachedOffenders || []

  // Client-side filtering
  $: filteredData = data.filter((offender) => {
    // All filters are applied via search - no additional client filtering needed
    // This allows instant filtering of cached results
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
    // Require at least one search parameter
    if (
      !searchTerm.trim() &&
      !companyNumber.trim() &&
      !location.trim() &&
      !industry.trim() &&
      !businessType
    ) {
      return
    }

    const params: OffendersSearchParams = {
      searchTerm: searchTerm.trim() || undefined,
      companyNumber: companyNumber.trim() || undefined,
      location: location.trim() || undefined,
      industry: industry.trim() || undefined,
      businessType: businessType || undefined,
    }

    try {
      await searchOffenders(params)
      hasSearched = true
      // Results automatically update via cachedOffenders store
    } catch (error) {
      console.error('[Offenders Page] Search failed:', error)
    }
  }

  // Clear all filters
  function clearFilters() {
    searchTerm = ''
    companyNumber = ''
    location = ''
    industry = ''
    businessType = ''
    if (searchDebounceTimer) {
      clearTimeout(searchDebounceTimer)
    }
  }
</script>

<svelte:head>
  <title>Offenders | EHS Enforcement</title>
  <meta name="description" content="Search enforcement offenders and companies" />
</svelte:head>

<div class="container mx-auto px-4 py-8">
  <!-- Header -->
  <div class="mb-8">
    <div class="flex items-center justify-between mb-2">
      <h1 class="text-4xl font-bold text-gray-900">Offenders</h1>
      <a href="/" class="text-blue-600 hover:text-blue-800 font-medium"> ← Back to Dashboard </a>
    </div>
    <p class="text-gray-600">Search for companies and individuals subject to enforcement action</p>
  </div>

  <!-- Sync Status Banner -->
  {#if $offendersSyncProgress.searchInProgress}
    <div class="mb-6 p-4 rounded-lg bg-blue-50 border border-blue-200">
      <div class="flex items-center gap-3">
        <div class="animate-spin rounded-full h-5 w-5 border-b-2 border-blue-600"></div>
        <div>
          <div class="font-semibold text-blue-900">Searching...</div>
          <div class="text-sm text-blue-700">{$offendersSyncProgress.currentSearch}</div>
        </div>
      </div>
    </div>
  {/if}

  {#if $offendersSyncProgress.error}
    <div class="mb-6 p-4 rounded-lg bg-red-50 border border-red-200">
      <div class="font-semibold text-red-900">Search Error</div>
      <div class="text-sm text-red-700">{$offendersSyncProgress.error}</div>
    </div>
  {/if}

  <!-- Search-First Prompt (shown when no searches yet) -->
  {#if !loading && !hasSearched && filteredData.length === 0}
    <div class="bg-gradient-to-br from-blue-50 to-indigo-50 border-2 border-blue-200 rounded-lg p-12 text-center mb-6">
      <div class="text-6xl mb-4">🔍</div>
      <h2 class="text-2xl font-bold text-gray-900 mb-3">Search to Load Offenders</h2>
      <p class="text-gray-600 mb-6 max-w-2xl mx-auto">
        This page uses search-driven caching. Enter a company name, registration number, location, or industry below to load matching offenders. Your search results will be cached for offline access.
      </p>
      <p class="text-sm text-gray-500">
        ℹ️ Tip: Start typing in the search box below to find offenders
      </p>
    </div>
  {/if}

  <!-- Search & Filters Panel -->
  <div class="bg-white border border-gray-200 rounded-lg p-6 mb-6">
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-lg font-semibold text-gray-900">🔍 Search Offenders</h2>
      <button onclick={clearFilters} class="text-sm text-blue-600 hover:text-blue-800 font-medium">
        Clear All
      </button>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <!-- Company Name Search -->
      <div class="md:col-span-2">
        <label for="search" class="block text-sm font-medium text-gray-700 mb-1">
          Company Name
        </label>
        <input
          id="search"
          type="text"
          value={searchTerm}
          oninput={handleSearchInput}
          placeholder="Search by company name..."
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
        <p class="mt-1 text-xs text-gray-500">
          Type to search (debounced 500ms) • Triggers server sync on enter
        </p>
      </div>

      <!-- Company Number -->
      <div>
        <label for="companyNumber" class="block text-sm font-medium text-gray-700 mb-1">
          Company Registration Number
        </label>
        <input
          id="companyNumber"
          type="text"
          bind:value={companyNumber}
          placeholder="e.g., 04622955"
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <!-- Location -->
      <div>
        <label for="location" class="block text-sm font-medium text-gray-700 mb-1">
          Location (Town/Postcode)
        </label>
        <input
          id="location"
          type="text"
          bind:value={location}
          placeholder="e.g., London, SW1A"
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <!-- Industry -->
      <div>
        <label for="industry" class="block text-sm font-medium text-gray-700 mb-1">
          Industry/Activity
        </label>
        <input
          id="industry"
          type="text"
          bind:value={industry}
          placeholder="e.g., Manufacturing"
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <!-- Business Type -->
      <div>
        <label for="businessType" class="block text-sm font-medium text-gray-700 mb-1">
          Business Type
        </label>
        <select
          id="businessType"
          bind:value={businessType}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">All Types</option>
          <option value="limited_company">Limited Company</option>
          <option value="plc">PLC</option>
          <option value="partnership">Partnership</option>
          <option value="individual">Individual</option>
          <option value="other">Other</option>
        </select>
      </div>
    </div>

    <!-- Search Button -->
    <div class="mt-4">
      <button
        onclick={triggerSearch}
        disabled={!searchTerm.trim() && !companyNumber.trim() && !location.trim() && !industry.trim() && !businessType}
        class="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed font-medium"
      >
        Search
      </button>
    </div>
  </div>

  <!-- Loading State -->
  {#if loading}
    <div class="flex items-center justify-center py-12">
      <div class="text-center">
        <div
          class="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mb-4"
        ></div>
        <p class="text-gray-600">Initializing...</p>
      </div>
    </div>

  <!-- Empty Search State -->
  {:else if filteredData.length === 0 && hasSearched}
    <div class="bg-gray-50 border border-gray-200 rounded-lg p-12 text-center">
      <h3 class="text-gray-900 font-semibold text-lg mb-2">No Offenders Found</h3>
      <p class="text-gray-600 mb-4">
        No results match your search criteria. Try different search terms or clear your filters.
      </p>
      <button
        onclick={clearFilters}
        class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
      >
        Clear Filters
      </button>
    </div>

  <!-- Offenders Table -->
  {:else if hasSearched}
    <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
      <!-- Stats Card -->
      <div class="bg-gray-50 px-6 py-4 border-b border-gray-200">
        <div class="flex items-center justify-between">
          <div>
            <div class="text-sm text-gray-600">Total Offenders Found</div>
            <div class="text-2xl font-bold text-gray-900">{filteredData.length.toLocaleString()}</div>
          </div>
          {#if $cacheState && $cacheState.totalShapes > 0}
            <div class="text-sm text-gray-600">
              {$cacheState.totalShapes} cached search{$cacheState.totalShapes > 1 ? 'es' : ''}
            </div>
          {/if}
        </div>
      </div>

      <!-- Table -->
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
            class="px-3 py-1 border border-gray-300 rounded-md hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Previous
          </button>
          <button
            onclick={() => $table.nextPage()}
            disabled={!$table.getCanNextPage()}
            class="px-3 py-1 border border-gray-300 rounded-md hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Next
          </button>
        </div>
      </div>

      <div class="mt-4 px-6 pb-4 text-sm text-gray-600">
        Showing {filteredData.length} of {$cachedOffenders.length} offenders
      </div>
    </div>

    <!-- Cached Searches Display -->
    {#if $cacheState && $cacheState.totalShapes > 0}
      <div class="mt-4 text-sm text-gray-600 bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div class="font-semibold text-blue-900 mb-2">
          📦 Cached Searches ({$cacheState.totalShapes}/{$cacheState.maxShapes})
        </div>
        <div class="space-y-1">
          {#each Array.from($cacheState.cacheDescriptions.entries()) as [key, description]}
            <div class="text-blue-700">• {description}</div>
          {/each}
        </div>
        <p class="mt-2 text-xs text-blue-600">
          These searches are available offline. When cache is full, oldest searches are removed.
        </p>
      </div>
    {/if}
  {/if}
</div>
