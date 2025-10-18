# Admin Guide: Case Scraping

**Route:** `/admin/cases/scrape`  
**Access Level:** Admin Required  
**Module:** `EhsEnforcementWeb.Admin.CaseLive.Scrape`

## Overview

The Case Scraping interface allows administrators to manually trigger HSE prosecution case data collection from the HSE website. This interface provides real-time progress monitoring, intelligent stopping logic, and comprehensive error reporting.

## Accessing Case Scraping

1. **Login Requirements:** Must be logged in with admin privileges
2. **Navigate to:** `/admin/cases/scrape`
3. **Feature Flag:** Manual scraping must be enabled in configuration
4. **Prerequisites:** Valid scraping configuration must exist

## Interface Components

### Scraping Configuration Panel
- **Start Page:** HSE website page number to begin scraping (default: 1)
- **Max Pages:** Maximum number of pages to process (default: 10, max: 100)
- **Database:** Fixed to "convictions" for prosecution cases
- **Submit Button:** "Start Scraping" to initiate data collection

### Real-Time Progress Monitor
- **Progress Bar:** Visual completion percentage
- **Current Status:** Text description of current operation
- **Session Statistics:** Live counters for pages, cases, errors
- **Stop Button:** Emergency stop for active scraping

### Recent Cases Display
- **Newly Scraped Cases:** Cases added during current session
- **Case Status Badges:** Created, Existing, Error indicators  
- **Clear Results:** Button to clear scraped cases display

### Processing Log
- **Live Activity:** Real-time processing events
- **Error Messages:** Detailed error information
- **Session History:** Previous scraping session summaries

## Scraping Process

### 1. Configure Scraping Parameters

**Start Page Selection:**
- Enter the HSE page number to begin scraping
- Default: 1 (most recent cases)
- Range: 1 to any valid HSE page number
- Tip: Higher numbers = older cases

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
- **Cases Found:** Total cases discovered on processed pages
- **Cases Created:** New cases successfully added to database
- **Cases Existing:** Duplicate cases already in database
- **Errors Count:** Processing failures or network issues

### 4. Intelligent Stopping Logic

**Automatic Stop Conditions:**
- **All Cases Exist:** If all cases on current page already exist in database
- **Max Pages Reached:** When configured maximum pages processed
- **Critical Errors:** Network failures or parsing errors
- **Manual Stop:** Admin clicks "Stop Scraping" button

**Early Termination Benefits:**
- Prevents redundant processing of old data
- Reduces load on HSE website
- Saves processing time and resources
- Maintains ethical scraping practices

## Real-Time Case Display

### Case Status System

**Created Cases (Green Badge):**
- New cases successfully added to database
- Complete with all scraped information
- Available immediately in main application

**Existing Cases (Blue Badge):**
- Cases already present in database
- May trigger updates to existing records
- Helps identify scraping boundaries

**Error Cases (Red Badge):**
- Cases that failed to process or save
- May have incomplete or invalid data
- Require manual review and potential retry

### Case Information Display

**For Each Scraped Case:**
- **Regulator ID:** HSE's unique case identifier
- **Offender Name:** Company or individual prosecuted
- **Action Date:** Date of prosecution or enforcement
- **Fine Amount:** Financial penalty imposed
- **Case Result:** Conviction, fine, or other outcome
- **Scraping Timestamp:** When case was processed

## Error Handling and Recovery

### Common Error Types

**Network Errors:**
- HSE website timeouts or connection failures
- Rate limiting when requests too frequent
- Temporary HSE website unavailability

**Parsing Errors:**
- HSE website structure changes
- Missing or malformed case data
- Unexpected HTML format changes

**Database Errors:**
- Validation failures for case data
- Constraint violations (duplicate regulator_ids)
- Database connectivity issues

### Error Recovery Actions

**For Network Issues:**
1. Check HSE website availability in browser
2. Verify internet connectivity
3. Adjust rate limiting in configuration
4. Retry scraping with smaller page count

