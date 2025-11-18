<script lang="ts">
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { browser } from '$app/environment'
  import { useCaseQuery, useUpdateCaseMutation } from '$lib/query/cases-edit'

  // Get case ID from URL
  $: caseId = $page.params.id

  // TanStack queries
  $: caseQuery = browser ? useCaseQuery(caseId) : null
  const updateMutation = browser ? useUpdateCaseMutation() : null

  // Case data
  $: caseRecord = $caseQuery?.data

  // Form state
  let formData = {
    regulator_id: '',
    offence_result: '',
    offence_fine: null as number | null,
    offence_costs: null as number | null,
    offence_action_date: '',
    offence_hearing_date: '',
    offence_action_type: '',
    regulator_function: '',
    url: '',
  }

  // Update form data when case loads
  $: if (caseRecord) {
    formData = {
      regulator_id: caseRecord.regulator_id || '',
      offence_result: caseRecord.offence_result || '',
      offence_fine: caseRecord.offence_fine,
      offence_costs: caseRecord.offence_costs,
      offence_action_date: caseRecord.offence_action_date || '',
      offence_hearing_date: caseRecord.offence_hearing_date || '',
      offence_action_type: caseRecord.offence_action_type || '',
      regulator_function: caseRecord.regulator_function || '',
      url: caseRecord.url || '',
    }
  }

  // Save case
  function handleSave() {
    if (!confirm('Are you sure you want to save these changes?')) {
      return
    }

    updateMutation?.mutate(
      { id: caseId, ...formData },
      {
        onSuccess: () => {
          alert('Case updated successfully')
          goto('/cases')
        },
        onError: (error) => {
          alert(`Failed to update case: ${error.message}`)
        },
      },
    )
  }

  // Cancel editing
  function handleCancel() {
    goto('/cases')
  }
</script>

<div class="min-h-screen bg-gray-50">
  <!-- Header -->
  <div class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="py-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">Edit Case</h1>
            {#if caseRecord}
              <p class="mt-2 text-sm text-gray-700">
                {caseRecord.regulator_id} - {caseRecord.offender?.name || 'Unknown offender'}
              </p>
            {/if}
          </div>

          <a
            href="/cases"
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
            Back to Cases
          </a>
        </div>
      </div>
    </div>
  </div>

  <!-- Main Content -->
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <!-- Loading State -->
    {#if !caseQuery || $caseQuery.isLoading}
      <div class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-sm text-gray-500">Loading case...</p>
      </div>
    {:else if $caseQuery.isError}
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
              {$caseQuery.error?.message || 'Failed to load case'}
            </p>
          </div>
        </div>
      </div>
    {:else if caseRecord}
      <form on:submit|preventDefault={handleSave} class="space-y-6">
        <!-- Basic Information -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">Basic Information</h3>
            <p class="mt-1 text-sm text-gray-500">Core case identification details</p>
          </div>
          <div class="px-4 py-5 sm:p-6">
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div class="col-span-2">
                <label for="regulator_id" class="block text-sm font-medium text-gray-700">
                  Regulator ID <span class="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  id="regulator_id"
                  bind:value={formData.regulator_id}
                  required
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>

              <div class="col-span-2">
                <label for="url" class="block text-sm font-medium text-gray-700"> URL </label>
                <input
                  type="url"
                  id="url"
                  bind:value={formData.url}
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Offence Details -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">Offence Details</h3>
            <p class="mt-1 text-sm text-gray-500">Offence result and type information</p>
          </div>
          <div class="px-4 py-5 sm:p-6">
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div class="col-span-2">
                <label for="offence_result" class="block text-sm font-medium text-gray-700">
                  Offence Result
                </label>
                <input
                  type="text"
                  id="offence_result"
                  bind:value={formData.offence_result}
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>

              <div>
                <label for="offence_action_type" class="block text-sm font-medium text-gray-700">
                  Action Type
                </label>
                <input
                  type="text"
                  id="offence_action_type"
                  bind:value={formData.offence_action_type}
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>

              <div>
                <label for="regulator_function" class="block text-sm font-medium text-gray-700">
                  Regulator Function
                </label>
                <input
                  type="text"
                  id="regulator_function"
                  bind:value={formData.regulator_function}
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Financial Information -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">Financial Information</h3>
            <p class="mt-1 text-sm text-gray-500">Fines and costs associated with the case</p>
          </div>
          <div class="px-4 py-5 sm:p-6">
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div>
                <label for="offence_fine" class="block text-sm font-medium text-gray-700">
                  Fine (£)
                </label>
                <input
                  type="number"
                  id="offence_fine"
                  bind:value={formData.offence_fine}
                  step="0.01"
                  min="0"
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>

              <div>
                <label for="offence_costs" class="block text-sm font-medium text-gray-700">
                  Costs (£)
                </label>
                <input
                  type="number"
                  id="offence_costs"
                  bind:value={formData.offence_costs}
                  step="0.01"
                  min="0"
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Date Information -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">Important Dates</h3>
            <p class="mt-1 text-sm text-gray-500">Action and hearing dates</p>
          </div>
          <div class="px-4 py-5 sm:p-6">
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div>
                <label for="offence_action_date" class="block text-sm font-medium text-gray-700">
                  Action Date
                </label>
                <input
                  type="date"
                  id="offence_action_date"
                  bind:value={formData.offence_action_date}
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>

              <div>
                <label for="offence_hearing_date" class="block text-sm font-medium text-gray-700">
                  Hearing Date
                </label>
                <input
                  type="date"
                  id="offence_hearing_date"
                  bind:value={formData.offence_hearing_date}
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Read-Only Related Information -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">Related Information</h3>
            <p class="mt-1 text-sm text-gray-500">Read-only associated data</p>
          </div>
          <div class="px-4 py-5 sm:p-6">
            <dl class="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div>
                <dt class="text-sm font-medium text-gray-500">Agency</dt>
                <dd class="mt-1 text-sm text-gray-900">
                  {caseRecord.agency?.name || 'Not assigned'}
                </dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Offender</dt>
                <dd class="mt-1 text-sm text-gray-900">
                  {caseRecord.offender?.name || 'Not assigned'}
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
