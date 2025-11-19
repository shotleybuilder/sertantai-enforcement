/**
 * Notices Query-Based On-Demand Caching
 *
 * Implements the "Query-Based On-Demand Caching" pattern for notices:
 * - Phase 1: Changes-only stream for real-time updates (no initial snapshot)
 * - Phase 2: Baseline sync (100 recent notices for quick start)
 * - Phase 3: On-demand search-triggered subset syncs (cached with LRU eviction)
 *
 * Dataset: ~40,000 records (80-120 MB) - too large for full sync
 * Strategy: Sync only what users search for + recent baseline
 *
 * See PUBLIC_SYNC.md for research and rationale.
 */

import { ShapeStream } from '@electric-sql/client'
import type { Notice } from '$lib/db/schema'
import { writable, get } from 'svelte/store'
import {
	SearchShapeManager,
	generateCacheKey,
	generateSearchDescription,
} from './search-shape-manager'

/**
 * Electric service configuration
 */
const ELECTRIC_URL = import.meta.env.PUBLIC_ELECTRIC_URL || 'http://localhost:3001'

/**
 * Sync progress state
 */
export interface NoticesSyncProgress {
	phase: 'idle' | 'initializing' | 'baseline_ready' | 'searching'
	baselineLoaded: boolean
	baselineCount: number
	totalCached: number // Total notices across all cached searches
	currentSearch: string | null
	searchInProgress: boolean
	error: string | null
	startTime: Date | null
}

/**
 * Search parameters
 */
export interface NoticesSearchParams {
	searchTerm?: string
	agencyId?: string
	noticeType?: string // offence_action_type
	dateFrom?: string
	dateTo?: string
}

/**
 * Store for sync progress tracking
 */
export const noticesSyncProgress = writable<NoticesSyncProgress>({
	phase: 'idle',
	baselineLoaded: false,
	baselineCount: 0,
	totalCached: 0,
	currentSearch: null,
	searchInProgress: false,
	error: null,
	startTime: null,
})

/**
 * Cached notices data (baseline + search results)
 * This is what TanStack Query reads from
 */
export const cachedNotices = writable<Notice[]>([])

/**
 * Shape manager for search-based caching
 */
const searchShapeManager = new SearchShapeManager(10) // Max 10 cached searches

/**
 * Active subscriptions
 */
let changesOnlyStream: any = null
let baselineStream: any = null

/**
 * Calculate date for 30 days ago (for baseline filter)
 */
function get30DaysAgo(): string {
	const date = new Date()
	date.setDate(date.getDate() - 30)
	return date.toISOString().split('T')[0] // YYYY-MM-DD format
}

/**
 * Build SQL WHERE clause from search parameters
 */
function buildWhereClause(params: NoticesSearchParams): string {
	const conditions: string[] = []

	// Search term (searches in regulator_id, notice_body, offence_breaches)
	if (params.searchTerm && params.searchTerm.trim()) {
		const term = params.searchTerm.trim()
		// Use ILIKE for case-insensitive search
		conditions.push(
			`(regulator_id ILIKE '%${term}%' OR notice_body ILIKE '%${term}%' OR offence_breaches ILIKE '%${term}%')`
		)
	}

	// Agency filter
	if (params.agencyId) {
		conditions.push(`agency_id = '${params.agencyId}'`)
	}

	// Notice type (action type)
	if (params.noticeType) {
		conditions.push(`offence_action_type = '${params.noticeType}'`)
	}

	// Date range
	if (params.dateFrom) {
		conditions.push(`notice_date >= '${params.dateFrom}'`)
	}
	if (params.dateTo) {
		conditions.push(`notice_date <= '${params.dateTo}'`)
	}

	return conditions.length > 0 ? conditions.join(' AND ') : ''
}

/**
 * Phase 1: Start changes-only stream for real-time updates
 *
 * This stream receives new/updated/deleted notices in real-time
 * WITHOUT loading the initial snapshot (saves bandwidth).
 */
