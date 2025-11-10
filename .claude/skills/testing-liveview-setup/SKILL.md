# SKILL: LiveView Test Setup Patterns

**Purpose:** Complete guide to structuring LiveView tests with proper authentication, setup blocks, and test organization

**Context:** Phoenix LiveView + ExUnit + AshAuthentication + Test Organization

**When to Use:**
- Starting a new LiveView test file
- Setting up authentication in tests
- Testing multiple permission levels
- Organizing tests with shared setup
- Creating maintainable test suites

---

## Complete Test File Structure

### Full Example: Admin LiveView Test

```elixir
defmodule EhsEnforcementWeb.Admin.SomeLiveTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  # Test authenticated routes
  describe "authenticated access" do
    setup :register_and_log_in_user

    test "regular user can access public sections", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, "/dashboard")
      assert has_element?(view, "h1", "Dashboard")
    end

    test "handles user interactions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Trigger event
      view
      |> element("button", "Refresh")
      |> render_click()

      assert has_element?(view, ".flash-success", "Refreshed")
    end
  end

  # Test admin-only routes
  describe "admin access" do
    setup :register_and_log_in_admin

    test "admin can access admin routes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/dashboard")
      assert has_element?(view, "h1", "Admin Panel")
    end

    test "admin can perform admin actions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/cases")

      view
      |> element("button", "Delete All")
      |> render_click()

      assert has_element?(view, ".flash-success", "All cases deleted")
    end
  end

  # Test unauthenticated access
  describe "unauthenticated access" do
    test "redirects to sign-in for protected routes", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, "/dashboard")
      assert path == "/sign-in"
    end

    test "redirects to sign-in for admin routes", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, "/admin/dashboard")
      assert path == "/sign-in"
    end
  end

  # Test authorization failures
  describe "authorization" do
    setup :register_and_log_in_user  # Regular user, not admin

    test "non-admin cannot access admin routes", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, "/admin/dashboard")
      assert path == "/sign-in"
    end

    test "non-admin cannot perform admin actions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Admin-only button should not be visible
      refute has_element?(view, "button", "Admin Settings")
    end
  end

  # Test error handling
  describe "error handling" do
    setup :register_and_log_in_user

    test "handles invalid parameters gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases/invalid-id")
      assert has_element?(view, ".error-message", "Case not found")
    end
  end
end
```

---

## Setup Block Patterns

### Pattern 1: Using Test Helper Functions (Recommended)

```elixir
describe "admin features" do
  setup :register_and_log_in_admin

  test "admin can manage users", %{conn: conn, user: admin} do
    # admin is available from setup
    {:ok, view, _html} = live(conn, "/admin/users")
    assert has_element?(view, "h1", "User Management")
  end
end
```

**Benefits:**
- Clean and concise
- Reusable across test files
- Consistent user creation
- Easy to maintain

---

### Pattern 2: Custom Setup Block

```elixir
describe "specific scenario" do
  setup %{conn: conn} do
    # Create custom test data
    {:ok, agency} = Ash.create(Agency, %{name: "HSE"})
    {:ok, case} = Ash.create(Case, %{
      title: "Test Case",
      agency_id: agency.id
    })

    # Authenticate user
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

    # Return all needed context
    %{conn: conn, user: user, agency: agency, case: case}
  end

  test "displays case with agency", %{conn: conn, case: case} do
    {:ok, view, _html} = live(conn, "/cases/#{case.id}")
    assert has_element?(view, "h1", "Test Case")
    assert has_element?(view, "span", "HSE")
  end
end
```

---

### Pattern 3: Chaining Multiple Setups

```elixir
describe "complex scenario" do
  setup :register_and_log_in_admin
  setup :create_test_data
  setup :configure_test_environment

  test "works with all setup data", %{conn: conn, user: user, data: data} do
    # All setup functions have run
    {:ok, view, _html} = live(conn, "/admin/reports")
    assert has_element?(view, "h1", "Reports")
  end
end

# Helper functions
defp create_test_data(_context) do
  data = %{cases: 10, notices: 5}
  %{data: data}
end

defp configure_test_environment(_context) do
  Application.put_env(:ehs_enforcement, :test_mode, true)
  on_exit(fn -> Application.delete_env(:ehs_enforcement, :test_mode) end)
  :ok
end
```

---

### Pattern 4: Conditional Setup

```elixir
describe "feature flags" do
  setup %{conn: conn} do
    %{conn: conn, user: _user} = register_and_log_in_user(%{conn: conn})
  end

  @tag feature: :new_ui
  test "new UI enabled", %{conn: conn} do
    Application.put_env(:ehs_enforcement, :features, [:new_ui])
    {:ok, view, _html} = live(conn, "/dashboard")
    assert has_element?(view, "[data-ui='new']")
  end

  test "old UI by default", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")
    assert has_element?(view, "[data-ui='classic']")
  end
end
```

