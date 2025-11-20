<script lang="ts">
	import { browser } from '$app/environment'
	import { goto } from '$app/navigation'
	import LineChart from '$lib/components/reports/charts/LineChart.svelte'
	import BarChart from '$lib/components/reports/charts/BarChart.svelte'
	import PieChart from '$lib/components/reports/charts/PieChart.svelte'
	import {
		groupCasesByTime,
		groupByAndSum,
		groupByAndCount,
		bucketByRange,
		calculateStats,
		formatCurrency,
		formatNumber
	} from '$lib/reports/aggregations'
	import { useCasesQuery } from '$lib/query/cases'
	import type { TimePeriod } from '$lib/reports/aggregations'

	// Query cases data (only in browser, not SSR)
	const casesQuery = browser ? useCasesQuery() : null

	// Reactive data access using $derived
	let cases = $derived(casesQuery ? $casesQuery.data || [] : [])
	let isLoading = $derived(casesQuery ? $casesQuery.isLoading : true)
	let error = $derived(casesQuery ? $casesQuery.error : null)

	// Filter state
	let period: TimePeriod = $state('month')
	let selectedAgency: string = $state('all')
	let selectedResult: string = $state('all')
	let dateRange = $state({ start: '', end: '' })

	// Filtered cases using $derived
	let filteredCases = $derived(
		cases.filter((c) => {
			if (selectedAgency !== 'all' && c.agency_id !== selectedAgency) return false
			if (selectedResult !== 'all' && c.offence_result !== selectedResult) return false
			if (dateRange.start && c.offence_action_date < dateRange.start) return false
			if (dateRange.end && c.offence_action_date > dateRange.end) return false
			return true
		})
	)

	// Chart 1.1: Cases Over Time using $derived
	let casesOverTime = $derived(
		groupCasesByTime(filteredCases, 'offence_action_date', period).map((d) => ({
			date: d.date,
			value: d.count
		}))
	)

	// Chart 1.2: Top 10 Offenders by Fine Amount using $derived
	let topOffenders = $derived.by(() => {
		const byOffender = groupByAndSum(filteredCases, 'offender_name', 'offence_fine')
		return byOffender
			.sort((a, b) => b.value - a.value)
			.slice(0, 10)
			.map((d) => ({
				name: d.name.slice(0, 40) + (d.name.length > 40 ? '...' : ''),
				value: d.value
			}))
	})

	// Chart 1.3: Enforcement by Agency using $derived
	let byAgency = $derived(groupByAndCount(filteredCases, 'agency_name'))

	// Chart 1.4: Fine Distribution using $derived
	let fineDistribution = $derived(
		bucketByRange(filteredCases, 'offence_fine', [
			{ min: 0, max: 5000, label: '£0-5k' },
			{ min: 5000, max: 10000, label: '£5k-10k' },
			{ min: 10000, max: 25000, label: '£10k-25k' },
			{ min: 25000, max: 50000, label: '£25k-50k' },
			{ min: 50000, max: 100000, label: '£50k-100k' },
			{ min: 100000, max: Infinity, label: '£100k+' }
		]).map((d) => ({
			name: d.label,
			value: d.count
		}))
	)

	// Summary stats using $derived
	let stats = $derived(calculateStats(filteredCases, 'offence_fine'))

	// Handle chart click - drill down to cases
	function handleCasesOverTimeClick(params: any) {
		const month = params.name
		goto(`/cases?date=${month}`)
	}

	function handleOffenderClick(params: any) {
		// Would need offender ID here - for now just navigate to offenders
		goto(`/offenders`)
	}

	function handleAgencyClick(params: any) {
		// Would filter by agency
		selectedAgency = params.name
	}

	// Export functionality
	function exportToPNG() {
		// TODO: Implement chart export
		alert('Export to PNG - Coming soon!')
	}

	function exportToCSV() {
		// TODO: Implement CSV export
		alert('Export to CSV - Coming soon!')
	}
</script>

<svelte:head>
	<title>Reports & Analytics | EHS Enforcement Tracker</title>
	<meta
		name="description"
		content="View enforcement trends, statistics, and analytics for UK health, safety, and environmental enforcement"
	/>
</svelte:head>

