/**
 * Legislation Full Sync
 *
 * Implements full sync pattern for legislation:
 * - Currently 0 records (empty table, data to be populated)
 * - Instant load when populated
 * - Full offline access
 * - Real-time updates via ElectricSQL
 *
 * Pattern: Full Sync (like Cases, ready for when legislation data is added)
 */

import { ShapeStream } from '@electric-sql/client'
import type { Legislation } from '$lib/db/schema'
import { writable } from 'svelte/store'

/**
 * Electric service configuration
 */
const ELECTRIC_URL = import.meta.env.PUBLIC_ELECTRIC_URL || 'http://localhost:3001'

/**
 * Sync progress state
 */
export interface LegislationSyncProgress {
	phase: 'idle' | 'syncing' | 'complete'
	totalSynced: number
	error: string | null
}

/**
 * Store for sync progress tracking
 */
export const legislationSyncProgress = writable<LegislationSyncProgress>({
	phase: 'idle',
	totalSynced: 0,
	error: null,
})

/**
 * Cached legislation data
 * This is what components read from
 */
export const cachedLegislation = writable<Legislation[]>([])

/**
 * Active shape subscription (for cleanup)
 */
let legislationShape: any = null

/**
 * Initialize legislation sync
 *
 * Syncs all legislation records (currently 0, ready for future data).
 * Full sync pattern - no progressive loading needed for reference data.
 */
export async function initLegislationSync(): Promise<void> {
	console.log('[Legislation Sync] Initializing full sync...')

	legislationSyncProgress.update((state) => ({
		...state,
		phase: 'syncing',
		totalSynced: 0,
		error: null,
	}))

	try {
		const stream = new ShapeStream<Legislation>({
			url: `${ELECTRIC_URL}/v1/shape`,
			params: {
				table: 'legislation',
			},
		})

		const legislation: Legislation[] = []

		legislationShape = stream.subscribe((messages) => {
			messages.forEach((msg: any) => {
				if (msg.headers?.control) return

				const operation = msg.headers?.operation
				const data = msg.value as Legislation

				if (operation === 'insert' && data) {
					legislation.push(data)
				} else if (operation === 'update' && data) {
					const index = legislation.findIndex((l) => l.id === data.id)
					if (index !== -1) {
						legislation[index] = data
					}
				} else if (operation === 'delete' && data) {
					const index = legislation.findIndex((l) => l.id === data.id)
					if (index !== -1) {
						legislation.splice(index, 1)
					}
				}
			})

			// Update store
			cachedLegislation.set([...legislation])

			legislationSyncProgress.update((state) => ({
				...state,
				phase: 'complete',
				totalSynced: legislation.length,
			}))

			console.log(`[Legislation Sync] Synced ${legislation.length} legislation records`)
		})
	} catch (error) {
		console.error('[Legislation Sync] Sync failed:', error)
		legislationSyncProgress.update((state) => ({
			...state,
			phase: 'idle',
			error: error instanceof Error ? error.message : 'Unknown error',
		}))
		throw error
	}
}

/**
 * Stop legislation sync
 */
export function stopLegislationSync(): void {
	console.log('[Legislation Sync] Stopping sync...')

	if (legislationShape) {
		legislationShape.unsubscribe()
		legislationShape = null
	}

	legislationSyncProgress.update((state) => ({
		...state,
		phase: 'idle',
	}))
}
