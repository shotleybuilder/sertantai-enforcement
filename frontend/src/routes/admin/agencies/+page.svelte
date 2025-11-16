<script lang="ts">
  import { onMount } from 'svelte'
  import { browser } from '$app/environment'
  import { useAgenciesQuery } from '$lib/query/agencies'
  import { startSync, checkElectricHealth } from '$lib/electric/sync'

  // TanStack Query for agencies data (only in browser, not SSR)
  const agenciesQuery = browser ? useAgenciesQuery() : null

  // State
  let loading = true

  // Initialize database and start sync on mount
  onMount(async () => {
    try {
      // Check if Electric service is available
      const electricHealthy = await checkElectricHealth()
      console.log('[Agencies Page] Electric health:', electricHealthy)

      if (!electricHealthy) {
        console.warn('[Agencies Page] Electric service unavailable, working offline')
      }

      // Start syncing data from PostgreSQL (if Electric is available)
      if (electricHealthy) {
        await startSync()
        console.log('[Agencies Page] Sync started - TanStack Query will update automatically')
      }

      loading = false
    } catch (err) {
      console.error('[Agencies Page] Initialization error:', err)
      loading = false
    }
  })

  // Delete handler
  function handleDelete(id: string) {
    if (confirm('Are you sure you want to delete this agency? This action cannot be undone.')) {
      // TODO: Implement delete mutation in Phase 5
      console.log('Delete agency:', id)
    }
  }
</script>

<div class="min-h-screen bg-gray-50">
  <!-- Header -->
  <div class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="py-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">Agency Management</h1>
            <p class="mt-2 text-sm text-gray-700">
              Manage Enforcement Agencies
              {#if $agenciesQuery?.data}
                · {$agenciesQuery.data.length} {$agenciesQuery.data.length === 1 ? 'agency' : 'agencies'}
              {:else}
                · No agencies found
              {/if}
            </p>
          </div>

          <div class="flex space-x-3">
            <!-- Back to Dashboard Button -->
            <a
              href="/admin"
              class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
              </svg>
              Back to Dashboard
            </a>

            <!-- Create New Agency Button -->
            <a
              href="/admin/agencies/new"
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              New Agency
            </a>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Main Content -->
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">

    <!-- Loading State -->
    {#if !agenciesQuery || $agenciesQuery.isLoading || loading}
      <div class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-sm text-gray-500">Loading agencies...</p>
      </div>
    {:else}
      <!-- Agencies Table -->
      <div class="bg-white shadow overflow-hidden sm:rounded-md">
        <div class="px-4 py-5 sm:p-6">
          {#if $agenciesQuery.data && $agenciesQuery.data.length > 0}
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      ID
                    </th>
                    <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Code
                    </th>
                    <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Name
                    </th>
                    <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Base URL
                    </th>
                    <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Enabled
                    </th>
                    <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Inserted At
                    </th>
                    <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Updated At
                    </th>
                    <th scope="col" class="relative px-6 py-3">
                      <span class="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>

                <tbody class="bg-white divide-y divide-gray-200">
                  {#each $agenciesQuery.data as agency}
                    <tr class="hover:bg-gray-50">
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-500">
                        {agency.id.slice(0, 8)}...
                      </td>

                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                          {agency.code.toUpperCase()}
                        </span>
                      </td>

                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {agency.name}
                      </td>

                      <td class="px-6 py-4 text-sm text-gray-900">
                        {#if agency.base_url}
                          <a
                            href={agency.base_url}
                            target="_blank"
                            rel="noopener noreferrer"
                            class="text-blue-600 hover:text-blue-500 underline"
                          >
                            {agency.base_url}
                          </a>
                        {:else}
                          <span class="text-gray-400">—</span>
                        {/if}
                      </td>

                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {#if agency.enabled}
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                            Yes
                          </span>
                        {:else}
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                            No
                          </span>
                        {/if}
                      </td>

                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {new Date(agency.inserted_at).toLocaleString('en-GB', {
                          year: 'numeric',
                          month: '2-digit',
                          day: '2-digit',
                          hour: '2-digit',
                          minute: '2-digit'
                        }).replace(',', '')}
                      </td>

                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {new Date(agency.updated_at).toLocaleString('en-GB', {
                          year: 'numeric',
                          month: '2-digit',
                          day: '2-digit',
                          hour: '2-digit',
                          minute: '2-digit'
                        }).replace(',', '')}
                      </td>

                      <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                        <div class="flex items-center space-x-2">
                          <a
                            href="/admin/agencies/{agency.id}/edit"
                            class="text-green-600 hover:text-green-900"
                            title="Edit agency"
                          >
                            <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                            </svg>
                          </a>

                          <button
                            on:click={() => handleDelete(agency.id)}
                            class="text-red-600 hover:text-red-900"
                            title="Delete agency"
                          >
                            <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                            </svg>
                          </button>
                        </div>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {:else}
            <!-- Empty State -->
            <div class="text-center py-12">
              <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
              </svg>
              <h3 class="mt-2 text-sm font-medium text-gray-900">No agencies found</h3>
              <p class="mt-1 text-sm text-gray-500">
                Get started by creating a new enforcement agency.
              </p>
              <div class="mt-6">
                <a
                  href="/admin/agencies/new"
                  class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                  </svg>
                  New Agency
                </a>
              </div>
            </div>
          {/if}
        </div>
      </div>
    {/if}
  </div>
</div>
