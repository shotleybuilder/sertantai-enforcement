/**
 * TanStack Query functions for Agencies
 *
 * Queries that read from TanStack DB and provide reactive data to components
 * Mutations that write to API and update local state optimistically
 */

import { createQuery, createMutation } from '@tanstack/svelte-query'
import { agenciesStore, addAgency, updateAgency, removeAgency } from '$lib/stores/agencies'
import { queryClient } from '$lib/query/client'
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

/**
 * Mutation types
 */
export interface CreateAgencyInput {
  code: 'hse' | 'onr' | 'orr' | 'ea'
  name: string
  base_url?: string | null
  enabled?: boolean
}

interface CreateAgencyResponse {
  success: boolean
  data: Agency
}

/**
 * Create agency mutation
 *
 * Sends POST request to API and updates local state optimistically
 */
async function createAgencyMutation(input: CreateAgencyInput): Promise<Agency> {
  const response = await fetch('http://localhost:4002/api/agencies', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(input),
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || `HTTP ${response.status}: ${response.statusText}`)
  }

  const result: CreateAgencyResponse = await response.json()
  return result.data
}

/**
 * Hook for creating agencies with optimistic updates
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useCreateAgencyMutation } from '$lib/query/agencies'
 *   const createMutation = useCreateAgencyMutation()
 *
 *   function handleSubmit() {
 *     $createMutation.mutate({
 *       code: 'hse',
 *       name: 'Health and Safety Executive',
 *       base_url: 'https://www.hse.gov.uk',
 *       enabled: true
 *     })
 *   }
 * </script>
 *
 * {#if $createMutation.isPending}
 *   Creating...
 * {:else if $createMutation.isError}
 *   Error: {$createMutation.error.message}
 * {:else if $createMutation.isSuccess}
 *   Success!
 * {/if}
 * ```
 */
export function useCreateAgencyMutation() {
  return createMutation({
    mutationFn: createAgencyMutation,

    // Optimistic update: immediately add to UI before server responds
    onMutate: async (newAgency: CreateAgencyInput) => {
      // Cancel any outgoing refetches to avoid overwriting optimistic update
      await queryClient?.cancelQueries({ queryKey: agenciesKeys.all })

      // Snapshot the previous value for rollback
      const previousAgencies = get(agenciesStore)

      // Optimistically create a temporary agency with placeholder ID
      const optimisticAgency: Agency = {
        id: `temp-${Date.now()}`, // Temporary ID
        code: newAgency.code,
        name: newAgency.name,
        base_url: newAgency.base_url || null,
        enabled: newAgency.enabled ?? true,
        inserted_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }

      // Optimistically update the store
      addAgency(optimisticAgency)

      // Return context with rollback data
      return { previousAgencies, optimisticAgency }
    },

    // On success: replace optimistic agency with real one from server
    onSuccess: (serverAgency, _variables, context) => {
      if (!context) return

      // Remove the optimistic agency
      const currentAgencies = get(agenciesStore)
      const withoutOptimistic = currentAgencies.filter(
        a => a.id !== context.optimisticAgency.id
      )

      // The server agency will be synced automatically via ElectricSQL
      // But we can manually add it immediately for instant feedback
      addAgency(serverAgency)

      // Invalidate queries to refetch from TanStack DB (which will have the real data from ElectricSQL)
      queryClient?.invalidateQueries({ queryKey: agenciesKeys.all })
    },

    // On error: rollback to previous state
    onError: (_error, _variables, context) => {
      if (!context) return

      // Rollback optimistic update
      agenciesStore.set(context.previousAgencies)

      // Invalidate to refetch correct state
      queryClient?.invalidateQueries({ queryKey: agenciesKeys.all })
    },
  })
}

/**
 * Update agency input type
 */
export interface UpdateAgencyInput {
  id: string
  name?: string
  base_url?: string | null
  enabled?: boolean
}

interface UpdateAgencyResponse {
  success: boolean
  data: Agency
}

