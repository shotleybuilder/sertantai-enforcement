# Scraping Module Documentation

## Overview
This directory contains documentation and analysis of the scraping architecture for HSE and EA enforcement data collection.

## Quick Navigation

### Architecture Analysis
**[scraping-architecture-analysis.md](scraping-architecture-analysis.md)** (24 KB)
- Comprehensive comparison of EA and HSE implementations
- Case vs. Notice scraping patterns for each agency
- Detailed duplication analysis with code examples
- 11 sections covering all aspects of the architecture

**Key Sections**:
- Part 1: Agency-level architectural differences (HSE pagination vs EA date-ranges)
- Part 2: EA implementation analysis (Case vs Notice scraping)
- Part 3: HSE implementation analysis (Case vs Notice scraping)
- Part 4: LiveView handler duplication
- Part 5-8: Detailed duplication tables and code examples
- Part 9-10: Consolidation opportunities and recommendations

### Implementation Roadmap
**[consolidation-roadmap.md](consolidation-roadmap.md)** (11 KB)
- 3-phase consolidation plan (8-12 hours total)
- Step-by-step implementation instructions
- Testing strategy and risk mitigation
- Week-by-week timeline

**Phases**:
- **Phase 1**: Quick Wins (2-3 hours, zero risk) - Extract utilities
- **Phase 2**: Medium Effort (2-3 hours) - Consolidate processors
- **Phase 3**: High Impact (4-6 hours) - Consolidate LiveView handlers

### Bug Investigations
**[ea-duplicate-detection.md](ea-duplicate-detection.md)** (20 KB)
- EA duplicate detection investigation
- Case-by-case analysis of duplicate cases

**[CRITICAL-ea-duplicate-bug.md](CRITICAL-ea-duplicate-bug.md)** (5.8 KB)
- Critical bug findings
- Quick summary and status

## Key Findings at a Glance

### Code Duplication
- **LiveView**: 900-1000 lines (60-70% duplicated)
- **HSE Processors**: 140-180 lines (25-30% duplicated)
- **EA Processors**: 150-200 lines (15-20% duplicated)
- **Total Opportunity**: 1,150-1,250 lines to consolidate

### Architecture Patterns
| Aspect | HSE | EA |
|--------|-----|-----|
| Pagination | Incremental pages | Date-range, single request |
| Databases | Multiple (convictions, notices, appeals) | N/A - web-based only |
| Rate Limiting | Per-page (3s) | Per-record (3s) |
| Early Stop | If all current page exist | None |

### Agency-Specific Patterns

**EA (Environment Agency)**:
- Good scraper design: NoticeScraper is clean wrapper around CaseScraper
- Medium processor duplication: Environmental data, offender attributes
- Addresses: Company registration numbers, environmental impact

**HSE (Health & Safety Executive)**:
- Different HTML table structures for cases vs notices
- High processor duplication: Business type detection (IDENTICAL in both)
- Fields: SIC codes, local authority, breach handling

## File Locations

### Main Scraping Modules
```
lib/ehs_enforcement/scraping/
├── ea/
│   ├── case_scraper.ex (603 lines)
│   ├── case_processor.ex (695 lines)
│   ├── notice_scraper.ex (231 lines) - wrapper pattern
│   └── notice_processor.ex (708 lines)
├── hse/
│   ├── case_scraper.ex (556 lines)
│   ├── case_processor.ex (466 lines)
│   ├── notice_scraper.ex (221 lines)
│   └── notice_processor.ex (322 lines)
└── [other modules]

lib/ehs_enforcement_web/live/admin/
├── case_live/
│   └── scrape.ex (1,279 lines) - ⚠️ 60-70% duplicated
└── notice_live/
    └── scrape.ex (1,124 lines) - ⚠️ 60-70% duplicated
```

### Shared Utilities (Current)
```
lib/ehs_enforcement/utilities/
├── business_type_detector.ex - DOES NOT EXIST (needs extraction!)
├── monetary_parser.ex - DOES NOT EXIST (needs extraction!)
└── date_parser.ex - DOES NOT EXIST (needs extraction!)
```

### Agency-Specific Helpers (Current)
```
lib/ehs_enforcement/agencies/
├── ea/
│   ├── data_helpers.ex - DOES NOT EXIST (needs extraction!)
│   ├── offender_builder.ex - DOES NOT EXIST (needs extraction!)
│   ├── data_transformer.ex
│   └── offender_matcher.ex
└── hse/
    ├── offender_builder.ex - DOES NOT EXIST (needs extraction!)
    ├── data_transformer.ex
    └── offender_matcher.ex
```

## Exact Duplications Found

### 1. Business Type Logic (23 lines - IDENTICAL)
**Current Locations**:
- `HSE.CaseProcessor.determine_business_type/1` (lines 423-433)
- `HSE.NoticeProcessor.determine_business_type/1` (lines 310-320)
- EA processors have similar implementations

**Consolidation**: Extract to `lib/ehs_enforcement/utilities/business_type_detector.ex`

### 2. Environmental Data (30-40 lines - SIMILAR)
**Current Locations**:
- `EA.CaseProcessor.assess_environmental_impact/1` (8 lines)
- `EA.NoticeProcessor.build_environmental_impact/1` (14 lines)
- Similar logic for detecting environmental receptor

**Consolidation**: Extract to `lib/ehs_enforcement/agencies/ea/data_helpers.ex`

### 3. LiveView Handlers (900-1000 lines - 60-70% DUPLICATED)
**Current Locations**:
- `lib/ehs_enforcement_web/live/admin/case_live/scrape.ex` (1,279 lines)
- `lib/ehs_enforcement_web/live/admin/notice_live/scrape.ex` (1,124 lines)

**Consolidation**: Create base module with callbacks

## Getting Started

### For Understanding the Architecture
1. Read "Part 1: Agency-Level Architectural Differences" in scraping-architecture-analysis.md
2. Skim the comparison tables in Parts 5-7
3. Review the architectural comparison matrix in Part 7

### For Planning Consolidation
1. Read consolidation-roadmap.md "Quick Reference" section
2. Start with Phase 1: Quick Wins (2-3 hours, zero risk)
3. Business type extraction is the perfect starting point

### For Detailed Implementation
1. Reference scraping-architecture-analysis.md Part 6 for specific functions to extract
2. Follow step-by-step instructions in consolidation-roadmap.md
3. Use the testing strategy provided

## Next Steps

1. **Review** both documentation files
2. **Prioritize** Phase 1 (Quick Wins) for immediate improvements
3. **Schedule** Phase 3 (LiveView) when you have time for larger refactoring
4. **Track** progress as you implement each phase

## Questions?
Refer to the detailed analysis documents for specific code locations, examples, and implementation guidance.

