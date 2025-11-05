defmodule EhsEnforcementWeb.Router do
  use EhsEnforcementWeb, :router
  use AshAuthentication.Phoenix.Router

  import EhsEnforcementWeb.Plugs.AuthHelpers, only: [load_current_user: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_cookies
    plug :fetch_live_flash
    plug :put_root_layout, html: {EhsEnforcementWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_current_user
    plug EhsEnforcement.Consent.Plug,
      resource: EhsEnforcement.Consent.ConsentSettings,
      user_id_key: :current_user,
      skip_session_cache: true
  end

  pipeline :auth_required do
    plug EhsEnforcementWeb.Plugs.AuthHelpers, :require_authenticated_user
  end

  pipeline :admin_required do
    plug EhsEnforcementWeb.Plugs.AuthHelpers, :require_authenticated_user
    plug EhsEnforcementWeb.Plugs.AuthHelpers, :require_admin_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  # Health check pipeline - no authentication required
  pipeline :health do
    plug :accepts, ["json"]
  end

  # Authentication routes
  scope "/", EhsEnforcementWeb do
    pipe_through :browser

    sign_in_route()
    sign_out_route(AuthController)
    auth_routes_for(EhsEnforcement.Accounts.User, to: AuthController)
    reset_route([])
  end

  # Public routes - no authentication required  
  scope "/", EhsEnforcementWeb do
    pipe_through :browser

    get "/home", PageController, :home

    live_session :public,
      on_mount: AshAuthentication.Phoenix.LiveSession,
      session: {AshAuthentication.Phoenix.LiveSession, :generate_session, []} do
      live "/", DashboardLive, :index
      live "/dashboard", DashboardLive, :index

      # Read-only Case Management Routes
      live "/cases", CaseLive.Index, :index
      live "/cases/:id", CaseLive.Show, :show

      # Read-only Notice Management Routes
      live "/notices", NoticeLive.Index, :index
      live "/notices/:id", NoticeLive.Show, :show

      # Read-only Offender Management Routes
      live "/offenders", OffenderLive.Index, :index
      live "/offenders/:id", OffenderLive.Show, :show

      # Read-only Legislation Management Routes
      live "/legislation", LegislationLive.Index, :index
      live "/legislation/:id", LegislationLive.Show, :show

      # Agency Management Routes (Open Access)
      live "/agencies", AgencyLive, :index

      # Reports & Analytics Routes (Open Access)
      live "/reports", ReportsLive.Index, :index
      live "/reports/offenders", ReportsLive.Offenders, :index

      # Static Pages (Open Access)
      live "/about", AboutLive, :index
      live "/docs", DocsLive, :index
      live "/privacy", PrivacyLive, :index
      live "/terms", TermsLive, :index
      live "/support", SupportLive, :index
      live "/contact", ContactLive, :index
    end

    # Non-LiveView routes
    get "/cases/export.csv", CaseController, :export_csv
    get "/cases/export.xlsx", CaseController, :export_excel
    get "/cases/export_detailed.csv", CaseController, :export_detailed_csv

    # Cookie consent route
    post "/consent", ConsentController, :create
  end

  # Admin-only routes - require authentication and admin privileges
  scope "/", EhsEnforcementWeb do
    pipe_through [:browser, :admin_required]

    live_session :admin,
      on_mount: [
        AshAuthentication.Phoenix.LiveSession,
        {AshCookieConsent.LiveView.Hook, :load_consent}
      ],
      session: {AshAuthentication.Phoenix.LiveSession, :generate_session, []} do
      # Admin Case Management Routes  
      # Redirect /admin/cases to the main cases page since we removed the separate admin index
      get "/admin/cases", PageController, :redirect_to_cases
      live "/admin/cases/:id/edit", Admin.CaseLive.Edit, :edit

      # Admin Notice Management Routes
      live "/admin/notices/:id/edit", Admin.NoticeLive.Edit, :edit

      # Admin Offender Management Routes
      live "/admin/offenders/:id/edit", Admin.OffenderLive.Edit, :edit

      # Admin Legislation Management Routes
      # TODO: Implement Admin.LegislationLive modules
      # live "/admin/legislation", Admin.LegislationLive.Index, :index
      # live "/admin/legislation/new", Admin.LegislationLive.New, :new
      # live "/admin/legislation/:id/edit", Admin.LegislationLive.Edit, :edit

      # Admin Dashboard
      live "/admin", Admin.DashboardLive, :index

      # Admin Duplicate Management
      live "/admin/duplicates", Admin.DuplicatesLive, :index

      # Admin Agency Management Routes
      live "/admin/agencies", Admin.AgencyLive.Index, :index
      live "/admin/agencies/new", Admin.AgencyLive.New, :new
      live "/admin/agencies/:id/edit", Admin.AgencyLive.Edit, :edit

      # Admin Configuration Management Routes
      live "/admin/config", Admin.ConfigLive.Index, :index
      live "/admin/config/scraping", Admin.ConfigLive.Scraping, :edit
      live "/admin/config/scraping/new", Admin.ConfigLive.Scraping, :new

      # Admin Scraping Management Routes
      live "/admin/scrape-sessions", Admin.ScrapeSessionsLive, :index
      live "/admin/scrape-sessions-design", Admin.ScrapeSessionsDesignLive, :index
      live "/admin/scrape-sessions/monitor", Admin.ScrapingLive.Index, :index

      # Unified Scraping Interface (Strategy Pattern)
      live "/admin/scrape", Admin.ScrapeLive, :index
    end
  end

  # Health check endpoint - no authentication required
  scope "/", EhsEnforcementWeb do
    pipe_through :health

    get "/health", HealthController, :check
  end

  # Other scopes may use custom stacks.
  # scope "/api", EhsEnforcementWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:ehs_enforcement, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: EhsEnforcementWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
