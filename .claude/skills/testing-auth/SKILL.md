# SKILL: Testing Phoenix LiveView with Authentication

**Purpose:** Guide for writing tests for Phoenix LiveView routes that require authentication, particularly with AshAuthentication and LiveView sessions.

**Context:** Phoenix LiveView + AshAuthentication + Test Environment

---

## Core Principles

### 1. Understand the Authentication Flow

**HTTP Request → LiveView Flow:**

```
1. Browser Pipeline (:browser)
   ↓
2. Plug: :load_current_user sets conn.assigns.current_user
   ↓
3. LiveView Session Function: generate_session/3 reads conn.assigns
   ↓
4. LiveView mount - Router Hook: AshAuthentication.Phoenix.LiveSession
   ↓
5. LiveView mount - Your LiveView code (can access socket.assigns.current_user)
```

**Critical Understanding:**
- `conn.assigns.current_user` must be set BEFORE LiveView mount
- `AshAuthentication.Phoenix.LiveSession.generate_session/3` reads from `conn.assigns`
- The LiveView session hook converts session data to `socket.assigns.current_user`
- If `conn.assigns.current_user` isn't set, the LiveView session will be empty

---

## 2. Common Pitfalls & Solutions

### ❌ Pitfall 1: Only Using `store_in_session`

```elixir
# WRONG - This doesn't set conn.assigns.current_user
conn =
  conn
  |> Phoenix.ConnTest.init_test_session(%{})
  |> AshAuthentication.Plug.Helpers.store_in_session(user)
```

**Why it fails:**
- `store_in_session` puts user in Plug session storage
- `generate_session/3` reads from `conn.assigns`, not Plug session
- LiveView session never gets user data
- Result: `KeyError: key :current_user not found in socket.assigns`

**✅ Correct Pattern:**
```elixir
conn =
  conn
  |> Phoenix.ConnTest.init_test_session(%{})
  |> assign(:current_user, user)  # ← CRITICAL: For generate_session
  |> AshAuthentication.Plug.Helpers.store_in_session(user)  # For Plug session
```

### ❌ Pitfall 2: Global Hooks Applied Everywhere

```elixir
# WRONG - in lib/my_app_web.ex
def live_view do
  quote do
    use Phoenix.LiveView
    on_mount {MyApp.SomeHook, :some_option}  # Applied to ALL LiveViews
  end
end
```

**Why it's problematic:**
- Applies hooks to admin routes, API routes, internal tools
- Can interfere with authentication when hooks run in wrong order
- Creates unnecessary overhead

**✅ Correct Pattern:**
```elixir
# In router.ex - Apply hooks conditionally per live_session
live_session :public,
  on_mount: [
    AshAuthentication.Phoenix.LiveSession,  # Auth first
    {MyApp.SomeHook, :some_option}          # App features second
  ],
  session: {AshAuthentication.Phoenix.LiveSession, :generate_session, []}

live_session :admin,
  on_mount: [
    AshAuthentication.Phoenix.LiveSession  # Only auth - no app hooks
  ],
  session: {AshAuthentication.Phoenix.LiveSession, :generate_session, []}
```

### ❌ Pitfall 3: Type Mismatches in Config Defaults

```elixir
# WRONG - Default is map, code expects keyword list
config = Application.get_env(:my_app, :some_config, %{})
value = Keyword.get(config, :key, [])  # FunctionClauseError!
```

**Why it fails:**
- In test environment, config often isn't set
- `Application.get_env/3` returns default value `%{}`
- `Keyword.get/3` expects keyword list, not map
- Result: `FunctionClauseError: no function clause matching in Keyword.get/3`

**✅ Correct Pattern:**
```elixir
# Use keyword list as default
config = Application.get_env(:my_app, :some_config, [])
value = Keyword.get(config, :key, [])
```

---

## 3. Test Setup Patterns

### Pattern A: Using Test Helpers (Recommended)

```elixir
defmodule MyAppWeb.Admin.SomeLiveTest do
  use MyAppWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "Admin LiveView" do
    setup :register_and_log_in_admin

    test "mounts successfully", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, "/admin/some-route")
      assert html =~ "Expected Content"
    end
  end
end
```

