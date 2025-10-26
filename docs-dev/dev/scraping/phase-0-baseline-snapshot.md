# Phase 0 Baseline Snapshot - Strategy Pattern Refactor

**Date**: 2025-10-26
**Branch**: `refactor/strategy-pattern-scraping`
**Commit**: Initial state before refactor

## Current State Documentation

### LiveView Files (To Be Replaced)

**Case Scraping LiveView**:
- File: `lib/ehs_enforcement_web/live/admin/case_live/scrape.ex`
- Lines: 1,278
- Purpose: HSE and EA case scraping interface
- Issues: Duplicate logic with Notice LiveView, complex PubSub handling

**Notice Scraping LiveView**:
- File: `lib/ehs_enforcement_web/live/admin/notice_live/scrape.ex`
- Lines: 1,111
- Issues: EA Notice progress tracking stuck at 0%, PubSub integration problems

**Total LiveView Code**: 2,389 lines

### Supporting Components

**Progress Component** (Existing):
- File: `lib/ehs_enforcement_web/components/progress_component.ex`
- Lines: 288
- Status: Already unified for both agencies
- Created: Previous refactor session (git commit 91394c0)

### Test Files

**Existing Test Coverage**:
- Total test files: 21 files
- Locations:
  - `test/ehs_enforcement/scraping/` - Scraper and processor tests
  - `test/ehs_enforcement_web/live/admin/` - LiveView tests

### Scraping Implementation Files

**HSE Scraping**:
- `lib/ehs_enforcement/scraping/hse/case_scraper.ex` (556 lines)
- `lib/ehs_enforcement/scraping/hse/case_processor.ex` (466 lines)
- `lib/ehs_enforcement/scraping/hse/notice_scraper.ex` (221 lines)
- `lib/ehs_enforcement/scraping/hse/notice_processor.ex` (322 lines)

**EA Scraping**:
- `lib/ehs_enforcement/scraping/ea/case_scraper.ex` (603 lines)
- `lib/ehs_enforcement/scraping/ea/case_processor.ex` (695 lines)
- `lib/ehs_enforcement/scraping/ea/notice_scraper.ex` (231 lines)
- `lib/ehs_enforcement/scraping/ea/notice_processor.ex` (708 lines)

**Shared Utilities** (From Phase 1-3 refactor):
- `lib/ehs_enforcement/scraping/shared/business_type_detector.ex` (89 lines)
- `lib/ehs_enforcement/scraping/shared/monetary_parser.ex` (47 lines)
- `lib/ehs_enforcement/scraping/shared/environmental_helpers.ex` (124 lines)
- `lib/ehs_enforcement/scraping/shared/date_parser.ex` (201 lines)

**Agency Helpers**:
- `lib/ehs_enforcement/agencies/hse/offender_builder.ex` (162 lines)
- `lib/ehs_enforcement/agencies/ea/offender_builder.ex` (182 lines)

### Known Issues

1. **EA Notice Progress Tracking Bug**
   - Symptom: Progress stuck at 0% despite processing
   - Root Cause: PubSub event subscription conflict
   - Impact: User can't monitor EA notice scraping progress

2. **LiveView Duplication**
   - ~60-70% code duplication between Case and Notice LiveViews
   - Complex event handling with `keep_live` vs manual PubSub subscriptions
   - Difficult to debug and maintain

### Performance Baseline

**Test Results** (before refactor):
```bash
mix test test/ehs_enforcement/scraping/
```
- Total tests: 89
- Failures: 30-31 (pre-existing, unrelated to refactor)
- Duration: ~195 seconds

### Git Information

**Current Branch**: `main` (before checkout)
**Feature Branch**: `refactor/strategy-pattern-scraping` (created)
**Last Commit**: Latest on main branch
**Remote**: https://github.com/shotleybuilder/ehs_enforcement.git

### Refactor Goals

**Target Metrics**:
- Reduce LiveView code by ~900 lines (38% reduction)
- Fix EA Notice progress tracking bug
- Create unified scraping interface
- Reduce new agency implementation time by 40%

**Expected Deliverables**:
- 4 strategy modules (~700 lines total)
- 1 unified LiveView (~300-400 lines)
- Supporting components (~350 lines)
- Comprehensive tests (~560 lines)
- Net reduction: ~900 lines

### Directory Structure (Before Refactor)

```
lib/ehs_enforcement/
├── scraping/
│   ├── agencies/
│   │   ├── hse.ex
│   │   └── ea.ex
│   ├── hse/
│   │   ├── case_scraper.ex
│   │   ├── case_processor.ex
│   │   ├── notice_scraper.ex
│   │   └── notice_processor.ex
│   ├── ea/
│   │   ├── case_scraper.ex
│   │   ├── case_processor.ex
│   │   ├── notice_scraper.ex (thin wrapper)
│   │   └── notice_processor.ex
│   ├── shared/
│   │   ├── business_type_detector.ex
│   │   ├── monetary_parser.ex
│   │   ├── environmental_helpers.ex
│   │   └── date_parser.ex
│   ├── resources/
│   │   ├── scrape_session.ex
│   │   └── processing_log.ex
│   ├── agency_behavior.ex
│   ├── scrape_coordinator.ex
│   └── rate_limiter.ex
├── agencies/
│   ├── hse/
│   │   └── offender_builder.ex
│   └── ea/
│       └── offender_builder.ex

lib/ehs_enforcement_web/
├── live/admin/
│   ├── case_live/
│   │   └── scrape.ex (1,278 lines - TO BE REMOVED)
│   └── notice_live/
│       └── scrape.ex (1,111 lines - TO BE REMOVED)
└── components/
    └── progress_component.ex (288 lines - existing)
```

### Expected Structure (After Refactor)

```
lib/ehs_enforcement/
├── scraping/
│   ├── strategies/              # NEW
│   │   ├── hse/
│   │   │   ├── case_strategy.ex
│   │   │   └── notice_strategy.ex
│   │   └── ea/
│   │       ├── case_strategy.ex
│   │       └── notice_strategy.ex
│   ├── scrape_strategy.ex       # NEW - Behavior definition
│   ├── strategy_registry.ex     # NEW - Strategy lookup
│   └── [existing files unchanged]

lib/ehs_enforcement_web/
├── live/admin/
│   └── scrape_live.ex           # NEW - Unified LiveView
└── components/
    ├── scrape_form_component.ex      # NEW
    └── scrape_progress_component.ex  # NEW (replaces progress_component.ex)
```

---

## Notes

- This snapshot provides baseline for measuring refactor success
- All metrics captured before any Phase 1 changes
- Known issues documented for verification after refactor
- Directory structure changes planned but not yet implemented
