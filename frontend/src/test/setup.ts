// Vitest test setup file
import { expect, afterEach } from 'vitest';
import { cleanup } from '@testing-library/svelte';

// Cleanup after each test
afterEach(() => {
	cleanup();
});

// Add custom matchers if needed
expect.extend({});
