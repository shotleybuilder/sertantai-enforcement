# User Segments Analysis

**Last Updated**: January 2025

This document analyzes the three primary user segments for the EHS Enforcement platform, based on feedback from AI analysis and market research.

---

## Overview

The platform serves three distinct user segments, each with unique needs, willingness to pay, and feature requirements:

1. **Risk & Compliance Professionals** (Primary focus Q1-Q2 2025)
2. **Legal & Law Firms** (Focus Q2-Q3 2025)
3. **Investors & Financial Institutions** (Focus Q3-Q4 2025)

---

## 1. Risk & Compliance Professionals

### Profile

**Job Titles**:
- EHS Manager / Director
- Compliance Manager
- Risk Manager
- Health & Safety Advisor
- Environmental Compliance Officer
- Quality Assurance Manager

**Company Types**:
- Manufacturing companies (construction, chemicals, food processing)
- Compliance consulting firms
- Industry associations (UK Steel, Chemical Industries Association, etc.)
- Multi-site operators (retail chains, logistics companies)

**Team Size**: 1-50 compliance professionals per organization

### Pain Points

1. **Peer Benchmarking**: "How does our enforcement record compare to competitors?"
2. **Trend Monitoring**: "Are prosecutions in our industry increasing?"
3. **Risk Identification**: "Which regulations are most frequently violated in our sector?"
4. **Board Reporting**: "I need data to show executive leadership about industry trends"
5. **Resource Allocation**: "Where should we focus our compliance budget?"

### Use Cases

| Use Case | Description | Current Gap | Implementation Complexity |
|----------|-------------|-------------|---------------------------|
| Industry benchmarking | Compare company's record vs. industry average | 🔴 Large | Low (data exists, needs UI) |
| Trend analysis | Track enforcement patterns over time | 🔴 Large | Medium (needs charting) |
| Legislation monitoring | Alert on new enforcement under specific regs | 🔴 Large | Medium (watchlist system) |
| Competitor monitoring | Track enforcement against key competitors | 🔶 Medium | Low (search + saved searches) |
| Regional risk assessment | Identify enforcement hotspots by location | 🔴 Large | Medium (geographic aggregation) |
| Board reporting | Generate executive summaries with charts | 🔴 Large | High (custom report builder) |

**Legend**: 🔴 Large Gap, 🔶 Medium Gap, 🟡 Small Gap, ✅ Complete

---

###

 Required Features

**Must-Have (Q1 2025)**:
- Industry/sector filtering (SIC codes, EA sectors)
- Saved searches for regular monitoring
- CSV exports for offline analysis
- Basic trend charts (monthly case counts)

**Should-Have (Q2 2025)**:
- Custom report builder
- Scheduled report emails
- Risk scoring (recidivism tracking)
- Watchlist with email alerts

**Nice-to-Have (Q3-Q4 2025)**:
- Predictive enforcement trends
- Compliance dashboard widgets (embed in intranets)
- API integration with compliance management systems
- White-label reports (branded for clients)

### Willingness to Pay

**Price Sensitivity**: Medium
- Compliance budgets are significant but scrutinized
- ROI focused (must show time savings or risk reduction)
- Annual contracts preferred over monthly

**Target Price Point**:
- **Individual**: £49-99/month
- **Team**: £199-499/month (5-10 users)
- **Enterprise**: £1,500-5,000/month (unlimited users)

**Value Drivers**:
- Time saved on manual research (2-5 hours/week)
- Better board presentations (defensible data)
- Risk mitigation (identify compliance gaps before inspection)

### Current Capabilities vs. Needs

**What We Have** (40% Complete):
- ✅ Comprehensive case/notice data
- ✅ Agency filtering (HSE, EA)
- ✅ Date range filtering
- ✅ CSV exports
- ✅ Basic dashboard with recent activity

**What's Missing** (60%):
- ❌ Industry filtering in UI (data exists!)
- ❌ Trend charts over time
- ❌ Saved searches
- ❌ Custom reports
- ❌ Risk scores
- ❌ Email alerts

**Time to MVP**: 3 months (Q1 2025)

---

## 2. Legal & Law Firms

### Profile

**Job Titles**:
- Regulatory Defense Lawyer
- In-House Counsel (EHS/Compliance)
- Legal Researcher
- Paralegal (regulatory practice)
- Expert Witness (health & safety)

**Firm Types**:
- Specialist regulatory defense firms (5-50 lawyers)
- Large commercial firms with regulatory practice (100+ lawyers)
- In-house legal teams at large corporations
- Solo practitioners (niche EHS defense)

**Team Size**: 1-20 lawyers per firm

### Pain Points

1. **Precedent Research**: "What's the typical fine for this type of breach?"
2. **Case Preparation**: "Find similar cases to support our defense strategy"
3. **Client Due Diligence**: "Research this company's enforcement history before taking them on"
4. **Expert Witness Prep**: "Identify enforcement patterns to support testimony"
5. **Sentencing Arguments**: "Show this fine is disproportionate compared to similar cases"

