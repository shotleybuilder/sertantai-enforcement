defmodule EhsEnforcementWeb.DocsLive do
  use EhsEnforcementWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-8">
      <div class="bg-white shadow rounded-lg p-6">
        <h1 class="text-3xl font-bold text-gray-900 mb-6">Documentation</h1>

        <div class="prose prose-lg text-gray-700 space-y-6">
          <p>
            This documentation provides guidance on using the EHS Enforcement platform effectively.
          </p>

          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Getting Started</h2>
          <p>
            The EHS Enforcement platform provides access to enforcement data from UK regulatory agencies.
            You can search, filter, and analyze enforcement cases and notices.
          </p>

          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Navigation</h2>
          <ul class="list-disc pl-6 space-y-2">
            <li>
              <strong>Dashboard:</strong> Overview of recent enforcement activity and key statistics
            </li>
            <li>
              <strong>Cases:</strong> Search and view enforcement cases with detailed information
            </li>
            <li><strong>Notices:</strong> Browse improvement and prohibition notices</li>
            <li>
              <strong>Offenders:</strong> View organizations that have received enforcement actions
            </li>
            <li><strong>Reports:</strong> Access analytical reports and data insights</li>
            <li><strong>Agencies:</strong> Information about regulatory agencies</li>
          </ul>

          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Search Features</h2>
          <p>
            Use the search functionality to find specific cases or notices. You can filter by:
          </p>
          <ul class="list-disc pl-6 space-y-2">
            <li>Date range</li>
            <li>Regulatory agency</li>
            <li>Offender name</li>
            <li>Location</li>
            <li>Violation type</li>
          </ul>

          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Data Export</h2>
          <p>
            Export search results and reports in various formats including CSV and Excel for further analysis.
          </p>

          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">API Access</h2>
          <div class="bg-yellow-50 border-l-4 border-yellow-400 p-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                  <path
                    fill-rule="evenodd"
                    d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
                    clip-rule="evenodd"
                  />
                </svg>
              </div>
              <div class="ml-3">
                <p class="text-sm text-yellow-700">
                  API access is planned for future releases. Contact support for early access opportunities.
                </p>
              </div>
            </div>
          </div>

          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Support</h2>
          <p>
            If you need assistance using the platform, please visit our
            <.link navigate={~p"/support"} class="text-blue-600 hover:text-blue-800 underline">
              Support page
            </.link>
            or
            <.link navigate={~p"/contact"} class="text-blue-600 hover:text-blue-800 underline">
              contact us
            </.link>
            directly.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
