# Test Directory Cleanup and Fixing Plan

**Created**: 2025-11-10
**Status**: PLANNING PHASE

## Overview

This document outlines the systematic plan for tidying up the `/test` directory structure and fixing all failing tests in the EHS Enforcement project.

---

## Phase 1: Directory Structure Cleanup

### 1.1 test_helper.exs Analysis

**Current State**: Located at `/test/test_helper.exs`

**Purpose**:
- Configures ExUnit with proper concurrency settings (max_cases: 2)
- Sets up Ecto SQL Sandbox for test isolation
- Configures mock Airtable client for tests
- Excludes slow/integration tests by default

**Recommendation**: **KEEP** - This is a standard Phoenix/ExUnit pattern
- ✅ `test_helper.exs` at test root is the proper location per ExUnit conventions
- ✅ Configuration is correct for database-heavy testing
- ✅ Sandbox mode ensures test isolation
- ⚠️ Consider documenting the `max_cases: 2` decision in the file itself

**Action**: Add inline documentation explaining concurrency limits

---

### 1.2 test/README.md → Skills Migration

**Current State**: 314-line README with comprehensive auth testing patterns

**Analysis**:
The README contains two distinct types of content:

1. **Skill-Suitable Content** (Lines 1-251): Authentication patterns, debugging, troubleshooting
2. **Reference Content** (Lines 252-314): Quick commands, field mappings, checklist

**Recommendation**: Split into multiple SKILLS.md files

#### Skill 1: OAuth Authentication Testing
**Location**: `.claude/skills/testing-oauth-auth/SKILL.md`
**Content**:
- OAuth2 test authentication pattern (lines 7-48)
- Creating test users with OAuth (lines 244-276)
- Common issues (missing tokens, redirect errors)

#### Skill 2: LiveView Element Testing
**Location**: `.claude/skills/testing-liveview-elements/SKILL.md`
**Content**:
- Element-based vs string-based testing (lines 73-100)
- Form testing patterns (lines 151-164)
- Button click testing (lines 166-179)
- HTML truncation avoidance strategies

#### Skill 3: LiveView Test Setup Patterns
**Location**: `.claude/skills/testing-liveview-setup/SKILL.md`
**Content**:
- Test helper patterns (lines 140-158)
- Manual setup patterns (lines 200-226)
- Unauthenticated access testing (lines 228-237)
- Complete file structure example (lines 395-448)

#### Keep in README.md (Reduced)
**New Content**:
```markdown
# Testing Guide for EHS Enforcement

## Quick Reference

### Running Tests
- `mix test` - Run all tests
- `mix test path/to/test.exs:42` - Run specific test
- `mix test --exclude integration` - Skip integration tests

### Test Helper Functions
Available in `test/support/conn_case.ex`:
- `register_and_log_in_user/1` - Creates regular user with OAuth2
- `register_and_log_in_admin/1` - Creates admin user with OAuth2
- `create_test_user/1` - Creates user without auth (unit tests)
- `create_test_admin/1` - Creates admin without auth (unit tests)

### Skills Available
For detailed testing patterns, see:
- `.claude/skills/testing-oauth-auth/` - OAuth authentication testing
- `.claude/skills/testing-liveview-elements/` - Element-based testing
- `.claude/skills/testing-liveview-setup/` - Test setup patterns
- `.claude/skills/testing-auth/` - General auth patterns (existing)

### Common Field Mappings
| Template Field | Resource Field | Fix |
|---------------|----------------|-----|
| `details.timestamp` | `details.inserted_at` | Use `inserted_at` |
| `details.existing_count` | `details.cases_existing` | Use `cases_existing` |
```

**Actions**:
1. Create three new skills in `.claude/skills/`
2. Migrate appropriate content from README
3. Reduce README to quick reference + links to skills
4. Cross-reference with existing `.claude/skills/testing-auth/SKILL.md`

---

## Phase 2: Test Failure Analysis

### 2.1 Current Test Status

**Test Run Stats** (as of 2025-11-10):
- Total test files: ~100+
- Estimated failures: 130+ tests (based on error count in output)
- Primary failure types:
  1. Route not found errors (404 on `/admin/cases/scrape`)
  2. Authentication/authorization failures
  3. Template field mismatches (KeyError)
  4. Unused variable warnings

