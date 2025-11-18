<script lang="ts">
  import type { RecordProcessedEvent } from '$lib/types/scraping'

  export let records: RecordProcessedEvent[] = []

  // Sorting state
  type SortColumn = 'regulator_id' | 'offender_name' | 'notice_type' | 'index'
  type SortDirection = 'asc' | 'desc'
  let sortColumn: SortColumn = 'index'
  let sortDirection: SortDirection = 'desc'

  // Filter state
  let searchTerm = ''

  // Sort records
  $: sortedRecords = [...records].sort((a, b) => {
    let compareA: any
    let compareB: any

    switch (sortColumn) {
      case 'regulator_id':
        compareA = a.regulator_id || ''
        compareB = b.regulator_id || ''
        break
      case 'offender_name':
        compareA = (a.offender_name || '').toLowerCase()
        compareB = (b.offender_name || '').toLowerCase()
        break
      case 'notice_type':
        compareA = (a.notice_type || '').toLowerCase()
        compareB = (b.notice_type || '').toLowerCase()
        break
      case 'index':
        // Use array index (order processed)
        return sortDirection === 'asc'
          ? records.indexOf(a) - records.indexOf(b)
          : records.indexOf(b) - records.indexOf(a)
    }

    if (compareA < compareB) return sortDirection === 'asc' ? -1 : 1
    if (compareA > compareB) return sortDirection === 'asc' ? 1 : -1
    return 0
  })

  // Filter records
  $: filteredRecords = sortedRecords.filter((record) => {
    if (!searchTerm) return true
    const search = searchTerm.toLowerCase()
    return (
      record.regulator_id?.toLowerCase().includes(search) ||
      record.offender_name?.toLowerCase().includes(search) ||
      record.notice_type?.toLowerCase().includes(search)
    )
  })

  // Toggle sort
  function toggleSort(column: SortColumn) {
    if (sortColumn === column) {
      sortDirection = sortDirection === 'asc' ? 'desc' : 'asc'
    } else {
      sortColumn = column
      sortDirection = 'asc'
    }
  }

  // Export to CSV
  function exportToCSV() {
    const headers = ['#', 'Regulator ID', 'Offender Name', 'Notice Type']
    const csvContent = [
      headers.join(','),
      ...filteredRecords.map((record, index) =>
        [
          index + 1,
          `"${record.regulator_id || ''}"`,
          `"${record.offender_name || 'Unknown'}"`,
          `"${record.notice_type || ''}"`,
        ].join(',')
      ),
    ].join('\n')

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
    const link = document.createElement('a')
    const url = URL.createObjectURL(blob)
    link.setAttribute('href', url)
    link.setAttribute('download', `scraping-results-${new Date().toISOString()}.csv`)
    link.style.visibility = 'hidden'
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
  }
</script>

<div class="bg-white shadow rounded-lg overflow-hidden">
  <!-- Header -->
  <div class="px-6 py-4 border-b border-gray-200">
    <div class="flex items-center justify-between">
      <div>
        <h3 class="text-lg font-semibold text-gray-900">
          All Processed Records ({filteredRecords.length})
        </h3>
        <p class="text-sm text-gray-500 mt-1">
          Complete list of all records processed in this session
        </p>
      </div>

      <div class="flex items-center space-x-3">
        <!-- Search -->
        <input
          type="text"
          placeholder="Search..."
          bind:value={searchTerm}
          class="px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-blue-500 focus:border-blue-500"
        />

        <!-- Export Button -->
        <button
          on:click={exportToCSV}
          disabled={filteredRecords.length === 0}
          class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
            />
          </svg>
          Export CSV
        </button>
      </div>
    </div>
  </div>

  <!-- Table -->
  <div class="overflow-x-auto">
    {#if filteredRecords.length === 0}
      <div class="text-center py-12 text-gray-500 text-sm">
        <svg
          class="mx-auto h-12 w-12 text-gray-400 mb-2"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
          />
        </svg>
        {searchTerm ? 'No records match your search' : 'No records processed yet'}
      </div>
    {:else}
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th
              scope="col"
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              on:click={() => toggleSort('index')}
            >
              <div class="flex items-center space-x-1">
                <span>#</span>
                {#if sortColumn === 'index'}
                  <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    {#if sortDirection === 'asc'}
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M5 15l7-7 7 7"
                      />
                    {:else}
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M19 9l-7 7-7-7"
                      />
                    {/if}
                  </svg>
                {/if}
              </div>
            </th>

            <th
              scope="col"
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              on:click={() => toggleSort('regulator_id')}
            >
              <div class="flex items-center space-x-1">
                <span>Regulator ID</span>
                {#if sortColumn === 'regulator_id'}
                  <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    {#if sortDirection === 'asc'}
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M5 15l7-7 7 7"
                      />
                    {:else}
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M19 9l-7 7-7-7"
                      />
                    {/if}
                  </svg>
                {/if}
              </div>
            </th>

            <th
              scope="col"
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              on:click={() => toggleSort('offender_name')}
            >
              <div class="flex items-center space-x-1">
                <span>Offender Name</span>
                {#if sortColumn === 'offender_name'}
                  <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    {#if sortDirection === 'asc'}
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M5 15l7-7 7 7"
                      />
                    {:else}
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M19 9l-7 7-7-7"
                      />
                    {/if}
                  </svg>
                {/if}
              </div>
            </th>

            <th
              scope="col"
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              on:click={() => toggleSort('notice_type')}
            >
              <div class="flex items-center space-x-1">
                <span>Notice Type</span>
                {#if sortColumn === 'notice_type'}
                  <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    {#if sortDirection === 'asc'}
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M5 15l7-7 7 7"
                      />
                    {:else}
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M19 9l-7 7-7-7"
                      />
                    {/if}
                  </svg>
                {/if}
              </div>
            </th>
          </tr>
        </thead>

        <tbody class="bg-white divide-y divide-gray-200">
          {#each filteredRecords as record, index (record.regulator_id + index)}
            <tr class="hover:bg-gray-50">
              <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                {index + 1}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-600">
                {record.regulator_id}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                {record.offender_name || 'Unknown Offender'}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-600">
                {record.notice_type || 'N/A'}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>

  <!-- Footer -->
  {#if filteredRecords.length > 0}
    <div class="px-6 py-3 bg-gray-50 border-t border-gray-200">
      <p class="text-sm text-gray-700">
        Showing <span class="font-medium">{filteredRecords.length}</span> of
        <span class="font-medium">{records.length}</span> records
      </p>
    </div>
  {/if}
</div>
