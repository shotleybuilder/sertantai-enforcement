# Production RPC Commands Reference

**Remote Procedure Call (RPC)** allows you to execute Elixir code directly on the running production application without rebuilding or restarting.

## Table of Contents

- [What is RPC?](#what-is-rpc)
- [When to Use RPC vs Rebuild](#when-to-use-rpc-vs-rebuild)
- [Basic Syntax](#basic-syntax)
- [Common Operations](#common-operations)
- [Debugging Commands](#debugging-commands)
- [Safety Guidelines](#safety-guidelines)

---

## What is RPC?

RPC connects to the running Erlang VM (BEAM) and executes code instantly:

```bash
# General syntax
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Your.Elixir.Code.here()'
```

**Advantages:**
- ⚡ Instant execution (no rebuild/redeploy)
- 🔍 Real-time inspection of production state
- 🛠️ Quick fixes and hotfixes
- 📊 Live metrics and diagnostics

**Limitations:**
- ⚠️ Changes are NOT persistent (lost on restart)
- ⚠️ No version control
- ⚠️ Can affect running system if misused

---

## When to Use RPC vs Rebuild

### Use RPC (Runtime Changes)

✅ **Temporary debugging:**
```bash
# Change log level temporarily
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Logger.configure(level: :debug)'
```

✅ **One-off data operations:**
```bash
# Refresh metrics manually
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:admin)'
```

✅ **Inspecting state:**
```bash
# Check current metrics count
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Enforcement.Metrics.get_current_metrics() |> elem(1) |> length()'
```

### Use Rebuild (Permanent Changes)

✅ **Configuration changes in `config/prod.exs`:**
```elixir
# File: config/prod.exs
config :logger, level: :info  # This requires rebuild
```

✅ **Code changes:**
- New features
- Bug fixes
- Schema changes

✅ **Dependency updates:**
- New packages
- Version bumps

**Rebuild process:**
```bash
./scripts/build.sh           # 5-10 minutes
./scripts/push.sh            # 1-2 minutes
./scripts/deployment/deploy-prod.sh  # 1-2 minutes
```

---

## Basic Syntax

### Single-Line Commands

```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Module.function(args)'
```

### Multi-Line Commands (Using Heredoc)

```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc '
IO.puts("Starting operation...")
result = Module.function()
IO.inspect(result, label: "Result")
:ok
'
```

### Piping Results

```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Enforcement.Metrics.get_current_metrics() |> elem(1) |> length() |> IO.inspect()'
```

---

## Common Operations

### Metrics Management

**Refresh all metrics:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:admin)'
```

**Check metrics count:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Enforcement.Metrics.get_current_metrics() |> elem(1) |> length() |> IO.inspect(label: "Metrics count")'
```

**Inspect metrics structure:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc '
{:ok, metrics} = EhsEnforcement.Enforcement.Metrics.get_current_metrics()
Enum.each(metrics, fn m ->
  IO.puts("Period: #{m.period}, Agency: #{m.agency_id || "all"}, Cases: #{m.total_cases_count}, Notices: #{m.total_notices_count}")
end)
'
```

### Logger Configuration

**Enable debug logging:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Logger.configure(level: :debug)'
```

**Revert to info level:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Logger.configure(level: :info)'
```

**Check current log level:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Logger.level() |> IO.inspect()'
```

### Database Operations

**Run raw SQL query:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Repo.query!("SELECT COUNT(*) FROM metrics") |> Map.get(:rows) |> List.first() |> List.first() |> IO.inspect(label: "Metrics count")'
```

**Check migration status:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Release.status'
```

**Run migrations:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Release.migrate'
```

### Application State

**Get all application config:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Application.get_all_env(:ehs_enforcement) |> IO.inspect(limit: :infinity)'
```

**Get specific config value:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Application.get_env(:ehs_enforcement, EhsEnforcementWeb.Endpoint) |> Keyword.get(:url) |> IO.inspect()'
```

**List all running processes:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc ':erlang.processes() |> length() |> IO.inspect(label: "Process count")'
```

---

## Debugging Commands

### Memory Usage

**Check total memory:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc ':erlang.memory() |> Enum.map(fn {k,v} -> {k, "#{div(v, 1024*1024)} MB"} end) |> IO.inspect()'
```

**Memory breakdown:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc '
memory = :erlang.memory()
total_mb = div(memory[:total], 1024*1024)
processes_mb = div(memory[:processes], 1024*1024)
ets_mb = div(memory[:ets], 1024*1024)
IO.puts("Total: #{total_mb} MB")
IO.puts("Processes: #{processes_mb} MB")
IO.puts("ETS: #{ets_mb} MB")
'
```

### Performance

**Check scheduler utilization:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc ':scheduler.utilization(1) |> IO.inspect()'
```

**Count active connections:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Phoenix.PubSub.subscribers(EhsEnforcement.PubSub, "sync:updates") |> length() |> IO.inspect(label: "Subscribers")'
```

### Database Connection Pool

**Check Ecto pool status:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc ':sys.get_state(EhsEnforcement.Repo) |> IO.inspect()'
```

**Count active database connections:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Repo.query!("SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()") |> Map.get(:rows) |> List.first() |> List.first() |> IO.inspect(label: "DB connections")'
```

### Phoenix LiveView

**Check connected LiveView sockets:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Registry.count(Phoenix.LiveView.Socket) |> IO.inspect(label: "Active LiveView sockets")'
```

### Ash Resources

**List all Ash domains:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc '[EhsEnforcement.Accounts, EhsEnforcement.Configuration, EhsEnforcement.Enforcement, EhsEnforcement.Events, EhsEnforcement.Scraping] |> IO.inspect(label: "Ash Domains")'
```

---

## Safety Guidelines

### ⚠️ DO NOT

- ❌ **Run destructive operations without backups**
  ```bash
  # DANGEROUS - Don't do this!
  docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Repo.delete_all(EhsEnforcement.Enforcement.Case)'
  ```

- ❌ **Modify production data directly via RPC**
  - Use proper admin interfaces
  - Go through application logic
  - Maintain audit trails

- ❌ **Execute untested code on production**
  - Test in development first
  - Use staging environment
  - Understand the impact

- ❌ **Leave debug logging enabled permanently**
  ```bash
  # Remember to revert after debugging
  docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Logger.configure(level: :info)'
  ```

### ✅ DO

- ✅ **Test RPC commands in development first**
  ```bash
  # On dev server
  docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Your.Code.here()'
  ```

- ✅ **Use read-only operations for inspection**
  ```bash
  docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Enforcement.Case |> Ash.count!() |> IO.inspect()'
  ```

- ✅ **Document what you changed**
  - Log RPC commands used
  - Note timestamps
  - Record results

- ✅ **Revert temporary changes**
  ```bash
  # After debugging, restore normal config
  docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Logger.configure(level: :info)'
  ```

---

## Real-World Examples

### Example 1: Debug Slow Dashboard Load

```bash
# 1. Enable debug logging
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Logger.configure(level: :debug)'

# 2. Check if metrics exist
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Enforcement.Metrics.get_current_metrics() |> elem(1) |> length() |> IO.inspect(label: "Metrics")'

# 3. Refresh metrics if missing
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:admin)'

# 4. Tail logs to see what's happening
docker compose logs -f ehs-enforcement

# 5. Revert to normal logging
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Logger.configure(level: :info)'
```

### Example 2: Check Migration Status

```bash
# Check what migrations have run
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Release.status'

# Check if specific table exists
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Repo.query!("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = '\''metrics'\'')") |> Map.get(:rows) |> List.first() |> List.first() |> IO.inspect(label: "Metrics table exists?")'
```

### Example 3: Manual Metrics Refresh After Scraping

```bash
# After running scraper, manually refresh metrics
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc '
IO.puts("Starting metrics refresh...")
start = System.monotonic_time(:millisecond)
{:ok, _} = EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:admin)
duration = System.monotonic_time(:millisecond) - start
IO.puts("✅ Refresh completed in #{duration}ms")
'
```

---

## Troubleshooting RPC Issues

### Error: "Node is not running"

**Problem:** Container isn't started or app crashed

**Solution:**
```bash
# Check container status
docker compose ps ehs-enforcement

# Check logs for crash
docker compose logs --tail=50 ehs-enforcement

# Restart if needed
docker compose restart ehs-enforcement
```

### Error: "Connection refused"

**Problem:** Erlang distribution not enabled in release

**Solution:**
Check that your `rel/env.sh.eex` has:
```bash
export RELEASE_DISTRIBUTION=name
export RELEASE_NODE=<%= @release.name %>@127.0.0.1
```

### Error: Timeout executing RPC

**Problem:** Command takes too long or blocks

**Solution:**
```bash
# Run in background via spawn
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'spawn(fn -> YourLongRunningCode.run() end)'
```

---

## Quick Reference

```bash
# Logger
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Logger.configure(level: :debug)'
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'Logger.configure(level: :info)'

# Metrics
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:admin)'
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Enforcement.Metrics.get_current_metrics() |> elem(1) |> length()'

# Memory
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc ':erlang.memory() |> Enum.map(fn {k,v} -> {k, div(v, 1024*1024)} end)'

# Database
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Repo.query!("SELECT COUNT(*) FROM cases")'

# Migrations
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Release.status'
docker compose exec ehs-enforcement /app/bin/ehs_enforcement rpc 'EhsEnforcement.Release.migrate'
```

---

## Additional Resources

- [Elixir Release Documentation](https://hexdocs.pm/mix/Mix.Tasks.Release.html)
- [Phoenix Deployment Guides](https://hexdocs.pm/phoenix/deployment.html)
- [Erlang RPC Documentation](https://www.erlang.org/doc/man/rpc.html)

---

**Last Updated:** 2025-10-19
**Maintainer:** Development Team
