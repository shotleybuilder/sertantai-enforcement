/**
 * ElectricSQL Sync Integration
 *
 * Connects ElectricSQL's HTTP Shape API with TanStack DB collections
 * to provide real-time sync from PostgreSQL to the client.
 */

import { ShapeStream } from '@electric-sql/client'
import {
  getCasesCollection,
  getAgenciesCollection,
  getOffendersCollection,
  getScrapeSessionsCollection,
} from '$lib/db/index.client'
import type { Case, Agency, Offender, ScrapeSession } from '$lib/db/schema'
import { addCase, updateCase, removeCase } from '$lib/stores/cases'
import { addAgency, updateAgency, removeAgency } from '$lib/stores/agencies'
import { addScrapeSession, updateScrapeSession, removeScrapeSession } from '$lib/stores/scrapeSessions'
import { queryClient } from '$lib/query/client'
import { casesKeys } from '$lib/query/cases'
import { agenciesKeys } from '$lib/query/agencies'
import { scrapeSessionsKeys } from '$lib/query/scrapeSessions'

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
export async function syncCases(organizationId?: string) {
  const key = 'cases'

  // If already syncing, return existing subscription
  if (activeSubscriptions.has(key)) {
    console.log('[Electric Sync] Cases already syncing')
    return activeSubscriptions.get(key)
  }

  try {
    syncStatus.syncing = true
    syncStatus.error = null

    // Get the cases collection (browser only)
    const casesCollection = await getCasesCollection()

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

      messages.forEach((msg: any) => {
        // Skip control messages
        if (msg.headers?.control) {
          return
        }

        // Handle data messages
        const operation = msg.headers?.operation
        const data = msg.value

        if (!operation || !data) {
          return
        }

        try {
          switch (operation) {
            case 'insert':
              // Insert new case into TanStack DB collection
              casesCollection.insert(data as Case)
              // Update Svelte store for immediate reactivity
              addCase(data as Case)
              break

            case 'update':
              // Update existing case in TanStack DB collection
              casesCollection.update(data.id, (draft) => {
                Object.assign(draft, data)
              })
              // Update Svelte store
              updateCase(data.id, data)
              break

            case 'delete':
              // Delete case from TanStack DB collection
              casesCollection.delete(data.id)
              // Update Svelte store
              removeCase(data.id)
              break
          }
        } catch (error) {
          console.error('[Electric Sync] Error processing case message:', error, msg)
        }
      })

      // Invalidate TanStack Query cache to trigger refetch
      // This ensures components using useCasesQuery get updated data
      queryClient?.invalidateQueries({ queryKey: casesKeys.all })

      // Update sync status
      syncStatus.connected = true
      syncStatus.lastSyncTime = new Date()
    })

    // Store subscription (stream handles errors internally)
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
export async function syncAgencies() {
  const key = 'agencies'

  if (activeSubscriptions.has(key)) {
    return activeSubscriptions.get(key)
  }

  try {
    // Get the agencies collection (browser only)
    const agenciesCollection = await getAgenciesCollection()

    const stream = new ShapeStream<Agency>({
      url: `${ELECTRIC_URL}/v1/shape`,
      params: {
        table: 'agencies',
      },
    })

    const subscription = stream.subscribe((messages) => {
      console.log(`[Electric Sync] Received ${messages.length} agency updates`)

      messages.forEach((msg: any) => {
        // Skip control messages
        if (msg.headers?.control) {
          console.log('[Electric Sync] Control message:', msg.headers.control)
          return
        }

        // Handle data messages (operation is in headers, data is in value)
        const operation = msg.headers?.operation
        const data = msg.value

        if (!operation || !data) {
          console.warn('[Electric Sync] Message missing operation or value:', msg)
          return
        }

        console.log('[Electric Sync] Agency operation:', operation, data)

        try {
          switch (operation) {
            case 'insert':
              // Insert into TanStack DB collection
              agenciesCollection.insert(data as Agency)
              // Update Svelte store for immediate reactivity
              addAgency(data as Agency)
              console.log('[Electric Sync] Agency inserted:', data.id, data.name)
              break

            case 'update':
              // Update in TanStack DB collection
              agenciesCollection.update(data.id, (draft) => {
                Object.assign(draft, data)
              })
              // Update Svelte store
              updateAgency(data.id, data)
              console.log('[Electric Sync] Agency updated:', data.id, data.name)
              break

            case 'delete':
              // Delete from TanStack DB collection
              agenciesCollection.delete(data.id)
              // Update Svelte store
              removeAgency(data.id)
              console.log('[Electric Sync] Agency deleted:', data.id)
              break
          }
        } catch (error) {
          console.error('[Electric Sync] Error processing agency message:', error, msg)
        }
      })

      // Invalidate TanStack Query cache to trigger refetch
      queryClient?.invalidateQueries({ queryKey: agenciesKeys.all })

      // Update sync status
      syncStatus.connected = true
      syncStatus.lastSyncTime = new Date()
    })

    // Store subscription (stream handles errors internally)
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
export async function syncOffenders() {
  const key = 'offenders'

  if (activeSubscriptions.has(key)) {
    return activeSubscriptions.get(key)
  }

  try {
    // Get the offenders collection (browser only)
    const offendersCollection = await getOffendersCollection()

    const stream = new ShapeStream<Offender>({
      url: `${ELECTRIC_URL}/v1/shape`,
      params: {
        table: 'offenders',
      },
    })

    const subscription = stream.subscribe((messages) => {
      messages.forEach((msg: any) => {
        // Skip control messages
        if (msg.headers?.control) {
          return
        }

        // Handle data messages
        const operation = msg.headers?.operation
        const data = msg.value

        if (!operation || !data) {
          return
        }

        try {
          switch (operation) {
            case 'insert':
              offendersCollection.insert(data as Offender)
              break
            case 'update':
              offendersCollection.update(data.id, (draft) => {
                Object.assign(draft, data)
              })
              break
            case 'delete':
              offendersCollection.delete(data.id)
              break
          }
        } catch (error) {
          console.error('[Electric Sync] Error processing offender message:', error)
        }
      })
    })

    // Store subscription (stream handles errors internally)
    activeSubscriptions.set(key, subscription)
    console.log('[Electric Sync] Started syncing offenders')
    return subscription
  } catch (error) {
    console.error('[Electric Sync] Failed to start offenders sync:', error)
    throw error
  }
}

/**
 * Transform scrape session data from ElectricSQL format to our schema
 * (converts string numbers to actual numbers)
 */
function transformScrapeSession(data: any): ScrapeSession {
  return {
    ...data,
    // Convert string numbers to actual numbers
    start_page: parseInt(data.start_page, 10) || 0,
    max_pages: parseInt(data.max_pages, 10) || 0,
    end_page: data.end_page ? parseInt(data.end_page, 10) : null,
    current_page: data.current_page ? parseInt(data.current_page, 10) : null,
    pages_processed: parseInt(data.pages_processed, 10) || 0,
    cases_found: parseInt(data.cases_found, 10) || 0,
    cases_processed: parseInt(data.cases_processed, 10) || 0,
    cases_created: parseInt(data.cases_created, 10) || 0,
    cases_created_current_page: parseInt(data.cases_created_current_page, 10) || 0,
    cases_updated: parseInt(data.cases_updated, 10) || 0,
    cases_updated_current_page: parseInt(data.cases_updated_current_page, 10) || 0,
    cases_exist_total: parseInt(data.cases_exist_total, 10) || 0,
    cases_exist_current_page: parseInt(data.cases_exist_current_page, 10) || 0,
    errors_count: parseInt(data.errors_count, 10) || 0,
  }
}

/**
 * Start syncing ScrapeSession collection
 */
export async function syncScrapeSessions() {
  const key = 'scrape_sessions'

  if (activeSubscriptions.has(key)) {
    return activeSubscriptions.get(key)
  }

  try {
    const scrapeSessionsCollection = await getScrapeSessionsCollection()

    const stream = new ShapeStream<ScrapeSession>({
      url: `${ELECTRIC_URL}/v1/shape`,
      params: {
        table: 'scrape_sessions',
      },
    })

    const subscription = stream.subscribe((messages) => {
      console.log(`[Electric Sync] Received ${messages.length} scrape session updates`)

      messages.forEach((msg: any) => {
        if (msg.headers?.control) {
          return
        }

        const operation = msg.headers?.operation
        const rawData = msg.value

        if (!operation || !rawData) {
          return
        }

        try {
          // Transform the data to convert string numbers to actual numbers
          const data = transformScrapeSession(rawData)

          switch (operation) {
            case 'insert':
              scrapeSessionsCollection.insert(data)
              addScrapeSession(data)
              console.log('[Electric Sync] Scrape session inserted:', data.session_id)
              break

            case 'update':
              scrapeSessionsCollection.update(data.id, (draft) => {
                Object.assign(draft, data)
              })
              updateScrapeSession(data.id, data)
              console.log('[Electric Sync] Scrape session updated:', data.session_id, data.status)
              break

            case 'delete':
              scrapeSessionsCollection.delete(rawData.id)
              removeScrapeSession(rawData.id)
              console.log('[Electric Sync] Scrape session deleted:', rawData.id)
              break
          }
        } catch (error) {
          console.error('[Electric Sync] Error processing scrape session message:', error, msg)
        }
      })

      // Invalidate TanStack Query cache (will be used by session history page)
      queryClient?.invalidateQueries({ queryKey: ['scrapeSessions'] })

      syncStatus.connected = true
      syncStatus.lastSyncTime = new Date()
    })

    activeSubscriptions.set(key, subscription)
    console.log('[Electric Sync] Started syncing scrape sessions')
    return subscription
  } catch (error) {
    console.error('[Electric Sync] Failed to start scrape sessions sync:', error)
    throw error
  }
}

/**
 * Start syncing all collections
 *
 * Call this when the app initializes to start syncing
 * all data from PostgreSQL to the local database.
 */
export async function startSync(organizationId?: string) {
  console.log('[Electric Sync] Starting full sync...')

  try {
    await Promise.all([
      syncCases(organizationId),
      syncAgencies(),
      syncOffenders(),
      syncScrapeSessions(),
    ])

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
