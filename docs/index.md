# EHS Enforcement Documentation

Welcome to the EHS Enforcement application documentation. This system collects and manages UK environmental, health, and safety enforcement data from the Health and Safety Executive (HSE).

## Quick Start

### Getting Started
- [Running the Application](running_the_app.md) - How to start and test the application

### User Guides
- [Installation Guide](installation.md) - Setting up the application
- [User Manual](user-guide.md) - Complete user guide for the web interface
- [API Documentation](api/index.md) - REST API reference

### Tutorials
- [Basic Usage Tutorial](tutorials/basic-usage.md) - Step-by-step introduction
- [Data Export Tutorial](tutorials/data-export.md) - How to export enforcement data
- [Search and Filtering](tutorials/search-filter.md) - Finding specific cases and notices

## About the System

The EHS Enforcement application automatically collects enforcement data from the HSE website, including:

- **Prosecution Cases**: Court cases and legal outcomes
- **Enforcement Notices**: Improvement and prohibition notices
- **Company Information**: Details about offending organizations
- **Financial Penalties**: Fines, costs, and payment tracking

## System Features

### Data Collection
- Automated scraping from HSE website
- Real-time data processing and validation
- Duplicate detection and data deduplication
- Comprehensive error handling and retry logic

### Web Interface
- Live dashboard with enforcement statistics
- Advanced search and filtering capabilities
- Interactive data visualization
- CSV export functionality
- Real-time updates during data collection

### Data Management
- PostgreSQL database for reliable storage
- Airtable integration for external sharing
- Automated backups and data integrity checks
- API access for external integrations

## Support

### Getting Help
- Check the [User Manual](user-guide.md) for detailed instructions
- Review [Common Issues](troubleshooting.md) for problem resolution
- Visit our [GitHub Repository](https://github.com/your-username/ehs_enforcement) for technical details

### System Requirements
- Modern web browser (Chrome, Firefox, Safari, Edge)
- Internet connection for real-time data updates
- JavaScript enabled for interactive features

## Data Sources

This application collects publicly available enforcement data from:
- [HSE Prosecutions Database](https://www.hse.gov.uk/prosecutions/)
- [HSE Enforcement Notices](https://www.hse.gov.uk/notices/)

All data collection respects HSE's terms of service and follows ethical scraping practices with appropriate rate limiting.

---

*This documentation is for the public user interface. Developer and administrative documentation is available separately for authorized users.*