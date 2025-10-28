defmodule EhsEnforcementWeb.SupportLive do
  use EhsEnforcementWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-8">
      <div class="bg-white shadow rounded-lg p-6">
        <h1 class="text-3xl font-bold text-gray-900 mb-6">Support</h1>

        <div class="prose prose-lg text-gray-700 space-y-6">
          <p>
            Need help using the EHS Enforcement platform? We're here to assist you.
          </p>

          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Frequently Asked Questions</h2>

          <div class="space-y-6">
            <div class="border-l-4 border-blue-400 bg-blue-50 p-4">
              <h3 class="font-semibold text-gray-900 mb-2">How often is the data updated?</h3>
              <p class="text-gray-700">
                Our data is updated regularly through automated scraping of regulatory agency websites.
                Most data is refreshed daily, with some sources updated multiple times per day.
              </p>
            </div>

            <div class="border-l-4 border-blue-400 bg-blue-50 p-4">
              <h3 class="font-semibold text-gray-900 mb-2">Can I export search results?</h3>
              <p class="text-gray-700">
                Yes, you can export search results in CSV and Excel formats. Look for export buttons
                on the search results pages.
              </p>
            </div>

            <div class="border-l-4 border-blue-400 bg-blue-50 p-4">
              <h3 class="font-semibold text-gray-900 mb-2">Is there an API available?</h3>
              <p class="text-gray-700">
                API access is planned for future releases. If you're interested in programmatic
                access to our data, please
                <.link navigate={~p"/contact"} class="text-blue-600 hover:text-blue-800 underline">
                  contact us
                </.link>
                for early access opportunities.
              </p>
            </div>

            <div class="border-l-4 border-blue-400 bg-blue-50 p-4">
              <h3 class="font-semibold text-gray-900 mb-2">How accurate is the data?</h3>
              <p class="text-gray-700">
                All data is sourced directly from official government and regulatory agency websites.
                While we process and structure the data for easier access, the underlying information
                comes from authoritative sources.
              </p>
            </div>

            <div class="border-l-4 border-blue-400 bg-blue-50 p-4">
              <h3 class="font-semibold text-gray-900 mb-2">
                Can I request specific data or features?
              </h3>
              <p class="text-gray-700">
                We welcome feedback and feature requests. Please
                <.link navigate={~p"/contact"} class="text-blue-600 hover:text-blue-800 underline">
                  contact us
                </.link>
                with your suggestions.
              </p>
            </div>
          </div>

          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Getting Help</h2>

          <div class="grid md:grid-cols-2 gap-6">
            <div class="bg-gray-50 rounded-lg p-6">
              <h3 class="font-semibold text-gray-900 mb-3 flex items-center">
                <svg
                  class="h-5 w-5 text-blue-500 mr-2"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"
                  />
                </svg>
                Documentation
              </h3>
              <p class="text-gray-700 mb-3">
                Check our comprehensive
                <.link navigate={~p"/docs"} class="text-blue-600 hover:text-blue-800 underline">
                  documentation
                </.link>
                for detailed guides and tutorials.
              </p>
            </div>

            <div class="bg-gray-50 rounded-lg p-6">
              <h3 class="font-semibold text-gray-900 mb-3 flex items-center">
                <svg
                  class="h-5 w-5 text-blue-500 mr-2"
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
                Direct Contact
              </h3>
              <p class="text-gray-700 mb-3">
                Still need help?
                <.link navigate={~p"/contact"} class="text-blue-600 hover:text-blue-800 underline">
                  Send us a message
                </.link>
                and we'll get back to you as soon as possible.
              </p>
            </div>
          </div>

          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Troubleshooting</h2>

          <div class="bg-yellow-50 border border-yellow-200 rounded-md p-4">
            <h3 class="font-semibold text-gray-900 mb-2">Common Issues</h3>
            <ul class="list-disc pl-6 space-y-1 text-gray-700">
              <li>Clear your browser cache if you experience loading issues</li>
              <li>Ensure JavaScript is enabled for full functionality</li>
              <li>Try refreshing the page if data appears outdated</li>
              <li>Use a modern browser (Chrome, Firefox, Safari, Edge) for best performance</li>
            </ul>
          </div>

          <div class="bg-green-50 border border-green-200 rounded-md p-4 mt-6">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                    clip-rule="evenodd"
                  />
                </svg>
              </div>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-green-800">
                  Platform Status
                </h3>
                <div class="mt-2 text-sm text-green-700">
                  <p>
                    All systems operational. Data last updated: <span class="font-medium">Today</span>
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
