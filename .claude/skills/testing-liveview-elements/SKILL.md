# SKILL: LiveView Element-Based Testing

**Purpose:** Best practices for element-based LiveView testing to avoid HTML truncation issues and write reliable component tests

**Context:** Phoenix LiveView + Phoenix.LiveViewTest + ExUnit

**When to Use:**
- Testing LiveView pages with large HTML output (>30k characters)
- Testing interactive components (buttons, forms, inputs)
- Verifying dynamic content updates
- Writing maintainable component tests

---

## The Problem: HTML Truncation

Phoenix LiveView tests can fail when HTML output exceeds ~30,000 characters. When you capture HTML with `{:ok, view, html} = live(conn, "/route")`, the `html` variable may be truncated.

### ❌ DOES NOT WORK: String-Based HTML Assertions

```elixir
test "page loads correctly", %{conn: conn} do
  {:ok, view, html} = live(conn, "/admin/cases/scrape")

  # This FAILS with large HTML documents due to truncation
  assert html =~ "Case Scraping"
  assert html =~ "Start"
  assert html =~ "Progress"  # May not be in truncated HTML
end
```

**Failure Message:**
```
Assertion with =~ failed
left: "<html lang=\"en\">...truncated..."
right: "Expected text"
```

**Why This Fails:**
- Large HTML output gets truncated by LiveView test helpers
- Truncation happens at arbitrary point
- Content at end of page may not be in captured string
- Tests become flaky and unreliable

---

## The Solution: Element-Based Testing

Use `has_element?/2` and `has_element?/3` to query the live view directly without relying on HTML strings.

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

**Why This Works:**
- `has_element?` queries the LiveView's rendered component tree
- Not affected by HTML string truncation
- More reliable and maintainable
- Tests actual rendered output, not intermediate strings

---

## Element-Based Testing Patterns

### Pattern 1: Testing Text Content

```elixir
# Check if element with text exists
assert has_element?(view, "h1", "Admin Dashboard")

# Check specific element by CSS selector
assert has_element?(view, "div.header h1", "Dashboard")

# Check button text
assert has_element?(view, "button", "Submit")
assert has_element?(view, "button[type='submit']", "Save Changes")
```

---

### Pattern 2: Testing Element Presence

```elixir
# Check if element exists (regardless of text)
assert has_element?(view, "form#case-form")
assert has_element?(view, "button[type='submit']")
assert has_element?(view, "[data-testid='progress-bar']")

# Check multiple elements
assert has_element?(view, "table tbody tr")
assert has_element?(view, "ul.menu li")
```

---

### Pattern 3: Testing Element Attributes

```elixir
# Check element with specific attributes
assert has_element?(view, "button[disabled]")
assert has_element?(view, "input[type='email'][required]")
assert has_element?(view, "a[href='/admin/cases']")

# Check data attributes
assert has_element?(view, "[data-status='active']")
assert has_element?(view, "[data-testid='case-table']")
```

---

### Pattern 4: Testing Dynamic Content

```elixir
test "dynamic content updates", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/admin/scraping")

  # Check initial state
  assert has_element?(view, "button", "Start Scraping")
  refute has_element?(view, "button", "Stop Scraping")

  # Trigger action
  view |> element("button", "Start Scraping") |> render_click()

  # Check updated state
  refute has_element?(view, "button", "Start Scraping")
  assert has_element?(view, "button", "Stop Scraping")
  assert has_element?(view, "div", "Scraping in progress")
end
```

---

## Form Testing

### Pattern: Complete Form Testing Flow

```elixir
test "form submission works", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/admin/cases/new")

  # Verify form exists
  assert has_element?(view, "form#case-form")
  assert has_element?(view, "input[name='case[name]']")
  assert has_element?(view, "button[type='submit']")

  # Fill and submit form
  view
  |> element("form#case-form")
  |> render_submit(%{case: %{
    name: "Test Case",
    description: "Test description"
  }})

  # Verify success
  assert has_element?(view, ".flash-success", "Case created successfully")
  assert has_element?(view, "h1", "Test Case")
end
```

---

### Pattern: Form Validation Testing

```elixir
test "form shows validation errors", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/admin/cases/new")

  # Submit empty form
  view
  |> element("form#case-form")
  |> render_submit(%{case: %{}})

  # Check validation errors appear
  assert has_element?(view, ".field-error", "can't be blank")
  assert has_element?(view, "form#case-form")  # Still on form page
end
```

---

### Pattern: Form Field Changes

```elixir
test "form field change triggers validation", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/admin/cases/new")

  # Change field value
  view
  |> element("form#case-form")
  |> render_change(%{case: %{name: "Te"}})  # Too short

  # Check validation feedback
  assert has_element?(view, ".field-error", "should be at least 3 character")

  # Fix validation error
  view
  |> element("form#case-form")
  |> render_change(%{case: %{name: "Test Case"}})

  # Verify error cleared
  refute has_element?(view, ".field-error")
end
```

---

## Button and Event Testing

### Pattern: Button Click Testing

```elixir
test "button click triggers action", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/admin/cases/scrape")

  # Verify button exists
  assert has_element?(view, "button", "Start Scraping")

  # Click button
  view
  |> element("button", "Start Scraping")
  |> render_click()

  # Verify result
  assert has_element?(view, "div", "Scraping in progress")
  assert has_element?(view, "[data-status='running']")
end
```

---

### Pattern: Testing Disabled State

