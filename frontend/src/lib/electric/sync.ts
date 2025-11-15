/**
 * ElectricSQL Sync Integration
 *
 * Connects ElectricSQL's HTTP Shape API with TanStack DB collections
 * to provide real-time sync from PostgreSQL to the client.
 */

import { ShapeStream } from '@electric-sql/client'
import { casesCollection, agenciesCollection, offendersCollection } from '$lib/db'
import type { Case, Agency, Offender } from '$lib/db/schema'

/**
 * Electric service configuration
 */
const ELECTRIC_URL = import.meta.env.PUBLIC_ELECTRIC_URL || 'http://localhost:3001'

/**
 * Sync status tracker
 */
export interface SyncStatus {
  connected: boolean
  syncing: boolean
  lastSyncTime: Date | null
  error: string | null
}

let syncStatus: SyncStatus = {
  connected: false,
  syncing: false,
  lastSyncTime: null,
  error: null,
}

/**
 * Active sync subscriptions
 */
const activeSubscriptions: Map<string, any> = new Map()

/**
 * Start syncing Cases collection
 *
 * This creates a shape stream for the cases table and
 * syncs all changes to the local TanStack DB collection.
 */
export function syncCases(organizationId?: string) {
  const key = 'cases'

  // If already syncing, return existing subscription
  if (activeSubscriptions.has(key)) {
    console.log('[Electric Sync] Cases already syncing')
    return activeSubscriptions.get(key)
  }

  try {
    syncStatus.syncing = true
    syncStatus.error = null

    // Create shape stream for cases table
    const stream = new ShapeStream<Case>({
      url: `${ELECTRIC_URL}/v1/shape`,
      params: {
        table: 'cases',
        // Filter by organization when multi-tenancy is enabled
        ...(organizationId && { where: `organization_id='${organizationId}'` }),
      },
    })

    // Subscribe to shape changes
    const subscription = stream.subscribe((messages) => {
      console.log(`[Electric Sync] Received ${messages.length} case updates`)

      messages.forEach((msg) => {
        try {
          switch (msg.action) {
            case 'insert':
              // Insert new case into TanStack DB collection
              casesCollection.insert(msg.value as Case)
              break

            case 'update':
              // Update existing case in TanStack DB collection
              casesCollection.update(msg.value.id, (draft) => {
                Object.assign(draft, msg.value)
              })
              break

            case 'delete':
              // Delete case from TanStack DB collection
              casesCollection.delete(msg.value.id)
              break
          }
        } catch (error) {
          console.error('[Electric Sync] Error processing case message:', error, msg)
        }
      })

      // Update sync status
      syncStatus.connected = true
      syncStatus.lastSyncTime = new Date()
    })

    // Handle errors
    stream.on('error', (error) => {
      console.error('[Electric Sync] Cases stream error:', error)
      syncStatus.error = error.message
      syncStatus.connected = false
    })

    // Store subscription
    activeSubscriptions.set(key, subscription)

    console.log('[Electric Sync] Started syncing cases')
    return subscription
  } catch (error) {
    console.error('[Electric Sync] Failed to start cases sync:', error)
    syncStatus.syncing = false
    syncStatus.error = error instanceof Error ? error.message : 'Unknown error'
    throw error
  }
}

/**
 * Start syncing Agencies collection
 */
export function syncAgencies() {
  const key = 'agencies'

  if (activeSubscriptions.has(key)) {
    return activeSubscriptions.get(key)
  }

  try {
    const stream = new ShapeStream<Agency>({
      url: `${ELECTRIC_URL}/v1/shape`,
      params: {
        table: 'agencies',
      },
    })

    const subscription = stream.subscribe((messages) => {
      messages.forEach((msg) => {
        try {
          switch (msg.action) {
            case 'insert':
              agenciesCollection.insert(msg.value as Agency)
              break
            case 'update':
              agenciesCollection.update(msg.value.id, (draft) => {
                Object.assign(draft, msg.value)
              })
              break
            case 'delete':
              agenciesCollection.delete(msg.value.id)
              break
          }
        } catch (error) {
          console.error('[Electric Sync] Error processing agency message:', error)
        }
      })
    })

    stream.on('error', (error) => {
      console.error('[Electric Sync] Agencies stream error:', error)
    })

    activeSubscriptions.set(key, subscription)
    console.log('[Electric Sync] Started syncing agencies')
    return subscription
  } catch (error) {
    console.error('[Electric Sync] Failed to start agencies sync:', error)
    throw error
  }
}

/**
 * Start syncing Offenders collection
 */
export function syncOffenders() {
  const key = 'offenders'

  if (activeSubscriptions.has(key)) {
    return activeSubscriptions.get(key)
  }

  try {
    const stream = new ShapeStream<Offender>({
      url: `${ELECTRIC_URL}/v1/shape`,
      params: {
        table: 'offenders',
      },
    })

    const subscription = stream.subscribe((messages) => {
      messages.forEach((msg) => {
        try {
          switch (msg.action) {
            case 'insert':
              offendersCollection.insert(msg.value as Offender)
              break
            case 'update':
              offendersCollection.update(msg.value.id, (draft) => {
                Object.assign(draft, msg.value)
              })
              break
            case 'delete':
              offendersCollection.delete(msg.value.id)
              break
          }
        } catch (error) {
          console.error('[Electric Sync] Error processing offender message:', error)
        }
      })
    })

    stream.on('error', (error) => {
      console.error('[Electric Sync] Offenders stream error:', error)
    })

    activeSubscriptions.set(key, subscription)
    console.log('[Electric Sync] Started syncing offenders')
    return subscription
  } catch (error) {
    console.error('[Electric Sync] Failed to start offenders sync:', error)
    throw error
  }
}

/**
 * Start syncing all collections
 *
 * Call this when the app initializes to start syncing
 * all data from PostgreSQL to the local database.
 */
export function startSync(organizationId?: string) {
  console.log('[Electric Sync] Starting full sync...')

  try {
    syncCases(organizationId)
    syncAgencies()
    syncOffenders()

    console.log('[Electric Sync] All syncs started successfully')
  } catch (error) {
    console.error('[Electric Sync] Failed to start sync:', error)
    throw error
  }
}

/**
 * Stop syncing a specific collection
 */
export function stopSync(table: string) {
  const subscription = activeSubscriptions.get(table)

  if (subscription && typeof subscription.unsubscribe === 'function') {
    subscription.unsubscribe()
    activeSubscriptions.delete(table)
    console.log(`[Electric Sync] Stopped syncing ${table}`)
  }
}

/**
 * Stop all syncs
 */
export function stopAllSyncs() {
  console.log('[Electric Sync] Stopping all syncs...')

  activeSubscriptions.forEach((subscription, key) => {
    if (subscription && typeof subscription.unsubscribe === 'function') {
      subscription.unsubscribe()
      console.log(`[Electric Sync] Stopped ${key}`)
    }
  })

  activeSubscriptions.clear()
  syncStatus.connected = false
  syncStatus.syncing = false
}

/**
 * Get current sync status
 */
export function getSyncStatus(): SyncStatus {
  return { ...syncStatus }
}

/**
 * Check if Electric service is available
 */
export async function checkElectricHealth(): Promise<boolean> {
  try {
    const response = await fetch(`${ELECTRIC_URL}/v1/shape?table=cases&offset=-1`)
    return response.ok
  } catch (error) {
    console.error('[Electric Sync] Health check failed:', error)
    return false
  }
}
