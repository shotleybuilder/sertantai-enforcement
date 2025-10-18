# Admin Guide: Configuration Management

**Route:** `/admin/config`  
**Access Level:** Admin Required  
**Module:** `EhsEnforcementWeb.Admin.ConfigLive.Index`

## Overview

The Configuration Management interface provides centralized control over system settings, scraping parameters, and feature flags. This is the main hub for all administrative configuration tasks.

## Accessing Configuration Management

1. **Login Requirements:** Must be logged in with admin privileges - see [Authentication Guide](authentication.md)
2. **Navigate to:** `/admin/config`
3. **Prerequisites:** Admin user account with proper permissions (GitHub username in `GITHUB_ALLOWED_USERS`)

## Interface Layout

### Configuration Overview Panel
- **Active Configurations:** Shows currently active scraping configurations
- **Configuration Status:** Displays whether configurations are active/inactive
- **Feature Flags Summary:** Quick overview of enabled/disabled features
- **Last Updated:** Timestamp of most recent configuration changes

### Navigation Options
- **Scraping Configuration:** Navigate to detailed scraping settings
- **Feature Flags:** Access feature toggle controls
- **System Settings:** General application settings

## Main Functions

### 1. View Configuration Status
**Purpose:** Monitor current system configuration state

**Steps:**
1. Access `/admin/config`
2. Review configuration overview panel
3. Check status badges (Active/Inactive)
4. Review feature flags summary

**Status Indicators:**
- 🟢 **Green Badge:** Configuration is active and operational
- ⚫ **Gray Badge:** Configuration exists but is inactive
- 🔴 **Red Alert:** Configuration errors or missing required settings

### 2. Navigate to Scraping Configuration
**Purpose:** Access detailed scraping parameter controls

**Steps:**
1. Click "Scraping Configuration" button
2. Redirects to `/admin/config/scraping`
3. Access detailed scraping parameters and controls

### 3. Create Default Configuration
**Purpose:** Initialize system with default settings when no configuration exists

**When to Use:**
- First-time system setup
- After configuration corruption or deletion
- Reset to factory defaults

**Steps:**
1. Click "Create Default Configuration" button
2. System creates default scraping configuration with safe defaults
3. Automatic redirect to scraping configuration page
4. Review and customize default settings as needed

**Default Configuration Values:**
- Rate limiting: 10 requests per minute
- Consecutive existing threshold: 10 records
- Network timeout: 30 seconds
- Manual scraping: Enabled
- Scheduled scraping: Disabled (for safety)

### 4. Monitor Feature Flags
**Purpose:** Quick overview of enabled system features

**Feature Categories:**
- **Manual Scraping Enabled:** Allow administrators to trigger manual scraping
- **Scheduled Scraping Enabled:** Enable automated scraping on schedule
- **Real-time Progress Enabled:** Show live progress during scraping operations
- **Admin Notifications Enabled:** Send alerts for system events and errors

**Status Display:** Shows "X/Y enabled" format (e.g., "3/4 enabled")

## Configuration Types

### Scraping Configuration
- **Purpose:** Control HSE website scraping behavior
- **Access:** Navigate from main config page
- **Settings:** Rate limits, timeouts, retry logic, stopping conditions

### Feature Flags
- **Purpose:** Enable/disable system capabilities
- **Scope:** Affects entire application behavior
- **Categories:** Scraping, notifications, UI features, automation

### System Settings
- **Purpose:** General application configuration
- **Includes:** Database settings, logging levels, cache configuration
- **Note:** Some settings require application restart

## Error Handling

### Configuration Loading Errors
**Symptoms:**
- "Failed to load configuration data" message
- Empty configuration list
- Error badges in interface

**Troubleshooting:**
1. Check database connectivity
2. Verify user permissions
3. Review application logs for specific error details
4. Try refreshing the page

### Configuration Creation Errors
**Symptoms:**
- "Failed to create default configuration" message
- No redirect to scraping configuration
- Error flash message

**Common Causes:**
- Database write permissions
- Invalid default values
- Conflicting existing configurations

**Resolution:**
1. Check database permissions
2. Review application logs
3. Manually create configuration via database if needed
4. Contact system administrator

### Permission Errors
**Symptoms:**
- Access denied messages
- Redirect to login page
- 403 Forbidden errors

**Resolution:**
1. Verify admin user status
2. Check user permissions in database
3. Re-authenticate if session expired
4. Contact administrator for permission changes

## Best Practices

### Configuration Management
1. **Always Review Before Changes:** Check current configuration before making modifications
2. **Test Changes in Development:** Validate configuration changes in non-production environment
3. **Monitor After Changes:** Watch system behavior after configuration updates
4. **Keep Backups:** Document working configurations for rollback purposes

### Feature Flag Management
1. **Enable Gradually:** Turn on features one at a time to isolate issues
2. **Monitor Impact:** Watch system performance after enabling features
3. **Disable on Problems:** Quickly disable problematic features
4. **Document Changes:** Keep record of when and why features were toggled

### Safety Guidelines
1. **Scheduled Scraping:** Only enable after thorough testing
2. **Rate Limiting:** Never disable completely - protects HSE website
3. **Admin Notifications:** Keep enabled for monitoring critical issues
4. **Manual Scraping:** Safe to enable for on-demand data collection

## Related Admin Interfaces

### Scraping Configuration Details
- **Route:** `/admin/config/scraping`
- **Purpose:** Detailed scraping parameter control
- **Access:** Via "Scraping Configuration" button

### Scraping Operations
- **Route:** `/admin/scraping`
- **Purpose:** Monitor and control active scraping operations
- **Access:** Separate navigation menu

### Case Scraping
- **Route:** `/admin/cases/scrape`
- **Purpose:** Manual case data collection
- **Dependency:** Requires proper configuration

### Notice Scraping
- **Route:** `/admin/notices/scrape`
- **Purpose:** Manual notice data collection
- **Dependency:** Requires proper configuration

## Troubleshooting Common Issues

### "No configurations found"
**Cause:** System has no scraping configurations
**Solution:** Click "Create Default Configuration"

### Configuration appears inactive
**Cause:** Configuration exists but is not set as active
**Solution:** Navigate to scraping configuration and activate

### Feature flags not updating
**Cause:** Browser caching or session issues
**Solution:** Refresh page or clear browser cache

### Navigation buttons not working
**Cause:** JavaScript errors or authentication issues
**Solution:** Check browser console, verify admin permissions

## Security Considerations

### Access Control
- Admin-only interface - regular users cannot access
- Session-based authentication required
- Automatic logout on session expiry

### Configuration Security
- All changes logged with user attribution
- No sensitive data exposed in interface
- Database-backed persistence with proper validation

### Audit Trail
- Configuration changes tracked in application logs
- User actions recorded for compliance
- System events logged for troubleshooting

This configuration management interface is the foundation for all admin operations. Proper configuration ensures reliable, ethical data collection from HSE sources while maintaining system security and performance.