# EHS Enforcement Deployment Guide (Current)

**Last Updated:** 2025-10-15
**Production URL:** https://legal.sertantai.com
**Production Status:** ✅ Running on shared infrastructure

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Current Architecture](#current-architecture)
3. [Local Development Environment](#local-development-environment)
4. [Deployment Workflow](#deployment-workflow)
5. [Database Management](#database-management)
6. [Monitoring & Health Checks](#monitoring--health-checks)
7. [Troubleshooting](#troubleshooting)
8. [Maintenance Tasks](#maintenance-tasks)
9. [Deployment Checklist](#deployment-checklist)

---

## Quick Reference

### Production Infrastructure
- **Server:** Digital Ocean droplet (sertantai)
- **Infrastructure Repo:** `~/infrastructure/docker` on server
- **URL:** https://legal.sertantai.com
- **Port:** 4002 (internal, proxied by nginx)
- **Container Name:** `ehs_enforcement_app`
- **Network:** `infra_network` (shared)
- **Database:** `ehs_enforcement_prod` (on `shared_postgres`)

### Common Commands

```bash
# Build production image locally
docker build -t ghcr.io/shotleybuilder/ehs-enforcement:latest .

# Push to GitHub Container Registry
docker push ghcr.io/shotleybuilder/ehs-enforcement:latest

# SSH to production server
ssh sertantai

# On server: Deploy
cd ~/infrastructure/docker
docker compose pull ehs-enforcement
docker compose up -d ehs-enforcement

# Watch logs
docker compose logs -f ehs-enforcement

# Run migrations
docker compose exec ehs-enforcement /app/bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"

# Check status
docker compose exec ehs-enforcement /app/bin/ehs_enforcement eval "EhsEnforcement.Release.status"
```

---

## Current Architecture

### Shared Infrastructure (Production)

```
Internet (HTTPS)
    ↓
Nginx Reverse Proxy (:80, :443)
    ↓ legal.sertantai.com
EHS Enforcement App (:4002 internal)
    ↓
Shared PostgreSQL (:5432)
Shared Redis (:6379)
```

### Container Configuration

**Image:** `ghcr.io/shotleybuilder/ehs-enforcement:latest`

**Environment Variables (from infrastructure/.env):**
```bash
DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres/ehs_enforcement_prod
PHX_HOST=legal.sertantai.com
SECRET_KEY_BASE=${EHS_SECRET_KEY_BASE}
GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID}
GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET}
GITHUB_REDIRECT_URI=${GITHUB_REDIRECT_URI}
TOKEN_SIGNING_SECRET=${TOKEN_SIGNING_SECRET}
PHX_SERVER=true
POOL_SIZE=10
AT_UK_E_API_KEY=${AT_UK_E_API_KEY}
```

**Resource Limits:**
- Memory limit: 1GB
- Memory reservation: 512MB
- ERL_MAX_PORTS: 1024
- ERL_MAX_ETS_TABLES: 64

**Health Check:**
- Endpoint: `http://localhost:4002/health`
- Interval: 30 seconds
- Timeout: 10 seconds
- Start period: 60 seconds
- Retries: 3

---

## Local Development Environment

The local development environment mirrors production configuration to prevent deployment issues.

**Three Development Modes:**
- **Mode 1 (Fast):** Phoenix on host with Docker services - for daily development with hot reload
- **Mode 2 (Container):** Full Docker stack - for testing production builds before deployment
- **Mode 3 (Integration):** Full stack with Baserow - for integration testing

**For detailed setup instructions, commands, and troubleshooting**, see:
- **[DOCKER_DEV_GUIDE.md](./DOCKER_DEV_GUIDE.md)** - Complete development environment guide

**Pre-Deployment Testing Workflow:**
```bash
# Always test in Mode 2 (container) before deploying to production
./scripts/deployment/build.sh           # Build production image
./scripts/deployment/test-container.sh  # Test locally
./scripts/deployment/push.sh            # Push to GHCR
./scripts/deployment/deploy-prod.sh     # Deploy to production
```

---

## Deployment Workflow

### Step 1: Local Development

Work on your local machine as usual:

```bash
cd ~/Desktop/ehs_enforcement

# Daily development
./scripts/ehs-dev.sh

# Make your changes, test locally
mix test
```

### Step 2: Build Docker Image

From your local machine:

```bash
cd ~/Desktop/ehs_enforcement

# Build the production Docker image
# Note: No -f flag needed! We renamed Dockerfile.phoenix → Dockerfile
docker build -t ghcr.io/shotleybuilder/ehs-enforcement:latest .

# Verify the build
docker images | grep ehs-enforcement
```

**Build time:** ~5-10 minutes (first time), ~2-5 minutes (cached)

### Step 3: Push to GitHub Container Registry

```bash
# Push to GHCR
docker push ghcr.io/shotleybuilder/ehs-enforcement:latest
```

**Note:** Ensure you're logged in to GHCR:
```bash
# If not logged in:
echo $GITHUB_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

### Step 4: Deploy to Production

SSH to the production server:

```bash
ssh sertantai
cd ~/infrastructure/docker
```

**Check current status:**
```bash
# See what's running
docker compose ps

# Check current version/status
docker compose logs --tail=20 ehs-enforcement
```

**Pull and deploy new image:**
```bash
# Pull the latest image
docker compose pull ehs-enforcement

# Check if migrations are needed (IMPORTANT!)
docker compose exec ehs-enforcement /app/bin/ehs_enforcement eval "EhsEnforcement.Release.status"

# If migrations pending, run them:
docker compose exec ehs-enforcement /app/bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"

# Restart with new image (brief downtime ~2-5 seconds)
docker compose up -d ehs-enforcement

# Watch startup
docker compose logs -f ehs-enforcement
```

### Step 5: Verify Deployment

**Success indicators:**
```
✓ Container started
✓ [info] Running EhsEnforcementWeb.Endpoint with Bandit at :::4002
✓ [info] Access EhsEnforcementWeb.Endpoint at https://legal.sertantai.com
✓ [info] GET /health
✓ [info] Sent 200 in 2ms
```

**Test the application:**
```bash
# From server
curl http://localhost:4002/health

# From your machine
curl https://legal.sertantai.com/health
```

**Expected health response:**
```json
{
  "status": "ok",
  "timestamp": "2025-10-14T20:18:24.810Z",
  "version": "0.1.0",
  "environment": "prod",
  "database": "connected"
}
```

---

## Database Management

### Migrations

The application uses both standard Ecto migrations and Ash-generated migrations. Both are handled together.

**Run migrations:**
```bash
# On production server
cd ~/infrastructure/docker
docker compose exec ehs-enforcement /app/bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"
```

**Check migration status:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement eval "EhsEnforcement.Release.status"
```

**Output example:**
```
=== EHS Enforcement Release Status ===
Application: ehs_enforcement
Environment: prod

✓ Database EhsEnforcement.Repo: Connected

=== Migration Status ===
Repository: EhsEnforcement.Repo
  ✓ 20250816080001 simple_remove_violations_table
  ✓ 20250816083052 drop_offence_breaches_column
  ✓ 20250816084247 drop_case_breach_columns
  ✓ 20250816090000 remove_breaches_table_after_consolidation

Running Ash migrations...
✓ Loaded Ash domain: EhsEnforcement.Accounts
✓ Loaded Ash domain: EhsEnforcement.Configuration
✓ Loaded Ash domain: EhsEnforcement.Enforcement
✓ Loaded Ash domain: EhsEnforcement.Events
✓ Loaded Ash domain: EhsEnforcement.Scraping
✓ Ash domains loaded successfully
```

### Ash Framework Considerations

This application uses [Ash Framework](https://ash-hq.org/) for data modeling and business logic.

**Ash Domains:**
- `EhsEnforcement.Accounts` - User authentication
- `EhsEnforcement.Configuration` - App configuration
- `EhsEnforcement.Enforcement` - Core enforcement data
- `EhsEnforcement.Events` - Event tracking
- `EhsEnforcement.Scraping` - Web scraping coordination

**Important:** Ash resource changes must generate migrations in development:
```bash
# In development (before deployment)
mix ash.codegen --check    # Generate migrations
mix ash.migrate           # Apply and test locally
git add priv/resource_snapshots/  # Commit snapshots!
```

**Production automatically runs both:**
- Standard Ecto migrations
- Ash-generated migrations

### Database Access

**Connect to production database:**
```bash
# From production server
cd ~/infrastructure/docker
docker compose exec postgres psql -U postgres -d ehs_enforcement_prod
```

**Common queries:**
```sql
-- Check table sizes
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Check row counts
SELECT
    schemaname,
    tablename,
    n_live_tup as rows
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;

-- Check active connections
SELECT count(*) FROM pg_stat_activity WHERE datname = 'ehs_enforcement_prod';
```

### Backups

**Backup location:** `~/infrastructure/backups/` on server

**Manual backup:**
```bash
# On production server
cd ~/infrastructure/docker
docker compose exec postgres pg_dump -U postgres ehs_enforcement_prod | gzip > ../backups/backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

**Restore from backup:**
```bash
# Stop app first
docker compose stop ehs-enforcement

# Restore
gunzip -c ../backups/backup_YYYYMMDD_HHMMSS.sql.gz | \
  docker compose exec -T postgres psql -U postgres ehs_enforcement_prod

# Restart app
docker compose start ehs-enforcement
```

---

## Monitoring & Health Checks

### Health Endpoint

**URL:** https://legal.sertantai.com/health

**Features:**
- Database connectivity check
- Application version
- Environment info
- Response time monitoring

**Health check logic:**
- Returns 200 OK if database is connected
- Returns 503 Service Unavailable if database is down
- Includes database query test

### Container Health

**Check container health:**
```bash
# On server
docker compose ps ehs-enforcement
```

**Healthy output:**
```
NAME                  STATUS              HEALTH
ehs_enforcement_app   Up 5 minutes        healthy
```

**View health check logs:**
```bash
docker compose logs ehs-enforcement | grep health
```

### Log Monitoring

**View application logs:**
```bash
# Real-time logs
docker compose logs -f ehs-enforcement

# Last 100 lines
docker compose logs --tail=100 ehs-enforcement

# Filter for errors
docker compose logs ehs-enforcement | grep -i error

# Filter for specific pattern
docker compose logs ehs-enforcement | grep "GET /health"
```

**Important log patterns:**
- `Running EhsEnforcementWeb.Endpoint` - Server started
- `GET /health` - Health checks
- `Migrations already up` - Database current
- `Ash domains loaded successfully` - Ash working

---

## Troubleshooting

### Container Won't Start

**Check container status:**
```bash
docker compose ps ehs-enforcement
docker compose logs ehs-enforcement
```

**Common issues:**

1. **Missing environment variables:**
```bash
docker compose exec ehs-enforcement env | grep -E "(SECRET_KEY_BASE|DATABASE_URL|PHX_HOST)"
```

2. **Database connection failed:**
```bash
# Check shared postgres is running
docker compose ps postgres

# Test database connectivity
docker compose exec postgres pg_isready -U postgres

# Check database logs
docker compose logs postgres
```

3. **Port already in use:**
```bash
# Check what's using port 4002
docker compose ps | grep 4002
```

4. **Out of memory:**
```bash
# Check container resources
docker stats ehs_enforcement_app
```

### Ash Framework Issues

**Ash domain loading failures:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement eval "
domains = [
  EhsEnforcement.Accounts,
  EhsEnforcement.Configuration,
  EhsEnforcement.Enforcement,
  EhsEnforcement.Events,
  EhsEnforcement.Scraping
]
for domain <- domains do
  try do
    Code.ensure_loaded(domain)
    IO.puts(\"✓ #{inspect(domain)} loaded\")
  rescue
    error -> IO.puts(\"✗ #{inspect(domain)} failed: #{inspect(error)}\")
  end
end
"
```

**Test Ash operations:**
```bash
docker compose exec ehs-enforcement /app/bin/ehs_enforcement eval "
case Ash.read(EhsEnforcement.Enforcement.Agency) do
  {:ok, agencies} -> IO.puts(\"✓ Found #{length(agencies)} agencies\")
  {:error, error} -> IO.puts(\"✗ Error: #{inspect(error)}\")
end
"
```

### Rollback Deployment

**If new deployment fails:**

```bash
# Option 1: Restart current container (no image change)
docker compose restart ehs-enforcement

# Option 2: Revert to previous image (if tagged)
# First, check available tags on GHCR
# Then pull specific version:
docker pull ghcr.io/shotleybuilder/ehs-enforcement:previous-tag
# Update docker-compose.yml temporarily to use that tag
# Then:
docker compose up -d ehs-enforcement

# Option 3: Rebuild from known good commit
# On your local machine:
git checkout <good-commit-hash>
docker build -t ghcr.io/shotleybuilder/ehs-enforcement:rollback .
docker push ghcr.io/shotleybuilder/ehs-enforcement:rollback
# Then on server, update image tag and restart
```

### Network Issues

**Check container networking:**
```bash
# Verify container is on infra_network
docker network inspect infra_network | grep ehs_enforcement

# Check if container can reach postgres
docker compose exec ehs-enforcement ping postgres

# Check if nginx can reach app
docker compose exec nginx_proxy wget -O- http://ehs-enforcement:4002/health
```

### Development Environment Issues

**For development environment troubleshooting**, see [DOCKER_DEV_GUIDE.md](./DOCKER_DEV_GUIDE.md#troubleshooting) which covers:
- Port conflicts
- Database connection issues
- Container build failures
- GitHub OAuth setup
- Hot reload issues

---

## Maintenance Tasks

### Daily
- [ ] Monitor health endpoint: `curl https://legal.sertantai.com/health`
- [ ] Check container status: `docker compose ps`
- [ ] Review error logs: `docker compose logs --tail=100 ehs-enforcement | grep -i error`

### Weekly
- [ ] Review full logs: `docker compose logs --tail=500 ehs-enforcement`
- [ ] Check database size and connections (see Database Access section)
- [ ] Verify backups exist: `ls -lh ~/infrastructure/backups/`
- [ ] Check disk space: `df -h`

### Monthly
- [ ] Update base images: `docker compose pull`
- [ ] Database maintenance: `docker compose exec postgres psql -U postgres ehs_enforcement_prod -c "VACUUM ANALYZE;"`
- [ ] Review and clean old backups: `find ~/infrastructure/backups -name "*.sql.gz" -mtime +90 -delete`
- [ ] Review container resource usage: `docker stats ehs_enforcement_app`

### Before Major Updates
- [ ] Create database backup
- [ ] Test locally in container mode first
- [ ] Check for Ash resource snapshot changes
- [ ] Review migration files
- [ ] Deploy during low-traffic period

---

## Support & Resources

### Documentation
- **Infrastructure Repo:** `~/infrastructure/` on sertantai server
- **Nginx Config:** `~/infrastructure/nginx/conf.d/ehs-enforcement.conf`
- **Production Docker Compose:** `~/infrastructure/docker/docker-compose.yml`
- **Docker Dev Guide:** [DOCKER_DEV_GUIDE.md](../../../../DOCKER_DEV_GUIDE.md)
- **Deployment Scripts:** `scripts/deployment/README.md`
- **Future Enhancements:** [DEPLOYMENT_FUTURE.md](../plan/DEPLOYMENT_FUTURE.md)

### Ash Framework Resources
- [Ash Documentation](https://ash-hq.org/)
- [Ash Forum](https://elixirforum.com/c/ash-framework/123)
- [Ash GitHub](https://github.com/ash-hq/ash)

### Key Contacts
- **Repository:** https://github.com/shotleybuilder/ehs_enforcement
- **Infrastructure Repo:** https://github.com/shotleybuilder/sertantai-stack
- **Production Server:** sertantai droplet (Digital Ocean)

---

## Deployment Checklist

Use this before each deployment:

### Pre-Deployment
- [ ] All tests passing locally: `mix test`
- [ ] Ash codegen complete: `mix ash.codegen --check`
- [ ] Migrations tested locally: `mix ash.migrate`
- [ ] Resource snapshots committed: `git status priv/resource_snapshots/`
- [ ] Code reviewed and merged to main
- [ ] Database backup created (if schema changes)

### Build & Push
- [ ] Docker image built: `docker build -t ghcr.io/shotleybuilder/ehs-enforcement:latest .`
- [ ] Build completed without errors
- [ ] Image pushed to GHCR: `docker push ghcr.io/shotleybuilder/ehs-enforcement:latest`

### Deployment
- [ ] SSH to server: `ssh sertantai`
- [ ] Navigate to infrastructure: `cd ~/infrastructure/docker`
- [ ] Check current status: `docker compose ps`
- [ ] Pull new image: `docker compose pull ehs-enforcement`
- [ ] Check for migrations: `docker compose exec ehs-enforcement /app/bin/ehs_enforcement eval "EhsEnforcement.Release.status"`
- [ ] Run migrations if needed: `docker compose exec ehs-enforcement /app/bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"`
- [ ] Deploy: `docker compose up -d ehs-enforcement`

### Post-Deployment
- [ ] Watch logs: `docker compose logs -f ehs-enforcement`
- [ ] Verify startup: Look for "Running EhsEnforcementWeb.Endpoint"
- [ ] Check health: `curl https://legal.sertantai.com/health`
- [ ] Test application: Visit https://legal.sertantai.com
- [ ] Monitor for 5-10 minutes
- [ ] Check error logs: `docker compose logs ehs-enforcement | grep -i error`

### If Issues Occur
- [ ] Review logs for errors
- [ ] Check database connectivity
- [ ] Verify environment variables
- [ ] Consider rollback if critical issues

---

**Remember:** Production is working well. These improvements are about making the deployment process easier and more repeatable, not fixing broken things.

**Last Successful Deployment:** 2025-10-14 20:18 UTC ✅
