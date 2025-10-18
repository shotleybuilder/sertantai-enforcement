# Admin Guide: Notice Scraping

**Route:** `/admin/notices/scrape`  
**Access Level:** Admin Required  
**Module:** `EhsEnforcementWeb.Admin.NoticeLive.Scrape`

## Overview

The Notice Scraping interface allows administrators to manually trigger HSE enforcement notice data collection from the HSE website. This interface collects improvement notices and prohibition notices issued by the Health and Safety Executive, providing real-time progress monitoring and comprehensive error reporting.

## Accessing Notice Scraping

1. **Login Requirements:** Must be logged in with admin privileges
2. **Navigate to:** `/admin/notices/scrape`
3. **Feature Flag:** Manual scraping must be enabled in configuration
4. **Prerequisites:** Valid scraping configuration must exist

## Interface Components

### Scraping Configuration Panel
- **Start Page:** HSE website page number to begin scraping (default: 1)
- **Max Pages:** Maximum number of pages to process (default: 10, max: 100)
- **Database:** Fixed to "notices" for enforcement notices
- **Submit Button:** "Start Scraping" to initiate data collection

### Real-Time Progress Monitor
- **Progress Bar:** Visual completion percentage
- **Current Status:** Text description of current operation
- **Session Statistics:** Live counters for pages, notices, errors
- **Stop Button:** Emergency stop for active scraping

### Recent Notices Display
- **Newly Scraped Notices:** Notices added during current session
- **Notice Status Badges:** Created, Existing, Error indicators  
- **Clear Results:** Button to clear scraped notices display

### Processing Log
- **Live Activity:** Real-time processing events
- **Error Messages:** Detailed error information
- **Session History:** Previous scraping session summaries

## Notice Types Collected

### Improvement Notices
- **Purpose:** Require organizations to remedy health and safety breaches
- **Content:** Specific improvements required, deadlines, legal basis
- **Follow-up:** May lead to prosecution if not complied with

### Prohibition Notices
- **Purpose:** Stop activities that pose serious and imminent danger
- **Content:** Activities prohibited, immediate action required
- **Urgency:** Take effect immediately upon service

### Notice Information Captured
- **Notice ID:** HSE's unique notice identifier
- **Recipient:** Company or individual receiving notice
- **Notice Type:** Improvement or Prohibition
- **Issue Date:** When notice was issued
- **Compliance Date:** Deadline for compliance (improvement notices)
- **Legal Basis:** Regulations or standards breached
- **Description:** Details of safety issues identified

## Scraping Process

### 1. Configure Scraping Parameters

**Start Page Selection:**
- Enter the HSE page number to begin scraping
- Default: 1 (most recent notices)
- Range: 1 to any valid HSE page number
- Tip: Higher numbers = older notices

**Max Pages Setting:**
- Choose how many pages to process
- Default: 10 pages
- Maximum: 100 pages (safety limit)
- Recommendation: Start with 5-10 for testing

### 2. Start Scraping Session

**Initiation Steps:**
1. Set start page and max pages
2. Click "Start Scraping" button
3. System validates parameters and configuration
4. Background scraping task begins immediately
5. Real-time progress updates appear

**Initial Validation:**
- Checks if manual scraping is enabled
- Verifies admin permissions
- Validates parameter ranges
- Creates scraping session record

### 3. Monitor Progress

**Progress Indicators:**
- **Status Text:** "Scraping in progress...", "Processing page...", etc.
- **Progress Bar:** Visual completion percentage (0-100%)
- **Current Page:** Which HSE page is being processed
- **Session ID:** Unique identifier for tracking

**Live Statistics:**
- **Pages Processed:** Number of HSE pages completed
- **Notices Found:** Total notices discovered on processed pages
- **Notices Created:** New notices successfully added to database
- **Notices Existing:** Duplicate notices already in database
- **Errors Count:** Processing failures or network issues

### 4. Intelligent Stopping Logic

**Automatic Stop Conditions:**
- **All Notices Exist:** If all notices on current page already exist in database
- **Max Pages Reached:** When configured maximum pages processed
- **Critical Errors:** Network failures or parsing errors
- **Manual Stop:** Admin clicks "Stop Scraping" button

**Early Termination Benefits:**
- Prevents redundant processing of old data
- Reduces load on HSE website
- Saves processing time and resources
- Maintains ethical scraping practices

## Real-Time Notice Display

### Notice Status System

**Created Notices (Green Badge):**
- New notices successfully added to database
- Complete with all scraped information
- Available immediately in main application

**Existing Notices (Blue Badge):**
- Notices already present in database
- May trigger updates to existing records
- Helps identify scraping boundaries

**Error Notices (Red Badge):**
- Notices that failed to process or save
- May have incomplete or invalid data
- Require manual review and potential retry

### Notice Information Display

**For Each Scraped Notice:**
- **Notice ID:** HSE's unique notice identifier
- **Recipient Name:** Company or individual served notice
- **Notice Type:** Improvement or Prohibition notice
- **Issue Date:** Date notice was issued by HSE
- **Compliance Date:** Deadline for improvement notices
- **Legal References:** Regulations or standards cited
- **Scraping Timestamp:** When notice was processed

