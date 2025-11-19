/**
 * Offenders Query-Based On-Demand Caching
 *
 * Implements the "Query-Based On-Demand Caching" pattern for offenders:
 * - NO baseline sync (pure search-driven)
 * - Search-triggered subset syncs only
 * - LRU cache management (max 10 searches)
 * - Changes-only stream for real-time updates (optional)
 *
 * Dataset: ~223 records (current), 10k+ (production potential)
 * Strategy: Search-first UX - users must search to see data
 *
 * See PUBLIC_SYNC.md for research and rationale.
 */

import { ShapeStream } from '@electric-sql/client'
import type { Offender } from '$lib/db/schema'
import { writable } from 'svelte/store'
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
export interface OffendersSyncProgress {
	phase: 'idle' | 'searching'
	totalCached: number // Total offenders across all cached searches
	currentSearch: string | null
	searchInProgress: boolean
	error: string | null
}

/**
 * Search parameters
 */
export interface OffendersSearchParams {
	searchTerm?: string
	companyNumber?: string
	location?: string // postcode, town, county
	industry?: string
	businessType?: string
}

/**
 * Store for sync progress tracking
 */
export const offendersSyncProgress = writable<OffendersSyncProgress>({
	phase: 'idle',
	totalCached: 0,
	currentSearch: null,
	searchInProgress: false,
	error: null,
})

/**
 * Cached offenders data (search results only - NO baseline)
 * This is what TanStack Table reads from
 */
export const cachedOffenders = writable<Offender[]>([])

/**
 * Shape manager for search-based caching
 */
const searchShapeManager = new SearchShapeManager(10) // Max 10 cached searches

/**
 * Build SQL WHERE clause from search parameters
 */
function buildWhereClause(params: OffendersSearchParams): string {
	const conditions: string[] = []

	// Search term (searches name, normalized_name, local_authority)
	if (params.searchTerm && params.searchTerm.trim()) {
		const term = params.searchTerm.trim()
		// Use ILIKE for case-insensitive search
		conditions.push(
			`(name ILIKE '%${term}%' OR normalized_name ILIKE '%${term}%' OR local_authority ILIKE '%${term}%')`
		)
	}

	// Company registration number
	if (params.companyNumber && params.companyNumber.trim()) {
		conditions.push(`company_registration_number LIKE '%${params.companyNumber.trim()}%'`)
	}

	// Location (postcode, town, county)
	if (params.location && params.location.trim()) {
		const loc = params.location.trim()
		conditions.push(`(postcode ILIKE '%${loc}%' OR town ILIKE '%${loc}%' OR county ILIKE '%${loc}%')`)
	}

	// Industry
	if (params.industry && params.industry.trim()) {
		const ind = params.industry.trim()
		conditions.push(`(industry ILIKE '%${ind}%' OR main_activity ILIKE '%${ind}%')`)
	}

	// Business type
	if (params.businessType) {
		conditions.push(`business_type = '${params.businessType}'`)
	}

	return conditions.length > 0 ? conditions.join(' AND ') : ''
}

/**
 * Initialize offenders sync (NO baseline - search-first UX)
 *
 * Unlike cases/notices, offenders start empty. Users must search to populate.
 */
export async function initOffendersSync(): Promise<void> {
	console.log('[Offenders Sync] Initializing search-first sync (no baseline)...')

	offendersSyncProgress.update((state) => ({
		...state,
		phase: 'idle',
		totalCached: 0,
		currentSearch: null,
		searchInProgress: false,
		error: null,
	}))

	// No baseline sync - start with empty table
	// Users trigger syncs by searching
	console.log('[Offenders Sync] Ready for searches (no baseline)')
}

/**
 * Search-triggered subset sync
 *
 * When user searches, sync matching offenders and cache for offline access.
 * Uses SearchShapeManager for LRU cache eviction.
 */
export async function searchOffenders(params: OffendersSearchParams): Promise<Offender[]> {
	const cacheKey = generateCacheKey(params)
	const description = generateSearchDescription(params)

	// Check cache first
	if (searchShapeManager.has(cacheKey)) {
		console.log(`[Offenders Sync] Cache HIT: ${description}`)
		searchShapeManager.get(cacheKey) // Update LRU timestamp

		// Return cached results (filter from cachedOffenders store)
		const allOffenders = cachedOffenders
		// In production, you'd filter by the search params
		// For now, return all cached offenders
		return new Promise((resolve) => {
			const unsubscribe = allOffenders.subscribe((offenders) => {
				resolve(offenders)
				unsubscribe()
			})
		})
	}

	// Cache MISS - sync new subset
	console.log(`[Offenders Sync] Cache MISS: ${description} - syncing from server...`)

	offendersSyncProgress.update((state) => ({
		...state,
		phase: 'searching',
		currentSearch: description,
		searchInProgress: true,
	}))

	try {
		const whereClause = buildWhereClause(params)

		if (!whereClause) {
			// Empty search - return empty results (no baseline)
			offendersSyncProgress.update((state) => ({
				...state,
				searchInProgress: false,
				currentSearch: null,
			}))
			return []
		}

		console.log('[Offenders Sync] WHERE clause:', whereClause)

		const stream = new ShapeStream<Offender>({
			url: `${ELECTRIC_URL}/v1/shape`,
			params: {
				table: 'offenders',
				where: whereClause,
			},
		})

		const searchResults: Offender[] = []

		return new Promise((resolve, reject) => {
			let initialSyncComplete = false

			const subscription = stream.subscribe((messages) => {
				messages.forEach((msg: any) => {
					if (msg.headers?.control) return

					const operation = msg.headers?.operation
					const data = msg.value as Offender

					if (operation === 'insert' && data) {
						searchResults.push(data)
					}
				})

				// Mark search complete after first batch
				if (!initialSyncComplete && messages.length > 0) {
					initialSyncComplete = true

					// Add to cached offenders
					cachedOffenders.update((existing) => {
						const combined = [...existing, ...searchResults]
						// Deduplicate
						return Array.from(new Map(combined.map((o) => [o.id, o])).values())
					})

					// Cache the shape subscription
					searchShapeManager.add(cacheKey, description, subscription, searchResults.length)

					offendersSyncProgress.update((state) => {
						let totalCached = 0
						cachedOffenders.subscribe((offenders) => {
							totalCached = offenders.length
						})()

						return {
							...state,
							searchInProgress: false,
							currentSearch: null,
							totalCached,
						}
					})

					console.log(
						`[Offenders Sync] Search complete: ${searchResults.length} results for "${description}"`
					)

					resolve(searchResults)
				}
			})

			// Timeout after 10 seconds
			setTimeout(() => {
				if (!initialSyncComplete) {
					offendersSyncProgress.update((state) => ({
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
		console.error('[Offenders Sync] Search failed:', error)
		offendersSyncProgress.update((state) => ({
			...state,
			searchInProgress: false,
			currentSearch: null,
			error: error instanceof Error ? error.message : 'Unknown error',
		}))
		throw error
	}
}

/**
 * Stop all offenders syncs
 */
export function stopOffendersSync(): void {
	console.log('[Offenders Sync] Stopping all syncs...')

	// Clear search cache
	searchShapeManager.clear()

	offendersSyncProgress.update((state) => ({
		...state,
		phase: 'idle',
	}))
}

/**
 * Get cache statistics (for UI display)
 */
export function getOffendersCacheStats() {
	return searchShapeManager.getStats()
}

/**
 * Get cache state store (for UI)
 */
export function getOffendersCacheState() {
	return searchShapeManager.getCacheState()
}
