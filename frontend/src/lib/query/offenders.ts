import { createQuery } from '@tanstack/svelte-query'
import { cachedOffenders } from '$lib/electric/sync-offenders'
import { get } from 'svelte/store'

/**
 * TanStack Query keys for offenders
 */
export const offendersKeys = {
	all: ['offenders'] as const,
	lists: () => [...offendersKeys.all, 'list'] as const,
	list: (filters: string) => [...offendersKeys.lists(), { filters }] as const,
	details: () => [...offendersKeys.all, 'detail'] as const,
	detail: (id: string) => [...offendersKeys.details(), id] as const,
}

/**
 * Fetch all offenders from the cached store
 *
 * This reads from the cachedOffenders Svelte store populated by ElectricSQL sync.
 * No network request - all data is local.
 */
async function fetchAllOffenders() {
	// Read from Svelte store (populated by ElectricSQL sync)
	return get(cachedOffenders)
}

/**
 * TanStack Query hook for offenders data
 *
 * Reads from local ElectricSQL-synced data (no network requests).
 * Data updates automatically when sync receives changes.
 */
export function useOffendersQuery() {
	return createQuery({
		queryKey: offendersKeys.all,
		queryFn: fetchAllOffenders,
		// Don't refetch - data updates via ElectricSQL sync
		refetchOnMount: false,
		refetchOnReconnect: false,
		refetchOnWindowFocus: false,
	})
}

/**
 * Fetch a single offender by ID
 */
async function fetchOffenderById(id: string) {
	const offenders = get(cachedOffenders)
	const offender = offenders.find((o) => o.id === id)
	if (!offender) {
		throw new Error(`Offender not found: ${id}`)
	}
	return offender
}

/**
 * TanStack Query hook for single offender
 */
export function useOffenderQuery(id: string) {
	return createQuery({
		queryKey: offendersKeys.detail(id),
		queryFn: () => fetchOffenderById(id),
		enabled: !!id,
		refetchOnMount: false,
		refetchOnReconnect: false,
		refetchOnWindowFocus: false,
	})
}
