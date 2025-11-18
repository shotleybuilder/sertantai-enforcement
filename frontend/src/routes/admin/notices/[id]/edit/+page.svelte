<script lang="ts">
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { browser } from '$app/environment'
  import { useNoticeQuery, useUpdateNoticeMutation } from '$lib/query/notices-edit'

  // Get notice ID from URL
  $: noticeId = $page.params.id

  // TanStack queries
  $: noticeQuery = browser ? useNoticeQuery(noticeId) : null
  const updateMutation = browser ? useUpdateNoticeMutation() : null

  // Notice data
  $: notice = $noticeQuery?.data

  // Form state
  let formData = {
    regulator_id: '',
    regulator_ref_number: '',
    notice_date: '',
    operative_date: '',
    compliance_date: '',
    notice_body: '',
    offence_action_type: '',
    offence_action_date: '',
    url: '',
    environmental_impact: '',
    environmental_receptor: '',
  }

  // Update form data when notice loads
  $: if (notice) {
    formData = {
      regulator_id: notice.regulator_id || '',
      regulator_ref_number: notice.regulator_ref_number || '',
      notice_date: notice.notice_date || '',
      operative_date: notice.operative_date || '',
      compliance_date: notice.compliance_date || '',
      notice_body: notice.notice_body || '',
      offence_action_type: notice.offence_action_type || '',
      offence_action_date: notice.offence_action_date || '',
      url: notice.url || '',
      environmental_impact: notice.environmental_impact || '',
      environmental_receptor: notice.environmental_receptor || '',
    }
  }

  // Save notice
  function handleSave() {
    if (!confirm('Are you sure you want to save these changes?')) {
      return
    }

    updateMutation?.mutate(
      { id: noticeId, ...formData },
      {
        onSuccess: () => {
          alert('Notice updated successfully')
          goto('/notices')
        },
        onError: (error) => {
          alert(`Failed to update notice: ${error.message}`)
        },
      },
    )
  }

  // Cancel editing
  function handleCancel() {
    goto('/notices')
  }
</script>

<div class="min-h-screen bg-gray-50">
  <!-- Header -->
  <div class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="py-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">Edit Notice</h1>
            {#if notice}
              <p class="mt-2 text-sm text-gray-700">
                {notice.regulator_id} - {notice.offender?.name || 'Unknown offender'}
              </p>
            {/if}
          </div>

          <a
            href="/notices"
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
            Back to Notices
          </a>
        </div>
      </div>
    </div>
  </div>

  <!-- Main Content -->
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <!-- Loading State -->
    {#if !noticeQuery || $noticeQuery.isLoading}
      <div class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-sm text-gray-500">Loading notice...</p>
      </div>
    {:else if $noticeQuery.isError}
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
              {$noticeQuery.error?.message || 'Failed to load notice'}
            </p>
          </div>
        </div>
      </div>
    {:else if notice}
      <form on:submit|preventDefault={handleSave} class="space-y-6">
        <!-- Basic Information -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">Basic Information</h3>
            <p class="mt-1 text-sm text-gray-500">Core notice identification details</p>
          </div>
          <div class="px-4 py-5 sm:p-6">
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div>
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

              <div>
                <label for="regulator_ref_number" class="block text-sm font-medium text-gray-700">
                  Reference Number
                </label>
                <input
                  type="text"
                  id="regulator_ref_number"
                  bind:value={formData.regulator_ref_number}
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

        <!-- Notice Details -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">Notice Details</h3>
            <p class="mt-1 text-sm text-gray-500">Notice body and action type</p>
          </div>
          <div class="px-4 py-5 sm:p-6">
            <div class="grid grid-cols-1 gap-6">
              <div>
                <label for="notice_body" class="block text-sm font-medium text-gray-700">
                  Notice Body
                </label>
                <textarea
                  id="notice_body"
                  bind:value={formData.notice_body}
                  rows="4"
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                ></textarea>
              </div>

              <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
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
              </div>
            </div>
          </div>
        </div>

        <!-- Date Information -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">Important Dates</h3>
            <p class="mt-1 text-sm text-gray-500">Notice, operative, and compliance dates</p>
          </div>
          <div class="px-4 py-5 sm:p-6">
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-3">
              <div>
                <label for="notice_date" class="block text-sm font-medium text-gray-700">
                  Notice Date
                </label>
                <input
                  type="date"
                  id="notice_date"
                  bind:value={formData.notice_date}
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>

              <div>
                <label for="operative_date" class="block text-sm font-medium text-gray-700">
                  Operative Date
                </label>
                <input
                  type="date"
                  id="operative_date"
                  bind:value={formData.operative_date}
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>

              <div>
                <label for="compliance_date" class="block text-sm font-medium text-gray-700">
                  Compliance Date
                </label>
                <input
                  type="date"
                  id="compliance_date"
                  bind:value={formData.compliance_date}
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Environmental Information -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">Environmental Details</h3>
            <p class="mt-1 text-sm text-gray-500">Impact and receptor information (EA notices)</p>
          </div>
          <div class="px-4 py-5 sm:p-6">
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div>
                <label for="environmental_impact" class="block text-sm font-medium text-gray-700">
                  Environmental Impact
                </label>
                <input
                  type="text"
                  id="environmental_impact"
                  bind:value={formData.environmental_impact}
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>

              <div>
                <label for="environmental_receptor" class="block text-sm font-medium text-gray-700">
                  Environmental Receptor
                </label>
                <input
                  type="text"
                  id="environmental_receptor"
                  bind:value={formData.environmental_receptor}
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
                <dd class="mt-1 text-sm text-gray-900">{notice.agency?.name || 'Not assigned'}</dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Offender</dt>
                <dd class="mt-1 text-sm text-gray-900">
                  {notice.offender?.name || 'Not assigned'}
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
