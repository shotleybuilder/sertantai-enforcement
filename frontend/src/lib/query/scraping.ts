/**
 * TanStack Query functions for Scraping
 *
 * Mutations for scraping API calls
 */

import { createMutation } from '@tanstack/svelte-query'
import type {
  StartScrapingRequest,
  StartScrapingResponse,
  ScrapingSession,
} from '$lib/types/scraping'

const API_BASE_URL = 'http://localhost:4002/api'

/**
 * Start a new scraping session
 */
async function startScrapingMutation(input: StartScrapingRequest): Promise<StartScrapingResponse> {
  const response = await fetch(`${API_BASE_URL}/scraping/start`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(input),
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || data.details || `HTTP ${response.status}: ${response.statusText}`)
  }

  return await response.json()
}

/**
 * Hook for starting scraping sessions
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useStartScrapingMutation } from '$lib/query/scraping'
 *   const startScraping = useStartScrapingMutation()
 *
 *   function handleStart() {
 *     $startScraping.mutate({
 *       agency: 'hse',
 *       database: 'notices',
 *       start_page: 1,
 *       max_pages: 10,
 *       country: 'All'
 *     })
 *   }
 * </script>
 * ```
 */
export function useStartScrapingMutation() {
  return createMutation({
    mutationFn: startScrapingMutation,
  })
}

/**
 * Stop an active scraping session
 */
async function stopScrapingMutation(sessionId: string): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/scraping/stop/${sessionId}`, {
    method: 'DELETE',
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || `HTTP ${response.status}: ${response.statusText}`)
  }
}

/**
 * Hook for stopping scraping sessions
 */
export function useStopScrapingMutation() {
  return createMutation({
    mutationFn: stopScrapingMutation,
  })
}

/**
 * Complete a scraping session (optimistic update from frontend)
 */
async function completeScrapingMutation(params: {
  sessionId: string
  recordsCreated: number
  recordsUpdated: number
}): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/scraping/sessions/${params.sessionId}/complete`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      records_created: params.recordsCreated,
      records_updated: params.recordsUpdated,
    }),
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || `HTTP ${response.status}: ${response.statusText}`)
  }
}

/**
 * Hook for completing scraping sessions
 */
export function useCompleteScrapingMutation() {
  return createMutation({
    mutationFn: completeScrapingMutation,
  })
}
