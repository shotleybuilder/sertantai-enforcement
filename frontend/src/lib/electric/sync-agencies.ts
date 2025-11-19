/**
 * Agencies Full Sync
 *
 * Implements full sync pattern for agencies:
 * - Small dataset (4 records: HSE, EA, ORR, ONR)
 * - Instant load (<1s for all records)
 * - Full offline access
 * - Real-time updates via ElectricSQL
 *
 * Pattern: Full Sync (like Cases, but simpler - no progressive loading needed)
 */

import { ShapeStream } from '@electric-sql/client'
import type { Agency } from '$lib/db/schema'
import { writable } from 'svelte/store'

/**
 * Electric service configuration
 */
const ELECTRIC_URL = import.meta.env.PUBLIC_ELECTRIC_URL || 'http://localhost:3001'

/**
 * Sync progress state
 */
export interface AgenciesSyncProgress {
	phase: 'idle' | 'syncing' | 'complete'
	totalSynced: number
	error: string | null
}

/**
 * Store for sync progress tracking
 */
export const agenciesSyncProgress = writable<AgenciesSyncProgress>({
	phase: 'idle',
	totalSynced: 0,
	error: null,
})

/**
 * Cached agencies data
 * This is what components read from
 */
export const cachedAgencies = writable<Agency[]>([])

/**
 * Active shape subscription (for cleanup)
 */
let agenciesShape: any = null

/**
 * Initialize agencies sync
 *
 * Syncs all 4 agencies instantly (very small dataset).
 * No progressive loading needed.
 */
export async function initAgenciesSync(): Promise<void> {
	console.log('[Agencies Sync] Initializing full sync...')

	agenciesSyncProgress.update((state) => ({
		...state,
		phase: 'syncing',
		totalSynced: 0,
		error: null,
	}))

	try {
		const stream = new ShapeStream<Agency>({
			url: `${ELECTRIC_URL}/v1/shape`,
			params: {
				table: 'agencies',
			},
		})

		const agencies: Agency[] = []

		agenciesShape = stream.subscribe((messages) => {
			messages.forEach((msg: any) => {
				if (msg.headers?.control) return

				const operation = msg.headers?.operation
				const data = msg.value as Agency

				if (operation === 'insert' && data) {
					agencies.push(data)
				} else if (operation === 'update' && data) {
					const index = agencies.findIndex((a) => a.id === data.id)
					if (index !== -1) {
						agencies[index] = data
					}
				} else if (operation === 'delete' && data) {
					const index = agencies.findIndex((a) => a.id === data.id)
					if (index !== -1) {
						agencies.splice(index, 1)
					}
				}
			})

			// Update store
			cachedAgencies.set([...agencies])

			agenciesSyncProgress.update((state) => ({
				...state,
				phase: 'complete',
				totalSynced: agencies.length,
			}))

			console.log(`[Agencies Sync] Synced ${agencies.length} agencies`)
		})
	} catch (error) {
		console.error('[Agencies Sync] Sync failed:', error)
		agenciesSyncProgress.update((state) => ({
			...state,
			phase: 'idle',
			error: error instanceof Error ? error.message : 'Unknown error',
		}))
		throw error
	}
}

/**
 * Stop agencies sync
 */
export function stopAgenciesSync(): void {
	console.log('[Agencies Sync] Stopping sync...')

	if (agenciesShape) {
		agenciesShape.unsubscribe()
		agenciesShape = null
	}

	agenciesSyncProgress.update((state) => ({
		...state,
		phase: 'idle',
	}))
}