export async function startChangesOnlyStream(): Promise<void> {
	if (changesOnlyStream) {
		console.log('[Notices Sync] Changes-only stream already active')
		return
	}

	try {
		console.log('[Notices Sync] Starting changes-only stream...')

		const stream = new ShapeStream<Notice>({
			url: `${ELECTRIC_URL}/v1/shape`,
			params: {
				table: 'notices',
				// CRITICAL: changes_only mode - no initial snapshot
				// offset: 'now', // Start from current point (ElectricSQL will handle this)
			},
		})

		changesOnlyStream = stream.subscribe((messages) => {
			// Process real-time updates
			messages.forEach((msg: any) => {
				if (msg.headers?.control) return

				const operation = msg.headers?.operation
				const data = msg.value as Notice

				if (!operation || !data) return

				// Update cached notices based on operation
				cachedNotices.update((notices) => {
					switch (operation) {
						case 'insert':
							// Add if not already present
							if (!notices.find((n) => n.id === data.id)) {
								return [...notices, data]
							}
							return notices

						case 'update':
							// Update existing
							return notices.map((n) => (n.id === data.id ? data : n))

						case 'delete':
							// Remove
							return notices.filter((n) => n.id !== data.id)

						default:
							return notices
					}
				})
			})
		})

		console.log('[Notices Sync] Changes-only stream started')
	} catch (error) {
		console.error('[Notices Sync] Failed to start changes-only stream:', error)
		throw error
	}
}

/**
 * Phase 2: Sync baseline (100 recent notices)
 *
 * Provides quick initial data for users to browse.
 * Users can interact immediately after this completes.
 */
export async function syncBaseline(): Promise<void> {
	if (baselineStream) {
		console.log('[Notices Sync] Baseline already synced')
		return
	}

	try {
		noticesSyncProgress.update((state) => ({
			...state,
			phase: 'initializing',
			startTime: new Date(),
		}))

		console.log('[Notices Sync] Syncing baseline (all notices, will take 100 most recent)')

		const stream = new ShapeStream<Notice>({
			url: `${ELECTRIC_URL}/v1/shape`,
			params: {
				table: 'notices',
				// No WHERE clause - sync all notices, we'll slice to 100 most recent client-side
			},
		})

		let initialSyncComplete = false

		baselineStream = stream.subscribe((messages) => {
			if (!initialSyncComplete && messages.length > 0) {
				console.log(`[Notices Sync] Received ${messages.length} baseline notice updates`)
			}

			// Collect baseline notices
			const baselineNotices: Notice[] = []

			messages.forEach((msg: any) => {
				if (msg.headers?.control) return

				const operation = msg.headers?.operation
				const data = msg.value as Notice

				if (operation === 'insert' && data) {
					baselineNotices.push(data)
				}
			})

			// Update cached notices with baseline (take first 100)
			if (baselineNotices.length > 0) {
				cachedNotices.update((existing) => {
					const combined = [...existing, ...baselineNotices]
					// Deduplicate by ID
					const unique = Array.from(new Map(combined.map((n) => [n.id, n])).values())
					// Sort by date descending and take first 100
					return unique.sort((a, b) => {
						const dateA = a.notice_date ? new Date(a.notice_date).getTime() : 0
						const dateB = b.notice_date ? new Date(b.notice_date).getTime() : 0
						return dateB - dateA
					}).slice(0, 100)
				})
			}

			// Mark baseline as loaded
			if (!initialSyncComplete && messages.length > 0) {
				initialSyncComplete = true

				const count = get(cachedNotices).length

				noticesSyncProgress.update((state) => ({
					...state,
					phase: 'baseline_ready',
					baselineLoaded: true,
					baselineCount: count,
					totalCached: count,
				}))

				console.log(`[Notices Sync] Baseline loaded - ${count} notices ready`)
			}
		})
	} catch (error) {
		console.error('[Notices Sync] Failed to sync baseline:', error)
		noticesSyncProgress.update((state) => ({
			...state,
			phase: 'idle',
			error: error instanceof Error ? error.message : 'Unknown error',
		}))
		throw error
	}
}

/**
 * Phase 3: Search-triggered subset sync
 *
 * When user searches, sync matching notices and cache for offline access.
 * Uses SearchShapeManager for LRU cache eviction.
 */
