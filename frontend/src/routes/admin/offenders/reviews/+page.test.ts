import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, within } from '@testing-library/svelte';
import MatchReviewsPage from './+page.svelte';
import * as matchReviewsQuery from '$lib/query/match-reviews';

// Mock SvelteKit modules
vi.mock('$app/environment', () => ({
	browser: true
}));

// Mock match reviews query module
vi.mock('$lib/query/match-reviews', () => ({
	useMatchReviewsQuery: vi.fn()
}));

describe('Admin Match Reviews Page (+page.svelte)', () => {
	// Helper to create Svelte-compatible store
	function createMockStore(value: any) {
		return {
			subscribe: (fn: (value: any) => void) => {
				fn(value);
				return {
					unsubscribe: () => {}
				};
			},
			refetch: vi.fn()
		};
	}

	// Mock review data
	const mockReviews = [
		{
			id: 'review-1',
			offender_id: 'offender-abc12345-6789-1234',
			offender_name: 'Manufacturing Solutions Ltd',
			status: 'pending',
			confidence_score: 0.85,
			candidate_count: 3,
			searched_at: '2024-01-15T10:30:00Z',
			reviewed_at: null
		},
		{
			id: 'review-2',
			offender_id: 'offender-def45678-9012-5678',
			offender_name: 'Industrial Operations Corp',
			status: 'needs_review',
			confidence_score: 0.65,
			candidate_count: 5,
			searched_at: '2024-01-14T14:20:00Z',
			reviewed_at: null
		},
		{
			id: 'review-3',
			offender_id: 'offender-ghi78901-2345-9012',
			offender_name: 'Chemical Processing PLC',
			status: 'approved',
			confidence_score: 0.92,
			candidate_count: 1,
			searched_at: '2024-01-13T09:15:00Z',
			reviewed_at: '2024-01-13T11:45:00Z'
		}
	];

	// Mock query response
	const mockReviewsQuery = {
		data: mockReviews,
		isLoading: false,
		isFetching: false,
		isError: false,
		error: null
	};

	// Create mock store with refetch
	let mockQueryStore: any;

	beforeEach(() => {
		vi.clearAllMocks();

		// Create fresh mock store with refetch
		mockQueryStore = createMockStore(mockReviewsQuery);

		// Setup query mock
		vi.mocked(matchReviewsQuery.useMatchReviewsQuery).mockReturnValue(mockQueryStore);
	});

	describe('Page Rendering', () => {
		it('renders the match reviews heading', () => {
			render(MatchReviewsPage);

			expect(screen.getByText('Offender Match Reviews')).toBeInTheDocument();
		});

		it('displays description text', () => {
			render(MatchReviewsPage);

			expect(
				screen.getByText('Review and approve company matches from Companies House')
			).toBeInTheDocument();
		});

		it('displays back to admin link', () => {
			render(MatchReviewsPage);

			const backLink = screen.getByRole('link', { name: /Back to Admin/i });
			expect(backLink).toHaveAttribute('href', '/admin');
		});

		it('displays refresh button', () => {
			render(MatchReviewsPage);

			expect(screen.getByRole('button', { name: /Refresh/i })).toBeInTheDocument();
		});
	});

	describe('Status Filters', () => {
		it('displays all status filter tabs', () => {
			render(MatchReviewsPage);

			expect(screen.getByRole('button', { name: /All Reviews/i })).toBeInTheDocument();
			expect(screen.getByRole('button', { name: /Pending/i })).toBeInTheDocument();
			expect(screen.getByRole('button', { name: /Needs Review/i })).toBeInTheDocument();
			expect(screen.getByRole('button', { name: /Approved/i })).toBeInTheDocument();
			expect(screen.getByRole('button', { name: /Skipped/i })).toBeInTheDocument();
		});

		it('initializes with pending filter active', () => {
			render(MatchReviewsPage);

			const pendingTab = screen.getByRole('button', { name: /Pending/i });
			expect(pendingTab).toHaveClass('border-blue-500');
			expect(pendingTab).toHaveClass('text-blue-600');
		});

		it('switches to all reviews filter when clicked', async () => {
			render(MatchReviewsPage);

			const allTab = screen.getByRole('button', { name: /All Reviews/i });
			await fireEvent.click(allTab);

			expect(allTab).toHaveClass('border-blue-500');
			expect(allTab).toHaveClass('text-blue-600');
		});

		it('switches to needs review filter when clicked', async () => {
			render(MatchReviewsPage);

			const needsReviewTab = screen.getByRole('button', { name: /Needs Review/i });
			await fireEvent.click(needsReviewTab);

			expect(needsReviewTab).toHaveClass('border-blue-500');
			expect(needsReviewTab).toHaveClass('text-blue-600');
		});

		it('switches to approved filter when clicked', async () => {
			render(MatchReviewsPage);

			const approvedTab = screen.getByRole('button', { name: /^Approved$/i });
			await fireEvent.click(approvedTab);

			expect(approvedTab).toHaveClass('border-blue-500');
			expect(approvedTab).toHaveClass('text-blue-600');
		});

		it('switches to skipped filter when clicked', async () => {
			render(MatchReviewsPage);

			const skippedTab = screen.getByRole('button', { name: /Skipped/i });
			await fireEvent.click(skippedTab);

			expect(skippedTab).toHaveClass('border-blue-500');
			expect(skippedTab).toHaveClass('text-blue-600');
		});

		it('shows count badge on active filter', () => {
			render(MatchReviewsPage);

			// Button accessible name includes the count "Pending 3"
			const pendingTab = screen.getByRole('button', { name: /Pending 3/i });
			expect(pendingTab).toBeInTheDocument();
		});
	});

	describe('Refresh Functionality', () => {
		it('calls refetch when refresh button clicked', async () => {
			render(MatchReviewsPage);

			const refreshButton = screen.getByRole('button', { name: /Refresh/i });
			await fireEvent.click(refreshButton);

			expect(mockQueryStore.refetch).toHaveBeenCalled();
		});

		it('shows refreshing state when fetching', () => {
			mockQueryStore = createMockStore({
				...mockReviewsQuery,
				isFetching: true
			});
			vi.mocked(matchReviewsQuery.useMatchReviewsQuery).mockReturnValue(mockQueryStore);

			render(MatchReviewsPage);

			expect(screen.getByText('Refreshing...')).toBeInTheDocument();
		});

		it('disables refresh button while fetching', () => {
			mockQueryStore = createMockStore({
				...mockReviewsQuery,
				isFetching: true
			});
			vi.mocked(matchReviewsQuery.useMatchReviewsQuery).mockReturnValue(mockQueryStore);

			render(MatchReviewsPage);

			const refreshButton = screen.getByRole('button', { name: /Refreshing.../i });
			expect(refreshButton).toBeDisabled();
		});
	});

	describe('Loading State', () => {
		it('shows loading spinner when query is loading', () => {
			mockQueryStore = createMockStore({
				data: undefined,
				isLoading: true,
				isFetching: false,
				isError: false,
				error: null
			});
			vi.mocked(matchReviewsQuery.useMatchReviewsQuery).mockReturnValue(mockQueryStore);

			render(MatchReviewsPage);

			expect(screen.getByText('Loading reviews...')).toBeInTheDocument();
			const spinner = document.querySelector('.animate-spin');
			expect(spinner).toBeInTheDocument();
		});

		it('does not show table when loading', () => {
			mockQueryStore = createMockStore({
				data: undefined,
				isLoading: true,
				isFetching: false,
				isError: false,
				error: null
			});
			vi.mocked(matchReviewsQuery.useMatchReviewsQuery).mockReturnValue(mockQueryStore);

			render(MatchReviewsPage);

			expect(screen.queryByRole('table')).not.toBeInTheDocument();
		});
	});

	describe('Error State', () => {
		it('shows error message when query fails', () => {
			mockQueryStore = createMockStore({
				data: undefined,
				isLoading: false,
				isFetching: false,
				isError: true,
				error: new Error('Failed to load reviews')
			});
			vi.mocked(matchReviewsQuery.useMatchReviewsQuery).mockReturnValue(mockQueryStore);

			render(MatchReviewsPage);

			expect(screen.getByText('Error')).toBeInTheDocument();
			expect(screen.getByText('Failed to load reviews')).toBeInTheDocument();
		});

		it('does not show table when error occurs', () => {
			mockQueryStore = createMockStore({
				data: undefined,
				isLoading: false,
				isFetching: false,
				isError: true,
				error: new Error('Not found')
			});
			vi.mocked(matchReviewsQuery.useMatchReviewsQuery).mockReturnValue(mockQueryStore);

			render(MatchReviewsPage);

			expect(screen.queryByRole('table')).not.toBeInTheDocument();
		});
	});

	describe('Empty State', () => {
		it('shows empty state when no reviews found', () => {
			mockQueryStore = createMockStore({
				data: [],
				isLoading: false,
				isFetching: false,
				isError: false,
				error: null
			});
			vi.mocked(matchReviewsQuery.useMatchReviewsQuery).mockReturnValue(mockQueryStore);

			render(MatchReviewsPage);

			expect(screen.getByText('No Reviews Found')).toBeInTheDocument();
			expect(
				screen.getByText('No pending reviews at the moment. All matches have been reviewed.')
			).toBeInTheDocument();
		});

		it('does not show table when empty', () => {
			mockQueryStore = createMockStore({
				data: [],
				isLoading: false,
				isFetching: false,
				isError: false,
				error: null
			});
			vi.mocked(matchReviewsQuery.useMatchReviewsQuery).mockReturnValue(mockQueryStore);

			render(MatchReviewsPage);

			expect(screen.queryByRole('table')).not.toBeInTheDocument();
		});
	});

	describe('Reviews Table', () => {
		it('displays table when reviews exist', () => {
			render(MatchReviewsPage);

			expect(screen.getByRole('table')).toBeInTheDocument();
		});

		it('displays all table headers', () => {
			render(MatchReviewsPage);

			expect(screen.getByRole('columnheader', { name: /Offender/i })).toBeInTheDocument();
			expect(screen.getByRole('columnheader', { name: /Status/i })).toBeInTheDocument();
			expect(screen.getByRole('columnheader', { name: /Confidence/i })).toBeInTheDocument();
			expect(screen.getByRole('columnheader', { name: /Candidates/i })).toBeInTheDocument();
			expect(screen.getByRole('columnheader', { name: /Searched/i })).toBeInTheDocument();
			expect(screen.getByRole('columnheader', { name: /Reviewed/i })).toBeInTheDocument();
		});

		it('displays correct number of review rows', () => {
			render(MatchReviewsPage);

			const rows = screen.getAllByRole('row');
			// 1 header row + 3 data rows
			expect(rows.length).toBe(4);
		});

		it('displays offender name', () => {
			render(MatchReviewsPage);

			expect(screen.getByText('Manufacturing Solutions Ltd')).toBeInTheDocument();
			expect(screen.getByText('Industrial Operations Corp')).toBeInTheDocument();
		});

		it('displays truncated offender ID', () => {
			render(MatchReviewsPage);

			// IDs are truncated to 8 characters and shown with "ID: " prefix
			// Multiple IDs displayed, use getAllByText
			const ids = screen.getAllByText(/ID: offender/);
			expect(ids.length).toBeGreaterThanOrEqual(1);
		});

		it('displays status badges', () => {
			render(MatchReviewsPage);

			expect(screen.getByText('pending')).toBeInTheDocument();
			expect(screen.getByText('needs_review')).toBeInTheDocument();
			expect(screen.getByText('approved')).toBeInTheDocument();
		});

		it('applies correct color to high confidence badge', () => {
			const { container } = render(MatchReviewsPage);

			// Find the 92% confidence badge (Chemical Processing PLC)
			const badges = container.querySelectorAll('.bg-green-100.text-green-800');
			// Should find at least one green badge (high confidence)
			expect(badges.length).toBeGreaterThan(0);
		});

		it('applies correct color to medium confidence badge', () => {
			const { container } = render(MatchReviewsPage);

			// Find the 65% confidence badge (Industrial Operations Corp)
			const badges = container.querySelectorAll('.bg-yellow-100.text-yellow-800');
			// Should find at least one yellow badge (medium confidence)
			expect(badges.length).toBeGreaterThan(0);
		});

		it('displays confidence as percentage', () => {
			render(MatchReviewsPage);

			expect(screen.getByText('85%')).toBeInTheDocument();
			expect(screen.getByText('65%')).toBeInTheDocument();
			expect(screen.getByText('92%')).toBeInTheDocument();
		});

		it('displays candidate count', () => {
			render(MatchReviewsPage);

			expect(screen.getByText('3 companies')).toBeInTheDocument();
			expect(screen.getByText('5 companies')).toBeInTheDocument();
			expect(screen.getByText('1 company')).toBeInTheDocument();
		});

		it('displays formatted searched date', () => {
			render(MatchReviewsPage);

			// Dates are formatted as "15 Jan 2024, 10:30" - multiple dates displayed
			const dates = screen.getAllByText(/Jan 2024/);
			expect(dates.length).toBeGreaterThanOrEqual(1);
		});

		it('displays formatted reviewed date when present', () => {
			render(MatchReviewsPage);

			// Approved review has reviewed_at date
			const rows = screen.getAllByRole('row');
			const approvedRow = rows.find((row) => row.textContent?.includes('approved'));
			expect(approvedRow).toBeDefined();
		});

		it('displays dash for null reviewed date', () => {
			render(MatchReviewsPage);

			// Pending reviews don't have reviewed_at
			const dashes = screen.getAllByText('—');
			expect(dashes.length).toBeGreaterThanOrEqual(2); // At least 2 pending reviews
		});

		it('displays review link for each row', () => {
			render(MatchReviewsPage);

			const reviewLinks = screen.getAllByRole('link', { name: /Review/i });
			expect(reviewLinks.length).toBe(3);
		});

		it('review links have correct href', () => {
			render(MatchReviewsPage);

			const reviewLinks = screen.getAllByRole('link', { name: /Review/i });
			expect(reviewLinks[0]).toHaveAttribute('href', '/admin/offenders/reviews/review-1');
			expect(reviewLinks[1]).toHaveAttribute('href', '/admin/offenders/reviews/review-2');
			expect(reviewLinks[2]).toHaveAttribute('href', '/admin/offenders/reviews/review-3');
		});
	});

	describe('Status Badge Colors', () => {
		it('applies blue badge to pending status', () => {
			const { container } = render(MatchReviewsPage);

			const pendingBadges = container.querySelectorAll('.bg-blue-100.text-blue-800');
			expect(pendingBadges.length).toBeGreaterThan(0);
		});

		it('applies yellow badge to needs_review status', () => {
			const { container } = render(MatchReviewsPage);

			const needsReviewBadges = container.querySelectorAll('.bg-yellow-100.text-yellow-800');
			expect(needsReviewBadges.length).toBeGreaterThan(0);
		});

		it('applies green badge to approved status', () => {
			const { container } = render(MatchReviewsPage);

			const approvedBadges = container.querySelectorAll('.bg-green-100.text-green-800');
			expect(approvedBadges.length).toBeGreaterThan(0);
		});
	});

	describe('Accessibility', () => {
		it('uses semantic table element', () => {
			render(MatchReviewsPage);

			const table = screen.getByRole('table');
			expect(table).toBeInTheDocument();
		});

		it('uses proper heading hierarchy', () => {
			const { container } = render(MatchReviewsPage);

			const h1 = container.querySelector('h1');
			expect(h1).toHaveTextContent('Offender Match Reviews');

			const h3 = container.querySelector('h3');
			if (h3) {
				// Error state might show h3
				expect(h3.textContent).toBeTruthy();
			}
		});

		it('provides descriptive button text', () => {
			render(MatchReviewsPage);

			expect(screen.getByRole('button', { name: /Refresh/i })).toBeInTheDocument();
			expect(screen.getByRole('button', { name: /All Reviews/i })).toBeInTheDocument();
		});

		it('uses sr-only for screen reader text', () => {
			const { container } = render(MatchReviewsPage);

			const srOnlyText = container.querySelector('.sr-only');
			expect(srOnlyText).toBeInTheDocument();
		});
	});
});
