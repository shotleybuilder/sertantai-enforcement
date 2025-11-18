import { defineConfig } from 'vitest/config';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import path from 'path';

export default defineConfig({
	plugins: [svelte({ hot: !process.env.VITEST })],
	test: {
		environment: 'jsdom',
		globals: true,
		setupFiles: ['./tests/setup.ts'],
		include: ['src/**/*.{test,spec}.{js,ts}'],
		coverage: {
			provider: 'v8',
			reporter: ['text', 'json', 'html'],
			exclude: [
				'node_modules/',
				'tests/',
				'**/*.d.ts',
				'**/*.config.*',
				'**/mockData',
				'**/.svelte-kit/**'
			]
		},
		// Add pool options to help with Node 18 compatibility
		pool: 'forks',
		poolOptions: {
			forks: {
				singleFork: true
			}
		}
	},
	resolve: {
		alias: {
			$lib: path.resolve('./src/lib'),
			$app: path.resolve('./node_modules/@sveltejs/kit/src/runtime/app'),
			'$env/static/public': path.resolve('./tests/mocks/env-static-public.ts')
		}
	}
});
