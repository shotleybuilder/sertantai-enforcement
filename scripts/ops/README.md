# Operations Scripts

Scripts for monitoring, backup, and operational maintenance of deployed environments.

## Available Scripts

### backup.sh

**Create database backups**

```bash
./scripts/ops/backup.sh [environment] [--restore <backup_file>]

# Examples:
./scripts/ops/backup.sh production
./scripts/ops/backup.sh dev
./scripts/ops/backup.sh production --restore backups/2024-01-15.sql
```

**What it does:**
- Creates timestamped database dump
- Stores in `backups/` directory
- Can restore from backup
- Compresses backups automatically

**When to use:**
- Before major changes
- Regular scheduled backups
- Before production deployments
- Before database migrations

**Backup location**: `backups/backup_YYYYMMDD_HHMMSS.sql.gz`

---

### update.sh

**Update application from git**

```bash
./scripts/ops/update.sh [environment]

# Examples:
./scripts/ops/update.sh dev
./scripts/ops/update.sh production
```

**What it does:**
- Pulls latest code from git
- Updates dependencies (`mix deps.get`)
- Runs migrations
- Restarts services
- Verifies update

**When to use:**
- Deploying updates from git
- Syncing development environment
- Pulling team changes

**Safety**: Creates automatic backup before updating production

---

### monitor.sh

**Monitor application health and performance**

```bash
./scripts/ops/monitor.sh [environment] [--continuous] [--alert]

# Examples:
./scripts/ops/monitor.sh production
./scripts/ops/monitor.sh production --continuous  # Keep monitoring
./scripts/ops/monitor.sh production --alert       # Send alerts
```

**What it does:**
- Checks application health endpoints
- Monitors resource usage (CPU, memory, disk)
- Reports container/process status
- Can send alerts on issues
- Continuous monitoring mode

**When to use:**
- Production monitoring
- Troubleshooting performance issues
- After deployments
- Regular health checks

**Monitoring includes:**
- HTTP health endpoint checks
- Database connectivity
- Container/process status
- Resource utilization
- Recent error logs

---

## Common Workflows

### Pre-Deployment Checklist

```bash
# 1. Create backup
./scripts/ops/backup.sh production

# 2. Monitor current state
./scripts/ops/monitor.sh production

# 3. Deploy (see scripts/deployment/)
./scripts/deployment/deploy-prod.sh --migrate

# 4. Monitor after deployment
./scripts/ops/monitor.sh production --continuous
```

### Regular Maintenance

```bash
# Daily: Backup production
./scripts/ops/backup.sh production

# Weekly: Monitor health
./scripts/ops/monitor.sh production

# As needed: Update from git
./scripts/ops/update.sh production
```

### Troubleshooting

```bash
# Check system health
./scripts/ops/monitor.sh production

# Review recent backups
ls -lh backups/

# Restore from backup if needed
./scripts/ops/backup.sh production --restore backups/latest.sql.gz
```

### Development Updates

```bash
# Pull latest changes
./scripts/ops/update.sh dev

# Verify everything works
./scripts/ops/monitor.sh dev
```

---

## Backup Management

### Backup Best Practices

1. **Regular Schedule**:
   ```bash
   # Add to crontab for daily backups
   0 2 * * * /path/to/scripts/ops/backup.sh production
   ```

2. **Before Changes**:
   - Always backup before migrations
   - Backup before major deployments
   - Backup before data operations

3. **Retention**:
   - Keep daily backups for 7 days
   - Keep weekly backups for 1 month
   - Keep monthly backups for 1 year

### Backup Locations

```
backups/
├── backup_20250116_020000.sql.gz  # Automatic daily
├── backup_20250115_143000.sql.gz  # Manual pre-deploy
└── backup_20250114_020000.sql.gz  # Automatic daily
```

### Restore Process

