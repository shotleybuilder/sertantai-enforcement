/**
 * TanStack Query functions for Cases
 *
 * Queries that read from TanStack DB and provide reactive data to components
 */

import { createQuery } from '@tanstack/svelte-query'
import { casesStore } from '$lib/stores/cases'
import { get } from 'svelte/store'
import type { Case } from '$lib/db/schema'

/**
 * Query key factory for cases
 */
export const casesKeys = {
  all: ['cases'] as const,
  lists: () => [...casesKeys.all, 'list'] as const,
  list: (filters?: any) => [...casesKeys.lists(), filters] as const,
  details: () => [...casesKeys.all, 'detail'] as const,
  detail: (id: string) => [...casesKeys.details(), id] as const,
}

/**
 * Fetch all cases from the store
 *
 * This reads from the Svelte store which is kept in sync by ElectricSQL
 */
async function fetchAllCases(): Promise<Case[]> {
  // Get current value from store
  const cases = get(casesStore)
  return cases
}

/**
 * Query hook for all cases
 *
 * Usage in Svelte components:
 * ```svelte
 * <script>
 *   import { useCasesQuery } from '$lib/query/cases'
 *   const casesQuery = useCasesQuery()
 * </script>
 *
 * {#if $casesQuery.isLoading}
 *   Loading...
 * {:else if $casesQuery.isError}
 *   Error: {$casesQuery.error}
 * {:else}
 *   {#each $casesQuery.data as case_}
 *     ...
 *   {/each}
 * {/if}
 * ```
 */
export function useCasesQuery() {
  return createQuery({
    queryKey: casesKeys.list(),
    queryFn: fetchAllCases,
    // Since ElectricSQL handles real-time updates to the store,
    // we don't need aggressive refetching
    refetchOnMount: false,
    refetchOnReconnect: false,
    refetchOnWindowFocus: false,
  })
}

/**
 * Fetch a single case by ID
 */
async function fetchCaseById(id: string): Promise<Case | undefined> {
  const cases = get(casesStore)
  return cases.find((c) => c.id === id)
}

/**
 * Query hook for a single case
 */
export function useCaseQuery(id: string) {
  return createQuery({
    queryKey: casesKeys.detail(id),
    queryFn: () => fetchCaseById(id),
    enabled: !!id, // Only run if ID is provided
  })
}
