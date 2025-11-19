/**
 * SearchShapeManager - Generic Shape Lifecycle Manager for Query-Based Caching
 *
 * Implements LRU (Least Recently Used) cache eviction for ElectricSQL shapes.
 * Used for large datasets where users search/filter and we cache results.
 *
 * Pattern: User searches → sync matching subset → cache for offline access
 * When cache is full → evict least recently used search → dispose shape
 *
 * Use Cases:
 * - Notices (40k records): Search-driven caching
 * - Offenders (10k+ records): Search-driven caching
 *
 * See PUBLIC_SYNC.md for research and rationale.
 */

import { ShapeStream } from '@electric-sql/client'
import { writable, get } from 'svelte/store'

/**
 * Represents a cached search shape
 */
export interface CachedShape {
	key: string // Unique cache key (hash of search params)
	description: string // Human-readable description ("Search: ABC Ltd")
	shapeSubscription: any // ElectricSQL shape subscription
	recordCount: number // Number of records in this shape
	createdAt: Date
	lastAccessedAt: Date
}

/**
 * Shape cache state for UI feedback
 */
export interface ShapeCacheState {
	totalShapes: number
	cacheKeys: string[] // List of cached search keys
	cacheDescriptions: Map<string, string> // key → description
	maxShapes: number
	oldestEvicted: string | null // Description of last evicted search
}

/**
 * SearchShapeManager - Manages lifecycle of search-based ElectricSQL shapes
 *
 * Features:
 * - LRU cache eviction (keeps most recently accessed)
 * - Automatic shape disposal when evicted
 * - Cache hit/miss tracking
 * - UI-friendly state for feedback
 */
export class SearchShapeManager {
	private shapes: Map<string, CachedShape>
	private maxShapes: number
	private cacheState: ReturnType<typeof writable<ShapeCacheState>>

	constructor(maxShapes: number = 10) {
		this.shapes = new Map()
		this.maxShapes = maxShapes

		// Create reactive store for UI
		this.cacheState = writable<ShapeCacheState>({
			totalShapes: 0,
			cacheKeys: [],
			cacheDescriptions: new Map(),
			maxShapes: this.maxShapes,
			oldestEvicted: null,
		})
	}

	/**
	 * Get the reactive cache state store (for Svelte components)
	 */
	getCacheState() {
		return this.cacheState
	}

	/**
	 * Check if a search is already cached
	 */
	has(cacheKey: string): boolean {
		return this.shapes.has(cacheKey)
	}

	/**
	 * Get a cached shape (marks as recently accessed)
	 */
	get(cacheKey: string): CachedShape | null {
		const shape = this.shapes.get(cacheKey)
		if (shape) {
			// Update last accessed time (LRU)
			shape.lastAccessedAt = new Date()
			console.log(`[SearchShapeManager] Cache HIT: ${shape.description}`)
		}
		return shape || null
	}

	/**
	 * Add a new shape to the cache
	 *
	 * If cache is full, evicts least recently used shape first.
	 */
	async add(
		cacheKey: string,
		description: string,
		shapeSubscription: any,
		recordCount: number = 0
	): Promise<void> {
		// If already exists, just update
		if (this.shapes.has(cacheKey)) {
			const existing = this.shapes.get(cacheKey)!
			existing.shapeSubscription = shapeSubscription
			existing.recordCount = recordCount
			existing.lastAccessedAt = new Date()
			this.updateCacheState()
			return
		}

		// Check if we need to evict
		if (this.shapes.size >= this.maxShapes) {
			await this.evictLRU()
		}

		// Add new shape
		const cachedShape: CachedShape = {
			key: cacheKey,
			description,
			shapeSubscription,
			recordCount,
			createdAt: new Date(),
			lastAccessedAt: new Date(),
		}

		this.shapes.set(cacheKey, cachedShape)
		console.log(
			`[SearchShapeManager] Cached: ${description} (${recordCount} records) - Total: ${this.shapes.size}/${this.maxShapes}`
		)

		this.updateCacheState()
	}

	/**
	 * Remove a specific shape from cache
	 */
	async remove(cacheKey: string): Promise<void> {
		const shape = this.shapes.get(cacheKey)
		if (!shape) return

		// Dispose the shape subscription
		await this.disposeShape(shape)

		this.shapes.delete(cacheKey)
		console.log(`[SearchShapeManager] Removed: ${shape.description}`)

		this.updateCacheState()
	}

