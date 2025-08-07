# Sync System Migration Plan: Legacy to ncdb_2_phx

## Executive Summary

This document outlines the migration plan for transitioning the EHS Enforcement sync system from the custom-built solution to the generic `ncdb_2_phx` package. The migration will reduce code complexity by ~70%, improve maintainability, and add new features like enhanced error recovery and LiveView UI components.

## Current State Analysis

### Legacy System Components

1. **Core Sync Module** (`lib/ehs_enforcement/sync/sync.ex`)
   - 584 lines of custom sync logic
   - Tightly coupled to Airtable and enforcement domain
   - Custom session management and progress tracking

2. **Supporting Modules** (to be replaced/removed)
   - `SessionManager` - Custom session lifecycle management
   - `EventBroadcaster` - Custom PubSub wrapper
   - `ProgressStreamer` - Real-time progress updates
   - `RetryEngine` - Custom retry logic
   - `ErrorClassifier` - Error categorization
   - `IntegrityVerifier` - Data validation
   - `ProgressSupervisor` - OTP supervision

3. **Resources** (duplicate of package resources)
   - `SyncSession` - Session tracking
   - `SyncProgress` - Batch progress
   - `SyncLog` - Event logging

4. **Domain-Specific** (to be kept)
   - `RecordProcessor` - Airtable → Enforcement transformation
   - `OffenderMatcher` - Deduplication logic
   - `AirtableAdapter` - Already compatible with ncdb_2_phx!

### Package Components (ncdb_2_phx)

1. **Generic Engine**
   - Pluggable adapter pattern
   - Configuration-driven behavior
   - Zero host coupling

2. **Built-in Features**
   - Session management
   - Progress tracking
   - Error recovery
   - LiveView components
   - Event broadcasting
   - Comprehensive logging

3. **Complete Admin Interface** (Available in v2.0+)
   - **Router Integration**: Single-macro setup with `ncdb_sync_routes`
   - **Dashboard**: Real-time metrics and system overview
   - **Session Management**: Full CRUD operations for sync sessions
   - **Live Monitoring**: Real-time progress tracking with PubSub
   - **Batch Management**: Detailed batch-level analysis and tracking
   - **Log Management**: Comprehensive log viewing with advanced filtering
   - **Configuration Interface**: Multi-tab configuration management
   - **API Endpoints**: RESTful APIs with proper error handling
   - **Authentication Ready**: Integrates with host app auth pipelines
   - **Mobile Responsive**: Modern, responsive UI components

## Migration Strategy

### Phase 1: Preparation (Week 1)

1. **Create Compatibility Layer**
   ```elixir
   defmodule EhsEnforcement.Sync.Compat do
     # Wrapper functions to maintain API compatibility
     def import_cases(opts), do: # Use ncdb_2_phx
     def import_notices(opts), do: # Use ncdb_2_phx
   end
   ```

2. **Update Domain Configuration**
   ```elixir
   defmodule EhsEnforcement.Sync do
     use Ash.Domain
     
     resources do
       # Use package resources
       resource NCDB2Phx.Resources.SyncSession
       resource NCDB2Phx.Resources.SyncBatch
       resource NCDB2Phx.Resources.SyncLog
     end
   end
   ```

3. **Test Parallel Operation**
   - Run both systems side-by-side
   - Compare results and performance
   - Identify any gaps

### Phase 2: Migration (Week 2)

1. **Update Import Functions**
   ```elixir
   def import_cases(opts \\ []) do
     config = build_sync_config(:cases, opts)
     NCDB2Phx.execute_sync(config, opts)
   end
   ```

2. **Migrate LiveView Components**
   - Replace custom components with package components
   - Update event handling for new event format
   - Test real-time updates

3. **Update Admin Routes**
   ```elixir
   import NCDB2Phx.Router
   
   scope "/admin", EhsEnforcementWeb.Admin do
     pipe_through [:browser, :admin_required]
     ncdb_sync_routes "/sync"
   end
   ```

### Phase 3: Cleanup (Week 3)

1. **Remove Duplicate Modules**
   - Delete custom session/progress/log resources
   - Remove utility modules (EventBroadcaster, etc.)
   - Clean up unused dependencies

2. **Update Tests**
   - Migrate tests to use package APIs
   - Remove tests for deleted modules
   - Add integration tests

3. **Documentation Updates**
   - Update deployment guide
   - Update admin guides
   - Update API documentation

### Phase 4: Router Integration (Week 4)

