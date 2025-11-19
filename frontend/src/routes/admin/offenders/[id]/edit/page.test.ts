import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import OffenderEditPage from './+page.svelte';
import * as offendersQuery from '$lib/query/offenders-edit';
import { goto } from '$app/navigation';

// Mock SvelteKit modules
vi.mock('$app/navigation', () => ({
	goto: vi.fn()
}));

vi.mock('$app/stores', () => ({
	page: {
		subscribe: (fn: (value: any) => void) => {
			fn({ params: { id: 'test-offender-123' } });
			return { unsubscribe: () => {} };
		}
	}
}));

vi.mock('$app/environment', () => ({
	browser: true
}));

// Mock offenders query module
vi.mock('$lib/query/offenders-edit', () => ({
	useOffenderQuery: vi.fn(),
	useUpdateOffenderMutation: vi.fn()
}));

describe('Admin Offender Edit Page (+page.svelte)', () => {
	// Helper to create Svelte-compatible store
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

	// Mock offender data
	const mockOffenderData = {
		id: 'test-offender-123',
		name: 'Manufacturing Solutions Ltd',
		address: '123 Industrial Estate, Manchester',
		local_authority: 'Manchester City Council',
		country: 'England',
		postcode: 'M1 1AA',
		main_activity: 'Metal fabrication and processing',
		sic_code: '25.11',
		business_type: 'Limited Company',
		industry: 'Manufacturing',
		total_cases: 4,
		total_notices: 6,
		total_fines: 275000
	};

	// Mock query response
	const mockOffenderQuery = {
		data: mockOffenderData,
		isLoading: false,
		isError: false,
		error: null
	};

	// Mock mutation response
	const mockUpdateMutation = {
		mutate: vi.fn(),
		isPending: false,
		isError: false,
		error: null
	};

	beforeEach(() => {
		vi.clearAllMocks();

		// Reset window methods
		global.confirm = vi.fn(() => true);
		global.alert = vi.fn();

		// Setup query mocks
		vi.mocked(offendersQuery.useOffenderQuery).mockReturnValue(createMockStore(mockOffenderQuery));
		vi.mocked(offendersQuery.useUpdateOffenderMutation).mockReturnValue(
			createMockStore(mockUpdateMutation)
		);
	});

	describe('Page Rendering', () => {
		it('renders the edit offender heading', () => {
			render(OffenderEditPage);

			expect(screen.getByText('Edit Offender')).toBeInTheDocument();
		});

		it('displays offender identifier in subheading', () => {
			render(OffenderEditPage);

			// Offender name appears in subheading
			expect(screen.getByText(/Manufacturing Solutions Ltd/)).toBeInTheDocument();
			expect(screen.getByText(/M1 1AA/)).toBeInTheDocument();
		});

		it('displays back to offenders link', () => {
			render(OffenderEditPage);

			const backLink = screen.getByRole('link', { name: /Back to Offenders/i });
			expect(backLink).toHaveAttribute('href', '/offenders');
		});
	});

	describe('Loading State', () => {
		it('shows loading spinner when query is loading', () => {
			vi.mocked(offendersQuery.useOffenderQuery).mockReturnValue(
				createMockStore({
					data: undefined,
					isLoading: true,
					isError: false,
					error: null
				})
			);

			render(OffenderEditPage);

			expect(screen.getByText('Loading offender...')).toBeInTheDocument();
			const spinner = document.querySelector('.animate-spin');
			expect(spinner).toBeInTheDocument();
		});

		it('does not show form when loading', () => {
			vi.mocked(offendersQuery.useOffenderQuery).mockReturnValue(
				createMockStore({
					data: undefined,
					isLoading: true,
					isError: false,
					error: null
				})
			);

			render(OffenderEditPage);

			expect(screen.queryByLabelText(/Name/i)).not.toBeInTheDocument();
		});
	});

	describe('Error State', () => {
		it('shows error message when query fails', () => {
			vi.mocked(offendersQuery.useOffenderQuery).mockReturnValue(
				createMockStore({
					data: undefined,
					isLoading: false,
					isError: true,
					error: new Error('Failed to load offender')
				})
			);

			render(OffenderEditPage);

			expect(screen.getByText('Error')).toBeInTheDocument();
			expect(screen.getByText('Failed to load offender')).toBeInTheDocument();
		});

		it('does not show form when error occurs', () => {
			vi.mocked(offendersQuery.useOffenderQuery).mockReturnValue(
				createMockStore({
					data: undefined,
					isLoading: false,
					isError: true,
					error: new Error('Not found')
				})
			);

			render(OffenderEditPage);

			expect(screen.queryByLabelText(/Name/i)).not.toBeInTheDocument();
		});
	});

	describe('Form Fields - Basic Information', () => {
		it('displays all basic information section fields', () => {
			render(OffenderEditPage);

			expect(screen.getByText('Basic Information')).toBeInTheDocument();
			expect(screen.getByLabelText(/Name/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Address/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Local Authority/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Country/i)).toBeInTheDocument();
		});

		it('marks name as required', () => {
			render(OffenderEditPage);

			const nameInput = screen.getByLabelText(/Name/i);
			expect(nameInput).toHaveAttribute('required');
		});

		it('populates name from offender data', () => {
			render(OffenderEditPage);

			const nameInput = screen.getByLabelText(/Name/i);
			expect(nameInput).toHaveValue('Manufacturing Solutions Ltd');
		});

		it('populates address from offender data', () => {
			render(OffenderEditPage);

			const addressInput = screen.getByLabelText(/Address/i);
			expect(addressInput).toHaveValue('123 Industrial Estate, Manchester');
		});

		it('address is a textarea', () => {
			render(OffenderEditPage);

			const addressInput = screen.getByLabelText(/Address/i);
			expect(addressInput.tagName).toBe('TEXTAREA');
		});

		it('populates local authority from offender data', () => {
			render(OffenderEditPage);

			const localAuthorityInput = screen.getByLabelText(/Local Authority/i);
			expect(localAuthorityInput).toHaveValue('Manchester City Council');
		});

		it('populates country from offender data', () => {
			render(OffenderEditPage);

			const countryInput = screen.getByLabelText(/Country/i);
			expect(countryInput).toHaveValue('England');
		});
	});

	describe('Form Fields - Business Information', () => {
		it('displays all business information section fields', () => {
			render(OffenderEditPage);

			expect(screen.getByText('Business Information')).toBeInTheDocument();
			expect(screen.getByLabelText(/Main Activity/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/SIC Code/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Business Type/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Industry/i)).toBeInTheDocument();
		});

		it('populates main activity from offender data', () => {
			render(OffenderEditPage);

			const mainActivityInput = screen.getByLabelText(/Main Activity/i);
			expect(mainActivityInput).toHaveValue('Metal fabrication and processing');
		});

		it('main activity is a textarea', () => {
			render(OffenderEditPage);

			const mainActivityInput = screen.getByLabelText(/Main Activity/i);
			expect(mainActivityInput.tagName).toBe('TEXTAREA');
		});

		it('populates SIC code from offender data', () => {
			render(OffenderEditPage);

			const sicCodeInput = screen.getByLabelText(/SIC Code/i);
			expect(sicCodeInput).toHaveValue('25.11');
		});

		it('populates business type from offender data', () => {
			render(OffenderEditPage);

			const businessTypeInput = screen.getByLabelText(/Business Type/i);
			expect(businessTypeInput).toHaveValue('Limited Company');
		});

		it('populates industry from offender data', () => {
			render(OffenderEditPage);

			const industryInput = screen.getByLabelText(/Industry/i);
			expect(industryInput).toHaveValue('Manufacturing');
		});
	});

	describe('Read-Only Enforcement Summary', () => {
		it('displays enforcement summary section', () => {
			render(OffenderEditPage);

			expect(screen.getByText('Enforcement Summary')).toBeInTheDocument();
			expect(screen.getByText('Total Cases')).toBeInTheDocument();
			expect(screen.getByText('Total Notices')).toBeInTheDocument();
			expect(screen.getByText('Total Fines')).toBeInTheDocument();
		});

		it('displays total cases', () => {
			render(OffenderEditPage);

			expect(screen.getByText('4')).toBeInTheDocument();
		});

		it('displays total notices', () => {
			render(OffenderEditPage);

			expect(screen.getByText('6')).toBeInTheDocument();
		});

		it('displays formatted total fines', () => {
			render(OffenderEditPage);

			// Check for formatted number with commas
			expect(screen.getByText(/275,000/)).toBeInTheDocument();
		});

		it('displays £ symbol for fines', () => {
			render(OffenderEditPage);

			const finesElement = screen.getByText(/£275,000/);
			expect(finesElement).toBeInTheDocument();
		});
	});

	describe('Action Buttons', () => {
		it('displays save and cancel buttons', () => {
			render(OffenderEditPage);

			expect(screen.getByRole('button', { name: /Save Changes/i })).toBeInTheDocument();
			expect(screen.getByRole('button', { name: /Cancel/i })).toBeInTheDocument();
		});

		it('save button is a submit button', () => {
			render(OffenderEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			expect(saveButton).toHaveAttribute('type', 'submit');
		});

		it('cancel button is not a submit button', () => {
			render(OffenderEditPage);

			const cancelButton = screen.getByRole('button', { name: /Cancel/i });
			expect(cancelButton).toHaveAttribute('type', 'button');
		});
	});

	describe('Save Functionality', () => {
		it('shows confirmation dialog before saving', async () => {
			render(OffenderEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			await fireEvent.click(saveButton);

			expect(global.confirm).toHaveBeenCalledWith(
				'Are you sure you want to save these changes?'
			);
		});

		it('does not save if user cancels confirmation', async () => {
			(global.confirm as any).mockReturnValue(false);

			render(OffenderEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			await fireEvent.click(saveButton);

			expect(mockUpdateMutation.mutate).not.toHaveBeenCalled();
		});

		it('saves offender when user confirms', async () => {
			(global.confirm as any).mockReturnValue(true);

			mockUpdateMutation.mutate.mockImplementation((data, callbacks) => {
				callbacks?.onSuccess?.();
			});

			render(OffenderEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			await fireEvent.click(saveButton);

			expect(mockUpdateMutation.mutate).toHaveBeenCalledWith(
				expect.objectContaining({
					id: 'test-offender-123',
					name: 'Manufacturing Solutions Ltd'
				}),
				expect.any(Object)
			);
		});

		it('sends all form data when saving', async () => {
			(global.confirm as any).mockReturnValue(true);

			mockUpdateMutation.mutate.mockImplementation((data, callbacks) => {
				expect(data).toEqual(
					expect.objectContaining({
						id: 'test-offender-123',
						name: 'Manufacturing Solutions Ltd',
						address: '123 Industrial Estate, Manchester',
						local_authority: 'Manchester City Council',
						country: 'England',
						main_activity: 'Metal fabrication and processing',
						sic_code: '25.11',
						business_type: 'Limited Company',
						industry: 'Manufacturing'
					})
				);
				callbacks?.onSuccess?.();
			});

			render(OffenderEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			await fireEvent.click(saveButton);

			expect(mockUpdateMutation.mutate).toHaveBeenCalled();
		});

		it('shows success alert on successful save', async () => {
			(global.confirm as any).mockReturnValue(true);

			mockUpdateMutation.mutate.mockImplementation((data, callbacks) => {
				callbacks?.onSuccess?.();
			});

			render(OffenderEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			await fireEvent.click(saveButton);

			expect(global.alert).toHaveBeenCalledWith('Offender updated successfully');
		});

		it('navigates to offenders list on successful save', async () => {
			(global.confirm as any).mockReturnValue(true);

			mockUpdateMutation.mutate.mockImplementation((data, callbacks) => {
				callbacks?.onSuccess?.();
			});

			render(OffenderEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			await fireEvent.click(saveButton);

			expect(goto).toHaveBeenCalledWith('/offenders');
		});

		it('shows error alert on save failure', async () => {
			(global.confirm as any).mockReturnValue(true);

			mockUpdateMutation.mutate.mockImplementation((data, callbacks) => {
				callbacks?.onError?.(new Error('Network error'));
			});

			render(OffenderEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			await fireEvent.click(saveButton);

			expect(global.alert).toHaveBeenCalledWith('Failed to update offender: Network error');
		});

		it('does not navigate on save failure', async () => {
			(global.confirm as any).mockReturnValue(true);

			mockUpdateMutation.mutate.mockImplementation((data, callbacks) => {
				callbacks?.onError?.(new Error('Network error'));
			});

			render(OffenderEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			await fireEvent.click(saveButton);

			expect(goto).not.toHaveBeenCalled();
		});

		it('shows loading state on save button while saving', () => {
			vi.mocked(offendersQuery.useUpdateOffenderMutation).mockReturnValue(
				createMockStore({
					...mockUpdateMutation,
					isPending: true
				})
			);

			render(OffenderEditPage);

			expect(screen.getByText('Saving...')).toBeInTheDocument();
		});

		it('disables save button while saving', () => {
			vi.mocked(offendersQuery.useUpdateOffenderMutation).mockReturnValue(
				createMockStore({
					...mockUpdateMutation,
					isPending: true
				})
			);

			render(OffenderEditPage);

			const saveButton = screen.getByRole('button', { name: /Saving.../i });
			expect(saveButton).toBeDisabled();
		});
	});

	describe('Cancel Functionality', () => {
		it('navigates to offenders list when cancel is clicked', async () => {
			render(OffenderEditPage);

			const cancelButton = screen.getByRole('button', { name: /Cancel/i });
			await fireEvent.click(cancelButton);

			expect(goto).toHaveBeenCalledWith('/offenders');
		});

		it('does not save when cancel is clicked', async () => {
			render(OffenderEditPage);

			const cancelButton = screen.getByRole('button', { name: /Cancel/i });
			await fireEvent.click(cancelButton);

			expect(mockUpdateMutation.mutate).not.toHaveBeenCalled();
		});
	});

	describe('Accessibility', () => {
		it('uses semantic form element', () => {
			const { container } = render(OffenderEditPage);

			const form = container.querySelector('form');
			expect(form).toBeInTheDocument();
		});

		it('labels all form inputs correctly', () => {
			render(OffenderEditPage);

			expect(screen.getByLabelText(/Name/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Address/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Local Authority/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Country/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Main Activity/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/SIC Code/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Business Type/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Industry/i)).toBeInTheDocument();
		});

		it('uses proper heading hierarchy', () => {
			const { container } = render(OffenderEditPage);

			const h1 = container.querySelector('h1');
			expect(h1).toHaveTextContent('Edit Offender');

			const h3s = container.querySelectorAll('h3');
			expect(h3s.length).toBeGreaterThan(0);
			expect(h3s[0]).toHaveTextContent('Basic Information');
		});

		it('provides descriptive button text', () => {
			render(OffenderEditPage);

			expect(screen.getByRole('button', { name: /Save Changes/i })).toBeInTheDocument();
			expect(screen.getByRole('button', { name: /Cancel/i })).toBeInTheDocument();
		});

		it('marks required fields visually', () => {
			const { container } = render(OffenderEditPage);

			const requiredIndicators = container.querySelectorAll('.text-red-500');
			expect(requiredIndicators.length).toBeGreaterThan(0);
		});
	});
});
