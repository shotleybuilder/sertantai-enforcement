# AI/ML Initiatives Roadmap

**Last Updated**: January 2025

This document outlines the AI/ML capabilities roadmap for the EHS Enforcement platform, focusing on practical, high-value applications of machine learning.

---

## Strategic Approach

**Philosophy**: Start with **simple, proven ML techniques** before investing in complex deep learning. Prioritize features that:
1. Directly solve user pain points
2. Can be built with Elixir-native tools (Nx, Bumblebee, Scholar)
3. Provide measurable value (time savings, accuracy improvements)
4. Require minimal external dependencies

---

## AI/ML Technology Stack

### Core Libraries (Elixir-Native)
- **Nx** - Numerical computing (tensors, matrix operations)
- **Bumblebee** - Pre-trained transformer models (BERT, GPT-2, etc.)
- **Scholar** - Traditional ML algorithms (regression, clustering, classification)
- **Axon** - Neural network framework (if deep learning needed)

### PostgreSQL Extensions
- **pgvector** - Vector similarity search for embeddings
- **pg_trgm** - Fuzzy text search (already enabled)

### External Services (Optional)
- **OpenAI API** - For advanced GPT-4 features (if cost-effective)
- **Anthropic Claude API** - Alternative to OpenAI for summarization

---

## Roadmap by Quarter

### Q2 2025: Semantic Search (Feasibility: High)

**Feature**: Natural language search for cases

**User Story**: *"As a compliance professional, I want to search for 'fall from height incidents in construction' and get relevant results, even if those exact words aren't in the case description."*

**Implementation**:
- Use Bumblebee with pre-trained sentence-transformer model
- Generate embeddings for all case descriptions, breaches, legislation
- Store embeddings in PostgreSQL with pgvector extension
- Implement semantic search endpoint in Ash resource

**Technical Tasks**:
1. Add pgvector extension to PostgreSQL
2. Create `CaseEmbedding` table (case_id, embedding vector[384])
3. Load sentence-transformers model via Bumblebee (`{:hf, "sentence-transformers/all-MiniLM-L6-v2"}`)
4. Generate embeddings for existing cases (background job via AshOban)
5. Add semantic search action to Case resource
6. Create hybrid search (combine keyword + semantic)

**Success Metrics**:
- Search result relevance improved by 30% (user surveys)
- Average time to find relevant case reduced from 5 min to 2 min

**Estimated Effort**: 3-4 weeks
**Priority Score**: 72 (medium-high)

---

### Q3 2025: Risk Scoring (Feasibility: Medium)

**Feature**: Predict likelihood of repeat enforcement

**User Story**: *"As a risk manager, I want to see which companies in my sector are most likely to be prosecuted again, so I can benchmark our risk profile."*

**Implementation**:
- Train logistic regression model on historical data
- Features: industry, company size (proxy), previous enforcement count, fine amounts, time since last enforcement
- Output: Risk score 0-100 (higher = more likely to reoffend)

**Technical Tasks**:
1. Feature engineering (extract company attributes from Offender resource)
2. Create training dataset (offenders with 2+ cases = positive examples)
3. Train model using Scholar (`Scholar.Linear.LogisticRegression`)
4. Save model coefficients in database or ETS table
5. Add `risk_score` calculation to Offender resource
6. Display risk score on offender detail pages

**Success Metrics**:
- Model accuracy: 70%+ on test set (predict reoffending within 12 months)
- User adoption: 50% of users filtering by risk score within 3 months

**Estimated Effort**: 4-5 weeks
**Priority Score**: 90 (medium)

---

### Q3 2025: Duplicate Detection Enhancement (Feasibility: Medium)

**Feature**: ML-powered company name matching

**User Story**: *"As a data quality engineer, I want the system to automatically detect when 'ABC Ltd' and 'ABC Limited' are the same company, even with typos."*

**Implementation**:
- Enhance existing fuzzy matching with learned similarity model
- Train binary classifier: "Are these two names the same company?"
- Features: Levenshtein distance, Jaro-Winkler similarity, token overlap, postcode match, industry match

**Technical Tasks**:
1. Create labeled training data (manual review of 500 offender pairs)
2. Extract features using existing utility functions
3. Train random forest classifier (Scholar)
4. Integrate with `Offender.find_or_create_offender/1` logic
5. Add confidence threshold (only auto-merge if >95% confident)

**Success Metrics**:
- Duplicate rate reduced by 50% (fewer "ACME Ltd" vs "ACME Limited" duplicates)
- False positive rate <1% (avoid merging different companies)

**Estimated Effort**: 3-4 weeks
**Priority Score**: 72 (medium-high)

---

### Q4 2025: Trend Prediction (Feasibility: Medium)

**Feature**: Forecast enforcement activity by agency and sector

