<script lang="ts">
  import { browser } from '$app/environment'
  import { useScrapingConfigsQuery } from '$lib/query/scraping-configs'

  // TanStack Query for scraping configs
  const scrapingConfigsQuery = browser ? useScrapingConfigsQuery() : null

  // Calculate stats
  $: totalConfigs = $scrapingConfigsQuery?.data?.length || 0
  $: activeConfig = $scrapingConfigsQuery?.data?.find(c => c.is_active)
  $: activeConfigName = activeConfig?.name || 'None'
</script>

<div class="min-h-screen bg-gray-50">
  <!-- Header -->
  <div class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="py-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">Configuration Dashboard</h1>
            <p class="mt-2 text-sm text-gray-700">
              Manage system-wide configuration and settings
            </p>
          </div>

          <div class="flex space-x-3">
            <a
              href="/admin"
              class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
              </svg>
              Back to Admin
            </a>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Main Content -->
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">

    <!-- Configuration Sections Grid -->
    <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">

      <!-- Scraping Configuration Card -->
      <a
        href="/admin/config/scraping"
        class="bg-white overflow-hidden shadow rounded-lg hover:shadow-md transition-shadow duration-200"
      >
        <div class="p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0 bg-blue-500 rounded-md p-3">
              <svg class="h-6 w-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dt class="text-sm font-medium text-gray-500 truncate">
                Scraping Configuration
              </dt>
              <dd class="flex items-baseline">
                <div class="text-2xl font-semibold text-gray-900">
                  {totalConfigs}
                </div>
                <div class="ml-2 text-sm text-gray-500">
                  {totalConfigs === 1 ? 'profile' : 'profiles'}
                </div>
              </dd>
            </div>
          </div>

          <div class="mt-4">
            <div class="text-sm">
              <span class="text-gray-500">Active:</span>
              <span class="ml-2 font-medium text-gray-900">{activeConfigName}</span>
            </div>
          </div>

          <div class="mt-4 flex items-center text-sm text-blue-600 hover:text-blue-500">
            <span>Manage scraping configs</span>
            <svg class="ml-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </div>
        </div>
      </a>

      <!-- Feature Flags Card (Placeholder) -->
      <div class="bg-white overflow-hidden shadow rounded-lg opacity-60">
        <div class="p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0 bg-gray-400 rounded-md p-3">
              <svg class="h-6 w-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 21v-4m0 0V5a2 2 0 012-2h6.5l1 1H21l-3 6 3 6h-8.5l-1-1H5a2 2 0 00-2 2zm9-13.5V9" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dt class="text-sm font-medium text-gray-500 truncate">
                Feature Flags
              </dt>
              <dd class="text-2xl font-semibold text-gray-900">
                Coming Soon
              </dd>
            </div>
          </div>

          <div class="mt-4">
            <p class="text-sm text-gray-500">
              Toggle application features on/off
            </p>
          </div>
        </div>
      </div>

      <!-- System Settings Card (Placeholder) -->
      <div class="bg-white overflow-hidden shadow rounded-lg opacity-60">
        <div class="p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0 bg-gray-400 rounded-md p-3">
              <svg class="h-6 w-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dt class="text-sm font-medium text-gray-500 truncate">
                System Settings
              </dt>
              <dd class="text-2xl font-semibold text-gray-900">
                Coming Soon
              </dd>
            </div>
          </div>

          <div class="mt-4">
            <p class="text-sm text-gray-500">
              System-wide application settings
            </p>
          </div>
        </div>
      </div>

    </div>

    <!-- Current Active Configuration Details -->
    {#if activeConfig}
      <div class="mt-8 bg-white shadow overflow-hidden sm:rounded-lg">
        <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
          <h3 class="text-lg leading-6 font-medium text-gray-900">
            Active Scraping Configuration
          </h3>
          <p class="mt-1 text-sm text-gray-500">
            Currently active configuration profile: <span class="font-medium text-gray-900">{activeConfig.name}</span>
          </p>
        </div>

        <div class="px-4 py-5 sm:p-6">
          <dl class="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2 lg:grid-cols-3">
            <div>
              <dt class="text-sm font-medium text-gray-500">HSE Database</dt>
              <dd class="mt-1 text-sm text-gray-900">{activeConfig.hse_database}</dd>
            </div>

            <div>
              <dt class="text-sm font-medium text-gray-500">Requests per Minute</dt>
              <dd class="mt-1 text-sm text-gray-900">{activeConfig.requests_per_minute}</dd>
            </div>

            <div>
              <dt class="text-sm font-medium text-gray-500">Max Pages per Session</dt>
              <dd class="mt-1 text-sm text-gray-900">{activeConfig.max_pages_per_session}</dd>
            </div>

            <div>
              <dt class="text-sm font-medium text-gray-500">Batch Size</dt>
              <dd class="mt-1 text-sm text-gray-900">{activeConfig.batch_size}</dd>
            </div>

            <div>
              <dt class="text-sm font-medium text-gray-500">Scheduled Scraping</dt>
              <dd class="mt-1">
                {#if activeConfig.scheduled_scraping_enabled}
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                    Enabled
                  </span>
                {:else}
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                    Disabled
                  </span>
                {/if}
              </dd>
            </div>

            <div>
              <dt class="text-sm font-medium text-gray-500">Manual Scraping</dt>
              <dd class="mt-1">
                {#if activeConfig.manual_scraping_enabled}
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                    Enabled
                  </span>
                {:else}
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                    Disabled
                  </span>
                {/if}
              </dd>
            </div>
          </dl>

          <div class="mt-6">
            <a
              href="/admin/config/scraping"
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              View All Configurations
              <svg class="ml-2 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </a>
          </div>
        </div>
      </div>
    {:else}
      <div class="mt-8 bg-yellow-50 border border-yellow-200 rounded-md p-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-yellow-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-yellow-800">No Active Configuration</h3>
            <div class="mt-2 text-sm text-yellow-700">
              <p>No scraping configuration is currently active. Create or activate a configuration profile.</p>
            </div>
            <div class="mt-4">
              <a
                href="/admin/config/scraping/new"
                class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-yellow-800 bg-yellow-100 hover:bg-yellow-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-yellow-500"
              >
                Create Configuration
              </a>
            </div>
          </div>
        </div>
      </div>
    {/if}

  </div>
</div>
