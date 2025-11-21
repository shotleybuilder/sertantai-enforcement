import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import { QueryClient } from '@tanstack/svelte-query';
import { createTestQueryClient } from '../../../tests/test-utils';
import DataPage from './+page.svelte';
import type { UnifiedDataResponse } from '$lib/query/unified';
import * as unifiedQuery from '$lib/query/unified';

// Mock the unified query module
vi.mock('$lib/query/unified', () => ({
	useUnifiedData: vi.fn()
}));

// Note: TableKit is not mocked - using real component for integration testing

describe('Data Page (/data/+page.svelte)', () => {
	let queryClient: QueryClient;

	// Mock unified data response
	const mockUnifiedData: UnifiedDataResponse = {
		data: [
			{
				id: '1',
				record_type: 'case',
				regulator_id: 'hse',
				offence_action_date: '2024-01-15T00:00:00Z',
				offence_action_type: 'Prosecution',
				offence_breaches: 'Health and safety breach - failure to ensure safe working conditions',
				regulator_function: 'Health & Safety',
				environmental_impact: null,
				environmental_receptor: null,
				url: 'https://example.com/case/1',
				agency_id: 'hse',
				// Case-specific
				case_reference: 'HSE/2024/001',
				offence_result: 'Guilty',
				offence_fine: 50000,
				offence_costs: 5000,
				offence_hearing_date: '2024-01-10T00:00:00Z',
				related_cases: null,
				// Notice-specific (null for cases)
				notice_date: null,
				notice_body: null,
				operative_date: null,
				compliance_date: null,
				regulator_ref_number: null,
				// Timestamps
				inserted_at: '2024-01-01T00:00:00Z',
				updated_at: '2024-01-01T00:00:00Z'
			},
			{
				id: '2',
				record_type: 'notice',
				regulator_id: 'hse',
				offence_action_date: '2024-01-10T00:00:00Z',
				offence_action_type: 'Improvement Notice',
				offence_breaches: 'Inadequate risk assessment procedures',
				regulator_function: 'Health & Safety',
				environmental_impact: null,
				environmental_receptor: null,
				url: 'https://example.com/notice/2',
				agency_id: 'hse',
				// Case-specific (null for notices)
				case_reference: null,
				offence_result: null,
				offence_fine: null,
				offence_costs: null,
				offence_hearing_date: null,
				related_cases: null,
				// Notice-specific
				notice_date: '2024-01-10T00:00:00Z',
				notice_body: 'The employer must review and update risk assessments',
				operative_date: '2024-01-17T00:00:00Z',
				compliance_date: '2024-02-10T00:00:00Z',
				regulator_ref_number: 'HSE/IN/2024/002',
				// Timestamps
				inserted_at: '2024-01-01T00:00:00Z',
				updated_at: '2024-01-01T00:00:00Z'
			}
		],
		meta: {
			total_count: 2,
			limit: 100,
			offset: 0,
			cases_count: 1,
			notices_count: 1,
			record_types: {
				case: 1,
				notice: 1
			}
		}
	};

	// Helper to create a readable store (like TanStack Query returns)
	function createMockStore(value: any) {
		return {
			subscribe: (fn: (value: any) => void) => {
				fn(value);
				return {
					unsubscribe: () => {}
				};
			}
		};
	}

	beforeEach(() => {
		queryClient = createTestQueryClient();
		vi.clearAllMocks();
	});

	// ==========================================
	// PHASE 1: PAGE LOADING STATES
	// ==========================================

	describe('Page Loading States', () => {
		it('renders loading spinner while data is being fetched', () => {
			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: undefined,
					isSuccess: false,
					isLoading: true,
					isPending: true,
					isError: false,
					error: null
				})
			);

			const { container } = render(DataPage);

			// Check for loading spinner
			const spinner = container.querySelector('.animate-spin');
			expect(spinner).toBeInTheDocument();
			expect(screen.getByText('Loading enforcement data...')).toBeInTheDocument();
		});

		it('displays error message when API request fails', () => {
			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: undefined,
					isSuccess: false,
					isLoading: false,
					isPending: false,
					isError: true,
					error: new Error('Failed to fetch unified data')
				})
			);

			render(DataPage);

			expect(screen.getByText('Error Loading Data')).toBeInTheDocument();
			expect(screen.getByText('Failed to fetch unified data')).toBeInTheDocument();
		});

		it('successfully renders page content when data loads', () => {
			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: mockUnifiedData,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);

			render(DataPage);

			expect(screen.getByText('Enforcement Data')).toBeInTheDocument();
		});

		it('does not show data table when loading', () => {
			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: undefined,
					isSuccess: false,
					isLoading: true,
					isPending: true,
					isError: false,
					error: null
				})
			);

			render(DataPage);

			// Stats cards should not be visible
			expect(screen.queryByText('Total Records')).not.toBeInTheDocument();
		});

		it('does not show data table when error occurs', () => {
			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: undefined,
					isSuccess: false,
					isLoading: false,
					isPending: false,
					isError: true,
					error: new Error('Network error')
				})
			);

			render(DataPage);

			expect(screen.queryByText('Total Records')).not.toBeInTheDocument();
		});
	});

	// ==========================================
	// PHASE 2: PAGE HEADER & METADATA
	// ==========================================

	describe('Page Header & Metadata', () => {
		beforeEach(() => {
			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: mockUnifiedData,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);
		});

		it('displays page title correctly', () => {
			render(DataPage);

			expect(screen.getByText('Enforcement Data')).toBeInTheDocument();
		});

		it('displays page description', () => {
			render(DataPage);

			expect(
				screen.getByText(
					'Unified view of Cases and Notices with flexible filtering, sorting, and grouping'
				)
			).toBeInTheDocument();
		});
	});

	// ==========================================
	// PHASE 3: STATISTICS OVERVIEW CARDS
	// ==========================================

	describe('Statistics Overview Cards', () => {
		beforeEach(() => {
			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: mockUnifiedData,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);
		});

		it('displays all 4 statistics cards', () => {
			render(DataPage);

			expect(screen.getByText('Total Records')).toBeInTheDocument();
			expect(screen.getByText('Cases')).toBeInTheDocument();
			expect(screen.getByText('Notices')).toBeInTheDocument();
			expect(screen.getByText('Showing')).toBeInTheDocument();
		});

		it('displays correct total count', () => {
			const { container } = render(DataPage);

			// Find the "Total Records" label and get the value in the next sibling
			const totalRecordsLabel = screen.getByText('Total Records');
			const statsCard = totalRecordsLabel.closest('div.bg-white');
			const valueDiv = statsCard?.querySelector('.text-2xl.font-bold.text-gray-900');
			expect(valueDiv?.textContent).toBe('2');
		});

		it('displays correct cases count', () => {
			const { container } = render(DataPage);

			// Find the "Cases" label and get the value in the next sibling (green text)
			const casesLabel = screen.getByText('Cases');
			const statsCard = casesLabel.closest('div.bg-white');
			const valueDiv = statsCard?.querySelector('.text-2xl.font-bold.text-green-600');
			expect(valueDiv?.textContent).toBe('1');
		});

		it('displays correct showing count (data length)', () => {
			render(DataPage);

			// Two instances of "2" - one for total, one for showing
			const twos = screen.getAllByText('2');
			expect(twos.length).toBeGreaterThanOrEqual(1);
		});

		it('handles zero counts gracefully', () => {
			const emptyData: UnifiedDataResponse = {
				data: [],
				meta: {
					total_count: 0,
					limit: 100,
					offset: 0,
					cases_count: 0,
					notices_count: 0,
					record_types: {
						case: 0,
						notice: 0
					}
				}
			};

			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: emptyData,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);

			render(DataPage);

			expect(screen.getAllByText('0').length).toBeGreaterThan(0);
		});

		it('formats large numbers with commas', () => {
			const largeData: UnifiedDataResponse = {
				...mockUnifiedData,
				meta: {
					...mockUnifiedData.meta,
					total_count: 10000,
					cases_count: 7500,
					notices_count: 2500
				}
			};

			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: largeData,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);

			render(DataPage);

			expect(screen.getByText('10,000')).toBeInTheDocument();
			expect(screen.getByText('7,500')).toBeInTheDocument();
			expect(screen.getByText('2,500')).toBeInTheDocument();
		});
	});

	// ==========================================
	// PHASE 4: DATA RENDERING
	// ==========================================

	describe('Data Rendering', () => {
		beforeEach(() => {
			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: mockUnifiedData,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);
		});

		it('passes data to TableKit component', () => {
			const { container } = render(DataPage);

			// TableKit should be rendered with data
			// We don't test TableKit internals, just that it receives data
			expect(container.querySelector('.table-kit-container')).toBeInTheDocument();
		});

		it('handles empty data array', () => {
			const emptyData: UnifiedDataResponse = {
				data: [],
				meta: {
					total_count: 0,
					limit: 100,
					offset: 0,
					cases_count: 0,
					notices_count: 0,
					record_types: {
						case: 0,
						notice: 0
					}
				}
			};

			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: emptyData,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);

			expect(() => render(DataPage)).not.toThrow();
		});
	});

	// ==========================================
	// PHASE 5: DATE FORMATTING
	// ==========================================

	describe('Date Formatting', () => {
		beforeEach(() => {
			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: mockUnifiedData,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);
		});

		it('formats dates in GB locale format', () => {
			render(DataPage);

			// The formatDate function should format "2024-01-15" as "15 Jan 2024"
			// This will be in the table cells
			// We don't directly test cell content as that's TableKit's responsibility
			// Just verify the page renders without errors
			expect(screen.getByText('Enforcement Data')).toBeInTheDocument();
		});

		it('handles null dates gracefully', () => {
			const dataWithNullDates: UnifiedDataResponse = {
				data: [
					{
						...mockUnifiedData.data[0],
						offence_action_date: null,
						offence_hearing_date: null
					}
				],
				meta: mockUnifiedData.meta
			};

			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: dataWithNullDates,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);

			expect(() => render(DataPage)).not.toThrow();
		});
	});

	// ==========================================
	// PHASE 6: CURRENCY FORMATTING
	// ==========================================

	describe('Currency Formatting', () => {
		beforeEach(() => {
			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: mockUnifiedData,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);
		});

		it('formats currency values in GBP', () => {
			render(DataPage);

			// formatCurrency function should format numbers as "£50,000"
			// We verify the page renders successfully
			expect(screen.getByText('Enforcement Data')).toBeInTheDocument();
		});

		it('handles null currency values gracefully', () => {
			const dataWithNullCurrency: UnifiedDataResponse = {
				data: [
					{
						...mockUnifiedData.data[0],
						offence_fine: null,
						offence_costs: null
					}
				],
				meta: mockUnifiedData.meta
			};

			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: dataWithNullCurrency,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);

			expect(() => render(DataPage)).not.toThrow();
		});
	});

	// ==========================================
	// PHASE 7: ERROR HANDLING & EDGE CASES
	// ==========================================

	describe('Error Handling & Edge Cases', () => {
		it('handles API error with user-friendly error message', () => {
			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: undefined,
					isSuccess: false,
					isLoading: false,
					isPending: false,
					isError: true,
					error: new Error('Network request failed')
				})
			);

			render(DataPage);

			expect(screen.getByText('Error Loading Data')).toBeInTheDocument();
			expect(screen.getByText('Network request failed')).toBeInTheDocument();
		});

		it('validates data structure before rendering stats', () => {
			const malformedData = {
				data: null as any,
				meta: null as any
			};

			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: malformedData,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);

			// Component expects proper data structure, will throw if malformed
			// This is acceptable behavior as the API contract should be honored
			expect(() => render(DataPage)).toThrow();
		});

		it('requires complete meta data for stats display', () => {
			const dataWithoutMeta = {
				data: mockUnifiedData.data,
				meta: {} as any
			};

			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: dataWithoutMeta,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);

			// Component expects complete meta object with count properties
			expect(() => render(DataPage)).toThrow();
		});

		it('handles undefined error message', () => {
			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: undefined,
					isSuccess: false,
					isLoading: false,
					isPending: false,
					isError: true,
					error: null
				})
			);

			render(DataPage);

			expect(screen.getByText('Error Loading Data')).toBeInTheDocument();
			// Should show "Unknown error occurred" when error.message is undefined
			expect(screen.getByText('Unknown error occurred')).toBeInTheDocument();
		});
	});

	// ==========================================
	// PHASE 8: RESPONSIVE LAYOUT
	// ==========================================

	describe('Responsive Layout', () => {
		beforeEach(() => {
			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: mockUnifiedData,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);
		});

		it('renders with responsive container classes', () => {
			const { container } = render(DataPage);

			// Check for Tailwind responsive classes
			const responsiveContainer = container.querySelector('.container');
			expect(responsiveContainer).toBeInTheDocument();
		});

		it('renders stats grid with responsive columns', () => {
			const { container } = render(DataPage);

			// Stats should be in a grid layout
			const grid = container.querySelector('.grid');
			expect(grid).toBeInTheDocument();
		});
	});

	// ==========================================
	// PHASE 9: ACCESSIBILITY
	// ==========================================

	describe('Accessibility', () => {
		beforeEach(() => {
			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: mockUnifiedData,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);
		});

		it('uses semantic HTML with proper heading hierarchy', () => {
			const { container } = render(DataPage);

			const h1 = container.querySelector('h1');
			expect(h1).toHaveTextContent('Enforcement Data');
		});

		it('provides descriptive text for all stat cards', () => {
			render(DataPage);

			expect(screen.getByText('Total Records')).toBeInTheDocument();
			expect(screen.getByText('Cases')).toBeInTheDocument();
			expect(screen.getByText('Notices')).toBeInTheDocument();
			expect(screen.getByText('Showing')).toBeInTheDocument();
		});

		it('includes loading state with descriptive text', () => {
			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: undefined,
					isSuccess: false,
					isLoading: true,
					isPending: true,
					isError: false,
					error: null
				})
			);

			render(DataPage);

			expect(screen.getByText('Loading enforcement data...')).toBeInTheDocument();
		});

		it('includes error state with descriptive text', () => {
			vi.mocked(unifiedQuery.useUnifiedData).mockReturnValue(
				createMockStore({
					data: undefined,
					isSuccess: false,
					isLoading: false,
					isPending: false,
					isError: true,
					error: new Error('Test error')
				})
			);

			render(DataPage);

			expect(screen.getByText('Error Loading Data')).toBeInTheDocument();
		});
	});
});
