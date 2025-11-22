/**
 * Cases Hybrid Progressive Sync
 *
 * Implements the "Hybrid Progressive Sync" pattern for cases:
 * - Phase 1: Sync recent cases (last 3 years) immediately for fast initial load
 * - Phase 2: Sync historical cases in background for full offline capability
 *
 * See PUBLIC_SYNC.md for research and rationale.
 */

import { ShapeStream } from '@electric-sql/client'
import { getCasesCollection } from '$lib/db/index.client'
import type { Case } from '$lib/db/schema'
import { addCase, updateCase, removeCase } from '$lib/stores/cases'
import { queryClient } from '$lib/query/client'
import { casesKeys } from '$lib/query/cases'
import { writable, get } from 'svelte/store'

/**
 * Electric service configuration
 */
const ELECTRIC_URL = import.meta.env.PUBLIC_ELECTRIC_URL || 'http://localhost:3001'

/**
 * Sync progress state
 */
export interface CasesSyncProgress {
	phase: 'idle' | 'syncing_recent' | 'syncing_historical' | 'complete'
	recentCasesLoaded: boolean
	historicalCasesLoaded: boolean
	totalSynced: number
	recentCount: number
	historicalCount: number
	startTime: Date | null
	recentCompleteTime: Date | null
	fullCompleteTime: Date | null
	error: string | null
}

/**
 * Store for sync progress tracking
 */
export const casesSyncProgress = writable<CasesSyncProgress>({
	phase: 'idle',
	recentCasesLoaded: false,
	historicalCasesLoaded: false,
	totalSynced: 0,
	recentCount: 0,
	historicalCount: 0,
	startTime: null,
	recentCompleteTime: null,
	fullCompleteTime: null,
	error: null,
})

/**
 * Active shape subscriptions
 */
const activeShapes = new Map<string, any>()

/**
 * Calculate date for 3 years ago (for recent cases filter)
 */
function get3YearsAgo(): string {
	const date = new Date()
	date.setFullYear(date.getFullYear() - 3)
	return date.toISOString().split('T')[0] // YYYY-MM-DD format
}

/**
 * Message batch buffer for performance
 * Processing messages one-by-one is too slow - batch them up
 */
const messageBatches = {
	recent: [] as any[],
	historical: [] as any[],
}

let batchProcessingTimer: ReturnType<typeof setTimeout> | null = null

/**
 * Process a batch of case messages efficiently with requestIdleCallback
 * to prevent blocking the main thread and freezing the browser
 */
async function processBatchedMessages(phase: 'recent' | 'historical') {
	const batch = messageBatches[phase]
	if (batch.length === 0) return

	// Take batch and clear buffer
	const messagesToProcess = batch.splice(0, batch.length)

	try {
		const casesCollection = await getCasesCollection()
		let insertCount = 0
		let updateCount = 0
		let deleteCount = 0

		// Process in chunks to avoid blocking main thread
		const CHUNK_SIZE = 50 // Process 50 messages at a time

		for (let i = 0; i < messagesToProcess.length; i += CHUNK_SIZE) {
			const chunk = messagesToProcess.slice(i, i + CHUNK_SIZE)

			// Use requestIdleCallback to yield to browser between chunks
			await new Promise<void>((resolve) => {
				const processChunk = () => {
					for (const msg of chunk) {
						const operation = msg.headers?.operation
						let data = msg.value

						if (!operation || !data) continue

						// Convert numeric fields from strings to numbers
						// ElectricSQL/Postgres returns numeric types as strings
						if (data.offence_fine !== null && data.offence_fine !== undefined) {
							data.offence_fine = parseFloat(data.offence_fine) || null
						}
						if (data.offence_costs !== null && data.offence_costs !== undefined) {
							data.offence_costs = parseFloat(data.offence_costs) || null
						}
						if (data.ea_total_violation_count !== null && data.ea_total_violation_count !== undefined) {
							data.ea_total_violation_count = parseInt(data.ea_total_violation_count, 10) || null
						}

						switch (operation) {
							case 'insert':
								casesCollection.insert(data as Case)
								addCase(data as Case)
								insertCount++
								break

							case 'update':
								casesCollection.update(data.id, (draft) => {
									Object.assign(draft, data)
								})
								updateCase(data.id, data)
								updateCount++
								break

							case 'delete':
								casesCollection.delete(data.id)
								removeCase(data.id)
								deleteCount++
								break
						}
					}
					resolve()
				}

				// Use requestIdleCallback if available, fallback to setTimeout
				if ('requestIdleCallback' in window) {
					requestIdleCallback(processChunk, { timeout: 100 })
				} else {
					setTimeout(processChunk, 0)
				}
			})
		}

		// Update progress counters once for whole batch
		casesSyncProgress.update((state) => ({
			...state,
			totalSynced: state.totalSynced + messagesToProcess.length,
			[phase === 'recent' ? 'recentCount' : 'historicalCount']:
				state[phase === 'recent' ? 'recentCount' : 'historicalCount'] + messagesToProcess.length,
		}))

		console.log(
			`[Cases Sync] Processed ${phase} batch: ${insertCount} inserts, ${updateCount} updates, ${deleteCount} deletes`
		)
	} catch (error) {
		console.error(`[Cases Sync] Error processing ${phase} batch:`, error)
	}
}

