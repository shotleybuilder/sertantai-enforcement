# Ash Framework Divergence Analysis

**Date**: 2025-08-02  
**Status**: Major Framework Alignment Completed in Phase 9  
**Current Phase**: LiveView Integration and PubSub Implementation

## Executive Summary

The EHS Enforcement project was initially built using legacy Phoenix/Ecto patterns instead of leveraging the full Ash Framework capabilities. Phase 9 identified critical framework divergence issues that were causing cascading problems, including UI update failures and inefficient data operations.

**Root Cause**: The project was "fighting against the framework" instead of leveraging Ash's declarative patterns, code interfaces, and automatic optimizations.

## 🚨 Critical Finding: PubSub Failure Root Cause

**The failing PubSub issues reported in previous sessions were directly caused by using manual `Phoenix.PubSub` patterns instead of Ash's declarative pub_sub configuration.**

**Symptom**: Events were being broadcast but UI wasn't updating consistently
**Root Cause**: Manual broadcasts scattered across LiveViews instead of automatic resource-level events
**Solution**: Implement Ash pub_sub blocks in resources for automatic, policy-aware event publishing

This explains why Phase 9's "PubSub Progress UI update issue" required extensive debugging - the fundamental approach was anti-pattern from the start.

## Major Divergence Areas Identified

### 1. ❌ Manual Domain Functions vs Code Interfaces (FIXED)

**Problem**: 50+ manual functions bypassing Ash's optimizations and patterns
**Impact**: No automatic form handling, missing optimizations, inconsistent error patterns

**Before** (Anti-pattern):
```elixir
def create_case(attrs) do
  case_changeset = Case.changeset(%Case{}, attrs)
  Repo.insert(case_changeset)
end

def list_cases(opts \\ []) do
  query = from(c in Case, join: o in Offender, on: c.offender_id == o.id)
  Repo.all(query)
end
```

**After** (Ash Pattern):
```elixir
# In domain resources block:
resource EhsEnforcement.Enforcement.Case do
  define :create_case, action: :create
  define :list_cases, action: :read
  define :update_case, action: :update
  define :sync_case, action: :sync  # For Airtable integration
end
```

**Benefits Gained**:
- Automatic form generation and validation
- Built-in error handling
- Performance optimizations
- Policy enforcement
- Consistent API patterns

### 2. ❌ Missing AshPhoenix Integration (FIXED)

**Problem**: LiveViews using manual changeset handling instead of AshPhoenix.Form
**Impact**: No automatic subscriptions, manual form validation, missing real-time updates

**Before** (Anti-pattern):
```elixir
# Manual changeset handling
changeset = Case.changeset(case, params)
form = to_form(changeset)

# Manual save logic
case Repo.insert(changeset) do
  {:ok, case} -> # manual success handling
  {:error, changeset} -> # manual error handling
end
```

**After** (Ash Pattern):
```elixir
# AshPhoenix.Form integration
form = AshPhoenix.Form.for_create(Case, :create, forms: [auto?: false])
form = AshPhoenix.Form.validate(form, params)

case AshPhoenix.Form.submit(form, params: params) do
  {:ok, case} -> # automatic success handling
  {:error, form} -> # rich error handling with field-level errors
end
```

**Benefits Gained**:
- Automatic LiveView subscriptions
- Rich form validation with field-level errors
- Consistent form handling patterns
- Integration with Ash policies and validations

### 3. ❌ Inconsistent Action Mapping (FIXED)

**Problem**: Code interfaces referenced non-existent actions
**Impact**: Compilation errors, undefined function calls

**Examples Fixed**:
- Case resource had no `:update` action (only `:sync` for Airtable)
- Function calls to `update_case/2` when only `sync_case/2` existed
- Missing `count_cases!/1` function for pagination

**Solution**:
- Added `:update` to Case resource defaults: `defaults([:read, :update, :destroy])`
- Preserved `:sync` action for Airtable integration
- Added comprehensive `count_cases!/1` with filtering support

### 4. ❌ Web Layer Framework Misalignment (FIXED)

**Problem**: LiveView macro missing AshPhoenix imports
**Impact**: No access to automatic subscriptions, form helpers, resource utilities

**Before**:
```elixir
defmacro live_view(_opts \\ []) do
  quote do
    use Phoenix.LiveView
    use EhsEnforcementWeb, :verified_routes
    # Missing AshPhoenix integration
  end
end
```

