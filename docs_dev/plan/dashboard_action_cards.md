# Dashboard Action Cards Design Document

## Overview

This document details the form and function of the Dashboard-Centric navigation approach using large, prominent action cards that serve as the primary navigation method for the EHS Enforcement application. Each card combines visual appeal, key metrics, and actionable navigation to create an intuitive, task-oriented user experience.

## Design Philosophy

**Dashboard as Command Center**: The dashboard serves as the central hub where users can see system status at a glance and quickly navigate to key functions through prominent action cards.

**Metrics-Driven Navigation**: Each card displays relevant statistics that help users understand current system state and decide which actions to take.

**Progressive Disclosure**: Cards show high-level information with the ability to drill down into detailed views.

## Card Layout Structure

### Grid System
- **Desktop**: 1x4 horizontal row (4 primary cards)
- **Tablet**: 2x2 grid (stacked responsively)
- **Mobile**: 1x4 vertical stack

### Card Dimensions
- **Desktop Width**: ~23% of container width (with 2% gaps)
- **Minimum Height**: 180px
- **Padding**: 20px internal padding (reduced for narrower cards)
- **Spacing**: 2% gap between cards horizontally
- **Border Radius**: 12px for modern, friendly appearance

## Primary Action Cards

### 1. Cases Management Card

**Visual Design:**
```
┌─────────────────────────────┐
│ 📁 ENFORCEMENT CASES        │
│                             │
│ 1,003 Total Cases           │
│ 0 Recent (Last 30 Days)     │
│ £0 Total Fines              │
│                             │
│ ┌─────────────┐             │
│ │ > Browse    │  [ADMIN]    │
│ │   Recent    │  > Add New  │
│ └─────────────┘     Case    │
│ ┌─────────────┐             │
│ │ > Search    │             │
│ │   Cases     │             │
│ └─────────────┘             │
└─────────────────────────────┘
```

**Functionality:**
- **Primary Metric**: Total number of enforcement cases in system
- **Secondary Metrics**:
  - Recent cases count (configurable time period)
  - Total fines amount from recent cases
  - Percentage change from previous period
- **Primary Actions**:
  - **Browse Recent**: Navigate to `/cases` with "recent" filter pre-applied (last 30 days, paginated)
  - **Search Cases**: Navigate to `/cases` with search interface activated
- **Admin-Only Actions**:
  - **Add New Case**: Navigate to `/cases/new` form (GitHub OAuth admins only)
- **Secondary Actions**:
  - **Export Data**: Quick CSV export of recent cases
- **Interactive Elements**:
  - Hover effects on action buttons
  - Loading states during data fetching
  - Real-time updates when cases are added/modified

**Data Sources:**
- `EhsEnforcement.Enforcement.list_cases!()` for totals
- Dashboard stats calculation for recent counts and fines
- Real-time updates via PubSub for live metrics

**Color Scheme:**
- **Primary**: Blue theme (`bg-blue-50`, `text-blue-700`, `border-blue-200`)
- **Accent**: Green for positive metrics
- **Buttons**: Indigo primary, gray secondary

### 2. Notices Management Card

**Visual Design:**
```
┌─────────────────────────────┐
│ 🔔 ENFORCEMENT NOTICES      │
│                             │
│ 0 Total Notices             │
│ 0 Recent (Last 30 Days)     │
│ 3 Compliance Required       │
│                             │
│ ┌─────────────┐             │
│ │ > Browse    │  [ADMIN]    │
│ │   Active    │  > Add New  │
│ └─────────────┘    Notice   │
│ ┌─────────────┐             │
│ │ > Search    │             │
│ │   Database  │             │
│ └─────────────┘             │
└─────────────────────────────┘
```

**Functionality:**
- **Primary Metric**: Total number of enforcement notices
- **Secondary Metrics**:
  - Recent notices count
  - Compliance status breakdown
  - Active vs. resolved notices
- **Primary Actions**:
  - **Browse Active**: Navigate to `/notices` with "active" filter pre-applied (non-complied notices, paginated)
  - **Search Database**: Navigate to `/notices` with advanced search interface
- **Admin-Only Actions**:
  - **Add New Notice**: Navigate to `/notices/new` form (GitHub OAuth admins only)
- **Secondary Actions**:
  - **Filter by Agency**: Dropdown with agency selection