```bash
# 1. Stop application (if running)
docker compose down ehs_enforcement_app

# 2. Restore backup
./scripts/ops/backup.sh production --restore backups/backup_file.sql.gz

# 3. Restart application
docker compose up -d ehs_enforcement_app

# 4. Verify
./scripts/ops/monitor.sh production
```

---

## Monitoring

### Health Checks

The monitor script checks:

1. **HTTP Endpoints**:
   - `/health` - Application health
   - `/` - Main page response

2. **Database**:
   - Connection status
   - Query performance
   - Disk usage

3. **System Resources**:
   - CPU usage
   - Memory usage
   - Disk space
   - Network connectivity

4. **Application**:
   - Container/process status
   - Recent errors in logs
   - Response times

### Alert Configuration

```bash
# Configure alerts (edit script for details)
ALERT_EMAIL="ops@example.com"
ALERT_SLACK_WEBHOOK="https://hooks.slack.com/..."

# Run with alerting
./scripts/ops/monitor.sh production --alert
```

---

## Production vs Development

### Production Operations

```bash
# Careful with production!
./scripts/ops/backup.sh production  # Always backup first
./scripts/ops/update.sh production  # Updates with safety checks
./scripts/ops/monitor.sh production # Check health
```

**Safety features for production:**
- Automatic backups before updates
- Confirmation prompts
- Health checks after changes
- Rollback capabilities

### Development Operations

```bash
# More relaxed in dev
./scripts/ops/backup.sh dev        # Optional
./scripts/ops/update.sh dev        # Quick updates
./scripts/ops/monitor.sh dev       # Check status
```

---

## Automation

### Cron Jobs

Example crontab for automated operations:

```bash
# Daily backup at 2 AM
0 2 * * * /path/to/scripts/ops/backup.sh production

# Hourly monitoring
0 * * * * /path/to/scripts/ops/monitor.sh production --alert

# Weekly cleanup of old backups (keep 30 days)
0 3 * * 0 find /path/to/backups -name "*.sql.gz" -mtime +30 -delete
```

---

## Environment Variables

Scripts may use:

```bash
# Database
DATABASE_URL=postgresql://user:pass@host:port/db

# Monitoring
HEALTH_CHECK_URL=http://localhost:4002/health
ALERT_EMAIL=ops@example.com

# Backup
BACKUP_DIR=./backups
BACKUP_RETENTION_DAYS=30
```

---

## Troubleshooting

### Backup Fails

```bash
# Check disk space
df -h

# Check database connectivity
psql -d ehs_enforcement_prod -c "SELECT 1"

# Check permissions
ls -la backups/
```

### Update Fails

```bash
# Check git status
git status

# Check for conflicts
git pull --rebase

# Check dependencies
mix deps.get
```

### Monitoring Issues

```bash
# Check if application is running
docker ps
# or
ps aux | grep beam

# Check health endpoint manually
curl http://localhost:4002/health

# Check logs
tail -f log/prod.log
```

---

## Safety Considerations

**⚠️ Production Safety:**
- Always backup before updates
- Test updates in development first
- Monitor after changes
- Have rollback plan ready
- Keep backup retention policy

**⚠️ Access Control:**
- Restrict production access
- Use separate credentials
- Audit operations
- Log all changes

---

## Related Documentation

- **[scripts/deployment/README.md](../deployment/README.md)** - Deployment scripts
- **[docs-dev/dev/deployment/](../../docs-dev/dev/deployment/)** - Deployment guides
- **[docs-dev/TROUBLESHOOTING.md](../../docs-dev/TROUBLESHOOTING.md)** - Common issues

---

## Related Scripts

**For deployment**, see:
- `scripts/deployment/deploy-prod.sh` - Deploy to production
- `scripts/deployment/build.sh` - Build Docker images
- `scripts/deployment/push.sh` - Push to registry

**For development**, see:
- `scripts/development/` - Development environment scripts
- `scripts/data/` - Data management scripts

---

**Parent README**: [scripts/README.md](../README.md)
