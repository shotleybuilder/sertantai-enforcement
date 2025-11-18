<script lang="ts">
  import { browser } from '$app/environment'
  import { useMatchReviewsQuery, type ReviewStatus } from '$lib/query/match-reviews'

  // Active status filter
  let activeStatus: ReviewStatus | 'all' = 'pending'

  // TanStack query
  $: reviewsQuery = browser
    ? useMatchReviewsQuery(activeStatus === 'all' ? undefined : activeStatus)
    : null

  // Reviews data
  $: reviews = $reviewsQuery?.data || []

  // Switch status filter
  function switchStatus(status: ReviewStatus | 'all') {
    activeStatus = status
  }

  // Refresh reviews
  function handleRefresh() {
    reviewsQuery?.refetch()
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
    if (score >= 0.8) return 'bg-green-100 text-green-800'
    if (score >= 0.6) return 'bg-yellow-100 text-yellow-800'
    return 'bg-red-100 text-red-800'
  }

  // Get status badge color
  function getStatusBadgeClass(status: ReviewStatus): string {
    switch (status) {
      case 'pending':
        return 'bg-blue-100 text-blue-800'
      case 'approved':
        return 'bg-green-100 text-green-800'
      case 'skipped':
        return 'bg-gray-100 text-gray-800'
      case 'needs_review':
        return 'bg-yellow-100 text-yellow-800'
      default:
        return 'bg-gray-100 text-gray-800'
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
            <h1 class="text-3xl font-bold text-gray-900">Offender Match Reviews</h1>
            <p class="mt-2 text-sm text-gray-700">
              Review and approve company matches from Companies House
            </p>
          </div>

          <div class="flex space-x-3">
            <a
              href="/admin"
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
              Back to Admin
            </a>

            <button
              on:click={handleRefresh}
              disabled={$reviewsQuery?.isFetching}
              class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50"
            >
              <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                />
              </svg>
              {$reviewsQuery?.isFetching ? 'Refreshing...' : 'Refresh'}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Main Content -->
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <!-- Status Filters -->
    <div class="border-b border-gray-200 mb-6">
      <nav class="-mb-px flex space-x-8">
        <button
          on:click={() => switchStatus('all')}
          class="py-4 px-1 border-b-2 font-medium text-sm {activeStatus === 'all'
            ? 'border-blue-500 text-blue-600'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
        >
          All Reviews
          {#if activeStatus === 'all' && reviews.length > 0}
            <span class="ml-2 py-0.5 px-2 rounded-full text-xs bg-blue-100 text-blue-800"
              >{reviews.length}</span
            >
          {/if}
        </button>

        <button
          on:click={() => switchStatus('pending')}
          class="py-4 px-1 border-b-2 font-medium text-sm {activeStatus === 'pending'
            ? 'border-blue-500 text-blue-600'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
        >
          Pending
          {#if activeStatus === 'pending' && reviews.length > 0}
            <span class="ml-2 py-0.5 px-2 rounded-full text-xs bg-blue-100 text-blue-800"
              >{reviews.length}</span
            >
          {/if}
        </button>

        <button
          on:click={() => switchStatus('needs_review')}
          class="py-4 px-1 border-b-2 font-medium text-sm {activeStatus === 'needs_review'
            ? 'border-blue-500 text-blue-600'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
        >
          Needs Review
          {#if activeStatus === 'needs_review' && reviews.length > 0}
            <span class="ml-2 py-0.5 px-2 rounded-full text-xs bg-yellow-100 text-yellow-800"
              >{reviews.length}</span
            >
          {/if}
        </button>

        <button
          on:click={() => switchStatus('approved')}
          class="py-4 px-1 border-b-2 font-medium text-sm {activeStatus === 'approved'
            ? 'border-blue-500 text-blue-600'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
        >
          Approved
          {#if activeStatus === 'approved' && reviews.length > 0}
            <span class="ml-2 py-0.5 px-2 rounded-full text-xs bg-green-100 text-green-800"
              >{reviews.length}</span
            >
          {/if}
        </button>

        <button
          on:click={() => switchStatus('skipped')}
          class="py-4 px-1 border-b-2 font-medium text-sm {activeStatus === 'skipped'
            ? 'border-blue-500 text-blue-600'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
        >
          Skipped
          {#if activeStatus === 'skipped' && reviews.length > 0}
            <span class="ml-2 py-0.5 px-2 rounded-full text-xs bg-gray-100 text-gray-800"
              >{reviews.length}</span
            >
          {/if}
        </button>
      </nav>
    </div>

    <!-- Loading State -->
    {#if !reviewsQuery || $reviewsQuery.isLoading}
      <div class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-sm text-gray-500">Loading reviews...</p>
      </div>
    {:else if $reviewsQuery.isError}
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
              {$reviewsQuery.error?.message || 'Failed to load reviews'}
            </p>
          </div>
        </div>
      </div>
    {:else if reviews.length === 0}
      <!-- Empty State -->
      <div class="text-center py-12 bg-white rounded-lg shadow">
        <svg
          class="mx-auto h-12 w-12 text-gray-400"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No Reviews Found</h3>
        <p class="mt-1 text-sm text-gray-500">
          {#if activeStatus === 'pending'}
            No pending reviews at the moment. All matches have been reviewed.
          {:else if activeStatus === 'all'}
            No match reviews exist yet.
          {:else}
            No {activeStatus} reviews found.
          {/if}
        </p>
      </div>
    {:else}
      <!-- Reviews Table -->
      <div class="bg-white shadow overflow-hidden sm:rounded-lg">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Offender
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Status
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Confidence
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Candidates
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Searched
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Reviewed
              </th>
              <th scope="col" class="relative px-6 py-3">
                <span class="sr-only">Actions</span>
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each reviews as review}
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4">
                  <div class="text-sm font-medium text-gray-900">
                    {review.offender_name || 'Unknown Offender'}
                  </div>
                  <div class="text-sm text-gray-500 font-mono">
                    ID: {review.offender_id.slice(0, 8)}...
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span
                    class="px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full {getStatusBadgeClass(
                      review.status,
                    )}"
                  >
                    {review.status}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span
                    class="px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full {getConfidenceBadgeClass(
                      review.confidence_score,
                    )}"
                  >
                    {formatConfidence(review.confidence_score)}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {review.candidate_count} {review.candidate_count === 1 ? 'company' : 'companies'}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {formatDate(review.searched_at)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {formatDate(review.reviewed_at)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <a
                    href="/admin/offenders/reviews/{review.id}"
                    class="text-blue-600 hover:text-blue-900"
                  >
                    Review
                  </a>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  </div>
</div>
