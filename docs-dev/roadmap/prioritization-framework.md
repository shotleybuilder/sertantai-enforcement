# Feature Prioritization Framework

**Last Updated**: January 2025

This framework provides a systematic approach to prioritizing features for the EHS Enforcement platform roadmap.

---

## Prioritization Formula

For each potential feature, score **1-5** on five dimensions:

```
Priority Score = (User Impact + Revenue Potential + Strategic Alignment)
                 × Technical Feasibility × Time to Market
```

**Result Range**: 3 (lowest) to 375 (highest)

---

## Scoring Dimensions

### 1. User Impact (1-5)

**5 - Critical**: Solves major pain point, users asking for it daily
**4 - High**: Significant improvement to existing workflow
**3 - Medium**: Nice-to-have, improves user experience
**2 - Low**: Minor convenience, rarely requested
**1 - Minimal**: No clear user demand

**Evaluation Questions**:
- How many users would benefit?
- How frequently would they use it?
- What's the pain level without it?
- Have users explicitly requested it?

---

### 2. Revenue Potential (1-5)

**5 - Direct monetization**: Required for paid tier, clear pricing premium
**4 - Strong enabler**: Increases conversion or reduces churn significantly
**3 - Moderate impact**: May influence some purchasing decisions
**2 - Indirect benefit**: Improves product perception, hard to quantify
**1 - No revenue impact**: Free tier feature, no monetization path

**Evaluation Questions**:
- Can we charge for this feature?
- Will it increase conversions (free → paid)?
- Will it reduce churn (retention)?
- Do competitors charge for similar features?

---

### 3. Strategic Alignment (1-5)

**5 - Core to strategy**: Essential for chosen user segment focus
**4 - Strong fit**: Directly supports segment goals
**3 - Moderate fit**: Beneficial but not central
**2 - Weak fit**: Tangential to current focus
**1 - Off-strategy**: Serves different segment or unclear fit

**Evaluation Questions**:
- Does this serve our primary user segment (Q1: Risk & Compliance)?
- Does it align with annual goals?
- Does it support our positioning ("compliance intelligence platform")?
- Would we promote this feature in marketing?

---

### 4. Technical Feasibility (1-5)

**5 - Trivial**: UI change only, no backend work, <1 week
**4 - Easy**: Uses existing infrastructure, well-understood, 1-2 weeks
**3 - Moderate**: Some new infrastructure, medium complexity, 3-4 weeks
**2 - Complex**: Significant new infrastructure, high complexity, 5-8 weeks
**1 - Very difficult**: Major technical unknowns, 3+ months

**Evaluation Questions**:
- Do we have the required infrastructure (Ash resources, APIs)?
- Is the implementation well-understood (clear technical design)?
- What's the estimated development time?
- What are the technical risks (new dependencies, complexity)?

---

### 5. Time to Market (1-5)

**5 - Immediate**: <1 week start to production
**4 - Fast**: 1-2 weeks
**3 - Medium**: 3-4 weeks
**2 - Slow**: 5-8 weeks
**1 - Very slow**: 9+ weeks

**Evaluation Questions**:
- How long until users can access this?
- Are there dependencies on other features?
- Do we need external services (Stripe, Companies House API)?
- What's the testing/QA burden?

---

## Example Prioritization

### Industry Filtering

- **User Impact**: 5 (compliance professionals need this for benchmarking)
- **Revenue Potential**: 4 (Professional tier feature, strong demand)
- **Strategic Alignment**: 5 (core to Risk & Compliance segment)
- **Technical Feasibility**: 5 (data exists in DB, just needs UI)
- **Time to Market**: 5 (<1 week, simple LiveView update)

**Score**: (5 + 4 + 5) × 5 × 5 = **350** (highest priority)

---

### AI-Powered Case Summarization

