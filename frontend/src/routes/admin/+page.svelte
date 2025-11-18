<script lang="ts">
  import { browser } from '$app/environment'
  import { useAdminStats } from '$lib/query/admin'

  // Selected time period
  let selectedPeriod: 'week' | 'month' | 'year' = 'month'

  // Fetch admin stats based on selected period
  $: adminStats = browser ? useAdminStats(selectedPeriod) : null

  // Helper to format currency
  function formatCurrency(value: string): string {
    const num = parseFloat(value)
    return new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency: 'GBP',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(num)
  }

  // Placeholder functions for interactive features
  function handleRefreshMetrics() {
    // TODO: Implement metrics refresh
    alert('Metrics refresh not yet implemented in Svelte')
  }

  function handleCheckDuplicates(type: 'cases' | 'notices' | 'offenders') {
    // TODO: Implement duplicate checking
    alert(`${type} duplicate checking not yet implemented in Svelte`)
  }

  function handleExport(format: 'csv' | 'json' | 'xlsx') {
    // TODO: Implement export
    alert(`Export to ${format.toUpperCase()} not yet implemented in Svelte`)
  }
</script>

<div class="min-h-screen bg-gray-50 py-8">
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <!-- Page Header -->
    <div class="md:flex md:items-center md:justify-between mb-8">
      <div class="min-w-0 flex-1">
        <h2
          class="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-3xl sm:tracking-tight"
        >
          🔧 Admin Dashboard
        </h2>
        <p class="mt-1 text-sm text-gray-500">Administrative tools and system management</p>
      </div>
      <div class="mt-4 flex items-center space-x-3 md:ml-4 md:mt-0">
        <!-- Admin indicator -->
        <div class="flex items-center space-x-2">
          <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-800">
            ADMIN
          </span>
          <a href="/" class="text-sm text-gray-500 hover:text-gray-700">← Main Dashboard</a>
        </div>

        <!-- Time Period Selector -->
        <div class="mr-3">
          <select
            bind:value={selectedPeriod}
            class="mt-1 block w-full rounded-md border-gray-300 py-2 pl-3 pr-10 text-base focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm"
          >
            <option value="week">Last Week</option>
            <option value="month">Last Month</option>
            <option value="year">Last Year</option>
          </select>
        </div>
      </div>
    </div>

    {#if $adminStats?.isPending}
      <div class="flex items-center justify-center py-12">
        <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
      </div>
    {:else if $adminStats?.isError}
      <div class="rounded-md bg-red-50 p-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-red-800">Error loading admin statistics</h3>
            <div class="mt-2 text-sm text-red-700">
              <p>{$adminStats.error.message}</p>
            </div>
          </div>
        </div>
      </div>
    {:else if $adminStats?.isSuccess}
      {@const stats = $adminStats.data.stats}
      {@const agencies = $adminStats.data.agencies}

      <!-- Admin Statistics Overview -->
      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-6 mb-8">
        <!-- Data Quality -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                </div>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Data Quality</dt>
                  <dd class="text-lg font-medium text-gray-900">{stats.data_quality_score}%</dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <!-- Active Agencies -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-indigo-500 rounded-md flex items-center justify-center">
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
                  <dd class="text-lg font-medium text-gray-900">{stats.active_agencies} Agencies</dd>
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
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
                  <dd class="text-lg font-medium text-gray-900">{stats.recent_cases} Cases</dd>
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
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
                  <dd class="text-lg font-medium text-gray-900">{stats.recent_notices} Notices</dd>
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
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
                  <dt class="text-sm font-medium text-gray-500 truncate">Recent Fines</dt>
                  <dd class="text-lg font-medium text-gray-900">{formatCurrency(stats.total_fines)}</dd>
                  <dd class="text-xs text-gray-400">{stats.timeframe}</dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <!-- Sync Status -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div
                  class="w-8 h-8 rounded-md flex items-center justify-center {stats.sync_errors ===
                  0
                    ? 'bg-green-500'
                    : 'bg-red-500'}"
                >
                  {#if stats.sync_errors === 0}
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
                        d="M5 13l4 4L19 7"
                      />
                    </svg>
                  {:else}
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
                        d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 15.5c-.77.833.192 2.5 1.732 2.5z"
                      />
                    </svg>
                  {/if}
                </div>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Sync Status</dt>
                  <dd
                    class="text-lg font-medium {stats.sync_errors === 0
                      ? 'text-green-600'
                      : 'text-red-600'}"
                  >
                    {stats.sync_errors === 0 ? 'Healthy' : `${stats.sync_errors} Errors`}
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Admin Action Cards -->
      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3 mb-8">
        <!-- Data Management -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4"
                    />
                  </svg>
                </div>
              </div>
              <div class="ml-5">
                <h3 class="text-lg font-medium text-gray-900">Data Management</h3>
                <p class="text-sm text-gray-500">Scraping, imports, and data quality</p>
              </div>
            </div>
            <div class="mt-6 space-y-3">
              <a
                href="/admin/scrape"
                class="w-full text-left bg-gradient-to-r from-blue-50 to-indigo-50 hover:from-blue-100 hover:to-indigo-100 px-4 py-3 rounded-md transition-colors block border border-blue-200"
              >
                <div class="flex items-center justify-between">
                  <span class="text-sm font-semibold text-gray-900">Scraping Interface</span>
                  <svg
                    class="w-4 h-4 text-blue-600"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 5l7 7-7 7"
                    />
                  </svg>
                </div>
                <p class="mt-1 text-xs text-gray-600">
                  Unified interface for all agencies and types
                </p>
              </a>
              <a
                href="/admin/scrape-sessions"
                class="w-full text-left bg-gray-50 hover:bg-gray-100 px-4 py-3 rounded-md transition-colors block"
              >
                <div class="flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-900">View Sessions</span>
                  <svg
                    class="w-4 h-4 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 5l7 7-7 7"
                    />
                  </svg>
                </div>
              </a>
            </div>
          </div>
        </div>

        <!-- System Operations -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
                    />
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                    />
                  </svg>
                </div>
              </div>
              <div class="ml-5">
                <h3 class="text-lg font-medium text-gray-900">System Operations</h3>
                <p class="text-sm text-gray-500">Monitoring and maintenance</p>
              </div>
            </div>
            <div class="mt-6 space-y-3">
              <button
                on:click={handleRefreshMetrics}
                type="button"
                class="w-full text-left bg-gray-50 hover:bg-gray-100 px-4 py-3 rounded-md transition-colors"
              >
                <div class="flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-900">Refresh Metrics</span>
                  <svg
                    class="w-4 h-4 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                    />
                  </svg>
                </div>
              </button>
              <a
                href="/admin/config"
                class="w-full text-left bg-gray-50 hover:bg-gray-100 px-4 py-3 rounded-md transition-colors block"
              >
                <div class="flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-900">System Config</span>
                  <svg
                    class="w-4 h-4 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 5l7 7-7 7"
                    />
                  </svg>
                </div>
              </a>
            </div>
          </div>
        </div>

        <!-- Agency Management -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-indigo-500 rounded-md flex items-center justify-center">
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
                <h3 class="text-lg font-medium text-gray-900">Agency Management</h3>
                <p class="text-sm text-gray-500">Configure enforcement agencies</p>
              </div>
            </div>
            <div class="mt-6 space-y-3">
              <a
                href="/admin/agencies"
                class="w-full text-left bg-gray-50 hover:bg-gray-100 px-4 py-3 rounded-md transition-colors block"
              >
                <div class="flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-900">Manage Agencies</span>
                  <svg
                    class="w-4 h-4 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 5l7 7-7 7"
                    />
                  </svg>
                </div>
              </a>
              <a
                href="/admin/agencies/new"
                class="w-full text-left bg-gray-50 hover:bg-gray-100 px-4 py-3 rounded-md transition-colors block"
              >
                <div class="flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-900">New Agency</span>
                  <svg
                    class="w-4 h-4 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 4v16m8-8H4"
                    />
                  </svg>
                </div>
              </a>
            </div>
          </div>
        </div>

        <!-- Case Management -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-orange-500 rounded-md flex items-center justify-center">
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
                <h3 class="text-lg font-medium text-gray-900">Case Management</h3>
                <p class="text-sm text-gray-500">Manage enforcement cases and records</p>
              </div>
            </div>
            <div class="mt-6 space-y-3">
              <a
                href="/cases"
                class="w-full text-left bg-gray-50 hover:bg-gray-100 px-4 py-3 rounded-md transition-colors block"
              >
                <div class="flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-900">Manage Cases</span>
                  <svg
                    class="w-4 h-4 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 5l7 7-7 7"
                    />
                  </svg>
                </div>
              </a>
              <button
                on:click={() => handleCheckDuplicates('cases')}
                type="button"
                class="w-full text-left bg-gray-50 hover:bg-gray-100 px-4 py-3 rounded-md transition-colors"
              >
                <div class="flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-900">Check for Duplicates</span>
                  <svg
                    class="w-4 h-4 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M8 7v8a2 2 0 002 2h6M8 7V5a2 2 0 012-2h4.586a1 1 0 01.707.293l4.414 4.414a1 1 0 01.293.707V15a2 2 0 01-2 2v0M8 7H6a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2v-2"
                    />
                  </svg>
                </div>
              </button>
            </div>
          </div>
        </div>

        <!-- Notice Management -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
                <h3 class="text-lg font-medium text-gray-900">Notice Management</h3>
                <p class="text-sm text-gray-500">Manage enforcement notices and records</p>
              </div>
            </div>
            <div class="mt-6 space-y-3">
              <a
                href="/notices"
                class="w-full text-left bg-gray-50 hover:bg-gray-100 px-4 py-3 rounded-md transition-colors block"
              >
                <div class="flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-900">Manage Notices</span>
                  <svg
                    class="w-4 h-4 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 5l7 7-7 7"
                    />
                  </svg>
                </div>
              </a>
              <button
                on:click={() => handleCheckDuplicates('notices')}
                type="button"
                class="w-full text-left bg-gray-50 hover:bg-gray-100 px-4 py-3 rounded-md transition-colors"
              >
                <div class="flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-900">Check for Duplicates</span>
                  <svg
                    class="w-4 h-4 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M8 7v8a2 2 0 002 2h6M8 7V5a2 2 0 012-2h4.586a1 1 0 01.707.293l4.414 4.414a1 1 0 01.293.707V15a2 2 0 01-2 2v0M8 7H6a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2v-2"
                    />
                  </svg>
                </div>
              </button>
            </div>
          </div>
        </div>

        <!-- Offender Management -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-emerald-500 rounded-md flex items-center justify-center">
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
                <h3 class="text-lg font-medium text-gray-900">Offender Management</h3>
                <p class="text-sm text-gray-500">Manage offender records and duplicates</p>
              </div>
            </div>
            <div class="mt-6 space-y-3">
              <a
                href="/offenders"
                class="w-full text-left bg-gray-50 hover:bg-gray-100 px-4 py-3 rounded-md transition-colors block"
              >
                <div class="flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-900">Manage Offenders</span>
                  <svg
                    class="w-4 h-4 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 5l7 7-7 7"
                    />
                  </svg>
                </div>
              </a>
              <a
                href="/admin/offenders/reviews"
                class="w-full text-left bg-gradient-to-r from-emerald-50 to-teal-50 hover:from-emerald-100 hover:to-teal-100 px-4 py-3 rounded-md transition-colors block border border-emerald-200"
              >
                <div class="flex items-center justify-between">
                  <span class="text-sm font-semibold text-gray-900">
                    🏢 Review Companies House Matches
                  </span>
                  <svg
                    class="w-4 h-4 text-emerald-600"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 5l7 7-7 7"
                    />
                  </svg>
                </div>
                <p class="mt-1 text-xs text-gray-600">
                  Approve medium-confidence company matches
                </p>
              </a>
              <button
                on:click={() => handleCheckDuplicates('offenders')}
                type="button"
                class="w-full text-left bg-gray-50 hover:bg-gray-100 px-4 py-3 rounded-md transition-colors"
              >
                <div class="flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-900">Check for Duplicates</span>
                  <svg
                    class="w-4 h-4 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M8 7v8a2 2 0 002 2h6M8 7V5a2 2 0 012-2h4.586a1 1 0 01.707.293l4.414 4.414a1 1 0 01.293.707V15a2 2 0 01-2 2v0M8 7H6a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2v-2"
                    />
                  </svg>
                </div>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Secondary Grid for Agency Status and Reports -->
      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 mb-8">
        <!-- Agency Status -->
        {#if agencies.length > 0}
          <div class="bg-white shadow overflow-hidden sm:rounded-md">
            <div class="px-4 py-5 sm:px-6">
              <h3 class="text-lg leading-6 font-medium text-gray-900">Agency Status</h3>
              <p class="mt-1 max-w-2xl text-sm text-gray-500">
                Current sync and data collection status
              </p>
            </div>
            <ul role="list" class="divide-y divide-gray-200">
              {#each agencies as agency}
                <li class="px-4 py-4 sm:px-6">
                  <div class="flex items-center justify-between">
                    <div class="flex items-center">
                      <div
                        class="flex-shrink-0 w-2.5 h-2.5 rounded-full {agency.enabled
                          ? 'bg-green-400'
                          : 'bg-gray-300'}"
                      ></div>
                      <div class="ml-4">
                        <div class="flex items-center">
                          <p class="text-sm font-medium text-gray-900">{agency.name}</p>
                          <p class="ml-2 text-sm text-gray-500">({agency.code})</p>
                        </div>
                        <p class="text-sm text-gray-500">
                          Status: {agency.enabled ? 'Active' : 'Inactive'}
                        </p>
                      </div>
                    </div>
                    <div class="flex items-center space-x-2">
                      <span
                        class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-gray-100 text-gray-800"
                      >
                        Idle
                      </span>
                    </div>
                  </div>
                </li>
              {/each}
            </ul>
          </div>
        {/if}

        <!-- Reports & Export -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-purple-500 rounded-md flex items-center justify-center">
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
                <h3 class="text-lg font-medium text-gray-900">Reports & Export</h3>
                <p class="text-sm text-gray-500">Data export and analytics</p>
              </div>
            </div>
            <div class="mt-6 space-y-3">
              <button
                on:click={() => handleExport('csv')}
                type="button"
                class="w-full text-left bg-gray-50 hover:bg-gray-100 px-4 py-3 rounded-md transition-colors"
              >
                <div class="flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-900">Export CSV</span>
                  <svg
                    class="w-4 h-4 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                </div>
              </button>
              <button
                on:click={() => handleExport('json')}
                type="button"
                class="w-full text-left bg-gray-50 hover:bg-gray-100 px-4 py-3 rounded-md transition-colors"
              >
                <div class="flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-900">Export JSON</span>
                  <svg
                    class="w-4 h-4 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                </div>
              </button>
              <button
                on:click={() => handleExport('xlsx')}
                type="button"
                class="w-full text-left bg-gray-50 hover:bg-gray-100 px-4 py-3 rounded-md transition-colors"
              >
                <div class="flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-900">Export Excel</span>
                  <svg
                    class="w-4 h-4 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                </div>
              </button>
            </div>
          </div>
        </div>
      </div>
    {/if}
  </div>
</div>