/**
 * Process case message from ElectricSQL shape stream
 * Uses batching to prevent browser freeze on large datasets
 */
async function processCaseMessage(msg: any, phase: 'recent' | 'historical') {
	// Skip control messages
	if (msg.headers?.control) {
		return
	}

	const operation = msg.headers?.operation
	const data = msg.value

	if (!operation || !data) {
		return
	}

	// Add to batch buffer
	messageBatches[phase].push(msg)

	// Clear existing timer
	if (batchProcessingTimer) {
		clearTimeout(batchProcessingTimer)
	}

	// Process batch after 50ms of no new messages OR when batch reaches 100 items
	if (messageBatches[phase].length >= 100) {
		// Immediate processing for large batches
		await processBatchedMessages(phase)
	} else {
		// Debounced processing for smaller batches
		batchProcessingTimer = setTimeout(async () => {
			await processBatchedMessages(phase)
		}, 50)
	}
}

/**
 * Phase 1: Sync recent cases (last 3 years)
 *
 * This provides fast initial load with relevant recent data.
 * Users can interact with the table immediately after this completes.
 */
export async function syncRecentCases(): Promise<void> {
	const key = 'cases-recent'

	// If already syncing recent cases, return existing subscription
	if (activeShapes.has(key)) {
		console.log('[Cases Sync] Recent cases already syncing')
		return
	}

	try {
		casesSyncProgress.update((state) => ({
			...state,
			phase: 'syncing_recent',
			startTime: new Date(),
			error: null,
		}))

		const threeYearsAgo = get3YearsAgo()
		console.log('[Cases Sync] Starting recent cases sync (since ' + threeYearsAgo + ')')

		// Create shape stream for recent cases only
		const stream = new ShapeStream<Case>({
			url: `${ELECTRIC_URL}/v1/shape`,
			params: {
				table: 'cases',
				// Filter for recent cases (last 3 years)
				where: `offence_action_date >= '${threeYearsAgo}'`,
			},
		})

		// Track if initial sync is complete
		let initialSyncComplete = false

		// Subscribe to shape changes
		const subscription = stream.subscribe((messages) => {
			if (!initialSyncComplete && messages.length > 0) {
				console.log(`[Cases Sync] Received ${messages.length} recent case updates`)
			}

			// Process all messages
			messages.forEach((msg) => processCaseMessage(msg, 'recent'))

			// Mark initial sync as complete (first batch received)
			if (!initialSyncComplete && messages.length > 0) {
				initialSyncComplete = true

				casesSyncProgress.update((state) => ({
					...state,
					recentCasesLoaded: true,
					recentCompleteTime: new Date(),
				}))

				// Invalidate TanStack Query cache to trigger UI update
				queryClient?.invalidateQueries({ queryKey: casesKeys.all })

				console.log('[Cases Sync] Recent cases loaded - users can now interact')

				// Start background sync of historical cases after 2 seconds
				setTimeout(() => {
					syncHistoricalCases()
				}, 2000)
			}
		})

		// Store subscription
		activeShapes.set(key, subscription)
	} catch (error) {
		console.error('[Cases Sync] Failed to sync recent cases:', error)
		casesSyncProgress.update((state) => ({
			...state,
			phase: 'idle',
			error: error instanceof Error ? error.message : 'Unknown error',
		}))
		throw error
	}
}

/**
 * Phase 2: Sync historical cases (older than 3 years)
 *
 * This runs in the background while users interact with recent cases.
 * Provides full offline capability once complete.
 */
