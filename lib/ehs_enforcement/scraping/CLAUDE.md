# CLAUDE.md - EHS Enforcement Scraping Module

This file provides guidance to Claude Code when working with the scraping features of the EHS Enforcement application.

## 🏗️ Architecture Overview

This is the **scraping module** for the EHS Enforcement Phoenix/Ash application. It implements a unified, behavior-driven architecture for collecting enforcement data from UK regulatory agencies.

### **Current Module Structure (Post-Strategy Pattern Refactor Oct 2025)**:
```
lib/ehs_enforcement/scraping/
├── strategies/                  # Strategy pattern implementations (NEW)
│   ├── hse/
│   │   ├── case_strategy.ex    # HSE case scraping strategy
│   │   └── notice_strategy.ex  # HSE notice scraping strategy
│   ├── ea/
│   │   ├── case_strategy.ex    # EA case scraping strategy
│   │   └── notice_strategy.ex  # EA notice scraping strategy (future)
│   └── scraping_strategy.ex    # Strategy behavior definition
├── agencies/                    # Agency behavior implementations
│   ├── hse.ex                  # HSE (Health & Safety Executive) behavior
│   └── ea.ex                   # EA (Environment Agency) behavior
├── hse/                        # HSE scraping and processing
│   ├── case_scraper.ex         # HTTP scraping for HSE cases
│   ├── case_processor.ex       # Case processing + Ash integration
│   ├── notice_scraper.ex       # HTTP scraping for HSE notices
│   └── notice_processor.ex     # Notice processing + Ash integration
├── ea/                         # EA scraping and processing
│   ├── case_scraper.ex         # HTTP scraping for EA cases
│   ├── case_processor.ex       # EA case processing + Ash integration
│   └── historical_scraper.ex   # Historical EA data scraping
├── resources/                  # Shared scraping resources
│   ├── scrape_session.ex       # Scraping session tracking (Ash resource)
│   ├── processing_log.ex       # Unified processing logs (Ash resource)
│   ├── scrape_request.ex       # Request management
│   └── scraped_case.ex         # Legacy scraped case struct
├── agency_behavior.ex          # AgencyBehavior protocol definition
├── scrape_coordinator.ex       # Main coordination and entry point
└── rate_limiter.ex            # HTTP rate limiting for respectful scraping
```

## 🎯 Key Patterns & Conventions

### **1. Strategy Pattern (New Architecture - Oct 2025)**
The unified admin scraping interface uses strategy pattern for UI form configuration and validation:

```elixir
defmodule EhsEnforcement.Scraping.Strategies.ScrapingStrategy do
  @callback strategy_name() :: String.t()
  @callback default_params() :: map()
  @callback form_fields() :: list(map())
  @callback validate_params(map()) :: {:ok, map()} | {:error, String.t()}
end
```

**Key Benefits**:
- Single admin interface (`/admin/scrape`) for all agency/database combinations
- Dynamic form rendering based on selected strategy
- Type-safe parameter validation per strategy
- Extensible for new agencies without UI changes

**Available Strategies**:
- `EhsEnforcement.Scraping.Strategies.HSE.CaseStrategy` - HSE convictions/appeals
- `EhsEnforcement.Scraping.Strategies.HSE.NoticeStrategy` - HSE enforcement notices
- `EhsEnforcement.Scraping.Strategies.EA.CaseStrategy` - EA court cases
- `EhsEnforcement.Scraping.Strategies.EA.NoticeStrategy` - EA enforcement notices (planned)

### **2. Agency Behavior Pattern**
All agencies implement the `AgencyBehavior` protocol:
```elixir
@callback validate_params(keyword()) :: {:ok, map()} | {:error, term()}
@callback start_scraping(map(), map()) :: {:ok, term()} | {:error, term()}
@callback process_results(term()) :: term()
```

### **3. Module Responsibilities**
- **`scraping/strategies/`**: Strategy pattern implementations for UI form configuration (NEW)
- **`scraping/agencies/`**: Agency-specific behavior implementations and routing
- **`scraping/hse/` & `scraping/ea/`**: HTTP scraping, data processing, Ash resource creation
- **`scraping/resources/`**: Shared Ash resources for session tracking and logging
- **Helper modules in `lib/ehs_enforcement/agencies/`**: Data transformation and business logic

