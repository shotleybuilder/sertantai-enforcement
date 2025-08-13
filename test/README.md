# Testing Guide for EHS Enforcement

This document captures working test patterns and key learnings for the EHS Enforcement project to prevent future developers from facing authentication and testing issues.

## Authentication Testing - CRITICAL PATTERNS

### ✅ WORKING: OAuth2 Test Authentication Pattern

The key to successful LiveView authentication testing is using the proper OAuth2 user creation flow that generates required tokens:

```elixir
# In test setup
setup %{conn: conn} do
  # Create admin user using OAuth2 pattern (generates proper tokens)
  user_info = %{
    "email" => "test-admin@example.com",
    "name" => "Test Admin", 
    "login" => "testadmin",
    "id" => 12345,
    "avatar_url" => "https://github.com/images/avatars/testadmin",
    "html_url" => "https://github.com/testadmin"
  }
  
  oauth_tokens = %{
    "access_token" => "test_access_token",
    "token_type" => "Bearer"
  }

  # Create user with OAuth2 action (generates required tokens)
  {:ok, user} = Ash.create(EhsEnforcement.Accounts.User, %{
    user_info: user_info,
    oauth_tokens: oauth_tokens
  }, action: :register_with_github)
  
  # Update admin status after creation
  {:ok, admin_user} = Ash.update(user, %{
    is_admin: true,
    admin_checked_at: DateTime.utc_now()
  }, action: :update_admin_status, actor: user)

  # CRITICAL: Use AshAuthentication session storage
  authenticated_conn = conn
  |> Phoenix.ConnTest.init_test_session(%{})
  |> AshAuthentication.Plug.Helpers.store_in_session(admin_user)

  %{admin_user: admin_user, conn: authenticated_conn}
end
```

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

### ❌ DOES NOT WORK: Ash.Seed without OAuth

```elixir
# This FAILS - missing required tokens
admin_user = Ash.Seed.seed!(EhsEnforcement.Accounts.User, %{
  email: "admin@test.com",
  is_admin: true
})
```

## Element-Based Testing (Avoiding HTML Truncation)

Phoenix LiveView tests can fail when HTML output exceeds ~30,000 characters. **Always use element-based testing instead of string matching:**

### ✅ WORKING: Element-Based Testing

```elixir
test "page loads correctly", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/admin/cases/scrape")

  # Use element-based assertions (no HTML truncation issues)
  assert has_element?(view, "h1", "Case Scraping")
  assert has_element?(view, "button", "Start")
  assert has_element?(view, "h2", "Progress")
end
```

### ❌ DOES NOT WORK: String-Based HTML Assertions

```elixir
test "page loads correctly", %{conn: conn} do
  {:ok, view, html} = live(conn, "/admin/cases/scrape")

  # This FAILS with large HTML documents due to truncation
  assert html =~ "Case Scraping"
  assert html =~ "Start"
end
```

## Key Testing Patterns

### 1. Admin LiveView Test Setup

```elixir
defmodule MyApp.AdminLiveTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    # Create admin using OAuth2 pattern
    user_info = %{
      "email" => "admin@test.com",
      "name" => "Admin User",
      "login" => "adminuser",
      "id" => 123,
      "avatar_url" => "https://github.com/images/avatars/adminuser",
      "html_url" => "https://github.com/adminuser"
    }
    
    oauth_tokens = %{
      "access_token" => "test_token",
      "token_type" => "Bearer"
    }

    {:ok, user} = Ash.create(EhsEnforcement.Accounts.User, %{
      user_info: user_info,
      oauth_tokens: oauth_tokens
    }, action: :register_with_github)
    
    {:ok, admin_user} = Ash.update(user, %{
      is_admin: true,
      admin_checked_at: DateTime.utc_now()
    }, action: :update_admin_status, actor: user)

    authenticated_conn = conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(admin_user)

    %{admin_user: admin_user, conn: authenticated_conn}
  end

  test "admin page loads", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/dashboard")
    assert has_element?(view, "h1", "Admin Dashboard")
  end
end
```

### 2. Form Testing

```elixir
test "form submission works", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/admin/cases/new")
  
  # Test form submission using element-based approach
  view
  |> element("#case-form")
  |> render_submit(%{case: %{name: "Test Case"}})
  
  assert has_element?(view, ".flash-success", "Case created")
end
```