## Error Handling and Recovery

### Common Error Types

**Network Errors:**
- HSE website timeouts or connection failures
- Rate limiting when requests too frequent
- Temporary HSE website unavailability

**Parsing Errors:**
- HSE website structure changes
- Missing or malformed notice data
- Unexpected HTML format changes

**Database Errors:**
- Validation failures for notice data
- Constraint violations (duplicate notice IDs)
- Database connectivity issues

### Error Recovery Actions

**For Network Issues:**
1. Check HSE website availability in browser
2. Verify internet connectivity
3. Adjust rate limiting in configuration
4. Retry scraping with smaller page count

**For Parsing Issues:**
1. Review recent notices for data quality
2. Check HSE website for structure changes
3. Contact development team if persistent
4. Use smaller page ranges to isolate problems

**For Database Issues:**
1. Check database connectivity
2. Review application logs for specific errors
3. Verify database schema is up to date
4. Check disk space and database resources

## Notice Data Quality

### Validation Checks
- **Notice ID Format:** Must match HSE identifier patterns
- **Date Validation:** Issue dates must be reasonable and formatted correctly
- **Recipient Information:** Company names and addresses validated
- **Notice Type:** Must be valid improvement or prohibition notice
- **Legal References:** Citations checked against known regulations

### Data Completeness
- **Required Fields:** Notice ID, recipient, type, issue date
- **Optional Fields:** Compliance date, detailed description, inspector name
- **Missing Data Handling:** Partial records flagged for manual review
- **Quality Scores:** Automated assessment of data completeness

## Best Practices

### Pre-Scraping Checklist
1. **Verify Configuration:** Ensure scraping settings are appropriate
2. **Check HSE Website:** Confirm website is accessible and normal
3. **Start Small:** Use 5-10 pages for initial testing
4. **Monitor First Pages:** Watch for immediate errors or issues

### Optimal Scraping Strategy
1. **Regular Small Batches:** Better than infrequent large batches
2. **Business Hours:** Avoid peak HSE website usage times
3. **Progressive Approach:** Start from page 1 (newest notices) and work backward
4. **Stop When Duplicates High:** When most notices already exist

### Notice-Specific Considerations
1. **Compliance Tracking:** Monitor improvement notice deadlines
2. **Follow-up Actions:** Track whether notices led to prosecutions
3. **Geographic Analysis:** Map notice distribution by region
4. **Industry Patterns:** Identify sectors with high notice activity

## Integration with Case Data

### Cross-Reference Opportunities
- **Notice to Prosecution:** Track when notices lead to prosecutions
- **Repeat Offenders:** Companies with multiple notices and cases
- **Escalation Patterns:** Improvement notices followed by prohibition notices
- **Compliance Outcomes:** Success rates for notice compliance

### Combined Analytics
- **Enforcement Trends:** Notice and prosecution patterns over time
- **Geographic Hotspots:** Areas with high enforcement activity
- **Industry Focus:** Sectors with concentrated HSE attention
- **Inspector Activity:** Individual inspector patterns and outcomes

## Troubleshooting Guide

### "Manual scraping is currently disabled"
**Cause:** Feature flag is turned off in configuration
**Solution:** Navigate to `/admin/config` and enable manual scraping

### Progress stuck at specific page
**Cause:** HSE website changes or network issues for that page
**Solution:** Stop current session, skip problematic page range

### High error count during scraping
**Cause:** HSE website structure changes or connectivity issues
**Solution:** Stop scraping, check HSE website manually, contact support

### Notices not appearing in main application
**Cause:** Database synchronization or caching issues
**Solution:** Refresh main application, check database directly

### Notice date parsing errors
**Cause:** Changes in HSE date format or unexpected date values
**Solution:** Review error logs, may require code updates for new formats

## Performance Considerations

### System Resources
- **Memory Usage:** Each notice uses small amount of memory
- **Database Load:** Creates database writes for new notices
- **Network Bandwidth:** HTTP requests to HSE website
- **Processing Time:** Varies based on notice complexity and legal text

### Optimization Tips
- **Smaller Batches:** Process 10-20 pages at a time
- **Off-Peak Hours:** Schedule during low system usage
- **Monitor Database:** Watch for performance impact
- **Rate Limiting:** Use conservative settings for stability

## Legal and Compliance Considerations

### Data Sources
- **Public Records:** All notice data is publicly available on HSE website
- **Accuracy:** Data reflects official HSE enforcement actions
- **Timeliness:** Notice data typically updated daily on HSE website
- **Completeness:** May not include all HSE enforcement activity

### Data Usage
- **Research Purposes:** Suitable for academic and policy research
- **Business Intelligence:** Helps organizations understand enforcement trends
- **Risk Assessment:** Identify high-risk activities and locations
- **Compliance Planning:** Learn from others' enforcement experiences

This notice scraping interface provides comprehensive collection of HSE enforcement notice data, enabling detailed analysis of regulatory enforcement patterns and compliance trends across industries and regions.