<script lang="ts">
	import { browser } from '$app/environment'
	import { useDashboardStats } from '$lib/query/dashboard'
	import RecentActivityTable from '$lib/components/RecentActivityTable.svelte'

	// Selected time period and filters
	let selectedPeriod: 'week' | 'month' | 'year' = 'month'
	let selectedActivityType: 'all' | 'cases' | 'notices' = 'all'

	// Fetch dashboard stats based on selected period
	$: dashboardStats = browser ? useDashboardStats(selectedPeriod) : null

	// Filter recent activity
	$: recentActivity =
		$dashboardStats?.data?.recent_activity?.filter((item) => {
			if (selectedActivityType === 'all') return true
			return selectedActivityType === 'cases' ? item.is_case : !item.is_case
		}) || []
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
			<div class="mt-4 flex gap-3 md:ml-4 md:mt-0">
				<!-- Admin Login Button -->
				<a
					href="http://localhost:4002/sign-in"
					class="inline-flex items-center gap-2 rounded-md bg-indigo-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 transition-colors"
				>
					<svg
						class="h-5 w-5"
						fill="none"
						viewBox="0 0 24 24"
						stroke-width="1.5"
						stroke="currentColor"
					>
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							d="M16.5 10.5V6.75a4.5 4.5 0 1 0-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 0 0 2.25-2.25v-6.75a2.25 2.25 0 0 0-2.25-2.25H6.75a2.25 2.25 0 0 0-2.25 2.25v6.75a2.25 2.25 0 0 0 2.25 2.25Z"
						/>
					</svg>
					Admin Login
				</a>

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

		{#if !browser || $dashboardStats?.isLoading}
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
			<div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-5 mb-8">
				<!-- Enforcement Cases -->
				<div class="bg-white overflow-hidden shadow rounded-lg border-l-4 border-l-blue-400 hover:shadow-lg transition-shadow">
					<div class="p-5">
						<div class="flex items-center mb-4">
							<div class="flex-shrink-0">
								<svg
									class="w-8 h-8 text-blue-500"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M3 6l3 1m0 0l-3 9a5.002 5.002 0 006.001 0M6 7l3 9M6 7l6-2m6 2l3-1m-3 1l-3 9a5.002 5.002 0 006.001 0M18 7l3 9m-3-9l-6-2m0-2v2m0 16V5m0 16H9m3 0h3"
									/>
								</svg>
							</div>
							<div class="ml-3">
								<h3 class="text-base font-medium text-gray-900">ENFORCEMENT CASES</h3>
							</div>
						</div>

						<div class="space-y-3">
							<div>
								<div class="text-3xl font-bold text-gray-900">{stats.total_cases}</div>
								<div class="text-sm text-gray-500">Total Cases</div>
							</div>
							<div>
								<div class="text-2xl font-semibold text-gray-900">{stats.recent_cases}</div>
								<div class="text-sm text-gray-500">Recent (Last 30 Days)</div>
							</div>
							<div>
								<div class="text-2xl font-semibold text-gray-900">
									£{parseFloat(stats.total_fines).toLocaleString('en-GB')}
								</div>
								<div class="text-sm text-gray-500">Total Fines</div>
							</div>
						</div>

						<div class="mt-4 space-y-2">
							<a
								href="/cases"
								class="block w-full text-center px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-md hover:bg-indigo-700 transition-colors"
							>
								Browse Recent →
							</a>
							<div class="relative">
								<input
									type="text"
									placeholder="Search"
									class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-1 focus:ring-indigo-500"
								/>
								<svg
									class="absolute right-3 top-2.5 w-4 h-4 text-gray-400"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
									/>
								</svg>
							</div>
						</div>
					</div>
				</div>

				<!-- Enforcement Notices -->
				<div class="bg-white overflow-hidden shadow rounded-lg border-l-4 border-l-yellow-400 hover:shadow-lg transition-shadow">
					<div class="p-5">
						<div class="flex items-center mb-4">
							<div class="flex-shrink-0">
								<svg
									class="w-8 h-8 text-yellow-600"
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
							<div class="ml-3">
								<h3 class="text-base font-medium text-gray-900">ENFORCEMENT NOTICES</h3>
							</div>
						</div>

						<div class="space-y-3">
							<div>
								<div class="text-3xl font-bold text-gray-900">{stats.total_notices}</div>
								<div class="text-sm text-gray-500">Total Notices</div>
							</div>
							<div>
								<div class="text-2xl font-semibold text-gray-900">{stats.recent_notices}</div>
								<div class="text-sm text-gray-500">Recent (Last 30 Days)</div>
							</div>
							<div>
								<div class="text-2xl font-semibold text-gray-900">0</div>
								<div class="text-sm text-gray-500">Compliance Required</div>
							</div>
						</div>

						<div class="mt-4 space-y-2">
							<a
								href="/notices"
								class="block w-full text-center px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-md hover:bg-indigo-700 transition-colors"
							>
								Browse Recent →
							</a>
							<div class="relative">
								<input
									type="text"
									placeholder="Search"
									class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-1 focus:ring-indigo-500"
								/>
								<svg
									class="absolute right-3 top-2.5 w-4 h-4 text-gray-400"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
									/>
								</svg>
							</div>
						</div>
					</div>
				</div>

				<!-- Offender Database -->
				<div class="bg-white overflow-hidden shadow rounded-lg border-l-4 border-l-purple-400 hover:shadow-lg transition-shadow">
					<div class="p-5">
						<div class="flex items-center mb-4">
							<div class="flex-shrink-0">
								<svg
									class="w-8 h-8 text-purple-500"
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
							<div class="ml-3">
								<h3 class="text-base font-medium text-gray-900">OFFENDER DATABASE</h3>
							</div>
						</div>

						<div class="space-y-3">
							<div>
								<div class="text-3xl font-bold text-gray-900">0</div>
								<div class="text-sm text-gray-500">Total Organizations</div>
							</div>
							<div>
								<div class="text-2xl font-semibold text-gray-900">0 (0.0%)</div>
								<div class="text-sm text-gray-500">Repeat Offenders</div>
							</div>
							<div>
								<div class="text-2xl font-semibold text-gray-900">£0.00</div>
								<div class="text-sm text-gray-500">Average Fine</div>
							</div>
						</div>

						<div class="mt-4 space-y-2">
							<a
								href="/offenders"
								class="block w-full text-center px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-md hover:bg-indigo-700 transition-colors"
							>
								Browse Top 50 →
							</a>
							<div class="relative">
								<input
									type="text"
									placeholder="Search Offenders"
									class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-1 focus:ring-indigo-500"
								/>
								<svg
									class="absolute right-3 top-2.5 w-4 h-4 text-gray-400"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
									/>
								</svg>
							</div>
						</div>
					</div>
				</div>

				<!-- Legislation Database -->
				<div class="bg-white overflow-hidden shadow rounded-lg border-l-4 border-l-amber-400 hover:shadow-lg transition-shadow">
					<div class="p-5">
						<div class="flex items-center mb-4">
							<div class="flex-shrink-0">
								<svg
									class="w-8 h-8 text-amber-600"
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
							<div class="ml-3">
								<h3 class="text-base font-medium text-gray-900">LEGISLATION DATABASE</h3>
							</div>
						</div>

						<div class="space-y-3">
							<div>
								<div class="text-3xl font-bold text-gray-900">0</div>
								<div class="text-sm text-gray-500">Total Legislation</div>
							</div>
							<div>
								<div class="text-2xl font-semibold text-gray-900">0</div>
								<div class="text-sm text-gray-500">Recent (Last 30 Days)</div>
								<div class="text-xs text-gray-400">(0.0%)</div>
							</div>
							<div>
								<div class="text-2xl font-semibold text-gray-900">£0.00</div>
								<div class="text-sm text-gray-500">Average Fine</div>
							</div>
						</div>

						<div class="mt-4 space-y-2">
							<a
								href="/legislation"
								class="block w-full text-center px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-md hover:bg-indigo-700 transition-colors"
							>
								Browse Recent →
							</a>
							<div class="relative">
								<input
									type="text"
									placeholder="Search"
									class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-1 focus:ring-indigo-500"
								/>
								<svg
									class="absolute right-3 top-2.5 w-4 h-4 text-gray-400"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
									/>
								</svg>
							</div>
						</div>
					</div>
				</div>

				<!-- Reports & Analytics -->
				<div class="bg-white overflow-hidden shadow rounded-lg border-l-4 border-l-green-400 hover:shadow-lg transition-shadow">
					<div class="p-5">
						<div class="flex items-center mb-4">
							<div class="flex-shrink-0">
								<svg
									class="w-8 h-8 text-green-600"
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
							<div class="ml-3">
								<h3 class="text-base font-medium text-gray-900">REPORTS & ANALYTICS</h3>
							</div>
						</div>

						<div class="space-y-3">
							<div>
								<div class="text-3xl font-bold text-gray-900">5</div>
								<div class="text-sm text-gray-500">Total Reports</div>
							</div>
							<div class="mt-6">
								<p class="text-sm text-gray-600">
									Generate comprehensive analytics and insights from enforcement data
								</p>
							</div>
						</div>

						<div class="mt-4">
							<a
								href="/reports"
								class="block w-full text-center px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-md hover:bg-indigo-700 transition-colors"
							>
								View Reports →
							</a>
						</div>
					</div>
				</div>
			</div>

			<!-- Recent Activity Section -->
			<div class="bg-white shadow overflow-hidden sm:rounded-lg p-6">
				<div class="mb-6 flex items-center justify-between">
					<div>
						<h3 class="text-lg leading-6 font-medium text-gray-900">Recent Activity</h3>
						<p class="mt-1 max-w-2xl text-sm text-gray-500">
							Latest enforcement cases and notices with customizable columns
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

				<RecentActivityTable data={recentActivity} />
			</div>
		{/if}
	</div>
</div>
