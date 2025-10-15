# Infrastructure Comparison: Current vs. Target

**Date:** 2025-10-13
**Purpose:** Compare EHS Enforcement standalone deployment with infrastructure-centric approach

---

## Overview

This document provides a side-by-side comparison of the current EHS Enforcement deployment architecture with the target infrastructure-centric setup managed in `~/Desktop/infrastructure`.

---

## Deployment Architecture

### Current Setup (Standalone)

**Location:** `/opt/ehs_enforcement` on Digital Ocean droplet

```yaml
Services:
  - PostgreSQL 16-alpine (dedicated)
  - Phoenix App (EHS Enforcement)

Network: ehs_network (isolated)
Volumes:
  - postgres_data (dedicated)

Exposed Ports:
  - Application: 4002 (or proxied externally)
  - Database: None (internal only)

Compose File: docker-compose.prod.yml
Environment: .env.prod
```

### Target Setup (Infrastructure-Centric)

**Location:** `~/infrastructure` on Digital Ocean droplet

```yaml
Services:
  - PostgreSQL 16-alpine (shared)
  - Redis 7-alpine (shared)
  - Nginx (reverse proxy)
  - Phoenix App (EHS Enforcement)
  - Baserow (optional, profile)
  - n8n (optional, profile)

Network: infra_network (shared)
Volumes:
  - postgres_data (shared across apps)
  - redis_data (shared)
  - baserow_data, baserow_media (optional)
  - n8n_data (optional)

Exposed Ports:
  - HTTP: 80 (nginx)
  - HTTPS: 443 (nginx)
  - Internal: Apps communicate via docker network

Compose File: docker/docker-compose.yml
Environment: docker/.env
```

---

## Detailed Comparison Table

| Aspect | Current (Standalone) | Target (Infrastructure) | Impact |
|--------|---------------------|------------------------|--------|
| **Database** | Dedicated PostgreSQL | Shared PostgreSQL | Reduced resource usage |
| **Redis** | Not present | Shared Redis available | Enables caching features |
| **Reverse Proxy** | None or external | Nginx with SSL | Centralized routing |
| **SSL Certificates** | External management | Certbot + Nginx | Simplified renewals |
| **Network** | `ehs_network` | `infra_network` | Shared with other apps |
| **Port Exposure** | Direct (4002) | Through proxy (80/443) | Better security |
| **Environment** | `.env.prod` file | `.env` with inline vars | Consistent patterns |
| **Deployment** | `scripts/deploy.sh` | `docker compose pull/up` | Simplified process |
| **Image Build** | Optional local build | Pull from GHCR only | Faster deployments |
| **Resource Limits** | None specified | 512MB-1GB memory | Prevents resource exhaustion |
| **Health Checks** | Via curl to :4002 | Via curl to :4002 | Same |
| **Backup Strategy** | Via script | Via infrastructure script | Centralized backups |
| **Service Discovery** | N/A | Via docker network names | Enables inter-app communication |
| **Scalability** | Add new compose | Add service to existing | Much easier expansion |
| **Monitoring** | Per-service | Centralized logging | Better visibility |

---

## Environment Variables Comparison

### Current (.env.prod) - 50+ variables

```bash
# Database - 8 variables
DATABASE_URL, DB_USERNAME, DB_PASSWORD, DB_HOSTNAME, DB_PORT, DB_NAME, POOL_SIZE, ECTO_IPV6

# Phoenix - 4 variables
SECRET_KEY_BASE, PHX_HOST, PORT, PHX_SERVER

# GitHub OAuth - 7 variables
GITHUB_CLIENT_ID, GITHUB_CLIENT_SECRET, GITHUB_REDIRECT_URI,
GITHUB_REPO_OWNER, GITHUB_REPO_NAME, GITHUB_ACCESS_TOKEN, GITHUB_ALLOWED_USERS

# Security - 1 variable
TOKEN_SIGNING_SECRET

# Airtable - 3 variables
AT_UK_E_API_KEY, AIRTABLE_API_KEY, AIRTABLE_BASE_ID

# Optional: SSL, DNS, SMTP, Telemetry - 10+ variables
```

