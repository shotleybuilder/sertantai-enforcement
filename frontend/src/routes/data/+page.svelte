<script lang="ts">
	import { TableKit } from '@shotleybuilder/svelte-table-kit'
	import type { ColumnDef } from '@tanstack/svelte-table'
	import { useUnifiedData, type UnifiedRecord } from '$lib/query/unified'

	// Fetch unified data with default parameters
	const unifiedData = useUnifiedData({
		limit: 100,
		offset: 0,
		order_by: 'offence_action_date',
		order: 'desc'
	})

	// Helper to format date
	function formatDate(dateStr: string | null): string {
		if (!dateStr) return '-'
		const date = new Date(dateStr)
		return date.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
	}

	// Helper to format currency
	function formatCurrency(amount: number | null): string {
		if (amount === null || amount === undefined) return '-'
		return new Intl.NumberFormat('en-GB', {
			style: 'currency',
			currency: 'GBP',
			minimumFractionDigits: 0,
			maximumFractionDigits: 0
		}).format(amount)
	}

	// Complete column definitions for unified table
	const columns: ColumnDef<UnifiedRecord>[] = [
		// Record Type - Always visible, grouped first
		{
			id: 'record_type',
			accessorKey: 'record_type',
			header: 'Type',
			cell: (info) => info.getValue(),
			size: 100,
			enableGrouping: true,
			meta: { sourceTable: 'common', group: 'Core' }
		},

		// Common Fields
		{
			accessorKey: 'regulator_id',
			header: 'Regulator ID',
			cell: (info) => info.getValue() || '-',
			size: 150,
			meta: { sourceTable: 'common', group: 'Core' }
		},
		{
			accessorKey: 'offence_action_date',
			header: 'Action Date',
			cell: (info) => formatDate(info.getValue() as string),
			size: 120,
			meta: { sourceTable: 'common', group: 'Core' }
		},
		{
			accessorKey: 'offence_action_type',
			header: 'Action Type',
			cell: (info) => info.getValue() || '-',
			size: 150,
			enableGrouping: true,
			meta: { sourceTable: 'common', group: 'Core' }
		},
		{
			accessorKey: 'offence_breaches',
			header: 'Breaches',
			cell: (info) => info.getValue() || '-',
			size: 300,
			meta: { sourceTable: 'common', group: 'Core' }
		},
		{
			accessorKey: 'regulator_function',
			header: 'Regulator Function',
			cell: (info) => info.getValue() || '-',
			size: 150,
			enableGrouping: true,
			meta: { sourceTable: 'common', group: 'Common' }
		},
		{
			accessorKey: 'environmental_impact',
			header: 'Environmental Impact',
			cell: (info) => info.getValue() || '-',
			size: 180,
			meta: { sourceTable: 'common', group: 'Common' }
		},
		{
			accessorKey: 'environmental_receptor',
			header: 'Environmental Receptor',
			cell: (info) => info.getValue() || '-',
			size: 180,
			meta: { sourceTable: 'common', group: 'Common' }
		},
		{
			id: 'url',
			accessorKey: 'url',
			header: 'Link',
			cell: (info) => (info.getValue() ? '🔗' : '-'),
			size: 80,
			enableSorting: false,
			meta: { sourceTable: 'common', group: 'Common' }
		},

		// Case-Specific Fields
		{
			accessorKey: 'case_reference',
			header: 'Case Reference',
			cell: (info) => info.getValue() || '-',
			size: 150,
			meta: { sourceTable: 'cases', group: 'Case Fields' }
		},
		{
			accessorKey: 'offence_result',
			header: 'Result',
			cell: (info) => info.getValue() || '-',
			size: 120,
			enableGrouping: true,
			meta: { sourceTable: 'cases', group: 'Case Fields' }
		},
		{
			accessorKey: 'offence_fine',
			header: 'Fine',
			cell: (info) => formatCurrency(info.getValue() as number),
			size: 120,
			meta: { sourceTable: 'cases', group: 'Case Fields' }
		},
		{
			accessorKey: 'offence_costs',
			header: 'Costs',
			cell: (info) => formatCurrency(info.getValue() as number),
			size: 120,
			meta: { sourceTable: 'cases', group: 'Case Fields' }
		},
		{
			accessorKey: 'offence_hearing_date',
			header: 'Hearing Date',
			cell: (info) => formatDate(info.getValue() as string),
			size: 120,
			meta: { sourceTable: 'cases', group: 'Case Fields' }
		},
		{
			accessorKey: 'related_cases',
			header: 'Related Cases',
			cell: (info) => {
				const val = info.getValue() as string[] | null
				return val && val.length > 0 ? val.join(', ') : '-'
			},
			size: 150,
			enableSorting: false,
			meta: { sourceTable: 'cases', group: 'Case Fields' }
		},

		// Notice-Specific Fields
		{
			accessorKey: 'notice_date',
			header: 'Notice Date',
			cell: (info) => formatDate(info.getValue() as string),
			size: 120,
			meta: { sourceTable: 'notices', group: 'Notice Fields' }
		},
		{
			accessorKey: 'notice_body',
			header: 'Notice Body',
			cell: (info) => info.getValue() || '-',
			size: 300,
			meta: { sourceTable: 'notices', group: 'Notice Fields' }
		},
		{
			accessorKey: 'operative_date',
			header: 'Operative Date',
			cell: (info) => formatDate(info.getValue() as string),
			size: 120,
			meta: { sourceTable: 'notices', group: 'Notice Fields' }
		},
		{
			accessorKey: 'compliance_date',
			header: 'Compliance Date',
			cell: (info) => formatDate(info.getValue() as string),
			size: 120,
			meta: { sourceTable: 'notices', group: 'Notice Fields' }
		},
		{
			accessorKey: 'regulator_ref_number',
			header: 'Regulator Ref',
			cell: (info) => info.getValue() || '-',
			size: 150,
			meta: { sourceTable: 'notices', group: 'Notice Fields' }
		},

		// Timestamps
		{
			accessorKey: 'inserted_at',
			header: 'Created',
			cell: (info) => formatDate(info.getValue() as string),
			size: 120,
			meta: { sourceTable: 'common', group: 'Timestamps' }
		},
		{
			accessorKey: 'updated_at',
			header: 'Updated',
			cell: (info) => formatDate(info.getValue() as string),
			size: 120,
			meta: { sourceTable: 'common', group: 'Timestamps' }
		}
	]
