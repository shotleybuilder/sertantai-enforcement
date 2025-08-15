# Environment Agency Notice Scraping Integration Plan

**Document Version**: 1.1  
**Date**: August 15, 2025  
**Focus**: Extending Notice scraping to Environment Agency following unified scraping architecture

**Prerequisites**: Complete scraping architecture standardization (see SCRAPING-ARCHITECTURE-STANDARDIZATION.md)

## Executive Summary

This plan outlines the integration of Environment Agency (EA) notice scraping with the existing HSE notice scraping system. The implementation follows the unified patterns established during recent case scraping integration, including shared database interfaces, PubSub notifications, unified progress components, and behavior-driven architecture.

## Background & Context

### Recent Integration Success Patterns

From the analysis of recent case scraping unification work:

1. **Unified Progress Components** (2025-08-13): Single progress component with agency-agnostic display logic
2. **Agency Behavior Pattern**: Standardized interface for agency-specific scraping implementations  
3. **Unified Case Processor**: Consistent status reporting (:created, :updated, :existing) for UI display
4. **Shared Database Resources**: Extended existing Ash resources rather than creating agency-specific ones
5. **Unified Processing Logs**: Single ProcessingLog resource with agency field instead of separate logs

### Current HSE Notice Architecture

**HSE Notice Scraping Components**:
- `EhsEnforcement.Agencies.Hse.NoticeScraper` - HTTP scraping logic
- `EhsEnforcement.Scraping.Hse.NoticeProcessor` - Data transformation and Ash integration
- Rate limiting and error handling patterns
- Three-stage data enrichment (basic → details → breaches)

**Key HSE Notice Patterns**:
- Page-based pagination (10 notices per page)
- Sequential detail fetching for each notice
- Integration with existing Notice Ash resource
- Offender matching using existing patterns
- PubSub notifications through Ash

## EA Notice Integration Requirements

### EA Notice Data Characteristics

From EA_PLAN.md "Extended Resource: Notice" section:

**EA Notice Types**:
- Enforcement Notices (primary focus for this integration)
- Cautions (handled by Case scraping - out of scope)
- Court Cases (handled by Case scraping - out of scope)

**EA Enforcement Notice Data Fields**:
```
EA Notice Fields → HSE Notice Resource Mapping:
├── regulator_id: EA case reference → regulator_id
├── notice_date: Action date → notice_date  
├── operative_date: When notice becomes effective → operative_date
├── compliance_date: Compliance deadline → compliance_date
├── notice_body: Notice text/description → notice_body
├── offence_action_type: "Enforcement Notice" → offence_action_type
├── offence_breaches: Breach description → offence_breaches
├── regulator_url: EA record URL → url
├── Environmental impact data → New EA-specific fields
├── Legal framework (Act + Section) → New EA-specific fields
└── Agency function (Waste, Water, etc.) → regulator_function
```

### EA-Specific Challenges

1. **No Dedicated Notice Endpoint**: EA enforcement notices are mixed within the general enforcement action search
2. **Action Type Filtering**: Must filter for `action_type=enforcement-notice` only
3. **Single Page Results**: No pagination (all results returned on one page for date ranges)
4. **Environmental Context**: Additional environmental impact and legal framework data
5. **Different URL Structure**: EA uses data.gov.uk domain with different URL patterns

## Architecture Design

### 1. Agency Behavior Integration

**Extend Existing EA Agency Module**: `EhsEnforcement.Scraping.Agencies.Ea`

```
Update Existing EA Agency Module:
├── validate_params/1: Add notice-specific validation (action_types: [:enforcement_notice])
├── start_scraping/2: Route to notice processor for enforcement notice action types  
├── process_results/1: Handle both case and notice results uniformly
└── Reuse existing EA configuration and session management
```

**Key Integration Strategy**:
- **Reuse existing EA agency behavior** - don't create separate EaNotices module
- Filter action_types to `[:enforcement_notice]` only for notice scraping
- Route enforcement notice requests to notice processor instead of case processor
- Maintain single EA scraping session tracking

### 2. EA Notice Scraping Components (Unified Architecture)

**New EA Notice Scraper**: `EhsEnforcement.Scraping.Ea.NoticeScraper`
- Thin wrapper around existing `EhsEnforcement.Scraping.Ea.CaseScraper`
- Filters action types to `[:enforcement_notice]` only
- Same HTTP scraping patterns as EA case scraper

