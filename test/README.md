# Testing Guide for EHS Enforcement

Quick reference for running tests and accessing detailed testing skills.

## Quick Commands

```bash
# Run all tests
mix test

# Run specific test file
mix test test/path/to/test.exs

# Run specific test by line number
mix test test/path/to/test.exs:42

# Run with limited concurrent test cases
mix test --max-cases=1

# Include slow/integration tests
mix test --include slow --include integration

# Exclude heavy tests (like dashboard metrics)
mix test --exclude heavy
```

## Test Helper Functions

Available in `test/support/conn_case.ex`:

| Helper | Description |
|--------|-------------|
| `register_and_log_in_user/1` | Creates regular user with OAuth2 tokens |
| `register_and_log_in_admin/1` | Creates admin user with OAuth2 tokens |
| `create_test_user/1` | Creates user without authentication (unit tests) |
| `create_test_admin/1` | Creates admin user without authentication (unit tests) |

**Usage:**

```elixir
describe "authenticated routes" do
  setup :register_and_log_in_user

  test "works", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, "/dashboard")
    assert has_element?(view, "h1", "Dashboard")
  end
end
```

## Testing Skills

Comprehensive testing patterns are available as skills in `.claude/skills/`:

### Authentication & Setup
- **[Testing OAuth Authentication](.claude/skills/testing-oauth-auth/SKILL.md)** - Creating OAuth test users with proper tokens, handling auth errors
- **[Testing Auth Patterns](.claude/skills/testing-auth/SKILL.md)** - JTI sessions, hooks, authentication flow troubleshooting

### LiveView Testing
- **[LiveView Element Testing](.claude/skills/testing-liveview-elements/SKILL.md)** - Element-based testing to avoid HTML truncation, form/button testing
- **[LiveView Test Setup](.claude/skills/testing-liveview-setup/SKILL.md)** - Complete test file structure, setup blocks, test organization

**💡 Tip:** Claude Code can automatically reference these skills when helping with test writing.

## Common Test Patterns

### Element-Based Testing (Avoid HTML Truncation)

```elixir
# ✅ GOOD - Works with large pages
test "page loads", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/admin/dashboard")
  assert has_element?(view, "h1", "Admin Dashboard")
  assert has_element?(view, "button", "Start")
end

# ❌ BAD - Fails with HTML > 30k chars
test "page loads", %{conn: conn} do
  {:ok, view, html} = live(conn, "/admin/dashboard")
  assert html =~ "Admin Dashboard"  # May fail if HTML truncated
end
```

### OAuth User Creation

```elixir
# ✅ GOOD - Creates user with proper OAuth tokens
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

# ❌ BAD - Missing OAuth tokens, auth will fail
user = %{email: "test@example.com", is_admin: true}
```

## Template vs Resource Field Mappings

When templates reference fields that don't match Ash resource definitions:

| Template Field | Resource Field | Fix |
|---------------|----------------|-----|
| `details.timestamp` | `details.inserted_at` | Use `inserted_at` |
| `details.existing_count` | `details.cases_existing` | Use `cases_existing` |
| `user.display_name` | Computed from first/last name | Use computed field or calculate in template |

## Test Configuration

### Concurrency Settings

The test suite is configured with `max_cases: 2` in `test/test_helper.exs` to prevent database connection pool exhaustion. Each test case uses multiple connections (main process + Sandbox.allow for async operations).

### Excluded Tags by Default

- `:slow` - Long-running tests
- `:integration` - Integration tests requiring external services

Include with: `mix test --include slow --include integration`

### Heavy Tests

Tests tagged with `:heavy` (like dashboard metrics) are included by default but run with limited concurrency. Exclude with: `mix test --exclude heavy`

## Troubleshooting

### Common Issues

**Authentication Redirect:**
```
{:error, {:redirect, %{to: "/sign-in"}}}
```
→ User not properly authenticated. Use `register_and_log_in_user` or `register_and_log_in_admin` helper.

**KeyError: :current_user not found:**
```
** (KeyError) key :current_user not found in socket.assigns
```
→ OAuth user creation missing or session not stored. See OAuth Testing skill.

**HTML Truncation:**
```
Assertion with =~ failed
left: "<html>...truncated..."
```
→ Use `has_element?` instead of string matching. See Element Testing skill.

**Field Not Found:**
```
** (KeyError) key :existing_count not found
```
→ Template field doesn't match resource. Check field mappings table above.

## Documentation

For detailed patterns and troubleshooting, refer to:

- **Skills**: `.claude/skills/testing-*/SKILL.md` - Complete testing guides
- **Testing Guide**: `docs-dev/TESTING_GUIDE.md` - Broader testing documentation
- **ExUnit**: https://hexdocs.pm/ex_unit/ - ExUnit framework docs
- **LiveViewTest**: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html - LiveView testing docs

## Test Structure

Tests follow the standard Phoenix directory structure:

```
test/
├── test_helper.exs              # ExUnit configuration
├── support/                     # Test support modules
│   ├── conn_case.ex            # LiveView test helpers
│   ├── data_case.ex            # Database test helpers
│   └── fixtures/               # Test data fixtures
├── ehs_enforcement/            # Domain tests (mirror lib/)
└── ehs_enforcement_web/        # Web layer tests (mirror lib/)
```

## Contributing

When writing new tests:

1. ✅ Use element-based assertions (`has_element?`)
2. ✅ Use test helpers for authentication
3. ✅ Add `data-testid` attributes for stable selectors
4. ✅ Test both happy paths and error scenarios
5. ✅ Use descriptive test names
6. ❌ Don't use string matching on large HTML
7. ❌ Don't create users without OAuth for auth tests
8. ❌ Don't test implementation details

---

**For comprehensive testing patterns, see the skills in `.claude/skills/testing-*/`**
