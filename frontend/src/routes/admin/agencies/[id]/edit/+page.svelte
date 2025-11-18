<script lang="ts">
  import { onMount } from 'svelte'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { browser } from '$app/environment'
  import { useAgencyQuery, useUpdateAgencyMutation } from '$lib/query/agencies'

  // Get agency ID from route params
  $: id = $page.params.id

  // TanStack queries/mutations (only in browser, not SSR)
  $: agencyQuery = browser && id ? useAgencyQuery(id) : null
  const updateMutation = browser ? useUpdateAgencyMutation() : null

  // Form state - initialized from agency data
  let name = ''
  let baseUrl = ''
  let enabled = true
  let code = ''

  // Track if form has been initialized
  let formInitialized = false

  // Initialize form when agency data loads
  $: if (agencyQuery && $agencyQuery.isSuccess && $agencyQuery.data && !formInitialized) {
    const agency = $agencyQuery.data
    name = agency.name
    baseUrl = agency.base_url || ''
    enabled = agency.enabled
    code = agency.code
    formInitialized = true
  }

  // Form validation
  $: isValid = name.trim().length > 0

  // Handle form submission with TanStack mutation
  function handleSubmit(event: Event) {
    event.preventDefault()

    if (!isValid || !id) {
      return
    }

    // Use TanStack mutation with optimistic updates
    updateMutation?.mutate(
      {
        id,
        name: name.trim(),
        base_url: baseUrl.trim() || null,
        enabled,
      },
      {
        onSuccess: () => {
          // Redirect to agencies list after successful update
          setTimeout(() => {
            goto('/admin/agencies')
          }, 500) // Small delay to show success state
        },
      }
    )
  }

  function handleCancel() {
    goto('/admin/agencies')
  }

  // Field descriptions
  const fieldDescriptions = {
    code: 'Agency code cannot be changed after creation',
    name: 'Display name for this enforcement agency',
    base_url: 'Base URL for this agency\'s enforcement data source',
    enabled: 'Whether this agency should be active in the system'
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
                    <a href="/admin/agencies" class="text-gray-400 hover:text-gray-500">
                      <svg class="flex-shrink-0 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                      </svg>
                      <span class="sr-only">Agencies</span>
                    </a>
                  </div>
                </li>
                <li>
                  <div class="flex items-center">
                    <svg class="flex-shrink-0 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                    </svg>
                    <a href="/admin/agencies" class="ml-4 text-sm font-medium text-gray-500 hover:text-gray-700">
                      Agencies
                    </a>
                  </div>
                </li>
                <li>
                  <div class="flex items-center">
                    <svg class="flex-shrink-0 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                    </svg>
                    <span class="ml-4 text-sm font-medium text-gray-500">
                      Edit
                    </span>
                  </div>
                </li>
              </ol>
            </nav>
            <h1 class="mt-2 text-3xl font-bold text-gray-900">Edit Agency</h1>
            <p class="mt-1 text-sm text-gray-500">
              Update agency details
            </p>
          </div>

          <div class="flex space-x-3">
            <button
              type="button"
              on:click={handleCancel}
              class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
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
    <div class="bg-white shadow overflow-hidden sm:rounded-lg">

      <!-- Loading State -->
      {#if !agencyQuery || $agencyQuery.isLoading}
        <div class="text-center py-12">
          <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          <p class="mt-2 text-sm text-gray-500">Loading agency...</p>
        </div>
      {:else if $agencyQuery.isError}
        <!-- Error State -->
        <div class="px-4 py-5 sm:p-6">
          <div class="bg-red-50 border border-red-200 rounded-md p-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-red-800">Error Loading Agency</h3>
                <div class="mt-2 text-sm text-red-700">
                  <p>{$agencyQuery.error?.message || 'Failed to load agency'}</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      {:else if !$agencyQuery.data}
        <!-- Not Found State -->
        <div class="px-4 py-5 sm:p-6">
          <div class="text-center py-12">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">Agency Not Found</h3>
            <p class="mt-1 text-sm text-gray-500">
              The agency you're looking for doesn't exist or has been deleted.
            </p>
            <div class="mt-6">
              <a
                href="/admin/agencies"
                class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                Back to Agencies
              </a>
            </div>
          </div>
        </div>
      {:else}
        <!-- Edit Form -->
        <form on:submit={handleSubmit} class="space-y-0">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-6">Agency Details</h3>

            <!-- Success Message -->
            {#if updateMutation && $updateMutation.isSuccess}
              <div class="mb-6 bg-green-50 border border-green-200 rounded-md p-4">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <h3 class="text-sm font-medium text-green-800">Agency Updated Successfully!</h3>
                    <div class="mt-2 text-sm text-green-700">
                      <p>Redirecting to agencies list...</p>
                    </div>
                  </div>
                </div>
              </div>
            {/if}

            <!-- Error Message -->
            {#if updateMutation && $updateMutation.isError}
              <div class="mb-6 bg-red-50 border border-red-200 rounded-md p-4">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <h3 class="text-sm font-medium text-red-800">Error</h3>
                    <div class="mt-2 text-sm text-red-700">
                      <p>{$updateMutation.error?.message || 'Failed to update agency'}</p>
                    </div>
                  </div>
                </div>
              </div>
            {/if}

            <!-- Three-column layout table -->
            <div class="overflow-hidden">
              <table class="min-w-full">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-1/4">
                      Field
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-2/5">
                      Description
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-1/3">
                      Value
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <!-- Code Field (read-only) -->
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      Code
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-500">
                      {fieldDescriptions.code}
                    </td>
                    <td class="px-6 py-4">
                      <div class="flex items-center">
                        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                          {code.toUpperCase()}
                        </span>
                        <span class="ml-2 text-xs text-gray-500">(read-only)</span>
                      </div>
                    </td>
                  </tr>

                  <!-- Name Field -->
                  <tr class="bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      Name *
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-500">
                      {fieldDescriptions.name}
                    </td>
                    <td class="px-6 py-4">
                      <input
                        type="text"
                        bind:value={name}
                        required
                        placeholder="Enter agency name"
                        class="max-w-md block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                      />
                    </td>
                  </tr>

                  <!-- Base URL Field -->
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      Base URL
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-500">
                      {fieldDescriptions.base_url}
                    </td>
                    <td class="px-6 py-4">
                      <input
                        type="url"
                        bind:value={baseUrl}
                        placeholder="https://example.com"
                        class="max-w-md block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                      />
                    </td>
                  </tr>

                  <!-- Enabled Field -->
                  <tr class="bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      Enabled
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-500">
                      {fieldDescriptions.enabled}
                    </td>
                    <td class="px-6 py-4">
                      <div class="flex items-center">
                        <input
                          type="checkbox"
                          bind:checked={enabled}
                          class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                        />
                        <label class="ml-2 text-sm text-gray-700">
                          Agency is active
                        </label>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div class="mt-6 text-sm text-gray-500">
              <p><span class="text-red-500">*</span> Required fields</p>
            </div>
          </div>

          <!-- Action Buttons -->
          <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
            <button
              type="submit"
              disabled={!isValid || (updateMutation && ($updateMutation.isPending || $updateMutation.isSuccess))}
              class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-blue-600 text-base font-medium text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 sm:ml-3 sm:w-auto sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {#if updateMutation && $updateMutation.isPending}
                <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Updating...
              {:else if updateMutation && $updateMutation.isSuccess}
                <svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                Updated!
              {:else}
                Update Agency
              {/if}
            </button>
            <button
              type="button"
              on:click={handleCancel}
              class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
            >
              Cancel
            </button>
          </div>
        </form>
      {/if}
    </div>
  </div>
</div>