**User Story**: *"As a compliance director, I want to know if HSE prosecutions in my industry are likely to increase next quarter, so I can allocate resources proactively."*

**Implementation**:
- Time-series forecasting using historical case counts
- Predict monthly case counts 3-6 months ahead
- Break down by agency, industry, legislation type

**Technical Tasks**:
1. Extract time-series data (monthly case counts by agency/industry)
2. Implement ARIMA or exponential smoothing (Scholar or Nx)
3. Train models on 3+ years of historical data
4. Generate forecasts via background job (monthly)
5. Display forecast charts on analytics dashboard
6. Add confidence intervals (show uncertainty)

**Success Metrics**:
- Forecast accuracy: MAPE <20% (Mean Absolute Percentage Error)
- User engagement: 30%+ of users viewing forecast charts

**Estimated Effort**: 5-6 weeks
**Priority Score**: 90 (medium)

---

### 2026: Advanced Features (Feasibility: Low-Medium)

#### Automated Case Summarization
- Use Bumblebee GPT-2 or call OpenAI API
- Generate 1-paragraph summaries of long case descriptions
- Estimated effort: 6-8 weeks
- Priority: Low (Q1 2026)

#### Chatbot Q&A (RAG Pattern)
- Answer questions like "What's the average fine for RIDDOR violations?"
- Use semantic search + GPT prompt engineering
- Estimated effort: 8-10 weeks
- Priority: Medium (Q2 2026)

#### Legislation Classification
- Auto-categorize cases by breach type (procedural, substantive, etc.)
- Fine-tune BERT classifier
- Estimated effort: 6-8 weeks
- Priority: Low (Q3 2026)

#### Compliance Assistant
- Proactive recommendations based on company profile
- "Companies like yours were recently prosecuted for X, you should review Y"
- Estimated effort: 10-12 weeks
- Priority: High (Q4 2026)

---

## AI/ML Infrastructure Requirements

### Computational Resources
- **Current**: Phoenix app runs on 2-4 CPU cores, 4-8GB RAM
- **With ML**: Need 4-8 CPU cores, 16-32GB RAM (for embedding generation)
- **GPU**: Not required (Bumblebee models run on CPU for inference)

### Storage Requirements
- **Embeddings**: ~1KB per case × 100K cases = 100MB (trivial)
- **Models**: Pre-trained models ~100MB each (sentence-transformers)
- **Total**: <1GB additional storage

### Performance Impact
- **Embedding generation**: 5-10ms per case (batch process, not real-time)
- **Semantic search**: 20-50ms query latency (acceptable for <1M records)
- **Risk scoring**: <1ms per offender (simple linear model)

---

## Data Quality Requirements

### Labeled Training Data
- **Duplicate detection**: 500 offender pairs (same/different) - Manual labeling required
- **Risk scoring**: Historical data already labeled (reoffending = implicit label)
- **Sentiment analysis**: Not applicable (enforcement data is factual)

### Feature Engineering
- Need to extract structured features from text:
  - Company size (proxy from fine amounts, number of cases)
  - Industry classification (SIC codes already available)
  - Geographic region (postcode → region mapping)

---

## Evaluation Metrics

### Model Performance
- **Semantic search**: Precision@10, Recall@10, nDCG (user relevance surveys)
- **Risk scoring**: AUC-ROC, Precision/Recall, Calibration plots
- **Duplicate detection**: Precision (avoid false merges), Recall (catch all duplicates)
- **Trend prediction**: MAPE, RMSE, directional accuracy

### Business Metrics
- **User adoption**: % of users using ML-powered features
- **Time savings**: Reduction in search time, research time
- **Accuracy improvements**: Fewer user corrections, better decision-making

---

## Risks & Mitigations

### Risk: ML models don't improve accuracy
**Mitigation**: Start with baseline (current system), A/B test ML vs. non-ML
**Contingency**: Keep existing non-ML fallback if model underperforms

### Risk: Computational costs too high
**Mitigation**: Use lightweight models (sentence-transformers, not GPT-4)
**Contingency**: Batch processing instead of real-time inference

### Risk: Insufficient training data
**Mitigation**: Use transfer learning (pre-trained models)
**Contingency**: Start with unsupervised methods (embeddings, clustering)

### Risk: User distrust of "black box" AI
**Mitigation**: Provide explainability (show why case is similar, which features drove risk score)
**Contingency**: Make ML features opt-in, not forced

---

## Related Documents

- [Strategic Roadmap](../ROADMAP.md)
- [User Segments](user-segments.md)
- [Prioritization Framework](prioritization-framework.md)

---

**Created**: January 7, 2025
**Owner**: Data Science / Engineering
**Review Date**: July 1, 2025 (Q3 Planning)
