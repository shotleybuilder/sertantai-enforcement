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

### ❌ Pitfall 1: Using `session: generate_session` with JTI Session Identifiers

**CRITICAL DISCOVERY (2025-11-07):** When your User resource is configured with `session_identifier(:jti)`, the `session: {AshAuthentication.Phoenix.LiveSession, :generate_session, []}` callback is **incompatible** with OAuth authentication!

```elixir
# BROKEN ROUTER CONFIGURATION
live_session :admin,
  on_mount: [AshAuthentication.Phoenix.LiveSession],
  session: {AshAuthentication.Phoenix.LiveSession, :generate_session, []} do  # ← BREAKS JTI AUTH!
```

**Why it fails:**
1. OAuth creates user with JWT token containing JTI claim
2. `store_in_session` correctly formats session as `"jti:subject"` (e.g., `"31qrgh...:user?id=123"`)
3. But `generate_session` callback reads `conn.assigns.current_user` and calls `user_to_subject`
4. `user_to_subject` returns `"user?id=123"` (NO JTI PREFIX)
5. Phoenix LiveView merges sessions with callback result **OVERRIDING** the Plug session
6. `on_mount` hook tries to parse session expecting JTI format → FAILS
7. Result: `current_user` never gets set → `KeyError: key :current_user not found in socket.assigns`

**✅ Correct Pattern for OAuth with JTI:**
```elixir
# FIXED ROUTER CONFIGURATION
live_session :admin,
  on_mount: [AshAuthentication.Phoenix.LiveSession] do  # ← NO session: callback!
  # Routes...
end

# TEST SETUP
conn =
  conn
  |> Phoenix.ConnTest.init_test_session(%{})
  |> AshAuthentication.Plug.Helpers.store_in_session(user)  # ← Correctly formats with JTI
  # DO NOT add assign(:current_user) when using JTI!
```

**When to use each approach:**

| Session Identifier | Router Config | Test Setup |
|-------------------|---------------|------------|
| `session_identifier(:unsafe)` | Include `session: generate_session` | `assign(:current_user) + store_in_session` |
| `session_identifier(:jti)` | **NO** `session:` callback | `store_in_session` ONLY |

**See:** `.claude/sessions/2025-11-07-fix-admin-auth-cookie-consent-conflict.md` for full root cause analysis.

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

**Requirements for `register_and_log_in_admin` helper (JTI Session Identifiers):**
```elixir
def register_and_log_in_admin(%{conn: conn} = context) do
  # 1. Create admin user with OAuth action (generates JWT token with JTI)
  user_info = %{
    "email" => "admin@example.com",
    "name" => "Admin User",
    "login" => "adminuser",
    "id" => 12_345
  }

  oauth_tokens = %{
    "access_token" => "test_access_token",
    "token_type" => "Bearer"
  }

  {:ok, user} = Ash.create(
    EhsEnforcement.Accounts.User,
    %{user_info: user_info, oauth_tokens: oauth_tokens},
    action: :register_with_github
  )

  # 2. Update to admin status
  {:ok, admin_user} = Ash.update(
    user,
    %{is_admin: true, admin_checked_at: DateTime.utc_now()},
    action: :update_admin_status,
    actor: user
  )

  # 3. Configure conn - store_in_session will format with JTI
  new_conn =
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(admin_user)
    # DO NOT add assign(:current_user) - it breaks JTI session format!

  %{context | conn: new_conn} |> Map.put(:user, admin_user)
end
```

### Pattern B: Manual Setup (For Specific Tests with JTI)

```elixir
describe "Specific scenario" do
  setup %{conn: conn} do
    # Create user through OAuth action to get JWT token
    {:ok, user} = Ash.create(
      User,
      %{user_info: %{...}, oauth_tokens: %{...}},
      action: :register_with_github
    )

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> AshAuthentication.Plug.Helpers.store_in_session(user)
      # NO assign(:current_user) for JTI!

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

**Golden Rules (Updated 2025-11-07):**
1. **NEVER** use `session: {AshAuthentication.Phoenix.LiveSession, :generate_session, []}` with JTI session identifiers
2. For JTI: Use ONLY `store_in_session(user)` in tests (NO `assign(:current_user)`)
3. For JTI: Remove `session:` callback from live_session in router
4. Apply hooks conditionally at router level, not globally
5. Use keyword list `[]` as default for config, not map `%{}`
6. Create users through OAuth actions to get JWT tokens with JTI
7. Authentication hooks should run BEFORE feature hooks

**When tests fail with KeyError (JTI users):**
- Check router does NOT have `session: generate_session` callback
- Check test uses `store_in_session` WITHOUT `assign(:current_user)`
- Check user was created through OAuth action (has `__metadata__.token`)
- Check hooks are applied in correct order
- Check no global hooks interfering with auth

**When creating test helpers (JTI):**
- Create users through OAuth actions (`:register_with_github`, etc.)
- Use ONLY `store_in_session(user)` to configure conn
- Do NOT use `assign(:current_user)` - it breaks JTI format
- Use unique identifiers to avoid conflicts
- Return both `conn` and `user` from setup

---

## Related Skills

For specific testing patterns, also see:

- **OAuth Testing**: `.claude/skills/testing-oauth-auth/` - Creating OAuth test users with proper tokens
- **Element Testing**: `.claude/skills/testing-liveview-elements/` - Element-based testing to avoid HTML truncation
- **Test Setup**: `.claude/skills/testing-liveview-setup/` - Complete test file structure and organization

## Related Documentation

- Phoenix.LiveViewTest: Testing LiveViews
- AshAuthentication: Authentication setup
- Phoenix.ConnTest: Connection test helpers
- Session: 2025-11-07-fix-admin-auth-cookie-consent-conflict.md
- Session: 2025-11-07-fix-oauth-test-config-bug.md