- **Interactive Elements**:
  - Status indicator badges (pending, complied, overdue)
  - Agency filter dropdown
  - Sortable metrics display

**Data Sources:**
- `EhsEnforcement.Enforcement.list_notices!()` for totals
- Compliance status calculated from notice dates and responses
- Agency breakdowns for filtering

**Color Scheme:**
- **Primary**: Yellow/Orange theme (`bg-yellow-50`, `text-yellow-700`)
- **Status Indicators**: Red (overdue), Yellow (pending), Green (complied)
- **Buttons**: Orange primary, gray secondary

### 3. Offenders Database Card

**Visual Design:**
```
┌─────────────────────────────┐
│ 👥 OFFENDER DATABASE        │
│                             │
│ 245 Total Organizations     │
│ 12 Repeat Offenders (5%)    │
│ £2.3M Average Fine          │
│                             │
│ ┌─────────────┐             │
│ │ > Browse    │             │
│ │   Top 50    │             │
│ └─────────────┘             │
│ ┌─────────────┐             │
│ │ > Search    │             │
│ │   Offenders │             │
│ └─────────────┘             │
└─────────────────────────────┘
```

**Functionality:**
- **Primary Metric**: Total number of unique offenders in database
- **Secondary Metrics**:
  - Repeat offender count and percentage
  - Average fine amount
  - Industry distribution stats
- **Primary Actions**:
  - **Browse Top 50**: Navigate to `/offenders` with "highest fines" filter pre-applied (paginated, 50 max)
  - **Search Offenders**: Navigate to `/offenders` with advanced search and filter interface
- **Secondary Actions**:
  - **Industry Analysis**: Detailed breakdown by industry sectors
  - **Repeat Offender Report**: Specialized view for recurring violations
- **Note**: No create functionality - offenders are system-managed from case/notice data
- **Interactive Elements**:
  - Industry sector tags
  - Risk level indicators
  - Quick search autocomplete

**Data Sources:**
- `EhsEnforcement.Enforcement.list_offenders!()` for totals
- Calculated metrics for repeat offenders, averages
- Industry classification from offender data

**Color Scheme:**
- **Primary**: Purple theme (`bg-purple-50`, `text-purple-700`)
- **Risk Indicators**: Red (high risk), Yellow (medium), Green (low)
- **Buttons**: Purple primary, gray secondary

### 4. Reports & Analytics Card

**Visual Design:**
```
┌─────────────────────────────┐
│ 📊 REPORTS & ANALYTICS      │
│                             │
│ 5 Saved Reports             │
│ Last Export: 2 days ago     │
│ 1.2MB Data Available        │
│                             │
│ ┌─────────────┐             │
│ │ > Generate  │             │
│ │   Report    │             │
│ └─────────────┘             │
│ ┌─────────────┐             │
│ │ > Export    │             │
│ │   Data      │             │
│ └─────────────┘             │
└─────────────────────────────┘
```

**Functionality:**
- **Primary Metric**: Number of saved/scheduled reports
- **Secondary Metrics**:
  - Last export timestamp
  - Available data size
  - Report generation frequency stats
- **Primary Actions**:
  - **Generate Report**: Custom report builder with filtering options (prevents full data dumps)
  - **Export Data**: Multiple format options with mandatory date/filter constraints
- **Secondary Actions**:
  - **Scheduled Reports**: Automated report management
  - **Data Visualization**: Charts and graphs dashboard
- **Note**: No admin restrictions - all users can generate filtered reports and exports
- **Interactive Elements**:
  - Export format selector
  - Date range picker for reports
  - Template selection dropdown

**Data Sources:**
- System metadata for report statistics
- File system data for export sizes and timestamps
- User preferences for saved reports

**Color Scheme:**
- **Primary**: Green theme (`bg-green-50`, `text-green-700`)
- **Status Indicators**: Blue (scheduled), Green (completed), Gray (pending)
- **Buttons**: Green primary, gray secondary

## Authentication & Admin Privileges

### GitHub OAuth Integration
- **Admin Detection**: Users authenticated via GitHub OAuth with repository permissions
- **Privilege Levels**:
  - **Read-Only Users**: Browse, search, export functionality only
  - **Admin Users**: All read-only features + create new cases/notices
