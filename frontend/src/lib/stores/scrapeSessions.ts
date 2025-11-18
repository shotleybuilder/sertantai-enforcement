/**
 * Svelte store for scrape sessions data
 * Updated by ElectricSQL sync
 */

import { writable } from 'svelte/store'
import type { ScrapeSession } from '$lib/db/schema'

// Create a writable store for scrape sessions
export const scrapeSessionsStore = writable<ScrapeSession[]>([])

// Helper functions to update the store
export function addScrapeSession(session: ScrapeSession) {
  scrapeSessionsStore.update((sessions) => {
    // Check if session already exists
    const existing = sessions.findIndex((s) => s.id === session.id)
    if (existing >= 0) {
      // Update existing
      sessions[existing] = session
      return [...sessions]
    } else {
      // Add new
      return [...sessions, session]
    }
  })
}

export function updateScrapeSession(id: string, updates: Partial<ScrapeSession>) {
  scrapeSessionsStore.update((sessions) => {
    const index = sessions.findIndex((s) => s.id === id)
    if (index >= 0) {
      sessions[index] = { ...sessions[index], ...updates }
      return [...sessions]
    }
    return sessions
  })
}

export function removeScrapeSession(id: string) {
  scrapeSessionsStore.update((sessions) => sessions.filter((s) => s.id !== id))
}

export function clearScrapeSessions() {
  scrapeSessionsStore.set([])
}
