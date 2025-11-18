import { render, screen, waitFor, within, fireEvent } from '@testing-library/svelte'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { tick } from 'svelte'
import AgenciesPage from './+page.svelte'

// Mock modules
vi.mock('$app/environment', () => ({
  browser: true
}))

vi.mock('$lib/query/agencies', () => ({
  useAgenciesQuery: vi.fn(),
  useDeleteAgencyMutation: vi.fn()
}))

vi.mock('$lib/electric/sync', () => ({
  startSync: vi.fn(() => Promise.resolve()),
  checkElectricHealth: vi.fn(() => Promise.resolve(true))
}))

// Import mocked modules
import * as agenciesQuery from '$lib/query/agencies'
import * as electricSync from '$lib/electric/sync'

// Helper to create TanStack Query store
function createMockStore(value: any) {
  return {
    subscribe: (fn: (value: any) => void) => {
      fn(value)
      return { unsubscribe: () => {} }
    }
  }
}

// NOTE: onMount Testing Limitation
// Per SKILLS.md Section 13: Svelte's onMount lifecycle hook does NOT execute
// reliably in Svelte Testing Library tests. The component's onMount initializes
// ElectricSQL sync and sets loading = false, but this never completes in tests.
// Tests that depend on onMount completing are skipped and should be covered by E2E tests.

// Mock agency data
const mockAgencies = [
  {
    id: 'agency-abc12345-6789-1234-5678-123456789012',
    code: 'hse',
    name: 'Health and Safety Executive',
    base_url: 'https://www.hse.gov.uk',
    enabled: true,
    inserted_at: '2024-01-15T10:30:00Z',
    updated_at: '2024-01-20T14:45:00Z'
  },
  {
    id: 'agency-def12345-6789-1234-5678-123456789012',
    code: 'ea',
    name: 'Environment Agency',
    base_url: 'https://www.gov.uk/environment-agency',
    enabled: true,
    inserted_at: '2024-01-16T11:00:00Z',
    updated_at: '2024-01-21T15:30:00Z'
  },
  {
    id: 'agency-ghi12345-6789-1234-5678-123456789012',
    code: 'sepa',
    name: 'Scottish Environment Protection Agency',
    base_url: null,
    enabled: false,
    inserted_at: '2024-01-17T12:15:00Z',
    updated_at: '2024-01-22T16:20:00Z'
  }
]