**After**:
```elixir
defmacro live_view(_opts \\ []) do
  quote do
    use Phoenix.LiveView
    use EhsEnforcementWeb, :verified_routes
    import AshPhoenix.LiveView     # Automatic subscriptions
    alias AshPhoenix.Form          # Form handling
  end
end
```

### 5. ❌ Anti-Pattern: Manual PubSub vs Ash Declarative PubSub (CRITICAL)

**Problem**: Using manual `Phoenix.PubSub.broadcast()` calls instead of Ash's declarative pub_sub patterns
**Impact**: 
- Manual event management prone to errors and inconsistencies
- Missing automatic subscriptions and optimizations
- **Root cause of failing PubSub** - events fired but UI not updating consistently
- No integration with Ash policies and validations
- Topic naming inconsistencies across the application

**Current Anti-Pattern** (Manual broadcasts scattered across LiveViews):
```elixir
# In CaseLive.Form - Manual broadcasts in multiple places
Phoenix.PubSub.broadcast(EhsEnforcement.PubSub, "case_updates", {:case_created, case_record})
Phoenix.PubSub.broadcast(EhsEnforcement.PubSub, "case:#{case_record.id}", {:case_updated, case_record})

# In LiveViews - Manual subscriptions
Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case_updates")
Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case:#{id}")
```

**Problems with Current Approach**:
1. **Scattered Logic**: Broadcasts in LiveViews instead of resource actions
2. **Inconsistent Topics**: Mixed naming patterns (`case_updates` vs `case:#{id}`)
3. **Missing Events**: Not all CRUD operations trigger broadcasts
4. **No Policy Integration**: Broadcasts bypass Ash authorization
5. **Manual Subscription Management**: Each LiveView manually manages subscriptions

**Ash Pattern** (Declarative resource-level configuration):
```elixir
# In Case resource:
pub_sub do
  module EhsEnforcement.PubSub
  prefix "enforcement"
  
  # Automatic broadcasts for all operations
  publish_all [:create, :update, :destroy]
  
  # Specific case updates with dynamic topics
  publish :update, ["case", :id]
  publish :sync, ["case", :id, "synced"]  # Airtable sync events
  
  # Global case events
  publish :create, ["cases", "created"]
  publish :destroy, ["cases", "deleted"]
end

# In LiveViews with AshPhoenix.LiveView:
# Automatic subscriptions - no manual Phoenix.PubSub calls needed!
```

**Benefits of Ash PubSub Pattern**:
- **Automatic Event Publishing**: All resource operations automatically trigger events
- **Policy-Aware**: Only publishes events for authorized operations
- **Consistent Topic Naming**: Template-based topic generation
- **AshPhoenix Integration**: Automatic subscriptions in LiveViews
- **Debugging Support**: Built-in debug mode for troubleshooting
- **Performance**: Optimized event filtering and delivery

### 6. ⚠️ LiveView Direct Ash Calls (IN PROGRESS)

**Problem**: LiveViews making direct `Ash.read()` calls instead of using code interfaces
**Impact**: Bypassing domain boundaries, inconsistent error handling

**Examples to Fix**:
```elixir
# Current (Direct Ash calls):
cases = Ash.read!(Case, load: [:offender, :agency])

# Target (Code interface):
cases = Enforcement.list_cases!(load: [:offender, :agency])
```

## Prioritized Remediation Plan

### ✅ Phase 1: Foundation (COMPLETED)
1. **Domain Code Interfaces** - Replace manual functions with generated code interfaces
2. **AshPhoenix Extension** - Add AshPhoenix to domain for form and LiveView integration  
3. **Web Macro Enhancement** - Import AshPhoenix utilities in LiveView macro
4. **Action Mapping** - Ensure all referenced actions exist in resources

### 🔄 Phase 2: LiveView Integration (IN PROGRESS)
1. **Form Migration** - Convert all forms to use AshPhoenix.Form patterns
2. **Function Reference Updates** - Replace direct Ash calls with code interfaces
3. **Error Handling** - Standardize error patterns using Ash error types
4. **Compilation Testing** - Ensure all function references are valid

### ⏳ Phase 3: Real-time Features (HIGH PRIORITY - ROOT CAUSE OF UI ISSUES)
1. **Ash PubSub Configuration** - Add pub_sub blocks to Case, Offender, Notice resources
2. **Remove Manual Broadcasts** - Delete all `Phoenix.PubSub.broadcast()` calls from LiveViews  
3. **Remove Manual Subscriptions** - Delete all `Phoenix.PubSub.subscribe()` calls from LiveViews
4. **AshPhoenix Automatic Subscriptions** - Leverage automatic resource subscriptions
5. **Debug Configuration** - Enable `config :ash, :pub_sub, debug?: true` for troubleshooting
6. **Topic Standardization** - Use Ash template patterns for consistent naming

