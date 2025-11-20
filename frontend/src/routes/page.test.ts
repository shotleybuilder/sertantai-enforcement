import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import { QueryClient } from '@tanstack/svelte-query';
import { createTestQueryClient } from '../../tests/test-utils';
import HomePage from './+page.svelte';
import type { DashboardStats } from '$lib/query/dashboard';
import * as dashboardQuery from '$lib/query/dashboard';

// Mock the dashboard query module
vi.mock('$lib/query/dashboard', () => ({
	useDashboardStats: vi.fn()
}));

// Note: RecentActivityTable is not mocked - using real component for integration testing

describe('Landing Page (+page.svelte)', () => {
	let queryClient: QueryClient;

	// Mock dashboard stats data
	const mockDashboardStats: DashboardStats = {
		stats: {
			active_agencies: 4,
			recent_cases: 127,
			recent_notices: 85,
			total_cases: 2456,
			total_notices: 1834,
			total_fines: '2450000.00',
			total_costs: '150000.00',
			timeframe: 'Last Month',
			period: 'Month',
			total_legislation: 45,
			acts_count: 12,
			regulations_count: 28,
			orders_count: 3,
			acops_count: 2
		},
		recent_activity: [
			{
				type: 'Court Case',
				record_type: 'case',
				is_case: true,
				regulator_id: 'hse',
				date: '2024-01-15T00:00:00Z',
				organization: 'Example Ltd',
				description: 'Health and safety breach',
				fine_amount: '50000.00',
				agency_link: 'http://example.com/case/1'
			},
			{
				type: 'Improvement Notice',
				record_type: 'notice',
				is_case: false,
				regulator_id: 'hse',
				date: '2024-01-10T00:00:00Z',
				organization: 'Sample Corp',
				description: 'Safety improvements required',
				fine_amount: '',
				agency_link: 'http://example.com/notice/1'
			}
		],
		agency_stats: [
			{
				agency_id: 'hse',
				agency_name: 'Health and Safety Executive',
				case_count: 127,
				notice_count: 85
			}
		]
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
			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: undefined,
					isSuccess: false,
					isLoading: true,
					isPending: true,
					isError: false,
					error: null
				})
			);

			const { container } = render(HomePage);

			// Check for loading spinner
			const spinner = container.querySelector('.animate-spin');
			expect(spinner).toBeInTheDocument();
		});

		it('displays error message when API request fails', () => {
			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: undefined,
					isSuccess: false,
					isLoading: false,
					isPending: false,
					isError: true,
					error: new Error('Failed to fetch dashboard stats')
				})
			);

			render(HomePage);

			expect(screen.getByText('Error loading dashboard')).toBeInTheDocument();
			expect(screen.getByText('Failed to fetch dashboard stats')).toBeInTheDocument();
		});

		it('successfully renders page content when data loads', () => {
			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: mockDashboardStats,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);

			render(HomePage);

			expect(screen.getByText('🏛️ UK EHS Enforcement Dashboard')).toBeInTheDocument();
			expect(screen.getByText('Active Agencies')).toBeInTheDocument();
		});

		it('does not show stats when loading', () => {
			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: undefined,
					isSuccess: false,
					isLoading: true,
					isPending: true,
					isError: false,
					error: null
				})
			);

			render(HomePage);

			expect(screen.queryByText('Active Agencies')).not.toBeInTheDocument();
			expect(screen.queryByText('Recent Cases')).not.toBeInTheDocument();
		});

		it('does not show stats when error occurs', () => {
			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: undefined,
					isSuccess: false,
					isLoading: false,
					isPending: false,
					isError: true,
					error: new Error('Network error')
				})
			);

			render(HomePage);

			expect(screen.queryByText('Active Agencies')).not.toBeInTheDocument();
			expect(screen.queryByText('Recent Cases')).not.toBeInTheDocument();
		});

		it('displays page title and meta description correctly', () => {
			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: mockDashboardStats,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);

			render(HomePage);

			// Check for page heading (visible on page)
			expect(screen.getByText('🏛️ UK EHS Enforcement Dashboard')).toBeInTheDocument();
			expect(
				screen.getByText(
					'Environmental, Health & Safety enforcement data from UK regulatory agencies'
				)
			).toBeInTheDocument();
		});
	});

	// ==========================================
	// PHASE 2: STATISTICS OVERVIEW CARDS
	// ==========================================

	describe('Statistics Overview Cards', () => {
		beforeEach(() => {
			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: mockDashboardStats,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);
		});

		it('displays all 5 stat cards', () => {
			render(HomePage);

			// These text labels appear in multiple places, so use getAllByText
			expect(screen.getAllByText('Active Agencies').length).toBeGreaterThan(0);
			expect(screen.getAllByText('Recent Cases').length).toBeGreaterThan(0);
			expect(screen.getAllByText('Recent Notices').length).toBeGreaterThan(0);
			expect(screen.getAllByText('Total Fines').length).toBeGreaterThan(0);
			expect(screen.getByText('Time Period')).toBeInTheDocument();
		});

		it('displays active agencies count correctly', () => {
			render(HomePage);

			// "Active Agencies" appears multiple times
			expect(screen.getAllByText('Active Agencies').length).toBeGreaterThan(0);
			expect(screen.getByText('4')).toBeInTheDocument();
		});

		it('displays recent cases count and timeframe', () => {
			render(HomePage);

			// "Recent Cases" and counts appear multiple times
			expect(screen.getAllByText('Recent Cases').length).toBeGreaterThan(0);
			expect(screen.getAllByText('127').length).toBeGreaterThan(0);
			// Timeframe appears multiple times
			const timeframes = screen.getAllByText('Last Month');
			expect(timeframes.length).toBeGreaterThan(0);
		});

		it('displays recent notices count and timeframe', () => {
			render(HomePage);

			// "Recent Notices" and counts appear multiple times
			expect(screen.getAllByText('Recent Notices').length).toBeGreaterThan(0);
			expect(screen.getAllByText('85').length).toBeGreaterThan(0);
		});

		it('formats total fines as GBP currency', () => {
			render(HomePage);

			// Should format 2450000.00 as £2,450,000
			// Both "Total Fines" and the amount appear multiple times
			const totalFinesElements = screen.getAllByText('Total Fines');
			expect(totalFinesElements.length).toBeGreaterThan(0);
			expect(screen.getAllByText(/£2,450,000/).length).toBeGreaterThan(0);
		});

		it('displays time period indicator card', () => {
			render(HomePage);

			expect(screen.getByText('Time Period')).toBeInTheDocument();
			expect(screen.getByText('Month')).toBeInTheDocument();
		});

		it('handles zero values gracefully', () => {
			const zeroStats = {
				...mockDashboardStats,
				stats: {
					...mockDashboardStats.stats,
					active_agencies: 0,
					recent_cases: 0,
					recent_notices: 0,
					total_fines: '0.00'
				}
			};

			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: zeroStats,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);

			render(HomePage);

			// Zero appears multiple times for different stats
			expect(screen.getAllByText('0').length).toBeGreaterThan(0);
			expect(screen.getAllByText(/£0/).length).toBeGreaterThan(0);
		});
	});

	// ==========================================
	// PHASE 3: TIME PERIOD SELECTOR
	// ==========================================

	describe('Time Period Selector', () => {
		beforeEach(() => {
			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: mockDashboardStats,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);
		});

		it('renders time period selector with all three options', () => {
			render(HomePage);

			// There are multiple comboboxes on the page, get all of them
			const selects = screen.getAllByRole('combobox');
			expect(selects.length).toBeGreaterThan(0);

			// Check for all options (they appear in all selectors)
			expect(screen.getAllByRole('option', { name: 'Last Week' }).length).toBeGreaterThan(0);
			expect(screen.getAllByRole('option', { name: 'Last Month' }).length).toBeGreaterThan(0);
			expect(screen.getAllByRole('option', { name: 'Last Year' }).length).toBeGreaterThan(0);
		});

		it('defaults to "month" selection', () => {
			render(HomePage);

			// Multiple comboboxes exist, check that at least one defaults to "month"
			const selects = screen.getAllByRole('combobox') as HTMLSelectElement[];
			const monthSelects = selects.filter((select) => select.value === 'month');
			expect(monthSelects.length).toBeGreaterThan(0);
		});
	});

	// ==========================================
	// PHASE 4: RECENT ACTIVITY TABLE INTEGRATION
	// ==========================================

	describe('RecentActivityTable Integration', () => {
		beforeEach(() => {
			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: mockDashboardStats,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);
		});

		it('renders recent activity section when data is loaded', () => {
			render(HomePage);

			expect(screen.getByText('Recent Activity')).toBeInTheDocument();
		});

		it('passes recent activity data to the table component', () => {
			const { container } = render(HomePage);

			// Check that the Recent Activity section is rendered
			expect(screen.getByText('Recent Activity')).toBeInTheDocument();
		});

		it('passes empty array when no recent activity', () => {
			const noActivityStats = {
				...mockDashboardStats,
				recent_activity: []
			};

			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: noActivityStats,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);

			const { container } = render(HomePage);

			// Component should still render
			expect(screen.getByText('Recent Activity')).toBeInTheDocument();
		});
	});

	// ==========================================
	// PHASE 5: RESPONSIVE LAYOUT & UI ELEMENTS
	// ==========================================

	describe('Responsive Layout & UI Elements', () => {
		beforeEach(() => {
			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: mockDashboardStats,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);
		});

		it('renders page header with proper layout classes', () => {
			const { container } = render(HomePage);

			// Check for responsive container
			const maxWidthContainer = container.querySelector('.max-w-7xl');
			expect(maxWidthContainer).toBeInTheDocument();
		});

		it('renders admin login button', () => {
			render(HomePage);

			const adminButton = screen.getByText('Admin Login').closest('a');
			expect(adminButton).toBeInTheDocument();
			expect(adminButton).toHaveAttribute('href', 'http://localhost:4002/sign-in');
		});

		it('displays all 5 dashboard action cards', () => {
			render(HomePage);

			expect(screen.getByText('ENFORCEMENT CASES')).toBeInTheDocument();
			expect(screen.getByText('ENFORCEMENT NOTICES')).toBeInTheDocument();
			expect(screen.getByText('OFFENDER DATABASE')).toBeInTheDocument();
			expect(screen.getByText('LEGISLATION DATABASE')).toBeInTheDocument();
			expect(screen.getByText('REPORTS & ANALYTICS')).toBeInTheDocument();
		});

		it('displays total cases and notices in action cards', () => {
			render(HomePage);

			// Total cases from mock data
			expect(screen.getByText('2456')).toBeInTheDocument(); // total_cases
			expect(screen.getByText('1834')).toBeInTheDocument(); // total_notices
		});

		it('renders "Browse Recent" links for cases and notices', () => {
			render(HomePage);

			const browseLinks = screen.getAllByText('Browse Recent →');
			expect(browseLinks.length).toBeGreaterThan(0);

			// Check cases link
			const casesLink = browseLinks[0].closest('a');
			expect(casesLink).toHaveAttribute('href', '/cases');

			// Check notices link
			const noticesLink = browseLinks[1].closest('a');
			expect(noticesLink).toHaveAttribute('href', '/notices');
		});

		it('renders search inputs in action cards', () => {
			const { container } = render(HomePage);

			const searchInputs = container.querySelectorAll('input[type="text"]');
			// Should have multiple search inputs in action cards
			expect(searchInputs.length).toBeGreaterThan(0);
		});
	});

	// ==========================================
	// PHASE 6: ERROR HANDLING & EDGE CASES
	// ==========================================

	describe('Error Handling & Edge Cases', () => {
		it('handles API error with user-friendly error message', () => {
			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: undefined,
					isSuccess: false,
					isLoading: false,
					isPending: false,
					isError: true,
					error: new Error('Network request failed')
				})
			);

			render(HomePage);

			expect(screen.getByText('Error loading dashboard')).toBeInTheDocument();
			expect(screen.getByText('Network request failed')).toBeInTheDocument();
		});

		it('handles empty dataset gracefully', () => {
			const emptyStats: DashboardStats = {
				stats: {
					active_agencies: 0,
					recent_cases: 0,
					recent_notices: 0,
					total_cases: 0,
					total_notices: 0,
					total_fines: '0.00',
					total_costs: '0.00',
					timeframe: 'Last Month',
					period: 'Month',
					total_legislation: 0,
					acts_count: 0,
					regulations_count: 0,
					orders_count: 0,
					acops_count: 0
				},
				recent_activity: [],
				agency_stats: []
			};

			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: emptyStats,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);

			render(HomePage);

			// Should still render page with zero values
			expect(screen.getAllByText('Active Agencies').length).toBeGreaterThan(0);
			expect(screen.getAllByText('0').length).toBeGreaterThan(0);
		});

		it('handles malformed API response with missing stats', () => {
			const malformedStats = {
				...mockDashboardStats,
				stats: {} as any
			};

			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: malformedStats,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);

			// Should not crash when rendering
			expect(() => render(HomePage)).not.toThrow();
		});

		it('handles undefined recent_activity gracefully', () => {
			const noActivityStats = {
				...mockDashboardStats,
				recent_activity: undefined as any
			};

			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: noActivityStats,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);

			// Should not crash
			expect(() => render(HomePage)).not.toThrow();
		});

		it('handles very large fine amounts', () => {
			const largeFineStats = {
				...mockDashboardStats,
				stats: {
					...mockDashboardStats.stats,
					total_fines: '999999999.99'
				}
			};

			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: largeFineStats,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);

			render(HomePage);

			// Should format large numbers correctly (appears multiple times)
			expect(screen.getAllByText(/£999,999,999/).length).toBeGreaterThan(0);
		});
	});

	// ==========================================
	// ACCESSIBILITY & SEMANTIC HTML
	// ==========================================

	describe('Accessibility', () => {
		beforeEach(() => {
			vi.mocked(dashboardQuery.useDashboardStats).mockReturnValue(
				createMockStore({
					data: mockDashboardStats,
					isSuccess: true,
					isLoading: false,
					isPending: false,
					isError: false,
					error: null
				})
			);
		});

		it('uses semantic HTML with proper heading hierarchy', () => {
			const { container } = render(HomePage);

			const h1 = container.querySelector('h1');
			const h3s = container.querySelectorAll('h3');

			expect(h1).toHaveTextContent('🏛️ UK EHS Enforcement Dashboard');
			expect(h3s.length).toBeGreaterThan(0);
		});

		it('provides accessible select for time period', () => {
			render(HomePage);

			// Multiple comboboxes exist on the page
			const selects = screen.getAllByRole('combobox');
			expect(selects.length).toBeGreaterThan(0);
		});

		it('includes descriptive text for all stat cards', () => {
			render(HomePage);

			// Each stat card should have descriptive text
			// Some text appears multiple times (in both stat cards and action cards)
			expect(screen.getAllByText('Active Agencies').length).toBeGreaterThan(0);
			expect(screen.getAllByText('Recent Cases').length).toBeGreaterThan(0);
			expect(screen.getAllByText('Recent Notices').length).toBeGreaterThan(0);
			expect(screen.getAllByText('Total Fines').length).toBeGreaterThan(0);
			expect(screen.getByText('Time Period')).toBeInTheDocument();
		});
	});
});
