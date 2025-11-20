<script lang="ts">
	import { writable } from 'svelte/store'
	import { browser } from '$app/environment'
	import {
		createSvelteTable,
		getCoreRowModel,
		getPaginationRowModel,
		getSortedRowModel,
		getFilteredRowModel,
		flexRender,
		type ColumnDef,
		type SortingState,
		type VisibilityState,
		type ColumnSizingState,
		type ColumnFiltersState,
		type ColumnOrderState
	} from '@tanstack/svelte-table'
	import {
		DndContext,
		closestCenter,
		PointerSensor,
		useSensor,
		useSensors,
		type DragEndEvent
	} from '@dnd-kit/core'
	import { SortableContext, useSortable, horizontalListSortingStrategy } from '@dnd-kit/sortable'
	import { CSS } from '@dnd-kit/utilities'

	export let data: any[] = []

	// LocalStorage keys
	const VISIBILITY_STORAGE_KEY = 'dashboard_column_visibility'
	const SIZING_STORAGE_KEY = 'dashboard_column_sizing'
	const FILTERS_STORAGE_KEY = 'dashboard_column_filters'
	const ORDER_STORAGE_KEY = 'dashboard_column_order'

	// Column visibility state - load from localStorage
	function loadColumnVisibility(): VisibilityState {
		if (!browser) return {}
		try {
			const saved = localStorage.getItem(VISIBILITY_STORAGE_KEY)
			return saved ? JSON.parse(saved) : {}
		} catch {
			return {}
		}
	}

	function saveColumnVisibility(state: VisibilityState) {
		if (!browser) return
		try {
			localStorage.setItem(VISIBILITY_STORAGE_KEY, JSON.stringify(state))
		} catch (e) {
			console.error('Failed to save column visibility:', e)
		}
	}

	// Column sizing state - load from localStorage
	function loadColumnSizing(): ColumnSizingState {
		if (!browser) return {}
		try {
			const saved = localStorage.getItem(SIZING_STORAGE_KEY)
			return saved ? JSON.parse(saved) : {}
		} catch {
			return {}
		}
	}

	function saveColumnSizing(state: ColumnSizingState) {
		if (!browser) return
		try {
			localStorage.setItem(SIZING_STORAGE_KEY, JSON.stringify(state))
		} catch (e) {
			console.error('Failed to save column sizing:', e)
		}
	}

	// Column filters state - load from localStorage
	function loadColumnFilters(): ColumnFiltersState {
		if (!browser) return []
		try {
			const saved = localStorage.getItem(FILTERS_STORAGE_KEY)
			return saved ? JSON.parse(saved) : []
		} catch {
			return []
		}
	}

	function saveColumnFilters(state: ColumnFiltersState) {
		if (!browser) return
		try {
			localStorage.setItem(FILTERS_STORAGE_KEY, JSON.stringify(state))
		} catch (e) {
			console.error('Failed to save column filters:', e)
		}
	}

	// Column order state - load from localStorage
	function loadColumnOrder(): ColumnOrderState {
		if (!browser) return []
		try {
			const saved = localStorage.getItem(ORDER_STORAGE_KEY)
			return saved ? JSON.parse(saved) : []
		} catch {
			return []
		}
	}

	function saveColumnOrder(state: ColumnOrderState) {
		if (!browser) return
		try {
			localStorage.setItem(ORDER_STORAGE_KEY, JSON.stringify(state))
		} catch (e) {
			console.error('Failed to save column order:', e)
		}
	}

	let sorting = writable<SortingState>([])
	let columnVisibility = writable<VisibilityState>(loadColumnVisibility())
	let columnSizing = writable<ColumnSizingState>(loadColumnSizing())
	let columnFilters = writable<ColumnFiltersState>(loadColumnFilters())
	let columnOrder = writable<ColumnOrderState>(loadColumnOrder())

	// Save to localStorage when visibility, sizing, filters, or order change
	$: if (browser) {
		saveColumnVisibility($columnVisibility)
		saveColumnSizing($columnSizing)
		saveColumnFilters($columnFilters)
		saveColumnOrder($columnOrder)
	}

	// Column picker visibility
	let showColumnPicker = false

	// Helper to format date
	function formatDate(dateStr: string): string {
		if (!dateStr) return '-'
		const date = new Date(dateStr)
		return date.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
	}

	// Column definitions
	const columns: ColumnDef<any>[] = [
		{
			accessorKey: 'type',
			header: 'Type',
			cell: (info) => info.getValue(),
			size: 100
		},
		{
			accessorKey: 'regulator_id',
			header: 'Case ID',
			cell: (info) => info.getValue() || '-',
			size: 120
		},
		{
			accessorKey: 'date',
			header: 'Date',
			cell: (info) => formatDate(info.getValue() as string),
			size: 120
		},
		{
			accessorKey: 'organization',
			header: 'Organization',
			cell: (info) => info.getValue() || '-',
			size: 200
		},
		{
			accessorKey: 'description',
			header: 'Description',
			cell: (info) => info.getValue() || '-',
			size: 300
		},
		{
			accessorKey: 'fine_amount',
			header: 'Fine',
			cell: (info) => info.getValue() || '-',
			size: 120
		},
		{
			accessorKey: 'agency_link',
			header: 'Link',
			cell: (info) => info.getValue(),
			size: 80,
			enableSorting: false
		}
	]

	const options = writable({
		data,
		columns,
		columnResizeMode: 'onChange' as const,
		state: {
			sorting: $sorting,
			columnVisibility: $columnVisibility,
			columnSizing: $columnSizing,
			columnFilters: $columnFilters,
			columnOrder: $columnOrder
		},
		onSortingChange: (updater) => {
			if (updater instanceof Function) {
				sorting.update(updater)
			} else {
				sorting.set(updater)
			}
		},
		onColumnVisibilityChange: (updater) => {
			if (updater instanceof Function) {
				columnVisibility.update(updater)
			} else {
				columnVisibility.set(updater)
			}
		},
		onColumnSizingChange: (updater) => {
			if (updater instanceof Function) {
				columnSizing.update(updater)
			} else {
				columnSizing.set(updater)
			}
		},
		onColumnFiltersChange: (updater) => {
			if (updater instanceof Function) {
				columnFilters.update(updater)
			} else {
				columnFilters.set(updater)
			}
		},
		onColumnOrderChange: (updater) => {
			if (updater instanceof Function) {
				columnOrder.update(updater)
			} else {
				columnOrder.set(updater)
			}
		},
		getCoreRowModel: getCoreRowModel(),
		getSortedRowModel: getSortedRowModel(),
		getFilteredRowModel: getFilteredRowModel(),
		getPaginationRowModel: getPaginationRowModel()
	})

	$: options.update((old) => ({
		...old,
		data,
		state: {
			sorting: $sorting,
			columnVisibility: $columnVisibility,
			columnSizing: $columnSizing,
			columnFilters: $columnFilters,
			columnOrder: $columnOrder
		}
	}))

	const table = createSvelteTable(options)

	function toggleAllColumns(show: boolean) {
		$table.getAllLeafColumns().forEach((column) => {
			column.toggleVisibility(show)
		})
	}

	// Helper to get unique values for Type filter
	$: uniqueTypes = Array.from(new Set(data.map((row) => row.type).filter(Boolean))).sort()

	// Clear all filters
	function clearAllFilters() {
		columnFilters.set([])
	}

	// Check if any filters are active
	$: hasActiveFilters = $columnFilters.length > 0

	// DND Kit sensors for drag and drop
	const sensors = useSensors(useSensor(PointerSensor))

	// Handle column reordering
	function handleDragEnd(event: DragEndEvent) {
		const { active, over } = event

		if (over && active.id !== over.id) {
			const oldIndex = $columnOrder.indexOf(active.id as string)
			const newIndex = $columnOrder.indexOf(over.id as string)

			// Reorder the column order array
			const newColumnOrder = [...$columnOrder]
			const [movedColumn] = newColumnOrder.splice(oldIndex, 1)
			newColumnOrder.splice(newIndex, 0, movedColumn)

			columnOrder.set(newColumnOrder)
		}
	}

	// Initialize column order if empty
	$: if ($columnOrder.length === 0 && columns.length > 0) {
		columnOrder.set(columns.map((col) => col.accessorKey || col.id) as string[])
	}