### Use Cases

| Use Case | Description | Current Gap | Implementation Complexity |
|----------|-------------|-------------|---------------------------|
| Full-text case search | Natural language search ("fall from height fatality") | 🔶 Medium | Low (pg_trgm ready) |
| Similar case finder | ML-based similarity search | 🔴 Large | High (semantic embeddings) |
| Fine range analysis | Calculate typical penalties by breach type | 🔴 Large | Medium (aggregation queries) |
| Document management | Store/search judgments and notices | 🔴 Large | Medium (S3 integration) |
| Timeline visualization | Offender enforcement history | 🔶 Medium | Medium (LiveView components) |
| Citation linking | Link related cases | 🔴 Large | High (graph relationships) |

### Required Features

**Must-Have (Q2 2025)**:
- Full-text search UI across all case fields
- Advanced filters (legislation type, fine range, outcome)
- Case detail pages with all breach information
- Export case lists with filters applied

**Should-Have (Q3 2025)**:
- Similar case finder (semantic search)
- Fine range calculator (avg/median by breach)
- Document storage (PDF judgments)
- Timeline visualization (offender history)

**Nice-to-Have (2026)**:
- AI-powered case summarization
- Automated citation extraction
- Precedent database (key passages from judgments)
- Integration with legal research platforms (Westlaw, LexisNexis)

### Willingness to Pay

**Price Sensitivity**: Low
- Legal billing rates are high (£200-500/hour)
- Research time is expensive (10-20 hours/case)
- Quality and accuracy are paramount

**Target Price Point**:
- **Individual**: £99-199/month
- **Firm**: £499-1,999/month (5-20 users)
- **Enterprise**: £3,000-10,000/month (unlimited users + white-label)

**Value Drivers**:
- Billable hours saved (5-10 hours per case)
- Better case outcomes (data-driven sentencing arguments)
- Client development (impress with comprehensive due diligence)

### Current Capabilities vs. Needs

**What We Have** (45% Complete):
- ✅ Comprehensive case data
- ✅ Legislation references
- ✅ Offender history tracking
- ✅ Source URLs to original documents
- ✅ Fine/costs data

**What's Missing** (55%):
- ❌ Full-text search UI
- ❌ Similar case finder
- ❌ Fine range analytics
- ❌ Document storage
- ❌ Timeline visualization
- ❌ Advanced Boolean search

**Time to MVP**: 5 months (Q2-Q3 2025)

---

## 3. Investors & Financial Institutions

### Profile

**Job Titles**:
- ESG Analyst
- Due Diligence Analyst
- Portfolio Manager
- Investment Analyst
- Risk Analyst
- M&A Associate

**Organization Types**:
- Private equity firms
- Venture capital funds
- Investment banks (M&A teams)
- Public equities (ESG screening)
- Credit rating agencies

**Team Size**: 5-100 analysts per organization

### Pain Points

1. **ESG Screening**: "Flag companies with poor environmental/safety records"
2. **Due Diligence**: "Research target company's regulatory compliance before acquisition"
3. **Portfolio Monitoring**: "Alert me if any portfolio company gets prosecuted"
4. **Sector Risk Assessment**: "Which industries have highest enforcement risk?"
5. **Reputational Risk**: "Quantify regulatory risk for credit rating models"

### Use Cases

| Use Case | Description | Current Gap | Implementation Complexity |
|----------|-------------|-------------|---------------------------|
| Bulk screening | Check 100s of companies at once | 🔴 Large | Medium (batch API) |
| ESG risk scores | Quantify enforcement history | 🔴 Large | High (ML scoring model) |
| Companies House integration | Link directors across companies | 🔴 Large | Medium (API integration) |
| Watchlist monitoring | Alert on new enforcement | 🔴 Large | Medium (webhook system) |
| Industry risk profiles | Sector-level enforcement rates | 🔶 Medium | Low (aggregation) |
| Data feeds | Automated daily exports | 🔴 Large | Medium (scheduled jobs) |

### Required Features

**Must-Have (Q3 2025)**:
- Bulk API screening (CSV upload → risk report)
- Companies House integration (director linkage)
- Basic ESG risk scores (enforcement count, fine total)
- Watchlist system with email alerts

**Should-Have (Q4 2025)**:
- Webhook notifications (real-time alerts)
- Advanced risk scores (ML-based recidivism prediction)
- Industry benchmarking (sector risk profiles)
- Data feeds (automated exports)

