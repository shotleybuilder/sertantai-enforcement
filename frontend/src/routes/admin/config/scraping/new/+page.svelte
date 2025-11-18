<script lang="ts">
  import { goto } from '$app/navigation'
  import { browser } from '$app/environment'
  import { useCreateScrapingConfigMutation } from '$lib/query/scraping-configs'

  // TanStack mutation
  const createMutation = browser ? useCreateScrapingConfigMutation() : null

  // Form state - Basic Info
  let name = ''
  let description = ''
  let is_active = true

  // HSE Configuration
  let hse_base_url = 'https://www.hse.gov.uk'
  let hse_database: 'convictions' | 'enforcement' | 'notices' = 'convictions'

  // Rate Limiting
  let requests_per_minute = 10
  let network_timeout_ms = 30000
  let pause_between_pages_ms = 3000

  // Scraping Behavior
  let consecutive_existing_threshold = 10
  let max_pages_per_session = 100
  let max_consecutive_errors = 3
  let batch_size = 50

  // Feature Flags
  let scheduled_scraping_enabled = true
  let manual_scraping_enabled = true
  let real_time_progress_enabled = true
  let admin_notifications_enabled = true

  // Schedules
  let daily_scrape_cron = '0 2 * * *'
  let weekly_scrape_cron = '0 1 * * 0'

  // Form validation
  $: isValid = name.trim().length > 0

  // Handle form submission
  function handleSubmit(event: Event) {
    event.preventDefault()

    if (!isValid) {
      return
    }

    createMutation?.mutate(
      {
        name: name.trim(),
        description: description.trim() || null,
        is_active,
        hse_base_url,
        hse_database,
        requests_per_minute,
        network_timeout_ms,
        pause_between_pages_ms,
        consecutive_existing_threshold,
        max_pages_per_session,
        max_consecutive_errors,
        batch_size,
        scheduled_scraping_enabled,
        manual_scraping_enabled,
        real_time_progress_enabled,
        admin_notifications_enabled,
        daily_scrape_cron: daily_scrape_cron.trim() || null,
        weekly_scrape_cron: weekly_scrape_cron.trim() || null,
      },
      {
        onSuccess: () => {
          setTimeout(() => {
            goto('/admin/config/scraping')
          }, 500)
        },
      }
    )
  }

  function handleCancel() {
    goto('/admin/config/scraping')
  }
</script>

