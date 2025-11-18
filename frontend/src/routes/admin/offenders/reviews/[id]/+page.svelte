<script lang="ts">
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { browser } from '$app/environment'
  import {
    useMatchReviewQuery,
    useApproveMatchMutation,
    useSkipMatchMutation,
    useFlagForLaterMutation,
    type CandidateCompany,
  } from '$lib/query/match-reviews'

  // Get review ID from URL
  $: reviewId = $page.params.id

  // TanStack queries
  $: reviewQuery = browser ? useMatchReviewQuery(reviewId) : null
  const approveMutation = browser ? useApproveMatchMutation() : null
  const skipMutation = browser ? useSkipMatchMutation() : null
  const flagMutation = browser ? useFlagForLaterMutation() : null

  // Review data
  $: review = $reviewQuery?.data

  // Selected company for approval
  let selectedCompanyNumber: string | null = null

  // Flag notes
  let flagNotes = ''

  // Select a candidate company
  function selectCompany(company: CandidateCompany) {
    selectedCompanyNumber = company.company_number
  }

  // Approve the match
  function handleApprove() {
    if (!selectedCompanyNumber) {
      alert('Please select a company to approve')
      return
    }

    if (
      !confirm(
        `Are you sure you want to approve this match and update the offender with company number ${selectedCompanyNumber}?`,
      )
    ) {
      return
    }

    approveMutation?.mutate(
      { id: reviewId, company_number: selectedCompanyNumber },
      {
        onSuccess: () => {
          alert('Match approved successfully')
          goto('/admin/offenders/reviews')
        },
        onError: (error) => {
          alert(`Failed to approve match: ${error.message}`)
        },
      },
    )
  }

  // Skip the match
  function handleSkip() {
    if (!confirm('Are you sure you want to skip this match? This action cannot be undone.')) {
      return
    }

    skipMutation?.mutate(reviewId, {
      onSuccess: () => {
        alert('Match skipped successfully')
        goto('/admin/offenders/reviews')
      },
      onError: (error) => {
        alert(`Failed to skip match: ${error.message}`)
      },
    })
  }

  // Flag for later review
  function handleFlag() {
    flagMutation?.mutate(
      { id: reviewId, notes: flagNotes },
      {
        onSuccess: () => {
          alert('Review flagged for later')
          goto('/admin/offenders/reviews')
        },
        onError: (error) => {
          alert(`Failed to flag review: ${error.message}`)
        },
      },
    )
  }

  // Format date for display
  function formatDate(dateStr: string | null): string {
    if (!dateStr) return '—'
    const date = new Date(dateStr)
    return date.toLocaleDateString('en-GB', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  // Format confidence score as percentage
  function formatConfidence(score: number): string {
    return `${(score * 100).toFixed(0)}%`
  }

  // Get confidence badge color
  function getConfidenceBadgeClass(score: number): string {
    if (score >= 0.8) return 'bg-green-100 text-green-800 border-green-200'
    if (score >= 0.6) return 'bg-yellow-100 text-yellow-800 border-yellow-200'
    return 'bg-red-100 text-red-800 border-red-200'
  }
</script>

<div class="min-h-screen bg-gray-50">
  <!-- Header -->
  <div class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="py-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">Review Company Match</h1>
            <p class="mt-2 text-sm text-gray-700">
              Review and approve suggested company registration for this offender
            </p>
          </div>

          <a
            href="/admin/offenders/reviews"
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
            Back to Reviews
          </a>
        </div>
      </div>
    </div>
  </div>

  <!-- Main Content -->
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <!-- Loading State -->
    {#if !reviewQuery || $reviewQuery.isLoading}
      <div class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-sm text-gray-500">Loading review...</p>
      </div>
    {:else if $reviewQuery.isError}
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
              {$reviewQuery.error?.message || 'Failed to load review'}
            </p>
          </div>
        </div>
      </div>
    {:else if review}
      <div class="space-y-6">
        <!-- Offender Information -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">Offender Information</h3>
            <p class="mt-1 text-sm text-gray-500">Details of the offender to be matched</p>
          </div>
          <div class="px-4 py-5 sm:p-6">
            {#if review.offender}
              <dl class="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
                <div>
                  <dt class="text-sm font-medium text-gray-500">Name</dt>
                  <dd class="mt-1 text-sm text-gray-900">{review.offender.name}</dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Current Company Number</dt>
                  <dd class="mt-1 text-sm text-gray-900">
                    {review.offender.company_registration_number || '—'}
                  </dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Location</dt>
                  <dd class="mt-1 text-sm text-gray-900">
                    {[review.offender.town, review.offender.county, review.offender.postcode]
                      .filter((v) => v)
                      .join(', ') || '—'}
                  </dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Overall Confidence</dt>
                  <dd class="mt-1">
                    <span
                      class="px-3 py-1 inline-flex text-sm font-semibold rounded-full border {getConfidenceBadgeClass(
                        review.confidence_score,
                      )}"
                    >
                      {formatConfidence(review.confidence_score)}
                    </span>
                  </dd>
                </div>
              </dl>
            {/if}
          </div>
        </div>

        <!-- Candidate Companies -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 class="text-lg leading-6 font-medium text-gray-900">
              Candidate Companies ({review.candidate_companies.length})
            </h3>
            <p class="mt-1 text-sm text-gray-500">
              Select the best match from Companies House search results
            </p>
          </div>
          <div class="px-4 py-5 sm:p-6">
            {#if review.candidate_companies.length === 0}
              <p class="text-sm text-gray-500">No candidate companies found</p>
            {:else}
              <div class="space-y-4">
                {#each review.candidate_companies as company}
                  <div
                    class="border rounded-lg p-4 cursor-pointer transition-colors {selectedCompanyNumber ===
                    company.company_number
                      ? 'border-blue-500 bg-blue-50'
                      : 'border-gray-200 hover:border-gray-300 hover:bg-gray-50'}"
                    on:click={() => selectCompany(company)}
                    on:keypress={(e) => e.key === 'Enter' && selectCompany(company)}
                    role="button"
                    tabindex="0"
                  >
                    <div class="flex items-start justify-between">
                      <div class="flex-1">
                        <div class="flex items-center">
                          <input
                            type="radio"
                            name="selected_company"
                            value={company.company_number}
                            checked={selectedCompanyNumber === company.company_number}
                            on:change={() => selectCompany(company)}
                            class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300"
                          />
                          <h4 class="ml-3 text-base font-medium text-gray-900">
                            {company.company_name}
                          </h4>
                          <span
                            class="ml-3 px-2 py-1 text-xs font-semibold rounded-full border {getConfidenceBadgeClass(
                              company.similarity_score,
                            )}"
                          >
                            {formatConfidence(company.similarity_score)} match
                          </span>
                        </div>
                        <dl class="mt-3 ml-7 grid grid-cols-1 gap-x-4 gap-y-2 sm:grid-cols-3">
                          <div>
                            <dt class="text-xs font-medium text-gray-500">Company Number</dt>
                            <dd class="mt-1 text-sm text-gray-900 font-mono">
                              {company.company_number}
                            </dd>
                          </div>
                          <div>
                            <dt class="text-xs font-medium text-gray-500">Status</dt>
                            <dd class="mt-1 text-sm text-gray-900 capitalize">
                              {company.company_status}
                            </dd>
                          </div>
                          <div>
                            <dt class="text-xs font-medium text-gray-500">Type</dt>
                            <dd class="mt-1 text-sm text-gray-900 uppercase">
                              {company.company_type}
                            </dd>
                          </div>
                          <div class="sm:col-span-3">
                            <dt class="text-xs font-medium text-gray-500">Address</dt>
                            <dd class="mt-1 text-sm text-gray-900">{company.address}</dd>
                          </div>
                        </dl>
                      </div>
                    </div>
                  </div>
                {/each}
              </div>
            {/if}
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <div class="flex items-center justify-between">
              <div class="flex-1 space-y-4">
                <!-- Approve Section -->
                <div class="flex items-center space-x-4">
                  <button
                    on:click={handleApprove}
                    disabled={!selectedCompanyNumber ||
                      $approveMutation?.isPending ||
                      review.status !== 'pending'}
                    class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md shadow-sm text-white bg-green-600 hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M5 13l4 4L19 7"
                      />
                    </svg>
                    {$approveMutation?.isPending ? 'Approving...' : 'Approve Match'}
                  </button>
                  {#if !selectedCompanyNumber}
                    <p class="text-sm text-gray-500">Select a company to approve</p>
                  {/if}
                </div>

                <!-- Skip Section -->
                <div class="flex items-center space-x-4">
                  <button
                    on:click={handleSkip}
                    disabled={$skipMutation?.isPending || review.status !== 'pending'}
                    class="inline-flex items-center px-6 py-3 border border-gray-300 text-base font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M6 18L18 6M6 6l12 12"
                      />
                    </svg>
                    {$skipMutation?.isPending ? 'Skipping...' : 'Skip / Reject Match'}
                  </button>
                  <p class="text-sm text-gray-500">None of these companies are correct</p>
                </div>

                <!-- Flag for Later Section -->
                <div class="border-t pt-4">
                  <label for="flag-notes" class="block text-sm font-medium text-gray-700 mb-2">
                    Flag for Later Review (Optional)
                  </label>
                  <div class="flex items-start space-x-4">
                    <textarea
                      id="flag-notes"
                      bind:value={flagNotes}
                      rows="2"
                      class="flex-1 shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md"
                      placeholder="Add notes about why this needs later review..."
                      disabled={review.status !== 'pending'}
                    ></textarea>
                    <button
                      on:click={handleFlag}
                      disabled={$flagMutation?.isPending || review.status !== 'pending'}
                      class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M3 21v-4m0 0V5a2 2 0 012-2h6.5l1 1H21l-3 6 3 6h-8.5l-1-1H5a2 2 0 00-2 2zm9-13.5V9"
                        />
                      </svg>
                      {$flagMutation?.isPending ? 'Flagging...' : 'Flag for Later'}
                    </button>
                  </div>
                </div>
              </div>
            </div>

            {#if review.status !== 'pending'}
              <div class="mt-4 p-4 bg-gray-50 rounded-md">
                <p class="text-sm text-gray-700">
                  This review has already been processed with status: <strong
                    class="capitalize">{review.status}</strong
                  >
                  {#if review.reviewed_at}
                    on {formatDate(review.reviewed_at)}
                  {/if}
                  {#if review.reviewed_by}
                    by {review.reviewed_by.email}
                  {/if}
                </p>
              </div>
            {/if}
          </div>
        </div>
      </div>
    {/if}
  </div>
</div>
