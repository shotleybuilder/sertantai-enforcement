# SKILL: OAuth Authentication Testing with Ash

**Purpose:** Guide for testing Phoenix LiveView routes with OAuth2 authentication using AshAuthentication

**Context:** Phoenix LiveView + AshAuthentication + GitHub OAuth + ExUnit Testing

**When to Use:**
- Testing admin routes requiring GitHub OAuth
- Creating authenticated test users with proper tokens
- Debugging authentication failures in tests
- Setting up test helpers for OAuth flows

---

## Core Concept

When testing LiveView routes with OAuth authentication, you must create users through the proper OAuth action to generate required tokens. Simple user creation without OAuth tokens will fail authentication checks.

---

## Pattern: OAuth2 Test User Creation

### ✅ WORKING: Full OAuth Pattern

```elixir
# In test setup
setup %{conn: conn} do
  # 1. Create user_info matching GitHub OAuth response
  user_info = %{
    "email" => "test-admin@example.com",
    "name" => "Test Admin",
    "login" => "testadmin",
    "id" => 12345,
    "avatar_url" => "https://github.com/images/avatars/testadmin",
    "html_url" => "https://github.com/testadmin"
  }

  # 2. Create OAuth tokens
  oauth_tokens = %{
    "access_token" => "test_access_token",
    "token_type" => "Bearer"
  }

  # 3. Create user with OAuth2 action (generates required tokens)
  {:ok, user} = Ash.create(EhsEnforcement.Accounts.User, %{
    user_info: user_info,
    oauth_tokens: oauth_tokens
  }, action: :register_with_github)

  # 4. Update admin status after creation (if needed)
  {:ok, admin_user} = Ash.update(user, %{
    is_admin: true,
    admin_checked_at: DateTime.utc_now()
  }, action: :update_admin_status, actor: user)

  # 5. CRITICAL: Use AshAuthentication session storage
  authenticated_conn = conn
  |> Phoenix.ConnTest.init_test_session(%{})
  |> AshAuthentication.Plug.Helpers.store_in_session(admin_user)

  %{admin_user: admin_user, conn: authenticated_conn}
end
```

**Why This Works:**
- `:register_with_github` action generates JWT tokens with proper claims
- `store_in_session` formats session data correctly for AshAuthentication
- Tokens persist through LiveView mount process
- Authentication hooks can verify user identity

---

### ❌ DOES NOT WORK: Simple User Creation

```elixir
# This FAILS - no OAuth tokens generated
admin_user = %{
  id: "test-admin-id",
  email: "admin@test.com",
  is_admin: true
}

conn = conn |> assign(:current_user, admin_user)  # Does not work for LiveView
```

**Why This Fails:**
- No JWT tokens created
- AshAuthentication cannot verify user
- LiveView mount hooks fail to load user
- Results in redirect to sign-in page

---

### ❌ DOES NOT WORK: Ash.Seed without OAuth

```elixir
# This FAILS - missing required tokens
admin_user = Ash.Seed.seed!(EhsEnforcement.Accounts.User, %{
  email: "admin@test.com",
  is_admin: true
})
```

**Why This Fails:**
- Bypasses OAuth action entirely
- No JWT token generation
- Missing authentication metadata
- User exists but cannot authenticate

---

## Pattern: Test Helper Functions

### Creating Reusable OAuth Test Helpers

```elixir
# In test/support/conn_case.ex

def register_and_log_in_user(%{conn: conn}) do
  user_info = %{
    "email" => "user-#{System.unique_integer([:positive])}@example.com",
    "name" => "Test User",
    "login" => "testuser#{System.unique_integer([:positive])}",
    "id" => System.unique_integer([:positive]),
    "avatar_url" => "https://github.com/images/avatars/testuser",
    "html_url" => "https://github.com/testuser"
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

  conn =
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)

  %{conn: conn, user: user}
end

def register_and_log_in_admin(%{conn: conn}) do
  # Create user with OAuth
  %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

  # Upgrade to admin
  {:ok, admin_user} = Ash.update(
    user,
    %{is_admin: true, admin_checked_at: DateTime.utc_now()},
    action: :update_admin_status,
    actor: user
  )

  # Re-store in session with updated user
  conn =
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(admin_user)

  %{conn: conn, user: admin_user}
end
```

---

## Usage in Tests

### Pattern A: Using Test Helpers (Recommended)

```elixir
defmodule MyAppWeb.Admin.SomeLiveTest do
  use MyAppWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "Admin LiveView" do
    setup :register_and_log_in_admin

    test "mounts successfully", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, "/admin/some-route")
      assert has_element?(view, "h1", "Admin Dashboard")
    end
  end
end
```

---

### Pattern B: Manual Setup for Specific Tests

