/**
 * TanStack Query functions for Duplicate Management
 *
 * Queries and mutations for detecting and removing duplicate records
 */

import { createQuery, createMutation } from '@tanstack/svelte-query'
import { queryClient } from '$lib/query/client'

const API_BASE_URL = 'http://localhost:4002/api/duplicates'

/**
 * Record types that can have duplicates
 */
export type DuplicateType = 'cases' | 'notices' | 'offenders'

/**
 * Case duplicate record
 */
export interface CaseDuplicate {
  id: string
  regulator_id: string
  case_result: string | null
  offence_date: string | null
  sentence_date: string | null
  prosecution_end_date: string | null
  fine_amount: number | null
  offender_id: string | null
  offender_name: string | null
  agency_id: string | null
  agency_code: string | null
  inserted_at: string
  updated_at: string
}

/**
 * Notice duplicate record
 */
export interface NoticeDuplicate {
  id: string
  regulator_id: string
  regulator_ref_number: string | null
  notice_type: string | null
  issued_date: string | null
  offender_id: string | null
  offender_name: string | null
  agency_id: string | null
  agency_code: string | null
  inserted_at: string
  updated_at: string
}

/**
 * Offender duplicate record
 */
export interface OffenderDuplicate {
  id: string
  name: string
  company_number: string | null
  inserted_at: string
  updated_at: string
}

/**
 * Union type for all duplicate records
 */
export type DuplicateRecord = CaseDuplicate | NoticeDuplicate | OffenderDuplicate

/**
 * Response structure from API
 */
export interface DuplicatesResponse {
  success: boolean
  type: DuplicateType
  data: DuplicateRecord[][]  // Array of duplicate groups
}

/**
 * Query key factory
 */
export const duplicatesKeys = {
  all: ['duplicates'] as const,
  byType: (type: DuplicateType) => [...duplicatesKeys.all, type] as const,
}

/**
 * Fetch duplicates for a specific type
 */
async function fetchDuplicates(type: DuplicateType): Promise<DuplicateRecord[][]> {
  const response = await fetch(`${API_BASE_URL}?type=${type}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    },
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || data.details || `HTTP ${response.status}: ${response.statusText}`)
  }

  const result: DuplicatesResponse = await response.json()
  return result.data
}

/**
 * Query hook for fetching duplicates
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useDuplicatesQuery } from '$lib/query/duplicates'
 *   const duplicatesQuery = useDuplicatesQuery('cases')
 * </script>
 *
 * {#if $duplicatesQuery.isLoading}
 *   Loading...
 * {:else if $duplicatesQuery.data}
 *   {$duplicatesQuery.data.length} duplicate groups found
 * {/if}
 * ```
 */
export function useDuplicatesQuery(type: DuplicateType) {
  return createQuery({
    queryKey: duplicatesKeys.byType(type),
    queryFn: () => fetchDuplicates(type),
    staleTime: 1000 * 60 * 5, // 5 minutes
    // Don't refetch automatically - user should manually refresh
    refetchOnMount: false,
    refetchOnReconnect: false,
    refetchOnWindowFocus: false,
  })
}

/**
 * Delete selected duplicates input
 */
export interface DeleteDuplicatesInput {
  type: DuplicateType
  ids: string[]
}

/**
 * Delete selected duplicates response
 */
export interface DeleteDuplicatesResponse {
  success: boolean
  deleted: number
  failed: number
  message: string
}

/**
 * Delete selected duplicate records
 */
async function deleteDuplicates(input: DeleteDuplicatesInput): Promise<DeleteDuplicatesResponse> {
  const response = await fetch(API_BASE_URL, {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      type: input.type,
      ids: input.ids,
    }),
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || data.details || `HTTP ${response.status}: ${response.statusText}`)
  }

  const result: DeleteDuplicatesResponse = await response.json()
  return result
}

/**
 * Hook for deleting duplicate records
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useDeleteDuplicatesMutation } from '$lib/query/duplicates'
 *   const deleteMutation = useDeleteDuplicatesMutation()
 *
 *   function handleDelete() {
 *     $deleteMutation.mutate({
 *       type: 'cases',
 *       ids: ['id1', 'id2']
 *     })
 *   }
 * </script>
 * ```
 */
export function useDeleteDuplicatesMutation() {
  return createMutation({
    mutationFn: deleteDuplicates,
    onSuccess: (data, variables) => {
      // Invalidate the duplicates query for this type to force a refresh
      queryClient?.invalidateQueries({ queryKey: duplicatesKeys.byType(variables.type) })
    },
  })
}