**New EA Notice Processor**: `EhsEnforcement.Scraping.Ea.NoticeProcessor`
- Follows same pattern as `EhsEnforcement.Scraping.Hse.NoticeProcessor`
- Uses `EhsEnforcement.Agencies.Ea.DataTransformer` for format conversion
- Uses `EhsEnforcement.Agencies.Ea.OffenderMatcher` for company matching

```
ProcessedEaNotice Struct:
├── regulator_id: EA case reference
├── agency_code: :environment_agency  
├── offender_attrs: Company data for matching
├── notice_date: When notice was issued
├── operative_date: When notice becomes effective
├── compliance_date: Compliance deadline
├── notice_body: Notice text/requirements
├── offence_action_type: "Enforcement Notice"
├── environmental_impact: EA-specific impact data
├── legal_framework: Act and section
├── source_metadata: Scraping metadata
└── regulator_function: "Waste", "Water Quality", etc.
```

**Processing Pipeline** (Consistent with HSE):
1. **EA Search**: Use `NoticeScraper.collect_summary_records/3` (wraps case scraper)
2. **Detail Enrichment**: Use `NoticeScraper.fetch_detail_record/2` for notice details  
3. **Data Transformation**: Use `Agencies.Ea.DataTransformer` for Notice resource format
4. **Offender Matching**: Use `Agencies.Ea.OffenderMatcher` with company registration numbers
5. **Notice Creation**: Create/update notices using Ash Notice resource

### 3. Unified Notice Resource Extension

**Extend Existing Notice Resource** (NOT create new EA-specific resource):

```sql
-- New EA-specific fields added to existing notices table
ALTER TABLE notices ADD COLUMN regulator_event_reference TEXT;
ALTER TABLE notices ADD COLUMN environmental_impact TEXT;  
ALTER TABLE notices ADD COLUMN environmental_receptor TEXT;
ALTER TABLE notices ADD COLUMN legal_act TEXT;
ALTER TABLE notices ADD COLUMN legal_section TEXT;
-- regulator_function field already exists from HSE notices
```

**Ash Resource Updates**:
```elixir
# In EhsEnforcement.Enforcement.Notice resource
attribute :regulator_event_reference, :string  # EA event ID
attribute :environmental_impact, :string       # "none", "minor", "major"  
attribute :environmental_receptor, :string     # "water", "land", "air"
attribute :legal_act, :string                  # Environmental act
attribute :legal_section, :string              # Regulation section
# Existing fields work for both HSE and EA notices
```

### 4. Scraping Coordinator Integration

**Minimal Updates to Existing Infrastructure**:

```elixir
# EA notice scraping handled by existing start_scraping_session/1
# with specific action_types filter:
opts = [
  agency: :environment_agency,
  action_types: [:enforcement_notice],  # Only enforcement notices
  date_from: ~D[2024-01-01],
  date_to: ~D[2024-12-31]
]

EhsEnforcement.Scraping.ScrapeCoordinator.start_scraping_session(opts)
```

**Internal Routing Logic** (in existing `Agencies.Ea` module):
- If action_types contains `:enforcement_notice` → route to `NoticeProcessor`  
- If action_types contains `:court_case` or `:caution` → route to `CaseProcessor`
- Reuse all existing session management, progress tracking, and error handling

### 5. UI Integration Points

**Admin Interface Updates**:
- Extend scraping admin to support notice scraping selection
- Add EA notice scraping configuration options
- Unified progress display for both case and notice scraping sessions

**Progress Component Compatibility**:
- Existing unified progress component works for notice scraping
- Same :created/:updated/:existing status patterns
- Agency-agnostic display with notice-specific metrics

## Implementation Phases

### Phase 0: Architecture Standardization (Week 0)
**Prerequisites - must be completed first**:
- [ ] Complete HSE standardization (move notice_scraper, create data_transformer)
- [ ] Complete EA standardization (move case_processor to scraping/ea/)
- [ ] Verify unified architecture patterns working
- [ ] Update all imports and references

### Phase 1: Foundation Setup (Week 1)

**1.1 Ash Resource Extensions**
- [ ] Extend Notice resource with EA-specific fields (environmental impact, legal framework)
- [ ] Generate and apply database migrations
- [ ] Update Notice resource actions for EA data
- [ ] Test Notice resource compatibility with existing HSE notices

**1.2 EA Notice Scraper Module**  
- [ ] Create `EhsEnforcement.Scraping.Ea.NoticeScraper`
- [ ] Implement as thin wrapper around existing `EhsEnforcement.Scraping.Ea.CaseScraper`
- [ ] Add `:enforcement_notice` filtering logic
- [ ] Reuse existing HTTP scraping and rate limiting patterns
- [ ] Test EA notice search and detail fetching

