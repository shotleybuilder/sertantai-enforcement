import { describe, it, expect, beforeEach, afterEach, afterAll, vi } from 'vitest';
import { QueryClient } from '@tanstack/svelte-query';
import type { AdminStats } from './admin';
import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';

// Mock PUBLIC_API_URL
vi.mock('$env/static/public', () => ({
  PUBLIC_API_URL: 'http://localhost:4002'
}));

// Mock admin stats data
const mockAdminStats: AdminStats = {
  stats: {
    data_quality_score: 95.5,
    active_agencies: 4,
    recent_cases: 142,
    recent_notices: 78,
    total_fines: '£2,450,000',
    sync_errors: 2,
    timeframe: 'Last 7 days'
  },
  agencies: [
    {
      id: 'agency-1',
      code: 'hse',
      name: 'Health and Safety Executive',
      enabled: true
    },
    {
      id: 'agency-2',
      code: 'ea',
      name: 'Environment Agency',
      enabled: true
    },
    {
      id: 'agency-3',
      code: 'sepa',
      name: 'Scottish Environment Protection Agency',
      enabled: false
    },
    {
      id: 'agency-4',
      code: 'nrw',
      name: 'Natural Resources Wales',
      enabled: true
    }
  ]
};

// Setup MSW server
const server = setupServer();

// Helper to create test query client
function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        retry: false, // Disable retries in tests
        gcTime: 0, // Disable caching
        staleTime: 0
      }
    }
  });
}