**Requirements for `register_and_log_in_admin` helper:**
```elixir
def register_and_log_in_admin(%{conn: conn}) do
  # 1. Create admin user
  admin = create_admin_user()

  # 2. Configure conn properly
  conn =
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> assign(:current_user, admin)  # ← For generate_session
    |> AshAuthentication.Plug.Helpers.store_in_session(admin)

  %{conn: conn, user: admin}
end
```

### Pattern B: Manual Setup (For Specific Tests)

```elixir
describe "Specific scenario" do
  setup %{conn: conn} do
    user = create_user(%{email: "test@example.com"})

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> assign(:current_user, user)

    %{conn: conn, user: user}
  end

  test "works with specific user", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/some-route")
    assert html =~ "Content"
  end
end
```

### Pattern C: Testing Unauthenticated Access

```elixir
describe "Unauthenticated access" do
  test "redirects to sign-in", %{conn: conn} do
    # Don't set up authentication - test redirect behavior
    {:error, {:redirect, %{to: redirect_path}}} = live(conn, "/admin/protected")
    assert redirect_path == "/sign-in"
  end
end
```

---

## 4. Creating Test Users

### With Ash Resources (No OAuth Actions)

If your User resource uses GitHub OAuth and doesn't have password auth in test:

```elixir
def create_test_user(attrs \\ %{}) do
  defaults = %{
    email: "test-#{System.unique_integer([:positive])}@example.com",
    github_id: "github-#{System.unique_integer([:positive])}",
    github_login: "testuser#{System.unique_integer([:positive])}",
    name: "Test User",
    is_admin: false
  }

  # Use Ash.Seed.seed! to bypass OAuth action requirement
  {:ok, user} =
    EhsEnforcement.Accounts.User
    |> Ash.Changeset.for_create(:register_with_github, Map.merge(defaults, attrs))
    |> Ash.Seed.seed!()

  user
end

def create_admin_user(attrs \\ %{}) do
  create_test_user(Map.merge(attrs, %{is_admin: true}))
end
```

**Why `Ash.Seed.seed!`:**
- Bypasses action requirements (like OAuth callbacks)
- Perfect for test data creation
- Skips validations that require external services

---

## 5. Debugging Test Failures

### KeyError: :current_user not found

**Symptom:**
```
** (KeyError) key :current_user not found in socket.assigns
```

**Check:**
1. Is `conn.assigns.current_user` set in test setup? ✓
2. Is `generate_session` reading from correct assigns? ✓
3. Is authentication hook running before LiveView mount? ✓
4. Are there global hooks interfering with auth flow? ✗

**Fix:** Add `assign(:current_user, user)` to conn setup

### Redirect to Sign-In

**Symptom:**
```
** (MatchError) no match of right hand side value:
  {:error, {:redirect, %{to: "/sign-in"}}}
```

**Check:**
1. Is user authenticated in test? ✗
2. Is `:admin_required` pipeline running? ✓
3. Does user have required permissions? ✗

**Fix:** Ensure proper authentication setup OR test the redirect behavior explicitly

### FunctionClauseError in Config

**Symptom:**
```
** (FunctionClauseError) no function clause matching in Keyword.get/3
```

**Check:**
1. Are config defaults keyword lists `[]` not maps `%{}`? ✗
2. Is test environment config set properly? ✗

**Fix:** Change default from `%{}` to `[]` in `Application.get_env/3`

---

## 6. Hook Execution Order

When multiple `on_mount` hooks are defined:

```elixir
live_session :example,
  on_mount: [
    FirstHook,              # Runs 1st
    {SecondHook, :option},  # Runs 2nd
    ThirdHook               # Runs 3rd
  ]
```

**Critical Rules:**
1. Hooks execute in array order
2. Each hook receives same `session` parameter (read-only)
3. Each hook must return `{:cont, socket}` or `{:halt, socket}`
4. If hook returns `{:halt, socket}`, subsequent hooks don't run
5. Router-level hooks run BEFORE module-level hooks

**Best Practice for Auth + Features:**
```elixir
on_mount: [
  AshAuthentication.Phoenix.LiveSession,  # 1st: Load user
  {MyApp.Features.Hook, :some_feature}    # 2nd: Use user data
]
```

---

## 7. Quick Reference

### Minimum Test Setup

```elixir
setup %{conn: conn} do
  user = create_user()

  conn =
    conn
    |> init_test_session(%{})
    |> assign(:current_user, user)

  %{conn: conn, user: user}
end
```

