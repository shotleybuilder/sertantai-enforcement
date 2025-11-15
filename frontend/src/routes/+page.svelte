<script lang="ts">
  import { onMount } from 'svelte'
  import { checkElectricHealth } from '$lib/electric/sync'
  import { getDBStatus } from '$lib/db'

  // Status tracking
  let postgresHealthy = false
  let electricHealthy = false
  let dbStatus = { initialized: false, name: '', version: 0, storage: '' }

  onMount(async () => {
    // Check Electric service
    electricHealthy = await checkElectricHealth()

    // Get TanStack DB status
    dbStatus = getDBStatus()

    // PostgreSQL is assumed healthy if Electric is healthy
    postgresHealthy = electricHealthy
  })
</script>

<div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
  <div class="container mx-auto px-4 py-16">
    <!-- Header -->
    <div class="text-center mb-16">
      <h1 class="text-5xl font-bold text-gray-900 mb-4">
        EHS Enforcement POC
      </h1>
      <p class="text-xl text-gray-600 mb-2">
        Local-First Architecture with Real-Time Sync
      </p>
      <p class="text-sm text-gray-500">
        Week 4 Proof of Concept - ElectricSQL + TanStack DB + SvelteKit
      </p>
    </div>

    <!-- Architecture Overview -->
    <div class="max-w-4xl mx-auto mb-12">
      <div class="bg-white rounded-lg shadow-lg p-8 mb-8">
        <h2 class="text-2xl font-semibold text-gray-800 mb-6">Architecture Flow</h2>

        <div class="space-y-4">
          <!-- Step 1: PostgreSQL -->
          <div class="flex items-center gap-4">
            <div class="flex-shrink-0 w-12 h-12 rounded-full flex items-center justify-center {postgresHealthy ? 'bg-green-100 text-green-600' : 'bg-gray-100 text-gray-400'}">
              {#if postgresHealthy}
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
              {:else}
                <span class="text-xl font-bold">1</span>
              {/if}
            </div>
            <div class="flex-1">
              <h3 class="font-semibold text-gray-900">PostgreSQL (Source of Truth)</h3>
              <p class="text-sm text-gray-600">Backend database with logical replication enabled</p>
            </div>
            <div class="text-sm {postgresHealthy ? 'text-green-600' : 'text-gray-400'}">
              {postgresHealthy ? 'Connected' : 'Checking...'}
            </div>
          </div>

          <div class="ml-6 border-l-2 border-gray-300 h-8"></div>

          <!-- Step 2: ElectricSQL -->
          <div class="flex items-center gap-4">
            <div class="flex-shrink-0 w-12 h-12 rounded-full flex items-center justify-center {electricHealthy ? 'bg-green-100 text-green-600' : 'bg-gray-100 text-gray-400'}">
              {#if electricHealthy}
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
              {:else}
                <span class="text-xl font-bold">2</span>
              {/if}
            </div>
            <div class="flex-1">
              <h3 class="font-semibold text-gray-900">ElectricSQL Sync Service</h3>
              <p class="text-sm text-gray-600">HTTP Shape API consuming PostgreSQL WAL stream</p>
            </div>
            <div class="text-sm {electricHealthy ? 'text-green-600' : 'text-red-600'}">
              {electricHealthy ? 'Healthy (port 3001)' : 'Unavailable'}
            </div>
          </div>

          <div class="ml-6 border-l-2 border-gray-300 h-8"></div>

          <!-- Step 3: TanStack DB -->
          <div class="flex items-center gap-4">
            <div class="flex-shrink-0 w-12 h-12 rounded-full flex items-center justify-center {dbStatus.initialized ? 'bg-green-100 text-green-600' : 'bg-gray-100 text-gray-400'}">
              {#if dbStatus.initialized}
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
              {:else}
                <span class="text-xl font-bold">3</span>
              {/if}
            </div>
            <div class="flex-1">
              <h3 class="font-semibold text-gray-900">TanStack DB (Client Store)</h3>
              <p class="text-sm text-gray-600">Local reactive database with IndexedDB persistence</p>
            </div>
            <div class="text-sm {dbStatus.initialized ? 'text-green-600' : 'text-gray-400'}">
              {dbStatus.initialized ? 'Initialized' : 'Not initialized'}
            </div>
          </div>

          <div class="ml-6 border-l-2 border-gray-300 h-8"></div>

          <!-- Step 4: Svelte UI -->
          <div class="flex items-center gap-4">
            <div class="flex-shrink-0 w-12 h-12 rounded-full bg-blue-100 text-blue-600 flex items-center justify-center">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
              </svg>
            </div>
            <div class="flex-1">
              <h3 class="font-semibold text-gray-900">Svelte UI</h3>
              <p class="text-sm text-gray-600">Reactive components with auto-updating queries</p>
            </div>
            <div class="text-sm text-blue-600">Active</div>
          </div>
        </div>
      </div>

      <!-- Features Grid -->
      <div class="grid md:grid-cols-2 gap-6 mb-8">
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="font-semibold text-gray-900 mb-3 flex items-center gap-2">
            <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
            Real-Time Sync
          </h3>
          <p class="text-sm text-gray-600">
            Changes in PostgreSQL appear in the UI within 500ms via ElectricSQL's shape streams
          </p>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="font-semibold text-gray-900 mb-3 flex items-center gap-2">
            <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 15a4 4 0 004 4h9a5 5 0 10-.1-9.999 5.002 5.002 0 10-9.78 2.096A4.001 4.001 0 003 15z" />
            </svg>
            Offline-First
          </h3>
          <p class="text-sm text-gray-600">
            App continues working with cached data when ElectricSQL is unavailable
          </p>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="font-semibold text-gray-900 mb-3 flex items-center gap-2">
            <svg class="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
            Sub-Millisecond Queries
          </h3>
          <p class="text-sm text-gray-600">
            All data queries run against local IndexedDB for instant response times
          </p>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="font-semibold text-gray-900 mb-3 flex items-center gap-2">
            <svg class="w-5 h-5 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
            </svg>
            Type-Safe
          </h3>
          <p class="text-sm text-gray-600">
            Full TypeScript coverage from database schema to UI components
          </p>
        </div>
      </div>

      <!-- Navigation -->
      <div class="text-center">
        <a
          href="/cases"
          class="inline-flex items-center gap-2 px-8 py-4 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors shadow-lg hover:shadow-xl"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
          </svg>
          View Cases
        </a>
      </div>
    </div>

    <!-- Tech Stack -->
    <div class="max-w-4xl mx-auto">
      <div class="bg-white rounded-lg shadow p-6">
        <h3 class="font-semibold text-gray-900 mb-4 text-center">Technology Stack</h3>
        <div class="flex flex-wrap justify-center gap-3">
          <span class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm">SvelteKit</span>
          <span class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm">TypeScript</span>
          <span class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm">TailwindCSS v4</span>
          <span class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm">TanStack DB</span>
          <span class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm">ElectricSQL v1.0</span>
          <span class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm">Phoenix + Ash</span>
          <span class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm">PostgreSQL 16</span>
        </div>
      </div>
    </div>
  </div>
</div>

<style>
  .container {
    max-width: 1200px;
  }
</style>