### 2.2 Failure Categories

#### Category A: Route Configuration Issues (Priority: HIGH)
**Symptom**: `Phoenix.Router.NoRouteError: no route found for GET /admin/cases/scrape`

**Affected Tests**:
- `test/ehs_enforcement_web/live/admin/case_live/ea_progress_test.exs` (multiple tests)
- `test/ehs_enforcement_web/live/admin/case_live/ea_records_display_test.exs`
- `test/ehs_enforcement_web/live/admin/case_live/ea_stop_scraping_test.exs`

**Root Cause**: Route `/admin/cases/scrape` may have been refactored or renamed

**Fix Strategy**:
1. Check `lib/ehs_enforcement_web/router.ex` for actual admin scraping routes
2. Verify if route was renamed (e.g., to `/admin/scraping`, `/admin/cases/scraping`)
3. Update all test files with correct route
4. Create route alias if needed for backward compatibility

**Estimated Impact**: ~30-40 tests

---

#### Category B: Authentication Setup Issues (Priority: HIGH)
**Symptom**: `KeyError: key :current_user not found in socket.assigns`

**Affected Tests**:
- Dashboard tests with auth failures
- Admin LiveView tests with improper setup

**Root Cause**:
- Using `session: generate_session` with JTI identifiers (incompatible with OAuth)
- Missing `store_in_session` in test setup
- Incorrect test helper usage

**Fix Strategy**:
1. Audit `router.ex` for any `session: {AshAuthentication.Phoenix.LiveSession, :generate_session, []}` with JTI
2. Update test helpers in `test/support/conn_case.ex` to match patterns in existing skill
3. Ensure all tests use `store_in_session` without `assign(:current_user)` for JTI
4. Verify OAuth user creation includes token generation

**Estimated Impact**: ~20-30 tests

---

#### Category C: Template/Resource Field Mismatches (Priority: MEDIUM)
**Symptom**: `KeyError: key :existing_count not found`

**Affected Tests**:
- Processing log display tests
- Scraping session detail tests

**Root Cause**: Template expects fields that don't exist in Ash resource

**Fix Strategy**:
1. Map all template fields to actual Ash resource attributes
2. Update templates OR add computed fields to resources
3. Document field mappings in README
4. Add validation tests for template/resource alignment

**Estimated Impact**: ~10-15 tests

---

#### Category D: Unused Variables (Priority: LOW)
**Symptom**: Compiler warnings about unused variables

**Affected Tests**:
- Multiple tests with `view`, `html`, `metadata`, `result` variables

**Root Cause**: Tests not fully asserting on all captured values

**Fix Strategy**:
1. Prefix unused variables with underscore: `_view`, `_html`
2. Add assertions if variables should be used
3. Remove variable capture if truly unnecessary

**Estimated Impact**: ~8-12 warnings to fix

---

#### Category E: Timing/Concurrency Issues (Priority: MEDIUM)
**Symptom**: Intermittent failures in dashboard refresh tests

**Affected Tests**:
- `test/ehs_enforcement_web/live/dashboard_metrics_test.exs`

**Root Cause**: Race conditions in PubSub message delivery during tests

**Fix Strategy**:
1. Use `assert_receive` with appropriate timeouts
2. Add synchronization points in async operations
3. Consider using `Ecto.Adapters.SQL.Sandbox.allow/3` for async processes
4. Review test isolation between concurrent test cases

**Estimated Impact**: ~5-10 tests

---

## Phase 3: Systematic Fix Implementation

### 3.1 Execution Order

**Week 1: Critical Path**
1. Fix route configuration issues (Category A)
2. Fix authentication setup (Category B)
3. Run full test suite to identify remaining issues

**Week 2: Resolution**
4. Fix template/resource mismatches (Category C)
5. Address timing/concurrency issues (Category E)
6. Clean up unused variable warnings (Category D)

**Week 3: Verification**
7. Run full test suite with all tags included
8. Fix any newly discovered issues
9. Update test documentation

---

### 3.2 Testing Strategy

#### Before Each Fix Session
```bash
# Run tests for specific category to get baseline
mix test test/ehs_enforcement_web/live/admin/ --max-failures 20

# Document current failure count
```

