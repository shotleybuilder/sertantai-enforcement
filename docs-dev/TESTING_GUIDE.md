# Testing Guide

Comprehensive guide to testing in the EHS Enforcement project using ExUnit, Phoenix LiveView testing, and Ash Framework patterns.

## Table of Contents

- [Testing Philosophy](#testing-philosophy)
- [Test Structure](#test-structure)
- [Running Tests](#running-tests)
- [Testing Ash Resources](#testing-ash-resources)
- [Testing LiveViews](#testing-liveviews)
- [Testing Controllers](#testing-controllers)
- [Testing Components](#testing-components)
- [Testing Integrations](#testing-integrations)
- [Test Data Setup](#test-data-setup)
- [Coverage and Quality](#coverage-and-quality)
- [Debugging Tests](#debugging-tests)

## Testing Philosophy

### Critical Testing Rules

**⚠️ NEVER create scripts in `/scripts` for testing**
- ALWAYS use proper ExUnit tests in `/test` folder
- ALWAYS use ExUnit framework with `describe` blocks
- FOLLOW Phoenix LiveView testing patterns
- USE proper test assertions (`assert`, `refute`, `assert_receive`)
- CREATE integration tests that mirror real application usage

### Testing Principles

1. **Test behavior, not implementation**
2. **Use Ash patterns in tests** (never bypass with Ecto)
3. **Keep tests fast** (use database transactions)
4. **Test edge cases** and error conditions
5. **Write descriptive test names**

## Test Structure

### Directory Organization

```
test/
├── support/              # Test helpers and utilities
│   ├── conn_case.ex     # Controller test setup
│   ├── data_case.ex     # Database test setup
│   └── fixtures.ex      # Test data factories
├── ehs_enforcement/     # Mirrors lib/ehs_enforcement/
│   ├── enforcement/     # Domain logic tests
│   ├── agencies/        # Agency-specific tests
│   └── integrations/    # Integration tests
└── ehs_enforcement_web/ # Mirrors lib/ehs_enforcement_web/
    ├── live/            # LiveView tests
    ├── controllers/     # Controller tests
    └── components/      # Component tests
```

### Test File Naming

```elixir
# Implementation file
lib/ehs_enforcement/enforcement/case.ex

# Test file (add _test.exs suffix)
test/ehs_enforcement/enforcement/case_test.exs
```

## Running Tests

### Basic Commands

```bash
# Run all tests
mix test

# Run specific file
mix test test/ehs_enforcement/enforcement/case_test.exs

# Run specific test by line number
mix test test/ehs_enforcement/enforcement/case_test.exs:23

# Run tests matching pattern
mix test --only focus  # Run tests tagged with @tag :focus

# Run with coverage
mix test --cover

# Show slowest tests
mix test --slowest 10

# Limit failures
mix test --max-failures 5

# Run in specific environment
MIX_ENV=test mix test
```

### Watch Mode (Optional)

If you have `mix_test_watch` installed:

```bash
# Watch and rerun tests on file changes
mix test.watch

# Watch specific test
mix test.watch test/ehs_enforcement/enforcement/case_test.exs
```

### Parallel Testing

```bash
# Run tests in parallel (default)
mix test

# Run tests serially (for debugging)
mix test --trace
```

## Testing Ash Resources

### Required Imports

**⚠️ CRITICAL**: Always add these at the top of Ash resource tests:

```elixir
defmodule EhsEnforcement.Enforcement.CaseTest do
  use EhsEnforcement.DataCase

  # REQUIRED for Ash queries
  require Ash.Query
  import Ash.Expr

  # Now you can use Ash filters
end
```

### Basic Resource Testing

```elixir
defmodule EhsEnforcement.Enforcement.CaseTest do
  use EhsEnforcement.DataCase

  require Ash.Query
  import Ash.Expr

  alias EhsEnforcement.Enforcement.Case

  describe "create/1" do
    test "creates case with valid attributes" do
      agency = create_agency()

      assert {:ok, case} =
        Ash.create(Case, %{
          title: "Test Case",
          agency_id: agency.id,
          case_date: ~D[2024-01-01]
        })

      assert case.title == "Test Case"
    end

    test "fails with invalid attributes" do
      assert {:error, %Ash.Error{}} =
        Ash.create(Case, %{title: nil})
    end
  end

  describe "read/1" do
    test "lists all cases" do
      case1 = create_case(title: "Case 1")
      case2 = create_case(title: "Case 2")

      assert {:ok, cases} = Ash.read(Case)
      assert length(cases) == 2
    end

    test "filters cases by agency" do
      agency1 = create_agency(name: "Agency 1")
      agency2 = create_agency(name: "Agency 2")

      case1 = create_case(agency_id: agency1.id)
      case2 = create_case(agency_id: agency2.id)

      # Filter using Ash.Query
      {:ok, cases} =
        Case
        |> Ash.Query.filter(agency_id == ^agency1.id)
        |> Ash.read()

      assert length(cases) == 1
      assert hd(cases).id == case1.id
    end
  end

  describe "update/2" do
    test "updates case with valid attributes" do
      case = create_case(title: "Old Title")

      assert {:ok, updated_case} =
        Ash.update(case, %{title: "New Title"})

      assert updated_case.title == "New Title"
    end
  end

  describe "destroy/1" do
    test "deletes case" do
      case = create_case()

      assert :ok = Ash.destroy(case)

      assert {:ok, []} =
        Case
        |> Ash.Query.filter(id == ^case.id)
        |> Ash.read()
    end
  end

  # Helper functions
  defp create_agency(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Test Agency",
        country: "England"
      })

    {:ok, agency} = Ash.create(Agency, attrs)
    agency
  end

  defp create_case(attrs \\ %{}) do
    agency = attrs[:agency_id] && get_agency(attrs[:agency_id]) || create_agency()

    attrs =
      attrs
      |> Enum.into(%{
        title: "Test Case",
        agency_id: agency.id,
        case_date: ~D[2024-01-01]
      })

    {:ok, case} = Ash.create(Case, attrs)
    case
  end
end
```

### Testing with Policies

```elixir
test "user can only read their own cases" do
  user1 = create_user()
  user2 = create_user()

  case1 = create_case(owner_id: user1.id)
  case2 = create_case(owner_id: user2.id)

  # User 1 can read their case
  assert {:ok, [^case1]} =
    Case
    |> Ash.Query.filter(id == ^case1.id)
    |> Ash.read(actor: user1)

  # User 1 cannot read user 2's case
  assert {:ok, []} =
    Case
    |> Ash.Query.filter(id == ^case2.id)
    |> Ash.read(actor: user1)
end
```

### Testing Relationships

```elixir
test "loads case with offender" do
  case = create_case()
  offender = create_offender(case_id: case.id)

  {:ok, loaded_case} =
    Case
    |> Ash.Query.filter(id == ^case.id)
    |> Ash.Query.load(:offender)
    |> Ash.read()
    |> then(fn {:ok, [case]} -> {:ok, case} end)

  assert loaded_case.offender.id == offender.id
end
```

## Testing LiveViews

### Basic LiveView Testing

```elixir
defmodule EhsEnforcementWeb.CaseLive.IndexTest do
  use EhsEnforcementWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Index" do
    setup do
      # Create test data
      case = create_case(title: "Test Case")
      %{case: case}
    end

    test "lists all cases", %{conn: conn, case: case} do
      {:ok, _index_live, html} = live(conn, ~p"/cases")

      assert html =~ "Listing Cases"
      assert html =~ case.title
    end

    test "searches cases", %{conn: conn, case: case} do
      {:ok, index_live, _html} = live(conn, ~p"/cases")

      # Simulate search
      html =
        index_live
        |> form("#search-form", search: %{query: "Test"})
        |> render_change()

      assert html =~ case.title
    end

    test "navigates to case details", %{conn: conn, case: case} do
      {:ok, index_live, _html} = live(conn, ~p"/cases")

      {:ok, _show_live, html} =
        index_live
        |> element("#case-#{case.id} a", "Show")
        |> render_click()
        |> follow_redirect(conn, ~p"/cases/#{case.id}")

      assert html =~ case.title
    end
  end
end
```

### Testing LiveView Forms

```elixir
defmodule EhsEnforcementWeb.CaseLive.FormComponentTest do
  use EhsEnforcementWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "create case" do
    test "creates case with valid data", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/cases")

      # Click new button
      {:ok, form_live, _html} =
        index_live
        |> element("a", "New Case")
        |> render_click()
        |> follow_redirect(conn, ~p"/cases/new")

      # Fill form
      assert form_live
             |> form("#case-form", case: %{title: "Invalid"})
             |> render_change() =~ "can't be blank"

      # Submit valid form
      {:ok, _, html} =
        form_live
        |> form("#case-form", case: %{
          title: "New Case",
          case_date: "2024-01-01"
        })
        |> render_submit()
        |> follow_redirect(conn, ~p"/cases")

      assert html =~ "Case created successfully"
      assert html =~ "New Case"
    end
  end
end
```

### Testing LiveView Events

```elixir
test "handles delete event", %{conn: conn, case: case} do
  {:ok, index_live, _html} = live(conn, ~p"/cases")

  # Trigger delete event
  html =
    index_live
    |> element("#case-#{case.id} button", "Delete")
    |> render_click()

  assert html =~ "Case deleted successfully"
  refute html =~ case.title
end

test "handles sort event", %{conn: conn} do
  {:ok, index_live, _html} = live(conn, ~p"/cases")

  # Click sort header
  html =
    index_live
    |> element("th", "Date")
    |> render_click()

  # Verify sorted order
  assert html =~ "sorted by date"
end
```

### Testing LiveView Hooks

```elixir
test "runs live view hook on mount", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/cases")

  # Verify hook was called
  assert has_element?(view, "[phx-hook='DatePicker']")
end
```

## Testing Controllers

```elixir
defmodule EhsEnforcementWeb.CaseControllerTest do
  use EhsEnforcementWeb.ConnCase

  describe "index" do
    test "lists all cases", %{conn: conn} do
      case = create_case()

      conn = get(conn, ~p"/api/cases")

      assert json_response(conn, 200)["data"] |> length() == 1
    end
  end

  describe "create" do
    test "creates case with valid data", %{conn: conn} do
      agency = create_agency()

      conn =
        post(conn, ~p"/api/cases", %{
          case: %{
            title: "Test Case",
            agency_id: agency.id
          }
        })

      assert %{"id" => id} = json_response(conn, 201)["data"]
    end

    test "returns errors with invalid data", %{conn: conn} do
      conn = post(conn, ~p"/api/cases", %{case: %{title: nil}})

      assert json_response(conn, 422)["errors"] != %{}
    end
  end
end
```

## Testing Components

### Functional Components

```elixir
defmodule EhsEnforcementWeb.Components.CaseCardTest do
  use EhsEnforcementWeb.ConnCase

  import Phoenix.LiveViewTest
  import EhsEnforcementWeb.Components.CaseCard

  test "renders case card" do
    case = create_case(title: "Test Case")

    html =
      render_component(&case_card/1, case: case)

    assert html =~ "Test Case"
    assert html =~ "View Details"
  end

  test "shows offender info when available" do
    case = create_case()
    offender = create_offender(case_id: case.id, name: "Test Offender")

    html =
      render_component(&case_card/1,
        case: case |> Ash.load!(:offender)
      )

    assert html =~ "Test Offender"
  end
end
```

## Testing Integrations

### Testing External APIs (Airtable)

```elixir
defmodule EhsEnforcement.Integrations.AirtableTest do
  use EhsEnforcement.DataCase

  import Mox

  # Setup mock
  setup :verify_on_exit!

  describe "fetch_cases/1" do
    test "fetches cases from Airtable" do
      # Mock HTTP response
      expect(HTTPClientMock, :get, fn _url, _headers ->
        {:ok, %{status: 200, body: mock_airtable_response()}}
      end)

      assert {:ok, cases} = Airtable.fetch_cases()
      assert length(cases) == 2
    end

    test "handles API errors" do
      expect(HTTPClientMock, :get, fn _url, _headers ->
        {:error, :timeout}
      end)

      assert {:error, :timeout} = Airtable.fetch_cases()
    end
  end

  defp mock_airtable_response do
    %{
      "records" => [
        %{"id" => "rec1", "fields" => %{"title" => "Case 1"}},
        %{"id" => "rec2", "fields" => %{"title" => "Case 2"}}
      ]
    }
  end
end
```

### Testing Background Jobs (Oban)

```elixir
defmodule EhsEnforcement.Workers.ScrapeWorkerTest do
  use EhsEnforcement.DataCase
  use Oban.Testing, repo: EhsEnforcement.Repo

  alias EhsEnforcement.Workers.ScrapeWorker

  test "enqueues scrape job" do
    assert {:ok, %Oban.Job{}} =
      ScrapeWorker.new(%{agency: "hse"})
      |> Oban.insert()
  end

  test "performs scraping" do
    assert :ok =
      perform_job(ScrapeWorker, %{agency: "hse"})

    # Verify scraping happened
    assert {:ok, cases} = Ash.read(Case)
    assert length(cases) > 0
  end
end
```

## Test Data Setup

### Using Fixtures

```elixir
# test/support/fixtures.ex
defmodule EhsEnforcement.Fixtures do
  def agency_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Test Agency",
        country: "England",
        agency_type: "regulator"
      })

    {:ok, agency} =
      Ash.create(EhsEnforcement.Enforcement.Agency, attrs)

    agency
  end

  def case_fixture(attrs \\ %{}) do
    agency = attrs[:agency_id] && get_agency!(attrs[:agency_id]) || agency_fixture()

    attrs =
      attrs
      |> Map.drop([:agency_id])
      |> Enum.into(%{
        title: "Test Case #{System.unique_integer()}",
        agency_id: agency.id,
        case_date: ~D[2024-01-01],
        offence_result: "conviction"
      })

    {:ok, case} =
      Ash.create(EhsEnforcement.Enforcement.Case, attrs)

    case
  end
end

# Use in tests
defmodule MyTest do
  use EhsEnforcement.DataCase
  import EhsEnforcement.Fixtures

  test "something" do
    case = case_fixture(title: "Custom Title")
    # test logic
  end
end
```

### Setup Blocks

```elixir
describe "case operations" do
  setup do
    agency = agency_fixture()
    case = case_fixture(agency_id: agency.id)

    %{agency: agency, case: case}
  end

  test "reads case", %{case: case} do
    assert {:ok, [found_case]} =
      Case
      |> Ash.Query.filter(id == ^case.id)
      |> Ash.read()

    assert found_case.id == case.id
  end
end
```

## Coverage and Quality

### Running Coverage

```bash
# Run with coverage
mix test --cover

# Generate HTML coverage report (requires excoveralls)
mix coveralls.html

# View coverage report
open cover/excoveralls.html
```

### Coverage Goals

- **Overall**: 80%+ coverage
- **Domain Logic**: 90%+ coverage
- **LiveViews**: 70%+ coverage
- **Controllers**: 80%+ coverage

### Quality Checks

```bash
# Run all quality checks
mix format --check-formatted
mix credo --strict
mix dialyzer
mix test
```

## Debugging Tests

### Print Debugging

```elixir
test "something" do
  case = create_case()

  # Debug output
  IO.inspect(case, label: "CASE")

  # Or use dbg
  case |> dbg()

  # Continue test
  assert case.title == "Test"
end
```

### Using IEx.pry

```elixir
test "something" do
  case = create_case()

  require IEx
  IEx.pry()  # Execution pauses here

  assert case.title == "Test"
end
```

Run test:
```bash
# Must use --trace flag
mix test --trace test/file_test.exs:10
```

### Isolating Tests

```elixir
# Run only this test
@tag :focus
test "specific test" do
  # test logic
end
```

```bash
mix test --only focus
```

### Verbose Output

```bash
# Show all output
mix test --trace

# Show test names
mix test --verbose
```

## Common Testing Patterns

### Testing Async Operations

```elixir
test "handles async message" do
  {:ok, view, _html} = live(conn, ~p"/cases")

  # Send async message
  send(view.pid, {:update, %{status: "complete"}})

  # Wait for update
  assert render_async(view) =~ "complete"
end
```

### Testing Forms with Validation

```elixir
test "validates form fields" do
  {:ok, view, _html} = live(conn, ~p"/cases/new")

  # Trigger validation
  view
  |> form("#case-form", case: %{title: ""})
  |> render_change()

  # Check for error
  assert has_element?(view, "#case-form .error", "can't be blank")
end
```

### Testing Navigation

```elixir
test "navigates between pages" do
  {:ok, view, _html} = live(conn, ~p"/cases")

  # Click link
  {:ok, show_view, _html} =
    view
    |> element("a", "View")
    |> render_click()
    |> follow_redirect(conn, ~p"/cases/123")

  assert has_element?(show_view, "h1", "Case Details")
end
```

---

**Related Guides:**
- [DEVELOPMENT_WORKFLOW.md](DEVELOPMENT_WORKFLOW.md) - Development processes
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
- [GETTING_STARTED.md](GETTING_STARTED.md) - Initial setup

**External Resources:**
- [ExUnit Documentation](https://hexdocs.pm/ex_unit/ExUnit.html)
- [Phoenix LiveView Testing](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html)
- [Ash Testing Patterns](https://hexdocs.pm/ash/testing.html)
