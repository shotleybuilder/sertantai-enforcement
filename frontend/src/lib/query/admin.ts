/**
 * TanStack Query functions for Admin Dashboard
 *
 * Provides hooks for fetching admin statistics and dashboard data
 */

import { createQuery } from '@tanstack/svelte-query'

const API_BASE_URL = 'http://localhost:4002/api'

export interface AdminStats {
  recent_cases: number
  recent_notices: number
  total_cases: number
  total_notices: number
  total_fines: string
  active_agencies: number
  agency_stats: Array<{
    agency_name: string
    case_count: number
    notice_count: number
  }>
  period: string
  timeframe: string
  sync_errors: number
  data_quality_score: number
}

export interface Agency {
  id: string
  code: string
  name: string
  base_url: string | null
  enabled: boolean
  inserted_at: string
  updated_at: string
}

export interface AdminDashboardData {
  stats: AdminStats
  agencies: Agency[]
}

export interface AdminStatsResponse {
  success: boolean
  data: AdminDashboardData
}

/**
 * Fetch admin dashboard statistics
 */
async function fetchAdminStats(period: 'week' | 'month' | 'year' = 'month'): Promise<AdminDashboardData> {
  const response = await fetch(`${API_BASE_URL}/admin/stats?period=${period}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    },
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || data.details || `HTTP ${response.status}: ${response.statusText}`)
  }

  const result: AdminStatsResponse = await response.json()
  return result.data
}

/**
 * Hook for fetching admin dashboard statistics
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useAdminStats } from '$lib/query/admin'
 *   const adminStats = useAdminStats('month')
 *
 *   $: if ($adminStats.isSuccess) {
 *     console.log('Stats:', $adminStats.data.stats)
 *     console.log('Agencies:', $adminStats.data.agencies)
 *   }
 * </script>
 *
 * {#if $adminStats.isPending}
 *   <p>Loading...</p>
 * {:else if $adminStats.isError}
 *   <p>Error: {$adminStats.error.message}</p>
 * {:else if $adminStats.isSuccess}
 *   <p>Total Cases: {$adminStats.data.stats.total_cases}</p>
 * {/if}
 * ```
 */
export function useAdminStats(period: 'week' | 'month' | 'year' = 'month') {
  return createQuery({
    queryKey: ['admin', 'stats', period],
    queryFn: () => fetchAdminStats(period),
    staleTime: 1000 * 60 * 5, // 5 minutes
    refetchOnWindowFocus: true,
  })
}
