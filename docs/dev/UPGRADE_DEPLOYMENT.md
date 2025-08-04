# EHS Enforcement Application Updates & Upgrades

This guide covers how to deploy newer versions of the EHS Enforcement application to production safely.

## Update Types

### 1. **Hot Updates** (Zero Downtime)
- Configuration changes
- Static asset updates
- Minor bug fixes without database changes

### 2. **Standard Updates** (Brief Downtime)
- Code updates with database migrations
- Dependency updates
- Feature additions

### 3. **Major Upgrades** (Planned Downtime)
- Elixir/Phoenix version upgrades
- Breaking database schema changes
- Major architectural changes

## Pre-Update Checklist

### Always Before Any Update:
```bash
# 1. Create database backup
./scripts/deploy.sh prod backup

# 2. Check current application status
docker-compose -f docker-compose.prod.yml ps
curl https://yourdomain.com/health

# 3. Review changes being deployed
git log --oneline HEAD..origin/main

# 4. Check for breaking changes in commits
git show --name-only HEAD..origin/main

# 5. Verify environment variables haven't changed
diff .env.example .env.prod
```

## Update Deployment Process

### Method 1: Using Deployment Script (Recommended)

```bash
# Standard update deployment
./scripts/deploy.sh prod

# The script automatically:
# - Creates database backup
# - Pulls latest code
# - Builds new Docker images
# - Runs migrations
# - Performs health checks
# - Rolls back on failure
```

### Method 2: Manual Step-by-Step

```bash
# 1. Navigate to application directory
cd /opt/ehs_enforcement

# 2. Create backup
mkdir -p backups
docker-compose -f docker-compose.prod.yml exec postgres pg_dump -U postgres ehs_enforcement_prod > backups/pre_update_$(date +%Y%m%d_%H%M%S).sql

# 3. Pull latest changes
git pull origin main

# 4. Check for new environment variables
diff .env.example .env.prod

# 5. Build new images
docker-compose -f docker-compose.prod.yml build --no-cache

# 6. Deploy with rolling update
docker-compose -f docker-compose.prod.yml up -d

# 7. Run migrations
docker-compose -f docker-compose.prod.yml exec app bin/migrate

# 8. Verify deployment
curl https://yourdomain.com/health
docker-compose -f docker-compose.prod.yml logs --tail=50 app
```

## Migration Handling

### Ash + Ecto Migrations

The application uses both Ash resources and standard Ecto migrations:

```bash
# Check for pending migrations
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement eval "EhsEnforcement.Release.migrate()"

# Manual migration steps if needed
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement remote

# In the remote shell:
EhsEnforcement.Release.migrate()
EhsEnforcement.Release.migrate_ash()
```

### Migration Safety Checks

```bash
# Before running migrations, check what will be applied
docker-compose -f docker-compose.prod.yml exec app mix ecto.migrations
docker-compose -f docker-compose.prod.yml exec app mix ash.codegen --check
```

## Rollback Procedures

### Quick Rollback (Last Working Version)

```bash
# 1. Stop current containers
docker-compose -f docker-compose.prod.yml down

# 2. Rollback to previous git commit
git log --oneline -10  # Find the commit hash
git reset --hard <previous-commit-hash>

# 3. Rebuild and deploy
docker-compose -f docker-compose.prod.yml build
docker-compose -f docker-compose.prod.yml up -d

# 4. Restore database if needed
# gunzip backups/backup_YYYYMMDD_HHMMSS.sql.gz
# docker-compose -f docker-compose.prod.yml exec -T postgres psql -U postgres ehs_enforcement_prod < backups/backup_YYYYMMDD_HHMMSS.sql
```

### Database Rollback

```bash
# Only if migrations need to be rolled back
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement eval "EhsEnforcement.Release.rollback(EhsEnforcement.Repo, <version>)"

# Or restore from backup
docker-compose -f docker-compose.prod.yml exec postgres dropdb -U postgres ehs_enforcement_prod
docker-compose -f docker-compose.prod.yml exec postgres createdb -U postgres ehs_enforcement_prod
gunzip -c backups/backup_YYYYMMDD_HHMMSS.sql.gz | docker-compose -f docker-compose.prod.yml exec -T postgres psql -U postgres ehs_enforcement_prod
```

## Zero-Downtime Deployments

For critical updates that need zero downtime:

### Blue-Green Deployment Strategy

```bash
# 1. Prepare second environment
cp docker-compose.prod.yml docker-compose.green.yml
# Edit ports in green compose file (4001 instead of 4000)

# 2. Deploy to green environment
docker-compose -f docker-compose.green.yml up -d

# 3. Test green environment
curl http://localhost:4001/health

# 4. Update load balancer to point to green
# (Update nginx upstream or DNS)

# 5. Stop blue environment
docker-compose -f docker-compose.prod.yml down
```

### Rolling Updates (Docker Swarm/Kubernetes)

For advanced setups, consider container orchestration:

