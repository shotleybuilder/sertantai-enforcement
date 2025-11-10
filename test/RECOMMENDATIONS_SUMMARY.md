# Test Directory Cleanup - Recommendations Summary

**Date**: 2025-11-10
**Status**: READY FOR IMPLEMENTATION

## Quick Summary

### 1. test_helper.exs - ✅ KEEP AS IS (with minor enhancement)

**Current Location**: `/test/test_helper.exs`

**Verdict**: This is correct and follows ExUnit/Phoenix conventions
- Standard location for ExUnit configuration
- Properly configures Ecto SQL Sandbox
- Correctly sets up test environment

**Action**: Add inline comments explaining the `max_cases: 2` setting

---

### 2. test/README.md - 🔄 SPLIT INTO SKILLS

**Current State**: 314 lines mixing reference material with deep tutorial content

**Recommendation**: Split into multiple focused skills in `.claude/skills/`

#### Create 3 New Skills:

1. **`.claude/skills/testing-oauth-auth/SKILL.md`**
   - OAuth2 authentication patterns
   - Creating test users with tokens
   - Common OAuth test issues

2. **`.claude/skills/testing-liveview-elements/SKILL.md`**
   - Element-based vs string-based testing
   - Avoiding HTML truncation
   - Form and button interaction testing

3. **`.claude/skills/testing-liveview-setup/SKILL.md`**
   - Complete test file structure
   - Setup block patterns
   - Testing authenticated/unauthenticated access

#### Reduce README to Quick Reference:
- Common test commands
- Available test helpers
- Links to skills
- Field mapping reference table

**Benefits**:
- Skills are discoverable by Claude Code automatically
- Each skill focused on specific testing pattern
- README becomes fast reference guide
- Easier to maintain and update

---

### 3. Failing Tests - 📋 SYSTEMATIC FIX PLAN

**Current Status**: ~130+ failing tests identified

**Categories**:

| Category | Count | Priority | Issue |
|----------|-------|----------|-------|
| A: Routes | ~35 | HIGH | `/admin/cases/scrape` 404 errors |
| B: Auth | ~25 | HIGH | Missing current_user in socket |
| C: Templates | ~15 | MEDIUM | Field mismatches with resources |
| E: Timing | ~8 | MEDIUM | Race conditions in async tests |
| D: Warnings | ~12 | LOW | Unused variables |

**Fix Strategy**: Address in priority order over 3 weeks

See `/test/TEST_CLEANUP_PLAN.md` for complete breakdown

---

## Detailed Recommendations

### Action 1: Enhance test_helper.exs Documentation

**File**: `test/test_helper.exs`

**Change**:
```elixir
ExUnit.start(
  # Limit concurrent test files to prevent resource exhaustion
  # With 8 CPU cores, default would be 16, but DB-heavy tests need more connections each
  # Set to 2 for Phase 2C verification (from 4)
  # Background: Each test uses multiple DB connections via Ecto Sandbox
  max_cases: 2,

  # ... rest
)
```

---

### Action 2: Create OAuth Authentication Skill

**File**: `.claude/skills/testing-oauth-auth/SKILL.md`

**Content Structure**:
```markdown
# SKILL: OAuth Authentication Testing with Ash

## Purpose
Guide for testing Phoenix LiveView with OAuth2 and AshAuthentication

## When to Use
- Testing admin routes requiring GitHub OAuth
- Creating authenticated test users
- Debugging authentication failures

## Patterns

### Creating OAuth Test User
[Include working pattern from README lines 22-47]

### Common Pitfalls
[Include OAuth-specific issues]

### Troubleshooting
[Include OAuth error debugging]
```

---

### Action 3: Create LiveView Elements Testing Skill

**File**: `.claude/skills/testing-liveview-elements/SKILL.md`

**Content Structure**:
```markdown
# SKILL: LiveView Element-Based Testing

## Purpose
Avoid HTML truncation issues with element-based testing

## When to Use
- Testing LiveView pages > 30k characters
- Testing interactive components
- Verifying dynamic content

## Patterns

### Element-Based vs String-Based
[Include examples from README lines 73-100]

### Form Testing
[Include form patterns]

### Button Interactions
[Include click patterns]
```

---

### Action 4: Create LiveView Setup Skill

**File**: `.claude/skills/testing-liveview-setup/SKILL.md`

**Content Structure**:
```markdown
# SKILL: LiveView Test Setup Patterns

## Purpose
Complete guide to structuring LiveView tests

## When to Use
- Starting new LiveView test file
- Setting up authentication in tests
- Testing multiple permission levels

## Patterns

### Test File Structure
[Include complete example from lines 395-448]

### Setup Blocks
[Include setup patterns]

### Helper Usage
[Include conn_case helper examples]
```

---

### Action 5: Reduce README.md

**File**: `test/README.md`

**New Content** (~60 lines):
```markdown
# Testing Guide for EHS Enforcement

Quick reference for running tests and accessing detailed testing skills.

## Running Tests

[Command reference]

## Test Helpers

[Available helpers from conn_case.ex]

## Testing Skills

Detailed testing patterns available in skills:
- **OAuth Authentication**: `.claude/skills/testing-oauth-auth/`
- **LiveView Elements**: `.claude/skills/testing-liveview-elements/`
- **Test Setup Patterns**: `.claude/skills/testing-liveview-setup/`
- **General Auth Patterns**: `.claude/skills/testing-auth/` (existing)

## Common Field Mappings

[Table from current README]

## Troubleshooting

See individual skills for detailed troubleshooting guides.
```

