import { createQuery } from '@tanstack/svelte-query'
import { cachedNotices } from '$lib/electric/sync-notices'
import { get } from 'svelte/store'

/**
 * TanStack Query keys for notices
 */
export const noticesKeys = {
	all: ['notices'] as const,
	lists: () => [...noticesKeys.all, 'list'] as const,
	list: (filters: string) => [...noticesKeys.lists(), { filters }] as const,
	details: () => [...noticesKeys.all, 'detail'] as const,
	detail: (id: string) => [...noticesKeys.details(), id] as const,
}

/**
 * Fetch all notices from the cached store
 *
 * This reads from the cachedNotices Svelte store populated by ElectricSQL sync.
 * No network request - all data is local.
 */
async function fetchAllNotices() {
	// Read from Svelte store (populated by ElectricSQL sync)
	return get(cachedNotices)
}

/**
 * TanStack Query hook for notices data
 *
 * Reads from local ElectricSQL-synced data (no network requests).
 * Data updates automatically when sync receives changes.
 */
export function useNoticesQuery() {
	return createQuery({
		queryKey: noticesKeys.all,
		queryFn: fetchAllNotices,
		// Don't refetch - data updates via ElectricSQL sync
		refetchOnMount: false,
		refetchOnReconnect: false,
		refetchOnWindowFocus: false,
	})
}

/**
 * Fetch a single notice by ID
 */
async function fetchNoticeById(id: string) {
	const notices = get(cachedNotices)
	const notice = notices.find((n) => n.id === id)
	if (!notice) {
		throw new Error(`Notice not found: ${id}`)
	}
	return notice
}

/**
 * TanStack Query hook for single notice
 */
export function useNoticeQuery(id: string) {
	return createQuery({
		queryKey: noticesKeys.detail(id),
		queryFn: () => fetchNoticeById(id),
		enabled: !!id,
		refetchOnMount: false,
		refetchOnReconnect: false,
		refetchOnWindowFocus: false,
	})
}
