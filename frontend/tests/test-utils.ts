import { QueryClient } from '@tanstack/svelte-query';

/**
 * Creates a fresh QueryClient for testing with optimized defaults
 * - Disables retries to prevent test timeouts
 * - Disables caching to ensure test isolation
 */
export function createTestQueryClient() {
	return new QueryClient({
		defaultOptions: {
			queries: {
				retry: false, // Disable retries in tests
				gcTime: 0, // Disable caching (previously cacheTime)
				staleTime: 0
			},
			mutations: {
				retry: false
			}
		}
	});
}

/**
 * Helper to wait for a condition to be true
 * @param condition - Function that returns true when condition is met
 * @param timeout - Maximum time to wait in milliseconds
 */
export async function waitForCondition(
	condition: () => boolean,
	timeout = 5000
): Promise<void> {
	const startTime = Date.now();
	while (!condition()) {
		if (Date.now() - startTime > timeout) {
			throw new Error('Timeout waiting for condition');
		}
		await new Promise((resolve) => setTimeout(resolve, 50));
	}
}
