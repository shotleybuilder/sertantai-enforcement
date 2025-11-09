# EHS Enforcement: Product Roadmap

**Last Updated**: January 2025
**Review Cadence**: Quarterly (Q1, Q2, Q3, Q4)
**Primary Focus**: Risk & Compliance Professionals
**Vision**: The UK's leading enforcement data platform for compliance professionals

---

## Table of Contents

1. [Strategic Direction](#strategic-direction)
2. [User Segments](#user-segments)
3. [Current State](#current-state)
4. [2025 Roadmap](#2025-roadmap)
5. [Long-Term Vision](#long-term-vision)
6. [Monetization Strategy](#monetization-strategy)
7. [Success Metrics](#success-metrics)

---

## Strategic Direction

### Mission Statement

To provide comprehensive, actionable regulatory enforcement intelligence that helps organizations understand compliance risks, benchmark against peers, and make data-driven decisions about health, safety, and environmental compliance.

### Target Market (2025)

**Primary Focus: Risk & Compliance Professionals**
- In-house EHS/compliance managers
- Compliance consulting firms
- Risk assessment professionals
- Industry associations

**Why This Segment First:**
- Fastest time-to-value with existing data structure
- Clear willingness to pay for compliance intelligence
- Data structure already supports industry benchmarking
- Strong product-market fit validation from early conversations

**Future Segments:**
- Legal & Law Firms (Q3-Q4 2025)
- Investors & Financial Institutions (2026)

### Core Value Propositions

1. **Comprehensive Data Coverage**: HSE, EA, and future UK agencies (ONR, ORR, SEPA, NRW)
2. **Industry Benchmarking**: Compare enforcement patterns across sectors and competitors
3. **Real-Time Intelligence**: Automated scraping with daily updates
4. **Actionable Insights**: Trend analysis, risk scoring, and predictive analytics
5. **Developer-Friendly**: RESTful API (JSON:API) for integration with compliance systems

---

## User Segments

See [roadmap/user-segments.md](roadmap/user-segments.md) for detailed analysis of:
- Risk & Compliance Professionals
- Legal & Law Firms
- Investors & Financial Institutions

Each segment has:
- Use cases and pain points
- Feature requirements
- Gap analysis (current vs. needed capabilities)
- Implementation complexity assessment

---

## Current State

### What We Have (January 2025)

**Data Infrastructure** ⭐⭐⭐⭐⭐
- HSE cases, notices, appeals (automated scraping)
- EA court cases and enforcement data
- 100K+ records with sophisticated deduplication
- PostgreSQL with pg_trgm full-text search
- Materialized metrics for sub-second dashboard performance

**User Interface** ⭐⭐⭐
- Public dashboard at https://legal.sertantai.com
- Case/notice browsing with basic filtering
- CSV exports (basic, detailed, Excel formats)
- Admin scraping interface with real-time progress
- Mobile-responsive design

**Technical Foundation** ⭐⭐⭐⭐⭐
- Phoenix LiveView for real-time UI
- Ash Framework for declarative data modeling
- AshOban for background jobs
- Ash JSON:API ready (not exposed publicly)
- Ash Authentication (GitHub OAuth)
- Docker deployment with CI/CD

**What's Missing** ❌
- Industry/sector filtering in UI (data exists, no UI)
- Trend analysis and time-series charts
- Advanced search with full-text
- API authentication (API keys)
- Saved searches and user preferences
- Risk scoring and predictive analytics
- Companies House integration
- Subscription/payment system

### Gap Analysis Summary

| Capability | Current | Risk & Compliance | Legal | Investors |
|------------|---------|-------------------|-------|-----------|
| Data Collection | 95% | ✅ | ✅ | ✅ |
| Search & Filtering | 60% | 🔶 Medium Gap | 🔶 Medium Gap | 🔶 Medium Gap |
| Analytics & Reporting | 30% | 🔴 Large Gap | 🔴 Large Gap | 🔴 Large Gap |
| API Access | 20% | 🔴 Large Gap | 🔶 Medium Gap | 🔴 Large Gap |
| Risk Scoring | 0% | 🔴 Large Gap | 🔶 Medium Gap | 🔴 Large Gap |

**Legend**: ✅ Complete, 🔶 Medium Gap, 🔴 Large Gap

---

## 2025 Roadmap

### Q1 2025 (Jan-Mar): Foundation & Quick Wins

**Theme**: Ship features that provide immediate value to Risk & Compliance professionals

**Detailed Plan**: [roadmap/2025-Q1.md](roadmap/2025-Q1.md)

**Month 1 (January): Quick Wins**
- ✅ Industry/sector filtering UI (SIC codes, EA sectors)
- ✅ Full-text search interface (activate pg_trgm)
- ✅ Saved searches (user preferences)
- ✅ API authentication infrastructure (API keys)

**Month 2 (February): Analytics Foundation**
- Time-series trend analysis (month-over-month, year-over-year)
- Legislation breakdown analysis (most violated regulations)
- Geographic analysis (by region, local authority)
- ApexCharts integration for visualizations

**Month 3 (March): API & Monetization**
- Expose JSON:API endpoints publicly
- Implement rate limiting (via Ash Rate Limiter)
- Design subscription tiers (Free/Pro/Business/Enterprise)
- Custom report builder (saved filters → scheduled exports)

**Success Metrics**:
- 10 beta users signed up
- 1,000+ API requests/month
- NPS score of 40+
- Test coverage 80%+

---

### Q2 2025 (Apr-Jun): Legal Professional Features

**Theme**: Expand to legal & law firm use cases

**Key Features**:
- Similar case finder (semantic search via Nx/Bumblebee)
- Document storage (PDF uploads for notices/judgments)
- Case timeline visualization (offender enforcement history)
- Precedent analysis (fine ranges by breach type)
- Advanced search syntax (Boolean operators, proximity search)
- Client portfolio monitoring (watchlist specific offenders)

**Monetization**:
- Launch paid tiers (Professional £49/month, Business £199/month)
- Stripe integration for billing
- Usage tracking and quota enforcement

**Success Metrics**:
- 50 paying customers
- £2,500/month MRR
- 10,000+ API requests/month

---

### Q3 2025 (Jul-Sep): Investor Features & AI/ML

**Theme**: Add due diligence capabilities and AI-powered insights

**Key Features**:
- Companies House API integration (director linkage, corporate structure)
- Basic risk scoring (recidivism prediction, industry benchmarks)
- Bulk screening API (check hundreds of companies)
- Webhook notifications (alert on new enforcement)
- ESG risk scores (environmental/safety record quantification)
- Semantic search (natural language queries)

**AI/ML Infrastructure**:
- Nx/Bumblebee for embeddings
- pgvector PostgreSQL extension
- Scholar for ML algorithms (logistic regression, random forests)

**Success Metrics**:
- 100 paying customers
- £5,000/month MRR
- 50,000+ API requests/month
- 5 Enterprise customers

---

### Q4 2025 (Oct-Dec): Scale & Polish

**Theme**: Optimize for growth and operational excellence

**Key Features**:
- Mobile apps (iOS/Android) - React Native or Flutter
- Advanced predictive analytics (enforcement trend forecasting)
- White-label reports (enterprise custom branding)
- Multi-user organizations (team collaboration)
- Audit logging (compliance with SOC2/ISO27001)
- International expansion planning (EU agencies research)

**Infrastructure**:
- Performance optimization (sub-100ms API responses)
- Horizontal scaling (multi-region deployment)
- Advanced monitoring (Datadog/NewRelic)
- Security audit (penetration testing)

**Success Metrics**:
- 250 paying customers
- £15,000/month MRR
- 250,000+ API requests/month
- 15 Enterprise customers
- 95%+ uptime SLA

---

## Long-Term Vision (2026-2027)

### Year 2 (2026): Market Leader

**Q1-Q2 2026: International Expansion**
- EU regulatory agencies (European Commission enforcement databases)
- US agencies (OSHA, EPA, FDA enforcement data)
- Multi-jurisdiction comparative analysis
- Currency handling (USD, EUR, GBP fines)

**Q3-Q4 2026: Advanced AI Platform**
- GPT-4 powered chatbot (answer compliance questions)
- Automated compliance risk reports (monthly summaries)
- Predictive enforcement targeting (which companies will be investigated next)
- Legislative change prediction (identify patterns leading to new regulations)

**Revenue Target**: £500K ARR (Annual Recurring Revenue)

### Year 3 (2027): Enterprise Platform

**Features**:
- Multi-tenancy with full org isolation
- SSO integration (SAML, LDAP)
- Custom data connectors (ingest client's internal incident data)
- AI-powered compliance assistant (proactive recommendations)
- Compliance workflow automation (remediation tracking)

**Revenue Target**: £2M ARR

---

## Monetization Strategy

### Pricing Tiers (Launching Q2 2025)

#### Free Tier (Public Access)
- Browse cases, notices, offenders
- Basic filtering (agency, date range)
- CSV export (100 rows/month)
- No saved searches
- No API access

**Target**: Marketing/lead generation

#### Professional Tier (£49/month)
- Unlimited CSV exports
- Saved searches (10 saved searches)
- Advanced filtering (industry, legislation, geographic)
- Trend charts
- Email support
- API: 1,000 requests/month

**Target**: Individual compliance professionals, small consulting firms

#### Business Tier (£199/month)
- Everything in Professional
- Custom report builder
- API: 10,000 requests/month
- Webhook notifications
- Scheduled exports (daily/weekly/monthly)
- Risk scoring (basic)
- Priority support
- Multi-user (up to 5 users)

**Target**: Medium-sized companies, consulting firms with teams

#### Enterprise Tier (Custom Pricing, from £1,500/month)
- Everything in Business
- Unlimited API access
- White-label reports
- Companies House integration
- ESG risk scores
- Dedicated account manager
- SLA guarantees (99.9% uptime)
- Bulk screening (thousands of companies)
- SSO integration
- Custom integrations

**Target**: Large corporations, financial institutions, law firms

### Revenue Projections (Conservative)

**Year 1 (2025)**:
- Q1: 0 paid users (beta testing)
- Q2: 10 Professional, 2 Business = £690/month
- Q3: 30 Professional, 8 Business, 2 Enterprise = £6,062/month
- Q4: 60 Professional, 15 Business, 5 Enterprise = £13,425/month
- **Total Year 1**: £73,062 ARR

**Year 2 (2026)**:
- Professional: 200 users × £49 = £9,800/month
- Business: 50 users × £199 = £9,950/month
- Enterprise: 15 customers × £2,000 avg = £30,000/month
- **Total Year 2**: £597,000 ARR

**Year 3 (2027)**:
- Professional: 500 users × £49 = £24,500/month
- Business: 150 users × £199 = £29,850/month
- Enterprise: 40 customers × £3,000 avg = £120,000/month
- **Total Year 3**: £2,092,200 ARR

---

## Success Metrics

### North Star Metric
**Monthly Recurring Revenue (MRR)** - Primary indicator of business health

### Supporting Metrics

**Product Metrics (Q1 2025)**:
- Active users (monthly unique visitors)
- API requests per month
- Search queries per user
- CSV exports per month
- Saved search usage rate

**User Acquisition (Q2 2025+)**:
- New signups per month
- Conversion rate (free → paid)
- Customer Acquisition Cost (CAC)
- Churn rate
- Net Revenue Retention

**Product Quality**:
- Test coverage (target: 80%+)
- API response time (p95 < 500ms)
- Uptime (target: 99.5% → 99.9%)
- Bug resolution time (critical < 4 hours)

**User Satisfaction**:
- Net Promoter Score (NPS) (target: 40+ in 2025, 60+ in 2026)
- Customer Support CSAT (target: 90%+)
- Feature request voting (identify high-demand features)

---

## Prioritization Framework

See [roadmap/prioritization-framework.md](roadmap/prioritization-framework.md) for detailed methodology.

**Quick Reference**:

For each feature, score 1-5 on:
1. **User Impact** (demand/pain point severity)
2. **Revenue Potential** (direct monetization opportunity)
3. **Technical Feasibility** (implementation complexity)
4. **Time to Market** (speed to ship)
5. **Strategic Alignment** (fit with chosen user segment)

**Formula**:
```
Priority Score = (User Impact + Revenue Potential + Strategic Alignment)
                 × Technical Feasibility × Time to Market
```

Higher score = higher priority

---

## Roadmap Maintenance

### Monthly Review (First Monday)
- Review open GitHub issues by priority
- Update ROADMAP.md with progress
- Add new ideas to backlog
- Close completed items

### Quarterly Review (Start of Q1, Q2, Q3, Q4)
- Review previous quarter (shipped vs. slipped)
- Update user segment priorities
- Technical debt assessment
- Create next quarterly plan (e.g., `roadmap/2025-Q2.md`)

### Annual Review (December)
- Year in review (achievements, lessons learned)
- Strategy refresh (market analysis, competitive landscape)
- User feedback synthesis (surveys, interviews)
- Set annual goals (revenue, user growth, features)

---

## Roadmap Tracking

### GitHub Integration

**Strategic Planning**: This document (ROADMAP.md) is the source of truth

**Tactical Execution**: GitHub Issues with labels:
- `type: bug` (red) - Functional issues
- `type: feature` (green) - New capabilities
- `type: strategic` (purple) - Major roadmap initiatives
- `segment: risk-compliance` (blue) - Risk & compliance features
- `segment: legal` (blue) - Legal features
- `segment: investors` (blue) - Investor features
- `priority: critical/high/medium/low` (red/orange/yellow/green)

**Issue Templates**:
- `.github/ISSUE_TEMPLATE/feature_request.md` - Tactical features
- `.github/ISSUE_TEMPLATE/strategic_initiative.md` - Major initiatives
- `.github/ISSUE_TEMPLATE/bug_report.md` - Bugs

---

## Current Focus (Q1 2025)

**Primary Goal**: Ship 3 quick wins to validate Risk & Compliance segment

**In Progress**:
1. Industry/sector filtering UI (targeting week of Jan 13)
2. Full-text search interface (targeting week of Jan 20)
3. Saved searches (targeting week of Jan 27)

**Up Next**:
- API authentication infrastructure
- Trend analysis charts (ApexCharts)
- Legislation breakdown reports

**Blockers/Risks**:
- None currently

---

## Related Documents

- [2025 Q1 Detailed Plan](roadmap/2025-Q1.md)
- [User Segments Analysis](roadmap/user-segments.md)
- [Prioritization Framework](roadmap/prioritization-framework.md)
- [AI/ML Initiatives](roadmap/ai-ml-initiatives.md)
- [API Strategy](plans/api-strategy.md)
- [Development Workflow](DEVELOPMENT_WORKFLOW.md)
- [Testing Guide](TESTING_GUIDE.md)

---

## Contact & Feedback

For questions about the roadmap or to suggest features:
- Create a GitHub issue with `type: strategic` label
- Email: [your-email@example.com]
- Join discussions in GitHub Discussions (if enabled)

---

**Last Updated**: January 7, 2025
**Next Review**: April 1, 2025 (Q2 Planning)