<div class="min-h-screen bg-gray-50">
  <!-- Header -->
  <div class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="py-6">
        <div class="flex items-center justify-between">
          <div>
            <nav class="flex" aria-label="Breadcrumb">
              <ol class="flex items-center space-x-4">
                <li>
                  <div>
                    <a href="/admin/config" class="text-gray-400 hover:text-gray-500">
                      <svg class="flex-shrink-0 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                      </svg>
                      <span class="sr-only">Configuration</span>
                    </a>
                  </div>
                </li>
                <li>
                  <div class="flex items-center">
                    <svg class="flex-shrink-0 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                    </svg>
                    <a href="/admin/config/scraping" class="ml-4 text-sm font-medium text-gray-500 hover:text-gray-700">
                      Scraping
                    </a>
                  </div>
                </li>
                <li>
                  <div class="flex items-center">
                    <svg class="flex-shrink-0 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                    </svg>
                    <span class="ml-4 text-sm font-medium text-gray-500">
                      New
                    </span>
                  </div>
                </li>
              </ol>
            </nav>
            <h1 class="mt-2 text-3xl font-bold text-gray-900">New Scraping Configuration</h1>
            <p class="mt-1 text-sm text-gray-500">
              Create a new configuration profile for scraping operations
            </p>
          </div>

          <div class="flex space-x-3">
            <button
              type="button"
              on:click={handleCancel}
              class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
            >
              Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Main Content -->
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <form on:submit={handleSubmit} class="space-y-6">

      <!-- Success Message -->
      {#if createMutation && $createMutation.isSuccess}
        <div class="bg-green-50 border border-green-200 rounded-md p-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-green-800">Configuration Created!</h3>
              <p class="mt-2 text-sm text-green-700">Redirecting...</p>
            </div>
          </div>
        </div>
      {/if}

      <!-- Error Message -->
      {#if createMutation && $createMutation.isError}
        <div class="bg-red-50 border border-red-200 rounded-md p-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-red-800">Error</h3>
              <p class="mt-2 text-sm text-red-700">{$createMutation.error?.message || 'Failed to create configuration'}</p>
            </div>
          </div>
        </div>
      {/if}

      <!-- Basic Information Section -->
      <div class="bg-white shadow overflow-hidden sm:rounded-lg">
        <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
          <h3 class="text-lg leading-6 font-medium text-gray-900">Basic Information</h3>
        </div>
        <div class="px-4 py-5 sm:p-6">
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
            <div>
              <label for="name" class="block text-sm font-medium text-gray-700">Name *</label>
              <input
                type="text"
                id="name"
                bind:value={name}
                required
                placeholder="e.g., hse_production"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
              <p class="mt-1 text-sm text-gray-500">Unique identifier for this configuration</p>
            </div>

            <div>
              <label for="is_active" class="block text-sm font-medium text-gray-700">Status</label>
              <div class="mt-2 flex items-center">
                <input
                  type="checkbox"
                  id="is_active"
                  bind:checked={is_active}
                  class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
                <label for="is_active" class="ml-2 text-sm text-gray-700">
                  Set as active configuration
                </label>
              </div>
            </div>

            <div class="sm:col-span-2">
              <label for="description" class="block text-sm font-medium text-gray-700">Description</label>
              <textarea
                id="description"
                bind:value={description}
                rows="3"
                placeholder="Optional description of this configuration profile"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              ></textarea>
            </div>
          </div>
        </div>
      </div>

      <!-- HSE Configuration Section -->
      <div class="bg-white shadow overflow-hidden sm:rounded-lg">
        <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
          <h3 class="text-lg leading-6 font-medium text-gray-900">HSE Configuration</h3>
        </div>
        <div class="px-4 py-5 sm:p-6">
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
            <div>
              <label for="hse_base_url" class="block text-sm font-medium text-gray-700">HSE Base URL *</label>
              <input
                type="url"
                id="hse_base_url"
                bind:value={hse_base_url}
                required
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>

            <div>
              <label for="hse_database" class="block text-sm font-medium text-gray-700">HSE Database *</label>
              <select
                id="hse_database"
                bind:value={hse_database}
                required
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              >
                <option value="convictions">Convictions</option>
                <option value="enforcement">Enforcement</option>
                <option value="notices">Notices</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <!-- Rate Limiting Section -->
      <div class="bg-white shadow overflow-hidden sm:rounded-lg">
        <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
          <h3 class="text-lg leading-6 font-medium text-gray-900">Rate Limiting</h3>
        </div>
        <div class="px-4 py-5 sm:p-6">
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-3">
            <div>
              <label for="requests_per_minute" class="block text-sm font-medium text-gray-700">Requests per Minute</label>
              <input
                type="number"
                id="requests_per_minute"
                bind:value={requests_per_minute}
                min="1"
                required
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>

            <div>
              <label for="network_timeout_ms" class="block text-sm font-medium text-gray-700">Network Timeout (ms)</label>
              <input
                type="number"
                id="network_timeout_ms"
                bind:value={network_timeout_ms}
                min="5000"
                step="1000"
                required
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>

            <div>
              <label for="pause_between_pages_ms" class="block text-sm font-medium text-gray-700">Pause Between Pages (ms)</label>
              <input
                type="number"
                id="pause_between_pages_ms"
                bind:value={pause_between_pages_ms}
                min="0"
                step="500"
                required
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Scraping Behavior Section -->
      <div class="bg-white shadow overflow-hidden sm:rounded-lg">
        <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
          <h3 class="text-lg leading-6 font-medium text-gray-900">Scraping Behavior</h3>
        </div>
        <div class="px-4 py-5 sm:p-6">
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
            <div>
              <label for="consecutive_existing_threshold" class="block text-sm font-medium text-gray-700">Consecutive Existing Threshold</label>
              <input
                type="number"
                id="consecutive_existing_threshold"
                bind:value={consecutive_existing_threshold}
                min="3"
                required
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
              <p class="mt-1 text-xs text-gray-500">Stop after N existing records</p>
            </div>

            <div>
              <label for="max_pages_per_session" class="block text-sm font-medium text-gray-700">Max Pages per Session</label>
              <input
                type="number"
                id="max_pages_per_session"
                bind:value={max_pages_per_session}
                min="5"
                required
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>

            <div>
              <label for="max_consecutive_errors" class="block text-sm font-medium text-gray-700">Max Consecutive Errors</label>
              <input
                type="number"
                id="max_consecutive_errors"
                bind:value={max_consecutive_errors}
                min="1"
                required
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>

            <div>
              <label for="batch_size" class="block text-sm font-medium text-gray-700">Batch Size</label>
              <input
                type="number"
                id="batch_size"
                bind:value={batch_size}
                min="10"
                required
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Feature Flags Section -->
      <div class="bg-white shadow overflow-hidden sm:rounded-lg">
        <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
          <h3 class="text-lg leading-6 font-medium text-gray-900">Feature Flags</h3>
        </div>
        <div class="px-4 py-5 sm:p-6">
          <div class="space-y-4">
            <div class="flex items-start">
              <div class="flex items-center h-5">
                <input
                  type="checkbox"
                  id="scheduled_scraping_enabled"
                  bind:checked={scheduled_scraping_enabled}
                  class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
              </div>
              <div class="ml-3">
                <label for="scheduled_scraping_enabled" class="font-medium text-gray-700">Scheduled Scraping</label>
                <p class="text-sm text-gray-500">Enable automatic scheduled scraping runs</p>
              </div>
            </div>

            <div class="flex items-start">
              <div class="flex items-center h-5">
                <input
                  type="checkbox"
                  id="manual_scraping_enabled"
                  bind:checked={manual_scraping_enabled}
                  class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
              </div>
              <div class="ml-3">
                <label for="manual_scraping_enabled" class="font-medium text-gray-700">Manual Scraping</label>
                <p class="text-sm text-gray-500">Allow admin-triggered manual scraping</p>
              </div>
            </div>

            <div class="flex items-start">
              <div class="flex items-center h-5">
                <input
                  type="checkbox"
                  id="real_time_progress_enabled"
                  bind:checked={real_time_progress_enabled}
                  class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
              </div>
              <div class="ml-3">
                <label for="real_time_progress_enabled" class="font-medium text-gray-700">Real-time Progress</label>
                <p class="text-sm text-gray-500">Enable real-time progress updates via PubSub</p>
              </div>
            </div>

            <div class="flex items-start">
              <div class="flex items-center h-5">
                <input
                  type="checkbox"
                  id="admin_notifications_enabled"
                  bind:checked={admin_notifications_enabled}
                  class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
              </div>
              <div class="ml-3">
                <label for="admin_notifications_enabled" class="font-medium text-gray-700">Admin Notifications</label>
                <p class="text-sm text-gray-500">Send notifications for critical errors</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Schedules Section -->
      <div class="bg-white shadow overflow-hidden sm:rounded-lg">
        <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
          <h3 class="text-lg leading-6 font-medium text-gray-900">Cron Schedules</h3>
        </div>
        <div class="px-4 py-5 sm:p-6">
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
            <div>
              <label for="daily_scrape_cron" class="block text-sm font-medium text-gray-700">Daily Scrape Schedule</label>
              <input
                type="text"
                id="daily_scrape_cron"
                bind:value={daily_scrape_cron}
                placeholder="0 2 * * *"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm font-mono"
              />
              <p class="mt-1 text-xs text-gray-500">Cron expression (default: 2 AM daily)</p>
            </div>

            <div>
              <label for="weekly_scrape_cron" class="block text-sm font-medium text-gray-700">Weekly Scrape Schedule</label>
              <input
                type="text"
                id="weekly_scrape_cron"
                bind:value={weekly_scrape_cron}
                placeholder="0 1 * * 0"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm font-mono"
              />
              <p class="mt-1 text-xs text-gray-500">Cron expression (default: 1 AM Sunday)</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="flex justify-end space-x-3">
        <button
          type="button"
          on:click={handleCancel}
          class="px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
        >
          Cancel
        </button>
        <button
          type="submit"
          disabled={!isValid || (createMutation && ($createMutation.isPending || $createMutation.isSuccess))}
          class="px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {#if createMutation && $createMutation.isPending}
            Creating...
          {:else if createMutation && $createMutation.isSuccess}
            Created!
          {:else}
            Create Configuration
          {/if}
        </button>
      </div>

    </form>
  </div>
</div>