</script>


<div class="space-y-4">
	<!-- Filters and Column Picker -->
	<div class="flex items-end justify-between gap-4">
		<!-- Column Filters -->
		<div class="flex-1">
			{#if hasActiveFilters}
				<div class="mb-1 flex justify-end">
					<button
						on:click={clearAllFilters}
						class="text-xs text-indigo-600 hover:text-indigo-900"
					>
						Clear All Filters
					</button>
				</div>
			{/if}
			<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
				<!-- Type Filter -->
				<div>
					<label for="type-filter" class="block text-xs font-medium text-gray-700 mb-1">
						Type
					</label>
					<select
						id="type-filter"
						value={$table.getColumn('type')?.getFilterValue() ?? ''}
						on:change={(e) => $table.getColumn('type')?.setFilterValue(e.currentTarget.value || undefined)}
						class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
					>
						<option value="">All Types</option>
						{#each uniqueTypes as type}
							<option value={type}>{type}</option>
						{/each}
					</select>
				</div>

				<!-- Organization Filter -->
				<div>
					<label for="org-filter" class="block text-xs font-medium text-gray-700 mb-1">
						Organization
					</label>
					<input
						id="org-filter"
						type="text"
						value={$table.getColumn('organization')?.getFilterValue() ?? ''}
						on:input={(e) => $table.getColumn('organization')?.setFilterValue(e.currentTarget.value || undefined)}
						placeholder="Search organizations..."
						class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
					/>
				</div>

				<!-- Fine Amount Filter -->
				<div>
					<label for="fine-filter" class="block text-xs font-medium text-gray-700 mb-1">
						Fine Amount
					</label>
					<input
						id="fine-filter"
						type="text"
						value={$table.getColumn('fine_amount')?.getFilterValue() ?? ''}
						on:input={(e) => $table.getColumn('fine_amount')?.setFilterValue(e.currentTarget.value || undefined)}
						placeholder="Search fines..."
						class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
					/>
				</div>

				<!-- Description Filter -->
				<div>
					<label for="desc-filter" class="block text-xs font-medium text-gray-700 mb-1">
						Description
					</label>
					<input
						id="desc-filter"
						type="text"
						value={$table.getColumn('description')?.getFilterValue() ?? ''}
						on:input={(e) => $table.getColumn('description')?.setFilterValue(e.currentTarget.value || undefined)}
						placeholder="Search descriptions..."
						class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
					/>
				</div>
			</div>
		</div>

		<!-- Column Visibility Picker -->
		<div class="flex-shrink-0">
		<div class="relative">
			<button
				on:click={() => (showColumnPicker = !showColumnPicker)}
				class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
			>
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						stroke-width="2"
						d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4"
					/>
				</svg>
				Columns
			</button>

			{#if showColumnPicker}
				<!-- svelte-ignore a11y-click-events-have-key-events -->
				<!-- svelte-ignore a11y-no-static-element-interactions -->
				<div
					class="fixed inset-0 z-10"
					on:click={() => (showColumnPicker = false)}
				/>
				<div
					class="absolute right-0 z-20 mt-2 w-56 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5"
				>
					<div class="py-1" role="menu">
						<div class="px-4 py-2 border-b border-gray-200">
							<div class="flex items-center justify-between">
								<span class="text-sm font-medium text-gray-900">Toggle Columns</span>
								<div class="flex gap-1">
									<button
										on:click={() => toggleAllColumns(true)}
										class="text-xs text-indigo-600 hover:text-indigo-900"
									>
										Show All
									</button>
									<span class="text-gray-300">|</span>
									<button
										on:click={() => toggleAllColumns(false)}
										class="text-xs text-indigo-600 hover:text-indigo-900"
									>
										Hide All
									</button>
								</div>
							</div>
						</div>
						<div class="max-h-64 overflow-y-auto">
							{#each $table.getAllLeafColumns() as column}
								<label
									class="flex items-center px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 cursor-pointer"
								>
									<input
										type="checkbox"
										checked={column.getIsVisible()}
										on:change={() => column.toggleVisibility()}
										class="mr-3 h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
									/>
									<span>{column.columnDef.header}</span>
								</label>
							{/each}
						</div>
					</div>
				</div>
			{/if}
		</div>
		</div>
	</div>

	<!-- Table -->
	{#if data.length === 0}
		<div class="px-4 py-8 text-center text-gray-500 bg-white rounded-lg border border-gray-200">
			<p>No recent activity found for this time period.</p>
		</div>
	{:else}
		<DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
			<div class="overflow-x-auto bg-white shadow rounded-lg">
				<table class="min-w-full divide-y divide-gray-200">
					<thead class="bg-gray-50">
						{#each $table.getHeaderGroups() as headerGroup}
							<tr>
								<SortableContext items={$columnOrder} strategy={horizontalListSortingStrategy}>
									{#each headerGroup.headers as header}
										{#each [useSortable({ id: header.column.id })] as sortable}
											<th
												use:sortable.setNodeRef
												scope="col"
												class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider relative"
												style="width: {header.getSize()}px; transform: {CSS.Transform.toString(sortable.transform)}; transition: {sortable.transition}; opacity: {sortable.isDragging ? 0.5 : 1}; cursor: {sortable.isDragging ? 'grabbing' : 'grab'}"
												{...sortable.attributes}
												{...sortable.listeners}
											>
												{#if !header.isPlaceholder}
													<div class="flex items-center gap-1">
														<button
															class="flex items-center gap-1 hover:text-gray-700 {header.column.getCanSort()
																? 'cursor-pointer select-none'
																: ''}"
															on:click={header.column.getToggleSortingHandler()}
														>
															<svelte:component
																this={flexRender(header.column.columnDef.header, header.getContext())}
															/>
															{#if header.column.getCanSort()}
																<span class="text-gray-400">
																	{{
																		asc: '↑',
																		desc: '↓'
																	}[header.column.getIsSorted()] ?? '↕'}
																</span>
															{/if}
														</button>
													</div>
													<!-- Resize Handle -->
													{#if header.column.getCanResize()}
														<!-- svelte-ignore a11y-no-static-element-interactions -->
														<div
															on:mousedown={header.getResizeHandler()}
															on:touchstart={header.getResizeHandler()}
															class="absolute top-0 right-0 h-full w-1 cursor-col-resize select-none touch-none bg-transparent hover:bg-indigo-500 {header.column.getIsResizing()
																? 'bg-indigo-500 opacity-100'
																: 'opacity-0 hover:opacity-100'}"
															style="user-select: none; touch-action: none;"
														/>
													{/if}
												{/if}
											</th>
										{/each}
									{/each}
								</SortableContext>
							</tr>
						{/each}
					</thead>
				<tbody class="bg-white divide-y divide-gray-200">
					{#each $table.getRowModel().rows as row}
						<tr class="hover:bg-gray-50">
							{#each row.getVisibleCells() as cell}
								<td class="px-6 py-4 text-sm text-gray-900">
									{#if cell.column.id === 'type'}
										<span
											class="inline-flex px-2 py-1 text-xs font-semibold rounded-full {cell.row.original
												.is_case
												? 'bg-green-100 text-green-800'
												: 'bg-blue-100 text-blue-800'}"
										>
											<svelte:component
												this={flexRender(cell.column.columnDef.cell, cell.getContext())}
											/>
										</span>
									{:else if cell.column.id === 'agency_link'}
										{#if cell.getValue()}
											<a
												href={cell.getValue()}
												target="_blank"
												rel="noopener noreferrer"
												class="text-indigo-600 hover:text-indigo-900"
											>
												<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path
														stroke-linecap="round"
														stroke-linejoin="round"
														stroke-width="2"
														d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
													/>
												</svg>
											</a>
										{:else}
											<span class="text-gray-400">-</span>
										{/if}
									{:else if cell.column.id === 'organization' || cell.column.id === 'description'}
										<div class="max-w-xs truncate" title={cell.getValue()}>
											<svelte:component
												this={flexRender(cell.column.columnDef.cell, cell.getContext())}
											/>
										</div>
									{:else}
										<svelte:component
											this={flexRender(cell.column.columnDef.cell, cell.getContext())}
										/>
									{/if}
								</td>
							{/each}
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	</DndContext>

		<!-- Pagination -->
		<div class="bg-white px-4 py-3 flex items-center justify-between border-t border-gray-200 rounded-b-lg">
			<div class="flex-1 flex justify-between sm:hidden">
				<button
					on:click={() => $table.previousPage()}
					disabled={!$table.getCanPreviousPage()}
					class="relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
				>
					Previous
				</button>
				<button
					on:click={() => $table.nextPage()}
					disabled={!$table.getCanNextPage()}
					class="ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
				>
					Next
				</button>
			</div>
			<div class="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
				<div>
					<p class="text-sm text-gray-700">
						Showing
						<span class="font-medium"
							>{$table.getState().pagination.pageIndex *
								$table.getState().pagination.pageSize +
								1}</span
						>
						to
						<span class="font-medium"
							>{Math.min(
								($table.getState().pagination.pageIndex + 1) *
									$table.getState().pagination.pageSize,
								$table.getFilteredRowModel().rows.length
							)}</span
						>
						of
						<span class="font-medium">{$table.getFilteredRowModel().rows.length}</span>
						results
					</p>
				</div>
				<div>
					<nav class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px">
						<button
							on:click={() => $table.previousPage()}
							disabled={!$table.getCanPreviousPage()}
							class="relative inline-flex items-center px-2 py-2 rounded-l-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							<svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M15 19l-7-7 7-7"
								/>
							</svg>
						</button>
						<span
							class="relative inline-flex items-center px-4 py-2 border border-gray-300 bg-white text-sm font-medium text-gray-700"
						>
							Page {$table.getState().pagination.pageIndex + 1} of {$table.getPageCount()}
						</span>
						<button
							on:click={() => $table.nextPage()}
							disabled={!$table.getCanNextPage()}
							class="relative inline-flex items-center px-2 py-2 rounded-r-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							<svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M9 5l7 7-7 7"
								/>
							</svg>
						</button>
					</nav>
				</div>
			</div>
		</div>
	{/if}
</div>