	/**
	 * Clear all cached shapes
	 */
	async clear(): Promise<void> {
		console.log(`[SearchShapeManager] Clearing all ${this.shapes.size} cached shapes...`)

		// Dispose all shapes
		for (const shape of this.shapes.values()) {
			await this.disposeShape(shape)
		}

		this.shapes.clear()
		this.updateCacheState()
	}

	/**
	 * Get cache statistics
	 */
	getStats() {
		const totalRecords = Array.from(this.shapes.values()).reduce(
			(sum, shape) => sum + shape.recordCount,
			0
		)

		return {
			totalShapes: this.shapes.size,
			maxShapes: this.maxShapes,
			totalRecords,
			cacheKeys: Array.from(this.shapes.keys()),
			shapes: Array.from(this.shapes.values()).map((s) => ({
				description: s.description,
				recordCount: s.recordCount,
				age: Date.now() - s.createdAt.getTime(),
				lastAccessed: Date.now() - s.lastAccessedAt.getTime(),
			})),
		}
	}

	/**
	 * Evict least recently used shape (LRU algorithm)
	 */
	private async evictLRU(): Promise<void> {
		if (this.shapes.size === 0) return

		// Find shape with oldest lastAccessedAt
		let oldestShape: CachedShape | null = null
		let oldestTime = Infinity

		for (const shape of this.shapes.values()) {
			const accessTime = shape.lastAccessedAt.getTime()
			if (accessTime < oldestTime) {
				oldestTime = accessTime
				oldestShape = shape
			}
		}

		if (oldestShape) {
			console.log(
				`[SearchShapeManager] Cache full (${this.shapes.size}/${this.maxShapes}) - Evicting LRU: ${oldestShape.description}`
			)

			// Dispose the shape
			await this.disposeShape(oldestShape)

			// Update state before removing
			this.cacheState.update((state) => ({
				...state,
				oldestEvicted: oldestShape!.description,
			}))

			// Remove from cache
			this.shapes.delete(oldestShape.key)
		}
	}

	/**
	 * Dispose a shape subscription (cleanup)
	 */
	private async disposeShape(shape: CachedShape): Promise<void> {
		try {
			if (shape.shapeSubscription && typeof shape.shapeSubscription.unsubscribe === 'function') {
				shape.shapeSubscription.unsubscribe()
				console.log(`[SearchShapeManager] Disposed shape: ${shape.description}`)
			}
		} catch (error) {
			console.error(`[SearchShapeManager] Error disposing shape:`, error)
		}
	}

	/**
	 * Update the reactive cache state (for UI)
	 */
	private updateCacheState(): void {
		const descriptions = new Map<string, string>()
		this.shapes.forEach((shape, key) => {
			descriptions.set(key, shape.description)
		})

		this.cacheState.set({
			totalShapes: this.shapes.size,
			cacheKeys: Array.from(this.shapes.keys()),
			cacheDescriptions: descriptions,
			maxShapes: this.maxShapes,
			oldestEvicted: get(this.cacheState).oldestEvicted,
		})
	}
}

/**
 * Generate a cache key from search parameters
 *
 * Creates a deterministic string key from search filters.
 * Same search params → same key → cache hit
 */
export function generateCacheKey(params: {
	searchTerm?: string
	agencyId?: string
	dateFrom?: string
	dateTo?: string
	noticeType?: string
	[key: string]: string | undefined
}): string {
	// Sort keys for deterministic output
	const sortedKeys = Object.keys(params).sort()

	const keyParts = sortedKeys
		.map((key) => {
			const value = params[key]
			return value ? `${key}:${value.toLowerCase().trim()}` : null
		})
		.filter(Boolean)

	return keyParts.join('|') || 'empty'
}

/**
 * Generate a human-readable description of a search
 */
export function generateSearchDescription(params: {
	searchTerm?: string
	agencyId?: string
	dateFrom?: string
	dateTo?: string
	noticeType?: string
	[key: string]: string | undefined
}): string {
	const parts: string[] = []

	if (params.searchTerm) {
		parts.push(`Search: "${params.searchTerm}"`)
	}
	if (params.agencyId) {
		parts.push(`Agency: ${params.agencyId.substring(0, 8)}`)
	}
	if (params.noticeType) {
		parts.push(`Type: ${params.noticeType}`)
	}
	if (params.dateFrom || params.dateTo) {
		const dateRange = [params.dateFrom, params.dateTo].filter(Boolean).join(' to ')
		parts.push(`Dates: ${dateRange}`)
	}

	return parts.length > 0 ? parts.join(' • ') : 'All Records'
}
