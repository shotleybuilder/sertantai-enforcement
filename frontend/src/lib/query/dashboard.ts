import { createQuery } from '@tanstack/svelte-query';
import { PUBLIC_API_URL } from '$env/static/public';

export interface DashboardStats {
	stats: {
		active_agencies: number;
		recent_cases: number;
		recent_notices: number;
		total_cases: number;
		total_notices: number;
		total_fines: string;
		total_costs: string;
		timeframe: string;
		period: string;
		total_legislation: number;
		acts_count: number;
		regulations_count: number;
		orders_count: number;
		acops_count: number;
	};
	recent_activity: Array<{
		type: string;
		record_type: string;
		is_case: boolean;
		regulator_id: string;
		date: string;
		organization: string;
		description: string;
		fine_amount: string;
		agency_link: string;
	}>;
	agency_stats: Array<{
		agency_id: string;
		agency_name: string;
		case_count: number;
		notice_count: number;
	}>;
	error?: string;
}

/**
 * Fetch dashboard statistics for a given time period and optional agency filter
 */
async function fetchDashboardStats(
	period: 'week' | 'month' | 'year',
	agencyId?: string
): Promise<DashboardStats> {
	const params = new URLSearchParams({ period });
	if (agencyId) {
		params.append('agency_id', agencyId);
	}

	const response = await fetch(`${PUBLIC_API_URL}/api/public/dashboard/stats?${params}`);

	if (!response.ok) {
		throw new Error(`Failed to fetch dashboard stats: ${response.statusText}`);
	}

	return response.json();
}

/**
 * TanStack Query hook for dashboard statistics
 * @param period - Time period for statistics (week, month, year)
 * @param agencyId - Optional agency ID to filter stats by specific agency
 */
export function useDashboardStats(period: 'week' | 'month' | 'year', agencyId?: string) {
	return createQuery({
		queryKey: ['dashboardStats', period, agencyId ?? 'all'],
		queryFn: () => fetchDashboardStats(period, agencyId),
		staleTime: 5 * 60 * 1000, // 5 minutes - stats are relatively stable
		gcTime: 10 * 60 * 1000 // 10 minutes - keep cached for quick navigation
	});
}
