# HSE Case Administration User Guide

## Getting Started

Welcome to the HSE Enforcement Data Management System. This guide will help you navigate the admin interface to manage HSE enforcement cases, monitor data collection, and maintain system operations.

### Accessing the System
- Navigate to the admin dashboard in your web browser
- Log in with your administrator credentials
- The main dashboard shows system status and recent activity

## Dashboard Overview

### System Status Panel
The top of your dashboard displays:
- **Data Collection Status**: Shows if automatic scraping is running
- **Last Update**: When the system last collected new cases
- **Total Cases**: Current number of cases in the system
- **Sync Status**: Connection status with external systems (Airtable)

### Quick Actions
Use the action buttons to:
- **Start Collection**: Manually trigger data collection from HSE website
- **Sync Data**: Force synchronization with Airtable
- **View Reports**: Generate data quality and collection reports
- **System Settings**: Configure collection schedules and notifications

## Managing HSE Cases

### Case Listings
The main case view shows all enforcement data with options to:
- **Filter by Date Range**: Use date pickers to narrow results
- **Search Cases**: Find specific companies or locations
- **Filter by Type**: Show only prosecutions or enforcement notices
- **Sort Results**: Order by date, company name, or penalty amount

### Case Details
Click any case to view:
- **Company Information**: Name, address, industry sector
- **Violation Details**: What regulations were breached
- **Enforcement Action**: Type of notice or prosecution outcome
- **Financial Penalties**: Fines, costs, and payment status
- **Source Data**: Original HSE website links and documents

### Case Management Actions
For each case you can:
- **Edit Details**: Correct any parsing errors or add notes
- **Mark as Reviewed**: Track which cases have been manually verified
- **Export Data**: Download case information for reports
- **View History**: See all changes made to the case record

## Manual HSE Case Scraping

### Accessing the Scraping Interface
Navigate to the **Admin Scraping Interface** to manually trigger HSE case collection:
- Requires administrator authentication
- Provides real-time progress monitoring
- Includes comprehensive error reporting

### Configuring Scraping Parameters
Before starting a scraping session, configure:

**Basic Parameters:**
- **Start Page**: Which HSE page to begin scraping from (default: 1)
- **Max Pages**: Maximum number of pages to scrape (default: 10, maximum: 100)
- **Database Type**: Choose between "convictions" (prosecution cases) or "notices" (enforcement notices)

**Advanced Settings** (via Configuration Management):
- **Rate Limiting**: Requests per minute for ethical scraping
- **Pause Between Pages**: Delay in milliseconds between page requests
- **Network Timeout**: HTTP request timeout values
- **Batch Size**: Number of cases to process together

### Starting a Scraping Session

1. **Configure Parameters**: Set start page, max pages, and database type
2. **Click "Start Scraping"**: System validates parameters and begins
3. **Monitor Progress**: Real-time updates show current status
4. **View Results**: Session summary appears upon completion

### Real-Time Progress Monitoring

During active scraping, you'll see:

**Progress Indicators:**
- **Progress Bar**: Visual completion percentage
- **Current Status**: "Scraping in progress...", "Processing page...", etc.
- **Session ID**: Unique identifier for tracking this scraping run

**Live Statistics:**
- **Pages Processed**: Number of HSE pages successfully scraped
- **Cases Found**: Total cases discovered on processed pages
- **Cases Created**: New cases successfully added to database
- **Error Count**: Any issues encountered during processing

### Intelligent Stopping Logic

The system automatically stops scraping when:
- **10 consecutive existing records** found (prevents duplicate scraping)
- **Maximum pages reached** (configured limit hit)
- **Critical errors occur** (network failures, parsing errors)
- **Admin manually stops** using "Stop Scraping" button

### Session Results and Reporting

After completion, review:

**Session Summary:**
- **Total Pages Processed**: Complete count of HSE pages scraped
- **Cases Created Successfully**: New enforcement cases added
- **Errors Encountered**: Any issues with detailed error messages
- **Session Duration**: Time taken to complete scraping

**Recent Cases Display:**
- **Newly Created Cases**: List of cases added in this session
- **Company Details**: Names, locations, violation types
- **Source Links**: Direct links to original HSE website pages
- **Verification Status**: Which cases need manual review

**Error Reporting:**
- **Processing Errors**: Pages that couldn't be parsed correctly
- **Network Issues**: Connection timeouts or rate limiting
- **Data Quality Issues**: Cases with missing or suspicious information
- **HSE Website Changes**: Structure changes requiring code updates

## System Configuration

### Scraping Configuration Management
Access the **Configuration Management** interface to modify system behavior:

**HSE Endpoint Settings:**
- **Base URL**: HSE website endpoint for scraping
- **Database Selection**: Default database type (convictions/notices)
- **Network Timeout**: HTTP request timeout in milliseconds
- **User Agent**: Browser identification for HSE requests

**Rate Limiting & Ethics:**
- **Requests Per Minute**: Maximum requests to HSE website (ethical scraping)
- **Pause Between Pages**: Delay in milliseconds between page requests
- **Extra Delays**: Additional delays for low rate limits (≤5 requests/minute)
- **Retry Logic**: Number of attempts for failed requests

**Scraping Behavior:**
- **Consecutive Existing Threshold**: Stop after N existing records found (default: 10)
- **Max Pages Per Session**: Maximum pages per manual scraping session
- **Batch Size**: Number of cases processed together
- **Default Start Page**: Starting page for new scraping sessions

**Feature Flags:**
- **Manual Scraping Enabled**: Allow/disable admin-triggered scraping
- **Scheduled Scraping Enabled**: Enable/disable automatic scheduled runs
- **Real-time Progress Enabled**: Show live progress updates during scraping
- **Admin Notifications Enabled**: Send alerts for critical errors

