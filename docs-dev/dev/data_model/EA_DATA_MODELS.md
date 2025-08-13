# Environment Agency Data Models Research

## Overview

This document analyzes enforcement data sources and schemas from UK environmental enforcement agencies, comparing them to the existing HSE enforcement data structure used in this application.

**Research Date:** 2025-08-13
**Target Agencies:**
- Environment Agency (England)
- Scottish Environmental Protection Agency (SEPA) 
- Natural Resources Wales (NRW)

---

## UK Environment Agency (England)

### Data Sources

1. **Environment Agency Prosecutions Dataset** (data.gov.uk)
   - **Format:** XLSX
   - **Update Frequency:** Quarterly
   - **Date Range:** From January 2000
   - **Coverage:** Cases completed that resulted in conviction
   - **Note:** Records related to prosecution of individuals are anonymised

2. **Register of Enforcement Actions** (environment.data.gov.uk)
   - **Format:** Online register with downloadable zip archive
   - **Coverage:** Formal cautions and prosecutions against companies only
   - **License:** Open Government Licence

### Data Schema - Register of Enforcement Actions

#### Core Fields
```
Offender Name          (String)    - Company name
Action Type            (Enum)      - "Caution" | "Court Case" | "Enforcement Notice"
Offence Type          (String)    - Regulatory code/act reference
Agency Function       (String)    - "Waste" | "Water Quality" | "Flood" | "Fisheries"
Action Date Range     (Date)      - From/to date filtering
```

#### Enforcement Action Types
- **Cautions** - Formal warnings issued
- **Court Cases** - Prosecutions taken to court
- **Enforcement Notices** - Regulatory notices issued

#### Agency Functions Covered
- Waste Management
- Water Quality
- Flood Management  
- Fisheries
- Pollution Control
- Various environmental regulations (extensive list)

### Current Prosecution Trends (2024-2025)
- Significant decline: Prosecutions at 6% of levels from a decade ago
- 84% decline in enforcement actions over last 10 years
- Increased use of alternative enforcement methods (e.g., enforcement undertakings)
- Shift from prosecutions to civil sanctions and undertakings

---

## Scottish Environmental Protection Agency (SEPA)

### Data Sources

1. **Annual Regulation Reports** 
   - **Most Recent:** 2023 data (published 2024)
   - **Format:** PDF reports with statistical summaries
   - **Coverage:** Comprehensive enforcement statistics

2. **Public Register** (Digital transformation in progress)
   - **Current Status:** Rebuilding after 2020 data loss
   - **Future:** New online digital Public Register service planned
   - **Access:** 16 separate public registers maintained

### Data Schema - Enforcement Framework

#### Enforcement Tools Available
```
Fixed Monetary Penalties (FMP)
├── Level 1: £300
├── Level 2: £600  
└── Level 3: £1000

Variable Monetary Penalties (VMP)
└── Discretionary amounts for serious offences

Prosecution Reports
├── Submitted via SRAWEB to COPFS
├── Target: 90% within 6 months of incident
└── Prepared per Guide for Specialist Reporting Agencies
```

#### 2023 Enforcement Statistics
```
Total Cases Concluded: 442
Cases Still Ongoing: 389
Successful Prosecutions: 85 (126 charges)
Total Fines: £648,320
```

#### Enforcement Actions Tracked (2012-2017 Historical Data)
- Formal enforcement actions by regime
- Cases referred to Procurator Fiscal by regime
- Penalty levels and undertakings accepted
- Compliance assessment results

### Planned 2025 Developments
- Environmental Performance Assessment Scheme introduction
- Enhanced publication of enforcement information
- Improved public register systems

---

## Natural Resources Wales (NRW)

### Data Sources

1. **Public Register** (publicregister.naturalresources.wales)
   - **Coverage:** Environmental permits, water resources, marine licensing
   - **Document Types:** Applications, compliance documents, monitoring reports
   - **Historical Cutoff:** Documents before September 2018 may not be fully available

2. **Annual Regulation Reports**
   - **Most Recent:** 2023 data available
   - **Format:** Statistical summaries and case studies

### Data Schema - Enforcement Records