**Nice-to-Have (2026)**:
- Credit risk models (integrate with Moody's, S&P)
- White-label risk reports (embed in pitchbooks)
- Historical snapshots (point-in-time views for audit)
- Integration with Bloomberg Terminal, FactSet

### Willingness to Pay

**Price Sensitivity**: Very Low
- M&A due diligence budgets are enormous (£50K-500K per deal)
- ESG data providers charge £10K-100K/year (MSCI, Sustainalytics)
- Bloomberg Terminal costs £20K/user/year

**Target Price Point**:
- **Individual**: £199-499/month
- **Team**: £1,999-4,999/month (10-50 users)
- **Enterprise**: £10,000-50,000/month (unlimited users + custom integrations)

**Value Drivers**:
- Risk mitigation (avoid bad acquisitions)
- Regulatory compliance (FCA, SEC ESG disclosure requirements)
- Competitive intelligence (track competitor enforcement)
- Time savings (automated screening vs. manual research)

### Current Capabilities vs. Needs

**What We Have** (35% Complete):
- ✅ Offender search by name
- ✅ Enforcement history per offender
- ✅ Fine totals
- ✅ CSV exports (bulk data)

**What's Missing** (65%):
- ❌ Companies House integration
- ❌ Bulk screening API
- ❌ ESG risk scores
- ❌ Watchlist monitoring
- ❌ Webhooks
- ❌ Data feeds
- ❌ Historical snapshots

**Time to MVP**: 6 months (Q3-Q4 2025)

---

## Segment Prioritization Matrix

| Criteria | Risk & Compliance | Legal | Investors |
|----------|-------------------|-------|-----------|
| Market Size | 🟢 Large (10K+ UK companies) | 🟡 Medium (500+ firms) | 🔴 Small (100+ firms) |
| Willingness to Pay | 🟡 Medium (£49-499/mo) | 🟢 High (£99-1,999/mo) | 🟢 Very High (£199-4,999/mo) |
| Time to Market | 🟢 Fast (3 months) | 🟡 Medium (5 months) | 🔴 Slow (6 months) |
| Technical Complexity | 🟢 Low (UI/analytics) | 🟡 Medium (search/ML) | 🔴 High (integrations) |
| Competitive Advantage | 🟢 Strong (unique data) | 🟡 Medium (legal databases exist) | 🟡 Medium (ESG providers exist) |
| **Overall Priority** | **1st (Q1-Q2 2025)** | **2nd (Q2-Q3 2025)** | **3rd (Q3-Q4 2025)** |

### Recommendation: Sequential Launch Strategy

**Phase 1 (Q1-Q2 2025)**: Focus exclusively on Risk & Compliance
- Fastest to validate product-market fit
- Lowest technical complexity
- Large addressable market
- Clear pain points we can solve immediately

**Phase 2 (Q2-Q3 2025)**: Add Legal features
- Higher price point than Risk & Compliance
- Builds on existing search infrastructure
- Can upsell existing Risk users to Legal tier

**Phase 3 (Q3-Q4 2025)**: Add Investor features
- Highest price point
- Requires mature product (Companies House, APIs)
- Can upsell both previous segments

---

## Cross-Segment Opportunities

### Features Valued by All Segments

1. **Full-text search** - Universal need
2. **API access** - Integration with existing tools
3. **CSV exports** - Offline analysis
4. **Saved searches** - Monitoring specific queries
5. **Email alerts** - Proactive notifications

### Segment-Specific Differentiation

**Risk & Compliance**: Trend analysis, benchmarking, risk scores
**Legal**: Case similarity, precedent analysis, document management
**Investors**: Bulk screening, ESG scores, Companies House integration

---

## Go-to-Market Strategy by Segment

### Risk & Compliance (Q1-Q2 2025)

**Channels**:
- LinkedIn ads (target EHS/compliance job titles)
- Industry association partnerships (IOSH, IEMA, NEBOSH)
- Content marketing (blog posts on enforcement trends)
- Webinars (quarterly enforcement data reviews)

**Messaging**:
"Stop spending hours researching enforcement data. Get instant insights into industry trends, peer benchmarking, and regulatory risk - all in one platform."

### Legal (Q2-Q3 2025)

**Channels**:
- Legal publications (Health & Safety at Work magazine, solicitor journals)
- Conference sponsorship (Health & Safety Legal Conference)
- Direct outreach to regulatory defense firms
- Partnerships with expert witnesses

**Messaging**:
"Win more regulatory cases with data-driven precedent research. Find similar cases, calculate typical fines, and build stronger sentencing arguments in minutes, not hours."

### Investors (Q3-Q4 2025)

**Channels**:
- ESG conferences (Responsible Investor events)
- Private equity network events
- Bloomberg Terminal integration (app listing)
- Direct outreach to M&A teams

**Messaging**:
"De-risk your investments with comprehensive regulatory enforcement intelligence. Screen portfolios, monitor targets, and quantify ESG risk with the UK's most complete enforcement database."

---

## Related Documents

- [Strategic Roadmap](../ROADMAP.md)
- [Q1 2025 Plan](2025-Q1.md)
- [Prioritization Framework](prioritization-framework.md)
- [AI/ML Initiatives](ai-ml-initiatives.md)

---

**Created**: January 7, 2025
**Owner**: Product Strategy
**Review Date**: April 1, 2025
