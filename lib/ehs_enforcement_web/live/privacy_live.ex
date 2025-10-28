defmodule EhsEnforcementWeb.PrivacyLive do
  use EhsEnforcementWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-8">
      <div class="bg-white shadow rounded-lg p-6">
        <h1 class="text-3xl font-bold text-gray-900 mb-6">Privacy Policy</h1>

        <div class="prose prose-lg text-gray-700 space-y-6">
          <p class="text-sm text-gray-500 mb-6">Last updated: January 14, 2025</p>

          <p>
            This Privacy Policy describes how EHS Enforcement ("we", "our", or "us") collects,
            uses, and protects your information when you use our service.
          </p>

          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Information We Collect</h2>

          <h3 class="text-xl font-semibold text-gray-900 mt-6 mb-3">Public Enforcement Data</h3>
          <p>
            We collect and process publicly available enforcement data from UK regulatory agencies,
            including but not limited to:
          </p>
          <ul class="list-disc pl-6 space-y-2">
            <li>Health and Safety Executive (HSE) enforcement cases and notices</li>
            <li>Environment Agency enforcement actions</li>
            <li>Other regulatory agency enforcement data</li>
          </ul>

          <h3 class="text-xl font-semibold text-gray-900 mt-6 mb-3">Usage Information</h3>
          <p>
            When you use our service, we may collect:
          </p>
          <ul class="list-disc pl-6 space-y-2">
            <li>Pages visited and features used</li>
            <li>Search queries and filters applied</li>
            <li>Time spent on the platform</li>
            <li>Browser and device information</li>
          </ul>

          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">How We Use Information</h2>
          <ul class="list-disc pl-6 space-y-2">
            <li>Provide access to enforcement data and analytics</li>
            <li>Improve platform functionality and user experience</li>
            <li>Generate usage statistics and platform insights</li>
            <li>Ensure platform security and prevent misuse</li>
          </ul>

          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Data Sharing</h2>
          <p>
            We do not sell, trade, or rent your personal information to third parties.
            The enforcement data we display is already publicly available from government sources.
          </p>

          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Data Security</h2>
          <p>
            We implement appropriate security measures to protect your information and
            maintain the integrity of our platform. However, no method of transmission
            over the internet is 100% secure.
          </p>

          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Cookies and Tracking</h2>
          <p>
            We use essential cookies to ensure the proper functioning of our platform.
            We do not use tracking cookies for advertising purposes.
          </p>

          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Your Rights</h2>
          <p>You have the right to:</p>
          <ul class="list-disc pl-6 space-y-2">
            <li>Access information about how your data is used</li>
            <li>Request correction of inaccurate information</li>
            <li>Request deletion of your data where applicable</li>
            <li>Object to processing of your data</li>
          </ul>

          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Contact Us</h2>
          <p>
            If you have questions about this Privacy Policy, please <.link
              navigate={~p"/contact"}
              class="text-blue-600 hover:text-blue-800 underline"
            >contact us</.link>.
          </p>

          <div class="bg-gray-50 border border-gray-200 rounded-md p-4 mt-8">
            <p class="text-sm text-gray-600">
              This Privacy Policy may be updated from time to time. We will notify users of
              any significant changes by posting the new policy on this page.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