#### 2023 Enforcement Statistics
```
Enforcement Cases Concluded: 442
Ongoing Cases: 389
Successful Prosecutions: 85
Total Charges: 126
Total Fines: £648,320
```

#### Recent Prosecution Activity (2025)
```
Case Example - Illegal Tree Felling:
├── Court: Swansea Crown Court
├── Date: 31 March 2025
├── Fine Amount: £78,614.60
└── Offence: Illegal tree felling
```

#### Public Register Information Types
```
Environmental Permits
├── Waste permits
├── Water quality permits
└── Regulated industry permits

Water Resources Licenses
└── Abstraction and discharge licenses

Marine Licenses
└── Marine activity permissions

Enforcement Information
├── Hazardous Waste Producers
├── Enforcement Actions
└── Scrap Metal Dealers
```

#### Document Categories
- **Application Documents** - Initial permit applications
- **Compliance Documents** - Monitoring and compliance reports  
- **Management Systems** - Environmental management documentation
- **Monitoring Reports** - Regular monitoring data
- **Operational Plans** - Operational procedures and plans

---

## Comparison with HSE Data Model

### Current HSE Schema (from codebase analysis)

#### Case Resource (`EhsEnforcement.Enforcement.Case`)
```elixir
# Primary identifiers
uuid_primary_key(:id)
attribute(:airtable_id, :string)
attribute(:regulator_id, :string)

# Core enforcement data
attribute(:offence_result, :string)
attribute(:offence_fine, :decimal)
attribute(:offence_costs, :decimal)
attribute(:offence_action_date, :date)
attribute(:offence_hearing_date, :date)
attribute(:offence_breaches, :string)
attribute(:offence_breaches_clean, :string)
attribute(:regulator_function, :string)
attribute(:regulator_url, :string)
attribute(:related_cases, :string)
attribute(:offence_action_type, :string)
attribute(:url, :string)
attribute(:last_synced_at, :utc_datetime)

# Relationships
belongs_to :agency, EhsEnforcement.Enforcement.Agency
belongs_to :offender, EhsEnforcement.Enforcement.Offender
has_many :breaches, EhsEnforcement.Enforcement.Breach
```

#### Notice Resource (`EhsEnforcement.Enforcement.Notice`)  
```elixir
# Primary identifiers
uuid_primary_key(:id)
attribute(:airtable_id, :string)
attribute(:regulator_id, :string)
attribute(:regulator_ref_number, :string)

# Notice-specific data
attribute(:notice_date, :date)
attribute(:operative_date, :date) 
attribute(:compliance_date, :date)
attribute(:notice_body, :string)
attribute(:offence_action_type, :string)
attribute(:offence_action_date, :date)
attribute(:offence_breaches, :string)
attribute(:url, :string)
attribute(:last_synced_at, :utc_datetime)

# Relationships
belongs_to :agency, EhsEnforcement.Enforcement.Agency
belongs_to :offender, EhsEnforcement.Enforcement.Offender
```

---

## Data Model Adaptations for EA Sources

### Required Schema Extensions

#### 1. Agency Function Classification
```elixir
# New enum type needed for EA functions
attribute(:agency_function, :atom) # :waste, :water_quality, :flood, :fisheries, etc.
```

#### 2. Enhanced Action Type Classification
```elixir
# Expand beyond HSE action types to include EA-specific actions
attribute(:enforcement_action_type, :atom) 
# Values: :prosecution, :caution, :enforcement_notice, :civil_sanction, :undertaking
```

#### 3. Civil Sanctions and Undertakings Support
```elixir
# New attributes for EA civil enforcement tools
attribute(:penalty_amount, :decimal)
attribute(:penalty_type, :atom) # :fixed_monetary, :variable_monetary, :undertaking
attribute(:undertaking_details, :string)
attribute(:undertaking_accepted_date, :date)
```

#### 4. SEPA-Specific Fields
```elixir
# SEPA uses COPFS reporting system
attribute(:copfs_reference, :string)
attribute(:reporting_target_date, :date)
attribute(:procurator_fiscal_decision, :string)
```

