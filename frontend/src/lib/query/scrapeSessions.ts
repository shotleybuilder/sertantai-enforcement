/**
 * TanStack Query Hooks for Scrape Sessions
 *
 * Provides reactive queries for browsing scraping session history.
 * Data is synced from PostgreSQL via ElectricSQL to Svelte store.
 */

import { createQuery } from '@tanstack/svelte-query'
import { scrapeSessionsStore } from '$lib/stores/scrapeSessions'
import { get } from 'svelte/store'
import type { ScrapeSession } from '$lib/db/schema'
import { browser } from '$app/environment'

/**
 * Query keys for session history
 */
export const scrapeSessionsKeys = {
  all: ['scrapeSessions'] as const,
  list: (filters?: SessionFilters) => ['scrapeSessions', 'list', filters] as const,
  detail: (id: string) => ['scrapeSessions', 'detail', id] as const,
}

/**
 * Session filtering options
 */
export interface SessionFilters {
  status?: 'all' | 'active' | 'completed' | 'failed'
  database?: string
  agency?: 'hse' | 'environment_agency' | 'all'
  limit?: number
  offset?: number
}

/**
 * Query all scrape sessions with optional filtering
 *
 * Reads from local TanStack DB collection which is synced
 * in real-time from PostgreSQL via ElectricSQL.
 */
/**
 * Fetch sessions from Svelte store
 */
async function fetchScrapeSessions(filters?: SessionFilters): Promise<ScrapeSession[]> {
  if (!browser) {
    return []
  }

  // Read from Svelte store (populated by ElectricSQL sync)
  let sessions = get(scrapeSessionsStore)

  // Apply status filter
  if (filters?.status && filters.status !== 'all') {
    switch (filters.status) {
      case 'active':
        sessions = sessions.filter(
          (s) => s.status === 'pending' || s.status === 'running'
        )
        break
      case 'completed':
        sessions = sessions.filter((s) => s.status === 'completed')
        break
      case 'failed':
        sessions = sessions.filter(
          (s) => s.status === 'failed' || s.status === 'stopped'
        )
        break
    }
  }

  // Apply database filter
  if (filters?.database && filters.database !== 'all') {
    sessions = sessions.filter((s) => s.database === filters.database)
  }

  // Apply agency filter
  if (filters?.agency && filters.agency !== 'all') {
    sessions = sessions.filter((s) => s.agency === filters.agency)
  }

  // Sort by most recent first
  sessions.sort((a, b) => {
    return new Date(b.inserted_at).getTime() - new Date(a.inserted_at).getTime()
  })

  // Apply pagination
  if (filters?.offset !== undefined && filters?.limit !== undefined) {
    sessions = sessions.slice(filters.offset, filters.offset + filters.limit)
  } else if (filters?.limit !== undefined) {
    sessions = sessions.slice(0, filters.limit)
  }

  return sessions
}

export function useScrapeSessions(filters?: SessionFilters) {
  return createQuery({
    queryKey: scrapeSessionsKeys.list(filters),
    queryFn: () => fetchScrapeSessions(filters),
    enabled: browser,
    staleTime: 0,
    refetchInterval: 5000,
  })
}

/**
 * Query a single session by ID
 */
export function useScrapeSession(id: string) {
  return createQuery({
    queryKey: scrapeSessionsKeys.detail(id),
    queryFn: () => {
      if (!browser) {
        return null
      }

      const sessions = get(scrapeSessionsStore)
      const session = sessions.find((s) => s.id === id)
      return session || null
    },
    enabled: browser && !!id,
    staleTime: 0,
    refetchInterval: 2000, // Faster refetch for individual session details
  })
}

/**
 * Get session count for stats
 */
export function useSessionStats() {
  return createQuery({
    queryKey: [...scrapeSessionsKeys.all, 'stats'] as const,
    queryFn: () => {
      if (!browser) {
        return { total: 0, active: 0, completed: 0, failed: 0 }
      }

      const sessions = get(scrapeSessionsStore)

      return {
        total: sessions.length,
        active: sessions.filter((s) => s.status === 'pending' || s.status === 'running').length,
        completed: sessions.filter((s) => s.status === 'completed').length,
        failed: sessions.filter((s) => s.status === 'failed' || s.status === 'stopped').length,
      }
    },
    enabled: browser,
    staleTime: 5000,
    refetchInterval: 10000,
  })
}