1. **Replace Custom Admin Interface**
   - Remove custom sync LiveView components
   - Replace with ncdb_2_phx router integration
   - Migrate to package-provided admin interface

2. **Update Router Configuration**
   ```elixir
   # lib/ehs_enforcement_web/router.ex
   import NCDB2Phx.Router
   
   scope "/admin", EhsEnforcementWeb.Admin do
     pipe_through [:browser, :admin_required]
     ncdb_sync_routes "/sync"
   end
   ```

3. **Configure Package Components**
   - Set up authentication integration
   - Configure custom layouts (optional)
   - Configure session arguments and route options
   - Test real-time monitoring and dashboard

4. **Remove Custom Sync LiveViews**
   - Delete `lib/ehs_enforcement_web/live/admin/sync_live/`
   - Remove custom sync components
   - Update navigation to use package routes

5. **Verify Complete Admin Interface**
   - Dashboard with real-time metrics
   - Session management (CRUD operations)
   - Live monitoring with PubSub updates
   - Batch tracking and analysis
   - Comprehensive log viewing with filtering
   - Configuration management interface

## Migration Checklist

### Pre-Migration
- [ ] Backup production database
- [ ] Document current sync statistics
- [ ] Review custom business logic
- [ ] Test ncdb_2_phx in development
- [ ] Create rollback plan

### During Migration
- [ ] Deploy compatibility layer
- [ ] Run parallel tests
- [ ] Migrate one sync type at a time
- [ ] Monitor error rates
- [ ] Verify data integrity

### Post-Migration
- [ ] Remove legacy code
- [ ] Update documentation
- [ ] Performance benchmarking
- [ ] Team training on new system
- [ ] Monitor for regressions

## Code Changes Required

### 1. Domain Configuration

```elixir
# Before
defmodule EhsEnforcement.Sync do
  use Ash.Domain
  
  resources do
    resource EhsEnforcement.Sync.SyncLog
    resource EhsEnforcement.Sync.SyncSession
    resource EhsEnforcement.Sync.SyncProgress
  end
end

# After
defmodule EhsEnforcement.Sync do
  use Ash.Domain
  
  resources do
    resource NCDB2Phx.Resources.SyncSession
    resource NCDB2Phx.Resources.SyncBatch
    resource NCDB2Phx.Resources.SyncLog
  end
end
```

### 2. Import Functions

```elixir
# Before
def import_cases(opts \\ []) do
  # 300+ lines of custom logic
end

# After
def import_cases(opts \\ []) do
  config = %{
    source_adapter: NCDB2Phx.Adapters.AirtableAdapter,
    source_config: airtable_config(),
    target_resource: EhsEnforcement.Enforcement.Case,
    target_config: %{
      unique_field: :regulator_id,
      transform_fn: &RecordProcessor.process_case_record/1
    },
    processing_config: build_processing_config(opts),
    pubsub_config: pubsub_config(),
    session_config: %{sync_type: :import_cases}
  }
  
  NCDB2Phx.execute_sync(config, opts)
end
```

### 3. LiveView Updates

```elixir
# Before
def handle_info({:sync_progress, data}, socket) do
  # Custom event handling
end

# After  
def handle_info({:sync_progress, %{event_type: type, data: data}}, socket) do
  # Standard ncdb_2_phx event format
end
```

### 4. Router Integration (Phase 4)

```elixir
# Before - Custom sync routes and LiveViews
scope "/admin", EhsEnforcementWeb.Admin do
  pipe_through [:browser, :admin_required]
  
  live "/sync", SyncLive.Index, :index
  live "/sync/sessions/:id", SyncLive.Show, :show
  # Multiple custom routes...
end

# After - Single macro provides complete admin interface
import NCDB2Phx.Router

scope "/admin", EhsEnforcementWeb.Admin do
  pipe_through [:browser, :admin_required]
  
  ncdb_sync_routes "/sync", [
    layout: {EhsEnforcementWeb.Layouts, :admin},
    session_args: %{current_user: :current_user}
  ]
end
```

### 5. Admin Interface Features Available

With the router integration, the following features become available:

- **Dashboard**: `/admin/sync` - Real-time sync system overview
- **Sessions**: `/admin/sync/sessions` - Session management and history
- **Monitoring**: `/admin/sync/monitor` - Live progress tracking
- **Batches**: `/admin/sync/batches` - Batch-level analysis
- **Logs**: `/admin/sync/logs` - Comprehensive log viewing
- **Config**: `/admin/sync/config` - System configuration
- **API**: `/admin/sync/api/sessions` - RESTful endpoints