### **4. Ash Framework Usage**
⚠️ **CRITICAL**: This app uses Ash Framework patterns exclusively:
- **NEVER use Ecto directly**: Always use `Ash.create/2`, `Ash.update/2`, `Ash.read/2`
- **All data operations**: Go through Ash resources with proper actor context
- **Error handling**: Use Ash error patterns, not Ecto changesets

## 🚀 Common Development Tasks

### **Adding New Agency Support**
1. Create agency behavior: `scraping/agencies/new_agency.ex`
2. Implement scraper modules: `scraping/new_agency/case_scraper.ex`
3. Implement processor modules: `scraping/new_agency/case_processor.ex`
4. Add helpers: `lib/ehs_enforcement/agencies/new_agency/data_transformer.ex`
5. Update `scrape_coordinator.ex` routing

### **Extending Existing Agency Features**
- **HSE**: Add new databases beyond "convictions", "notices", "appeals"
- **EA**: Add new action types beyond `:court_case`, `:caution`, `:enforcement_notice`
- **Both**: Enhance error handling, add new data fields, improve matching logic

### **Working with Scraping Sessions**
```elixir
# Create session through ScrapeCoordinator
opts = [agency: :hse, start_page: 1, max_pages: 10, database: "convictions"]
{:ok, session} = ScrapeCoordinator.start_scraping_session(opts)

# Monitor progress via ScrapeSession resource
session = Ash.read_one!(ScrapeSession, filter: [session_id: session_id])
```

## 📊 Agency-Specific Details

### **HSE (Health and Safety Executive)**
- **Characteristics**: Page-based scraping, multiple databases, consecutive existing stop logic
- **URL Pattern**: `https://resources.hse.gov.uk/{database}/...`
- **Parameters**: `start_page`, `max_pages`, `database`
- **Databases**: "convictions", "notices", "appeals"
- **Rate Limiting**: 3-second pause between pages

### **EA (Environment Agency)**  
- **Characteristics**: Date-range scraping, action type filtering, single-request model
- **URL Pattern**: `https://environment.data.gov.uk/public-register/enforcement-action/...`
- **Parameters**: `date_from`, `date_to`, `action_types`
- **Action Types**: `:court_case`, `:caution`, `:enforcement_notice`
- **Special Features**: Company registration number matching, environmental impact data

## 🔧 Development Commands

### **Manual Scraping (IEx)**
```elixir
# HSE case scraping
opts = [agency: :hse, start_page: 1, max_pages: 5, database: "convictions"]
{:ok, session} = EhsEnforcement.Scraping.ScrapeCoordinator.start_scraping_session(opts)

# EA case scraping
opts = [agency: :environment_agency, date_from: ~D[2024-01-01], date_to: ~D[2024-12-31], action_types: [:court_case]]
{:ok, session} = EhsEnforcement.Scraping.ScrapeCoordinator.start_scraping_session(opts)

# Check session progress
session = Ash.read_one!(EhsEnforcement.Scraping.ScrapeSession, filter: [session_id: session_id])
```

### **Testing Commands**
```bash
# Run scraping-specific tests
mix test test/ehs_enforcement/scraping/

# Test specific agency
mix test test/ehs_enforcement/scraping/agencies/hse_test.exs
mix test test/ehs_enforcement/scraping/agencies/ea_test.exs

# Integration tests  
mix test test/ehs_enforcement/scraping/workflows/
```

## 🐛 Common Issues & Solutions

### **Rate Limiting Problems**
- **Issue**: HTTP requests failing due to rate limiting
- **Solution**: Adjust `pause_between_pages_ms` in scraping configuration
- **Location**: `EhsEnforcement.Configuration.ScrapingConfig` resource

### **Duplicate Detection**  
- **Issue**: Cases/notices being created as duplicates instead of updating existing
- **Solution**: Check offender matching logic in `agencies/{agency}/offender_matcher.ex`
- **Pattern**: Look for `regulator_id` uniqueness constraints

### **Session Tracking Issues**
- **Issue**: Progress not updating in UI during scraping
- **Solution**: Verify PubSub notifications in agency behavior implementations
- **Check**: Ash PubSub configuration and `ProcessingLog` creation

### **Memory Issues During Large Scraping**
- **Issue**: Memory usage grows during long scraping sessions  
- **Solution**: Process cases individually, not in large batches
- **Pattern**: Use `Enum.reduce` with immediate Ash resource creation, not `Enum.map`

## 📁 Related Files & Directories

### **Ash Resources** (Outside scraping module)
- `lib/ehs_enforcement/enforcement/case.ex` - Case Ash resource
- `lib/ehs_enforcement/enforcement/notice.ex` - Notice Ash resource  
- `lib/ehs_enforcement/enforcement/offender.ex` - Offender Ash resource

