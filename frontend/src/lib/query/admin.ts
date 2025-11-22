import { createQuery } from '@tanstack/svelte-query';
import { PUBLIC_API_URL } from '$env/static/public';

export interface AdminStats {
	stats: {
		data_quality_score: number;
		active_agencies: number;
		recent_cases: number;
		recent_notices: number;
		total_fines: string;
		sync_errors: number;
		timeframe: string;
	};
	agencies: Array<{
		id: string;
		code: string;
		name: string;
		enabled: boolean;
	}>;
}

/**
 * Fetch admin statistics for a given time period
 */
async function fetchAdminStats(period: 'week' | 'month' | 'year'): Promise<AdminStats> {
	const response = await fetch(`${PUBLIC_API_URL}/api/admin/stats?period=${period}`);

	if (!response.ok) {
		throw new Error(`Failed to fetch admin stats: ${response.statusText}`);
	}

	return response.json();
}

/**
 * TanStack Query hook for admin statistics
 * @param period - Time period for statistics (week, month, year)
 */
export function useAdminStats(period: 'week' | 'month' | 'year') {
	return createQuery({
		queryKey: ['adminStats', period],
		queryFn: () => fetchAdminStats(period),
		staleTime: 5 * 60 * 1000, // 5 minutes
		gcTime: 10 * 60 * 1000 // 10 minutes
	});
}
