# Admin Guide: Scraping Overview

**Route:** `/admin/scraping`  
**Access Level:** Admin Required  
**Module:** `EhsEnforcementWeb.Admin.ScrapingLive.Index`

## Overview

The Scraping Overview interface provides comprehensive monitoring, analytics, and management capabilities for all HSE data collection activities. This dashboard serves as the central hub for tracking scraping performance, analyzing collected data, and managing scraping operations across both prosecution cases and enforcement notices.

## Accessing Scraping Overview

1. **Login Requirements:** Must be logged in with admin privileges
2. **Navigate to:** `/admin/scraping`
3. **Real-time Updates:** Interface updates automatically with live scraping activity
4. **Prerequisites:** Admin access and active scraping configuration

## Interface Components

### Performance Dashboard
- **System Metrics:** Overall scraping performance indicators
- **Data Collection Stats:** Total cases and notices collected
- **Success Rates:** Percentage of successful scraping operations
- **Error Tracking:** Recent errors and resolution status

### Recent Activity Monitor
- **Live Activity Feed:** Real-time scraping operations
- **Case Creation Events:** Newly added prosecution cases
- **Notice Collection Events:** Recently scraped enforcement notices
- **Processing Status:** Current scraping session information

### Historical Analytics
- **Collection Trends:** Data collection patterns over time
- **Performance Metrics:** Speed, efficiency, and reliability statistics
- **Error Analysis:** Common issues and resolution patterns
- **Data Quality Metrics:** Completeness and accuracy indicators

### Quick Actions Panel
- **Navigate to Case Scraping:** Direct link to manual case collection
- **Navigate to Notice Scraping:** Direct link to manual notice collection
- **Configuration Management:** Access to scraping settings
- **System Refresh:** Update all statistics and data

## Key Metrics and Statistics

### Data Collection Overview

**Total Collections:**
- **Cases Collected:** Total prosecution cases in database
- **Notices Collected:** Total enforcement notices in database
- **HSE Records:** Combined cases and notices from HSE
- **Recent Activity:** Data collected in selected time period

**Collection Rates:**
- **Cases per Day:** Average daily case collection rate
- **Notices per Day:** Average daily notice collection rate
- **Success Rate:** Percentage of successful scraping attempts
- **Error Rate:** Percentage of failed scraping operations

### Performance Indicators

**System Health:**
- **Active Sessions:** Currently running scraping operations
- **Queue Status:** Pending scraping tasks
- **Database Performance:** Database response times for scraping
- **Network Status:** Connectivity to HSE website

**Efficiency Metrics:**
- **Pages Processed:** Total HSE pages scraped
- **Processing Speed:** Average time per page
- **Data Throughput:** Records processed per hour
- **Resource Utilization:** System resources used for scraping

## Filter and Analysis Options

### Date Range Filters
- **Last 24 Hours:** Most recent scraping activity
- **Last 7 Days:** Weekly performance overview
- **Last 30 Days:** Monthly trends and patterns
- **Custom Range:** Specify exact date periods
- **All Time:** Complete historical data

### Agency Filtering
- **HSE Primary:** Cases and notices from main HSE enforcement
- **HSE Regional:** Regional HSE office activities
- **Specific Agencies:** Filter by particular enforcement agencies
- **Multi-Agency:** Combined view across all agencies

### Data Type Filtering
- **Prosecution Cases Only:** Filter to show only court cases
- **Enforcement Notices Only:** Show only improvement/prohibition notices
- **Combined View:** All HSE enforcement data together
- **Error Records Only:** Focus on failed or problematic records

## Real-Time Monitoring

### Live Activity Feed
**Active Scraping Sessions:**
- Session ID and current status
- Pages being processed
- Cases/notices being collected
- Progress indicators and estimated completion

**Recent Completions:**
- Successfully completed scraping sessions
- Records added in each session
- Performance metrics for each session
- Any errors encountered and resolved

**System Events:**
- Configuration changes
- System restarts or maintenance
- Database updates or migrations
- External system synchronization

### Alert System
**Performance Alerts:**
- Unusually slow scraping speeds
- High error rates during collection
- Database performance issues
- Network connectivity problems

**Data Quality Alerts:**
- Parsing errors for HSE website changes
- Incomplete or malformed records
- Duplicate detection failures
- Validation rule violations

## Historical Analysis