---

## Test Helper Patterns

### Pattern: Creating Test Helpers in conn_case.ex

```elixir
# In test/support/conn_case.ex

def register_and_log_in_user(%{conn: conn}) do
  user = create_oauth_user()

  conn =
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)

  %{conn: conn, user: user}
end

def register_and_log_in_admin(%{conn: conn}) do
  %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

  {:ok, admin_user} = Ash.update(
    user,
    %{is_admin: true, admin_checked_at: DateTime.utc_now()},
    action: :update_admin_status,
    actor: user
  )

  conn =
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(admin_user)

  %{conn: conn, user: admin_user}
end

defp create_oauth_user do
  unique_id = System.unique_integer([:positive])

  user_info = %{
    "email" => "user-#{unique_id}@example.com",
    "name" => "Test User",
    "login" => "testuser#{unique_id}",
    "id" => unique_id
  }

  oauth_tokens = %{
    "access_token" => "test_token",
    "token_type" => "Bearer"
  }

  {:ok, user} = Ash.create(
    EhsEnforcement.Accounts.User,
    %{user_info: user_info, oauth_tokens: oauth_tokens},
    action: :register_with_github
  )

  user
end
```

---

## Testing Different User Scenarios

### Scenario 1: Regular User Access

```elixir
describe "regular user" do
  setup :register_and_log_in_user

  test "can view own dashboard", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")
    assert has_element?(view, "h1", "Dashboard")
  end

  test "cannot access admin pages", %{conn: conn} do
    {:error, {:redirect, %{to: path}}} = live(conn, "/admin")
    assert path == "/sign-in"
  end
end
```

---

### Scenario 2: Admin User Access

```elixir
describe "admin user" do
  setup :register_and_log_in_admin

  test "can access admin pages", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin")
    assert has_element?(view, "h1", "Admin Panel")
  end

  test "can perform admin actions", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/users")

    view
    |> element("button", "Create User")
    |> render_click()

    assert has_element?(view, "form")
  end
end
```

---

### Scenario 3: Unauthenticated Access

```elixir
describe "unauthenticated user" do
  # No setup - tests as guest

  test "cannot access protected routes", %{conn: conn} do
    {:error, {:redirect, %{to: path}}} = live(conn, "/dashboard")
    assert path == "/sign-in"
  end

  test "can access public routes", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "h1", "Welcome")
  end
end
```

---

## Testing Form Workflows

### Pattern: Multi-Step Form Testing

```elixir
describe "case creation workflow" do
  setup :register_and_log_in_admin

  test "complete workflow from start to finish", %{conn: conn} do
    # Step 1: Navigate to form
    {:ok, view, _html} = live(conn, "/admin/cases/new")
    assert has_element?(view, "h1", "New Case")

    # Step 2: Fill form
    view
    |> element("form")
    |> render_change(%{case: %{
      title: "Test Case",
      description: "Test description"
    }})

    # Step 3: Verify preview (if applicable)
    assert has_element?(view, ".preview", "Test Case")

    # Step 4: Submit
    view
    |> element("form")
    |> render_submit()

    # Step 5: Verify redirect and success
    assert_redirect(view, "/admin/cases")
    flash = assert_redirected(view, "/admin/cases")
    assert flash["success"] == "Case created successfully"
  end
end
```

---

## Testing Real-Time Updates

### Pattern: PubSub Testing

```elixir
describe "real-time updates" do
  setup :register_and_log_in_user

  test "receives updates via PubSub", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")

    # Initial state
    assert has_element?(view, "[data-count='0']")

    # Broadcast update
    Phoenix.PubSub.broadcast(
      EhsEnforcement.PubSub,
      "dashboard:updates",
      {:metrics_updated, %{count: 42}}
    )

    # Wait for and verify update
    assert_receive {:metrics_updated, _}, 1000
    assert has_element?(view, "[data-count='42']")
  end
end
```

---

## Testing Error Scenarios

### Pattern: Error Handling Tests

```elixir
describe "error handling" do
  setup :register_and_log_in_user

  test "handles network errors gracefully", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")

    # Simulate error
    send(view.pid, {:error, :network_error})

    # Verify error message displayed
    assert has_element?(view, ".error-message", "Network error occurred")
  end

  test "handles not found errors", %{conn: conn} do
    {:error, {:live_redirect, %{to: path}}} = live(conn, "/cases/nonexistent")
    assert path == "/cases"
  end
end
```

---

## Testing Component State

### Pattern: Component Lifecycle Testing