```elixir
describe "Specific scenario" do
  setup %{conn: conn} do
    # Create user through OAuth action
    user_info = %{
      "email" => "specific@example.com",
      "name" => "Specific User",
      "login" => "specificuser",
      "id" => 99999
    }

    oauth_tokens = %{
      "access_token" => "specific_token",
      "token_type" => "Bearer"
    }

    {:ok, user} = Ash.create(
      User,
      %{user_info: user_info, oauth_tokens: oauth_tokens},
      action: :register_with_github
    )

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> AshAuthentication.Plug.Helpers.store_in_session(user)

    %{conn: conn, user: user}
  end

  test "works with specific user", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/some-route")
    assert html =~ "Content"
  end
end
```

---

## Common Issues and Solutions

### Issue 1: Authentication Redirect Errors

**Symptom:**
```
{:error, {:redirect, %{to: "/sign-in", flash: %{"info" => "Please sign in to continue"}}}}
```

**Cause:** User not properly authenticated in test setup

**Solution:**
1. Verify user created with `:register_with_github` action
2. Ensure `store_in_session` called on conn
3. Check LiveView route requires authentication
4. Verify user has required permissions (e.g., is_admin)

---

### Issue 2: Missing Token Errors

**Symptom:**
```
** (KeyError) key :token not found in: %{}
```

**Cause:** User created without OAuth action

**Solution:** Always use `:register_with_github` action (or equivalent OAuth action)

```elixir
# CORRECT
{:ok, user} = Ash.create(User, %{
  user_info: user_info,
  oauth_tokens: oauth_tokens
}, action: :register_with_github)

# WRONG
{:ok, user} = Ash.create(User, %{
  email: "test@example.com"
})
```

---

### Issue 3: Session Not Persisting

**Symptom:** User authenticated in setup but not in LiveView mount

**Cause:** Session not initialized or stored incorrectly

**Solution:**
```elixir
# Must call BOTH init_test_session AND store_in_session
conn =
  conn
  |> Phoenix.ConnTest.init_test_session(%{})  # ← Initialize first
  |> AshAuthentication.Plug.Helpers.store_in_session(user)  # ← Then store
```

---

## OAuth Token Structure

### GitHub OAuth Response Format

The `user_info` should match GitHub's OAuth response:

```elixir
user_info = %{
  "email" => "user@example.com",      # Required
  "name" => "Full Name",              # Required
  "login" => "github_username",       # Required (unique)
  "id" => 12345,                      # Required (GitHub user ID)
  "avatar_url" => "https://...",      # Optional
  "html_url" => "https://github.com/username"  # Optional
}
```

### OAuth Tokens Format

```elixir
oauth_tokens = %{
  "access_token" => "github_access_token",  # Required
  "token_type" => "Bearer"                  # Required
}
```

**Note:** In tests, these can be any valid strings. The OAuth action validates structure, not authenticity.

---

## Testing Different User Types

### Regular User

```elixir
setup :register_and_log_in_user

test "regular user can access", %{conn: conn} do
  {:ok, _view, html} = live(conn, "/dashboard")
  assert html =~ "Welcome"
end
```

### Admin User

```elixir
setup :register_and_log_in_admin

test "admin can access admin routes", %{conn: conn} do
  {:ok, _view, html} = live(conn, "/admin/dashboard")
  assert html =~ "Admin Panel"
end
```

### Unauthenticated User

```elixir
test "unauthenticated user redirects to sign-in", %{conn: conn} do
  # Don't set up authentication
  {:error, {:redirect, %{to: path}}} = live(conn, "/dashboard")
  assert path == "/sign-in"
end
```

---

## Unique Identifiers in Tests

When creating multiple test users, use unique identifiers:

```elixir
def create_unique_user do
  unique_id = System.unique_integer([:positive])

  user_info = %{
    "email" => "user-#{unique_id}@example.com",
    "login" => "testuser#{unique_id}",
    "id" => unique_id,
    "name" => "Test User #{unique_id}"
  }

  # ... create user
end
```

**Why:** Prevents email/login conflicts when tests run concurrently

---

## Quick Reference

### Minimum OAuth Test Setup

```elixir
setup %{conn: conn} do
  {:ok, user} = Ash.create(User, %{
    user_info: %{
      "email" => "test@example.com",
      "name" => "Test User",
      "login" => "testuser",
      "id" => 12345
    },
    oauth_tokens: %{
      "access_token" => "test_token",
      "token_type" => "Bearer"
    }
  }, action: :register_with_github)

  conn =
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)

  %{conn: conn, user: user}
end
```

---

## Related Skills

- **LiveView Setup Patterns**: `.claude/skills/testing-liveview-setup/` - Complete test file structure
- **General Auth Testing**: `.claude/skills/testing-auth/` - Authentication hooks and session management
- **Element Testing**: `.claude/skills/testing-liveview-elements/` - Testing LiveView components

---

## Key Takeaways

1. ✅ Always create test users through OAuth actions (`:register_with_github`)
2. ✅ Always use `store_in_session` for authentication
3. ✅ Include both `user_info` and `oauth_tokens` when creating users
4. ✅ Use unique identifiers to prevent test conflicts
5. ✅ Create reusable test helpers in `conn_case.ex`
6. ❌ Never create users without OAuth action for auth-required routes
7. ❌ Never skip `init_test_session` before `store_in_session`
