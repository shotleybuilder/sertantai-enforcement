defmodule EhsEnforcementWeb.TermsLive do
  use EhsEnforcementWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-8">
      <div class="bg-white shadow rounded-lg p-6">
        <h1 class="text-3xl font-bold text-gray-900 mb-6">Terms of Service</h1>
        
        <div class="prose prose-lg text-gray-700 space-y-6">
          <p class="text-sm text-gray-500 mb-6">Last updated: January 14, 2025</p>
          
          <p>
            These Terms of Service ("Terms") govern your use of the EHS Enforcement platform 
            ("Service") operated by us ("we", "our", or "us").
          </p>
          
          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Acceptance of Terms</h2>
          <p>
            By accessing and using our Service, you accept and agree to be bound by the terms 
            and provision of this agreement. If you do not agree to these Terms, please do not use our Service.
          </p>
          
          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Use of Service</h2>
          
          <h3 class="text-xl font-semibold text-gray-900 mt-6 mb-3">Permitted Use</h3>
          <p>You may use our Service to:</p>
          <ul class="list-disc pl-6 space-y-2">
            <li>Access and search publicly available enforcement data</li>
            <li>Generate reports and analytics for legitimate research or business purposes</li>
            <li>Export data in accordance with our export policies</li>
          </ul>
          
          <h3 class="text-xl font-semibold text-gray-900 mt-6 mb-3">Prohibited Use</h3>
          <p>You may not:</p>
          <ul class="list-disc pl-6 space-y-2">
            <li>Use automated systems to scrape or harvest data beyond reasonable limits</li>
            <li>Attempt to reverse engineer, hack, or compromise the platform</li>
            <li>Use the Service for any illegal or unauthorized purpose</li>
            <li>Transmit viruses, malware, or other harmful content</li>
            <li>Impersonate others or provide false information</li>
          </ul>
          
          <h2 class="text-2xl font-semibent text-gray-900 mt-8 mb-4">Data and Content</h2>
          
          <h3 class="text-xl font-semibold text-gray-900 mt-6 mb-3">Public Data</h3>
          <p>
            The enforcement data displayed on our platform is sourced from publicly available 
            government and regulatory agency websites. We do not claim ownership of this data.
          </p>
          
          <h3 class="text-xl font-semibold text-gray-900 mt-6 mb-3">Data Accuracy</h3>
          <p>
            While we strive to provide accurate and up-to-date information, we cannot guarantee 
            the completeness or accuracy of all data. Users should verify information with 
            original sources when necessary.
          </p>
          
          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Service Availability</h2>
          <p>
            We aim to provide continuous service availability but cannot guarantee uninterrupted access. 
            The Service may be temporarily unavailable for maintenance, updates, or due to circumstances 
            beyond our control.
          </p>
          
          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Privacy</h2>
          <p>
            Your privacy is important to us. Please review our <.link navigate={~p"/privacy"} class="text-blue-600 hover:text-blue-800 underline">Privacy Policy</.link>, 
            which also governs your use of the Service.
          </p>
          
          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Disclaimers</h2>
          <p>
            The Service is provided "as is" without warranties of any kind. We disclaim all 
            warranties, express or implied, including warranties of merchantability, fitness 
            for a particular purpose, and non-infringement.
          </p>
          
          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Limitation of Liability</h2>
          <p>
            In no event shall we be liable for any indirect, incidental, special, consequential, 
            or punitive damages arising out of or relating to your use of the Service.
          </p>
          
          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Termination</h2>
          <p>
            We may terminate or suspend access to our Service immediately, without prior notice, 
            for any reason, including breach of these Terms.
          </p>
          
          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Changes to Terms</h2>
          <p>
            We reserve the right to modify these Terms at any time. Changes will be effective 
            immediately upon posting on this page.
          </p>
          
          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Contact Information</h2>
          <p>
            If you have questions about these Terms, please <.link navigate={~p"/contact"} class="text-blue-600 hover:text-blue-800 underline">contact us</.link>.
          </p>
          
          <div class="bg-blue-50 border-l-4 border-blue-400 p-4 mt-8">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <p class="text-sm text-blue-700">
                  By continuing to use our Service after any modifications to these Terms, 
                  you agree to be bound by the revised Terms.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end