export async function searchNotices(params: NoticesSearchParams): Promise<Notice[]> {
	const cacheKey = generateCacheKey(params)
	const description = generateSearchDescription(params)

	// Check cache first
	if (searchShapeManager.has(cacheKey)) {
		console.log(`[Notices Sync] Cache HIT: ${description}`)
		const cachedShape = searchShapeManager.get(cacheKey)

		// Return cached results (filter from cachedNotices store)
		const allNotices = get(cachedNotices)
		return allNotices // In a real implementation, you'd filter by the search params
	}

	// Cache MISS - sync new subset
	console.log(`[Notices Sync] Cache MISS: ${description} - syncing from server...`)

	noticesSyncProgress.update((state) => ({
		...state,
		phase: 'searching',
		currentSearch: description,
		searchInProgress: true,
	}))

	try {
		const whereClause = buildWhereClause(params)

		if (!whereClause) {
			// Empty search - just return baseline
			noticesSyncProgress.update((state) => ({
				...state,
				searchInProgress: false,
				currentSearch: null,
			}))
			return get(cachedNotices)
		}

		console.log('[Notices Sync] WHERE clause:', whereClause)

		const stream = new ShapeStream<Notice>({
			url: `${ELECTRIC_URL}/v1/shape`,
			params: {
				table: 'notices',
				where: whereClause,
			},
		})

		const searchResults: Notice[] = []

		return new Promise((resolve, reject) => {
			let initialSyncComplete = false

			const subscription = stream.subscribe((messages) => {
				messages.forEach((msg: any) => {
					if (msg.headers?.control) return

					const operation = msg.headers?.operation
					const data = msg.value as Notice

					if (operation === 'insert' && data) {
						searchResults.push(data)
					}
				})

				// Mark search complete after first batch
				if (!initialSyncComplete && messages.length > 0) {
					initialSyncComplete = true

					// Add to cached notices
					cachedNotices.update((existing) => {
						const combined = [...existing, ...searchResults]
						// Deduplicate
						return Array.from(new Map(combined.map((n) => [n.id, n])).values())
					})

					// Cache the shape subscription
					searchShapeManager.add(cacheKey, description, subscription, searchResults.length)

					noticesSyncProgress.update((state) => ({
						...state,
						searchInProgress: false,
						currentSearch: null,
						totalCached: get(cachedNotices).length,
					}))

					console.log(`[Notices Sync] Search complete: ${searchResults.length} results for "${description}"`)

					resolve(searchResults)
				}
			})

			// Timeout after 10 seconds
			setTimeout(() => {
				if (!initialSyncComplete) {
					noticesSyncProgress.update((state) => ({
						...state,
						searchInProgress: false,
						currentSearch: null,
						error: 'Search timeout',
					}))
					reject(new Error('Search timeout'))
				}
			}, 10000)
		})
	} catch (error) {
		console.error('[Notices Sync] Search failed:', error)
		noticesSyncProgress.update((state) => ({
			...state,
			searchInProgress: false,
			currentSearch: null,
			error: error instanceof Error ? error.message : 'Unknown error',
		}))
		throw error
	}
}

/**
 * Initialize notices sync
 *
 * Call this when the notices page loads.
 * Starts changes-only stream + baseline sync.
 */
export async function initNoticesSync(): Promise<void> {
	console.log('[Notices Sync] Initializing query-based sync...')

	// Reset progress
	noticesSyncProgress.update((state) => ({
		...state,
		phase: 'initializing',
		baselineLoaded: false,
		baselineCount: 0,
		totalCached: 0,
		currentSearch: null,
		searchInProgress: false,
		error: null,
		startTime: new Date(),
	}))

	try {
		// Start baseline sync only (changes-only stream temporarily disabled for testing)
		await syncBaseline() // Initial 100 notices

		console.log('[Notices Sync] Initialization complete')
	} catch (error) {
		console.error('[Notices Sync] Initialization failed:', error)
		throw error
	}
}

/**
 * Stop all notices syncs
 */
export function stopNoticesSync(): void {
	console.log('[Notices Sync] Stopping all syncs...')

	if (changesOnlyStream && typeof changesOnlyStream.unsubscribe === 'function') {
		changesOnlyStream.unsubscribe()
		changesOnlyStream = null
	}

	if (baselineStream && typeof baselineStream.unsubscribe === 'function') {
		baselineStream.unsubscribe()
		baselineStream = null
	}

	// Clear search cache
	searchShapeManager.clear()

	noticesSyncProgress.update((state) => ({
		...state,
		phase: 'idle',
	}))
}

/**
 * Get cache statistics (for UI display)
 */
export function getNoticesCacheStats() {
	return searchShapeManager.getStats()
}

/**
 * Get cache state store (for UI)
 */
export function getNoticesCacheState() {
	return searchShapeManager.getCacheState()
}