---

### Action 6: Update Existing Auth Skill

**File**: `.claude/skills/testing-auth/SKILL.md`

**Add Section**:
```markdown
## Related Skills

For specific testing patterns, also see:
- **OAuth Testing**: `.claude/skills/testing-oauth-auth/`
- **Element Testing**: `.claude/skills/testing-liveview-elements/`
- **Setup Patterns**: `.claude/skills/testing-liveview-setup/`
```

---

### Action 7: Create Test Fixture Structure

**New Directory**: `test/support/fixtures/`

**Files to Create**:
```
test/support/fixtures/
├── accounts_fixtures.ex       # User creation helpers
├── enforcement_fixtures.ex    # Case/notice/offender helpers
├── scraping_fixtures.ex      # Scrape session helpers
└── README.md                 # Fixture usage guide
```

**Benefits**:
- Centralized test data creation
- Reusable across test files
- Easier maintenance

---

## Implementation Order

### Week 1: Documentation Cleanup
1. ✅ Create 3 new skills in `.claude/skills/`
2. ✅ Update existing testing-auth skill with cross-references
3. ✅ Reduce test/README.md to quick reference
4. ✅ Add documentation to test_helper.exs
5. ✅ Verify all skills work with Claude Code

**Time Estimate**: 4-6 hours

---

### Week 2-4: Fix Failing Tests
6. 🔧 Fix Category A: Route configuration issues (~35 tests)
7. 🔧 Fix Category B: Authentication setup issues (~25 tests)
8. 🔧 Fix Category C: Template/resource mismatches (~15 tests)
9. 🔧 Fix Category E: Timing/concurrency issues (~8 tests)
10. 🔧 Fix Category D: Unused variable warnings (~12 tests)

**Time Estimate**: 15-20 hours (spread over 3 weeks)

See `/test/TEST_CLEANUP_PLAN.md` for detailed fix strategy

---

### Week 5: Infrastructure Improvements
11. 📦 Create test fixture structure
12. 📝 Enhance test helpers with documentation
13. 🤖 Set up pre-commit test hooks
14. 📊 Create test health monitoring

**Time Estimate**: 6-8 hours

---

## Expected Outcomes

### After Week 1 (Documentation)
- ✅ Skills discoverable by Claude Code
- ✅ Clear separation between reference and tutorial content
- ✅ Easier for developers to find testing patterns
- ✅ README.md < 100 lines

### After Week 4 (Test Fixes)
- ✅ `mix test` passes 100%
- ✅ Zero authentication failures
- ✅ Zero route configuration errors
- ✅ All warnings resolved

### After Week 5 (Infrastructure)
- ✅ Centralized test data creation
- ✅ Automated test validation
- ✅ Test health monitoring
- ✅ Pre-commit test checks

---

## Why Skills Over Documentation?

**Anthropic Skills** (https://support.claude.com/en/articles/12512176-what-are-skills):
- Designed for reusable workflows and patterns
- Discoverable by Claude Code automatically
- Structured format for consistent guidance
- Can include examples and anti-patterns
- Living documents that evolve with codebase

**Benefits for Testing**:
1. **Focused**: Each skill covers one testing pattern
2. **Actionable**: Step-by-step guidance with code examples
3. **Discoverable**: Claude Code can reference them automatically
4. **Maintainable**: Easier to update than long README
5. **Reusable**: Can be adapted for other Phoenix projects

---

## Next Steps

1. **Review** this plan with team
2. **Approve** skill creation approach
3. **Begin** with Week 1 documentation cleanup
4. **Track** progress in `/test/TEST_CLEANUP_PLAN.md`
5. **Document** any discoveries during implementation

---

## Questions to Consider

1. Should we create additional skills for:
   - Database testing patterns?
   - Scraping test strategies?
   - Component testing patterns?

2. Should we set up CI/CD to run tests in categories?

3. Should we add mutation testing for critical paths?

4. Should test fixtures be auto-generated or manually maintained?

---

## Files Affected

### Created
- ✅ `/test/TEST_CLEANUP_PLAN.md` (this file)
- ✅ `/test/RECOMMENDATIONS_SUMMARY.md` (summary)
- 📝 `.claude/skills/testing-oauth-auth/SKILL.md`
- 📝 `.claude/skills/testing-liveview-elements/SKILL.md`
- 📝 `.claude/skills/testing-liveview-setup/SKILL.md`
- 📝 `test/support/fixtures/README.md`

### Modified
- 📝 `/test/README.md` (reduced to ~60 lines)
- 📝 `/test/test_helper.exs` (add comments)
- 📝 `.claude/skills/testing-auth/SKILL.md` (cross-references)
- 🔧 ~95 test files (fixes during Weeks 2-4)

### Reference
- 📖 `.claude/sessions/.current-session` (track progress)
- 📖 `docs-dev/TESTING_GUIDE.md` (broader testing docs)

---

## Conclusion

The `/test` directory is generally well-structured. Main improvements needed:

1. **Keep** test_helper.exs (standard pattern)
2. **Split** README.md into focused skills
3. **Fix** ~130 failing tests systematically
4. **Create** test fixture infrastructure
5. **Document** patterns for future developers

This approach balances immediate cleanup with long-term test maintainability.