/**
 * Update agency mutation
 *
 * Sends PATCH request to API and updates local state optimistically
 */
async function updateAgencyMutation(input: UpdateAgencyInput): Promise<Agency> {
  const { id, ...updates } = input

  const response = await fetch(`http://localhost:4002/api/agencies/${id}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(updates),
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || `HTTP ${response.status}: ${response.statusText}`)
  }

  const result: UpdateAgencyResponse = await response.json()
  return result.data
}

/**
 * Hook for updating agencies with optimistic updates
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useUpdateAgencyMutation } from '$lib/query/agencies'
 *   const updateMutation = useUpdateAgencyMutation()
 *
 *   function handleUpdate() {
 *     $updateMutation.mutate({
 *       id: 'agency-uuid',
 *       name: 'Updated Name',
 *       enabled: false
 *     })
 *   }
 * </script>
 * ```
 */
export function useUpdateAgencyMutation() {
  return createMutation({
    mutationFn: updateAgencyMutation,

    // Optimistic update: immediately update in UI before server responds
    onMutate: async (updates: UpdateAgencyInput) => {
      // Cancel any outgoing refetches
      await queryClient?.cancelQueries({ queryKey: agenciesKeys.all })

      // Snapshot the previous value for rollback
      const previousAgencies = get(agenciesStore)

      // Optimistically update the agency
      const { id, ...fields } = updates
      updateAgency(id, fields)

      // Return context with rollback data
      return { previousAgencies }
    },

    // On success: ElectricSQL will sync the real update
    onSuccess: (serverAgency, _variables, _context) => {
      // Update with server response immediately
      updateAgency(serverAgency.id, serverAgency)

      // Invalidate queries to refetch
      queryClient?.invalidateQueries({ queryKey: agenciesKeys.all })
    },

    // On error: rollback to previous state
    onError: (_error, _variables, context) => {
      if (!context) return

      // Rollback optimistic update
      agenciesStore.set(context.previousAgencies)

      // Invalidate to refetch correct state
      queryClient?.invalidateQueries({ queryKey: agenciesKeys.all })
    },
  })
}

/**
 * Delete agency mutation
 *
 * Sends DELETE request to API and removes from local state optimistically
 */
async function deleteAgencyMutation(id: string): Promise<void> {
  const response = await fetch(`http://localhost:4002/api/agencies/${id}`, {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json',
    },
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || `HTTP ${response.status}: ${response.statusText}`)
  }

  // No data returned on successful delete
}

/**
 * Hook for deleting agencies with optimistic updates
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useDeleteAgencyMutation } from '$lib/query/agencies'
 *   const deleteMutation = useDeleteAgencyMutation()
 *
 *   function handleDelete(id: string) {
 *     if (confirm('Are you sure?')) {
 *       $deleteMutation.mutate(id)
 *     }
 *   }
 * </script>
 * ```
 */
export function useDeleteAgencyMutation() {
  return createMutation({
    mutationFn: deleteAgencyMutation,

    // Optimistic update: immediately remove from UI before server responds
    onMutate: async (id: string) => {
      // Cancel any outgoing refetches
      await queryClient?.cancelQueries({ queryKey: agenciesKeys.all })

      // Snapshot the previous value for rollback
      const previousAgencies = get(agenciesStore)

      // Optimistically remove the agency
      removeAgency(id)

      // Return context with rollback data
      return { previousAgencies }
    },

    // On success: ElectricSQL will sync the deletion
    onSuccess: (_data, _variables, _context) => {
      // Invalidate queries to refetch
      queryClient?.invalidateQueries({ queryKey: agenciesKeys.all })
    },

    // On error: rollback to previous state
    onError: (_error, _variables, context) => {
      if (!context) return

      // Rollback optimistic update
      agenciesStore.set(context.previousAgencies)

      // Invalidate to refetch correct state
      queryClient?.invalidateQueries({ queryKey: agenciesKeys.all })
    },
  })
}