export async function syncHistoricalCases(): Promise<void> {
	const key = 'cases-historical'

	// If already syncing historical cases, return
	if (activeShapes.has(key)) {
		console.log('[Cases Sync] Historical cases already syncing')
		return
	}

	try {
		casesSyncProgress.update((state) => ({
			...state,
			phase: 'syncing_historical',
		}))

		const threeYearsAgo = get3YearsAgo()
		console.log('[Cases Sync] Starting historical cases sync (before ' + threeYearsAgo + ')')

		// Create shape stream for historical cases only
		const stream = new ShapeStream<Case>({
			url: `${ELECTRIC_URL}/v1/shape`,
			params: {
				table: 'cases',
				// Filter for historical cases (older than 3 years)
				where: `offence_action_date < '${threeYearsAgo}'`,
			},
		})

		// Track if initial sync is complete
		let initialSyncComplete = false

		// Subscribe to shape changes
		const subscription = stream.subscribe((messages) => {
			if (!initialSyncComplete && messages.length > 0) {
				console.log(`[Cases Sync] Received ${messages.length} historical case updates`)
			}

			// Process all messages
			messages.forEach((msg) => processCaseMessage(msg, 'historical'))

			// Mark initial sync as complete
			if (!initialSyncComplete && messages.length > 0) {
				initialSyncComplete = true

				casesSyncProgress.update((state) => ({
					...state,
					phase: 'complete',
					historicalCasesLoaded: true,
					fullCompleteTime: new Date(),
				}))

				// Invalidate TanStack Query cache to show full dataset
				queryClient?.invalidateQueries({ queryKey: casesKeys.all })

				const progress = get(casesSyncProgress)
				const syncDuration = progress.fullCompleteTime && progress.startTime
					? ((progress.fullCompleteTime.getTime() - progress.startTime.getTime()) / 1000).toFixed(1)
					: 'unknown'

				console.log('[Cases Sync] Full dataset loaded - complete offline capability')
				console.log(`[Cases Sync] Total synced: ${progress.totalSynced} cases in ${syncDuration}s`)
				console.log(`[Cases Sync] Recent: ${progress.recentCount}, Historical: ${progress.historicalCount}`)
			}
		})

		// Store subscription
		activeShapes.set(key, subscription)
	} catch (error) {
		console.error('[Cases Sync] Failed to sync historical cases:', error)
		casesSyncProgress.update((state) => ({
			...state,
			error: error instanceof Error ? error.message : 'Unknown error',
		}))
		// Don't throw - historical sync failing shouldn't block the app
	}
}

/**
 * Start hybrid progressive sync for cases
 *
 * Call this when the cases page loads to start the two-phase sync:
 * 1. Recent cases first (fast, users can interact immediately)
 * 2. Historical cases in background (full offline capability)
 */
export async function startCasesSync(): Promise<void> {
	console.log('[Cases Sync] Starting hybrid progressive sync...')

	// Reset progress state
	casesSyncProgress.update((state) => ({
		...state,
		phase: 'syncing_recent',
		recentCasesLoaded: false,
		historicalCasesLoaded: false,
		totalSynced: 0,
		recentCount: 0,
		historicalCount: 0,
		startTime: new Date(),
		recentCompleteTime: null,
		fullCompleteTime: null,
		error: null,
	}))

	// Start with recent cases (historical will auto-start after recent completes)
	await syncRecentCases()
}

/**
 * Stop all cases syncs
 */
export function stopCasesSync(): void {
	console.log('[Cases Sync] Stopping all cases syncs...')

	activeShapes.forEach((subscription, key) => {
		if (subscription && typeof subscription.unsubscribe === 'function') {
			subscription.unsubscribe()
			console.log(`[Cases Sync] Stopped ${key}`)
		}
	})

	activeShapes.clear()

	casesSyncProgress.update((state) => ({
		...state,
		phase: 'idle',
	}))
}

/**
 * Check if cases sync is ready for user interaction
 * (recent cases have been loaded)
 */
export function isCasesSyncReady(): boolean {
	const progress = get(casesSyncProgress)
	return progress.recentCasesLoaded
}

/**
 * Check if full cases sync is complete
 * (both recent and historical cases loaded)
 */
export function isCasesSyncComplete(): boolean {
	const progress = get(casesSyncProgress)
	return progress.recentCasesLoaded && progress.historicalCasesLoaded
}