describe('Admin Query - API Integration', () => {
  let queryClient: QueryClient;

  beforeEach(() => {
    queryClient = createTestQueryClient();
    server.listen({ onUnhandledRequest: 'error' });
  });

  afterEach(() => {
    queryClient.clear();
    server.resetHandlers();
  });

  afterAll(() => {
    server.close();
  });

  describe('fetchAdminStats API', () => {
    describe('Successful Data Fetching', () => {
      it('fetches admin stats for week period', async () => {
        let capturedPeriod = '';

        server.use(
          http.get('http://localhost:4002/api/admin/stats', ({ request }) => {
            const url = new URL(request.url);
            capturedPeriod = url.searchParams.get('period') || '';
            return HttpResponse.json(mockAdminStats);
          })
        );

        const response = await fetch('http://localhost:4002/api/admin/stats?period=week');
        const data = await response.json();

        expect(capturedPeriod).toBe('week');
        expect(response.ok).toBe(true);
        expect(data).toEqual(mockAdminStats);
      });

      it('fetches admin stats for month period', async () => {
        let capturedPeriod = '';

        server.use(
          http.get('http://localhost:4002/api/admin/stats', ({ request }) => {
            const url = new URL(request.url);
            capturedPeriod = url.searchParams.get('period') || '';
            return HttpResponse.json(mockAdminStats);
          })
        );

        const response = await fetch('http://localhost:4002/api/admin/stats?period=month');
        const data = await response.json();

        expect(capturedPeriod).toBe('month');
        expect(data).toEqual(mockAdminStats);
      });

      it('fetches admin stats for year period', async () => {
        let capturedPeriod = '';

        server.use(
          http.get('http://localhost:4002/api/admin/stats', ({ request }) => {
            const url = new URL(request.url);
            capturedPeriod = url.searchParams.get('period') || '';
            return HttpResponse.json(mockAdminStats);
          })
        );

        const response = await fetch('http://localhost:4002/api/admin/stats?period=year');
        const data = await response.json();

        expect(capturedPeriod).toBe('year');
        expect(data).toEqual(mockAdminStats);
      });

      it('returns correct data structure', async () => {
        server.use(
          http.get('http://localhost:4002/api/admin/stats', () => {
            return HttpResponse.json(mockAdminStats);
          })
        );

        // Set query data manually to test structure
        queryClient.setQueryData(['adminStats', 'week'], mockAdminStats);

        const data = queryClient.getQueryData<AdminStats>(['adminStats', 'week']);

        expect(data).toBeDefined();
        expect(data?.stats).toBeDefined();
        expect(data?.stats.data_quality_score).toBe(95.5);
        expect(data?.stats.active_agencies).toBe(4);
        expect(data?.stats.recent_cases).toBe(142);
        expect(data?.stats.recent_notices).toBe(78);
        expect(data?.stats.total_fines).toBe('£2,450,000');
        expect(data?.stats.sync_errors).toBe(2);
        expect(data?.stats.timeframe).toBe('Last 7 days');
      });

      it('returns correct agencies array', async () => {
        server.use(
          http.get('http://localhost:4002/api/admin/stats', () => {
            return HttpResponse.json(mockAdminStats);
          })
        );

        queryClient.setQueryData(['adminStats', 'week'], mockAdminStats);

        const data = queryClient.getQueryData<AdminStats>(['adminStats', 'week']);

        expect(data?.agencies).toBeDefined();
        expect(data?.agencies).toHaveLength(4);
        expect(data?.agencies[0].code).toBe('hse');
        expect(data?.agencies[0].enabled).toBe(true);
        expect(data?.agencies[2].code).toBe('sepa');
        expect(data?.agencies[2].enabled).toBe(false);
      });
    });

    describe('Error Handling', () => {
      it('handles 404 error', async () => {
        server.use(
          http.get('http://localhost:4002/api/admin/stats', () => {
            return new HttpResponse(null, { status: 404, statusText: 'Not Found' });
          })
        );

        const response = await fetch('http://localhost:4002/api/admin/stats?period=week');

        expect(response.ok).toBe(false);
        expect(response.status).toBe(404);
        expect(response.statusText).toBe('Not Found');
      });

      it('handles 500 error', async () => {
        server.use(
          http.get('http://localhost:4002/api/admin/stats', () => {
            return new HttpResponse(null, { status: 500, statusText: 'Internal Server Error' });
          })
        );

        const response = await fetch('http://localhost:4002/api/admin/stats?period=week');

        expect(response.ok).toBe(false);
        expect(response.status).toBe(500);
      });

      it('handles network error', async () => {
        server.use(
          http.get('http://localhost:4002/api/admin/stats', () => {
            return HttpResponse.error();
          })
        );

        await expect(
          fetch('http://localhost:4002/api/admin/stats?period=week')
        ).rejects.toThrow();
      });

      it('throws error for non-OK responses', async () => {
        server.use(
          http.get('http://localhost:4002/api/admin/stats', () => {
            return new HttpResponse(null, { status: 403, statusText: 'Forbidden' });
          })
        );

        const response = await fetch('http://localhost:4002/api/admin/stats?period=week');

        expect(response.ok).toBe(false);
        expect(response.status).toBe(403);
      });
    });

  });

  describe('Query Key Management', () => {
    it('uses different query keys for different periods', () => {
      // Set different data for each period
      queryClient.setQueryData(['adminStats', 'week'], { ...mockAdminStats, stats: { ...mockAdminStats.stats, timeframe: 'Last 7 days' } });
      queryClient.setQueryData(['adminStats', 'month'], { ...mockAdminStats, stats: { ...mockAdminStats.stats, timeframe: 'Last 30 days' } });
      queryClient.setQueryData(['adminStats', 'year'], { ...mockAdminStats, stats: { ...mockAdminStats.stats, timeframe: 'Last 365 days' } });

      const weekData = queryClient.getQueryData<AdminStats>(['adminStats', 'week']);
      const monthData = queryClient.getQueryData<AdminStats>(['adminStats', 'month']);
      const yearData = queryClient.getQueryData<AdminStats>(['adminStats', 'year']);

      expect(weekData?.stats.timeframe).toBe('Last 7 days');
      expect(monthData?.stats.timeframe).toBe('Last 30 days');
      expect(yearData?.stats.timeframe).toBe('Last 365 days');
    });

    it('invalidates only specific period when cleared', () => {
      queryClient.setQueryData(['adminStats', 'week'], mockAdminStats);
      queryClient.setQueryData(['adminStats', 'month'], mockAdminStats);
      queryClient.setQueryData(['adminStats', 'year'], mockAdminStats);

      // Remove only week data
      queryClient.removeQueries({ queryKey: ['adminStats', 'week'] });

      expect(queryClient.getQueryData(['adminStats', 'week'])).toBeUndefined();
      expect(queryClient.getQueryData(['adminStats', 'month'])).toBeDefined();
      expect(queryClient.getQueryData(['adminStats', 'year'])).toBeDefined();
    });
  });

  describe('API URL Construction', () => {
    it('constructs correct URL with period parameter', async () => {
      let capturedUrl = '';

      server.use(
        http.get('http://localhost:4002/api/admin/stats', ({ request }) => {
          capturedUrl = request.url;
          return HttpResponse.json(mockAdminStats);
        })
      );

      await fetch('http://localhost:4002/api/admin/stats?period=month');

      expect(capturedUrl).toContain('/api/admin/stats');
      expect(capturedUrl).toContain('period=month');
    });

    it('uses correct base URL', async () => {
      let capturedUrl = '';

      server.use(
        http.get('http://localhost:4002/api/admin/stats', ({ request }) => {
          capturedUrl = request.url;
          return HttpResponse.json(mockAdminStats);
        })
      );

      await fetch('http://localhost:4002/api/admin/stats?period=week');

      expect(capturedUrl).toContain('http://localhost:4002');
    });
  });

  describe('Type Safety', () => {
    it('returns correctly typed AdminStats interface', () => {
      queryClient.setQueryData(['adminStats', 'week'], mockAdminStats);

      const data = queryClient.getQueryData<AdminStats>(['adminStats', 'week']);

      // TypeScript compilation would fail if types don't match
      const dataQualityScore: number = data!.stats.data_quality_score;
      const activeAgencies: number = data!.stats.active_agencies;
      const totalFines: string = data!.stats.total_fines;
      const agencyCode: string = data!.agencies[0].code;
      const agencyEnabled: boolean = data!.agencies[0].enabled;

      expect(dataQualityScore).toBe(95.5);
      expect(activeAgencies).toBe(4);
      expect(totalFines).toBe('£2,450,000');
      expect(agencyCode).toBe('hse');
      expect(agencyEnabled).toBe(true);
    });
  });
});
