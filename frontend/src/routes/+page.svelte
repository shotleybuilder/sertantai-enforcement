<script lang="ts">
	import { browser } from '$app/environment'
	import { goto } from '$app/navigation'
	import NaturalLanguageQuery from '$lib/components/NaturalLanguageQuery.svelte'
	import { queryState } from '$lib/stores/query-state'

	// Example queries to showcase the system's capabilities
	const exampleQueries = [
		{
			text: "Show me HSE cases with fines over £50,000 from 2024",
			description: "High-value prosecutions"
		},
		{
			text: "Find SEPA enforcement notices from 2024",
			description: "Scottish environmental notices"
		},
		{
			text: "Cases with fines between £10k and £100k",
			description: "Medium-range penalties"
		},
		{
			text: "Show me all prosecutions by the Environment Agency",
			description: "EA enforcement actions"
		}
	]

	// Handle successful query - save to store and navigate to data page
	function handleQuerySuccess(filters: any[], sort: any | null, columns?: string[], columnOrder?: string[]) {
		console.log('[Homepage] Query successful, navigating to /data with config:', { filters, sort, columns, columnOrder })

		// Save query state to store so /data page can pick it up
		queryState.setQuery({
			query: '', // We don't track the raw query text from homepage
			filters: filters || [],
			sort,
			columns: columns || [],
			columnOrder: columnOrder || []
		})

		// Navigate to /data page
		goto('/data')
	}

	// Handle example query click - trigger API call and navigate
	async function handleExampleClick(queryText: string) {
		console.log('[Homepage] Example clicked:', queryText)

		try {
			// Call the NL query API directly
			const response = await fetch('http://localhost:4002/api/nl-query', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({ query: queryText }),
			})

			if (!response.ok) {
				throw new Error('Failed to translate query')
			}

			const data = await response.json()
			console.log('[Homepage] Query translated:', data)

			// Save to store and navigate
			queryState.setQuery({
				query: queryText,
				filters: data.filters || [],
				sort: data.sort || null,
				columns: data.columns || [],
				columnOrder: data.columnOrder || []
			})

			goto('/data')
		} catch (error) {
			console.error('[Homepage] Query failed:', error)
			// Still navigate to data page on error - user can manually filter
			goto('/data')
		}
	}
</script>

<svelte:head>
	<title>EHS Enforcement - UK Environmental, Health & Safety Data</title>
	<meta
		name="description"
		content="Search and analyze UK enforcement data using natural language. AI-powered insights into cases, notices, and compliance."
	/>
</svelte:head>

<div class="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 flex flex-col">
	<!-- Header -->
	<header class="w-full px-6 py-4 bg-white border-b border-gray-200">
		<div class="container mx-auto flex items-center justify-between">
			<div class="flex items-center space-x-3">
				<div class="w-10 h-10 bg-indigo-600 rounded-lg flex items-center justify-center">
					<svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
					</svg>
				</div>
				<div>
					<h1 class="text-xl font-bold text-gray-900">EHS Enforcement</h1>
					<p class="text-xs text-gray-500">UK Environmental, Health & Safety Data</p>
				</div>
			</div>
			<nav class="flex items-center space-x-4">
				<a href="/dashboard" class="text-sm text-gray-600 hover:text-gray-900 transition-colors">Dashboard</a>
				<a href="/data" class="text-sm text-gray-600 hover:text-gray-900 transition-colors">Browse Data</a>
			</nav>
		</div>
	</header>

	<!-- Main Content - Centered Prompt Interface -->
	<main class="flex-1 flex flex-col items-center justify-center px-4 py-12">
		<div class="w-full max-w-3xl space-y-8">
			<!-- Hero Section -->
			<div class="text-center space-y-4">
				<h2 class="text-4xl font-bold text-gray-900 sm:text-5xl">
					Ask about enforcement data<br />in plain English
				</h2>
				<p class="text-lg text-gray-600 max-w-2xl mx-auto">
					Search thousands of UK enforcement cases and notices using natural language.
					Our AI understands your questions and finds exactly what you're looking for.
				</p>
			</div>

			<!-- Natural Language Query Component (browser only to avoid SSR issues) -->
			{#if browser}
				<div class="w-full">
					<NaturalLanguageQuery
						onQuerySuccess={handleQuerySuccess}
						placeholder="Ask in plain English... e.g., 'Show me HSE cases with fines over £50,000 from 2024'"
					/>
				</div>
			{:else}
				<!-- SSR Fallback - Show a placeholder -->
				<div class="w-full">
					<div class="relative">
						<input
							type="text"
							disabled
							placeholder="Loading search..."
							class="w-full px-6 py-4 text-lg border-2 border-gray-300 rounded-lg bg-gray-50"
						/>
					</div>
				</div>
			{/if}

			<!-- Example Queries Section -->
			<div class="space-y-4">
				<h3 class="text-sm font-semibold text-gray-700 text-center uppercase tracking-wide">
					Try these examples
				</h3>
				<div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
					{#each exampleQueries as example}
						<button
							on:click={() => handleExampleClick(example.text)}
							class="group text-left p-4 bg-white border border-gray-200 rounded-lg hover:border-indigo-300 hover:shadow-md transition-all"
						>
							<div class="flex items-start space-x-3">
								<div class="flex-shrink-0 mt-0.5">
									<svg class="w-5 h-5 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
									</svg>
								</div>
								<div class="flex-1 min-w-0">
									<p class="text-sm font-medium text-gray-900 group-hover:text-indigo-600 transition-colors">
										{example.text}
									</p>
									<p class="text-xs text-gray-500 mt-1">
										{example.description}
									</p>
								</div>
							</div>
						</button>
					{/each}
				</div>
			</div>

			<!-- Feature Highlights -->
			<div class="mt-12 grid grid-cols-1 sm:grid-cols-3 gap-6 text-center">
				<div class="space-y-2">
					<div class="inline-flex items-center justify-center w-12 h-12 bg-indigo-100 rounded-lg">
						<svg class="w-6 h-6 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
						</svg>
					</div>
					<h4 class="font-semibold text-gray-900">Smart Search</h4>
					<p class="text-sm text-gray-600">AI-powered queries understand context and intent</p>
				</div>
				<div class="space-y-2">
					<div class="inline-flex items-center justify-center w-12 h-12 bg-green-100 rounded-lg">
						<svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
						</svg>
					</div>
					<h4 class="font-semibold text-gray-900">Comprehensive Data</h4>
					<p class="text-sm text-gray-600">45,000+ cases and notices from UK regulators</p>
				</div>
				<div class="space-y-2">
					<div class="inline-flex items-center justify-center w-12 h-12 bg-purple-100 rounded-lg">
						<svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" />
						</svg>
					</div>
					<h4 class="font-semibold text-gray-900">Flexible Views</h4>
					<p class="text-sm text-gray-600">Filter, sort, and group data exactly how you need</p>
				</div>
			</div>
		</div>
	</main>

	<!-- Footer -->
	<footer class="w-full px-6 py-6 bg-white border-t border-gray-200">
		<div class="container mx-auto text-center text-sm text-gray-600">
			<p>Data sourced from HSE, Environment Agency, SEPA, and Natural Resources Wales</p>
		</div>
	</footer>
</div>
