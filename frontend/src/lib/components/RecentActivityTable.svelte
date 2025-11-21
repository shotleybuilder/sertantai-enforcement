<script lang="ts">
	import { TableKit } from '@shotleybuilder/svelte-table-kit'
	import type { ColumnDef } from '@tanstack/svelte-table'

	export let data: any[] = []

	// Helper to format date
	function formatDate(dateStr: string): string {
		if (!dateStr) return '-'
		const date = new Date(dateStr)
		return date.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
	}

	// Column definitions - use simple string returns, not HTML
	const columns: ColumnDef<any>[] = [
		{
			accessorKey: 'type',
			header: 'Type',
			cell: (info) => info.getValue(),
			size: 100,
			enableGrouping: false
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
			size: 200,
			enableGrouping: true
		},
		{
			accessorKey: 'description',
			header: 'Description',
			cell: (info) => info.getValue() || '-',
			size: 300,
			enableGrouping: false
		},
		{
			accessorKey: 'fine_amount',
			header: 'Fine',
			cell: (info) => info.getValue() || '-',
			size: 120,
			enableGrouping: false
		},
		{
			id: 'agency_link',
			accessorKey: 'agency_link',
			header: 'Link',
			cell: (info) => info.getValue() ? '🔗' : '-',
			size: 80,
			enableSorting: false,
			enableGrouping: false
		}
	]
</script>

{#if data.length === 0}
	<div class="px-4 py-8 text-center text-gray-500 bg-white rounded-lg border border-gray-200">
		<p>No recent activity found for this time period.</p>
	</div>
{:else}
	<TableKit
		{data}
		{columns}
		storageKey="dashboard_recent_activity"
		persistState={true}
		features={{
			columnVisibility: true,
			columnResizing: true,
			columnReordering: true,
			filtering: true,
			sorting: true,
			pagination: true,
			grouping: true
		}}
	>
		<svelte:fragment slot="cell" let:cell let:column>
			{#if column === 'type'}
				<span
					class="inline-flex px-2 py-1 text-xs font-semibold rounded-full {cell.row.original
						.is_case
						? 'bg-green-100 text-green-800'
						: 'bg-blue-100 text-blue-800'}"
				>
					{cell.getValue()}
				</span>
			{:else if column === 'agency_link' && cell.getValue()}
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
			{:else if column === 'organization' || column === 'description'}
				<div class="max-w-xs truncate" title={cell.getValue()}>
					{cell.getValue()}
				</div>
			{:else}
				{cell.getValue()}
			{/if}
		</svelte:fragment>
	</TableKit>
{/if}