### Trend Visualization
- **Collection Volume:** Charts showing data collection over time
- **Success Rates:** Historical performance trends
- **Error Patterns:** Common issues and seasonal variations
- **Efficiency Improvements:** Performance optimization results

### Comparative Analysis
- **Period Comparisons:** Compare different time periods
- **Before/After Analysis:** Impact of configuration changes
- **Agency Comparisons:** Performance across different HSE regions
- **Data Type Analysis:** Cases vs. notices collection patterns

## System Management

### Session Management
**Active Session Control:**
- View currently running scraping operations
- Monitor progress and resource usage
- Stop problematic sessions if needed
- Restart failed sessions with corrected parameters

**Session History:**
- Complete log of all scraping sessions
- Success/failure rates by session
- Performance metrics per session
- Error details and resolution notes

### Performance Optimization
**Configuration Tuning:**
- Adjust rate limiting based on performance data
- Optimize batch sizes for efficiency
- Configure retry logic for reliability
- Set appropriate timeout values

**Resource Management:**
- Monitor system resource usage
- Schedule scraping during low-usage periods
- Balance scraping load across system capacity
- Plan for peak data collection periods

## Data Quality Management

### Quality Metrics
**Completeness Indicators:**
- Percentage of records with complete data
- Missing field analysis by data type
- Critical vs. optional field completeness
- Trends in data quality over time

**Accuracy Measures:**
- Data validation success rates
- Format compliance percentages
- Cross-reference verification results
- Manual review confirmation rates

### Error Analysis
**Common Error Types:**
- Network timeouts and connectivity issues
- HSE website structure changes
- Data parsing and validation failures
- Database constraint violations

**Error Resolution:**
- Automatic retry success rates
- Manual intervention requirements
- Code updates needed for HSE changes
- Configuration adjustments for stability

## Integration Status

### External System Synchronization
**Airtable Integration:**
- Sync status and last update times
- Record counts in external systems
- Synchronization error tracking
- Data consistency verification

**API Availability:**
- REST API endpoint status
- Data export functionality
- Third-party system connections
- Authentication and access control

### Database Health
**Performance Monitoring:**
- Query response times
- Database storage utilization
- Index effectiveness
- Connection pool status

**Data Integrity:**
- Constraint validation
- Referential integrity checks
- Duplicate detection results
- Data consistency audits

## Troubleshooting and Maintenance

### Common Issues
**Performance Problems:**
1. **Slow Scraping:** Check rate limiting and network connectivity
2. **High Memory Usage:** Review batch sizes and processing parameters
3. **Database Bottlenecks:** Monitor query performance and indexing
4. **Network Timeouts:** Adjust timeout settings and retry logic

**Data Quality Issues:**
1. **Parsing Errors:** Investigate HSE website structure changes
2. **Missing Data:** Review field mapping and extraction logic
3. **Duplicate Records:** Check duplicate detection algorithms
4. **Validation Failures:** Update validation rules for new data formats

### Preventive Maintenance
**Regular Monitoring:**
- Daily review of performance metrics
- Weekly analysis of error patterns
- Monthly data quality assessments
- Quarterly system optimization reviews

**Proactive Actions:**
- Monitor HSE website for structural changes
- Update parsing logic before errors occur
- Optimize database queries and indexes
- Plan capacity expansion before limits reached

## Best Practices for System Management

### Monitoring Routines
1. **Daily Checks:** Review overnight scraping results and error rates
2. **Weekly Analysis:** Analyze trends and performance patterns
3. **Monthly Reports:** Generate comprehensive system health reports
4. **Quarterly Reviews:** Assess system capacity and optimization needs

### Performance Optimization
1. **Baseline Establishment:** Document normal performance metrics
2. **Continuous Monitoring:** Track deviations from baseline performance
3. **Incremental Improvement:** Make small, measured optimization changes
4. **Impact Assessment:** Measure results of all configuration changes

### Data Quality Assurance
1. **Regular Validation:** Routine checks of data completeness and accuracy
2. **Trend Monitoring:** Watch for gradual degradation in data quality
3. **Source Monitoring:** Track changes in HSE website structure and content
4. **User Feedback:** Incorporate feedback from data consumers

This scraping overview interface provides comprehensive monitoring and management capabilities, ensuring reliable, efficient, and high-quality data collection from HSE sources while maintaining system performance and data integrity.