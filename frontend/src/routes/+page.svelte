<script lang="ts">
	import { browser } from '$app/environment'
	import { useDashboardStats } from '$lib/query/dashboard'

	// Selected time period and filters
	let selectedPeriod: 'week' | 'month' | 'year' = 'month'
	let selectedActivityType: 'all' | 'cases' | 'notices' = 'all'
	let currentPage = 0
	const itemsPerPage = 10

	// Fetch dashboard stats based on selected period
	$: dashboardStats = browser ? useDashboardStats(selectedPeriod) : null

	// Filter and paginate recent activity
	$: recentActivity =
		$dashboardStats?.data?.recent_activity?.filter((item) => {
			if (selectedActivityType === 'all') return true
			return selectedActivityType === 'cases' ? item.is_case : !item.is_case
		}) || []

	$: totalPages = Math.max(1, Math.ceil(recentActivity.length / itemsPerPage))
	$: paginatedActivity = recentActivity.slice(
		currentPage * itemsPerPage,
		(currentPage + 1) * itemsPerPage
	)

	// Helper to format currency (already formatted by backend, just display)
	function formatDate(dateStr: string): string {
		if (!dateStr) return '-'
		const date = new Date(dateStr)
		return date.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
	}

	// Pagination handlers
	function nextPage() {
		if (currentPage < totalPages - 1) {
			currentPage++
		}
	}

	function prevPage() {
		if (currentPage > 0) {
			currentPage--
		}
	}

	// Reset page when filters change
	$: {
		selectedActivityType
		selectedPeriod
		currentPage = 0
	}
</script>

<svelte:head>
	<title>UK EHS Enforcement Dashboard</title>
	<meta
		name="description"
		content="UK Environmental, Health & Safety enforcement data - Cases, notices, and offender information"
	/>
</svelte:head>

