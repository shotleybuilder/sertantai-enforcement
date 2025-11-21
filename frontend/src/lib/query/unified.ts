import { createQuery } from '@tanstack/svelte-query';
import { PUBLIC_API_URL } from '$env/static/public';

/**
 * Unified record type combining Cases and Notices
 */
export interface UnifiedRecord {
	id: string;
	record_type: 'case' | 'notice';

	// Common fields
	regulator_id: string;
	offence_action_date: string | null;
	offence_action_type: string | null;
	offence_breaches: string | null;
	regulator_function: string | null;
	environmental_impact: string | null;
	environmental_receptor: string | null;
	url: string | null;
	agency_id: string;

	// Case-specific fields (NULL for notices)
	case_reference: string | null;
	offence_result: string | null;
	offence_fine: number | null;
	offence_costs: number | null;
	offence_hearing_date: string | null;
	related_cases: string[] | null;

	// Notice-specific fields (NULL for cases)
	notice_date: string | null;
	notice_body: string | null;
	operative_date: string | null;
	compliance_date: string | null;
	regulator_ref_number: string | null;

	// Timestamps
	inserted_at: string;
	updated_at: string;
}

export interface UnifiedDataResponse {
	data: UnifiedRecord[];
	meta: {
		total_count: number;
		limit: number;
		offset: number;
		cases_count: number;
		notices_count: number;
		record_types: {
			case: number;
			notice: number;
		};
	};
}

export interface UnifiedDataParams {
	limit?: number;
	offset?: number;
	order_by?: string;
	order?: 'asc' | 'desc';
	record_type?: 'case' | 'notice' | 'all';
	date_from?: string;
	date_to?: string;
	agency_id?: string;
}

/**
 * Fetch unified data from the API
 */
async function fetchUnifiedData(params: UnifiedDataParams = {}): Promise<UnifiedDataResponse> {
	const searchParams = new URLSearchParams();

	if (params.limit) searchParams.set('limit', params.limit.toString());
	if (params.offset) searchParams.set('offset', params.offset.toString());
	if (params.order_by) searchParams.set('order_by', params.order_by);
	if (params.order) searchParams.set('order', params.order);
	if (params.record_type) searchParams.set('record_type', params.record_type);
	if (params.date_from) searchParams.set('date_from', params.date_from);
	if (params.date_to) searchParams.set('date_to', params.date_to);
	if (params.agency_id) searchParams.set('agency_id', params.agency_id);

	const url = `${PUBLIC_API_URL}/api/unified-data?${searchParams.toString()}`;
	const response = await fetch(url);

	if (!response.ok) {
		throw new Error(`Failed to fetch unified data: ${response.statusText}`);
	}

	return response.json();
}

/**
 * TanStack Query hook for unified data
 * @param params - Query parameters for filtering, sorting, pagination
 */
export function useUnifiedData(params: UnifiedDataParams = {}) {
	return createQuery({
		queryKey: ['unifiedData', params],
		queryFn: () => fetchUnifiedData(params),
		staleTime: 2 * 60 * 1000, // 2 minutes
		gcTime: 5 * 60 * 1000 // 5 minutes
	});
}