### ⏳ Phase 4: Optimization (PENDING)
1. **Performance Testing** - Measure improvements from framework alignment
2. **Policy Integration** - Ensure all operations respect Ash policies
3. **Caching Strategy** - Leverage Ash caching capabilities
4. **Production Validation** - Test all functionality with new patterns

## Configuration Changes Applied

### Domain Configuration
```elixir
# EhsEnforcement.Enforcement domain
use Ash.Domain, extensions: [AshPhoenix]

resources do
  resource EhsEnforcement.Enforcement.Case do
    define :list_cases, action: :read
    define :get_case, action: :read, get_by: [:id]
    define :create_case, action: :create
    define :update_case, action: :update      # Added for UI editing
    define :sync_case, action: :sync          # Preserved for Airtable
    define :destroy_case, action: :destroy
    define :count_cases!, # Custom function for pagination
  end
  # ... other resources
end

forms do
  form :create_case, args: []
  form :sync_case, args: []    # Airtable sync form
  # ... other forms
end
```

### Resource Updates
```elixir
# Case resource actions
actions do
  defaults([:read, :update, :destroy])  # Added :update
  
  create :create do
    # Complex creation logic with offender/agency resolution
  end
  
  update :sync do
    # Limited fields for Airtable synchronization
    accept([:offence_result, :offence_fine, :offence_costs, :offence_hearing_date])
    change(set_attribute(:last_synced_at, &DateTime.utc_now/0))
  end
end
```

### Web Layer Integration
```elixir
# EhsEnforcementWeb live_view macro
defmacro live_view(_opts \\ []) do
  quote do
    use Phoenix.LiveView
    use EhsEnforcementWeb, :verified_routes
    import AshPhoenix.LiveView     # Automatic subscriptions
    alias AshPhoenix.Form          # Form handling utilities
    # ... other imports
  end
end
```

## Key Insights and Lessons Learned

### 1. Framework Compliance is Critical
Working against the framework causes cascading issues. The UI update problems were ultimately caused by not leveraging Ash's declarative patterns.

### 2. Code Interfaces Provide More Than Convenience
Generated functions enable automatic form handling, optimizations, and feature integrations that manual functions miss.

### 3. Action Mapping Must Match Business Logic
Resources define their own action patterns based on business needs (e.g., `:sync` vs `:update` for Cases), not just standard CRUD.

### 4. Incremental Migration Strategy
Large framework changes require careful incremental migration with frequent compilation testing.

### 5. Documentation Verification
Always verify that referenced actions and functions actually exist before implementing.

## Remaining Work

### Immediate (Phase 10)
- [ ] Complete LiveView migration to use code interfaces
- [ ] Fix any remaining function reference issues
- [ ] Test form handling with AshPhoenix.Form patterns

### Near-term
- [ ] Implement Ash PubSub for automatic resource updates
- [ ] Remove manual Phoenix.PubSub broadcasts
- [ ] Add resource pub_sub configurations

### Long-term  
- [ ] Performance benchmarking of framework alignment benefits
- [ ] Full integration testing of CRUD operations
- [ ] Policy integration verification
- [ ] Production deployment validation

## Benefits Expected

### Performance
- Ash query optimizations and caching
- Reduced manual data fetching logic
- Automatic relationship loading optimization

### Developer Experience
- Consistent API patterns via code interfaces
- Automatic form generation and validation
- Rich error handling with field-level feedback
- Declarative resource definitions

### Maintainability
- Framework compliance reduces maintenance burden
- Automatic feature integration (subscriptions, forms, policies)
- Cleaner separation of concerns
- Better testing patterns

### User Experience
- Real-time UI updates via Ash PubSub
- Better form validation feedback
- Consistent loading and error states
- Improved application responsiveness

## Conclusion

The framework alignment effort has established a solid foundation for proper Ash Framework usage. The major structural issues have been resolved, and the remaining work focuses on completing the LiveView migration and implementing automatic real-time features.

**Status**: ✅ Foundation Complete | 🔄 Integration In Progress | ⏳ Optimization Pending

The project is now positioned to leverage the full power of the Ash Framework while maintaining backward compatibility with existing Airtable synchronization requirements.