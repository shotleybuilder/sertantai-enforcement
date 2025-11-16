/**
 * TanStack Query functions for Agencies
 *
 * Queries that read from TanStack DB and provide reactive data to components
 */

import { createQuery } from '@tanstack/svelte-query'
import { agenciesStore } from '$lib/stores/agencies'
import { get } from 'svelte/store'
import type { Agency } from '$lib/db/schema'

/**
 * Query key factory for agencies
 */
export const agenciesKeys = {
  all: ['agencies'] as const,
  lists: () => [...agenciesKeys.all, 'list'] as const,
  list: (filters?: any) => [...agenciesKeys.lists(), filters] as const,
  details: () => [...agenciesKeys.all, 'detail'] as const,
  detail: (id: string) => [...agenciesKeys.details(), id] as const,
}

/**
 * Fetch all agencies from the store
 *
 * This reads from the Svelte store which is kept in sync by ElectricSQL
 */
async function fetchAllAgencies(): Promise<Agency[]> {
  // Get current value from store
  const agencies = get(agenciesStore)
  return agencies
}

/**
 * Query hook for all agencies
 *
 * Usage in Svelte components:
 * ```svelte
 * <script>
 *   import { useAgenciesQuery } from '$lib/query/agencies'
 *   const agenciesQuery = useAgenciesQuery()
 * </script>
 *
 * {#if $agenciesQuery.isLoading}
 *   Loading...
 * {:else if $agenciesQuery.isError}
 *   Error: {$agenciesQuery.error}
 * {:else}
 *   {#each $agenciesQuery.data as agency}
 *     ...
 *   {/each}
 * {/if}
 * ```
 */
export function useAgenciesQuery() {
  return createQuery({
    queryKey: agenciesKeys.list(),
    queryFn: fetchAllAgencies,
    // Since ElectricSQL handles real-time updates to the store,
    // we don't need aggressive refetching
    refetchOnMount: false,
    refetchOnReconnect: false,
    refetchOnWindowFocus: false,
  })
}

/**
 * Fetch a single agency by ID
 */
async function fetchAgencyById(id: string): Promise<Agency | undefined> {
  const agencies = get(agenciesStore)
  return agencies.find((a) => a.id === id)
}

/**
 * Query hook for a single agency
 */
export function useAgencyQuery(id: string) {
  return createQuery({
    queryKey: agenciesKeys.detail(id),
    queryFn: () => fetchAgencyById(id),
    enabled: !!id, // Only run if ID is provided
  })
}

/**
 * Fetch a single agency by code (:hse, :onr, :orr, :ea)
 */
async function fetchAgencyByCode(code: string): Promise<Agency | undefined> {
  const agencies = get(agenciesStore)
  return agencies.find((a) => a.code === code)
}

/**
 * Query hook for a single agency by code
 */
export function useAgencyByCodeQuery(code: string) {
  return createQuery({
    queryKey: [...agenciesKeys.details(), 'code', code] as const,
    queryFn: () => fetchAgencyByCode(code),
    enabled: !!code,
  })
}
