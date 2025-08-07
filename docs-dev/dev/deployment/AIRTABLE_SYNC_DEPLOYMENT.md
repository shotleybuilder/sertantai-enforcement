# Airtable to PostgreSQL Sync Deployment Guide

Your EHS Enforcement application has robust Airtable sync functionality built-in. Here are the **multiple ways** to run the sync on your production server.

## Sync Architecture Overview

### **Current Sync System:**
- ✅ **`EhsEnforcement.Sync`** - Main sync domain with import functions
- ✅ **`EhsEnforcement.Sync.SyncManager`** - Manages sync operations  
- ✅ **Admin UI** - Web interface for running syncs
- ✅ **Streaming imports** - Handles large datasets efficiently
- ✅ **Batch processing** - Prevents memory issues with 1000s of records

## Option 1: Admin Web Interface (Recommended)

### **Access the Built-in Admin Panel:**

Once deployed, you can sync via the web interface:

```
https://yourdomain.com/admin/config
https://yourdomain.com/admin/scraping
```

### **Features:**
- ✅ **One-click sync** for cases and notices
- ✅ **Progress monitoring** with real-time updates
- ✅ **Error handling** and retry capabilities
- ✅ **Batch size control** (100 records per batch)
- ✅ **Import statistics** and logging

### **Usage:**
1. Login with GitHub OAuth (admin user)
2. Navigate to Admin → Configuration  
3. Click "Import from Airtable"
4. Monitor progress in real-time
5. Review import statistics

## Option 2: Command Line Scripts (Server)

### **Direct Elixir Console Commands:**

```bash
# SSH into your server
ssh user@yourdomain.com

# Access running application
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement remote

# In the Elixir console:
# Import all cases (up to 1000)
EhsEnforcement.Sync.import_cases()

# Import all notices (up to 1000) 
EhsEnforcement.Sync.import_notices()

# Import with custom limits
EhsEnforcement.Sync.import_cases(limit: 5000, batch_size: 200)

# Check import statistics
EhsEnforcement.Sync.get_case_import_stats()
EhsEnforcement.Sync.get_notice_import_stats()
```

## Option 3: Automated Sync Scripts

### **Create Production Sync Scripts:**

Let me create automated scripts for you:

```bash
# One-time full import script
./scripts/airtable_import.sh prod

# Scheduled incremental sync  
./scripts/airtable_sync.sh prod --incremental
```

### **Cron Job Setup:**
```bash
# Add to server crontab for daily sync at 2 AM
0 2 * * * /opt/ehs_enforcement/scripts/airtable_sync.sh prod --incremental >> /var/log/airtable_sync.log 2>&1
```

## Option 4: Oban Background Jobs

### **Built-in Job System:**

Your app already has Oban configured for background jobs:

```elixir
# Queue a sync job
%{action: :import_cases, limit: 1000}  
|> EhsEnforcement.Sync.SyncWorker.new()
|> Oban.insert()

# Queue notice import
%{action: :import_notices, limit: 1000}
|> EhsEnforcement.Sync.SyncWorker.new() 
|> Oban.insert()
```

## Production Deployment Steps

### **1. Initial Data Migration (One-time):**

After deploying to production, run the full import:

```bash
# Method A: Via Admin UI
# Login → Admin → Configuration → "Import from Airtable"

# Method B: Via Console
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement remote
EhsEnforcement.Sync.import_cases(limit: 10000)
EhsEnforcement.Sync.import_notices(limit: 10000)

# Method C: Via Script
./scripts/airtable_import.sh prod --full
```

### **2. Environment Variables Setup:**

Ensure your `.env.prod` has:

```bash
# Required for Airtable sync
AT_UK_E_API_KEY=your-airtable-api-key
AIRTABLE_BASE_ID=appq5OQW9bTHC1zO5
```

### **3. Monitor Sync Progress:**

```bash
# View import logs
docker-compose -f docker-compose.prod.yml logs -f app | grep -i "import\|sync"

# Check database counts
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement remote
Ash.count(EhsEnforcement.Enforcement.Case)
Ash.count(EhsEnforcement.Enforcement.Notice)
```

