# Developer Documentation

This directory contains all developer-focused documentation for the EHS Enforcement application.

## Structure Overview

```
docs_dev/
├── README.md                          # This file - dev docs overview
├── DOCS_PLAN.md                      # Documentation automation plan
├── admin_guides/                      # Admin interface guides
│   ├── configuration_management.md   # /admin/config guide
│   ├── case_scraping.md              # /admin/cases/scrape guide
│   ├── notice_scraping.md            # /admin/notices/scrape guide
│   ├── scraping_overview.md          # /admin/scraping guide
│   ├── cases.md                      # General case admin guide
│   └── hse_cases.md                  # HSE-specific admin guide
├── exdoc/                            # Generated API documentation
│   ├── index.html                    # Main ExDoc entry point
│   ├── api-reference.html            # Module reference
│   ├── search.html                   # Documentation search
│   └── [150+ module documentation files]
├── plan/                             # Planning and architecture docs
│   ├── IMPLEMENTATION_PLAN.md
│   ├── PHASE_3_LIVEVIEW_UI_PLAN.md
│   └── [5 other planning documents]
└── [15 technical documentation files] # Architecture, deployment, schemas
```

## Documentation Categories

### Admin Guides (`/admin_guides/`)
Comprehensive guides for all administrative interfaces:
- **Configuration Management**: System settings and feature flags
- **Case Scraping**: Manual HSE prosecution case collection
- **Notice Scraping**: Manual HSE enforcement notice collection  
- **Scraping Overview**: Monitoring and analytics dashboard
- **General Admin**: Case management and system administration

### API Documentation (`/exdoc/`)
Generated ExDoc documentation covering:
- **Enforcement Domain**: Case, Notice, Offender, and Agency resources
- **Scraping System**: HSE data collection and processing modules
- **Integration & Sync**: Airtable and external system integrations
- **Configuration**: System configuration and feature management
- **Web Interface**: Phoenix LiveView controllers and components
- **Authentication**: User accounts and access control
- **Utilities**: Logging, telemetry, and helper modules

### Technical Documentation
- **Architecture Analysis**: System design and module structure
- **Deployment Guides**: Production deployment procedures
- **Database Documentation**: Schema design and migration guides
- **Integration Guides**: External system integration patterns
- **Development Workflows**: Development tools and procedures

### Planning Documentation (`/plan/`)
- **Implementation Plans**: Feature development roadmaps
- **UI Design Plans**: LiveView interface specifications
- **Architecture Decisions**: Technical design choices and rationale

## Generated API Documentation Stats

ExDoc successfully generated documentation for **150+ modules** including:

- **30+ Enforcement Domain modules** (Cases, Notices, Offenders, Agencies)
- **25+ Scraping System modules** (HSE scrapers, processors, coordinators)
- **15+ Integration modules** (Airtable client, sync workers)
- **20+ Web Interface modules** (LiveViews, components, controllers)
- **15+ Configuration modules** (Settings, feature flags, validation)
- **10+ Authentication modules** (Users, tokens, identities)
- **35+ Utility modules** (Logging, telemetry, error handling)

## Key Features of Generated Documentation

### Module Organization
- **Grouped by Domain**: Related modules organized into logical categories
- **Cross-Referenced**: Links between related modules and functions
- **Searchable**: Full-text search across all documentation
- **Responsive**: Mobile-friendly documentation interface

### Documentation Quality
- **@moduledoc Coverage**: Module-level documentation for most modules
- **@doc Coverage**: Function-level documentation where available
- **Type Specifications**: @spec documentation for function signatures
- **Examples**: Code examples in module documentation

### Interactive Features
- **Dark/Light Theme**: Automatic theme detection and manual toggle
- **Sidebar Navigation**: Collapsible module navigation
- **Search Functionality**: Quick search across all modules and functions
- **Mobile Responsive**: Works well on mobile devices

## Accessing the Documentation

### Local Development
1. **View in Browser**: Open `docs_dev/exdoc/index.html` in web browser
2. **Regenerate**: Run `mix docs` to update documentation
3. **Custom Output**: Documentation configured to output to `docs_dev/exdoc/`

### Automated Generation
The `DOCS_PLAN.md` file contains scripts for:
- **CI/CD Integration**: GitHub Actions workflow for automatic generation
- **Development Scripts**: Local scripts for documentation updates
- **Deployment Automation**: Automated publishing workflows

## Documentation Maintenance

### Keeping Documentation Current
1. **Add @moduledoc**: Document new modules with purpose and usage
2. **Add @doc**: Document public functions with parameters and return values
3. **Include Examples**: Add @doc examples for complex functions
4. **Update README**: Keep this overview current as structure evolves

### Quality Improvements
1. **Fix Warnings**: Address ExDoc warnings about missing references
2. **Add Type Specs**: Include @spec for better documentation
3. **Cross-Reference**: Link related modules and functions
4. **Add Guides**: Create additional guides for complex workflows

This developer documentation provides comprehensive coverage of the EHS Enforcement application's codebase, administrative interfaces, and technical architecture.