<div class="min-h-screen bg-gray-50 py-8">
	<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
		<!-- Header -->
		<div class="mb-8">
			<h1 class="text-3xl font-bold text-gray-900">Enforcement Trends Dashboard</h1>
			<p class="mt-2 text-gray-600">
				Comprehensive analytics and insights into UK enforcement activity
			</p>
		</div>

		{#if isLoading}
			<div class="flex items-center justify-center py-12">
				<div class="text-center">
					<div
						class="inline-block h-12 w-12 animate-spin rounded-full border-4 border-solid border-blue-600 border-r-transparent"
					></div>
					<p class="mt-4 text-gray-600">Loading enforcement data...</p>
				</div>
			</div>
		{:else if error}
			<div class="bg-red-50 border border-red-200 rounded-lg p-6">
				<h2 class="text-lg font-semibold text-red-800">Error Loading Data</h2>
				<p class="mt-2 text-red-600">{error.message}</p>
			</div>
		{:else}
			<!-- Filter Panel -->
			<div class="bg-white rounded-lg shadow p-6 mb-6">
				<div class="grid grid-cols-1 md:grid-cols-4 gap-4">
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-2">Time Period</label>
						<select
							bind:value={period}
							class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
						>
							<option value="day">Daily</option>
							<option value="week">Weekly</option>
							<option value="month">Monthly</option>
							<option value="quarter">Quarterly</option>
							<option value="year">Yearly</option>
						</select>
					</div>

					<div>
						<label class="block text-sm font-medium text-gray-700 mb-2">Agency</label>
						<select
							bind:value={selectedAgency}
							class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
						>
							<option value="all">All Agencies</option>
							<!-- TODO: Add dynamic agency options -->
						</select>
					</div>

					<div>
						<label class="block text-sm font-medium text-gray-700 mb-2">Result Type</label>
						<select
							bind:value={selectedResult}
							class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
						>
							<option value="all">All Results</option>
							<option value="Conviction">Conviction</option>
							<option value="Not Guilty">Not Guilty</option>
							<option value="Withdrawn">Withdrawn</option>
						</select>
					</div>

					<div class="flex items-end">
						<button
							onclick={exportToPNG}
							class="mr-2 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition"
						>
							Export PNG
						</button>
						<button
							onclick={exportToCSV}
							class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition"
						>
							Export CSV
						</button>
					</div>
				</div>
			</div>

			<!-- Summary Stats -->
			<div class="grid grid-cols-1 md:grid-cols-5 gap-6 mb-6">
				<div class="bg-white rounded-lg shadow p-6">
					<div class="text-sm font-medium text-gray-600">Total Cases</div>
					<div class="mt-2 text-3xl font-bold text-gray-900">{formatNumber(filteredCases.length)}</div>
				</div>

				<div class="bg-white rounded-lg shadow p-6">
					<div class="text-sm font-medium text-gray-600">Total Fines</div>
					<div class="mt-2 text-3xl font-bold text-gray-900">{formatCurrency(stats.sum)}</div>
				</div>

				<div class="bg-white rounded-lg shadow p-6">
					<div class="text-sm font-medium text-gray-600">Average Fine</div>
					<div class="mt-2 text-3xl font-bold text-gray-900">{formatCurrency(stats.mean)}</div>
				</div>

				<div class="bg-white rounded-lg shadow p-6">
					<div class="text-sm font-medium text-gray-600">Median Fine</div>
					<div class="mt-2 text-3xl font-bold text-gray-900">{formatCurrency(stats.median)}</div>
				</div>

				<div class="bg-white rounded-lg shadow p-6">
					<div class="text-sm font-medium text-gray-600">Max Fine</div>
					<div class="mt-2 text-3xl font-bold text-gray-900">{formatCurrency(stats.max)}</div>
				</div>
			</div>

			<!-- Charts Grid -->
			<div class="space-y-6">
				<!-- Chart 1.1: Cases Over Time -->
				<div class="bg-white rounded-lg shadow p-6">
					<LineChart
						title="Cases Over Time"
						data={casesOverTime}
						height="400px"
						onChartClick={handleCasesOverTimeClick}
					/>
				</div>

				<!-- Charts 1.2 & 1.3: Side by Side -->
				<div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
					<div class="bg-white rounded-lg shadow p-6">
						<BarChart
							title="Top 10 Offenders by Total Fines"
							data={topOffenders}
							height="400px"
							horizontal={true}
							onChartClick={handleOffenderClick}
							seriesName="Total Fines (£)"
						/>
					</div>

					<div class="bg-white rounded-lg shadow p-6">
						<PieChart
							title="Enforcement by Agency"
							data={byAgency}
							height="400px"
							onChartClick={handleAgencyClick}
						/>
					</div>
				</div>

				<!-- Chart 1.4: Fine Distribution -->
				<div class="bg-white rounded-lg shadow p-6">
					<BarChart
						title="Fine Distribution"
						data={fineDistribution}
						height="400px"
						seriesName="Number of Cases"
					/>
				</div>
			</div>

			<!-- Additional Reports Links -->
			<div class="mt-8 bg-white rounded-lg shadow p-6">
				<h2 class="text-xl font-bold text-gray-900 mb-4">Specialized Reports</h2>
				<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
					<a
						href="/reports/offenders"
						class="p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition"
					>
						<h3 class="font-semibold text-gray-900">Offenders Report</h3>
						<p class="text-sm text-gray-600 mt-1">
							Repeat offenders, sectors, and geographic analysis
						</p>
					</a>

					<a
						href="/reports/sectors"
						class="p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition"
					>
						<h3 class="font-semibold text-gray-900">Sector Analysis</h3>
						<p class="text-sm text-gray-600 mt-1">Enforcement patterns by industry sector</p>
					</a>

					<a
						href="/reports/agencies"
						class="p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition"
					>
						<h3 class="font-semibold text-gray-900">Agency Performance</h3>
						<p class="text-sm text-gray-600 mt-1">Enforcement activity by regulator</p>
					</a>
				</div>
			</div>
		{/if}
	</div>
</div>
