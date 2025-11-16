/**
 * Svelte store for agencies data
 * Updated by ElectricSQL sync
 */

import { writable } from 'svelte/store'
import type { Agency } from '$lib/db/schema'

// Create a writable store for agencies
export const agenciesStore = writable<Agency[]>([])

// Helper functions to update the store
export function addAgency(agency: Agency) {
  agenciesStore.update((agencies) => {
    // Check if agency already exists
    const existing = agencies.findIndex((a) => a.id === agency.id)
    if (existing >= 0) {
      // Update existing
      agencies[existing] = agency
      return [...agencies]
    } else {
      // Add new
      return [...agencies, agency]
    }
  })
}

export function updateAgency(id: string, updates: Partial<Agency>) {
  agenciesStore.update((agencies) => {
    const index = agencies.findIndex((a) => a.id === id)
    if (index >= 0) {
      agencies[index] = { ...agencies[index], ...updates }
      return [...agencies]
    }
    return agencies
  })
}

export function removeAgency(id: string) {
  agenciesStore.update((agencies) => agencies.filter((a) => a.id !== id))
}

export function clearAgencies() {
  agenciesStore.set([])
}