**1.3 EA Notice Processor Module**
- [ ] Create `EhsEnforcement.Scraping.Ea.NoticeProcessor`
- [ ] Follow pattern of `EhsEnforcement.Scraping.Hse.NoticeProcessor`
- [ ] Implement `ProcessedEaNotice` struct (similar to HSE's `ProcessedNotice`)
- [ ] Integrate with `Agencies.Ea.DataTransformer` for format conversion
- [ ] Integrate with `Agencies.Ea.OffenderMatcher` for company matching
- [ ] Add environmental impact and legal framework parsing
- [ ] Test notice creation using Ash patterns

### Phase 2: EA Agency Integration (Week 2)

**2.1 EA Agency Module Updates**
- [ ] Update `EhsEnforcement.Scraping.Agencies.Ea` for notice routing
- [ ] Add routing logic: `:enforcement_notice` → EA NoticeProcessor
- [ ] Add routing logic: `:court_case`, `:caution` → EA CaseProcessor (moved location)
- [ ] Test agency behavior routing with different action types

**2.2 EA Notice Data Pipeline**
- [ ] Test EA NoticeScraper with `:enforcement_notice` action type filter
- [ ] Verify EA detail record parsing works for notice data
- [ ] Test EA NoticeProcessor with DataTransformer integration
- [ ] Test end-to-end EA notice creation flow

**2.3 Processing Log Integration**
- [ ] Verify ProcessingLog works with notice scraping (existing unified log structure)
- [ ] Test notice-specific metrics display in unified progress component
- [ ] Ensure EA notices appear correctly in scraping session logs
- [ ] Test error handling with duplicate EA notice scenarios

### Phase 3: UI Integration (Week 3)

**3.1 Admin Interface Extensions**
- [ ] Add notice scraping section to admin dashboard
- [ ] EA notice scraping configuration options
- [ ] Date range selection for EA notice scraping
- [ ] Integration with existing scraping controls

**3.2 Progress Display Updates**
- [ ] Test unified progress component with notice scraping
- [ ] Ensure agency-agnostic display works for EA notices
- [ ] Notice-specific metrics in progress display
- [ ] Real-time updates via PubSub integration

**3.3 Notice Display Enhancements**
- [ ] Update notice list/detail views to show agency
- [ ] Display EA-specific fields (environmental impact, legal framework)
- [ ] Cross-agency notice search functionality
- [ ] Agency filtering in notice interfaces

### Phase 4: Testing & Validation (Week 4)

**4.1 Integration Testing**
- [ ] End-to-end EA notice scraping workflow with `:enforcement_notice` filter
- [ ] HSE notice scraping compatibility (regression testing) 
- [ ] Cross-agency notice search and display
- [ ] Error handling and recovery scenarios

**4.2 Performance Testing**  
- [ ] EA notice scraping performance (reusing EA infrastructure)
- [ ] Database performance with extended Notice resource
- [ ] UI responsiveness with mixed HSE/EA notice data
- [ ] Memory usage during notice processing

**4.3 Data Validation**
- [ ] Accuracy of EA notice data transformation
- [ ] Offender matching correctness using company registration numbers
- [ ] Environmental impact and legal framework data integrity
- [ ] Notice compliance date and operative date parsing

## Technical Specifications

### EA Notice URL Structure

**EA Search URL** (Enforcement Notices Only):
```
Base URL: https://environment.data.gov.uk/public-register/enforcement-action/registration

Parameters:
- name-search: "" (empty but required)
- actionType: http%3A%2F%2Fenvironment.data.gov.uk%2Fpublic-register%2Fenforcement-action%2Fdef%2Faction-type%2Fenforcement-notice
- offenceType: "" (empty but required)  
- agencyFunction: "" (empty but required)
- after: 2024-01-01 (start date)
- before: 2024-12-31 (end date)
```

**EA Detail Page URL**:
```
https://environment.data.gov.uk/public-register/enforcement-action/registration/{ea_record_id}?__pageState=result-enforcement-action
```

### Data Transformation Mapping

**EA Notice Fields → Notice Resource**:
```elixir
%{
  # Core Notice Fields (existing)
  regulator_id: ea_case_reference,
  notice_date: action_date,
  operative_date: nil,  # Not provided by EA
  compliance_date: nil,  # Not provided by EA  
  notice_body: offence_description,
  offence_action_type: "Enforcement Notice",
  offence_action_date: action_date,
  offence_breaches: offence_description,
  url: ea_detail_page_url,
  
  # EA-Specific Extensions (new fields)
  regulator_event_reference: ea_event_reference,
  environmental_impact: environmental_impact_assessment,
  environmental_receptor: environmental_receptor_type,
  legal_act: regulatory_act,
  legal_section: regulatory_section,
  regulator_function: agency_function,
  
  # Relationships
  agency_id: environment_agency_id,
  offender_id: matched_offender_id
}
```

### Error Handling Strategy

**EA-Specific Error Scenarios**:
1. **No enforcement notices found**: Return empty result set (not an error)
2. **Invalid date range**: Return validation error with date format requirements
3. **EA website unavailable**: Retry with exponential backoff
4. **Individual notice detail page 404**: Log warning, continue with basic notice data
5. **Environmental impact data missing**: Use "none" as default value
6. **Legal framework data incomplete**: Log warning, store partial data

**Integration with Existing Error Handling**:
- Use same PubSub error notification patterns as case scraping
- Integrate with ProcessingLog error tracking
- Maintain session status (:running, :completed, :error) consistency
- Follow same retry and circuit breaker patterns

## Success Metrics

### Technical KPIs
- **EA Notice Coverage**: >95% of available EA enforcement notices scraped successfully
- **Data Accuracy**: <2% data validation errors in EA notice transformation
- **HSE Compatibility**: 100% backward compatibility with existing HSE notice scraping
- **Integration Performance**: <5 second response time for notice scraping session start

### Business KPIs  
- **Cross-Agency Intelligence**: Identify companies with both HSE and EA notices
- **Comprehensive Coverage**: Complete UK enforcement notice dataset (HSE + EA)
- **User Experience**: Single interface for searching all UK agency notices
- **Data Freshness**: EA notices updated within 24 hours of EA data publication

### User Experience KPIs
- **Search Performance**: <3 seconds for cross-agency notice queries
- **Interface Consistency**: Unified progress display for both case and notice scraping
- **Admin Usability**: Single scraping dashboard for all agency/data type combinations

## Risk Assessment & Mitigation

### Technical Risks

**1. EA Website Changes**
- **Risk**: EA modifies URL structure or HTML format
- **Mitigation**: Comprehensive error handling, fallback to basic data, monitoring alerts

**2. Database Schema Conflicts**  
- **Risk**: EA notice fields conflict with existing HSE notice structure
- **Mitigation**: Use optional fields, test migrations in staging, maintain backward compatibility

**3. Performance Impact**
- **Risk**: EA notice scraping impacts existing HSE performance  
- **Mitigation**: Separate scraping queues, resource monitoring, rate limiting

### Integration Risks

**1. Agency Behavior Pattern Deviation**
- **Risk**: EA notice scraping doesn't fit established behavior pattern
- **Mitigation**: Flexible behavior interface, EA-specific customizations allowed

**2. UI Component Incompatibility**
- **Risk**: Unified progress component doesn't handle notice-specific metrics
- **Mitigation**: Test with notice scraping early, add notice-specific display logic

### Data Quality Risks

**1. EA Data Inconsistency**
- **Risk**: EA environmental impact data incomplete or inconsistent
- **Mitigation**: Default values, data validation, quality monitoring

**2. Offender Matching Failures**
- **Risk**: EA company data doesn't match existing offender records
- **Mitigation**: Enhanced matching algorithms, manual review interface for failed matches

## Future Enhancement Opportunities

### Advanced Features (Phase 5+)
- **Cross-Agency Notice Analytics**: Identify patterns in companies receiving both HSE and EA notices
- **Compliance Timeline Tracking**: Track notice compliance dates and follow-up enforcement actions
- **Industry Pattern Analysis**: Notice frequency by industry sector across agencies
- **Automated Risk Scoring**: Companies with multiple agency notices flagged as high-risk

### Additional Agency Integration
- **SEPA Notice Integration**: Scottish environmental enforcement notices
- **NRW Notice Integration**: Welsh environmental notices and permissions
- **Local Authority Integration**: Council-level enforcement notices

## Conclusion

This plan provides a comprehensive approach to integrating EA notice scraping with the existing HSE notice system using proven patterns from recent case scraping integration work. The implementation follows established architectural patterns while extending functionality to cover the complete UK environmental enforcement notice landscape.

The phased approach ensures minimal risk to existing systems while delivering incremental value at each stage. Success metrics focus on both technical performance and business value, ensuring the integration delivers meaningful cross-agency enforcement intelligence for users.