- **User Impact**: 4 (lawyers would love this, saves time reading)
- **Revenue Potential**: 5 (premium Enterprise feature, high perceived value)
- **Strategic Alignment**: 3 (Legal segment, but that's Q2-Q3 focus)
- **Technical Feasibility**: 2 (requires Bumblebee fine-tuning, complex)
- **Time to Market**: 1 (6-8 weeks minimum, needs training data)

**Score**: (4 + 5 + 3) × 2 × 1 = **24** (low priority for Q1)

---

## Top 20 Features (Q1 2025 Prioritization)

| Rank | Feature | User Impact | Revenue | Strategic | Feasibility | Time | **Score** |
|------|---------|-------------|---------|-----------|-------------|------|-----------|
| 1 | Industry filtering | 5 | 4 | 5 | 5 | 5 | **350** |
| 2 | Full-text search UI | 5 | 4 | 5 | 5 | 5 | **350** |
| 3 | Saved searches | 4 | 2 | 3 | 5 | 5 | **150** |
| 4 | API authentication | 4 | 5 | 5 | 4 | 4 | **280** |
| 5 | Trend charts | 5 | 3 | 5 | 4 | 4 | **208** |
| 6 | Legislation breakdown | 5 | 3 | 5 | 4 | 4 | **208** |
| 7 | Geographic analysis | 4 | 3 | 4 | 4 | 3 | **132** |
| 8 | JSON:API endpoints | 4 | 5 | 5 | 5 | 4 | **280** |
| 9 | Rate limiting | 3 | 5 | 5 | 4 | 4 | **208** |
| 10 | Subscription tiers | 3 | 5 | 5 | 3 | 3 | **117** |
| 11 | Custom report builder | 4 | 4 | 4 | 3 | 2 | **72** |
| 12 | Document storage | 4 | 4 | 3 | 4 | 3 | **132** |
| 13 | Companies House API | 4 | 5 | 5 | 4 | 3 | **168** |
| 14 | Risk scoring (basic) | 5 | 5 | 5 | 3 | 2 | **90** |
| 15 | Similar case finder | 4 | 4 | 4 | 3 | 2 | **72** |
| 16 | Webhook notifications | 3 | 5 | 5 | 3 | 3 | **117** |
| 17 | Timeline visualization | 4 | 3 | 3 | 4 | 4 | **160** |
| 18 | Email alerts | 4 | 3 | 4 | 4 | 4 | **176** |
| 19 | Bulk screening API | 3 | 5 | 4 | 3 | 2 | **72** |
| 20 | ESG risk scores | 5 | 5 | 5 | 2 | 1 | **30** |

---

## Decision Rules

### High Priority (Score 200+)
- **Ship in Q1**: Critical for segment MVP
- Fast-track development
- Prioritize even if other work in progress

### Medium Priority (Score 100-199)
- **Ship in Q2-Q3**: Important but not urgent
- Schedule after high-priority features
- Consider bundling with related features

### Low Priority (Score <100)
- **Backlog for Q4 or later**: Nice-to-have
- Wait for user demand validation
- May be deprioritized if better opportunities emerge

---

## Special Considerations

### Technical Debt Exception
Some low-priority features may be critical for technical health:
- Increasing test coverage (no direct user value, but reduces bugs)
- Performance optimizations (may not be user-visible)
- Security improvements (compliance requirements)

**Rule**: Technical debt scores separately on "Risk Mitigation" scale

---

### Quick Wins Bonus
Features that score high on **Feasibility + Time to Market** get a morale boost:
- Easy wins build momentum
- Demonstrate progress to stakeholders
- Provide early user feedback

**Rule**: If Score > 100 AND (Feasibility + Time) ≥ 9, ship ASAP

---

### Dependency Chains
Some features block others:
- API authentication must ship before paid API access
- Subscription system must ship before tier-gated features

**Rule**: Prioritize blockers first, even if standalone score is lower

---

## Continuous Prioritization Process

### Weekly
- Review new feature requests from users
- Score new ideas using this framework
- Update backlog rankings

### Monthly
- Re-score top 20 features (context changes)
- Adjust for new market intel
- Re-sequence roadmap if needed

### Quarterly
- Major roadmap review
- Validate scoring criteria still relevant
- Update user segment focus (may shift Strategic Alignment scores)

---

## Related Documents

- [Strategic Roadmap](../ROADMAP.md)
- [Q1 2025 Plan](2025-Q1.md)
- [User Segments](user-segments.md)

---

**Created**: January 7, 2025
**Owner**: Product Strategy