- **Visual Indicators**:
  - Admin-only buttons clearly marked with `[ADMIN]` label
  - Disabled state for non-admin users with tooltip explaining privilege requirement
- **Security**:
  - Server-side privilege checking on all create operations
  - Admin status cached in session with periodic re-validation

### Database Protection Strategy
- **No "View All" Operations**: All list views require filtering or pagination
- **Default Filters**: Recent items (30 days), active status, top results
- **Mandatory Pagination**: Maximum 50 records per request
- **Search Requirements**: Minimum search criteria for broad queries
- **Export Limits**: Time-bounded exports with maximum row limits

## Secondary Action Cards (Future Enhancement)

### 5. System Administration Card
- **User Management**: Role assignments, permissions
- **Agency Configuration**: Add/edit enforcement agencies
- **System Settings**: Application configuration
- **Audit Logs**: System activity tracking

### 6. Data Integration Card
- **Airtable Sync**: Real-time synchronization status
- **API Endpoints**: External system integrations
- **Import Tools**: Bulk data import utilities
- **Data Validation**: Quality checks and reports

## Card Interaction Patterns

### Hover States
- **Subtle elevation**: `shadow-md` to `shadow-lg`
- **Border highlight**: Themed border color intensifies
- **Button prominence**: Action buttons gain slight scale transform
- **Metric animation**: Numbers can animate/pulse for attention

### Loading States
- **Skeleton loaders**: Gray placeholder blocks for metrics
- **Disabled actions**: Buttons show loading spinner
- **Progress indicators**: For long-running operations
- **Error states**: Red border with error message overlay

### Responsive Behavior
- **Desktop (lg+)**: 1x4 horizontal row with full feature set
- **Tablet (md)**: 2x2 grid with condensed metrics
- **Mobile (sm)**: 1x4 vertical stack with simplified actions
- **Touch optimization**: Larger tap targets, gesture support
- **Horizontal scrolling**: On narrow screens, cards can scroll horizontally if needed

## Implementation Architecture

### Component Structure
```
lib/ehs_enforcement_web/
├── components/
│   ├── dashboard_action_card.ex      # Base reusable card component
│   ├── cases_action_card.ex          # Cases-specific card with admin detection
│   ├── notices_action_card.ex        # Notices-specific card with admin detection
│   ├── offenders_action_card.ex      # Offenders-specific card (read-only)
│   └── reports_action_card.ex        # Reports-specific card (no admin restrictions)
├── live/
│   └── dashboard_live.ex             # Main dashboard controller with auth context
└── plugs/
    └── admin_auth.ex                 # GitHub OAuth admin detection middleware
```

### Data Flow
1. **Dashboard Mount**: Load all card metrics in parallel + authenticate user privileges
2. **Admin Detection**: Check GitHub OAuth permissions and set admin context
3. **Real-time Updates**: PubSub subscriptions update metrics live
4. **Card Actions**: Navigate with pre-applied filters or trigger auth-protected forms
5. **Error Handling**: Graceful degradation with cached data + auth fallbacks

### Performance Considerations
- **Lazy Loading**: Cards load metrics independently
- **Filtered Queries**: All database operations use indexes and limits
- **Caching**: Expensive calculations cached with TTL + admin status cached
- **Optimistic Updates**: UI updates immediately, syncs in background
- **Debounced Interactions**: Prevent rapid-fire clicks
- **Database Protection**: No full table scans, mandatory filtering on large datasets

## Accessibility Features

### Keyboard Navigation
- **Tab Order**: Logical flow through cards and actions
- **Enter/Space**: Activate primary card actions
- **Arrow Keys**: Navigate between cards
- **Escape**: Close any opened overlays

### Screen Reader Support
- **ARIA Labels**: Descriptive labels for all interactive elements
- **Live Regions**: Announce metric updates
- **Semantic HTML**: Proper heading hierarchy and structure
- **Focus Management**: Clear focus indicators

### Visual Accessibility
- **High Contrast**: WCAG AA compliant color ratios
- **Large Touch Targets**: Minimum 44px for mobile
- **Clear Typography**: Readable fonts and sizing
- **Motion Preferences**: Respect `prefers-reduced-motion`

## Testing Strategy

### Unit Tests
- Card component rendering with various data states
- Metric calculation accuracy
- Action button functionality
- Error state handling