```elixir
test "button disabled during operation", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/admin/cases/scrape")

  # Button initially enabled
  refute has_element?(view, "button[disabled]", "Start")

  # Start operation
  view |> element("button", "Start") |> render_click()

  # Button now disabled
  assert has_element?(view, "button[disabled]", "Start")
end
```

---

### Pattern: Testing Event with Parameters

```elixir
test "event with parameters", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/admin/cases")

  # Click button with phx-value-* attributes
  view
  |> element("button[phx-click='delete'][phx-value-id='123']")
  |> render_click()

  # Or pass parameters explicitly
  view
  |> element("button", "Delete")
  |> render_click(%{"id" => "123"})

  # Verify result
  assert has_element?(view, ".flash-success", "Case deleted")
end
```

---

## Table and List Testing

### Pattern: Testing Table Content

```elixir
test "table displays data", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/admin/cases")

  # Verify table structure
  assert has_element?(view, "table")
  assert has_element?(view, "table thead th", "Case Name")
  assert has_element?(view, "table tbody tr")

  # Verify specific row exists
  assert has_element?(view, "table tbody tr td", "Test Case 1")
end
```

---

### Pattern: Testing Empty States

```elixir
test "empty state displays when no data", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/admin/cases")

  # Verify empty state
  assert has_element?(view, "p", "No cases found")
  refute has_element?(view, "table tbody tr")
end
```

---

## Testing Async Updates

### Pattern: Testing PubSub Updates

```elixir
test "live view receives real-time updates", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/admin/scraping")

  # Initial state
  assert has_element?(view, "[data-count='0']")

  # Trigger external event (e.g., via PubSub)
  Phoenix.PubSub.broadcast(
    EhsEnforcement.PubSub,
    "scraping:updates",
    {:case_scraped, %{count: 5}}
  )

  # Wait for update and verify
  assert_receive {:case_scraped, _}, 1000
  assert has_element?(view, "[data-count='5']")
end
```

---

## CSS Selector Best Practices

### Use Data Attributes for Testing

**Recommended:**
```elixir
# HTML
<div data-testid="user-profile">...</div>

# Test
assert has_element?(view, "[data-testid='user-profile']")
```

**Why:**
- Decouples tests from styling
- Won't break if CSS classes change
- Clear intent (this is for testing)
- Industry standard practice

---

### Selector Priority Order

1. **Data attributes** (best): `[data-testid='element']`
2. **Semantic HTML**: `h1`, `button`, `form`, `nav`
3. **ID attributes**: `#user-form`
4. **CSS classes** (avoid): `.btn-primary` (brittle)

---

## Common Assertions

### Positive Assertions

```elixir
# Element exists
assert has_element?(view, "button", "Submit")

# Element exists with selector
assert has_element?(view, "button[type='submit']")

# Element exists with text content
assert has_element?(view, "div.message", "Success")
```

---

### Negative Assertions

```elixir
# Element does not exist
refute has_element?(view, "button", "Delete")

# Element not in specific state
refute has_element?(view, "button[disabled]")

# Error message not shown
refute has_element?(view, ".error-message")
```

---

## Combining Element Tests with Rendered Output

Sometimes you need to check the actual rendered HTML (e.g., for generated IDs):

```elixir
test "generated content", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/admin/cases/123")

  # Use render() to get current HTML (not truncated initial HTML)
  current_html = render(view)

  # Safe to use string matching on render() output
  assert current_html =~ ~r/case-\d+/  # Matches generated ID pattern

  # But still prefer element-based for structure
  assert has_element?(view, "[id^='case-']")  # CSS attribute selector
end
```

---

## Testing Component State Changes

```elixir
test "component toggles state", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/admin/dashboard")

  # Initial collapsed state
  assert has_element?(view, "[data-expanded='false']")
  assert has_element?(view, "button", "Expand")

  # Click to expand
  view |> element("button", "Expand") |> render_click()

  # Verify expanded state
  assert has_element?(view, "[data-expanded='true']")
  assert has_element?(view, "button", "Collapse")
  assert has_element?(view, ".expanded-content")
end
```

---

## When to Use String Matching

String matching on HTML is still valid for:

1. **Small components** with guaranteed small HTML output
2. **Specific text patterns** like regex matching
3. **Generated content** that can't be easily selected

But always prefer element-based testing when possible.

---

## Quick Reference

### Essential Functions

```elixir
# Check if element exists
has_element?(view, selector)
has_element?(view, selector, text_content)

# Get element (for interaction)
element(view, selector)
element(view, selector, text_filter)

# Render actions
render_click(element)
render_submit(element, params)
render_change(element, params)

# Get current HTML
render(view)
```

---

## Related Skills

- **OAuth Testing**: `.claude/skills/testing-oauth-auth/` - Setting up authenticated tests
- **Test Setup**: `.claude/skills/testing-liveview-setup/` - Complete test file structure
- **Auth Testing**: `.claude/skills/testing-auth/` - Authentication patterns

---

## Key Takeaways

1. ✅ Always use `has_element?` for assertions on large pages
2. ✅ Use data attributes (`data-testid`) for stable test selectors
3. ✅ Test user interactions (clicks, form submissions) with element-based approach
4. ✅ Use semantic selectors (h1, button, form) over CSS classes
5. ✅ Use `render(view)` for current HTML, not initial `html` variable
6. ❌ Avoid relying on initial `html` variable for large pages
7. ❌ Avoid CSS class selectors (they change with styling)
8. ❌ Don't use string matching for structural tests
