import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import NoticeEditPage from './+page.svelte';
import * as noticesQuery from '$lib/query/notices-edit';
import { goto } from '$app/navigation';

// Mock SvelteKit modules
vi.mock('$app/navigation', () => ({
	goto: vi.fn()
}));

vi.mock('$app/stores', () => ({
	page: {
		subscribe: (fn: (value: any) => void) => {
			fn({ params: { id: 'test-notice-123' } });
			return { unsubscribe: () => {} };
		}
	}
}));

vi.mock('$app/environment', () => ({
	browser: true
}));

// Mock notices query module
vi.mock('$lib/query/notices-edit', () => ({
	useNoticeQuery: vi.fn(),
	useUpdateNoticeMutation: vi.fn()
}));

describe('Admin Notice Edit Page (+page.svelte)', () => {
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

	// Mock notice data
	const mockNoticeData = {
		id: 'test-notice-123',
		regulator_id: 'HSE-NOTICE-2024-001',
		regulator_ref_number: 'HSE/REF/001',
		notice_date: '2024-01-15',
		operative_date: '2024-01-29',
		compliance_date: '2024-03-15',
		notice_body: 'Failure to maintain adequate safety procedures in manufacturing operations',
		offence_action_type: 'Improvement Notice',
		offence_action_date: '2024-01-15',
		url: 'https://example.com/notice/123',
		environmental_impact: 'Moderate',
		environmental_receptor: 'Air Quality',
		agency: {
			id: 'agency-1',
			name: 'Health and Safety Executive',
			code: 'hse'
		},
		offender: {
			id: 'offender-1',
			name: 'Manufacturing Solutions Ltd'
		}
	};

	// Mock query response
	const mockNoticeQuery = {
		data: mockNoticeData,
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
		vi.mocked(noticesQuery.useNoticeQuery).mockReturnValue(createMockStore(mockNoticeQuery));
		vi.mocked(noticesQuery.useUpdateNoticeMutation).mockReturnValue(
			createMockStore(mockUpdateMutation)
		);
	});

	describe('Page Rendering', () => {
		it('renders the edit notice heading', () => {
			render(NoticeEditPage);

			expect(screen.getByText('Edit Notice')).toBeInTheDocument();
		});

		it('displays notice identifier in subheading', () => {
			render(NoticeEditPage);

			// Check for regulator ID in subheading
			expect(screen.getByText(/HSE-NOTICE-2024-001/)).toBeInTheDocument();

			// Check for offender name - appears in both subheading and read-only field
			const offenderNames = screen.getAllByText(/Manufacturing Solutions Ltd/);
			expect(offenderNames.length).toBeGreaterThanOrEqual(1);
		});

		it('displays back to notices link', () => {
			render(NoticeEditPage);

			const backLink = screen.getByRole('link', { name: /Back to Notices/i });
			expect(backLink).toHaveAttribute('href', '/notices');
		});
	});

	describe('Loading State', () => {
		it('shows loading spinner when query is loading', () => {
			vi.mocked(noticesQuery.useNoticeQuery).mockReturnValue(
				createMockStore({
					data: undefined,
					isLoading: true,
					isError: false,
					error: null
				})
			);

			render(NoticeEditPage);

			expect(screen.getByText('Loading notice...')).toBeInTheDocument();
			const spinner = document.querySelector('.animate-spin');
			expect(spinner).toBeInTheDocument();
		});

		it('does not show form when loading', () => {
			vi.mocked(noticesQuery.useNoticeQuery).mockReturnValue(
				createMockStore({
					data: undefined,
					isLoading: true,
					isError: false,
					error: null
				})
			);

			render(NoticeEditPage);

			expect(screen.queryByLabelText(/Regulator ID/i)).not.toBeInTheDocument();
		});
	});

	describe('Error State', () => {
		it('shows error message when query fails', () => {
			vi.mocked(noticesQuery.useNoticeQuery).mockReturnValue(
				createMockStore({
					data: undefined,
					isLoading: false,
					isError: true,
					error: new Error('Failed to load notice')
				})
			);

			render(NoticeEditPage);

			expect(screen.getByText('Error')).toBeInTheDocument();
			expect(screen.getByText('Failed to load notice')).toBeInTheDocument();
		});

		it('does not show form when error occurs', () => {
			vi.mocked(noticesQuery.useNoticeQuery).mockReturnValue(
				createMockStore({
					data: undefined,
					isLoading: false,
					isError: true,
					error: new Error('Not found')
				})
			);

			render(NoticeEditPage);

			expect(screen.queryByLabelText(/Regulator ID/i)).not.toBeInTheDocument();
		});
	});

	describe('Form Fields - Basic Information', () => {
		it('displays all basic information section fields', () => {
			render(NoticeEditPage);

			expect(screen.getByText('Basic Information')).toBeInTheDocument();
			expect(screen.getByLabelText(/Regulator ID/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Reference Number/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/URL/i)).toBeInTheDocument();
		});

		it('marks regulator ID as required', () => {
			render(NoticeEditPage);

			const regulatorIdInput = screen.getByLabelText(/Regulator ID/i);
			expect(regulatorIdInput).toHaveAttribute('required');
		});

		it('populates regulator ID from notice data', () => {
			render(NoticeEditPage);

			const regulatorIdInput = screen.getByLabelText(/Regulator ID/i);
			expect(regulatorIdInput).toHaveValue('HSE-NOTICE-2024-001');
		});

		it('populates reference number from notice data', () => {
			render(NoticeEditPage);

			const refNumberInput = screen.getByLabelText(/Reference Number/i);
			expect(refNumberInput).toHaveValue('HSE/REF/001');
		});

		it('populates URL from notice data', () => {
			render(NoticeEditPage);

			const urlInput = screen.getByLabelText(/URL/i);
			expect(urlInput).toHaveValue('https://example.com/notice/123');
		});

		it('URL field has correct type', () => {
			render(NoticeEditPage);

			const urlInput = screen.getByLabelText(/URL/i) as HTMLInputElement;
			expect(urlInput.type).toBe('url');
		});
	});

	describe('Form Fields - Notice Details', () => {
		it('displays all notice details section fields', () => {
			render(NoticeEditPage);

			expect(screen.getByText('Notice Details')).toBeInTheDocument();
			expect(screen.getByLabelText(/Notice Body/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Action Type/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Action Date/i)).toBeInTheDocument();
		});

		it('populates notice body from notice data', () => {
			render(NoticeEditPage);

			const noticeBodyInput = screen.getByLabelText(/Notice Body/i);
			expect(noticeBodyInput).toHaveValue(
				'Failure to maintain adequate safety procedures in manufacturing operations'
			);
		});

		it('notice body is a textarea', () => {
			render(NoticeEditPage);

			const noticeBodyInput = screen.getByLabelText(/Notice Body/i);
			expect(noticeBodyInput.tagName).toBe('TEXTAREA');
		});

		it('populates action type from notice data', () => {
			render(NoticeEditPage);

			const actionTypeInput = screen.getByLabelText(/Action Type/i);
			expect(actionTypeInput).toHaveValue('Improvement Notice');
		});

		it('populates action date from notice data', () => {
			render(NoticeEditPage);

			const actionDateInput = screen.getByLabelText(/Action Date/i);
			expect(actionDateInput).toHaveValue('2024-01-15');
		});
	});

	describe('Form Fields - Important Dates', () => {
		it('displays all date information section fields', () => {
			render(NoticeEditPage);

			expect(screen.getByText('Important Dates')).toBeInTheDocument();
			expect(screen.getByLabelText(/Notice Date/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Operative Date/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Compliance Date/i)).toBeInTheDocument();
		});

		it('populates notice date from notice data', () => {
			render(NoticeEditPage);

			const noticeDateInput = screen.getByLabelText(/Notice Date/i);
			expect(noticeDateInput).toHaveValue('2024-01-15');
		});

		it('populates operative date from notice data', () => {
			render(NoticeEditPage);

			const operativeDateInput = screen.getByLabelText(/Operative Date/i);
			expect(operativeDateInput).toHaveValue('2024-01-29');
		});

		it('populates compliance date from notice data', () => {
			render(NoticeEditPage);

			const complianceDateInput = screen.getByLabelText(/Compliance Date/i);
			expect(complianceDateInput).toHaveValue('2024-03-15');
		});

		it('date fields have correct type', () => {
			render(NoticeEditPage);

			const noticeDateInput = screen.getByLabelText(/Notice Date/i) as HTMLInputElement;
			const operativeDateInput = screen.getByLabelText(/Operative Date/i) as HTMLInputElement;
			const complianceDateInput = screen.getByLabelText(/Compliance Date/i) as HTMLInputElement;

			expect(noticeDateInput.type).toBe('date');
			expect(operativeDateInput.type).toBe('date');
			expect(complianceDateInput.type).toBe('date');
		});
	});

	describe('Form Fields - Environmental Details', () => {
		it('displays all environmental details section fields', () => {
			render(NoticeEditPage);

			expect(screen.getByText('Environmental Details')).toBeInTheDocument();
			expect(screen.getByLabelText(/Environmental Impact/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Environmental Receptor/i)).toBeInTheDocument();
		});

		it('populates environmental impact from notice data', () => {
			render(NoticeEditPage);

			const impactInput = screen.getByLabelText(/Environmental Impact/i);
			expect(impactInput).toHaveValue('Moderate');
		});

		it('populates environmental receptor from notice data', () => {
			render(NoticeEditPage);

			const receptorInput = screen.getByLabelText(/Environmental Receptor/i);
			expect(receptorInput).toHaveValue('Air Quality');
		});
	});

	describe('Read-Only Related Information', () => {
		it('displays related information section', () => {
			render(NoticeEditPage);

			expect(screen.getByText('Related Information')).toBeInTheDocument();
			expect(screen.getByText('Agency')).toBeInTheDocument();
			expect(screen.getByText('Offender')).toBeInTheDocument();
		});

		it('displays agency name', () => {
			render(NoticeEditPage);

			expect(screen.getByText('Health and Safety Executive')).toBeInTheDocument();
		});

		it('displays offender name', () => {
			render(NoticeEditPage);

			// Use getAllByText since offender name appears in subheading too
			const offenderNames = screen.getAllByText('Manufacturing Solutions Ltd');
			expect(offenderNames.length).toBeGreaterThanOrEqual(1);
		});

		it('shows "Not assigned" when agency is missing', () => {
			vi.mocked(noticesQuery.useNoticeQuery).mockReturnValue(
				createMockStore({
					...mockNoticeQuery,
					data: {
						...mockNoticeData,
						agency: null
					}
				})
			);

			render(NoticeEditPage);

			const notAssigned = screen.getAllByText('Not assigned');
			expect(notAssigned.length).toBeGreaterThanOrEqual(1);
		});

		it('shows "Not assigned" when offender is missing', () => {
			vi.mocked(noticesQuery.useNoticeQuery).mockReturnValue(
				createMockStore({
					...mockNoticeQuery,
					data: {
						...mockNoticeData,
						offender: null
					}
				})
			);

			render(NoticeEditPage);

			const notAssigned = screen.getAllByText('Not assigned');
			expect(notAssigned.length).toBeGreaterThanOrEqual(1);
		});
	});

	describe('Action Buttons', () => {
		it('displays save and cancel buttons', () => {
			render(NoticeEditPage);

			expect(screen.getByRole('button', { name: /Save Changes/i })).toBeInTheDocument();
			expect(screen.getByRole('button', { name: /Cancel/i })).toBeInTheDocument();
		});

		it('save button is a submit button', () => {
			render(NoticeEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			expect(saveButton).toHaveAttribute('type', 'submit');
		});

		it('cancel button is not a submit button', () => {
			render(NoticeEditPage);

			const cancelButton = screen.getByRole('button', { name: /Cancel/i });
			expect(cancelButton).toHaveAttribute('type', 'button');
		});
	});

	describe('Save Functionality', () => {
		it('shows confirmation dialog before saving', async () => {
			render(NoticeEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			await fireEvent.click(saveButton);

			expect(global.confirm).toHaveBeenCalledWith(
				'Are you sure you want to save these changes?'
			);
		});

		it('does not save if user cancels confirmation', async () => {
			(global.confirm as any).mockReturnValue(false);

			render(NoticeEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			await fireEvent.click(saveButton);

			expect(mockUpdateMutation.mutate).not.toHaveBeenCalled();
		});

		it('saves notice when user confirms', async () => {
			(global.confirm as any).mockReturnValue(true);

			mockUpdateMutation.mutate.mockImplementation((data, callbacks) => {
				callbacks?.onSuccess?.();
			});

			render(NoticeEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			await fireEvent.click(saveButton);

			expect(mockUpdateMutation.mutate).toHaveBeenCalledWith(
				expect.objectContaining({
					id: 'test-notice-123',
					regulator_id: 'HSE-NOTICE-2024-001'
				}),
				expect.any(Object)
			);
		});

		it('sends all form data when saving', async () => {
			(global.confirm as any).mockReturnValue(true);

			mockUpdateMutation.mutate.mockImplementation((data, callbacks) => {
				expect(data).toEqual(
					expect.objectContaining({
						id: 'test-notice-123',
						regulator_id: 'HSE-NOTICE-2024-001',
						regulator_ref_number: 'HSE/REF/001',
						notice_date: '2024-01-15',
						operative_date: '2024-01-29',
						compliance_date: '2024-03-15',
						notice_body:
							'Failure to maintain adequate safety procedures in manufacturing operations',
						offence_action_type: 'Improvement Notice',
						offence_action_date: '2024-01-15',
						url: 'https://example.com/notice/123',
						environmental_impact: 'Moderate',
						environmental_receptor: 'Air Quality'
					})
				);
				callbacks?.onSuccess?.();
			});

			render(NoticeEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			await fireEvent.click(saveButton);

			expect(mockUpdateMutation.mutate).toHaveBeenCalled();
		});

		it('shows success alert on successful save', async () => {
			(global.confirm as any).mockReturnValue(true);

			mockUpdateMutation.mutate.mockImplementation((data, callbacks) => {
				callbacks?.onSuccess?.();
			});

			render(NoticeEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			await fireEvent.click(saveButton);

			expect(global.alert).toHaveBeenCalledWith('Notice updated successfully');
		});

		it('navigates to notices list on successful save', async () => {
			(global.confirm as any).mockReturnValue(true);

			mockUpdateMutation.mutate.mockImplementation((data, callbacks) => {
				callbacks?.onSuccess?.();
			});

			render(NoticeEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			await fireEvent.click(saveButton);

			expect(goto).toHaveBeenCalledWith('/notices');
		});

		it('shows error alert on save failure', async () => {
			(global.confirm as any).mockReturnValue(true);

			mockUpdateMutation.mutate.mockImplementation((data, callbacks) => {
				callbacks?.onError?.(new Error('Network error'));
			});

			render(NoticeEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			await fireEvent.click(saveButton);

			expect(global.alert).toHaveBeenCalledWith('Failed to update notice: Network error');
		});

		it('does not navigate on save failure', async () => {
			(global.confirm as any).mockReturnValue(true);

			mockUpdateMutation.mutate.mockImplementation((data, callbacks) => {
				callbacks?.onError?.(new Error('Network error'));
			});

			render(NoticeEditPage);

			const saveButton = screen.getByRole('button', { name: /Save Changes/i });
			await fireEvent.click(saveButton);

			expect(goto).not.toHaveBeenCalled();
		});

		it('shows loading state on save button while saving', () => {
			vi.mocked(noticesQuery.useUpdateNoticeMutation).mockReturnValue(
				createMockStore({
					...mockUpdateMutation,
					isPending: true
				})
			);

			render(NoticeEditPage);

			expect(screen.getByText('Saving...')).toBeInTheDocument();
		});

		it('disables save button while saving', () => {
			vi.mocked(noticesQuery.useUpdateNoticeMutation).mockReturnValue(
				createMockStore({
					...mockUpdateMutation,
					isPending: true
				})
			);

			render(NoticeEditPage);

			const saveButton = screen.getByRole('button', { name: /Saving.../i });
			expect(saveButton).toBeDisabled();
		});
	});

	describe('Cancel Functionality', () => {
		it('navigates to notices list when cancel is clicked', async () => {
			render(NoticeEditPage);

			const cancelButton = screen.getByRole('button', { name: /Cancel/i });
			await fireEvent.click(cancelButton);

			expect(goto).toHaveBeenCalledWith('/notices');
		});

		it('does not save when cancel is clicked', async () => {
			render(NoticeEditPage);

			const cancelButton = screen.getByRole('button', { name: /Cancel/i });
			await fireEvent.click(cancelButton);

			expect(mockUpdateMutation.mutate).not.toHaveBeenCalled();
		});
	});

	describe('Accessibility', () => {
		it('uses semantic form element', () => {
			const { container } = render(NoticeEditPage);

			const form = container.querySelector('form');
			expect(form).toBeInTheDocument();
		});

		it('labels all form inputs correctly', () => {
			render(NoticeEditPage);

			expect(screen.getByLabelText(/Regulator ID/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Reference Number/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/URL/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Notice Body/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Action Type/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Action Date/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Notice Date/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Operative Date/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Compliance Date/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Environmental Impact/i)).toBeInTheDocument();
			expect(screen.getByLabelText(/Environmental Receptor/i)).toBeInTheDocument();
		});

		it('uses proper heading hierarchy', () => {
			const { container } = render(NoticeEditPage);

			const h1 = container.querySelector('h1');
			expect(h1).toHaveTextContent('Edit Notice');

			const h3s = container.querySelectorAll('h3');
			expect(h3s.length).toBeGreaterThan(0);
			expect(h3s[0]).toHaveTextContent('Basic Information');
		});

		it('provides descriptive button text', () => {
			render(NoticeEditPage);

			expect(screen.getByRole('button', { name: /Save Changes/i })).toBeInTheDocument();
			expect(screen.getByRole('button', { name: /Cancel/i })).toBeInTheDocument();
		});

		it('marks required fields visually', () => {
			const { container } = render(NoticeEditPage);

			const requiredIndicators = container.querySelectorAll('.text-red-500');
			expect(requiredIndicators.length).toBeGreaterThan(0);
		});
	});
});
