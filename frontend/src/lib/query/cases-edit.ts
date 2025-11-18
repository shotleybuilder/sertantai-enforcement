/**
 * TanStack Query functions for Case Editing
 *
 * Queries and mutations for fetching and updating case records
 */

import { createQuery, createMutation } from '@tanstack/svelte-query'
import { queryClient } from '$lib/query/client'

const API_BASE_URL = 'http://localhost:4002/api/cases'

/**
 * Case detail for editing
 */
export interface CaseDetail {
  id: string
  regulator_id: string
  offence_result: string | null
  offence_fine: number | null
  offence_costs: number | null
  offence_action_date: string | null
  offence_hearing_date: string | null
  offence_breaches: string[] | null
  offence_action_type: string | null
  regulator_function: string | null
  url: string | null
  related_cases: string[] | null
  agency_id: string | null
  offender_id: string | null
  agency: {
    id: string
    code: string
    name: string
  } | null
  offender: {
    id: string
    name: string
  } | null
  inserted_at: string
  updated_at: string
}

/**
 * Update case input
 */
export interface UpdateCaseInput {
  id: string
  regulator_id?: string
  offence_result?: string | null
  offence_fine?: number | null
  offence_costs?: number | null
  offence_action_date?: string | null
  offence_hearing_date?: string | null
  offence_action_type?: string | null
  regulator_function?: string | null
  url?: string | null
}

/**
 * Query key factory
 */
export const casesEditKeys = {
  all: ['cases-edit'] as const,
  detail: (id: string) => [...casesEditKeys.all, id] as const,
}

/**
 * Fetch single case for editing
 */
async function fetchCaseForEdit(id: string): Promise<CaseDetail> {
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
 * Query hook for fetching single case for editing
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useCaseQuery } from '$lib/query/cases-edit'
 *   const caseQuery = useCaseQuery(caseId)
 * </script>
 *
 * {#if $caseQuery.data}
 *   <h2>{$caseQuery.data.regulator_id}</h2>
 * {/if}
 * ```
 */
export function useCaseQuery(id: string) {
  return createQuery({
    queryKey: casesEditKeys.detail(id),
    queryFn: () => fetchCaseForEdit(id),
    staleTime: 1000 * 60 * 2, // 2 minutes
  })
}

/**
 * Update case
 */
async function updateCase(input: UpdateCaseInput): Promise<CaseDetail> {
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
 * Hook for updating a case
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useUpdateCaseMutation } from '$lib/query/cases-edit'
 *   const updateMutation = useUpdateCaseMutation()
 *
 *   function handleSave(formData) {
 *     $updateMutation.mutate({ id: caseId, ...formData })
 *   }
 * </script>
 * ```
 */
export function useUpdateCaseMutation() {
  return createMutation({
    mutationFn: updateCase,
    onSuccess: (data) => {
      // Update the detail query cache
      queryClient?.setQueryData(casesEditKeys.detail(data.id), data)
      // Could also invalidate cases lists if needed
    },
  })
}
