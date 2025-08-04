# HSE Case Administration Guide

## Overview

This guide covers administrative operations for managing HSE enforcement cases in the EHS Enforcement system. The system collects, processes, and manages enforcement data from the Health and Safety Executive (HSE).

## Case Data Sources

### HSE Website Scraping
The system automatically scrapes enforcement data from two main HSE sources:

- **Prosecution Cases**: Legal proceedings and court outcomes
- **Enforcement Notices**: Improvement and prohibition notices issued

### Data Collection Process
1. Automated scraping runs collect new cases and notices
2. Data is processed and structured using Ash resources
3. Information is synchronized with Airtable for external access
4. Local PostgreSQL database provides caching and backup

## Case Management Operations

### Viewing Cases
- Access case listings through the Phoenix LiveView interface
- Filter cases by date range, agency, or enforcement type
- Search cases by company name, location, or violation details

### Case Data Structure
Each case contains:
- **Basic Information**: Case ID, date, location, company details
- **Enforcement Details**: Violation type, severity, regulatory basis
- **Outcomes**: Fines, notices issued, court decisions
- **Administrative**: Processing status, data source, sync status

### Data Synchronization

#### Airtable Integration
- Primary data store for external team access
- Automatic sync after case processing
- Manual sync available for troubleshooting
- API key required: `AT_UK_E_API_KEY` environment variable

#### Database Operations
```bash
# Check database status
mix ecto.migrations

# Reset database (development only)
mix ecto.reset

# Run Ash migrations
mix ash.migrate
```

## Administrative Tasks

### Starting Data Collection
```bash
# Start the Phoenix server
mix phx.server

# Run interactive shell for debugging
iex -S mix phx.server
```

### Monitoring Collection Status
- Check server logs for scraping errors
- Monitor Airtable sync status in admin interface
- Review data quality through case listings

### Troubleshooting Common Issues

#### Scraping Failures
1. Check HSE website availability
2. Verify scraping client configuration
3. Review error logs for parsing issues
4. Manually trigger collection if needed

#### Database Issues
1. Verify PostgreSQL connection
2. Check for pending migrations
3. Ensure Ash resources are up to date
4. Test with `mix ash.codegen --check`

#### Airtable Sync Problems
1. Verify API key configuration
2. Check Airtable base structure
3. Review sync error messages
4. Test connection manually

## Development Configuration

### Required Environment Variables
```bash
AT_UK_E_API_KEY=your_airtable_api_key
```

### Port Configuration
- Application runs on port 4002 (development)
- Tidewave MCP available at `http://localhost:4002/tidewave/mcp`
- Configured to avoid conflicts with other Phoenix projects

### Testing
```bash
# Run all tests
mix test

# Run specific test files
mix test test/ehs_enforcement/countries/uk/legl_enforcement/

# Run tests with coverage
mix test --cover
```

## Data Quality Management

### Validation Rules
- Cases must have valid dates and location data
- Company information is standardized where possible
- Enforcement types follow HSE classification system
- Financial penalties are validated for accuracy

### Data Cleanup
- Duplicate detection and merging
- Standardization of company names and addresses
- Correction of data parsing errors
- Regular data quality audits

## Security Considerations

- API keys stored as environment variables only
- No sensitive data in version control
- Database access restricted to authorized users
- Audit trail for all administrative changes

## Support and Maintenance

### Regular Maintenance Tasks
1. Monitor scraping success rates
2. Review data quality metrics
3. Update HSE website parsing logic as needed
4. Maintain Airtable schema compatibility
5. Backup critical data regularly

### Getting Help
- Check application logs for error details
- Review existing test cases for expected behavior
- Consult HSE website structure for parsing issues
- Verify Ash resource definitions for data model questions

## Technical Architecture

### Key Components
- **Ash Framework**: Data modeling and business logic
- **Phoenix LiveView**: Real-time administrative interface
- **Tesla/Req**: HTTP clients for HSE website scraping
- **Airtable API**: External data synchronization
- **PostgreSQL**: Local data storage and caching

### Module Structure
- `EhsEnforcement.Agencies.*` - Agency-specific processing
- `EhsEnforcement.Integrations.*` - External service integration
- Legacy `Legl.*` modules being refactored to new structure