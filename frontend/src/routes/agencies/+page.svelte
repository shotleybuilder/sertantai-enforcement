<script lang="ts">
	import { onMount } from 'svelte'
	import {
		initAgenciesSync,
		stopAgenciesSync,
		cachedAgencies,
		agenciesSyncProgress,
	} from '$lib/electric/sync-agencies'
	import type { Agency } from '$lib/db/schema'

	// Reactive data
	$: agencies = $cachedAgencies || []
	$: syncProgress = $agenciesSyncProgress
	$: loading = syncProgress.phase === 'syncing'

	// Initialize sync on mount
	onMount(async () => {
		try {
			await initAgenciesSync()
		} catch (error) {
			console.error('[Agencies Page] Sync initialization failed:', error)
		}

		// Cleanup on unmount
		return () => {
			stopAgenciesSync()
		}
	})

	// Agency display helpers
	function getAgencyDescription(code: string): string {
		const descriptions: Record<string, string> = {
			hse: 'Responsible for workplace health, safety and welfare regulations in Great Britain',
			ea: 'Protects and improves the environment in England',
			orr: 'Regulates the UK railway and road industries',
			onr: 'Regulates nuclear safety and security in the UK',
		}
		return descriptions[code] || 'No description available'
	}

	function getAgencyIconClass(code: string): string {
		const icons: Record<string, string> = {
			hse: 'bg-blue-100 text-blue-600',
			ea: 'bg-green-100 text-green-600',
			orr: 'bg-purple-100 text-purple-600',
			onr: 'bg-orange-100 text-orange-600',
		}
		return icons[code] || 'bg-gray-100 text-gray-600'
	}

	function getAgencyIcon(code: string): string {
		const icons: Record<string, string> = {
			hse: '⚠️',
			ea: '🌿',
			orr: '🚆',
			onr: '⚛️',
		}
		return icons[code] || '🏛️'
	}
</script>

<svelte:head>
	<title>Enforcement Agencies | EHS Enforcement Tracker</title>
	<meta name="description" content="UK environmental, health, and safety enforcement agencies" />
</svelte:head>

<div class="container mx-auto px-4 py-8 max-w-7xl">
	<!-- Header -->
	<div class="mb-8">
		<h1 class="text-3xl font-bold text-gray-900 mb-2">Enforcement Agencies</h1>
		<p class="text-gray-600">
			UK agencies responsible for environmental, health, and safety enforcement
		</p>
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
				<span class="text-blue-800 font-medium">Loading agencies...</span>
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
	{#if agencies.length > 0}
		<div class="bg-white border border-gray-200 rounded-lg p-6 mb-8 shadow-sm">
			<div class="grid grid-cols-1 md:grid-cols-3 gap-6">
				<div>
					<p class="text-sm text-gray-600 mb-1">Total Agencies</p>
					<p class="text-3xl font-bold text-gray-900">{agencies.length}</p>
				</div>
				<div>
					<p class="text-sm text-gray-600 mb-1">Active Agencies</p>
					<p class="text-3xl font-bold text-green-600">
						{agencies.filter((a) => a.enabled).length}
					</p>
				</div>
				<div>
					<p class="text-sm text-gray-600 mb-1">Status</p>
					<p class="text-sm font-medium text-green-600">✓ All agencies synced</p>
				</div>
			</div>
		</div>
	{/if}

	<!-- Empty State -->
	{#if !loading && agencies.length === 0}
		<div
			class="bg-gradient-to-br from-gray-50 to-gray-100 border-2 border-gray-200 rounded-lg p-12 text-center"
		>
			<div class="text-6xl mb-4">🏛️</div>
			<h2 class="text-2xl font-bold text-gray-900 mb-3">No Agencies Found</h2>
			<p class="text-gray-600 max-w-2xl mx-auto">
				Enforcement agency data will appear here when available. These agencies are responsible
				for monitoring and enforcing environmental, health, and safety regulations.
			</p>
		</div>
	{/if}

	<!-- Agency Cards Grid -->
	{#if agencies.length > 0}
		<div class="grid grid-cols-1 md:grid-cols-2 gap-6">
			{#each agencies as agency (agency.id)}
				<div
					class="bg-white border border-gray-200 rounded-lg p-6 hover:shadow-lg transition-shadow duration-200"
				>
					<!-- Agency Header -->
					<div class="flex items-start gap-4 mb-4">
						<div class={`w-16 h-16 rounded-lg flex items-center justify-center text-3xl ${getAgencyIconClass(agency.code)}`}>
							{getAgencyIcon(agency.code)}
						</div>
						<div class="flex-1">
							<h3 class="text-xl font-bold text-gray-900 mb-1">{agency.name}</h3>
							<span
								class="inline-block px-2 py-1 text-xs font-medium rounded-full bg-gray-100 text-gray-700 uppercase"
							>
								{agency.code}
							</span>
						</div>
					</div>

					<!-- Agency Description -->
					<p class="text-gray-600 mb-4">
						{getAgencyDescription(agency.code)}
					</p>

					<!-- Agency Details -->
					<div class="space-y-2 mb-4">
						{#if agency.base_url}
							<div class="flex items-center gap-2 text-sm">
								<span class="text-gray-500">Website:</span>
								<a
									href={agency.base_url}
									target="_blank"
									rel="noopener noreferrer"
									class="text-blue-600 hover:text-blue-800 hover:underline"
								>
									{agency.base_url}
								</a>
							</div>
						{/if}
						<div class="flex items-center gap-2 text-sm">
							<span class="text-gray-500">Status:</span>
							{#if agency.enabled}
								<span class="text-green-600 font-medium">✓ Active</span>
							{:else}
								<span class="text-gray-400 font-medium">Inactive</span>
							{/if}
						</div>
					</div>

					<!-- Action Buttons -->
					<div class="flex gap-3">
						<a
							href="/cases?agency={agency.code}"
							class="flex-1 text-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors duration-200 font-medium text-sm"
						>
							View Cases
						</a>
						<a
							href="/notices?agency={agency.code}"
							class="flex-1 text-center px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors duration-200 font-medium text-sm"
						>
							View Notices
						</a>
					</div>
				</div>
			{/each}
		</div>
	{/if}

	<!-- Additional Information -->
	{#if agencies.length > 0}
		<div class="mt-12 bg-blue-50 border border-blue-200 rounded-lg p-6">
			<h3 class="text-lg font-bold text-gray-900 mb-3">About Enforcement Agencies</h3>
			<p class="text-gray-700 mb-3">
				These agencies are responsible for enforcing regulations and ensuring compliance across
				various sectors including health and safety, environmental protection, and transport
				infrastructure.
			</p>
			<p class="text-sm text-gray-600">
				Each agency maintains public registers of enforcement actions, including prosecutions,
				improvement notices, and prohibition notices issued to businesses and individuals.
			</p>
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
	}
</style>