```yaml
# docker-compose.swarm.yml
version: '3.8'
services:
  app:
    image: ehs_enforcement:latest
    deploy:
      replicas: 2
      update_config:
        parallelism: 1
        delay: 30s
        failure_action: rollback
      rollback_config:
        parallelism: 1
        delay: 30s
```

## Environment Variable Updates

### Adding New Variables

```bash
# 1. Update .env.prod with new variables
nano .env.prod

# 2. Restart containers to pick up new env vars
docker-compose -f docker-compose.prod.yml restart app

# 3. Verify new variables are loaded
docker-compose -f docker-compose.prod.yml exec app env | grep NEW_VAR
```

### Rotating Secrets

```bash
# 1. Generate new secrets
NEW_SECRET=$(mix phx.gen.secret)

# 2. Update environment file
sed -i "s/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$NEW_SECRET/" .env.prod

# 3. Rolling restart to avoid session disruption
docker-compose -f docker-compose.prod.yml restart app
```

## Dependency Updates

### Elixir/Phoenix Updates

```bash
# 1. Test in development first
mix deps.update --all
mix test

# 2. Update Dockerfile with new base image
# FROM hexpm/elixir:1.17.3-erlang-27.1.2-alpine-3.20.3

# 3. Build and test locally
docker build -t ehs_enforcement:test .

# 4. Deploy to staging first, then production
```

### Database Updates (PostgreSQL)

```bash
# 1. Create database backup
docker-compose -f docker-compose.prod.yml exec postgres pg_dump -U postgres ehs_enforcement_prod > backups/pre_pg_upgrade.sql

# 2. Update postgres image version in docker-compose.prod.yml
# postgres:16-alpine -> postgres:17-alpine

# 3. Stop containers
docker-compose -f docker-compose.prod.yml down

# 4. Backup data volume
docker run --rm -v ehs_enforcement_postgres_data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/postgres_data_$(date +%Y%m%d).tar.gz -C /data .

# 5. Start with new postgres version
docker-compose -f docker-compose.prod.yml up -d postgres

# 6. Test application connectivity
docker-compose -f docker-compose.prod.yml up -d app
curl https://yourdomain.com/health
```

## Monitoring During Updates

### Health Check Monitoring

```bash
# Continuous health monitoring during update
while true; do
  echo "$(date): $(curl -s -o /dev/null -w "%{http_code}" https://yourdomain.com/health)"
  sleep 5
done
```

### Log Monitoring

```bash
# Monitor application logs during update
docker-compose -f docker-compose.prod.yml logs -f app &

# Monitor database logs
docker-compose -f docker-compose.prod.yml logs -f postgres &
```

### Performance Monitoring

```bash
# Monitor resource usage
docker stats

# Monitor database connections
docker-compose -f docker-compose.prod.yml exec postgres psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
```

## Update Automation

### Automated Update Script

Create `scripts/update.sh`:

```bash
#!/bin/bash
set -e

echo "Starting automated update process..."

# Backup
./scripts/backup.sh

# Pull changes
git pull origin main

# Check for migration warnings
if git diff HEAD~1 --name-only | grep -q "priv/repo/migrations\|priv/resource_snapshots"; then
    echo "WARNING: Database migrations detected. Proceed? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Update cancelled"
        exit 1
    fi
fi

# Deploy
./scripts/deploy.sh prod

echo "Update completed successfully!"
```

### CI/CD Integration

For automated deployments with GitHub Actions:

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production
on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to server
        uses: appleboy/ssh-action@v0.1.7
        with:
          host: ${{ secrets.HOST }}
          username: ${{ secrets.USERNAME }}
          key: ${{ secrets.SSH_KEY }}
          script: |
            cd /opt/ehs_enforcement
            ./scripts/update.sh
```

## Best Practices

### 1. **Always Test Updates**
- Test in development environment first
- Use staging environment that mirrors production
- Run full test suite before deploying

### 2. **Gradual Rollouts**
- Deploy during low-traffic periods
- Monitor metrics closely after deployment
- Have rollback plan ready

### 3. **Communication**
- Notify users of planned maintenance
- Document all changes in CHANGELOG.md
- Keep deployment logs for troubleshooting

### 4. **Database Safety**
- Always backup before migrations
- Test migrations on copy of production data
- Use database migration safety tools

### 5. **Monitoring**
- Monitor application metrics during and after deployment
- Set up alerts for error rates and performance degradation
- Keep deployment scripts and documentation updated

## Emergency Procedures

### Application Down
```bash
# Quick restart
docker-compose -f docker-compose.prod.yml restart app

# Full restart with logs
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d
docker-compose -f docker-compose.prod.yml logs -f app
```

### Database Issues
```bash
# Check database status
docker-compose -f docker-compose.prod.yml exec postgres pg_isready

# Restart database
docker-compose -f docker-compose.prod.yml restart postgres

# Emergency database restore
# (Follow database rollback procedures above)
```

Remember: **When in doubt, rollback!** It's better to maintain service availability and plan a proper fix than to troubleshoot in production.