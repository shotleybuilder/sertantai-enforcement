<script lang="ts">
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { browser } from '$app/environment'
  import { useOffenderQuery, useUpdateOffenderMutation } from '$lib/query/offenders-edit'

  // Get offender ID from URL
  $: offenderId = $page.params.id

  // TanStack queries
  $: offenderQuery = browser ? useOffenderQuery(offenderId) : null
  const updateMutation = browser ? useUpdateOffenderMutation() : null

  // Offender data
  $: offender = $offenderQuery?.data

  // Form state
  let formData = {
    name: '',
    address: '',
    local_authority: '',
    country: '',
    main_activity: '',
    sic_code: '',
    business_type: '',
    industry: '',
  }

  // Update form data when offender loads
  $: if (offender) {
    formData = {
      name: offender.name || '',
      address: offender.address || '',
      local_authority: offender.local_authority || '',
      country: offender.country || '',
      main_activity: offender.main_activity || '',
      sic_code: offender.sic_code || '',
      business_type: offender.business_type || '',
      industry: offender.industry || '',
    }
  }

  // Save offender
  function handleSave() {
    if (!confirm('Are you sure you want to save these changes?')) {
      return
    }

    $updateMutation?.mutate(
      { id: offenderId, ...formData },
      {
        onSuccess: () => {
          alert('Offender updated successfully')
          goto('/offenders')
        },
        onError: (error) => {
          alert(`Failed to update offender: ${error.message}`)
        },
      },
    )
  }

  // Cancel editing
  function handleCancel() {
    goto('/offenders')
  }
</script>

<div class="min-h-screen bg-gray-50">
  <!-- Header -->
  <div class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="py-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">Edit Offender</h1>
            {#if offender}
              <p class="mt-2 text-sm text-gray-700">
                {offender.name} - {offender.postcode || 'No postcode'}
              </p>
            {/if}
          </div>

          <a
            href="/offenders"
            class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
          >
            <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M10 19l-7-7m0 0l7-7m-7 7h18"
              />
            </svg>
            Back to Offenders
          </a>
        </div>
      </div>
    </div>
  </div>

  <!-- Main Content -->
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <!-- Loading State -->
    {#if !offenderQuery || $offenderQuery.isLoading}
      <div class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-sm text-gray-500">Loading offender...</p>
      </div>
    {:else if $offenderQuery.isError}
      <!-- Error State -->
      <div class="bg-red-50 border border-red-200 rounded-md p-4">
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
            <h3 class="text-sm font-medium text-red-800">Error</h3>
            <p class="mt-2 text-sm text-red-700">
              {$offenderQuery.error?.message || 'Failed to load offender'}
            </p>
          </div>
        </div>
      </div>
    {:else if offender}
      <form on:submit|preventDefault={handleSave} class="space-y-6">
        <!-- Basic Information -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">Basic Information</h3>
            <p class="mt-1 text-sm text-gray-500">Core details about the offender</p>
          </div>
          <div class="px-4 py-5 sm:p-6">
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div class="col-span-2">
                <label for="name" class="block text-sm font-medium text-gray-700">
                  Name <span class="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  id="name"
                  bind:value={formData.name}
                  required
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>

              <div class="col-span-2">
                <label for="address" class="block text-sm font-medium text-gray-700"> Address </label>
                <textarea
                  id="address"
                  bind:value={formData.address}
                  rows="2"
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                ></textarea>
              </div>

              <div>
                <label for="local_authority" class="block text-sm font-medium text-gray-700">
                  Local Authority
                </label>
                <input
                  type="text"
                  id="local_authority"
                  bind:value={formData.local_authority}
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>

              <div>
                <label for="country" class="block text-sm font-medium text-gray-700"> Country </label>
                <input
                  type="text"
                  id="country"
                  bind:value={formData.country}
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Business Information -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">Business Information</h3>
            <p class="mt-1 text-sm text-gray-500">Industry and business classification details</p>
          </div>
          <div class="px-4 py-5 sm:p-6">
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div class="col-span-2">
                <label for="main_activity" class="block text-sm font-medium text-gray-700">
                  Main Activity
                </label>
                <textarea
                  id="main_activity"
                  bind:value={formData.main_activity}
                  rows="2"
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                ></textarea>
              </div>

              <div>
                <label for="sic_code" class="block text-sm font-medium text-gray-700"> SIC Code </label>
                <input
                  type="text"
                  id="sic_code"
                  bind:value={formData.sic_code}
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>

              <div>
                <label for="business_type" class="block text-sm font-medium text-gray-700">
                  Business Type
                </label>
                <input
                  type="text"
                  id="business_type"
                  bind:value={formData.business_type}
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>

              <div class="col-span-2">
                <label for="industry" class="block text-sm font-medium text-gray-700"> Industry </label>
                <input
                  type="text"
                  id="industry"
                  bind:value={formData.industry}
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Read-Only Summary -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">Enforcement Summary</h3>
            <p class="mt-1 text-sm text-gray-500">Read-only statistics (calculated from cases and notices)</p>
          </div>
          <div class="px-4 py-5 sm:p-6">
            <dl class="grid grid-cols-1 gap-6 sm:grid-cols-3">
              <div>
                <dt class="text-sm font-medium text-gray-500">Total Cases</dt>
                <dd class="mt-1 text-3xl font-semibold text-gray-900">{offender.total_cases}</dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Total Notices</dt>
                <dd class="mt-1 text-3xl font-semibold text-gray-900">{offender.total_notices}</dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Total Fines</dt>
                <dd class="mt-1 text-3xl font-semibold text-gray-900">
                  £{offender.total_fines?.toLocaleString() || '0'}
                </dd>
              </div>
            </dl>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="flex items-center justify-end space-x-4">
          <button
            type="button"
            on:click={handleCancel}
            class="px-6 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={$updateMutation?.isPending}
            class="px-6 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 disabled:opacity-50"
          >
            {$updateMutation?.isPending ? 'Saving...' : 'Save Changes'}
          </button>
        </div>
      </form>
    {/if}
  </div>
</div>
