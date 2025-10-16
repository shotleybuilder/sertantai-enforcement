# EHS Enforcement Admin Guide Documentation

This directory contains comprehensive administrative documentation for the EHS Enforcement system, covering all aspects of HSE (Health and Safety Executive) data collection, management, and analysis.

## Quick Navigation

| Guide | Purpose | Route | Key Features |
|-------|---------|-------|-------------|
| **[Authentication](authentication.md)** | **Admin access and login** | `/admin` | **GitHub OAuth, user allowlist, access control** |
| [Import and Sync Operations](import_sync_guide.md) | Data import and synchronization from Airtable | `/admin/sync` | Real-time progress, batch processing, error recovery |
| [General Cases Guide](cases.md) | Overview of HSE case administration | Various | System overview, troubleshooting |
| [Scraping Overview](scraping_overview.md) | Central monitoring dashboard | `/admin/scraping` | Performance metrics, analytics |
| [Case Scraping](case_scraping.md) | Manual prosecution case collection | `/admin/cases/scrape` | Real-time progress, intelligent stopping |
| [Notice Scraping](notice_scraping.md) | Manual enforcement notice collection | `/admin/notices/scrape` | Improvement/prohibition notices |
| [HSE Cases](hse_cases.md) | Specific HSE case management | N/A | Data structure, development setup |
| [Configuration Management](configuration_management.md) | System settings control | `/admin/config` | Feature flags, scraping parameters |

## System Overview

The EHS Enforcement system automatically collects, processes, and manages enforcement data from the Health and Safety Executive (HSE) website, covering:

- **Prosecution Cases**: Legal proceedings and court outcomes
- **Enforcement Notices**: Improvement and prohibition notices issued
- **Real-time Monitoring**: Live progress tracking during data collection
- **Data Synchronization**: Integration with Airtable and PostgreSQL

## Key Administrative Functions

### Data Collection
- **Automated Scraping**: Scheduled collection from HSE website
- **Manual Triggering**: On-demand scraping with parameter controls
- **Intelligent Stopping**: Prevents redundant processing of existing data
- **Error Recovery**: Comprehensive error handling and retry logic

### Monitoring & Analytics
- **Performance Dashboard**: System metrics and collection statistics
- **Real-time Progress**: Live activity feeds and progress indicators
- **Historical Analysis**: Trends, patterns, and comparative analysis
- **Quality Metrics**: Data completeness and accuracy tracking

### System Configuration
- **Scraping Parameters**: Rate limiting, timeouts, batch sizes
- **Feature Flags**: Enable/disable system capabilities
- **Safety Settings**: Ethical scraping controls and limits
- **Integration Settings**: External system connections

## Getting Started

### Prerequisites
- **Admin user account with proper permissions** - See [Authentication Guide](authentication.md) for setup
- Valid scraping configuration (auto-created if missing)
- Network access to HSE website
- Environment variables configured (e.g., `AT_UK_E_API_KEY`)

### Initial Setup
1. **Set Up Admin Access**: Configure GitHub OAuth authentication - [See Authentication Guide](authentication.md)
2. **Log In**: Sign in with authorized GitHub account
3. **Check Configuration**: Visit `/admin/config` to verify settings
4. **Test Collection**: Use small manual scraping sessions
5. **Monitor Results**: Review data quality and system performance

### Daily Operations
1. **Check Dashboard**: Review system status and recent activity
2. **Monitor Errors**: Address any collection or processing issues
3. **Review Data Quality**: Verify accuracy of newly collected data
4. **Manage Sessions**: Monitor active scraping operations

## Technical Architecture

### Core Technologies
- **Ash Framework**: Data modeling and business logic
- **Phoenix LiveView**: Real-time administrative interfaces
- **Tesla/Req**: HTTP clients for HSE website scraping
- **PostgreSQL**: Local data storage and caching
- **Airtable API**: External data synchronization

### Data Processing Flow
1. **Collection**: Scrape data from HSE website
2. **Processing**: Parse and structure enforcement data
3. **Validation**: Apply data quality and completeness checks
4. **Storage**: Save to PostgreSQL database
5. **Synchronization**: Update external systems (Airtable)

## Safety and Ethics

### Ethical Scraping Practices
- **Rate Limiting**: Respectful request frequencies to HSE website
- **Public Data Only**: Collection limited to publicly available information
- **Network Timeouts**: Reasonable connection and processing timeouts
- **Error Handling**: Graceful failure management

### Data Protection
- **Access Control**: Admin-only interfaces with GitHub OAuth authentication - [See Authentication Guide](authentication.md)
- **User Allowlist**: Configurable list of authorized GitHub users
- **Audit Trails**: Complete logging of administrative actions
- **Secure Storage**: Encrypted data transmission and storage
- **No Personal Data**: Focus on organizational enforcement data only

## Troubleshooting Quick Reference

### Common Issues
- **"Manual scraping is currently disabled"** → Enable in `/admin/config`
- **High error rates** → Check HSE website availability and rate limiting
- **Slow performance** → Adjust batch sizes and rate limits
- **Missing data** → Verify parsing logic and HSE website structure

### Performance Optimization
- **Start Small**: Use 5-10 pages for initial testing
- **Off-Peak Hours**: Schedule during low HSE website usage
- **Monitor Resources**: Watch system memory and database performance
- **Incremental Changes**: Make small configuration adjustments

## Support Resources

### Documentation Structure
Each guide follows a consistent structure:
- **Overview**: Purpose and key capabilities
- **Interface Components**: Detailed UI element descriptions
- **Step-by-step Processes**: Complete operational procedures
- **Error Handling**: Common issues and resolution steps
- **Best Practices**: Recommended approaches and safety guidelines

### Getting Help
- **In-App Guidance**: Context-sensitive help throughout interfaces
- **Error Messages**: Detailed error information with suggested actions
- **System Logs**: Comprehensive logging for troubleshooting
- **Development Support**: Technical assistance for complex issues

## Development Information

### Project Structure
- **Port Configuration**: Application runs on port 4002 (development)
- **Testing Framework**: ExUnit with Phoenix LiveView testing patterns
- **Environment Setup**: Mix tasks for development and deployment
- **Module Architecture**: Legacy `Legl.*` modules being refactored to `EhsEnforcement.*`

### Key Commands
```bash
# Start development server
mix phx.server

# Run tests
mix test

# Database operations
mix ash.migrate

# Check configuration
mix ash.codegen --check
```

This admin guide documentation provides complete coverage of all administrative functions, ensuring effective management of HSE enforcement data collection and system operations.