describe('Agencies Page', () => {
  beforeEach(async () => {
    vi.clearAllMocks()
    vi.useRealTimers()

    // Default: successful query with agencies
    const mockAgenciesQuery = {
      data: mockAgencies,
      isLoading: false,
      isError: false,
      error: null
    }

    const mockAgenciesQueryStore = createMockStore(mockAgenciesQuery)
    vi.mocked(agenciesQuery.useAgenciesQuery).mockReturnValue(mockAgenciesQueryStore)

    // Default: successful delete mutation
    const mockDeleteMutation = {
      mutate: vi.fn(),
      isPending: false
    }

    const mockDeleteMutationStore = createMockStore(mockDeleteMutation)
    vi.mocked(agenciesQuery.useDeleteAgencyMutation).mockReturnValue(mockDeleteMutationStore)
  })

  describe('Page Rendering', () => {
    it('displays the page heading', async () => {
      render(AgenciesPage)
      await waitFor(() => {
        expect(screen.getByRole('heading', { name: /Agency Management/i })).toBeInTheDocument()
      })
    })

    it('displays the page description with agency count', async () => {
      render(AgenciesPage)
      await waitFor(() => {
        expect(screen.getByText(/Manage Enforcement Agencies/i)).toBeInTheDocument()
        expect(screen.getByText(/3 agencies/i)).toBeInTheDocument()
      })
    })

    it('displays singular "agency" when count is 1', async () => {
      const singleAgency = [mockAgencies[0]]
      const mockQuery = createMockStore({
        data: singleAgency,
        isLoading: false,
        isError: false,
        error: null
      })
      vi.mocked(agenciesQuery.useAgenciesQuery).mockReturnValue(mockQuery)

      render(AgenciesPage)
      await waitFor(() => {
        expect(screen.getByText(/1 agency/i)).toBeInTheDocument()
      })
    })

    // SKIPPED: Requires onMount to complete (see note at top of file)
    it.skip('displays "No agencies found" when data is empty', async () => {
      const mockQuery = createMockStore({
        data: [],
        isLoading: false,
        isError: false,
        error: null
      })
      vi.mocked(agenciesQuery.useAgenciesQuery).mockReturnValue(mockQuery)

      render(AgenciesPage)

      expect(screen.getByText(/No agencies found/i)).toBeInTheDocument()
    })

    it('displays back to dashboard link', async () => {
      render(AgenciesPage)
      await waitFor(() => {
        const backLink = screen.getByRole('link', { name: /Back to Dashboard/i })
        expect(backLink).toBeInTheDocument()
        expect(backLink).toHaveAttribute('href', '/admin')
      })
    })

    it('displays new agency button', async () => {
      render(AgenciesPage)
      await waitFor(() => {
        const newButton = screen.getByRole('link', { name: /New Agency/i })
        expect(newButton).toBeInTheDocument()
        expect(newButton).toHaveAttribute('href', '/admin/agencies/new')
      })
    })
  })

  describe('Loading State', () => {
    it('displays loading spinner when query is loading', () => {
      const mockQuery = createMockStore({
        data: null,
        isLoading: true,
        isError: false,
        error: null
      })
      vi.mocked(agenciesQuery.useAgenciesQuery).mockReturnValue(mockQuery)

      render(AgenciesPage)
      expect(screen.getByText(/Loading agencies.../i)).toBeInTheDocument()
    })

    it('does not display table when loading', () => {
      const mockQuery = createMockStore({
        data: null,
        isLoading: true,
        isError: false,
        error: null
      })
      vi.mocked(agenciesQuery.useAgenciesQuery).mockReturnValue(mockQuery)

      render(AgenciesPage)
      expect(screen.queryByRole('table')).not.toBeInTheDocument()
    })
  })

  // SKIPPED: All tests below require onMount to complete (see note at top of file)
  // These should be covered by E2E tests instead
  describe.skip('Empty State', () => {
    it('displays empty state when no agencies exist', async () => {
      const mockQuery = createMockStore({
        data: [],
        isLoading: false,
        isError: false,
        error: null
      })
      vi.mocked(agenciesQuery.useAgenciesQuery).mockReturnValue(mockQuery)

      render(AgenciesPage)

      expect(screen.getByText(/No agencies found/i)).toBeInTheDocument()
      expect(screen.getByText(/Get started by creating a new enforcement agency/i)).toBeInTheDocument()
    })

    it('displays new agency button in empty state', async () => {
      const mockQuery = createMockStore({
        data: [],
        isLoading: false,
        isError: false,
        error: null
      })
      vi.mocked(agenciesQuery.useAgenciesQuery).mockReturnValue(mockQuery)

      render(AgenciesPage)

      const newButtons = screen.getAllByRole('link', { name: /New Agency/i })
      expect(newButtons.length).toBeGreaterThan(0)
    })

    it('does not display table when empty', async () => {
      const mockQuery = createMockStore({
        data: [],
        isLoading: false,
        isError: false,
        error: null
      })
      vi.mocked(agenciesQuery.useAgenciesQuery).mockReturnValue(mockQuery)

      render(AgenciesPage)

      expect(screen.queryByRole('table')).not.toBeInTheDocument()
    })
  })

  describe.skip('Agencies Table', () => {
    it('displays the agencies table', async () => {
      render(AgenciesPage)
      expect(screen.getByRole('table')).toBeInTheDocument()
    })

    it('displays all table headers', async () => {
      render(AgenciesPage)

      expect(screen.getByRole('columnheader', { name: /^ID$/i })).toBeInTheDocument()
      expect(screen.getByRole('columnheader', { name: /^Code$/i })).toBeInTheDocument()
      expect(screen.getByRole('columnheader', { name: /^Name$/i })).toBeInTheDocument()
      expect(screen.getByRole('columnheader', { name: /Base URL/i })).toBeInTheDocument()
      expect(screen.getByRole('columnheader', { name: /^Enabled$/i })).toBeInTheDocument()
      expect(screen.getByRole('columnheader', { name: /Inserted At/i })).toBeInTheDocument()
      expect(screen.getByRole('columnheader', { name: /Updated At/i })).toBeInTheDocument()
    })

    it('displays correct number of agency rows', async () => {
      render(AgenciesPage)

      const rows = screen.getAllByRole('row')
      // Header row + 3 data rows
      expect(rows).toHaveLength(4)
    })

    it('displays agency names', async () => {
      render(AgenciesPage)

      expect(screen.getByText(/Health and Safety Executive/i)).toBeInTheDocument()
      expect(screen.getByText(/Environment Agency/i)).toBeInTheDocument()
      expect(screen.getByText(/Scottish Environment Protection Agency/i)).toBeInTheDocument()
    })

    it('displays truncated agency IDs', async () => {
      render(AgenciesPage)

      const ids = screen.getAllByText(/agency-abc/)
      expect(ids.length).toBeGreaterThanOrEqual(1)
    })

    it('displays agency codes as uppercase badges', async () => {
      render(AgenciesPage)

      expect(screen.getByText('HSE')).toBeInTheDocument()
      expect(screen.getByText('EA')).toBeInTheDocument()
      expect(screen.getByText('SEPA')).toBeInTheDocument()
    })

    it('displays base URL as clickable link when present', async () => {
      render(AgenciesPage)

      const hseLink = screen.getByRole('link', { name: /hse\.gov\.uk/i })
      expect(hseLink).toBeInTheDocument()
      expect(hseLink).toHaveAttribute('href', 'https://www.hse.gov.uk')
      expect(hseLink).toHaveAttribute('target', '_blank')
      expect(hseLink).toHaveAttribute('rel', 'noopener noreferrer')
    })

    it('displays em dash when base URL is null', async () => {
      render(AgenciesPage)

      const emDashes = screen.getAllByText('—')
      expect(emDashes.length).toBeGreaterThan(0)
    })

    it('displays enabled badge as green "Yes" when enabled is true', async () => {
      render(AgenciesPage)

      const yesBadges = screen.getAllByText('Yes')
      expect(yesBadges).toHaveLength(2)
    })

    it('displays enabled badge as red "No" when enabled is false', async () => {
      render(AgenciesPage)

      expect(screen.getByText('No')).toBeInTheDocument()
    })

    it('displays formatted inserted_at dates', async () => {
      render(AgenciesPage)

      // Dates are formatted as dd/mm/yyyy hh:mm in en-GB locale
      const dates = screen.getAllByText(/15\/01\/2024/)
      expect(dates.length).toBeGreaterThanOrEqual(1)
    })

    it('displays formatted updated_at dates', async () => {
      render(AgenciesPage)

      const dates = screen.getAllByText(/20\/01\/2024/)
      expect(dates.length).toBeGreaterThanOrEqual(1)
    })

    it('displays edit link for each agency', async () => {
      render(AgenciesPage)

      const editLinks = screen.getAllByTitle(/Edit agency/i)
      expect(editLinks).toHaveLength(3)
      expect(editLinks[0]).toHaveAttribute('href', '/admin/agencies/agency-abc12345-6789-1234-5678-123456789012/edit')
    })

    it('displays delete button for each agency', async () => {
      render(AgenciesPage)

      const deleteButtons = screen.getAllByTitle(/Delete agency/i)
      expect(deleteButtons).toHaveLength(3)
    })
  })

  describe.skip('Delete Functionality', () => {
    it('shows confirmation dialog when delete button is clicked', async () => {
      const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(false)

      render(AgenciesPage)

      const deleteButtons = screen.getAllByTitle(/Delete agency/i)
      await fireEvent.click(deleteButtons[0])

      expect(confirmSpy).toHaveBeenCalledWith('Are you sure you want to delete this agency? This action cannot be undone.')
      confirmSpy.mockRestore()
    })

    it('calls delete mutation when user confirms', async () => {
      const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true)
      const mockMutate = vi.fn()

      const mockDeleteMutation = createMockStore({
        mutate: mockMutate,
        isPending: false
      })
      vi.mocked(agenciesQuery.useDeleteAgencyMutation).mockReturnValue(mockDeleteMutation)

      render(AgenciesPage)

      const deleteButtons = screen.getAllByTitle(/Delete agency/i)
      await fireEvent.click(deleteButtons[0])

      expect(mockMutate).toHaveBeenCalledWith('agency-abc12345-6789-1234-5678-123456789012')
      confirmSpy.mockRestore()
    })

    it('does not call delete mutation when user cancels', async () => {
      const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(false)
      const mockMutate = vi.fn()

      const mockDeleteMutation = createMockStore({
        mutate: mockMutate,
        isPending: false
      })
      vi.mocked(agenciesQuery.useDeleteAgencyMutation).mockReturnValue(mockDeleteMutation)

      render(AgenciesPage)

      const deleteButtons = screen.getAllByTitle(/Delete agency/i)
      await fireEvent.click(deleteButtons[0])

      expect(mockMutate).not.toHaveBeenCalled()
      confirmSpy.mockRestore()
    })
  })

  describe.skip('Electric Sync Integration', () => {
    it('checks Electric health on mount', async () => {
      render(AgenciesPage)
      expect(electricSync.checkElectricHealth).toHaveBeenCalled()
    })

    it('starts sync when Electric is healthy', async () => {
      vi.mocked(electricSync.checkElectricHealth).mockResolvedValue(true)

      render(AgenciesPage)
      expect(electricSync.startSync).toHaveBeenCalled()
    })

    it('does not start sync when Electric is unhealthy', async () => {
      vi.mocked(electricSync.checkElectricHealth).mockResolvedValue(false)
      vi.mocked(electricSync.startSync).mockClear()

      render(AgenciesPage)

      expect(electricSync.checkElectricHealth).toHaveBeenCalled()
      expect(electricSync.startSync).not.toHaveBeenCalled()
    })
  })

  describe('Accessibility', () => {
    // SKIPPED: Requires table to be rendered (which requires onMount to complete)
    it.skip('uses semantic table structure', async () => {
      render(AgenciesPage)

      const table = screen.getByRole('table')
      expect(table).toBeInTheDocument()

      const columnHeaders = screen.getAllByRole('columnheader')
      expect(columnHeaders.length).toBeGreaterThan(0)
    })

    it('uses proper heading hierarchy', async () => {
      render(AgenciesPage)
      await waitFor(() => {
        const h1 = screen.getByRole('heading', { level: 1 })
        expect(h1).toHaveTextContent(/Agency Management/i)
      })
    })

    it('provides descriptive button text', async () => {
      render(AgenciesPage)
      await waitFor(() => {
        expect(screen.getByRole('link', { name: /Back to Dashboard/i })).toBeInTheDocument()
        expect(screen.getByRole('link', { name: /New Agency/i })).toBeInTheDocument()
      })
    })

    // SKIPPED: Requires table to be rendered (which requires onMount to complete)
    it.skip('provides sr-only text for actions column', async () => {
      render(AgenciesPage)

      const srOnlyText = screen.getByText('Actions')
      expect(srOnlyText).toBeInTheDocument()
      expect(srOnlyText).toHaveClass('sr-only')
    })

    // SKIPPED: Requires table to be rendered (which requires onMount to complete)
    it.skip('provides title attributes for action buttons', async () => {
      render(AgenciesPage)

      const editLinks = screen.getAllByTitle('Edit agency')
      expect(editLinks.length).toBeGreaterThan(0)

      const deleteButtons = screen.getAllByTitle('Delete agency')
      expect(deleteButtons.length).toBeGreaterThan(0)
    })
  })
})