<div class="min-h-screen bg-gray-50">
	<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
		<!-- Page Header -->
		<div class="md:flex md:items-center md:justify-between mb-8">
			<div class="min-w-0 flex-1">
				<h1
					class="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-3xl sm:tracking-tight"
				>
					🏛️ UK EHS Enforcement Dashboard
				</h1>
				<p class="mt-1 text-sm text-gray-500">
					Environmental, Health & Safety enforcement data from UK regulatory agencies
				</p>
			</div>
			<div class="mt-4 flex md:ml-4 md:mt-0">
				<!-- Time Period Selector -->
				<select
					bind:value={selectedPeriod}
					class="block w-full rounded-md border-gray-300 py-2 pl-3 pr-10 text-base focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm"
				>
					<option value="week">Last Week</option>
					<option value="month">Last Month</option>
					<option value="year">Last Year</option>
				</select>
			</div>
		</div>

		{#if $dashboardStats?.isPending}
			<div class="flex items-center justify-center py-12">
				<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
			</div>
		{:else if $dashboardStats?.isError}
			<div class="rounded-md bg-red-50 p-4">
				<div class="flex">
					<div class="flex-shrink-0">
						<svg
							class="h-5 w-5 text-red-400"
							fill="none"
							stroke="currentColor"
							viewBox="0 0 24 24"
						>
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								stroke-width="2"
								d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
							/>
						</svg>
					</div>
					<div class="ml-3">
						<h3 class="text-sm font-medium text-red-800">Error loading dashboard</h3>
						<div class="mt-2 text-sm text-red-700">
							<p>{$dashboardStats.error.message}</p>
						</div>
					</div>
				</div>
			</div>
		{:else if $dashboardStats?.isSuccess}
			{@const stats = $dashboardStats.data.stats}

			<!-- Statistics Overview -->
			<div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-5 mb-8">
				<!-- Active Agencies -->
				<div class="bg-white overflow-hidden shadow rounded-lg">
					<div class="p-5">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<div class="w-8 h-8 bg-indigo-500 rounded-md flex items-center justify-center">
									<svg
										class="w-5 h-5 text-white"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											stroke-width="2"
											d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
										/>
									</svg>
								</div>
							</div>
							<div class="ml-5 w-0 flex-1">
								<dl>
									<dt class="text-sm font-medium text-gray-500 truncate">Active Agencies</dt>
									<dd class="text-lg font-medium text-gray-900">{stats.active_agencies}</dd>
								</dl>
							</div>
						</div>
					</div>
				</div>

				<!-- Recent Cases -->
				<div class="bg-white overflow-hidden shadow rounded-lg">
					<div class="p-5">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
									<svg
										class="w-5 h-5 text-white"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											stroke-width="2"
											d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
										/>
									</svg>
								</div>
							</div>
							<div class="ml-5 w-0 flex-1">
								<dl>
									<dt class="text-sm font-medium text-gray-500 truncate">Recent Cases</dt>
									<dd class="text-lg font-medium text-gray-900">{stats.recent_cases}</dd>
									<dd class="text-xs text-gray-400">{stats.timeframe}</dd>
								</dl>
							</div>
						</div>
					</div>
				</div>

				<!-- Recent Notices -->
				<div class="bg-white overflow-hidden shadow rounded-lg">
					<div class="p-5">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
									<svg
										class="w-5 h-5 text-white"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											stroke-width="2"
											d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
										/>
									</svg>
								</div>
							</div>
							<div class="ml-5 w-0 flex-1">
								<dl>
									<dt class="text-sm font-medium text-gray-500 truncate">Recent Notices</dt>
									<dd class="text-lg font-medium text-gray-900">{stats.recent_notices}</dd>
									<dd class="text-xs text-gray-400">{stats.timeframe}</dd>
								</dl>
							</div>
						</div>
					</div>
				</div>

				<!-- Total Fines -->
				<div class="bg-white overflow-hidden shadow rounded-lg">
					<div class="p-5">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<div class="w-8 h-8 bg-yellow-500 rounded-md flex items-center justify-center">
									<svg
										class="w-5 h-5 text-white"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											stroke-width="2"
											d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"
										/>
									</svg>
								</div>
							</div>
							<div class="ml-5 w-0 flex-1">
								<dl>
									<dt class="text-sm font-medium text-gray-500 truncate">Total Fines</dt>
									<dd class="text-lg font-medium text-gray-900">
										£{parseFloat(stats.total_fines).toLocaleString('en-GB')}
									</dd>
									<dd class="text-xs text-gray-400">{stats.timeframe}</dd>
								</dl>
							</div>
						</div>
					</div>
				</div>

				<!-- Period Indicator -->
				<div class="bg-white overflow-hidden shadow rounded-lg">
					<div class="p-5">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<div class="w-8 h-8 bg-red-500 rounded-md flex items-center justify-center">
									<svg
										class="w-5 h-5 text-white"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											stroke-width="2"
											d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
										/>
									</svg>
								</div>
							</div>
							<div class="ml-5 w-0 flex-1">
								<dl>
									<dt class="text-sm font-medium text-gray-500 truncate">Time Period</dt>
									<dd class="text-lg font-medium text-gray-900">{stats.period}</dd>
									<dd class="text-xs text-gray-400">{stats.timeframe}</dd>
								</dl>
							</div>
						</div>
					</div>
				</div>
			</div>

			<!-- Dashboard Action Cards -->
			<div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3 mb-8">
				<!-- Cases -->
				<a
					href="/cases"
					class="bg-white overflow-hidden shadow rounded-lg hover:shadow-md transition-shadow"
				>
					<div class="p-6">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<div class="w-12 h-12 bg-green-500 rounded-md flex items-center justify-center">
									<svg
										class="w-6 h-6 text-white"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											stroke-width="2"
											d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
										/>
									</svg>
								</div>
							</div>
							<div class="ml-5">
								<h3 class="text-lg font-medium text-gray-900">Cases</h3>
								<p class="text-sm text-gray-500">Prosecutions & Convictions</p>
							</div>
						</div>
						<div class="mt-4">
							<div class="text-2xl font-bold text-gray-900">{stats.total_cases}</div>
							<p class="text-sm text-gray-500">Total cases on record</p>
						</div>
					</div>
				</a>

				<!-- Notices -->
				<a
					href="/notices"
					class="bg-white overflow-hidden shadow rounded-lg hover:shadow-md transition-shadow"
				>
					<div class="p-6">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<div class="w-12 h-12 bg-blue-500 rounded-md flex items-center justify-center">
									<svg
										class="w-6 h-6 text-white"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											stroke-width="2"
											d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
										/>
									</svg>
								</div>
							</div>
							<div class="ml-5">
								<h3 class="text-lg font-medium text-gray-900">Notices</h3>
								<p class="text-sm text-gray-500">Enforcement Notices</p>
							</div>
						</div>
						<div class="mt-4">
							<div class="text-2xl font-bold text-gray-900">{stats.total_notices}</div>
							<p class="text-sm text-gray-500">Total notices issued</p>
						</div>
					</div>
				</a>

				<!-- Offenders -->
				<a
					href="/offenders"
					class="bg-white overflow-hidden shadow rounded-lg hover:shadow-md transition-shadow"
				>
					<div class="p-6">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<div class="w-12 h-12 bg-emerald-500 rounded-md flex items-center justify-center">
									<svg
										class="w-6 h-6 text-white"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											stroke-width="2"
											d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
										/>
									</svg>
								</div>
							</div>
							<div class="ml-5">
								<h3 class="text-lg font-medium text-gray-900">Offenders</h3>
								<p class="text-sm text-gray-500">Organizations & Individuals</p>
							</div>
						</div>
						<div class="mt-4">
							<div class="text-2xl font-bold text-gray-900">
								{$dashboardStats.data.agency_stats.reduce(
									(sum, agency) => sum + agency.case_count,
									0
								)}
							</div>
							<p class="text-sm text-gray-500">Unique offenders tracked</p>
						</div>
					</div>
				</a>

				<!-- Legislation -->
				<a
					href="/legislation"
					class="bg-white overflow-hidden shadow rounded-lg hover:shadow-md transition-shadow"
				>
					<div class="p-6">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<div class="w-12 h-12 bg-purple-500 rounded-md flex items-center justify-center">
									<svg
										class="w-6 h-6 text-white"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											stroke-width="2"
											d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"
										/>
									</svg>
								</div>
							</div>
							<div class="ml-5">
								<h3 class="text-lg font-medium text-gray-900">Legislation</h3>
								<p class="text-sm text-gray-500">Acts & Regulations</p>
							</div>
						</div>
						<div class="mt-4">
							<div class="text-2xl font-bold text-gray-900">{stats.total_legislation}</div>
							<p class="text-sm text-gray-500">Referenced legislation</p>
						</div>
					</div>
				</a>

				<!-- Agencies -->
				<a
					href="/agencies"
					class="bg-white overflow-hidden shadow rounded-lg hover:shadow-md transition-shadow"
				>
					<div class="p-6">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<div class="w-12 h-12 bg-indigo-500 rounded-md flex items-center justify-center">
									<svg
										class="w-6 h-6 text-white"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											stroke-width="2"
											d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
										/>
									</svg>
								</div>
							</div>
							<div class="ml-5">
								<h3 class="text-lg font-medium text-gray-900">Agencies</h3>
								<p class="text-sm text-gray-500">Regulatory Bodies</p>
							</div>
						</div>
						<div class="mt-4">
							<div class="text-2xl font-bold text-gray-900">{stats.active_agencies}</div>
							<p class="text-sm text-gray-500">Active agencies</p>
						</div>
					</div>
				</a>

				<!-- Reports -->
				<a
					href="/reports"
					class="bg-white overflow-hidden shadow rounded-lg hover:shadow-md transition-shadow"
				>
					<div class="p-6">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<div class="w-12 h-12 bg-orange-500 rounded-md flex items-center justify-center">
									<svg
										class="w-6 h-6 text-white"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											stroke-width="2"
											d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
										/>
									</svg>
								</div>
							</div>
							<div class="ml-5">
								<h3 class="text-lg font-medium text-gray-900">Reports</h3>
								<p class="text-sm text-gray-500">Analytics & Insights</p>
							</div>
						</div>
						<div class="mt-4">
							<div class="text-sm text-gray-500">View detailed reports and analytics</div>
						</div>
					</div>
				</a>
			</div>

			<!-- Recent Activity Section -->
			<div class="bg-white shadow overflow-hidden sm:rounded-lg">
				<div class="px-4 py-5 sm:px-6 flex items-center justify-between">
					<div>
						<h3 class="text-lg leading-6 font-medium text-gray-900">Recent Activity</h3>
						<p class="mt-1 max-w-2xl text-sm text-gray-500">
							Latest enforcement cases and notices
						</p>
					</div>
					<div class="flex space-x-2">
						<button
							on:click={() => (selectedActivityType = 'all')}
							class="px-3 py-1 text-sm rounded-md {selectedActivityType === 'all'
								? 'bg-indigo-100 text-indigo-700'
								: 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
						>
							All Types
						</button>
						<button
							on:click={() => (selectedActivityType = 'cases')}
							class="px-3 py-1 text-sm rounded-md {selectedActivityType === 'cases'
								? 'bg-green-100 text-green-700'
								: 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
						>
							Cases
						</button>
						<button
							on:click={() => (selectedActivityType = 'notices')}
							class="px-3 py-1 text-sm rounded-md {selectedActivityType === 'notices'
								? 'bg-blue-100 text-blue-700'
								: 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
						>
							Notices
						</button>
					</div>
				</div>
				<div class="border-t border-gray-200">
					{#if paginatedActivity.length === 0}
						<div class="px-4 py-8 text-center text-gray-500">
							<p>No recent activity found for this time period.</p>
						</div>
					{:else}
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="bg-gray-50">
								<tr>
									<th
										scope="col"
										class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
										>Type</th
									>
									<th
										scope="col"
										class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
										>Case ID</th
									>
									<th
										scope="col"
										class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
										>Date</th
									>
									<th
										scope="col"
										class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
										>Organization</th
									>
									<th
										scope="col"
										class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
										>Description</th
									>
									<th
										scope="col"
										class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
										>Fine</th
									>
									<th
										scope="col"
										class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
										>Link</th
									>
								</tr>
							</thead>
							<tbody class="bg-white divide-y divide-gray-200">
								{#each paginatedActivity as activity}
									<tr class="hover:bg-gray-50">
										<td class="px-6 py-4 whitespace-nowrap">
											<span
												class="inline-flex px-2 py-1 text-xs font-semibold rounded-full {activity.is_case
													? 'bg-green-100 text-green-800'
													: 'bg-blue-100 text-blue-800'}"
											>
												{activity.type}
											</span>
										</td>
										<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
											{activity.regulator_id || '-'}
										</td>
										<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
											{formatDate(activity.date)}
										</td>
										<td class="px-6 py-4 text-sm text-gray-900 max-w-xs truncate">
											{activity.organization || '-'}
										</td>
										<td class="px-6 py-4 text-sm text-gray-500 max-w-md truncate">
											{activity.description || '-'}
										</td>
										<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
											{activity.fine_amount || '-'}
										</td>
										<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
											{#if activity.agency_link}
												<a
													href={activity.agency_link}
													target="_blank"
													rel="noopener noreferrer"
													class="text-indigo-600 hover:text-indigo-900"
												>
													<svg
														class="w-4 h-4"
														fill="none"
														stroke="currentColor"
														viewBox="0 0 24 24"
													>
														<path
															stroke-linecap="round"
															stroke-linejoin="round"
															stroke-width="2"
															d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
														/>
													</svg>
												</a>
											{:else}
												-
											{/if}
										</td>
									</tr>
								{/each}
							</tbody>
						</table>

						<!-- Pagination -->
						<div
							class="bg-white px-4 py-3 flex items-center justify-between border-t border-gray-200 sm:px-6"
						>
							<div class="flex-1 flex justify-between sm:hidden">
								<button
									on:click={prevPage}
									disabled={currentPage === 0}
									class="relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
								>
									Previous
								</button>
								<button
									on:click={nextPage}
									disabled={currentPage >= totalPages - 1}
									class="ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
								>
									Next
								</button>
							</div>
							<div class="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
								<div>
									<p class="text-sm text-gray-700">
										Showing
										<span class="font-medium">{currentPage * itemsPerPage + 1}</span>
										to
										<span class="font-medium"
											>{Math.min((currentPage + 1) * itemsPerPage, recentActivity.length)}</span
										>
										of
										<span class="font-medium">{recentActivity.length}</span>
										results
									</p>
								</div>
								<div>
									<nav class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px">
										<button
											on:click={prevPage}
											disabled={currentPage === 0}
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
											Page {currentPage + 1} of {totalPages}
										</span>
										<button
											on:click={nextPage}
											disabled={currentPage >= totalPages - 1}
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
			</div>
		{/if}
	</div>
</div>
