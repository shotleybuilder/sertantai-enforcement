<script lang="ts">
	import { onMount } from 'svelte'

	let formData = {
		name: '',
		email: '',
		subject: '',
		message: ''
	}

	let formStatus: 'idle' | 'submitting' | 'success' | 'error' = 'idle'
	let formMessage = ''

	function handleSubmit(event: Event) {
		event.preventDefault()
		formStatus = 'submitting'

		// Simulate form submission (in real app, this would send to backend)
		setTimeout(() => {
			formStatus = 'success'
			formMessage = 'Thank you for your message. We\'ll get back to you soon!'

			// Reset form
			formData = {
				name: '',
				email: '',
				subject: '',
				message: ''
			}
		}, 1000)
	}
</script>

<svelte:head>
	<title>Contact Us | EHS Enforcement Tracker</title>
	<meta name="description" content="Get in touch with EHS Enforcement for support, feedback, or inquiries" />
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

	<!-- Main Content -->
	<main class="container mx-auto px-4 py-8 max-w-5xl">
		<div class="bg-white shadow rounded-lg p-8">
			<h1 class="text-3xl font-bold text-gray-900 mb-6">Contact Us</h1>

			<div class="prose prose-lg text-gray-700 mb-8">
				<p>
					We'd love to hear from you. Get in touch with us for support, feedback, or general
					inquiries.
				</p>
			</div>

			<div class="grid md:grid-cols-2 gap-8">
				<!-- Contact Form -->
				<div>
					<h2 class="text-2xl font-semibold text-gray-900 mb-4">Send us a message</h2>

					<form onsubmit={handleSubmit} class="space-y-4">
						<div>
							<label for="name" class="block text-sm font-medium text-gray-700 mb-1">
								Name *
							</label>
							<input
								type="text"
								id="name"
								name="name"
								required
								bind:value={formData.name}
								class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
							/>
						</div>

						<div>
							<label for="email" class="block text-sm font-medium text-gray-700 mb-1">
								Email *
							</label>
							<input
								type="email"
								id="email"
								name="email"
								required
								bind:value={formData.email}
								class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
							/>
						</div>

						<div>
							<label for="subject" class="block text-sm font-medium text-gray-700 mb-1">
								Subject *
							</label>
							<select
								id="subject"
								name="subject"
								required
								bind:value={formData.subject}
								class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
							>
								<option value="">Select a subject</option>
								<option value="support">Technical Support</option>
								<option value="data">Data Inquiry</option>
								<option value="feature">Feature Request</option>
								<option value="api">API Access</option>
								<option value="partnership">Partnership</option>
								<option value="other">Other</option>
							</select>
						</div>

						<div>
							<label for="message" class="block text-sm font-medium text-gray-700 mb-1">
								Message *
							</label>
							<textarea
								id="message"
								name="message"
								rows={5}
								required
								bind:value={formData.message}
								class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
								placeholder="Please provide details about your inquiry..."
							></textarea>
						</div>

						<button
							type="submit"
							disabled={formStatus === 'submitting'}
							class="w-full bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors duration-200 disabled:opacity-50"
						>
							{formStatus === 'submitting' ? 'Sending...' : 'Send Message'}
						</button>
					</form>

					{#if formStatus === 'success'}
						<div class="mt-4 p-3 bg-green-50 border border-green-200 rounded-md">
							<p class="text-sm text-green-700">{formMessage}</p>
						</div>
					{/if}

					<div class="mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded-md">
						<p class="text-sm text-yellow-700 flex items-start">
							<svg class="inline h-4 w-4 mr-1 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
								<path
									fill-rule="evenodd"
									d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
									clip-rule="evenodd"
								/>
							</svg>
							Contact form is currently under development. Please use the email contact below.
						</p>
					</div>
				</div>

				<!-- Contact Information -->
				<div>
					<h2 class="text-2xl font-semibold text-gray-900 mb-4">Get in touch</h2>

					<div class="space-y-6">
						<div class="flex items-start">
							<div class="flex-shrink-0">
								<svg
									class="h-6 w-6 text-blue-600"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M3 8l7.89 7.89a1 1 0 001.41 0L21 7M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
									/>
								</svg>
							</div>
							<div class="ml-3">
								<h3 class="text-lg font-medium text-gray-900">Email</h3>
								<p class="text-gray-600">support@ehsenforcement.co.uk</p>
								<p class="text-sm text-gray-500 mt-1">We typically respond within 24 hours</p>
							</div>
						</div>

						<div class="flex items-start">
							<div class="flex-shrink-0">
								<svg
									class="h-6 w-6 text-blue-600"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
									/>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
									/>
								</svg>
							</div>
							<div class="ml-3">
								<h3 class="text-lg font-medium text-gray-900">Location</h3>
								<p class="text-gray-600">United Kingdom</p>
								<p class="text-sm text-gray-500 mt-1">Remote-first organization</p>
							</div>
						</div>

						<div class="flex items-start">
							<div class="flex-shrink-0">
								<svg
									class="h-6 w-6 text-blue-600"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
									/>
								</svg>
							</div>
							<div class="ml-3">
								<h3 class="text-lg font-medium text-gray-900">Response Time</h3>
								<p class="text-gray-600">Business hours: 9 AM - 6 PM GMT</p>
								<p class="text-sm text-gray-500 mt-1">Monday to Friday</p>
							</div>
						</div>
					</div>

					<div class="mt-8 p-4 bg-blue-50 rounded-lg">
						<h3 class="font-medium text-blue-900 mb-2">Need immediate help?</h3>
						<p class="text-sm text-blue-700 mb-3">
							Check our <a href="/support" class="underline hover:text-blue-800">Support page</a>
							for frequently asked questions and troubleshooting guides.
						</p>
						<p class="text-sm text-blue-700">
							For technical documentation, visit our
							<a href="/docs" class="underline hover:text-blue-800">Documentation</a> section.
						</p>
					</div>
				</div>
			</div>

			<!-- Response Times -->
			<div class="border-t border-gray-200 pt-6 mt-8">
				<h2 class="text-2xl font-semibold text-gray-900 mb-4">About Response Times</h2>
				<div class="grid sm:grid-cols-2 gap-4 text-sm">
					<div class="bg-green-50 border border-green-200 rounded-md p-3">
						<h4 class="font-medium text-green-900">Technical Support</h4>
						<p class="text-green-700">Within 24 hours</p>
					</div>
					<div class="bg-blue-50 border border-blue-200 rounded-md p-3">
						<h4 class="font-medium text-blue-900">General Inquiries</h4>
						<p class="text-blue-700">Within 2-3 business days</p>
					</div>
					<div class="bg-purple-50 border border-purple-200 rounded-md p-3">
						<h4 class="font-medium text-purple-900">Partnership Requests</h4>
						<p class="text-purple-700">Within 1 week</p>
					</div>
					<div class="bg-orange-50 border border-orange-200 rounded-md p-3">
						<h4 class="font-medium text-orange-900">Feature Requests</h4>
						<p class="text-orange-700">Acknowledged within 48 hours</p>
					</div>
				</div>
			</div>
		</div>
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
