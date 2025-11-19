<script lang="ts">
	import { onMount } from 'svelte'
	import { page } from '$app/stores'
	import {
		initLegislationSync,
		stopLegislationSync,
		cachedLegislation,
		legislationSyncProgress,
	} from '$lib/electric/sync-legislation'
	import type { Legislation } from '$lib/db/schema'

	// Get legislation ID from URL
	$: legislationId = $page.params.id

	// Reactive data
	$: allLegislation = $cachedLegislation || []
	$: legislation = allLegislation.find((l) => l.id === legislationId) || null
	$: syncProgress = $legislationSyncProgress
	$: loading = syncProgress.phase === 'syncing'

	// Initialize sync on mount
	onMount(async () => {
		try {
			await initLegislationSync()
		} catch (error) {
			console.error('[Legislation Detail Page] Sync initialization failed:', error)
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

	function getFullReference(leg: Legislation): string {
		let ref = leg.legislation_title
		if (leg.legislation_year) {
			ref += ` ${leg.legislation_year}`
		}
		if (leg.legislation_number) {
			ref += ` No. ${leg.legislation_number}`
		}
		return ref
	}
</script>

<svelte:head>
	<title>{legislation?.legislation_title || 'Legislation'} | EHS Enforcement Tracker</title>
	<meta name="description" content="UK legislation details" />
</svelte:head>

<div class="container mx-auto px-4 py-8 max-w-5xl">
	<!-- Back Button -->
	<div class="mb-6">
		<a
			href="/legislation"
			class="inline-flex items-center gap-2 text-blue-600 hover:text-blue-800 hover:underline"
		>
			← Back to Legislation
		</a>
	</div>

	<!-- Loading State -->
	{#if loading}
		<div class="bg-blue-50 border border-blue-200 rounded-lg p-8 text-center">
			<div class="animate-spin inline-block mb-4">
				<svg class="h-8 w-8 text-blue-600" viewBox="0 0 24 24">
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
			<p class="text-blue-800 font-medium">Loading legislation...</p>
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

	<!-- Not Found State -->
	{#if !loading && !legislation}
		<div class="bg-yellow-50 border-2 border-yellow-200 rounded-lg p-12 text-center">
			<div class="text-6xl mb-4">📚</div>
			<h2 class="text-2xl font-bold text-gray-900 mb-3">Legislation Not Found</h2>
			<p class="text-gray-600 max-w-2xl mx-auto mb-6">
				The legislation you're looking for could not be found. It may have been removed or the ID
				is incorrect.
			</p>
			<a
				href="/legislation"
				class="inline-block px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors duration-200 font-medium"
			>
				Browse All Legislation
			</a>
		</div>
	{/if}

	<!-- Legislation Details -->
	{#if !loading && legislation}
		<!-- Header Card -->
		<div class="bg-white border border-gray-200 rounded-lg p-8 mb-6 shadow-sm">
			<div class="flex items-start justify-between mb-4">
				<h1 class="text-3xl font-bold text-gray-900 flex-1">
					{legislation.legislation_title}
				</h1>
				<span
					class={`px-3 py-1 text-sm font-medium rounded-full ${getLegislationTypeBadgeClass(legislation.legislation_type)}`}
				>
					{formatLegislationType(legislation.legislation_type)}
				</span>
			</div>

			<!-- Full Reference -->
			<p class="text-lg text-gray-700 mb-6">
				<strong>Full Reference:</strong>
				{getFullReference(legislation)}
			</p>

			<!-- Metadata Grid -->
			<div class="grid grid-cols-1 md:grid-cols-3 gap-6">
				<div>
					<p class="text-sm text-gray-600 mb-1">Year Enacted</p>
					<p class="text-2xl font-bold text-gray-900">
						{legislation.legislation_year || '—'}
					</p>
				</div>
				<div>
					<p class="text-sm text-gray-600 mb-1">Legislation Number</p>
					<p class="text-2xl font-bold text-gray-900">
						{legislation.legislation_number || '—'}
					</p>
				</div>
				<div>
					<p class="text-sm text-gray-600 mb-1">Type</p>
					<p class="text-2xl font-bold text-gray-900">
						{formatLegislationType(legislation.legislation_type)}
					</p>
				</div>
			</div>
		</div>

		<!-- Related Information Card -->
		<div class="bg-blue-50 border border-blue-200 rounded-lg p-6 mb-6">
			<h3 class="text-lg font-bold text-gray-900 mb-3">About This Legislation</h3>
			<p class="text-gray-700 mb-4">
				This legislation is referenced in enforcement actions tracked in this system. Enforcement
				agencies cite specific Acts, Regulations, and Orders when issuing notices or pursuing
				prosecutions.
			</p>
			<div class="flex gap-3">
				<a
					href="/cases?legislation={legislation.id}"
					class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors duration-200 font-medium text-sm"
				>
					View Related Cases
				</a>
				<a
					href="/notices?legislation={legislation.id}"
					class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors duration-200 font-medium text-sm"
				>
					View Related Notices
				</a>
			</div>
		</div>

		<!-- Timestamps Card -->
		<div class="bg-white border border-gray-200 rounded-lg p-6 shadow-sm">
			<h3 class="text-lg font-bold text-gray-900 mb-4">Record Information</h3>
			<div class="space-y-2 text-sm text-gray-700">
				<div class="flex justify-between">
					<span class="text-gray-600">Record Created:</span>
					<span class="font-medium">
						{new Date(legislation.created_at).toLocaleString('en-GB', {
							dateStyle: 'medium',
							timeStyle: 'short',
						})}
					</span>
				</div>
				<div class="flex justify-between">
					<span class="text-gray-600">Last Updated:</span>
					<span class="font-medium">
						{new Date(legislation.updated_at).toLocaleString('en-GB', {
							dateStyle: 'medium',
							timeStyle: 'short',
						})}
					</span>
				</div>
				<div class="flex justify-between">
					<span class="text-gray-600">Record ID:</span>
					<span class="font-mono text-xs">{legislation.id}</span>
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

		h1 {
			font-size: 1.5rem;
		}
	}
</style>
