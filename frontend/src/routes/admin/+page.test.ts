import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import { QueryClient } from '@tanstack/svelte-query';
import { createTestQueryClient } from '../../../tests/test-utils';
import AdminPage from './+page.svelte';
import type { AdminStats } from '$lib/query/admin';
import * as adminQuery from '$lib/query/admin';

// Mock the admin query module
vi.mock('$lib/query/admin', () => ({
	useAdminStats: vi.fn()
}));

describe('Admin Dashboard (+page.svelte)', () => {
	let queryClient: QueryClient;

	// Mock data matching the component's expected structure
	const mockAdminStats: AdminStats = {
		stats: {
			data_quality_score: 95,
			active_agencies: 3,
			recent_cases: 127,
			recent_notices: 85,
			total_fines: '2450000.00',
			sync_errors: 0,
			timeframe: 'Last Month'
		},
		agencies: [
			{
				id: '1',
				code: 'hse',
				name: 'Health and Safety Executive',
				enabled: true
			},
			{
				id: '2',
				code: 'ea',
				name: 'Environment Agency',
				enabled: true
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

	describe('Page Rendering', () => {
		it('renders the admin dashboard heading', () => {
			vi.mocked(adminQuery.useAdminStats).mockReturnValue(
				createMockStore({
					data: mockAdminStats,
					isSuccess: true,
					isPending: false,
					isError: false,
					error: null
				})
			);

			render(AdminPage);

			expect(screen.getByText('🔧 Admin Dashboard')).toBeInTheDocument();
			expect(screen.getByText('Administrative tools and system management')).toBeInTheDocument();
		});

		it('displays ADMIN indicator badge', () => {
			vi.mocked(adminQuery.useAdminStats).mockReturnValue(createMockStore({
				data: mockAdminStats,
				isSuccess: true,
				isPending: false,
				isError: false,
				error: null
			}));

			render(AdminPage);

			expect(screen.getByText('ADMIN')).toBeInTheDocument();
			expect(screen.getByText('← Main Dashboard')).toBeInTheDocument();
		});

		it('renders time period selector with default "month" selected', () => {
			vi.mocked(adminQuery.useAdminStats).mockReturnValue(createMockStore({
				data: mockAdminStats,
				isSuccess: true,
				isPending: false,
				isError: false,
				error: null
			}));

			render(AdminPage);

			const select = screen.getByRole('combobox');
			expect(select).toHaveValue('month');
			// Check for options within the select
			expect(screen.getByRole('option', { name: 'Last Week' })).toBeInTheDocument();
			expect(screen.getByRole('option', { name: 'Last Month' })).toBeInTheDocument();
			expect(screen.getByRole('option', { name: 'Last Year' })).toBeInTheDocument();
		});
	});

	describe('Loading State', () => {
		it('shows loading spinner when data is pending', () => {
			vi.mocked(adminQuery.useAdminStats).mockReturnValue(createMockStore({
				data: undefined,
				isSuccess: false,
				isPending: true,
				isError: false,
				error: null
			}));

			const { container } = render(AdminPage);

			// Check for loading spinner
			const spinner = container.querySelector('.animate-spin');
			expect(spinner).toBeInTheDocument();
		});

		it('does not show stats when loading', () => {
			vi.mocked(adminQuery.useAdminStats).mockReturnValue(createMockStore({
				data: undefined,
				isSuccess: false,
				isPending: true,
				isError: false,
				error: null
			}));

			render(AdminPage);

			expect(screen.queryByText('Data Quality')).not.toBeInTheDocument();
			expect(screen.queryByText('Active Agencies')).not.toBeInTheDocument();
		});
	});

	describe('Error State', () => {
		it('shows error message when query fails', () => {
			vi.mocked(adminQuery.useAdminStats).mockReturnValue(createMockStore({
				data: undefined,
				isSuccess: false,
				isPending: false,
				isError: true,
				error: new Error('Failed to fetch admin stats')
			}));

			render(AdminPage);

			expect(screen.getByText('Error loading admin statistics')).toBeInTheDocument();
			expect(screen.getByText('Failed to fetch admin stats')).toBeInTheDocument();
		});

		it('does not show stats when error occurs', () => {
			vi.mocked(adminQuery.useAdminStats).mockReturnValue(createMockStore({
				data: undefined,
				isSuccess: false,
				isPending: false,
				isError: true,
				error: new Error('Network error')
			}));

			render(AdminPage);

			expect(screen.queryByText('Data Quality')).not.toBeInTheDocument();
		});
	});

	describe('Success State - Statistics Display', () => {
		beforeEach(() => {
			vi.mocked(adminQuery.useAdminStats).mockReturnValue(createMockStore({
				data: mockAdminStats,
				isSuccess: true,
				isPending: false,
				isError: false,
				error: null
			}));
		});

		it('displays all 6 stat cards', () => {
			render(AdminPage);

			expect(screen.getByText('Data Quality')).toBeInTheDocument();
			expect(screen.getByText('Active Agencies')).toBeInTheDocument();
			expect(screen.getByText('Recent Cases')).toBeInTheDocument();
			expect(screen.getByText('Recent Notices')).toBeInTheDocument();
			expect(screen.getByText('Recent Fines')).toBeInTheDocument();
			expect(screen.getByText('Sync Status')).toBeInTheDocument();
		});

		it('displays data quality score', () => {
			render(AdminPage);

			expect(screen.getByText('95%')).toBeInTheDocument();
		});

		it('displays active agencies count', () => {
			render(AdminPage);

			expect(screen.getByText('3 Agencies')).toBeInTheDocument();
		});

		it('displays recent cases count', () => {
			render(AdminPage);

			expect(screen.getByText('127 Cases')).toBeInTheDocument();
		});

		it('displays recent notices count', () => {
			render(AdminPage);

			expect(screen.getByText('85 Notices')).toBeInTheDocument();
		});

		it('formats total fines as GBP currency', () => {
			render(AdminPage);

			// Should format 2450000.00 as £2,450,000
			expect(screen.getByText(/£2,450,000/)).toBeInTheDocument();
		});

		it('shows "Healthy" sync status when no errors', () => {
			render(AdminPage);

			expect(screen.getByText('Healthy')).toBeInTheDocument();
		});

		it('shows error count when sync has errors', () => {
			vi.mocked(adminQuery.useAdminStats).mockReturnValue(createMockStore({
				data: {
					...mockAdminStats,
					stats: { ...mockAdminStats.stats, sync_errors: 3 }
				},
				isSuccess: true,
				isPending: false,
				isError: false,
				error: null
			}));

			render(AdminPage);

			expect(screen.getByText('3 Errors')).toBeInTheDocument();
		});

		it('displays timeframe for stats', () => {
			render(AdminPage);

			// Timeframe appears multiple times (for cases, notices, fines)
			const timeframes = screen.getAllByText('Last Month');
			expect(timeframes.length).toBeGreaterThan(0);
		});
	});

	describe('Agency Status Section', () => {
		beforeEach(() => {
			vi.mocked(adminQuery.useAdminStats).mockReturnValue(createMockStore({
				data: mockAdminStats,
				isSuccess: true,
				isPending: false,
				isError: false,
				error: null
			}));
		});

		it('renders agency status section when agencies exist', () => {
			render(AdminPage);

			expect(screen.getByText('Agency Status')).toBeInTheDocument();
			expect(screen.getByText('Current sync and data collection status')).toBeInTheDocument();
		});

		it('displays all agencies in the list', () => {
			render(AdminPage);

			expect(screen.getByText('Health and Safety Executive')).toBeInTheDocument();
			expect(screen.getByText('Environment Agency')).toBeInTheDocument();
			expect(screen.getByText('(hse)')).toBeInTheDocument();
			expect(screen.getByText('(ea)')).toBeInTheDocument();
		});

		it('shows active status for enabled agencies', () => {
			render(AdminPage);

			const activeStatuses = screen.getAllByText('Status: Active');
			expect(activeStatuses).toHaveLength(2);
		});

		it('shows idle state for agencies', () => {
			render(AdminPage);

			const idleStatuses = screen.getAllByText('Idle');
			expect(idleStatuses.length).toBeGreaterThan(0);
		});
	});

	describe('Action Cards', () => {
		beforeEach(() => {
			vi.mocked(adminQuery.useAdminStats).mockReturnValue(createMockStore({
				data: mockAdminStats,
				isSuccess: true,
				isPending: false,
				isError: false,
				error: null
			}));
		});

		it('displays all 6 action card sections', () => {
			render(AdminPage);

			expect(screen.getByText('Data Management')).toBeInTheDocument();
			expect(screen.getByText('System Operations')).toBeInTheDocument();
			expect(screen.getByText('Agency Management')).toBeInTheDocument();
			expect(screen.getByText('Case Management')).toBeInTheDocument();
			expect(screen.getByText('Notice Management')).toBeInTheDocument();
			expect(screen.getByText('Offender Management')).toBeInTheDocument();
		});

		it('renders scraping interface link', () => {
			render(AdminPage);

			const link = screen.getByText('Scraping Interface').closest('a');
			expect(link).toHaveAttribute('href', '/admin/scrape');
		});

		it('renders scrape sessions link', () => {
			render(AdminPage);

			const link = screen.getByText('View Sessions').closest('a');
			expect(link).toHaveAttribute('href', '/admin/scrape-sessions');
		});

		it('renders system config link', () => {
			render(AdminPage);

			const link = screen.getByText('System Config').closest('a');
			expect(link).toHaveAttribute('href', '/admin/config');
		});

		it('renders agency management links', () => {
			render(AdminPage);

			const manageLink = screen.getByText('Manage Agencies').closest('a');
			expect(manageLink).toHaveAttribute('href', '/admin/agencies');

			const newLink = screen.getByText('New Agency').closest('a');
			expect(newLink).toHaveAttribute('href', '/admin/agencies/new');
		});

		it('renders case management link', () => {
			render(AdminPage);

			const link = screen.getByText('Manage Cases').closest('a');
			expect(link).toHaveAttribute('href', 'http://localhost:4002/cases');
		});

		it('renders notice management link', () => {
			render(AdminPage);

			const link = screen.getByText('Manage Notices').closest('a');
			expect(link).toHaveAttribute('href', 'http://localhost:4002/notices');
		});

		it('renders offender management link', () => {
			render(AdminPage);

			const link = screen.getByText('Manage Offenders').closest('a');
			expect(link).toHaveAttribute('href', 'http://localhost:4002/offenders');
		});

		it('renders companies house match review link', () => {
			render(AdminPage);

			const link = screen.getByText(/Review Companies House Matches/).closest('a');
			expect(link).toHaveAttribute('href', '/admin/offenders/reviews');
		});
	});

	describe('Interactive Features', () => {
		beforeEach(() => {
			vi.mocked(adminQuery.useAdminStats).mockReturnValue(createMockStore({
				data: mockAdminStats,
				isSuccess: true,
				isPending: false,
				isError: false,
				error: null
			}));

			// Mock window.alert
			global.alert = vi.fn();
		});

		it('handles time period change', async () => {
			const mockUseAdminStats = vi.fn().mockReturnValue(
				createMockStore({
					data: mockAdminStats,
					isSuccess: true,
					isPending: false,
					isError: false,
					error: null
				})
			);
			vi.mocked(adminQuery.useAdminStats).mockImplementation(mockUseAdminStats);

			render(AdminPage);

			const select = screen.getByRole('combobox');
			await fireEvent.change(select, { target: { value: 'week' } });

			// Note: In actual implementation, this would trigger a new query
			// The test verifies the select can be changed
			expect(select).toHaveValue('week');
		});

		it('handles refresh metrics button click', async () => {
			render(AdminPage);

			const button = screen.getByText('Refresh Metrics');
			await fireEvent.click(button);

			expect(global.alert).toHaveBeenCalledWith(
				'Metrics refresh not yet implemented in Svelte'
			);
		});

		it('handles check duplicates for cases', async () => {
			render(AdminPage);

			// Find the "Check for Duplicates" button under Case Management
			const buttons = screen.getAllByText('Check for Duplicates');
			const casesButton = buttons[0]; // First one is for cases

			await fireEvent.click(casesButton);

			expect(global.alert).toHaveBeenCalledWith(
				'cases duplicate checking not yet implemented in Svelte'
			);
		});

		it('handles check duplicates for notices', async () => {
			render(AdminPage);

			const buttons = screen.getAllByText('Check for Duplicates');
			const noticesButton = buttons[1]; // Second one is for notices

			await fireEvent.click(noticesButton);

			expect(global.alert).toHaveBeenCalledWith(
				'notices duplicate checking not yet implemented in Svelte'
			);
		});

		it('handles check duplicates for offenders', async () => {
			render(AdminPage);

			const buttons = screen.getAllByText('Check for Duplicates');
			const offendersButton = buttons[2]; // Third one is for offenders

			await fireEvent.click(offendersButton);

			expect(global.alert).toHaveBeenCalledWith(
				'offenders duplicate checking not yet implemented in Svelte'
			);
		});

		it('handles export CSV button click', async () => {
			render(AdminPage);

			const button = screen.getByText('Export CSV');
			await fireEvent.click(button);

			expect(global.alert).toHaveBeenCalledWith('Export to CSV not yet implemented in Svelte');
		});

		it('handles export JSON button click', async () => {
			render(AdminPage);

			const button = screen.getByText('Export JSON');
			await fireEvent.click(button);

			expect(global.alert).toHaveBeenCalledWith('Export to JSON not yet implemented in Svelte');
		});

		it('handles export Excel button click', async () => {
			render(AdminPage);

			const button = screen.getByText('Export Excel');
			await fireEvent.click(button);

			expect(global.alert).toHaveBeenCalledWith('Export to XLSX not yet implemented in Svelte');
		});
	});

	describe('Reports & Export Section', () => {
		beforeEach(() => {
			vi.mocked(adminQuery.useAdminStats).mockReturnValue(createMockStore({
				data: mockAdminStats,
				isSuccess: true,
				isPending: false,
				isError: false,
				error: null
			}));
		});

		it('displays reports & export section', () => {
			render(AdminPage);

			expect(screen.getByText('Reports & Export')).toBeInTheDocument();
			expect(screen.getByText('Data export and analytics')).toBeInTheDocument();
		});

		it('shows all export format buttons', () => {
			render(AdminPage);

			expect(screen.getByText('Export CSV')).toBeInTheDocument();
			expect(screen.getByText('Export JSON')).toBeInTheDocument();
			expect(screen.getByText('Export Excel')).toBeInTheDocument();
		});
	});

	describe('Accessibility', () => {
		beforeEach(() => {
			vi.mocked(adminQuery.useAdminStats).mockReturnValue(createMockStore({
				data: mockAdminStats,
				isSuccess: true,
				isPending: false,
				isError: false,
				error: null
			}));
		});

		it('uses semantic HTML with proper headings hierarchy', () => {
			const { container } = render(AdminPage);

			const h2 = container.querySelector('h2');
			const h3s = container.querySelectorAll('h3');

			expect(h2).toHaveTextContent('🔧 Admin Dashboard');
			expect(h3s.length).toBeGreaterThan(0);
		});

		it('uses role="list" for agency status', () => {
			render(AdminPage);

			const list = screen.getByRole('list');
			expect(list).toBeInTheDocument();
		});

		it('provides accessible select for time period', () => {
			render(AdminPage);

			const select = screen.getByRole('combobox');
			expect(select).toBeInTheDocument();
		});
	});
});