## Sync Performance & Safety

### **Built-in Safety Features:**
- ✅ **Streaming processing** - Memory efficient for large datasets
- ✅ **Batch processing** - 100 records per batch (configurable)
- ✅ **Error recovery** - Continues processing if individual records fail
- ✅ **Duplicate prevention** - Uses `regulator_id` for uniqueness
- ✅ **Progress tracking** - Real-time sync status updates
- ✅ **Rollback capability** - Database transactions for safety

### **Performance Tuning:**

```bash
# For large imports, increase batch size
EhsEnforcement.Sync.import_cases(limit: 10000, batch_size: 500)

# Check memory usage during import
docker stats ehs_enforcement_app
```

## Recommended Production Workflow

### **Initial Migration:**
1. ✅ Deploy application to production
2. ✅ Verify Airtable API connectivity  
3. ✅ Run full import via Admin UI (recommended)
4. ✅ Verify data integrity and counts
5. ✅ Set up monitoring and logging

### **Ongoing Sync Strategy:**
- **Primary**: Use Admin UI for manual syncs as needed
- **Backup**: Automated scripts for scheduled updates
- **Emergency**: Console commands for troubleshooting

## Troubleshooting Sync Issues

### **Common Issues:**

#### **API Rate Limits:**
```bash
# Reduce batch size if hitting rate limits
EhsEnforcement.Sync.import_cases(batch_size: 50)
```

#### **Memory Issues:**
```bash
# Monitor memory during import
docker stats ehs_enforcement_app

# Reduce batch size if needed
EhsEnforcement.Sync.import_cases(batch_size: 25)
```

#### **Connection Timeouts:**
```bash
# Check Airtable connectivity
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement remote
EhsEnforcement.Integrations.Airtable.ReqClient.get("/appq5OQW9bTHC1zO5/tbl6NZm9bLU2ijivf", %{maxRecords: 1})
```

#### **Duplicate Records:**
```bash
# Clean up orphaned offenders
EhsEnforcement.Sync.cleanup_orphaned_offenders()

# Check for duplicates
EhsEnforcement.Repo.query("SELECT regulator_id, COUNT(*) FROM cases GROUP BY regulator_id HAVING COUNT(*) > 1")
```

## Data Verification

### **After Import Verification:**

```bash
# Check total counts
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement remote

# Cases imported
{:ok, cases} = Ash.read(EhsEnforcement.Enforcement.Case)
length(cases)

# Notices imported  
{:ok, notices} = Ash.read(EhsEnforcement.Enforcement.Notice)
length(notices)

# Offenders created
{:ok, offenders} = Ash.read(EhsEnforcement.Enforcement.Offender)
length(offenders)

# Sample data verification
cases |> Enum.take(5) |> Enum.map(&(&1.regulator_id))
```

## Monitoring & Alerting

### **Sync Monitoring:**

```bash
# Monitor sync logs
docker-compose -f docker-compose.prod.yml logs -f app | grep "import\|sync"

# Check for errors
docker-compose -f docker-compose.prod.yml logs app | grep -i error | tail -20

# Database health after sync
curl https://yourdomain.com/health
```

## Recommendation

**For your production deployment:**

1. **🎯 Start with Admin UI** - Most user-friendly and feature-rich
2. **🔧 Add console access** - For troubleshooting and maintenance  
3. **⚙️ Consider automation** - For ongoing incremental updates
4. **📊 Monitor everything** - Use built-in logging and health checks

The **Admin UI approach is recommended** because:
- ✅ **No command line needed** - Web-based interface
- ✅ **Real-time progress** - See sync status live
- ✅ **Error handling** - Built-in retry and error recovery
- ✅ **User-friendly** - Point-and-click operation
- ✅ **Secure** - Uses your existing GitHub OAuth authentication

Your sync system is **production-ready** with enterprise-grade error handling, progress tracking, and safety features! 🚀