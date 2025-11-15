/**
 * TanStack DB Collections
 *
 * Creates reactive collections for each database table.
 * Collections provide:
 * - Local storage with IndexedDB persistence
 * - Reactive queries that auto-update
 * - Optimistic mutations
 */

import { createCollection, localStorageCollectionOptions } from '@tanstack/db'
import type { Case, Agency, Offender } from './schema'

/**
 * Cases Collection
 */
export const casesCollection = createCollection(
  localStorageCollectionOptions<Case, string>({
    storageKey: 'ehs-enforcement-cases',
    getKey: (item) => item.id,
  })
)

/**
 * Agencies Collection
 */
export const agenciesCollection = createCollection(
  localStorageCollectionOptions<Agency, string>({
    storageKey: 'ehs-enforcement-agencies',
    getKey: (item) => item.id,
  })
)

/**
 * Offenders Collection
 */
export const offendersCollection = createCollection(
  localStorageCollectionOptions<Offender, string>({
    storageKey: 'ehs-enforcement-offenders',
    getKey: (item) => item.id,
  })
)

/**
 * Database status tracking
 */
let isInitialized = false

/**
 * Initialize all collections
 *
 * Note: TanStack DB collections are initialized on creation,
 * but we track initialization state for the app
 */
export async function initDB(): Promise<void> {
  if (isInitialized) return

  try {
    // Collections are automatically initialized when created
    // We just need to mark as ready
    isInitialized = true
    console.log('[TanStack DB] Collections initialized successfully')
  } catch (error) {
    console.error('[TanStack DB] Failed to initialize collections:', error)
    throw error
  }
}

/**
 * Get database status
 */
export function getDBStatus() {
  return {
    initialized: isInitialized,
    collections: {
      cases: casesCollection.id,
      agencies: agenciesCollection.id,
      offenders: offendersCollection.id,
    },
    storage: 'localStorage (IndexedDB)',
  }
}

/**
 * Clear all collections (useful for testing/debugging)
 *
 * WARNING: This will delete all local data!
 */
export async function clearDB(): Promise<void> {
  try {
    // Clear each collection
    const caseKeys = Array.from(casesCollection.getAllKeys())
    const agencyKeys = Array.from(agenciesCollection.getAllKeys())
    const offenderKeys = Array.from(offendersCollection.getAllKeys())

    for (const key of caseKeys) {
      casesCollection.delete(key)
    }
    for (const key of agencyKeys) {
      agenciesCollection.delete(key)
    }
    for (const key of offenderKeys) {
      offendersCollection.delete(key)
    }

    console.log('[TanStack DB] Collections cleared')
  } catch (error) {
    console.error('[TanStack DB] Failed to clear collections:', error)
    throw error
  }
}

/**
 * Export collections as default for convenience
 */
export default {
  cases: casesCollection,
  agencies: agenciesCollection,
  offenders: offendersCollection,
  init: initDB,
  getStatus: getDBStatus,
  clear: clearDB,
}