**Schedule Configuration:**
- **Daily Scrape Schedule**: Cron expression for daily automated runs
- **Weekly Scrape Schedule**: Cron expression for weekly deep scans
- **Timezone Settings**: Time zone for scheduled operations

### Status Indicators

**System Health Monitoring:**
- **Green Status**: All systems operational, scraping running normally
- **Yellow Warning**: Minor issues detected (some pages failed, rate limiting active)
- **Red Alert**: Critical failure requiring immediate attention

**Configuration Status:**
- **Active Configuration**: Currently loaded settings with last update time
- **Pending Changes**: Configuration updates awaiting activation
- **Validation Errors**: Invalid settings that need correction

### External Integrations
Manage connections to external systems:
- **Airtable Sync**: Configure automatic data sharing with external teams
- **API Access**: Set up connections for other applications accessing case data
- **Export Formats**: Choose default formats for data exports (CSV, Excel, JSON)
- **Backup Settings**: Configure automatic database backups

## Troubleshooting Common Issues

### Scraping Problems
If manual scraping fails or shows errors:

**Before Starting Scraping:**
1. Check **Feature Flags** - ensure "Manual Scraping Enabled" is active
2. Verify **Rate Limiting Settings** - too aggressive limits may cause failures
3. Test **Network Connectivity** - confirm HSE website is accessible
4. Review **Configuration Status** - ensure no validation errors exist

**During Scraping Session:**
1. **Yellow Warning Status**: Minor issues detected
   - Check error count in live statistics
   - Review which pages failed processing
   - Consider adjusting rate limiting if network timeouts occur
   
2. **Red Alert Status**: Critical failure
   - Session has stopped due to serious errors
   - Check session error log for specific failure reasons
   - May indicate HSE website structure changes

3. **Slow Progress**: 
   - Rate limiting is active (ethical scraping behavior)
   - Network issues causing timeouts
   - HSE website responding slowly

**After Failed Session:**
1. Review **Session Results** for error details
2. Check **Error Reporting** for specific failure types
3. Use **Manual Collection** with smaller page ranges to isolate issues
4. Contact support if consistent failures suggest HSE website changes

### Data Quality Issues
When scraped cases show incomplete or incorrect information:

**Immediate Actions:**
1. Use **Edit Case** function to correct parsing errors
2. Check **Source Link** to verify against original HSE data
3. Mark case as **Needs Review** if information is questionable
4. Document patterns in error reporting system

**Systematic Fixes:**
1. Review **Processing Errors** in session results
2. Update **Data Quality Rules** to catch similar issues automatically
3. Adjust **Parsing Logic** if HSE format has changed
4. Set up **Quality Alerts** for critical missing information

### Configuration Issues
When configuration changes don't take effect:

**Validation Problems:**
1. Check **Configuration Status** for validation errors
2. Ensure **Numeric Values** are within acceptable ranges
3. Verify **Cron Expressions** for scheduled scraping are valid
4. Confirm **Feature Flag** combinations are logical

**Database Configuration:**
1. Only **One Active Configuration** allowed per environment
2. **Pending Changes** must be activated to take effect
3. Invalid configurations prevent system startup
4. Use **Fallback Configuration** if active config becomes corrupted

### Rate Limiting Issues
When scraping is too slow or fails due to rate limits:

**Adjusting Rate Limits:**
1. Increase **Pause Between Pages** for more conservative scraping
2. Reduce **Requests Per Minute** if getting blocked by HSE
3. Enable **Extra Delays** for very conservative scraping (≤5 requests/minute)
4. Adjust **Network Timeout** for slower connections

**Understanding Rate Limiting:**
- System automatically adds extra delays for low rate limits
- Progress may appear slow but this ensures ethical scraping
- Rate limiting prevents blocking by HSE website
- Monitor session duration vs. pages processed for efficiency

## Reports and Analytics

### Case Summary Reports
Generate reports showing:
- **Enforcement Trends**: Cases by month, region, or industry
- **Penalty Analysis**: Average fines and prosecution outcomes
- **Company Profiles**: Repeat offenders and enforcement history
- **Regulatory Focus**: Most commonly breached regulations

### Data Quality Metrics
Monitor system performance with:
- **Collection Success Rates**: Percentage of pages successfully processed
- **Data Completeness**: Fields with missing information
- **Processing Speed**: Time to collect and process new cases
- **Error Patterns**: Common parsing or validation failures

### Custom Reports
Create tailored reports for:
- **Executive Summaries**: High-level enforcement activity
- **Regulatory Analysis**: Trends in specific types of violations
- **Geographic Reports**: Enforcement activity by region
- **Industry Focus**: Cases in specific business sectors

## Best Practices

### Daily Tasks
- Check the dashboard status panel
- Review any error notifications
- Verify recent case additions look accurate
- Monitor external system sync status

### Weekly Tasks
- Run data quality reports
- Review and correct any flagged issues
- Check collection success rates
- Update any configuration changes needed

### Monthly Tasks
- Generate summary reports for stakeholders
- Review system performance metrics
- Update data quality rules based on patterns
- Plan any needed system maintenance

## Getting Help

### In-App Support
- Use the **Help** button for context-sensitive guidance
- Check **System Messages** for important updates
- Review **FAQ** section for common questions
- Access **Video Tutorials** for complex procedures

### When to Contact Support
Contact technical support when:
- Collection has been down for more than 24 hours
- Data quality issues affect large numbers of cases
- External integrations stop working
- You need help with advanced configuration changes

The system is designed to run automatically with minimal intervention, but regular monitoring ensures you catch any issues early and maintain high data quality standards.