### Integration Tests
- Full dashboard loading and navigation flow
- Real-time updates and PubSub integration
- Cross-card data consistency
- Performance under load

### User Experience Tests
- A/B testing for card layouts and messaging
- Usability testing for task completion rates
- Accessibility testing with screen readers
- Mobile responsiveness testing

## Implementation Phases

The dashboard action cards implementation is broken down into 6 sequential phases, each designed to be completed in a single Claude Code session (2-4 hours) with full test coverage and git commits.

### Phase 1: Base Card Infrastructure (Foundation)
  **Duration**: ~3 hours | **Dependencies**: None | **Priority**: Critical

  **Deliverables**:
  - Create reusable `dashboard_action_card.ex` base component with slots for metrics, actions, and admin indicators
  - Implement 1x4 horizontal grid layout using Tailwind CSS with responsive breakpoints
  - Add card styling system (themes, hover states, loading states, error states)
  - Create comprehensive component tests covering all visual states and interactions

  **Files Created/Modified**:
  ```
  lib/ehs_enforcement_web/components/dashboard_action_card.ex
  lib/ehs_enforcement_web/live/dashboard_live.html.heex (layout update)
  test/ehs_enforcement_web/components/dashboard_action_card_test.exs
  ```

  **Test Coverage**:
  - Component rendering with various slot configurations
  - Responsive layout behavior across breakpoints
  - Theme application and visual state management
  - Accessibility compliance (ARIA labels, keyboard navigation)

  **Git Commit**: `feat: implement base dashboard action card infrastructure with 1x4 layout`

  ---

### Phase 2: Authentication & Authorization Framework
  **Duration**: ~4 hours | **Dependencies**: Phase 1 | **Priority**: Critical

  **Deliverables**:
  - GitHub OAuth integration plug with repository permission checking
  - Admin privilege detection middleware with session caching
  - User context assignment for LiveView components
  - Security middleware for protecting admin-only routes and actions

  **Files Created/Modified**:
  ```
  lib/ehs_enforcement_web/plugs/admin_auth.ex
  lib/ehs_enforcement_web/plugs/github_oauth.ex
  lib/ehs_enforcement_web/router.ex (pipeline updates)
  lib/ehs_enforcement_web/live/dashboard_live.ex (auth context)
  config/runtime.exs (OAuth configuration)
  test/ehs_enforcement_web/plugs/admin_auth_test.exs
  test/ehs_enforcement_web/plugs/github_oauth_test.exs
  ```

  **Test Coverage**:
  - OAuth authentication flow with GitHub API mocking
  - Admin privilege detection for repository contributors
  - Session management and cache behavior
  - Security middleware protection tests

  **Git Commit**: `feat: implement GitHub OAuth authentication with admin privilege detection`

  ---

### Phase 3: Cases Management Card (Complete Implementation)
**Duration**: ~3.5 hours | **Dependencies**: Phase 1, 2 | **Priority**: High

**Deliverables**:
- Complete cases action card with live metrics display
- "Browse Recent" action with 30-day filter and pagination
- "Search Cases" action with advanced search interface
- Admin-only "Add New Case" button with privilege checking

**Files Created/Modified**:
```
lib/ehs_enforcement_web/components/cases_action_card.ex
lib/ehs_enforcement_web/live/case_live/index.ex (filter updates)
lib/ehs_enforcement_web/live/dashboard_live.ex (cases card integration)
test/ehs_enforcement_web/components/cases_action_card_test.exs
test/ehs_enforcement_web/live/dashboard_cases_integration_test.exs
```

**Test Coverage**:
- Cases metrics calculation and real-time updates
- Filtered navigation with pagination limits
- Admin privilege enforcement for create actions
- Integration with existing case management system

**Git Commit**: `feat: implement cases management card with filtered navigation and admin controls`

---

### Phase 4: Notices Management Card (Complete Implementation)
**Duration**: ~3.5 hours | **Dependencies**: Phase 1, 2 | **Priority**: High

**Deliverables**:
- Complete notices action card with compliance metrics
- "Browse Active" action filtering non-complied notices
- "Search Database" action with advanced filtering
- Admin-only "Add New Notice" functionality