#### During Fix Implementation
```bash
# Run specific test file while fixing
mix test test/path/to/file_test.exs --trace

# Verify fix doesn't break other tests
mix test test/path/to/related_tests/
```

#### After Each Fix Session
```bash
# Run full suite for category
mix test test/ehs_enforcement_web/live/admin/

# Run integration tests
mix test --include integration

# Check for new warnings
mix test 2>&1 | grep "warning:"
```

---

### 3.3 Fix Documentation Template

For each fixed test file, document:

```markdown
## [Test File Name]

**Issue**: [Brief description]
**Category**: [A/B/C/D/E]
**Root Cause**: [Technical explanation]
**Fix Applied**: [What was changed]
**Tests Affected**: [Count]
**Verification**: [How fix was verified]
**Related Files**: [Other files changed]
```

---

## Phase 4: Skill Creation

### 4.1 New Skills to Create

#### Skill: OAuth Authentication Testing
**Path**: `.claude/skills/testing-oauth-auth/SKILL.md`
**Purpose**: Guide for OAuth2 test patterns with AshAuthentication
**Source**: Lines 7-48, 244-276 from test/README.md
**Additional Content**:
- GitHub OAuth token structure
- JWT token generation in tests
- Mock OAuth provider setup
- Token expiration handling

#### Skill: LiveView Element Testing
**Path**: `.claude/skills/testing-liveview-elements/SKILL.md`
**Purpose**: Best practices for element-based LiveView testing
**Source**: Lines 73-100, 151-179 from test/README.md
**Additional Content**:
- CSS selector patterns
- Form submission testing
- Event handling testing
- Async updates with assert_receive

#### Skill: LiveView Test Setup Patterns
**Path**: `.claude/skills/testing-liveview-setup/SKILL.md`
**Purpose**: Complete guide to test setup with authentication
**Source**: Lines 140-158, 200-237, 395-448 from test/README.md
**Additional Content**:
- Multiple user setup patterns
- Testing with different permission levels
- Shared setup blocks
- Test data factories

---

### 4.2 Existing Skill Updates

#### Update: .claude/skills/testing-auth/SKILL.md
**Changes Needed**:
- ✅ Already covers JTI authentication issues
- ✅ Already covers hook execution order
- ⚠️ Add cross-references to new OAuth skill
- ⚠️ Add section on test helper usage from conn_case.ex
- ⚠️ Add troubleshooting section for common test failures

---

## Phase 5: Test Infrastructure Improvements

### 5.1 Test Helper Enhancements

**File**: `test/support/conn_case.ex`

**Improvements Needed**:
1. Add documentation for each helper function
2. Add variants for different auth scenarios:
   - `register_and_log_in_user_with_token/2` - Custom OAuth token
   - `register_and_log_in_readonly_user/1` - Read-only permissions
   - `register_and_log_in_superadmin/1` - Full admin access
3. Add helper for creating test agencies/cases/offenders
4. Add helper for cleaning up test data

---

### 5.2 Test Fixtures

**Create**: `test/support/fixtures/`

**Structure**:
```
test/support/fixtures/
├── accounts_fixtures.ex          # User creation helpers
├── enforcement_fixtures.ex       # Case/notice/offender helpers
├── scraping_fixtures.ex         # Scrape session helpers
└── integration_fixtures.ex      # Cross-domain test data
```

**Purpose**: Centralize test data creation patterns

---

### 5.3 Test Configuration

**File**: `test/test_helper.exs`

**Enhancement**: Add comment explaining concurrency

```elixir
ExUnit.start(
  # Limit concurrent test files to prevent resource exhaustion
  # With 8 CPU cores, default would be 16, but DB-heavy tests need more connections each
  # Set to 2 for Phase 2C verification to ensure test isolation
  # Background: Each test case uses multiple DB connections (main + Sandbox.allow for async)
  # Increase to 4 once Phase 2C auth issues are resolved
  max_cases: 2,

  # ... rest of config
)
```

---

## Phase 6: Continuous Testing Strategy

### 6.1 Pre-Commit Checks

**Create**: `.git/hooks/pre-commit` (or update existing)

```bash
#!/bin/bash
# Run fast tests before commit
mix test --exclude slow --exclude integration --max-failures 5

if [ $? -ne 0 ]; then
  echo "❌ Tests failed. Fix before committing."
  exit 1
fi
```

