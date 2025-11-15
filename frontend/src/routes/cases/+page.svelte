<script lang="ts">
  import { onMount } from 'svelte'
  import db, { initDB } from '$lib/db'
  import { startSync, getSyncStatus, checkElectricHealth } from '$lib/electric/sync'
  import type { Case } from '$lib/db/schema'

  // Reactive query for cases
  // This automatically updates when the local DB changes
  let cases = db.query((q) =>
    q.cases
      .all()
      .orderBy('offence_action_date', 'desc')
      .limit(50)
  )

  // State
  let loading = true
  let error: string | null = null
  let electricHealthy = false
  let syncStatus = getSyncStatus()

  // Initialize database and start sync on mount
  onMount(async () => {
    try {
      // 1. Initialize local database
      await initDB()
      console.log('[Cases Page] Database initialized')

      // 2. Check if Electric service is available
      electricHealthy = await checkElectricHealth()
      console.log('[Cases Page] Electric health:', electricHealthy)

      if (!electricHealthy) {
        console.warn('[Cases Page] Electric service unavailable, working offline')
      }

      // 3. Start syncing data from PostgreSQL (if Electric is available)
      if (electricHealthy) {
        startSync()
        console.log('[Cases Page] Sync started')
      }

      // 4. Update sync status periodically
      const statusInterval = setInterval(() => {
        syncStatus = getSyncStatus()
      }, 1000)

      loading = false

      // Cleanup on unmount
      return () => {
        clearInterval(statusInterval)
      }
    } catch (err) {
      console.error('[Cases Page] Initialization error:', err)
      error = err instanceof Error ? err.message : 'Unknown error'
      loading = false
    }
  })

  // Format date for display
  function formatDate(dateString: string | null): string {
    if (!dateString) return 'N/A'
    try {
      const date = new Date(dateString)
      return date.toLocaleDateString('en-GB', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
      })
    } catch {
      return 'Invalid date'
    }
  }

  // Format currency
  function formatCurrency(amount: number | null): string {
    if (amount === null || amount === undefined) return 'N/A'
    return new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency: 'GBP'
    }).format(amount)
  }
</script>

<div class="container mx-auto px-4 py-8">
  <!-- Header -->
  <div class="mb-8">
    <h1 class="text-4xl font-bold text-gray-900 mb-2">
      Enforcement Cases
    </h1>
    <p class="text-gray-600">
      Local-first POC - Cases synced from PostgreSQL via ElectricSQL
    </p>
  </div>

  <!-- Sync Status Banner -->
  <div class="mb-6 p-4 rounded-lg {electricHealthy ? 'bg-green-50 border border-green-200' : 'bg-yellow-50 border border-yellow-200'}">
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <div class="w-3 h-3 rounded-full {syncStatus.connected ? 'bg-green-500' : 'bg-yellow-500'} animate-pulse"></div>
        <span class="font-medium text-gray-900">
          {#if syncStatus.connected}
            ✓ Connected & Syncing
          {:else if electricHealthy}
            ⚠ Connecting...
          {:else}
            ⚠ Offline Mode
          {/if}
        </span>
      </div>
      {#if syncStatus.lastSyncTime}
        <span class="text-sm text-gray-600">
          Last sync: {syncStatus.lastSyncTime.toLocaleTimeString()}
        </span>
      {/if}
    </div>
    {#if !electricHealthy}
      <p class="mt-2 text-sm text-gray-600">
        Electric service is unavailable. Working with locally cached data.
      </p>
    {/if}
  </div>

  <!-- Loading State -->
  {#if loading}
    <div class="flex items-center justify-center py-12">
      <div class="text-center">
        <div class="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mb-4"></div>
        <p class="text-gray-600">Initializing local database...</p>
      </div>
    </div>

  <!-- Error State -->
  {:else if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-6">
      <h3 class="text-red-900 font-semibold mb-2">Error</h3>
      <p class="text-red-700">{error}</p>
    </div>

  <!-- Empty State -->
  {:else if !$cases || $cases.length === 0}
    <div class="bg-gray-50 border border-gray-200 rounded-lg p-12 text-center">
      <h3 class="text-gray-900 font-semibold text-lg mb-2">No Cases Found</h3>
      <p class="text-gray-600 mb-4">
        {#if electricHealthy}
          Waiting for data to sync from PostgreSQL...
        {:else}
          No cached data available. Connect to Electric service to sync data.
        {/if}
      </p>
      <p class="text-sm text-gray-500">
        Make sure your PostgreSQL database has case data and ElectricSQL is running.
      </p>
    </div>

  <!-- Cases List -->
  {:else}
    <div class="mb-4 text-sm text-gray-600">
      Showing {$cases.length} case{$cases.length !== 1 ? 's' : ''}
    </div>

    <div class="grid gap-4">
      {#each $cases as case_}
        <div class="bg-white border border-gray-200 rounded-lg p-6 hover:shadow-md transition-shadow">
          <div class="flex justify-between items-start mb-3">
            <div>
              <h3 class="text-lg font-semibold text-gray-900">
                {case_.case_reference || 'No reference'}
              </h3>
              {#if case_.regulator_id}
                <p class="text-sm text-gray-600">Regulator ID: {case_.regulator_id}</p>
              {/if}
            </div>
            {#if case_.offence_action_date}
              <span class="text-sm text-gray-500">
                {formatDate(case_.offence_action_date)}
              </span>
            {/if}
          </div>

          <div class="grid grid-cols-2 gap-4 mb-3">
            <div>
              <span class="text-xs text-gray-500 uppercase">Result</span>
              <p class="text-sm text-gray-900">{case_.offence_result || 'N/A'}</p>
            </div>
            <div>
              <span class="text-xs text-gray-500 uppercase">Action Type</span>
              <p class="text-sm text-gray-900">{case_.offence_action_type || 'N/A'}</p>
            </div>
          </div>

          {#if case_.offence_fine || case_.offence_costs}
            <div class="grid grid-cols-2 gap-4 mb-3">
              {#if case_.offence_fine}
                <div>
                  <span class="text-xs text-gray-500 uppercase">Fine</span>
                  <p class="text-sm font-semibold text-gray-900">{formatCurrency(case_.offence_fine)}</p>
                </div>
              {/if}
              {#if case_.offence_costs}
                <div>
                  <span class="text-xs text-gray-500 uppercase">Costs</span>
                  <p class="text-sm font-semibold text-gray-900">{formatCurrency(case_.offence_costs)}</p>
                </div>
              {/if}
            </div>
          {/if}

          {#if case_.offence_breaches}
            <div class="mt-3 pt-3 border-t border-gray-100">
              <span class="text-xs text-gray-500 uppercase">Breaches</span>
              <p class="text-sm text-gray-700 mt-1">{case_.offence_breaches}</p>
            </div>
          {/if}

          <div class="mt-4 flex gap-2 text-xs text-gray-500">
            <span>Agency: {case_.agency_id.substring(0, 8)}...</span>
            <span>•</span>
            <span>Offender: {case_.offender_id.substring(0, 8)}...</span>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .container {
    max-width: 1200px;
  }
</style>