## Risk Mitigation

### Identified Risks

1. **Data Loss Risk**
   - Mitigation: Full database backup before migration
   - Rollback: Restore from backup

2. **API Compatibility**
   - Mitigation: Compatibility layer maintains existing API
   - Rollback: Keep legacy code in separate branch

3. **Performance Regression**
   - Mitigation: Benchmark before/after migration
   - Rollback: Revert to legacy system

4. **Missing Features**
   - Mitigation: Thorough testing of all use cases
   - Rollback: Implement missing features in package

### Rollback Plan

1. Keep legacy code in `legacy-sync` branch
2. Database migrations are additive only
3. Feature flag to switch between systems
4. Monitor error rates and performance
5. One-command rollback script ready

## Success Metrics

### Technical Metrics
- [ ] Code reduction: >60% fewer lines
- [ ] Test coverage: >90%
- [ ] Performance: Equal or better
- [ ] Error rate: <0.1%
- [ ] Admin interface: Complete package integration
- [ ] Custom LiveView removal: 100% replaced with package components

### Business Metrics
- [ ] Import success rate: >99%
- [ ] Processing speed: >100 records/second
- [ ] User satisfaction: Positive feedback
- [ ] System stability: No regressions
- [ ] Admin usability: Improved with real-time monitoring
- [ ] Maintenance efficiency: Reduced by standardized interface

## Timeline

### Week 1: Preparation
- Days 1-2: Create compatibility layer
- Days 3-4: Update domain configuration
- Day 5: Test parallel operation

### Week 2: Migration
- Days 1-2: Migrate import functions
- Days 3-4: Update LiveView components
- Day 5: Deploy to staging

### Week 3: Cleanup
- Days 1-2: Remove legacy code
- Days 3-4: Update documentation
- Day 5: Production deployment

### Week 4: Router Integration
- Days 1-2: Configure ncdb_2_phx router and admin interface
- Days 3: Remove custom sync LiveViews and components
- Days 4: Test complete admin interface functionality
- Day 5: Final deployment and user training

## Team Responsibilities

### Development Team
- Implement compatibility layer
- Migrate core functionality
- Update tests
- Remove legacy code

### QA Team
- Test data integrity
- Verify feature parity
- Performance testing
- User acceptance testing

### Operations Team
- Database backups
- Deployment coordination
- Monitoring setup
- Rollback preparation

## Conclusion

The migration to ncdb_2_phx will significantly improve the maintainability and features of the sync system while reducing technical debt. The phased approach minimizes risk and allows for gradual validation of the new system.

**Phase 4 Enhancement**: With the addition of the comprehensive router integration, the migration now provides a complete, plug-and-play admin interface that eliminates the need for custom sync LiveViews entirely. This delivers a professional-grade admin experience with real-time monitoring, comprehensive session management, and advanced configuration capabilities - all with a single macro integration.

The four-phase migration ensures:
1. **Compatibility** (Phase 1) - Safe transition without breaking existing functionality
2. **Integration** (Phase 2) - Core engine migration with NCDB2Phx
3. **Cleanup** (Phase 3) - Legacy code removal and architecture simplification  
4. **Enhancement** (Phase 4) - Complete admin interface with advanced features

## Appendix: File Deletion List

### Modules to Delete
```
lib/ehs_enforcement/sync/
├── session_manager.ex          # Replaced by package
├── event_broadcaster.ex        # Replaced by package
├── progress_streamer.ex        # Replaced by package
├── progress_supervisor.ex      # Replaced by package
├── retry_engine.ex            # Replaced by package
├── error_classifier.ex        # Replaced by package
├── error_recovery.ex          # Replaced by package
├── integrity_verifier.ex      # Replaced by package
├── integrity_reporter.ex      # Replaced by package
├── enhanced_sync.ex           # Replaced by package
├── generic.ex                 # Replaced by package
└── resources/
    ├── sync_session.ex        # Use package resource
    ├── sync_progress.ex       # Use package resource
    └── sync_log.ex           # Use package resource
```

### Modules to Keep
```
lib/ehs_enforcement/sync/
├── sync.ex                    # Refactor to wrapper
├── record_processor.ex        # Domain-specific
├── offender_matcher.ex        # Domain-specific
├── airtable_importer.ex       # May need minor updates
└── adapters/
    └── airtable_adapter.ex    # Already compatible!
```