<script lang="ts">
  import { onMount } from 'svelte'
  import { browser } from '$app/environment'
  import { useCasesQuery } from '$lib/query/cases'
  import { startCasesSync, stopCasesSync, casesSyncProgress } from '$lib/electric/sync-cases'
  import { checkElectricHealth } from '$lib/electric/sync'
  import NaturalLanguageQuery from '$lib/components/NaturalLanguageQuery.svelte'
  import {
    createSvelteTable,
    getCoreRowModel,
    getSortedRowModel,
    getFilteredRowModel,
    getPaginationRowModel,
    flexRender,
  } from '@tanstack/svelte-table'
  import type { ColumnDef, SortingState, ColumnFiltersState, PaginationState } from '@tanstack/svelte-table'
  import type { Case } from '$lib/db/schema'

  // TanStack Query for cases data (only in browser, not SSR)
  const casesQuery = browser ? useCasesQuery() : null

  // State
  let loading = true
  let error: string | null = null
  let electricHealthy = false

  // Table state
  let sorting: SortingState = [{ id: 'offence_action_date', desc: true }] // Default sort: date descending
  let columnFilters: ColumnFiltersState = []
  let pagination: PaginationState = {
    pageIndex: 0,
    pageSize: 20,
  }

  // Helper to get date 3 years ago
  function get3YearsAgo(): string {
    const date = new Date()
    date.setFullYear(date.getFullYear() - 3)
    return date.toISOString().split('T')[0]
  }

  // Filter state - DEFAULT to last 3 years
  let globalFilter = ''
  let agencyFilter = ''
  let minFine: number | null = null
  let maxFine: number | null = null
  let dateFrom: string = get3YearsAgo() // Default: last 3 years
  let dateTo: string = ''

  // AI-generated filters from natural language query
  let aiFilters: any[] = []
  let aiSort: any | null = null
  let aiColumns: string[] = []  // AI-selected columns to display
  let aiColumnOrder: string[] = []  // AI-determined column order

  // Initialize database and start sync on mount
  onMount(async () => {
    try {
      // 1. Check if Electric service is available
      electricHealthy = await checkElectricHealth()
      console.log('[Cases Page] Electric health:', electricHealthy)

      if (!electricHealthy) {
        console.warn('[Cases Page] Electric service unavailable, working offline')
      }

      // 2. Start hybrid progressive sync (recent → historical)
      if (electricHealthy) {
        await startCasesSync()
        console.log('[Cases Page] Hybrid progressive sync started')
      }

      loading = false

      // Cleanup on unmount
      return () => {
        // Note: We don't stop sync on unmount - it continues for other pages
        // stopCasesSync()
      }
    } catch (err) {
      console.error('[Cases Page] Initialization error:', err)
      error = err instanceof Error ? err.message : 'Unknown error'
      loading = false
    }
  })

  // Get visible columns based on AI selection (reactive)
  $: visibleColumnIds = aiColumns.length > 0 ? aiColumns : null

  // Reorder columns based on AI columnOrder
  $: orderedColumnIds = aiColumnOrder.length > 0 ? aiColumnOrder : null

  // Column definitions for TanStack Table
  const columns: ColumnDef<Case>[] = [
    {
      accessorKey: 'case_reference',
      header: 'Case Reference',
      cell: (info) => info.getValue() || 'N/A',
      enableSorting: true,
      enableColumnFilter: true,
    },
    {
      accessorKey: 'offence_action_date',
      header: 'Date',
      cell: (info) => formatDate(info.getValue() as string),
      enableSorting: true,
      sortingFn: 'datetime',
    },
    {
      accessorKey: 'offence_result',
      header: 'Result',
      cell: (info) => info.getValue() || 'N/A',
      enableSorting: true,
    },
    {
      accessorKey: 'offence_action_type',
      header: 'Action Type',
      cell: (info) => info.getValue() || 'N/A',
      enableSorting: true,
    },
    {
      accessorKey: 'offence_fine',
      header: 'Fine',
      cell: (info) => formatCurrency(info.getValue() as number),
      enableSorting: true,
      sortingFn: 'basic', // Numeric sorting
    },
    {
      accessorKey: 'offence_costs',
      header: 'Costs',
      cell: (info) => formatCurrency(info.getValue() as number),
      enableSorting: true,
      sortingFn: 'basic',
    },
    {
      accessorKey: 'offence_breaches',
      header: 'Breaches',
      cell: (info) => {
        const breaches = info.getValue() as string
        if (!breaches) return 'N/A'
        // Truncate long breach descriptions
        return breaches.length > 100 ? breaches.substring(0, 100) + '...' : breaches
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
        const caseId = info.row.original.id
        return `<a href="/cases/${caseId}" class="text-blue-600 hover:text-blue-800 font-medium">View</a>`
      },
    },
  ]

  // Create table instance (reactive to data changes)
  $: data = ($casesQuery?.data || [])

  $: filteredData = filterData(data, {
    global: globalFilter,
    agency: agencyFilter,
    minFine,
    maxFine,
    dateFrom,
    dateTo,
  })

  // Filter and reorder columns based on AI selection
  $: visibleColumns = visibleColumnIds
    ? columns.filter((col) => {
        const id = col.accessorKey || col.id
        return visibleColumnIds.includes(id as string)
      })
    : columns

  // Apply column ordering if AI provided it
  $: finalColumns = orderedColumnIds && orderedColumnIds.length > 0
    ? orderedColumnIds
        .map((id) => visibleColumns.find((col) => (col.accessorKey || col.id) === id))
        .filter((col) => col !== undefined) as ColumnDef<Case>[]
    : visibleColumns

  $: table = createSvelteTable({
    data: filteredData,
    columns: finalColumns,  // Use AI-filtered/ordered columns
    state: {
      sorting,
      columnFilters,
      pagination,
    },
    onSortingChange: (updater) => {
      sorting = typeof updater === 'function' ? updater(sorting) : updater
    },
    onColumnFiltersChange: (updater) => {
      columnFilters = typeof updater === 'function' ? updater(columnFilters) : updater
    },
    onPaginationChange: (updater) => {
      pagination = typeof updater === 'function' ? updater(pagination) : updater
    },
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
  })

  // Handle AI query success
  function handleAIQuery(filters: any[], sort: any | null, columns?: string[], columnOrder?: string[]) {
    console.log('[Cases Page] AI Query received:', { filters, sort, columns, columnOrder })
    aiFilters = filters
    aiSort = sort
    aiColumns = columns || []
    aiColumnOrder = columnOrder || []

    // Apply sort if provided
    if (sort) {
      sorting = [{ id: sort.columnId, desc: sort.direction === 'desc' }]
    }
  }

  // Apply a single AI filter to a case
  function applyAIFilter(caseData: Case, filter: any): boolean {
    const { field, operator, value } = filter

    // Get field value from case
    const fieldValue = (caseData as any)[field]

    // Handle different operators
    switch (operator) {
      case 'equals':
        return fieldValue === value
      case 'not_equals':
        return fieldValue !== value
      case 'contains':
        return fieldValue?.toString().toLowerCase().includes(value.toLowerCase())
      case 'not_contains':
        return !fieldValue?.toString().toLowerCase().includes(value.toLowerCase())
      case 'starts_with':
        return fieldValue?.toString().toLowerCase().startsWith(value.toLowerCase())
      case 'ends_with':
        return fieldValue?.toString().toLowerCase().endsWith(value.toLowerCase())
      case 'greater_than':
        return (fieldValue ?? 0) > value
      case 'less_than':
        return (fieldValue ?? 0) < value
      case 'greater_or_equal':
        return (fieldValue ?? 0) >= value
      case 'less_or_equal':
        return (fieldValue ?? 0) <= value
      case 'is_empty':
        return !fieldValue || fieldValue === ''
      case 'is_not_empty':
        return !!fieldValue && fieldValue !== ''
      default:
        console.warn('[Filter] Unknown operator:', operator)
        return true
    }
  }

  // Filter function (client-side)
  function filterData(
    cases: Case[],
    filters: {
      global: string
      agency: string
      minFine: number | null
      maxFine: number | null
      dateFrom: string
      dateTo: string
    }
  ): Case[] {
    return cases.filter((c) => {
      // Apply AI filters first (if any)
      if (aiFilters.length > 0) {
        const passesAIFilters = aiFilters.every((filter) => applyAIFilter(c, filter))
        if (!passesAIFilters) return false
      }
      // Global search (case reference, result, action type, breaches)
      if (filters.global) {
        const searchTerm = filters.global.toLowerCase()
        const searchableText = [
          c.case_reference,
          c.offence_result,
          c.offence_action_type,
          c.offence_breaches,
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase()

        if (!searchableText.includes(searchTerm)) {
          return false
        }
      }

      // Agency filter
      if (filters.agency && c.agency_id !== filters.agency) {
        return false
      }

      // Fine range filter
      if (filters.minFine !== null && (c.offence_fine ?? 0) < filters.minFine) {
        return false
      }
      if (filters.maxFine !== null && (c.offence_fine ?? 0) > filters.maxFine) {
        return false
      }

      // Date range filter
      if (filters.dateFrom && c.offence_action_date) {
        if (c.offence_action_date < filters.dateFrom) {
          return false
        }
      }
      if (filters.dateTo && c.offence_action_date) {
        if (c.offence_action_date > filters.dateTo) {
          return false
        }
      }

      return true
    })
  }

  // Clear all filters
  function clearFilters() {
    globalFilter = ''
    agencyFilter = ''
    minFine = null
    maxFine = null
    dateFrom = ''
    dateTo = ''
    aiFilters = []
    aiSort = null
    aiColumns = []
    aiColumnOrder = []
  }

  // Format date for display
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

  // Format currency
  function formatCurrency(amount: number | null): string {
    if (amount === null || amount === undefined) return 'N/A'
    return new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency: 'GBP',
    }).format(amount)
  }

  // Calculate total fines (client-side)
  $: totalFines = filteredData.reduce((sum, c) => sum + (c.offence_fine ?? 0), 0)
  $: totalCosts = filteredData.reduce((sum, c) => sum + (c.offence_costs ?? 0), 0)
