defmodule EhsEnforcementWeb.PageController do
  use EhsEnforcementWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def redirect_to_cases(conn, _params) do
    # Redirect /admin/cases to the main cases page since we removed the separate admin index
    redirect(conn, to: ~p"/cases")
  end
end