### Target (.env) - Organized by service

```bash
# Shared Infrastructure - 2 variables
POSTGRES_USER, POSTGRES_PASSWORD

# EHS Enforcement - 15+ variables
EHS_VERSION, PHX_HOST, SECRET_KEY_BASE, TOKEN_SIGNING_SECRET, PHX_SERVER, POOL_SIZE,
GITHUB_CLIENT_ID, GITHUB_CLIENT_SECRET, GITHUB_REDIRECT_URI,
GITHUB_REPO_OWNER, GITHUB_REPO_NAME, GITHUB_ACCESS_TOKEN, GITHUB_ALLOWED_USERS,
AT_UK_E_API_KEY, PORT

# Baserow (future) - 3 variables
BASEROW_PUBLIC_URL, BASEROW_SECRET_KEY, BASEROW_PREVENT_POSTGRESQL_DATA_SYNC_CONNECTION_TO_DATABASE

# n8n (future) - 1 variable
N8N_HOST
```

**Key Difference:** Target uses `DATABASE_URL` constructed in docker-compose.yml from `POSTGRES_*` variables, eliminating redundant DB variables.

---

## Docker Compose Configuration Comparison

### Current (docker-compose.prod.yml)

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: ehs_enforcement_postgres_prod
    env_file:
      - .env.prod
    environment:
      POSTGRES_DB: ${DATABASE_NAME:-ehs_enforcement_prod}
      POSTGRES_USER: ${DATABASE_USER:-postgres}
      POSTGRES_PASSWORD: ${DATABASE_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    networks:
      - ehs_network

  app:
    image: ghcr.io/shotleybuilder/ehs-enforcement:latest
    container_name: ehs_enforcement_app
    deploy:
      resources:
        limits:
          memory: 1g
        reservations:
          memory: 512m
    env_file:
      - .env.prod
    environment:
      ERL_MAX_PORTS: "1024"
      ERL_MAX_ETS_TABLES: "64"
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - ehs_network

networks:
  ehs_network:
    driver: bridge

volumes:
  postgres_data:
```

**Characteristics:**
- Uses `env_file` for environment variables
- Dedicated network and volumes
- No resource sharing
- No reverse proxy

### Target (docker/docker-compose.yml)

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: shared_postgres
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - PGDATA=/var/lib/postgresql/data/pgdata
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ../data/postgres-init:/docker-entrypoint-initdb.d
      - ../backups:/backups
    networks:
      - infra_network

  redis:
    image: redis:7-alpine
    container_name: shared_redis
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - infra_network

  nginx:
    image: nginx:alpine
    container_name: nginx_proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ../nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ../nginx/conf.d:/etc/nginx/conf.d:ro
      - ../nginx/ssl:/etc/nginx/ssl:ro
    networks:
      - infra_network

  ehs-enforcement:
    image: ghcr.io/shotleybuilder/ehs-enforcement:${EHS_VERSION:-latest}
    container_name: ehs_enforcement_app
    deploy:
      resources:
        limits:
          memory: 1g
        reservations:
          memory: 512m
    environment:
      - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres/ehs_enforcement_prod
      - PHX_HOST=${PHX_HOST}
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      # ... all env vars explicitly listed
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - infra_network

  baserow:
    profiles: ["baserow"]
    # ... baserow config

  n8n:
    profiles: ["n8n"]
    # ... n8n config

networks:
  infra_network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  baserow_data:
  baserow_media:
  n8n_data:
```

**Characteristics:**
- Environment variables explicitly listed (no env_file)
- Shared network and resources
- Nginx reverse proxy included
- Multiple apps supported
- Optional services via profiles

---

## Nginx Configuration

### Current Setup

No nginx configuration in EHS repository. Either:
- No reverse proxy (direct access)
- External reverse proxy managed separately

### Target Setup

**Main nginx.conf:**
- Worker connections: 1024
- Client max body size: 100M
- Gzip compression enabled
- Includes subdomain configs from `/etc/nginx/conf.d/*.conf`

**Subdomain config (nginx/conf.d/ehs-enforcement.conf):**

```nginx
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name legal.sertantai.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS server
server {
    listen 443 ssl;
    server_name legal.sertantai.com;

    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;

    location / {
        proxy_pass http://ehs-enforcement:4002;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Phoenix WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

**Benefits:**
- Automatic HTTPS redirect
- SSL termination at proxy level
- WebSocket support for LiveView
- Easy to add more subdomains
- Centralized certificate management

---

## Deployment Process Comparison

### Current Process (deploy.sh)

```bash
1. Check prerequisites (docker, docker-compose)
2. Validate environment variables
3. Create database backup
4. Build Docker images (optional)
5. Stop existing containers
6. Start new containers
7. Wait for database
8. Run migrations (bin/migrate)
9. Health check
10. Show status
11. Cleanup old images
```

**Characteristics:**
- Automated via script
- Builds locally (optional)
- Includes backup
- Runs migrations automatically
- ~5-10 minutes

### Target Process

```bash
# On server
cd ~/infrastructure/docker

# Pull new image
docker compose pull ehs-enforcement

# Restart with new image
docker compose up -d ehs-enforcement

# Run migrations (if needed)
docker compose exec ehs-enforcement \
  /app/bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"

# Check logs
docker compose logs -f ehs-enforcement
```

**Characteristics:**
- Simple pull and restart
- No local building
- Manual migration step
- Faster deployment (~2-3 minutes)
- Consistent with other apps in infrastructure

---

## Resource Usage Comparison

### Current Setup

```
Container: ehs_enforcement_app
  Memory: 512MB-1GB (limit: 1GB)
  CPU: Shared (no limit)

Container: ehs_enforcement_postgres_prod
  Memory: ~256MB typical
  CPU: Shared (no limit)

Total: ~768MB-1.25GB
```

### Target Setup

```
Container: ehs_enforcement_app
  Memory: 512MB-1GB (limit: 1GB)
  CPU: Shared (no limit)

Container: shared_postgres (all apps)
  Memory: ~300MB typical (shared)
  CPU: Shared (no limit)

Container: shared_redis
  Memory: ~50MB typical
  CPU: Minimal

Container: nginx_proxy
  Memory: ~10MB typical
  CPU: Minimal

Total EHS-specific: ~512MB-1GB
Total infrastructure: ~360MB (shared)
Overall: ~900MB-1.36GB
```

**Analysis:**
- Slightly higher total memory usage initially
- More efficient with multiple apps (shared postgres/redis)
- Better resource utilization overall

---

## Backup Strategy Comparison

### Current Backup

**Location:** `scripts/backup.sh`

```bash
# Manual or scheduled backup
./scripts/backup.sh

# Creates:
backups/backup_YYYYMMDD_HHMMSS.sql.gz
```

**Features:**
- Database dump via pg_dump
- Gzip compression
- Timestamp naming
- Retention: Manual cleanup

### Target Backup

**Location:** `~/infrastructure/scripts/backup-ehs.sh`

```bash
# Scheduled backup (cron)
~/infrastructure/scripts/backup-ehs.sh

# Creates:
~/backups/ehs_db_YYYYMMDD_HHMMSS.sql.gz
```

**Features:**
- Database dump via pg_dump
- Gzip compression
- Timestamp naming
- Retention: 7 days automatic cleanup
- Centralized backup location
- Consistent with other app backups

---

## Pros and Cons Analysis

### Current Setup (Standalone)

**Pros:**
- ✅ Simple, self-contained
- ✅ Isolated from other services
- ✅ Easy to understand
- ✅ Dedicated resources
- ✅ Independent deployment

**Cons:**
- ❌ Resource duplication if adding more apps
- ❌ No SSL/proxy management
- ❌ Manual certificate renewals
- ❌ No shared infrastructure benefits
- ❌ Harder to add new services
- ❌ No centralized logging

### Target Setup (Infrastructure)

**Pros:**
- ✅ Shared resources (postgres, redis)
- ✅ Centralized SSL management
- ✅ Nginx reverse proxy included
- ✅ Easy to add more Phoenix apps
- ✅ Consistent deployment patterns
- ✅ Better prepared for scaling
- ✅ Centralized monitoring/logging
- ✅ Organized infrastructure repository

**Cons:**
- ❌ More complex initial setup
- ❌ Shared network dependencies
- ❌ Requires coordination for shared resources
- ❌ Single point of failure (shared postgres)
- ❌ More services to manage

---

## Migration Complexity Assessment

### Technical Complexity: **Medium**

**Factors:**
- Database migration is straightforward (pg_dump/restore)
- Environment variables need careful mapping
- Network changes are minor
- Nginx configuration is provided
- Rollback plan is clear

### Risk Level: **Low-Medium**

**Mitigations:**
- Comprehensive backup before migration
- Parallel deployment (old stays running)
- Clear rollback procedure
- Minimal downtime (< 5 minutes)
- Tested migration path from infrastructure docs

### Time Estimate: **4-6 hours total**

**Breakdown:**
- Preparation: 2-3 hours
- Backup: 30 minutes
- Infrastructure deployment: 1-2 hours
- Switchover: 15 minutes
- Validation: 30 minutes
- Cleanup: 30 minutes (after 48-72 hours monitoring)

---

## Recommendations

### Short-term (Migration Phase)

1. **Follow phased migration plan** from DEPLOYMENT_MIGRATION_PLAN.md
2. **Test infrastructure locally first** if possible
3. **Schedule migration during low-traffic period**
4. **Have team ready for monitoring** during and after migration
5. **Keep old deployment for 72 hours** before cleanup

### Medium-term (Post-Migration)

1. **Update CI/CD pipelines** for new deployment process
2. **Document new deployment procedures** for team
3. **Setup automated backups** via cron
4. **Configure monitoring/alerting** for new infrastructure
5. **Consider adding Baserow** for no-code database needs

### Long-term (Future Scaling)

1. **Add monitoring stack** (Prometheus + Grafana)
2. **Consider managed database** (Digital Ocean Managed PostgreSQL)
3. **Implement log aggregation** (Loki + Grafana)
4. **Add CI/CD integration** for automated deployments
5. **Plan for horizontal scaling** if traffic grows

---

## Conclusion

The migration from standalone to infrastructure-centric deployment offers significant benefits for future scaling and management, with reasonable complexity and low risk. The infrastructure project is well-designed and includes comprehensive documentation, making the migration straightforward.

### Key Takeaways

1. **Shared infrastructure enables efficient multi-app hosting**
2. **Migration complexity is medium but well-documented**
3. **Downtime can be minimized to < 5 minutes**
4. **Rollback plan is clear and tested**
5. **Long-term benefits outweigh short-term migration effort**

### Decision Points

- **Proceed with migration?** Recommended: Yes
- **Timing?** Schedule during low-traffic period
- **Team involvement?** 1-2 people for migration, team for validation
- **Monitoring period?** 48-72 hours before final cleanup

---

## Next Steps

1. ✅ **Review this comparison document**
2. ✅ **Read DEPLOYMENT_MIGRATION_PLAN.md**
3. [ ] **Schedule migration window**
4. [ ] **Assign migration lead**
5. [ ] **Prepare infrastructure repository** (Phase 1)
6. [ ] **Execute migration** (Phases 2-6)
7. [ ] **Monitor and validate** (Phase 7)
8. [ ] **Update documentation**
9. [ ] **Train team on new procedures**

---

**Document Version:** 1.0
**Last Updated:** 2025-10-13
**Status:** Final for Review