### 3. Button Click Testing

```elixir
test "button actions work", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/admin/cases/scrape")
  
  # Click button and verify result
  view
  |> element("button", "Start Scraping")
  |> render_click()
  
  assert has_element?(view, "div", "Scraping in progress")
end
```

## Common Issues and Solutions

### 1. Authentication Redirect Errors

**Problem**: 
```
{:error, {:redirect, %{to: "/sign-in", flash: %{"info" => "Please sign in to continue"}}}}
```

**Solution**: Use the OAuth2 pattern above with proper token generation and `AshAuthentication.Plug.Helpers.store_in_session/2`.

### 2. HTML Truncation Failures

**Problem**: 
```
Assertion with =~ failed
left: "<html lang=\"en\">...truncated..."
right: "Expected text"
```

**Solution**: Replace `assert html =~ "text"` with `assert has_element?(view, "selector", "text")`.

### 3. Missing Token Errors

**Problem**: 
```
** (KeyError) key :token not found in: %{}
```

**Solution**: Use the OAuth2 user creation pattern that generates proper authentication tokens.

### 4. Template Field Errors

**Problem**: 
```
** (KeyError) key :existing_count not found in: %EhsEnforcement.Scraping.CaseProcessingLog{...}
```

**Solution**: Ensure template fields match the actual Ash resource attributes. Check resource definitions in `lib/` for exact field names.

## Test Helper Functions

The project includes helpful authentication functions in `test/support/conn_case.ex`:

- `register_and_log_in_user/1` - Creates a regular user with OAuth2 tokens
- `register_and_log_in_admin/1` - Creates an admin user with OAuth2 tokens  
- `create_test_user/1` - Creates a user without authentication (for unit tests)
- `create_test_admin/1` - Creates an admin user without authentication (for unit tests)

## Running Tests

```bash
# Run specific test file
mix test test/path/to/test.exs

# Run specific test by line number
mix test test/path/to/test.exs:42

# Run with limited test cases for faster feedback
mix test test/path/to/test.exs --max-cases=1

# Run tests excluding integration tests
mix test --exclude integration
```

## Important Notes

1. **Always use OAuth2 pattern** for LiveView authentication tests
2. **Always use element-based testing** to avoid HTML truncation
3. **Check resource field names** in templates match Ash resource definitions
4. **Use proper selectors** that target actual HTML elements, not CSS classes
5. **Test user interactions** rather than implementation details

## Templates vs Resources Field Mapping

Common field mismatches to watch for:

| Template Field | Resource Field | Fix |
|---------------|----------------|-----|
| `details.timestamp` | `details.inserted_at` | Use `inserted_at` |
| `details.existing_count` | `details.cases_existing` | Use `cases_existing` |
| `user.display_name` | Calculate from first/last name | Use computed field |

## Example Working Test

```elixir
defmodule EhsEnforcementWeb.Admin.CaseLive.ScrapeTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    # OAuth2 admin user setup
    user_info = %{
      "email" => "scrape-admin@test.com",
      "name" => "Scrape Admin",
      "login" => "scrapeadmin", 
      "id" => 12345,
      "avatar_url" => "https://github.com/images/avatars/scrapeadmin",
      "html_url" => "https://github.com/scrapeadmin"
    }
    
    oauth_tokens = %{
      "access_token" => "test_access_token",
      "token_type" => "Bearer"
    }

    {:ok, user} = Ash.create(EhsEnforcement.Accounts.User, %{
      user_info: user_info,
      oauth_tokens: oauth_tokens
    }, action: :register_with_github)
    
    {:ok, admin_user} = Ash.update(user, %{
      is_admin: true,
      admin_checked_at: DateTime.utc_now()
    }, action: :update_admin_status, actor: user)

    authenticated_conn = conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(admin_user)

    %{admin_user: admin_user, conn: authenticated_conn}
  end

  test "scrape page loads successfully", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/cases/scrape")

    # Element-based testing - works with large HTML
    assert has_element?(view, "h1", "Case Scraping")
    assert has_element?(view, "h2", "HSE Progress")
    assert has_element?(view, "button[type='submit']")
  end
end
```

This test pattern has been verified to work and avoids all the common authentication and HTML truncation issues.