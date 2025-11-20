<script lang="ts">
	// mdsvex passes frontmatter as props using Svelte 4 syntax
	export let title = 'EHS Enforcement Tracker'
	export let description = 'UK enforcement data tracking platform'

	// Full title with site name
	$: fullTitle = title === 'EHS Enforcement Tracker' ? title : `${title} | EHS Enforcement Tracker`
</script>

<svelte:head>
	<title>{fullTitle}</title>
	<meta name="description" content={description} />
</svelte:head>

<div class="min-h-screen bg-gray-50">
	<!-- Header Navigation -->
	<nav class="bg-white border-b border-gray-200">
		<div class="container mx-auto px-4 py-4">
			<div class="flex items-center justify-between">
				<a href="/" class="text-xl font-bold text-gray-900">EHS Enforcement Tracker</a>
				<div class="flex gap-6">
					<a href="/cases" class="text-gray-600 hover:text-gray-900">Cases</a>
					<a href="/notices" class="text-gray-600 hover:text-gray-900">Notices</a>
					<a href="/offenders" class="text-gray-600 hover:text-gray-900">Offenders</a>
					<a href="/agencies" class="text-gray-600 hover:text-gray-900">Agencies</a>
					<a href="/legislation" class="text-gray-600 hover:text-gray-900">Legislation</a>
				</div>
			</div>
		</div>
	</nav>

	<!-- Main Content Area -->
	<main class="container mx-auto px-4 py-8 max-w-4xl">
		<!-- Markdown Content with Tailwind Typography -->
		<article class="prose prose-lg prose-slate max-w-none">
			<slot />
		</article>
	</main>

	<!-- Footer -->
	<footer class="bg-white border-t border-gray-200 mt-16">
		<div class="container mx-auto px-4 py-8">
			<div class="flex justify-between items-center text-sm text-gray-600">
				<p>&copy; {new Date().getFullYear()} EHS Enforcement Tracker</p>
				<div class="flex gap-6">
					<a href="/about" class="hover:text-gray-900">About</a>
					<a href="/privacy" class="hover:text-gray-900">Privacy</a>
					<a href="/terms" class="hover:text-gray-900">Terms</a>
					<a href="/contact" class="hover:text-gray-900">Contact</a>
				</div>
			</div>
		</div>
	</footer>
</div>