### Common Assertions

```elixir
# LiveView mounted successfully
{:ok, view, html} = live(conn, "/path")

# Check rendered content
assert html =~ "Expected Text"

# Check element exists
assert has_element?(view, "[data-testid='some-element']")

# Check socket assigns (indirectly - via successful mount)
# If mount succeeds without KeyError, assigns are correct

# Test redirect
{:error, {:redirect, %{to: path}}} = live(conn, "/protected")
assert path == "/sign-in"
```

---

## 8. Common Test File Structure

```elixir
defmodule MyAppWeb.SomeLiveTest do
  use MyAppWeb.ConnCase
  import Phoenix.LiveViewTest

  # Test authenticated routes
  describe "authenticated access" do
    setup :register_and_log_in_user

    test "mounts successfully", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, "/route")
      assert html =~ "Content"
    end

    test "handles user interactions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/route")

      # Trigger event
      html = render_click(view, "some-event", %{})
      assert html =~ "Updated Content"
    end
  end

  # Test admin-only routes
  describe "admin access" do
    setup :register_and_log_in_admin

    test "admin can access", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/route")
      assert html =~ "Admin Content"
    end
  end

  # Test unauthenticated access
  describe "unauthenticated access" do
    test "redirects to sign-in", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, "/protected")
      assert path == "/sign-in"
    end
  end

  # Test authorization failures
  describe "authorization" do
    setup :register_and_log_in_user  # Regular user, not admin

    test "non-admin cannot access admin routes", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, "/admin/route")
      assert path == "/sign-in"
    end
  end
end
```

---

## 9. Testing Checklist

Before writing authentication tests:

- [ ] Understand the authentication flow (HTTP → Plug → LiveView)
- [ ] Know which hooks are applied (router vs global)
- [ ] Create test helpers that set `conn.assigns.current_user`
- [ ] Use `Ash.Seed.seed!` for test data if OAuth is required
- [ ] Fix any config type mismatches (`%{}` → `[]`)
- [ ] Test both authenticated and unauthenticated scenarios
- [ ] Test authorization (regular user vs admin)
- [ ] Verify hooks execute in correct order

---

## 10. Real-World Example

From our EHS Enforcement project - the complete working pattern:

```elixir
# test/ehs_enforcement_web/live/admin/scrape_sessions_live_test.exs
defmodule EhsEnforcementWeb.Admin.ScrapeSessionsLiveTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "ScrapeSessionsLive (admin route)" do
    setup :register_and_log_in_admin

    test "mounts successfully with authenticated admin user", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/scrape-sessions")
      assert html =~ "Scraping Sessions"
    end

    test "handles filter changes without KeyError", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/scrape-sessions")
      html = render_change(view, "filter_status", %{"status" => "running"})
      assert html =~ "Scraping Sessions"
    end
  end

  describe "Other admin routes (working correctly)" do
    setup %{conn: conn} do
      admin = create_test_admin(%{
        email: "test-admin-#{System.unique_integer([:positive])}@example.com",
        github_login: "testadmin#{System.unique_integer([:positive])}"
      })

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> assign(:current_user, admin)  # ← CRITICAL

      %{conn: conn, user: admin}
    end

    test "admin dashboard mounts successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin")
      assert html =~ "Admin Dashboard"
    end
  end
end
```

---

## Summary

**Golden Rules:**
1. Always set `conn.assigns.current_user` in test setup
2. Apply hooks conditionally at router level, not globally
3. Use keyword list `[]` as default for config, not map `%{}`
4. Use `Ash.Seed.seed!` to bypass OAuth requirements in tests
5. Authentication hooks should run BEFORE feature hooks

**When tests fail with KeyError:**
- Check `conn.assigns.current_user` is set
- Check hooks are applied in correct order
- Check no global hooks interfering with auth

**When creating test helpers:**
- Set both `conn.assigns.current_user` AND Plug session
- Use unique identifiers to avoid conflicts
- Return both `conn` and `user` from setup

---

## Related Documentation

- Phoenix.LiveViewTest: Testing LiveViews
- AshAuthentication: Authentication setup
- Phoenix.ConnTest: Connection test helpers
- Session: 2025-11-07-fix-admin-auth-cookie-consent-conflict.md
- Session: 2025-11-07-fix-oauth-test-config-bug.md