**Files Created/Modified**:
```
lib/ehs_enforcement_web/components/notices_action_card.ex
lib/ehs_enforcement_web/live/notice_live/index.ex (filter updates)
lib/ehs_enforcement_web/live/dashboard_live.ex (notices card integration)
test/ehs_enforcement_web/components/notices_action_card_test.exs
test/ehs_enforcement_web/live/dashboard_notices_integration_test.exs
```

**Test Coverage**:
- Notices metrics with compliance status calculations
- Active notice filtering and search functionality
- Admin create notice privilege enforcement
- Integration with existing notice management system

**Git Commit**: `feat: implement notices management card with compliance tracking and admin controls`

---

### Phase 5: Offenders Database Card (Read-Only Implementation)
**Duration**: ~3 hours | **Dependencies**: Phase 1 | **Priority**: Medium

**Deliverables**:
- Offenders action card with database statistics
- "Browse Top 50" action with highest fines filter
- "Search Offenders" with advanced search and industry filters
- Industry analysis and repeat offender metrics

**Files Created/Modified**:
```
lib/ehs_enforcement_web/components/offenders_action_card.ex
lib/ehs_enforcement_web/live/offender_live/index.ex (filter updates)
lib/ehs_enforcement_web/live/dashboard_live.ex (offenders card integration)
test/ehs_enforcement_web/components/offenders_action_card_test.exs
test/ehs_enforcement_web/live/dashboard_offenders_integration_test.exs
```

**Test Coverage**:
- Offender statistics calculation (repeat offenders, industry distribution)
- Top offenders filtering with database limits
- Advanced search functionality with industry categorization
- Read-only operations (no create functionality)

**Git Commit**: `feat: implement offenders database card with statistics and filtered browsing`

---

### Phase 6: Reports & Analytics Card (Open Access Implementation)
**Duration**: ~3 hours | **Dependencies**: Phase 1 | **Priority**: Medium

**Deliverables**:
- Reports action card with export statistics
- "Generate Report" with custom filtering and date constraints
- "Export Data" with multiple formats and mandatory filters
- Report template management and scheduling foundation

**Files Created/Modified**:
```
lib/ehs_enforcement_web/components/reports_action_card.ex
lib/ehs_enforcement_web/live/reports_live/index.ex (new)
lib/ehs_enforcement_web/controllers/export_controller.ex (enhanced)
lib/ehs_enforcement_web/live/dashboard_live.ex (reports card integration)
test/ehs_enforcement_web/components/reports_action_card_test.exs
test/ehs_enforcement_web/live/reports_live_test.exs
test/ehs_enforcement_web/controllers/export_controller_test.exs
```

**Test Coverage**:
- Report generation with filtering constraints
- Multi-format export functionality (CSV, Excel, JSON, PDF)
- Database protection through mandatory date/filter requirements
- Export file management and cleanup

**Git Commit**: `feat: implement reports and analytics card with filtered export capabilities`

---

## Phase Dependencies & Sequence

```
Phase 1 (Base Infrastructure)
    ├── Phase 2 (Authentication)
    │   ├── Phase 3 (Cases Card)
    │   └── Phase 4 (Notices Card)
    ├── Phase 5 (Offenders Card)
    └── Phase 6 (Reports Card)
```

**Critical Path**: Phases 1 → 2 → 3, 4 must be completed sequentially
**Parallel Development**: Phases 5 and 6 can be developed independently after Phase 1

## Session Planning Guidelines

### Pre-Session Preparation
- Review previous phase deliverables and test results
- Ensure development environment is clean with latest changes
- Verify database state and test data availability
- Check dependency versions and Phoenix/Ash framework compatibility

### Session Execution Pattern
1. **Analysis** (15 min): Review requirements and existing code
2. **Implementation** (2-2.5 hours): Component development and integration
3. **Testing** (30-45 min): Comprehensive test coverage
4. **Documentation** (15 min): Update code comments and documentation
5. **Git Commit** (10 min): Clean commit with descriptive message and summary

### Quality Gates
- **All tests pass**: Unit, integration, and component tests
- **Code quality**: Consistent with existing codebase patterns
- **Accessibility**: WCAG AA compliance verified
- **Performance**: Database queries optimized with proper indexing
- **Security**: Admin privileges properly enforced

---

*This phased approach ensures systematic delivery of the dashboard action cards with full test coverage, proper error handling, and maintainable code architecture.*