</script>

<svelte:head>
  <title>Enforcement Cases | EHS Enforcement</title>
  <meta name="description" content="Browse enforcement cases and prosecutions" />
</svelte:head>

<div class="container mx-auto px-4 py-8">
  <!-- Header -->
  <div class="mb-8">
    <div class="flex items-center justify-between mb-2">
      <h1 class="text-4xl font-bold text-gray-900">Enforcement Cases</h1>
      <a href="/" class="text-blue-600 hover:text-blue-800 font-medium">
        ← Back to Dashboard
      </a>
    </div>
    <p class="text-gray-600">Browse enforcement cases, prosecutions, and convictions</p>
  </div>

  <!-- Sync Status Banner -->
  <div
    class="mb-6 p-4 rounded-lg {$casesSyncProgress.phase === 'complete'
      ? 'bg-green-50 border border-green-200'
      : $casesSyncProgress.phase === 'idle'
        ? 'bg-yellow-50 border border-yellow-200'
        : 'bg-blue-50 border border-blue-200'}"
  >
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <div
          class="w-3 h-3 rounded-full {$casesSyncProgress.phase === 'complete'
            ? 'bg-green-500'
            : $casesSyncProgress.phase === 'idle'
              ? 'bg-yellow-500'
              : 'bg-blue-500 animate-pulse'}"
        ></div>
        <span class="font-medium text-gray-900">
          {#if $casesSyncProgress.phase === 'syncing_recent'}
            Syncing recent cases... ({$casesSyncProgress.recentCount} loaded)
          {:else if $casesSyncProgress.phase === 'syncing_historical'}
            ✓ Recent cases ready • Syncing historical cases in background... ({$casesSyncProgress
              .historicalCount} loaded)
          {:else if $casesSyncProgress.phase === 'complete'}
            ✓ Full dataset synced ({$casesSyncProgress.totalSynced} cases) • Offline-capable
          {:else}
            Offline Mode
          {/if}
        </span>
      </div>
      {#if $casesSyncProgress.fullCompleteTime && $casesSyncProgress.startTime}
        {@const syncTime =
          ($casesSyncProgress.fullCompleteTime.getTime() -
            $casesSyncProgress.startTime.getTime()) /
          1000}
        <span class="text-sm text-gray-600"> Sync time: {syncTime.toFixed(1)}s </span>
      {/if}
    </div>
    {#if $casesSyncProgress.recentCasesLoaded && !$casesSyncProgress.historicalCasesLoaded}
      <p class="mt-2 text-sm text-gray-600">
        You can interact with the table now. Historical cases are syncing in the background.
      </p>
    {/if}
  </div>

  <!-- Natural Language Query Component (always visible) -->
  {#if casesQuery}
    <NaturalLanguageQuery onQuerySuccess={handleAIQuery} />
  {/if}

  <!-- SSR or Loading State -->
  {#if !casesQuery || $casesQuery.isLoading || loading}
    <div class="flex items-center justify-center py-12">
      <div class="text-center">
        <div
          class="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mb-4"
        ></div>
        <p class="text-gray-600">Loading cases from local database...</p>
      </div>
    </div>

    <!-- TanStack Query Error State -->
  {:else if $casesQuery.isError}
    <div class="bg-red-50 border border-red-200 rounded-lg p-6">
      <h3 class="text-red-900 font-semibold mb-2">Query Error</h3>
      <p class="text-red-700">{$casesQuery.error?.message || 'Unknown error'}</p>
    </div>

    <!-- Empty State -->
  {:else if !$casesQuery.data || $casesQuery.data.length === 0}
    <div class="bg-gray-50 border border-gray-200 rounded-lg p-12 text-center">
      <h3 class="text-gray-900 font-semibold text-lg mb-2">No Cases Found</h3>
      <p class="text-gray-600 mb-4">
        {#if electricHealthy}
          Waiting for data to sync from PostgreSQL via ElectricSQL...
        {:else}
          No cached data available. Electric service is offline.
        {/if}
      </p>
    </div>

    <!-- Cases Table -->
  {:else}

    <!-- Stats Cards -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
      <div class="bg-white border border-gray-200 rounded-lg p-4">
        <div class="text-sm text-gray-600 mb-1">Total Cases</div>
        <div class="text-2xl font-bold text-gray-900">{filteredData.length.toLocaleString()}</div>
      </div>
      <div class="bg-white border border-gray-200 rounded-lg p-4">
        <div class="text-sm text-gray-600 mb-1">Total Fines</div>
        <div class="text-2xl font-bold text-green-600">{formatCurrency(totalFines)}</div>
      </div>
      <div class="bg-white border border-gray-200 rounded-lg p-4">
        <div class="text-sm text-gray-600 mb-1">Total Costs</div>
        <div class="text-2xl font-bold text-blue-600">{formatCurrency(totalCosts)}</div>
      </div>
    </div>

    <!-- Filters Panel -->
    <div class="bg-white border border-gray-200 rounded-lg p-6 mb-6">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-semibold text-gray-900">Filters</h2>
        <button
          onclick={clearFilters}
          class="text-sm text-blue-600 hover:text-blue-800 font-medium"
        >
          Clear All
        </button>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <!-- Global Search -->
        <div class="md:col-span-3">
          <label for="search" class="block text-sm font-medium text-gray-700 mb-1">
            Search (reference, result, action type, breaches)
          </label>
          <input
            id="search"
            type="text"
            bind:value={globalFilter}
            placeholder="Search cases..."
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <!-- Date From -->
        <div>
          <label for="dateFrom" class="block text-sm font-medium text-gray-700 mb-1">
            Date From
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
          <label for="dateTo" class="block text-sm font-medium text-gray-700 mb-1"> Date To </label>
          <input
            id="dateTo"
            type="date"
            bind:value={dateTo}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <!-- Min Fine -->
        <div>
          <label for="minFine" class="block text-sm font-medium text-gray-700 mb-1">
            Min Fine (£)
          </label>
          <input
            id="minFine"
            type="number"
            bind:value={minFine}
            placeholder="0"
            min="0"
            step="100"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <!-- Max Fine -->
        <div>
          <label for="maxFine" class="block text-sm font-medium text-gray-700 mb-1">
            Max Fine (£)
          </label>
          <input
            id="maxFine"
            type="number"
            bind:value={maxFine}
            placeholder="No limit"
            min="0"
            step="100"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
      </div>

      <div class="mt-4 text-sm text-gray-600">
        Showing {filteredData.length} of {$casesQuery.data.length} cases
      </div>
    </div>

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
                        <svelte:component this={flexRender(header.column.columnDef.header, header.getContext())} />
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
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <svelte:component this={flexRender(cell.column.columnDef.cell, cell.getContext())} />
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