```elixir
describe "component state management" do
  setup :register_and_log_in_user

  test "component initializes correctly", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")

    # Verify initial state
    assert has_element?(view, "[data-state='initialized']")
    assert has_element?(view, "[data-loading='false']")
  end

  test "component updates state on interaction", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")

    # Trigger state change
    view
    |> element("button", "Load Data")
    |> render_click()

    # Verify loading state
    assert has_element?(view, "[data-loading='true']")

    # Wait for data load (mock or test)
    send(view.pid, {:data_loaded, %{items: []}})

    # Verify loaded state
    assert has_element?(view, "[data-loading='false']")
    assert has_element?(view, "[data-state='loaded']")
  end
end
```

---

## Testing Navigation

### Pattern: Navigation Testing

```elixir
describe "navigation" do
  setup :register_and_log_in_user

  test "navigates between pages", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")

    # Click link
    view
    |> element("a", "Cases")
    |> render_click()

    # Verify navigation (if using live_redirect)
    assert_redirect(view, "/cases")

    # Or if patching in place
    assert has_element?(view, "h1", "Cases")
  end
end
```

---

## Testing with Test Data

### Pattern: Using Fixtures

```elixir
describe "displaying data" do
  setup %{conn: conn} do
    # Create test data
    {:ok, agency} = Ash.create(Agency, %{name: "HSE"})

    {:ok, case1} = Ash.create(Case, %{
      title: "Case 1",
      agency_id: agency.id
    })

    {:ok, case2} = Ash.create(Case, %{
      title: "Case 2",
      agency_id: agency.id
    })

    # Authenticate
    %{conn: conn, user: _user} = register_and_log_in_user(%{conn: conn})

    %{conn: conn, cases: [case1, case2], agency: agency}
  end

  test "displays all cases", %{conn: conn, cases: cases} do
    {:ok, view, _html} = live(conn, "/cases")

    Enum.each(cases, fn case ->
      assert has_element?(view, "td", case.title)
    end)
  end
end
```

---

## Common Assertions

### LiveView Mount Assertions

```elixir
# Successful mount
{:ok, view, html} = live(conn, "/path")

# Redirect on mount
{:error, {:redirect, %{to: path}}} = live(conn, "/path")

# Live redirect on mount
{:error, {:live_redirect, %{to: path}}} = live(conn, "/path")
```

---

### Element Existence Assertions

```elixir
# Element exists
assert has_element?(view, "h1", "Title")

# Element does not exist
refute has_element?(view, "button", "Delete")

# Element with specific attributes
assert has_element?(view, "button[disabled]")
```

---

### Event Assertions

```elixir
# Click succeeded
html = render_click(view, "button", "Submit")

# Form submission succeeded
html = render_submit(view, "form", %{data: "value"})

# Change event succeeded
html = render_change(view, "form", %{field: "new_value"})
```

---

## Test Organization Tips

### 1. Group Related Tests

```elixir
describe "feature name" do
  # All tests for this feature
end
```

### 2. Use Descriptive Test Names

```elixir
# Good
test "admin can delete cases when authorized", %{conn: conn}

# Bad
test "delete works", %{conn: conn}
```

### 3. One Assertion per Test (When Possible)

```elixir
# Good - focused test
test "displays case title", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/cases/123")
  assert has_element?(view, "h1", "Case Title")
end

# Acceptable - related assertions
test "form displays validation errors", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/cases/new")
  render_submit(view, "form", %{})

  assert has_element?(view, ".error", "Title can't be blank")
  assert has_element?(view, ".error", "Description can't be blank")
end
```

---

## Quick Reference

### Essential Setup Pattern

```elixir
defmodule MyAppWeb.SomeLiveTest do
  use MyAppWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "feature" do
    setup :register_and_log_in_user

    test "works", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/path")
      assert has_element?(view, "h1")
    end
  end
end
```

---

## Related Skills

- **OAuth Testing**: `.claude/skills/testing-oauth-auth/` - Creating authenticated users
- **Element Testing**: `.claude/skills/testing-liveview-elements/` - Element-based assertions
- **Auth Patterns**: `.claude/skills/testing-auth/` - Authentication hooks and sessions

---

## Key Takeaways

1. ✅ Use `describe` blocks to organize related tests
2. ✅ Use setup blocks to share common test setup
3. ✅ Create reusable test helpers in `conn_case.ex`
4. ✅ Test multiple user scenarios (guest, user, admin)
5. ✅ Use descriptive test names that explain what's being tested
6. ✅ Test both happy paths and error scenarios
7. ✅ Keep tests focused and maintainable
8. ❌ Don't repeat setup code across tests (use helpers)
9. ❌ Don't test implementation details (test behavior)
10. ❌ Don't create overly complex test setups