---

### 6.2 CI/CD Integration

**Recommended**: GitHub Actions workflow

```yaml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        test-category:
          - unit
          - integration
          - web
    steps:
      - uses: actions/checkout@v2
      - name: Run ${{ matrix.test-category }} tests
        run: mix test test/category/${{ matrix.test-category }}/
```

---

### 6.3 Test Monitoring

**Create**: `scripts/test_health_check.exs`

```elixir
# Script to track test health over time
# - Count passing/failing tests by category
# - Track test execution time
# - Identify flaky tests (pass/fail inconsistently)
# - Generate test coverage reports
```

---

## Implementation Checklist

### Phase 1: Cleanup ✓
- [ ] Document test_helper.exs rationale (inline comments)
- [ ] Create `.claude/skills/testing-oauth-auth/SKILL.md`
- [ ] Create `.claude/skills/testing-liveview-elements/SKILL.md`
- [ ] Create `.claude/skills/testing-liveview-setup/SKILL.md`
- [ ] Update `.claude/skills/testing-auth/SKILL.md` with cross-refs
- [ ] Reduce test/README.md to quick reference
- [ ] Verify all skills are discoverable

### Phase 2: Analysis ✓
- [ ] Run full test suite, capture all failures
- [ ] Categorize each failing test (A/B/C/D/E)
- [ ] Create tracking document for each category
- [ ] Identify dependencies between fixes

### Phase 3: Fix Implementation
- [ ] Week 1: Fix Category A (Route issues)
- [ ] Week 1: Fix Category B (Auth issues)
- [ ] Week 2: Fix Category C (Template issues)
- [ ] Week 2: Fix Category E (Timing issues)
- [ ] Week 2: Fix Category D (Warnings)
- [ ] Week 3: Verification and documentation

### Phase 4: Infrastructure
- [ ] Create test fixtures structure
- [ ] Enhance test helpers in conn_case.ex
- [ ] Add test helper documentation
- [ ] Create test health check script

### Phase 5: Documentation
- [ ] Update TESTING_GUIDE.md with new patterns
- [ ] Add test failure troubleshooting guide
- [ ] Document all new skills
- [ ] Create test writing checklist

### Phase 6: Automation
- [ ] Set up pre-commit hooks
- [ ] Configure CI/CD for test categories
- [ ] Add test monitoring dashboard
- [ ] Schedule weekly test health reports

---

## Success Criteria

### Phase 1 Complete When:
- ✓ All skills created and documented
- ✓ README.md reduced to < 100 lines
- ✓ Skills cross-referenced in CLAUDE.md
- ✓ test_helper.exs properly documented

### Phase 3 Complete When:
- ✓ Zero failing tests in Category A
- ✓ Zero failing tests in Category B
- ✓ < 5 failing tests in Category C
- ✓ < 3 intermittent failures in Category E
- ✓ Zero unused variable warnings

### Final Success When:
- ✓ `mix test` passes 100% (excluding intentionally skipped)
- ✓ `mix test --include slow --include integration` passes 100%
- ✓ All tests have proper documentation
- ✓ Test execution time < 5 minutes for fast suite
- ✓ Test coverage > 80% overall
- ✓ All new features have tests
- ✓ CI/CD pipeline green

---

## Notes and Discoveries

### 2025-11-10: Initial Analysis
- Found ~130+ failing tests across multiple categories
- Primary issue: Route configuration for EA scraping UI
- Secondary issue: Auth setup patterns with JTI
- Many tests written before Phase 2C auth refactoring

### Future Considerations
- Consider migrating to Wallaby for browser-based tests
- Evaluate test performance optimization opportunities
- Assess value of mutation testing (e.g., with `mix_test_interactive`)
- Plan for load testing scraping operations

---

## References

- **Current Session**: `.claude/sessions/.current-session`
- **Auth Testing Skill**: `.claude/skills/testing-auth/SKILL.md`
- **Testing Guide**: `docs-dev/TESTING_GUIDE.md`
- **Test Helpers**: `test/support/conn_case.ex`
- **ExUnit Docs**: https://hexdocs.pm/ex_unit/
- **Phoenix LiveView Testing**: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html
