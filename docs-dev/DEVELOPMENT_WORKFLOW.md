# Development Workflow

This guide covers the day-to-day development workflow for the EHS Enforcement project.

## Table of Contents

- [Daily Development Loop](#daily-development-loop)
- [Working with Ash Resources](#working-with-ash-resources)
- [Feature Development Process](#feature-development-process)
- [Database Migrations](#database-migrations)
- [Testing Your Changes](#testing-your-changes)
- [Git Workflow](#git-workflow)
- [Code Review Process](#code-review-process)
- [Debugging Tips](#debugging-tips)

## Daily Development Loop

### 1. Start Your Day

```bash
# Pull latest changes
git pull origin main

# Update dependencies if mix.lock changed
mix deps.get

# Check for pending migrations
mix ecto.migrations

# Start the dev environment
./scripts/development/ehs-dev.sh
# OR for IEx:
iex -S mix phx.server
```

### 2. Make Your Changes

- Edit files in `lib/` or `lib/ehs_enforcement_web/`
- Phoenix automatically recompiles on file save
- Browser auto-refreshes for LiveView changes
- Use IEx for interactive testing

### 3. Test Your Changes

```bash
# Run relevant tests
mix test test/path/to/your_test.exs

# Run all tests
mix test

# Format code
mix format
```

### 4. Commit and Push

```bash
git add .
git commit -m "feat: descriptive message"
git push origin your-branch
```

## Working with Ash Resources

### The Ash Development Cycle

**⚠️ GOLDEN RULE**: After modifying Ash resources, ALWAYS run:

```bash
# 1. Check for needed migrations
mix ash.codegen --check

# 2. Apply migrations
mix ash.migrate

# 3. THEN start/restart the server
mix phx.server
```

### Creating a New Ash Resource

```bash
# 1. Create the resource file
touch lib/ehs_enforcement/enforcement/my_resource.ex
```

```elixir
# 2. Define the resource
defmodule EhsEnforcement.Enforcement.MyResource do
  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "my_resources"
    repo EhsEnforcement.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name]
    end

    update :update do
      accept [:name]
    end
  end
end
```

```bash
# 3. Add to domain
# Edit lib/ehs_enforcement/enforcement.ex and add to resources list

# 4. Generate migration
mix ash.codegen

# 5. Review the generated migration in priv/repo/migrations/

# 6. Apply migration
mix ash.migrate
```

### Modifying an Existing Ash Resource

```elixir
# 1. Edit the resource
# Add a new attribute
attribute :description, :string

# 2. Check what migration will be generated
mix ash.codegen --check

# 3. Generate and review migration
mix ash.codegen

# 4. Apply migration
mix ash.migrate

# 5. Restart server
mix phx.server
```

### Using Ash in Your Code

```elixir
# Always use Ash functions, never Repo functions

# Create
{:ok, resource} = Ash.create(MyResource, %{name: "Test"}, actor: current_user)

# Read all
{:ok, resources} = Ash.read(MyResource, actor: current_user)

# Read with filters
{:ok, resources} =
  MyResource
  |> Ash.Query.filter(name == "Test")
  |> Ash.read(actor: current_user)

# Get by ID
{:ok, resource} = Ash.get(MyResource, id, actor: current_user)

# Update
{:ok, updated} = Ash.update(resource, %{name: "New Name"}, actor: current_user)

# Destroy
:ok = Ash.destroy(resource, actor: current_user)
```

### Using AshPhoenix.Form in LiveViews

```elixir
# In your LiveView mount
def mount(_params, _session, socket) do
  form = AshPhoenix.Form.for_create(MyResource, :create, forms: [auto?: false])

  {:ok, assign(socket, form: form)}
end

# Handle form validation
def handle_event("validate", %{"form" => params}, socket) do
  form = AshPhoenix.Form.validate(socket.assigns.form, params)
  {:noreply, assign(socket, form: form)}
end

# Handle form submission
def handle_event("save", %{"form" => params}, socket) do
  case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
    {:ok, resource} ->
      {:noreply,
       socket
       |> put_flash(:info, "Created successfully")
       |> push_navigate(to: ~p"/resources/#{resource.id}")}

    {:error, form} ->
      {:noreply, assign(socket, form: form)}
  end
end
```

## Feature Development Process

### 1. Plan Your Feature

- Create a feature branch: `git checkout -b feature/my-feature`
- If complex, create a planning doc in `docs-dev/plan/`
- Identify which Ash resources and actions you need

### 2. Implement Backend (Ash Resources)

```bash
# Create/modify Ash resources
# Generate migrations
mix ash.codegen
mix ash.migrate

# Test in IEx
iex -S mix
# Try your Ash operations interactively
```

### 3. Implement Frontend (LiveView)

```elixir
# Create LiveView in lib/ehs_enforcement_web/live/
# Use AshPhoenix.Form for forms
# Use Ash.read/2 for data loading
```

### 4. Add Tests

```elixir
# Create test file in test/ (mirrors lib/ structure)
# Test Ash resource operations
# Test LiveView interactions
```

### 5. Documentation

```elixir
# Add @moduledoc to new modules
# Add @doc to public functions
# Regenerate docs: mix docs
```

## Database Migrations

### Ash Migrations (Preferred)

```bash
# Check if migration needed
mix ash.codegen --check

# Generate migration
mix ash.codegen

# Review generated migration
cat priv/repo/migrations/TIMESTAMP_*.exs

# Apply migration
mix ash.migrate

# Rollback if needed
mix ash.rollback
```

### Manual Ecto Migrations (When Needed)

```bash
# Create migration
mix ecto.gen.migration add_custom_index

# Edit priv/repo/migrations/TIMESTAMP_add_custom_index.exs

# Apply
mix ecto.migrate
```

### Migration Safety Checklist

**Before running migrations:**
- [ ] Check existing schema: `\d table_name` in psql
- [ ] Verify resource snapshots in `priv/resource_snapshots/`
- [ ] Review generated SQL
- [ ] Remove duplicate table creation if table exists
- [ ] Test in development first
- [ ] Back up production before applying

### Common Migration Issues

**Table already exists:**
```elixir
# In migration, change:
create table(:my_table) do
  # ...
end

# To:
create_if_not_exists table(:my_table) do
  # ...
end
```

**Migration conflicts:**
```bash
# Reset dev database
mix ecto.reset

# Re-run all migrations
mix ash.migrate
mix ecto.migrate
```

## Testing Your Changes

See [TESTING_GUIDE.md](TESTING_GUIDE.md) for comprehensive testing guide.

### Quick Test Commands

```bash
# Run all tests
mix test

# Run specific file
mix test test/ehs_enforcement/enforcement/case_test.exs

# Run specific test
mix test test/ehs_enforcement/enforcement/case_test.exs:23

# Watch mode (requires mix_test_watch)
mix test.watch

# With coverage
mix test --cover
```

### Testing Ash Resources

```elixir
defmodule EhsEnforcement.Enforcement.MyResourceTest do
  use EhsEnforcement.DataCase

  # Required for Ash queries
  require Ash.Query
  import Ash.Expr

  describe "create/1" do
    test "creates resource with valid attributes" do
      assert {:ok, resource} =
        Ash.create(MyResource, %{name: "Test"})

      assert resource.name == "Test"
    end
  end
end
```

## Git Workflow

### Branch Naming

- `feature/description` - New features
- `fix/description` - Bug fixes
- `refactor/description` - Code refactoring
- `docs/description` - Documentation updates
- `test/description` - Test additions/fixes

### Commit Messages

Follow conventional commits:

```bash
# Features
git commit -m "feat: add user authentication"
git commit -m "feat(cases): add CSV export functionality"

# Fixes
git commit -m "fix: resolve database connection timeout"
git commit -m "fix(scraper): handle missing date fields"

# Documentation
git commit -m "docs: update API documentation"

# Refactoring
git commit -m "refactor: extract duplicate code into helper"

# Tests
git commit -m "test: add integration tests for case creation"
```

### Pull Request Process

1. **Create PR** with descriptive title and description
2. **Link issues** if applicable
3. **Request review** from team members
4. **Address feedback** promptly
5. **Merge** when approved and CI passes

## Debugging Tips

### Using IEx

```elixir
# Start with IEx
iex -S mix phx.server

# Reload all modules
recompile()

# Test a function
EhsEnforcement.Enforcement.Case.some_function()

# Introspect module
EhsEnforcement.Enforcement.Case.__info__(:functions)

# Use dbg/1 for debugging
result = some_function() |> dbg()
```

### Using IEx.pry

```elixir
# In your code, add:
require IEx
IEx.pry()

# Run code that hits this line
# You'll get an IEx prompt at that point
# Type 'continue' to resume
```

### LiveView Debugging

```elixir
# In your LiveView
def handle_event("debug", _params, socket) do
  IO.inspect(socket.assigns, label: "SOCKET ASSIGNS")
  {:noreply, socket}
end

# Add to your template
<button phx-click="debug">Debug</button>
```

### Database Debugging

```bash
# Connect to database
psql -d ehs_enforcement_dev -U postgres

# Common queries
\dt                          # List tables
\d cases                     # Describe table
SELECT * FROM cases LIMIT 5; # Query data
```

### Logging

```elixir
# Use Logger
require Logger

Logger.debug("Debug info: #{inspect(data)}")
Logger.info("Something happened")
Logger.warning("Warning message")
Logger.error("Error occurred: #{inspect(error)}")
```

## Performance Optimization

### Database Queries

```elixir
# Preload associations
{:ok, cases} =
  Case
  |> Ash.Query.load([:offender, :agency])
  |> Ash.read()

# Use pagination
{:ok, page} =
  Case
  |> Ash.Query.page(limit: 20, offset: 0)
  |> Ash.read()
```

### LiveView Optimization

```elixir
# Use temporary assigns for large data
socket = assign(socket, :large_list, temporary_assigns: [large_list: []])

# Debounce events
<form phx-change="validate" phx-debounce="300">
```

## Common Development Tasks

### Reset Everything

```bash
# Nuclear option - fresh start
mix ecto.reset        # Drop, create, migrate, seed
mix deps.clean --all  # Clean dependencies
mix deps.get          # Reinstall dependencies
mix compile --force   # Force recompile
```

### Check Code Quality

```bash
# Format
mix format --check-formatted

# Credo
mix credo --strict

# Dialyzer
mix dialyzer

# All checks
mix format --check-formatted && mix credo && mix dialyzer && mix test
```

### Generate Documentation

```bash
# Generate ExDoc
mix docs

# Open in browser (macOS)
open docs_dev/exdoc/index.html

# Open in browser (Linux)
xdg-open docs_dev/exdoc/index.html
```

## Development Environment Variables

Create `.env` file:

```bash
# Database
DATABASE_URL=postgresql://postgres:postgres@localhost:5434/ehs_enforcement_dev

# Airtable
AT_UK_E_API_KEY=your_api_key_here

# Phoenix
SECRET_KEY_BASE=your_secret_key_here
PHX_HOST=localhost
PORT=4002

# Development
MIX_ENV=dev
```

Load with:
```bash
source .env
```

---

**Next Steps:**
- Learn testing patterns: [TESTING_GUIDE.md](TESTING_GUIDE.md)
- Troubleshoot issues: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Review deployment: [dev/deployment/DEPLOYMENT_CURRENT.md](dev/deployment/DEPLOYMENT_CURRENT.md)
