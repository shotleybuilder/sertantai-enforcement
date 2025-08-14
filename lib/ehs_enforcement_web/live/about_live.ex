defmodule EhsEnforcementWeb.AboutLive do
  use EhsEnforcementWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-8">
      <div class="bg-white shadow rounded-lg p-6">
        <h1 class="text-3xl font-bold text-gray-900 mb-6">About EHS Enforcement</h1>
        
        <div class="prose prose-lg text-gray-700 space-y-6">
          <p>
            Welcome to EHS Enforcement, a comprehensive platform for collecting and managing 
            UK environmental, health, and safety enforcement data.
          </p>
          
          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Our Mission</h2>
          <p>
            We provide transparency and insight into UK enforcement actions by collecting, 
            processing, and presenting enforcement data from various regulatory agencies 
            including HSE (Health and Safety Executive) and Environment Agency.
          </p>
          
          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">What We Do</h2>
          <ul class="list-disc pl-6 space-y-2">
            <li>Collect enforcement data from UK regulatory agencies</li>
            <li>Process and structure enforcement information</li>
            <li>Provide searchable database of cases and notices</li>
            <li>Generate reports and analytics on enforcement trends</li>
            <li>Maintain up-to-date information on offenders and violations</li>
          </ul>
          
          <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">Data Sources</h2>
          <p>
            Our data is collected from official government sources and regulatory agency websites, 
            ensuring accuracy and reliability. We continuously monitor these sources to provide 
            the most current information available.
          </p>
          
          <div class="bg-blue-50 border-l-4 border-blue-400 p-4 mt-8">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <p class="text-sm text-blue-700">
                  This platform is currently in active development. Features and data may change as we continue to improve our services.
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