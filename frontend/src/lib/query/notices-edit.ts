/**
 * TanStack Query functions for Notice Editing
 *
 * Queries and mutations for fetching and updating notice records
 */

import { createQuery, createMutation } from '@tanstack/svelte-query'
import { queryClient } from '$lib/query/client'

const API_BASE_URL = 'http://localhost:4002/api/notices'

/**
 * Notice detail for editing
 */
export interface NoticeDetail {
  id: string
  regulator_id: string
  regulator_ref_number: string | null
  notice_date: string | null
  operative_date: string | null
  compliance_date: string | null
  notice_body: string | null
  offence_action_type: string | null
  offence_action_date: string | null
  url: string | null
  offence_breaches: string[] | null
  environmental_impact: string | null
  environmental_receptor: string | null
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
 * Update notice input
 */
export interface UpdateNoticeInput {
  id: string
  regulator_id?: string
  regulator_ref_number?: string | null
  notice_date?: string | null
  operative_date?: string | null
  compliance_date?: string | null
  notice_body?: string | null
  offence_action_type?: string | null
  offence_action_date?: string | null
  url?: string | null
  environmental_impact?: string | null
  environmental_receptor?: string | null
}

/**
 * Query key factory
 */
export const noticesEditKeys = {
  all: ['notices-edit'] as const,
  detail: (id: string) => [...noticesEditKeys.all, id] as const,
}

/**
 * Fetch single notice for editing
 */
async function fetchNoticeForEdit(id: string): Promise<NoticeDetail> {
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
 * Query hook for fetching single notice for editing
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useNoticeQuery } from '$lib/query/notices-edit'
 *   const noticeQuery = useNoticeQuery(noticeId)
 * </script>
 *
 * {#if $noticeQuery.data}
 *   <h2>{$noticeQuery.data.regulator_id}</h2>
 * {/if}
 * ```
 */
export function useNoticeQuery(id: string) {
  return createQuery({
    queryKey: noticesEditKeys.detail(id),
    queryFn: () => fetchNoticeForEdit(id),
    staleTime: 1000 * 60 * 2, // 2 minutes
  })
}

/**
 * Update notice
 */
async function updateNotice(input: UpdateNoticeInput): Promise<NoticeDetail> {
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
 * Hook for updating a notice
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useUpdateNoticeMutation } from '$lib/query/notices-edit'
 *   const updateMutation = useUpdateNoticeMutation()
 *
 *   function handleSave(formData) {
 *     $updateMutation.mutate({ id: noticeId, ...formData })
 *   }
 * </script>
 * ```
 */
export function useUpdateNoticeMutation() {
  return createMutation({
    mutationFn: updateNotice,
    onSuccess: (data) => {
      // Update the detail query cache
      queryClient?.setQueryData(noticesEditKeys.detail(data.id), data)
      // Could also invalidate notices lists if needed
    },
  })
}
