import { expect, afterEach, vi } from 'vitest';
import { cleanup } from '@testing-library/svelte';
import '@testing-library/jest-dom';

// Cleanup after each test
afterEach(() => {
	cleanup();
});

// Mock SvelteKit modules
vi.mock('$app/environment', () => ({
	browser: true, // Set to true for client-side rendering in tests
	dev: true,
	building: false,
	version: 'test'
}));

vi.mock('$app/navigation', () => ({
	goto: vi.fn(),
	invalidate: vi.fn(),
	invalidateAll: vi.fn(),
	preloadData: vi.fn(),
	preloadCode: vi.fn(),
	beforeNavigate: vi.fn(),
	afterNavigate: vi.fn()
}));

vi.mock('$app/stores', () => {
	const readable = (value: any) => ({
		subscribe: (fn: any) => {
			fn(value);
			return () => {};
		}
	});

	return {
		page: readable({ url: new URL('http://localhost'), params: {} }),
		navigating: readable(null),
		updated: readable(false)
	};
});