**For Parsing Issues:**
1. Review recent cases for data quality
2. Check HSE website for structure changes
3. Contact development team if persistent
4. Use smaller page ranges to isolate problems

**For Database Issues:**
1. Check database connectivity
2. Review application logs for specific errors
3. Verify database schema is up to date
4. Check disk space and database resources

## Session Management

### Active Session Monitoring
- **Session Start Time:** When scraping began
- **Current Operation:** Which page/case being processed
- **Estimated Completion:** Based on progress and remaining pages
- **Resource Usage:** Memory and processing impact

### Session History
- **Previous Sessions:** List of completed scraping runs
- **Success Metrics:** Cases created, pages processed, duration
- **Error Summaries:** Issues encountered and resolution
- **Performance Data:** Speed and efficiency metrics

### Session Cleanup
- **Clear Results:** Remove scraped cases display (doesn't delete from database)
- **Clear Processing Log:** Remove session activity log
- **Reset Progress:** Clear all session-specific data

## Best Practices

### Pre-Scraping Checklist
1. **Verify Configuration:** Ensure scraping settings are appropriate
2. **Check HSE Website:** Confirm website is accessible and normal
3. **Start Small:** Use 5-10 pages for initial testing
4. **Monitor First Pages:** Watch for immediate errors or issues

### Optimal Scraping Strategy
1. **Regular Small Batches:** Better than infrequent large batches
2. **Business Hours:** Avoid peak HSE website usage times
3. **Progressive Approach:** Start from page 1 (newest cases) and work backward
4. **Stop When Duplicates High:** When most cases already exist

### Ethical Considerations
1. **Respect Rate Limits:** Don't override safety settings
2. **Monitor Impact:** Watch for any signs of blocking or throttling
3. **Reasonable Requests:** Avoid excessive or unnecessary scraping
4. **Public Data Only:** Only collect publicly available information

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

### Cases not appearing in main application
**Cause:** Database synchronization or caching issues
**Solution:** Refresh main application, check database directly

### "All cases already exist" stops too early
**Cause:** System correctly detected existing cases boundary
**Solution:** Normal behavior - indicates efficient scraping boundaries

## Performance Considerations

### System Resources
- **Memory Usage:** Each case uses small amount of memory
- **Database Load:** Creates database writes for new cases
- **Network Bandwidth:** HTTP requests to HSE website
- **Processing Time:** Depends on page size and case complexity

### Optimization Tips
- **Smaller Batches:** Process 10-20 pages at a time
- **Off-Peak Hours:** Schedule during low system usage
- **Monitor Database:** Watch for performance impact
- **Rate Limiting:** Use conservative settings for stability

## Integration with Other Systems

### Database Updates
- **Case Records:** New cases added to main database
- **Offender Records:** Company information created/updated
- **Agency Records:** HSE agency data maintained
- **PubSub Events:** Real-time notifications to other system components

### External Synchronization
- **Airtable Sync:** Cases may sync to external Airtable
- **API Access:** Scraped cases available via API endpoints
- **Export Functions:** Cases included in CSV/Excel exports
- **Reporting Systems:** Data available for reports and analytics

## Security and Compliance

### Data Protection
- **Public Data Only:** Only collects publicly available HSE data
- **No Personal Data:** Company information only, not individual details
- **Secure Transport:** HTTPS connections for all data transfer
- **Access Logging:** All scraping activity logged with user attribution

### Audit Trail
- **Session Logs:** Complete record of scraping activities
- **User Attribution:** All actions tied to authenticated admin user
- **Error Logging:** Detailed error information for troubleshooting
- **Database Changes:** All case creation/updates logged

This case scraping interface provides powerful, automated data collection while maintaining ethical practices and comprehensive monitoring. Regular use with appropriate configuration ensures up-to-date HSE prosecution data for analysis and reporting.