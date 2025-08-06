# Import and Sync Operations Guide

This guide covers the import and synchronization features available in the EHS Enforcement application, including the new generic sync engine powered by the `ncdb_2_phx` package.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Import Operations](#import-operations)
4. [Sync Configuration](#sync-configuration)
5. [Admin Interface](#admin-interface)
6. [Command Line Operations](#command-line-operations)
7. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
8. [Migration from Legacy System](#migration-from-legacy-system)

## Overview

The EHS Enforcement application provides comprehensive data import and synchronization capabilities:

- **One-time imports** from Airtable to PostgreSQL
- **Real-time progress tracking** with LiveView
- **Error recovery** and retry mechanisms
- **Batch processing** for large datasets
- **Multiple sync types** (cases, notices, all data)

### Key Features

- 🔄 **Streaming imports** - Memory-efficient processing of large datasets
- 📊 **Progress monitoring** - Real-time updates via Phoenix PubSub
- 🛡️ **Error handling** - Automatic retry and recovery
- 📦 **Batch processing** - Configurable batch sizes (default: 100 records)
- 🔍 **Duplicate prevention** - Uses `regulator_id` for uniqueness
- 📈 **Performance metrics** - Detailed statistics and analytics

## Architecture

### Current System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Admin Interface (LiveView)                │
├─────────────────────────────────────────────────────────────┤
│                         Sync Engine                          │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │   Session    │  │   Progress   │  │     Event       │   │
│  │  Management  │  │   Tracking   │  │  Broadcasting   │   │
│  └─────────────┘  └──────────────┘  └─────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    Source Adapters                           │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │  Airtable   │  │     CSV      │  │      API        │   │
│  │  Adapter    │  │   Adapter    │  │    Adapter      │   │
│  └─────────────┘  └──────────────┘  └─────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                  Target Processing                           │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │    Case     │  │    Notice    │  │    Offender     │   │
│  │  Processor  │  │  Processor   │  │    Matcher      │   │
│  └─────────────┘  └──────────────┘  └─────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Source Data** → Adapter → Stream Processing
2. **Validation** → Transformation → Deduplication
3. **Batch Processing** → Database Operations
4. **Progress Updates** → PubSub → LiveView UI

## Import Operations

### Import Cases from Airtable

Import enforcement cases (Court Cases and Cautions):

```elixir
# Basic import (up to 1000 cases)
EhsEnforcement.Sync.import_cases()

# Import with options
EhsEnforcement.Sync.import_cases(
  limit: 5000,        # Maximum records to import
  batch_size: 200,    # Records per batch
  actor: admin_user   # User performing import
)
```

### Import Notices from Airtable

Import enforcement notices (Improvement, Prohibition, etc.):

```elixir
# Basic import (up to 1000 notices)
EhsEnforcement.Sync.import_notices()

# Import with options
EhsEnforcement.Sync.import_notices(
  limit: 5000,
  batch_size: 200,
  actor: admin_user
)
```

### Import All Data

Import both cases and notices in a single operation:

```elixir
# Using the generic sync engine
config = %{
  source_adapter: NCDB2Phx.Adapters.AirtableAdapter,
  source_config: %{
    api_key: System.get_env("AT_UK_E_API_KEY"),
    base_id: "appq5OQW9bTHC1zO5",
    table_id: "tbl6NZm9bLU2ijivf"
  },
  target_resource: EhsEnforcement.Enforcement.Case,
  target_config: %{
    unique_field: :regulator_id,
    create_action: :create,
    update_action: :update
  },
  processing_config: %{
    batch_size: 100,
    limit: 10000,
    enable_error_recovery: true,
    enable_progress_tracking: true
  },
  pubsub_config: %{
    module: EhsEnforcement.PubSub,
    topic: "sync_progress"
  },
  session_config: %{
    sync_type: :import_all,
    description: "Full Airtable import"
  }
}

{:ok, result} = NCDB2Phx.execute_sync(config, actor: admin_user)
```

## Sync Configuration

### Environment Variables

Required environment variables for Airtable sync:

```bash
# Airtable API credentials
AT_UK_E_API_KEY=keyXXXXXXXXXXXXXX
AIRTABLE_BASE_ID=appq5OQW9bTHC1zO5
AIRTABLE_TABLE_ID=tbl6NZm9bLU2ijivf
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `limit` | Maximum records to import | 1000 |
| `batch_size` | Records processed per batch | 100 |
| `enable_error_recovery` | Retry failed records | true |
| `enable_progress_tracking` | Real-time progress updates | true |
| `max_retries` | Maximum retry attempts | 3 |
| `retry_delay_ms` | Delay between retries | 1000 |
| `rate_limit_delay_ms` | API rate limiting delay | 200 |

### Advanced Configuration

```elixir
# Custom sync configuration with all options
advanced_config = %{
  source_adapter: NCDB2Phx.Adapters.AirtableAdapter,
  source_config: %{
    api_key: System.get_env("AT_UK_E_API_KEY"),
    base_id: "appq5OQW9bTHC1zO5",
    table_id: "tbl6NZm9bLU2ijivf",
    view: "Grid view",              # Optional: specific view
    formula: "NOT({Status} = 'Deleted')",  # Optional: filter
    fields: ["regulator_id", "offender_name", "offence_action_type"],
    sort: [%{field: "offence_action_date", direction: "desc"}],
    page_size: 100,
    rate_limit_delay_ms: 200
  },
  target_resource: EhsEnforcement.Enforcement.Case,
  target_config: %{
    unique_field: :regulator_id,
    create_action: :create_with_offender,
    update_action: :update_with_offender,
    transform_fn: &transform_airtable_to_case/1
  },
  processing_config: %{
    batch_size: 200,
    limit: nil,  # No limit - import all
    enable_error_recovery: true,
    max_retries: 5,
    retry_backoff: :exponential,
    stop_on_error: false,
    error_threshold: 0.1,  # Stop if >10% errors
    record_validator: &validate_case_record/1,
    pre_batch_hook: &log_batch_start/1,
    post_batch_hook: &log_batch_complete/2
  },
  pubsub_config: %{
    module: EhsEnforcement.PubSub,
    topic: "sync_progress",
    broadcast_interval_ms: 1000
  },
  session_config: %{
    sync_type: :import_cases_enhanced,
    description: "Enhanced case import with validation",
    metadata: %{source: "admin_ui", user_id: admin_user.id}
  }
}
```

## Admin Interface

### Accessing the Admin Panel

The admin interface is available at:

```
https://yourdomain.com/admin/sync
```

### Features

1. **Sync Dashboard**
   - Active sync sessions
   - Recent sync history
   - Performance metrics

2. **One-Click Import**
   - Import Cases button
   - Import Notices button
   - Import All button

3. **Real-Time Progress**
   - Progress bars
   - Record counters
   - Error notifications
   - Batch tracking

4. **Configuration Panel**
   - Batch size adjustment
   - Limit configuration
   - Retry settings

### LiveView Components

The admin interface uses reusable LiveView components:

```elixir
# In your LiveView
def render(assigns) do
  ~H"""
  <.sync_dashboard sessions={@sessions} />
  
  <.sync_progress_panel 
    session_id={@current_session_id}
    progress={@progress}
    stats={@stats}
  />
  
  <.sync_configuration_form
    config={@sync_config}
    on_submit={&handle_config_update/1}
  />
  
  <.sync_history_table
    sessions={@recent_sessions}
    on_retry={&handle_retry/1}
  />
  """
end
```

## Command Line Operations

### Interactive Console

Access the running application console:

```bash
# Development
iex -S mix phx.server

# Production (Docker)
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement remote
```

### Import Commands

```elixir
# Import cases with default settings
EhsEnforcement.Sync.import_cases()

# Import notices with custom batch size
EhsEnforcement.Sync.import_notices(batch_size: 250)

# Get import statistics
{:ok, stats} = EhsEnforcement.Sync.get_case_import_stats()
IO.inspect(stats)
# => %{
#   total_cases: 5432,
#   recent_imports: 1200,
#   error_rate: 0.02
# }

# Clean up orphaned offenders
EhsEnforcement.Sync.cleanup_orphaned_offenders(dry_run: true)
```

### Monitoring Active Syncs

```elixir
# Get active sync sessions
{:ok, sessions} = NCDB2Phx.list_active_sessions()

# Get specific session status
{:ok, status} = NCDB2Phx.get_sync_status("sync_abc123")

# Cancel a running sync
NCDB2Phx.cancel_sync("sync_abc123")

# Get comprehensive metrics
{:ok, metrics} = NCDB2Phx.get_sync_metrics("sync_abc123")
```

### Database Queries

```elixir
# Check record counts
Ash.count!(EhsEnforcement.Enforcement.Case)
Ash.count!(EhsEnforcement.Enforcement.Notice)
Ash.count!(EhsEnforcement.Enforcement.Offender)

# Find duplicate records
EhsEnforcement.Repo.query!("""
  SELECT regulator_id, COUNT(*) as count
  FROM cases
  GROUP BY regulator_id
  HAVING COUNT(*) > 1
""")

# Check sync logs
{:ok, logs} = EhsEnforcement.Sync.SyncLog.read()
recent_logs = Enum.take(logs, 10)
```

## Monitoring and Troubleshooting

### Real-Time Monitoring

Subscribe to sync events in your LiveView:

```elixir
def mount(_params, _session, socket) do
  # Subscribe to sync events
  NCDB2Phx.subscribe_to_sync_events("sync_progress")
  
  {:ok, assign(socket, progress: 0, status: :idle)}
end

def handle_info({:sync_progress, event}, socket) do
  case event do
    %{event_type: :batch_completed, data: data} ->
      {:noreply, update_progress(socket, data)}
      
    %{event_type: :sync_error, data: error} ->
      {:noreply, show_error(socket, error)}
      
    %{event_type: :sync_completed, data: stats} ->
      {:noreply, show_completion(socket, stats)}
  end
end
```

### Common Issues and Solutions

#### 1. API Rate Limits

**Problem**: Airtable API returns 429 errors

**Solution**:
```elixir
# Increase rate limit delay
config = %{
  source_config: %{
    rate_limit_delay_ms: 500,  # Increase from 200ms
    page_size: 50  # Reduce from 100
  }
}
```

#### 2. Memory Issues

**Problem**: Large imports cause memory spikes

**Solution**:
```elixir
# Reduce batch size and enable streaming
config = %{
  processing_config: %{
    batch_size: 25,  # Reduce from 100
    enable_streaming: true,
    gc_interval: 10  # Force GC every 10 batches
  }
}
```

#### 3. Duplicate Records

**Problem**: Duplicate cases or notices created

**Solution**:
```elixir
# Ensure unique field is properly configured
config = %{
  target_config: %{
    unique_field: :regulator_id,
    update_action: :update,  # Update existing records
    skip_existing: false     # Don't skip, update instead
  }
}

# Clean up existing duplicates
EhsEnforcement.Sync.cleanup_orphaned_offenders()
```

#### 4. Connection Timeouts

**Problem**: Airtable requests timeout

**Solution**:
```elixir
# Increase timeout and add retries
config = %{
  source_config: %{
    timeout_ms: 60_000,  # Increase to 60 seconds
    retry_attempts: 5,
    retry_delay_ms: 2000
  }
}
```

### Error Recovery

The sync engine includes automatic error recovery:

1. **Transient Errors** - Automatically retried with exponential backoff
2. **Validation Errors** - Logged and skipped, sync continues
3. **Fatal Errors** - Sync stopped, session marked as failed

Access error details:

```elixir
# Get failed records from a session
{:ok, session} = NCDB2Phx.get_sync_session("sync_abc123")
{:ok, logs} = NCDB2Phx.Resources.SyncLog.list_session_logs(session.session_id)

error_logs = Enum.filter(logs, &(&1.level == :error))
Enum.each(error_logs, fn log ->
  IO.inspect(log.error_details)
end)
```

### Performance Metrics

Monitor sync performance:

```elixir
{:ok, metrics} = NCDB2Phx.get_sync_metrics("sync_abc123")

IO.puts("Records per second: #{metrics.performance_metrics.records_per_second}")
IO.puts("Error rate: #{metrics.performance_metrics.error_rate}%")
IO.puts("Average batch time: #{metrics.batch_summary.average_batch_time}ms")
```

## Migration from Legacy System

### Phase 1: Parallel Operation

Run both systems in parallel during transition:

```elixir
# Legacy system (current)
EhsEnforcement.Sync.import_cases()

# New system (ncdb_2_phx)
config = build_ncdb_config(:cases)
NCDB2Phx.execute_sync(config)
```

### Phase 2: Switch Primary System

Update your code to use the new system:

```elixir
defmodule EhsEnforcement.Sync do
  # Wrapper functions for compatibility
  
  def import_cases(opts \\ []) do
    config = build_ncdb_config(:cases, opts)
    NCDB2Phx.execute_sync(config, opts)
  end
  
  def import_notices(opts \\ []) do
    config = build_ncdb_config(:notices, opts)
    NCDB2Phx.execute_sync(config, opts)
  end
  
  defp build_ncdb_config(type, opts) do
    %{
      source_adapter: NCDB2Phx.Adapters.AirtableAdapter,
      source_config: airtable_config(),
      target_resource: target_resource(type),
      target_config: target_config(type),
      processing_config: processing_config(opts),
      pubsub_config: pubsub_config(),
      session_config: session_config(type, opts)
    }
  end
end
```

### Phase 3: Remove Legacy Code

After successful migration:

1. Remove duplicate resources
2. Remove custom sync modules
3. Update LiveView components
4. Update documentation

### Benefits of Migration

- ✅ **Reduced code complexity** - Remove ~2000 lines of duplicate code
- ✅ **Better maintainability** - Use battle-tested package
- ✅ **More features** - Get LiveView UI, better error handling
- ✅ **Future-proof** - Easy to add new data sources
- ✅ **Performance improvements** - Optimized streaming and batching

---

## Appendix: Quick Reference

### Import Functions

```elixir
# Cases
EhsEnforcement.Sync.import_cases(limit: 5000, batch_size: 200)

# Notices  
EhsEnforcement.Sync.import_notices(limit: 5000, batch_size: 200)

# Statistics
EhsEnforcement.Sync.get_case_import_stats()
EhsEnforcement.Sync.get_notice_import_stats()

# Cleanup
EhsEnforcement.Sync.cleanup_orphaned_offenders()
```

### Configuration Reference

```elixir
%{
  source_adapter: Module,           # Adapter module
  source_config: %{                 # Adapter-specific config
    api_key: String.t(),
    base_id: String.t(),
    table_id: String.t()
  },
  target_resource: Module,          # Ash resource module
  target_config: %{                 # Target processing config
    unique_field: atom(),
    create_action: atom(),
    update_action: atom()
  },
  processing_config: %{             # Processing options
    batch_size: integer(),
    limit: integer() | nil,
    enable_error_recovery: boolean(),
    enable_progress_tracking: boolean()
  },
  pubsub_config: %{                 # Event broadcasting
    module: Module,
    topic: String.t()
  },
  session_config: %{                # Session metadata
    sync_type: atom(),
    description: String.t()
  }
}
```

### Useful Commands

```bash
# Development
mix phx.server                      # Start dev server
mix test test/sync                  # Run sync tests

# Production
docker-compose logs -f app | grep sync    # Monitor sync logs
docker-compose exec app bin/ehs_enforcement remote  # Production console

# Database
mix ash.rollback --step 1          # Rollback last migration
mix ash.migrate                     # Run pending migrations
```