### **Agency Helpers** (Outside scraping module)
- `lib/ehs_enforcement/agencies/hse/data_transformer.ex` - HSE data transformation
- `lib/ehs_enforcement/agencies/hse/offender_matcher.ex` - HSE offender matching
- `lib/ehs_enforcement/agencies/ea/data_transformer.ex` - EA data transformation
- `lib/ehs_enforcement/agencies/ea/offender_matcher.ex` - EA offender matching

### **UI Integration**
- `lib/ehs_enforcement_web/live/admin/scrape_live.ex` - **Unified admin scraping interface** (NEW)
  - Single interface for all agencies and database types
  - Dynamic form rendering using strategy pattern
  - Real-time progress tracking via PubSub
  - Route: `/admin/scrape`
- `lib/ehs_enforcement_web/components/progress_component.ex` - Unified progress display

### **Configuration**
- `lib/ehs_enforcement/configuration/scraping_config.ex` - Scraping configuration management
- Database: `scraping_configs` table via Ash resource

## 🧪 Testing Patterns

### **Unit Tests**: Test individual scrapers and processors
```elixir  
defmodule EhsEnforcement.Scraping.Hse.CaseScraperTest do
  use ExUnit.Case
  # Test HTTP scraping with mocked responses
end
```

### **Integration Tests**: Test complete workflows
```elixir
defmodule EhsEnforcement.Scraping.Workflows.CaseScrapingTest do
  use EhsEnforcementWeb.ConnCase  
  # Test end-to-end scraping with database interactions
end
```

### **Behavior Tests**: Test agency behavior implementations
```elixir
defmodule EhsEnforcement.Scraping.Agencies.HseTest do
  use ExUnit.Case
  # Test AgencyBehavior protocol implementation
end
```

## 📚 Key Documentation

- **Architecture**: `/docs-dev/dev/docs/ARCHITECTURE.md` - Complete scraping architecture details
- **Main CLAUDE.md**: `/CLAUDE.md` - Project-wide Ash patterns and conventions
- **EA Notice Integration**: `/docs-dev/plan/EA-NOTICE-INTEGRATION.md` - Future EA notice scraping plan

## 🎖️ Development Principles

1. **Respectful Scraping**: Always implement proper rate limiting and error handling
2. **Unified Patterns**: Follow established agency behavior patterns for consistency
3. **Ash-First**: All data operations through Ash resources with proper actor context  
4. **Error Recovery**: Comprehensive error handling with session state preservation
5. **Real-time Feedback**: Progress tracking and UI updates via PubSub
6. **Testing**: Comprehensive unit and integration test coverage
7. **Documentation**: Update architecture docs when adding new features

## 📅 Recent Changes & Migration Notes

### **October 2025: Strategy Pattern Refactor (Phases 1-7)**
- **New unified admin interface** at `/admin/scrape` replaces separate agency/type interfaces
- **Strategy pattern** introduced for dynamic form configuration and validation
- **Parameterized routes removed**: `/admin/cases/scrape/:agency/:database` deprecated
- **Benefits**: Single interface, extensible architecture, improved maintainability
- **See**: `.claude/sessions/2025-10-26-refactor-strategy-pattern-plan.md` for complete refactor plan
- **Implementation**: 7 phases completed (Oct 21-28, 2025)

### **Adding New Scraping Strategies**
When adding a new agency or database type:
1. Create strategy module in `scraping/strategies/{agency}/{type}_strategy.ex`
2. Implement `ScrapingStrategy` behavior callbacks
3. Add strategy to `Admin.ScrapeLive.determine_strategy/2`
4. Update documentation (this file)
5. Add comprehensive tests

## ⚠️ Important Notes

- **Port Configuration**: This app runs on port 4002 (not 4000 like standard Phoenix apps)
- **Database**: Uses PostgreSQL with Ash resources (no direct Ecto)
- **Rate Limiting**: Essential for respectful scraping - never bypass or disable
- **Session Management**: Always use ScrapeCoordinator for session lifecycle
- **Cross-Agency**: Maintain consistency between HSE and EA implementations
- **Unified Interface**: Use `/admin/scrape` for all scraping operations (as of Oct 2025)

When working on scraping features, always consider the impact on both agencies and maintain the unified architecture patterns established in August 2025 and enhanced with strategy pattern in October 2025.