#### 5. NRW-Specific Fields  
```elixir
# NRW has more detailed permit/license tracking
attribute(:permit_number, :string)
attribute(:permit_type, :atom) # :environmental, :water_resources, :marine
attribute(:compliance_status, :atom)
```

### Proposed Unified Schema

#### Enhanced Case Resource
```elixir
defmodule EhsEnforcement.Enforcement.Case do
  # Existing HSE fields...
  
  # EA/SEPA/NRW extensions
  attribute(:agency_function, :atom)          # :health_safety, :waste, :water_quality, etc.
  attribute(:enforcement_tool_type, :atom)    # :prosecution, :caution, :notice, :penalty, :undertaking
  attribute(:penalty_amount, :decimal)        # For civil sanctions
  attribute(:penalty_type, :atom)             # :fixed, :variable, :court_fine
  attribute(:permit_reference, :string)       # Associated permit/license
  attribute(:compliance_deadline, :date)      # For undertakings/notices
  attribute(:enforcement_outcome, :string)    # Detailed outcome description
  
  # SEPA-specific
  attribute(:copfs_reference, :string)
  attribute(:procurator_fiscal_status, :atom)
  
  # Document links (all agencies maintain document registers)
  attribute(:public_register_url, :string)
  attribute(:case_documents, {:array, :string})
end
```

#### Enhanced Notice Resource
```elixir
defmodule EhsEnforcement.Enforcement.Notice do
  # Existing HSE fields...
  
  # EA/SEPA/NRW extensions  
  attribute(:notice_category, :atom)          # :improvement, :prohibition, :enforcement, :caution
  attribute(:agency_function, :atom)          # Match case function categorization
  attribute(:permit_conditions_breached, :string)
  attribute(:improvement_required, :string)
  attribute(:appeal_deadline, :date)
  attribute(:appeal_status, :atom)            # :none, :pending, :upheld, :dismissed
  attribute(:compliance_monitoring, :string)
end
```

### Implementation Considerations

#### Database Performance
- Current HSE model uses composite indexes `[:agency_id, :offence_action_date]`
- EA sources would benefit from similar indexing on `[:agency_id, :agency_function, :action_date]`
- Text search capabilities already implemented via pg_trgm for fuzzy matching

#### Data Integration Challenges
1. **Inconsistent Data Availability**: EA quarterly updates vs HSE real-time scraping
2. **Different Action Taxonomies**: HSE focuses on prosecutions, EA includes civil sanctions
3. **Anonymization Policies**: EA anonymizes individual prosecutions
4. **Historical Data Gaps**: SEPA lost pre-2018 register data, NRW pre-2018 availability limited

#### Scraping Feasibility Assessment

| Agency | Data Availability | Scraping Complexity | Update Frequency |
|--------|------------------|-------------------|------------------|
| **Environment Agency** | ✅ Public register searchable | 🟡 Medium - structured but requires download | Quarterly |
| **SEPA** | ⚠️ Limited during rebuild | 🔴 High - manual reports only | Annual |
| **NRW** | ✅ Public register online | 🟡 Medium - permit-focused structure | Ongoing |

### Recommended Implementation Approach

1. **Phase 1**: Extend existing schema with EA-specific fields while maintaining HSE compatibility
2. **Phase 2**: Implement EA register data import (quarterly batch process)
3. **Phase 3**: Add NRW register integration (permit-focused)
4. **Phase 4**: Monitor SEPA digital register development for future integration

The unified data model would allow this application to become a comprehensive UK enforcement data platform covering health & safety, environmental, and regulatory enforcement across all UK jurisdictions.

---

## References

- Environment Agency Prosecutions Dataset: https://www.data.gov.uk/dataset/6f06910a-8411-4117-9905-6284f1997c33/environment-agency-prosecutions
- Environment Agency Register: https://environment.data.gov.uk/public-register/view/search-enforcement-action  
- SEPA Enforcement Policy: https://www.sepa.org.uk/regulations/enforcement/
- NRW Public Register: https://publicregister.naturalresources.wales/
- NRW Annual Regulation Reports: https://naturalresources.wales/about-us/how-we-are-performing/