</script>

<div class="container mx-auto px-4 py-8">
	<div class="mb-6">
		<h1 class="text-3xl font-bold text-gray-900 mb-2">Enforcement Data</h1>
		<p class="text-gray-600">
			Unified view of Cases and Notices with flexible filtering, sorting, and grouping
		</p>
	</div>

	{#if $unifiedData.isLoading}
		<div class="px-4 py-12 text-center bg-white rounded-lg border border-gray-200">
			<div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
			<p class="mt-4 text-gray-600">Loading enforcement data...</p>
		</div>
	{:else if $unifiedData.isError}
		<div class="px-4 py-8 bg-red-50 border border-red-200 rounded-lg">
			<h3 class="text-lg font-semibold text-red-800 mb-2">Error Loading Data</h3>
			<p class="text-red-600">{$unifiedData.error?.message || 'Unknown error occurred'}</p>
		</div>
	{:else if $unifiedData.data}
		<!-- Stats Overview -->
		<div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
			<div class="bg-white rounded-lg border border-gray-200 px-4 py-3">
				<div class="text-sm text-gray-600">Total Records</div>
				<div class="text-2xl font-bold text-gray-900">
					{$unifiedData.data.meta.total_count.toLocaleString()}
				</div>
			</div>
			<div class="bg-white rounded-lg border border-gray-200 px-4 py-3">
				<div class="text-sm text-gray-600">Cases</div>
				<div class="text-2xl font-bold text-green-600">
					{$unifiedData.data.meta.cases_count.toLocaleString()}
				</div>
			</div>
			<div class="bg-white rounded-lg border border-gray-200 px-4 py-3">
				<div class="text-sm text-gray-600">Notices</div>
				<div class="text-2xl font-bold text-blue-600">
					{$unifiedData.data.meta.notices_count.toLocaleString()}
				</div>
			</div>
			<div class="bg-white rounded-lg border border-gray-200 px-4 py-3">
				<div class="text-sm text-gray-600">Showing</div>
				<div class="text-2xl font-bold text-gray-900">
					{$unifiedData.data.data.length.toLocaleString()}
				</div>
			</div>
		</div>

		<!-- Unified Data Table -->
		<TableKit
			data={$unifiedData.data.data}
			{columns}
			storageKey="unified_data_table"
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
				{#if column === 'record_type'}
					<span
						class="inline-flex px-2 py-1 text-xs font-semibold rounded-full {cell.getValue() ===
						'case'
							? 'bg-green-100 text-green-800'
							: 'bg-blue-100 text-blue-800'}"
					>
						{cell.getValue() === 'case' ? 'Case' : 'Notice'}
					</span>
				{:else if column === 'url' && cell.getValue()}
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
				{:else if column === 'offence_breaches' || column === 'notice_body'}
					<div class="max-w-md truncate" title={cell.getValue()}>
						{cell.getValue()}
					</div>
				{:else}
					{cell.getValue()}
				{/if}
			</svelte:fragment>
		</TableKit>
	{/if}
</div>
