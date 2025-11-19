<script lang="ts">
	import { onMount } from 'svelte'
	import {
		initLegislationSync,
		stopLegislationSync,
		cachedLegislation,
		legislationSyncProgress,
	} from '$lib/electric/sync-legislation'
	import type { Legislation } from '$lib/db/schema'
	import {
		createSvelteTable,
		getCoreRowModel,
		getSortedRowModel,
		getFilteredRowModel,
		getPaginationRowModel,
		type ColumnDef,
		type SortingState,
		type PaginationState,
	} from '@tanstack/svelte-table'

	// Reactive data
	$: data = $cachedLegislation || []
	$: syncProgress = $legislationSyncProgress
	$: loading = syncProgress.phase === 'syncing'

	// Table state
	let sorting: SortingState = [{ id: 'legislation_year', desc: true }]
	let pagination: PaginationState = { pageIndex: 0, pageSize: 20 }

	// Filters
	let searchTerm = ''
	let typeFilter = ''

	// Filtered data
	$: filteredData = data.filter((leg) => {
		// Search filter
		if (searchTerm && !leg.legislation_title.toLowerCase().includes(searchTerm.toLowerCase())) {
			return false
		}
		// Type filter
		if (typeFilter && leg.legislation_type !== typeFilter) {
			return false
		}
		return true
	})

	// Column definitions
	const columns: ColumnDef<Legislation>[] = [
		{
			accessorKey: 'legislation_title',
			header: 'Title',
			cell: (info) => info.getValue(),
			enableSorting: true,
		},
		{
			accessorKey: 'legislation_year',
			header: 'Year',
			cell: (info) => info.getValue() || '—',
			enableSorting: true,
		},
		{
			accessorKey: 'legislation_number',
			header: 'Number',
			cell: (info) => info.getValue() || '—',
			enableSorting: true,
		},
		{
			accessorKey: 'legislation_type',
			header: 'Type',
			cell: (info) => {
				const type = info.getValue() as string
				return formatLegislationType(type)
			},
			enableSorting: true,
		},
		{
			id: 'actions',
			header: 'Actions',
			cell: (info) => {
				const leg = info.row.original
				return `<a href="/legislation/${leg.id}" class="text-blue-600 hover:text-blue-800 hover:underline">View Details</a>`
			},
		},
	]

	// TanStack Table instance
	$: table = createSvelteTable({
		get data() {
			return filteredData
		},
		columns,
		state: {
			get sorting() {
				return sorting
			},
			get pagination() {
				return pagination
			},
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

	// Initialize sync on mount
	onMount(async () => {
		try {
			await initLegislationSync()
		} catch (error) {
			console.error('[Legislation Page] Sync initialization failed:', error)
		}

		// Cleanup on unmount
		return () => {
			stopLegislationSync()
		}
	})

	// Helpers
	function formatLegislationType(type: string): string {
		const types: Record<string, string> = {
			act: 'Act',
			regulation: 'Regulation',
			order: 'Order',
			acop: 'ACOP',
		}
		return types[type] || type
	}

	function getLegislationTypeBadgeClass(type: string): string {
		const classes: Record<string, string> = {
			act: 'bg-blue-100 text-blue-800',
			regulation: 'bg-green-100 text-green-800',
			order: 'bg-yellow-100 text-yellow-800',
			acop: 'bg-purple-100 text-purple-800',
		}
		return classes[type] || 'bg-gray-100 text-gray-800'
	}
</script>

<svelte:head>
	<title>Legislation | EHS Enforcement Tracker</title>
	<meta
		name="description"
		content="UK environmental, health, and safety legislation reference"
	/>
</svelte:head>

<div class="container mx-auto px-4 py-8 max-w-7xl">
	<!-- Header -->
	<div class="mb-8">
		<h1 class="text-3xl font-bold text-gray-900 mb-2">Legislation</h1>
		<p class="text-gray-600">UK Acts, Regulations, and Orders referenced in enforcement actions</p>
	</div>

	<!-- Sync Progress Banner -->
	{#if loading}
		<div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
			<div class="flex items-center gap-3">
				<div class="animate-spin">
					<svg class="h-5 w-5 text-blue-600" viewBox="0 0 24 24">
						<circle
							class="opacity-25"
							cx="12"
							cy="12"
							r="10"
							stroke="currentColor"
							stroke-width="4"
							fill="none"
						></circle>
						<path
							class="opacity-75"
							fill="currentColor"
							d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
						></path>
					</svg>
				</div>
				<span class="text-blue-800 font-medium">Loading legislation...</span>
			</div>
		</div>
	{/if}

	<!-- Error State -->
	{#if syncProgress.error}
		<div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
			<p class="text-red-800">
				<strong>Error:</strong>
				{syncProgress.error}
			</p>
		</div>
	{/if}

	<!-- Stats Card -->
	{#if data.length > 0}
		<div class="bg-white border border-gray-200 rounded-lg p-6 mb-6 shadow-sm">
			<div class="grid grid-cols-1 md:grid-cols-4 gap-6">
				<div>
					<p class="text-sm text-gray-600 mb-1">Total Legislation</p>
					<p class="text-3xl font-bold text-gray-900">{data.length}</p>
				</div>
				<div>
					<p class="text-sm text-gray-600 mb-1">Acts</p>
					<p class="text-3xl font-bold text-blue-600">
						{data.filter((l) => l.legislation_type === 'act').length}
					</p>
				</div>
				<div>
					<p class="text-sm text-gray-600 mb-1">Regulations</p>
					<p class="text-3xl font-bold text-green-600">
						{data.filter((l) => l.legislation_type === 'regulation').length}
					</p>
				</div>
				<div>
					<p class="text-sm text-gray-600 mb-1">Filtered Results</p>
					<p class="text-3xl font-bold text-gray-900">{filteredData.length}</p>
				</div>
			</div>
		</div>
	{/if}

	<!-- Empty State -->
	{#if !loading && data.length === 0}
		<div
			class="bg-gradient-to-br from-blue-50 to-indigo-50 border-2 border-blue-200 rounded-lg p-12 text-center"
		>
			<div class="text-6xl mb-4">📚</div>
			<h2 class="text-2xl font-bold text-gray-900 mb-3">No Legislation Found</h2>
			<p class="text-gray-600 max-w-2xl mx-auto mb-6">
				The legislation database is currently empty. Legislation data will appear here when
				populated. This section will contain Acts, Regulations, Orders, and ACOPs referenced in
				enforcement actions.
			</p>
			<div class="bg-white border border-blue-200 rounded-lg p-6 max-w-xl mx-auto text-left">
				<h3 class="font-semibold text-gray-900 mb-2">Examples of Legislation:</h3>
				<ul class="text-sm text-gray-700 space-y-1">
					<li>• Health and Safety at Work etc. Act 1974</li>
					<li>• The Construction (Design and Management) Regulations 2015</li>
					<li>• The Work at Height Regulations 2005</li>
					<li>• The Management of Health and Safety at Work Regulations 1999</li>
				</ul>
			</div>
		</div>
	{/if}

	<!-- Filter Panel -->
	{#if data.length > 0}
		<div class="bg-white border border-gray-200 rounded-lg p-6 mb-6 shadow-sm">
			<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
				<!-- Search Input -->
				<div>
					<label for="search" class="block text-sm font-medium text-gray-700 mb-2">
						Search Title
					</label>
					<input
						id="search"
						type="text"
						bind:value={searchTerm}
						placeholder="e.g., Health and Safety"
						class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					/>
				</div>

				<!-- Type Filter -->
				<div>
					<label for="type" class="block text-sm font-medium text-gray-700 mb-2">
						Legislation Type
					</label>
					<select
						id="type"
						bind:value={typeFilter}
						class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					>
						<option value="">All Types</option>
						<option value="act">Act</option>
						<option value="regulation">Regulation</option>
						<option value="order">Order</option>
						<option value="acop">ACOP</option>
					</select>
				</div>
			</div>

			<!-- Clear Filters -->
			{#if searchTerm || typeFilter}
				<button
					on:click={() => {
						searchTerm = ''
						typeFilter = ''
					}}
					class="mt-4 px-4 py-2 text-sm text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors duration-200"
				>
					Clear Filters
				</button>
			{/if}
		</div>

		<!-- Table -->
		<div class="bg-white border border-gray-200 rounded-lg shadow-sm overflow-hidden">
			<div class="overflow-x-auto">
				<table class="min-w-full divide-y divide-gray-200">
					<thead class="bg-gray-50">
						{#each table.getHeaderGroups() as headerGroup}
							<tr>
								{#each headerGroup.headers as header}
									<th
										class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
										on:click={header.column.getToggleSortingHandler()}
									>
										<div class="flex items-center gap-2">
											{#if !header.isPlaceholder}
												{header.column.columnDef.header}
											{/if}
											{#if header.column.getIsSorted()}
												<span class="text-blue-600">
													{header.column.getIsSorted() === 'desc' ? '↓' : '↑'}
												</span>
											{/if}
										</div>
									</th>
								{/each}
							</tr>
						{/each}
					</thead>
					<tbody class="bg-white divide-y divide-gray-200">
						{#each table.getRowModel().rows as row}
							<tr class="hover:bg-gray-50">
								{#each row.getVisibleCells() as cell}
									<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
										{@html cell.column.columnDef.cell(cell.getContext())}
									</td>
								{/each}
							</tr>
						{/each}
					</tbody>
				</table>
			</div>

			<!-- Pagination -->
			<div class="bg-gray-50 px-6 py-4 border-t border-gray-200">
				<div class="flex items-center justify-between">
					<div class="flex items-center gap-2">
						<button
							on:click={() => table.setPageIndex(0)}
							disabled={!table.getCanPreviousPage()}
							class="px-3 py-1 text-sm border border-gray-300 rounded disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-100"
						>
							««
						</button>
						<button
							on:click={() => table.previousPage()}
							disabled={!table.getCanPreviousPage()}
							class="px-3 py-1 text-sm border border-gray-300 rounded disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-100"
						>
							«
						</button>
						<button
							on:click={() => table.nextPage()}
							disabled={!table.getCanNextPage()}
							class="px-3 py-1 text-sm border border-gray-300 rounded disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-100"
						>
							»
						</button>
						<button
							on:click={() => table.setPageIndex(table.getPageCount() - 1)}
							disabled={!table.getCanNextPage()}
							class="px-3 py-1 text-sm border border-gray-300 rounded disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-100"
						>
							»»
						</button>
					</div>

					<div class="flex items-center gap-4">
						<span class="text-sm text-gray-700">
							Page {table.getState().pagination.pageIndex + 1} of {table.getPageCount()}
						</span>
						<select
							value={table.getState().pagination.pageSize}
							on:change={(e) => table.setPageSize(Number(e.currentTarget.value))}
							class="px-2 py-1 text-sm border border-gray-300 rounded"
						>
							{#each [20, 50, 100] as pageSize}
								<option value={pageSize}>
									Show {pageSize}
								</option>
							{/each}
						</select>
					</div>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	/* Mobile responsive adjustments */
	@media (max-width: 768px) {
		.container {
			padding-left: 1rem;
			padding-right: 1rem;
		}

		table {
			font-size: 0.875rem;
		}

		th,
		td {
			padding: 0.5rem 0.75rem;
		}
	}
</style>
