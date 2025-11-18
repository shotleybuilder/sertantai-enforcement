/**
 * TanStack Query functions for Offender Editing
 *
 * Queries and mutations for fetching and updating offender records
 */

import { createQuery, createMutation } from '@tanstack/svelte-query'
import { queryClient } from '$lib/query/client'

const API_BASE_URL = 'http://localhost:4002/api/offenders'

/**
 * Offender detail for editing
 */
export interface OffenderDetail {
  id: string
  name: string
  address: string | null
  local_authority: string | null
  country: string | null
  postcode: string | null
  town: string | null
  county: string | null
  main_activity: string | null
  sic_code: string | null
  business_type: string | null
  industry: string | null
  agencies: string[]
  industry_sectors: string[]
  company_registration_number: string | null
  total_cases: number
  total_notices: number
  total_fines: number
  first_seen_date: string | null
  last_seen_date: string | null
  inserted_at: string
  updated_at: string
}

/**
 * Update offender input
 */
export interface UpdateOffenderInput {
  id: string
  name?: string
  address?: string | null
  local_authority?: string | null
  country?: string | null
  main_activity?: string | null
  sic_code?: string | null
  business_type?: string | null
  industry?: string | null
  agencies?: string[]
}

/**
 * Query key factory
 */
export const offendersEditKeys = {
  all: ['offenders-edit'] as const,
  detail: (id: string) => [...offendersEditKeys.all, id] as const,
}

/**
 * Fetch single offender for editing
 */
async function fetchOffenderForEdit(id: string): Promise<OffenderDetail> {
  const response = await fetch(`${API_BASE_URL}/${id}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    },
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || data.details || `HTTP ${response.status}: ${response.statusText}`)
  }

  const result = await response.json()
  return result.data
}

/**
 * Query hook for fetching single offender for editing
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useOffenderQuery } from '$lib/query/offenders-edit'
 *   const offenderQuery = useOffenderQuery(offenderId)
 * </script>
 *
 * {#if $offenderQuery.data}
 *   <h2>{$offenderQuery.data.name}</h2>
 * {/if}
 * ```
 */
export function useOffenderQuery(id: string) {
  return createQuery({
    queryKey: offendersEditKeys.detail(id),
    queryFn: () => fetchOffenderForEdit(id),
    staleTime: 1000 * 60 * 2, // 2 minutes
  })
}

/**
 * Update offender
 */
async function updateOffender(input: UpdateOffenderInput): Promise<OffenderDetail> {
  const { id, ...updateData } = input

  const response = await fetch(`${API_BASE_URL}/${id}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(updateData),
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || data.details || `HTTP ${response.status}: ${response.statusText}`)
  }

  const result = await response.json()
  return result.data
}

/**
 * Hook for updating an offender
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useUpdateOffenderMutation } from '$lib/query/offenders-edit'
 *   const updateMutation = useUpdateOffenderMutation()
 *
 *   function handleSave(formData) {
 *     $updateMutation.mutate({ id: offenderId, ...formData })
 *   }
 * </script>
 * ```
 */
export function useUpdateOffenderMutation() {
  return createMutation({
    mutationFn: updateOffender,
    onSuccess: (data) => {
      // Update the detail query cache
      queryClient?.setQueryData(offendersEditKeys.detail(data.id), data)
      // Could also invalidate offenders lists if needed
    },
  })
}
