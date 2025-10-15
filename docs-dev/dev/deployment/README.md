# Deployment Documentation

This directory contains all deployment-related documentation for the EHS Enforcement project.

**Last Updated:** 2025-10-15
**Status:** ✅ Production deployed and running at https://legal.sertantai.com

---

## 📁 Directory Structure

### `current/` - Active Deployment Documentation

**Use these for current deployment procedures and production management.**

- **[DEPLOYMENT_CURRENT.md](./current/DEPLOYMENT_CURRENT.md)** ⭐ **START HERE**
  - Complete production deployment guide
  - Current deployment workflow (build → test → push → deploy)
  - Database management and migrations
  - Health checks and monitoring
  - Troubleshooting guide (production)
  - **Use for:** Day-to-day deployment operations

- **[DOCKER_DEV_GUIDE.md](./current/DOCKER_DEV_GUIDE.md)** - Development environment guide
  - Three development modes (fast, container, integration)
  - Complete setup instructions and commands
  - Environment variables configuration
  - Development troubleshooting
  - **Use for:** Setting up and using the local development environment

### `reference/` - Specialized Topics

**Use these for specific integration or feature deployments.**

- **[AIRTABLE_SYNC_DEPLOYMENT.md](./reference/AIRTABLE_SYNC_DEPLOYMENT.md)**
  - Airtable integration deployment
  - Data sync configuration
  - API setup and credentials
  - **Use for:** Setting up or troubleshooting Airtable integration

- **[DEPLOYMENT_WITH-SCRIPTS.md](./reference/DEPLOYMENT_WITH-SCRIPTS.md)**
  - Detailed documentation about deployment scripts
  - Script usage and examples
  - Alternative deployment methods
  - **Use for:** Understanding the deployment automation scripts

- **[PG_TRGM_PRODUCTION_DEPLOYMENT.md](./reference/PG_TRGM_PRODUCTION_DEPLOYMENT.md)**
  - PostgreSQL pg_trgm extension deployment
  - Text search functionality setup
  - **Use for:** Setting up PostgreSQL text search features

### `plan/` - Future Enhancements

**Optional improvements and long-term planning.**

- **[DEPLOYMENT_FUTURE.md](./plan/DEPLOYMENT_FUTURE.md)**
  - Optional development wrapper scripts
  - CI/CD pipeline automation plans
  - Staging environment setup
  - Monitoring and metrics options
  - Long-term infrastructure improvements
  - **Use for:** Planning future enhancements (all optional)

### `archive/` - Historical Documentation

**Reference only. These approaches are superseded by current implementation.**

- `DEPLOYMENT_MIGRATION_PLAN_OLD.md` - **Migration completion record (2025-10-13 to 2025-10-15)**
  - Historical record of infrastructure migration and dev environment alignment
  - Reference for understanding why current infrastructure was chosen
  - Lessons learned and technical decisions made
- `DEPLOYMENT-DOCKER-REGISTRY.md` - Old Docker registry setup
- `DEPLOYMENT-DOCKER-REGISTRY-CHECKLIST.md` - Registry checklist
- `DEPLOYMENT-GITHUB-ACTIONS.md` - GitHub Actions approach (not implemented)
- `DEPLOYMENT-GITHUB-CONTAINER-REGISTRY.md` - GHCR setup details
- `DEPLOYMENT-PROS-CONS.md` - Deployment options comparison
- `DEPLOYMENT_OLD.md` - Original deployment documentation
- `UPGRADE_DEPLOYMENT.md` - Old upgrade procedures

**Note:** These documents are kept for historical reference but do not reflect current practices.

---

## 🚀 Quick Start

### For New Team Members

1. **Read** [DEPLOYMENT_CURRENT.md](./current/DEPLOYMENT_CURRENT.md) to understand current deployment
2. **Review** production URL: https://legal.sertantai.com
3. **Check** deployment scripts in `../../scripts/deployment/`

### For Deploying Code

```bash
# Complete deployment workflow
./scripts/deployment/build.sh           # Build production image
./scripts/deployment/test-container.sh  # Test locally
./scripts/deployment/push.sh            # Push to GHCR
./scripts/deployment/deploy-prod.sh     # Deploy to production
```

See [DEPLOYMENT_CURRENT.md](./current/DEPLOYMENT_CURRENT.md) for detailed instructions.

### For Local Development

See development documentation:
- [DOCKER_DEV_GUIDE.md](./current/DOCKER_DEV_GUIDE.md) - Docker development guide (in `current/`)
- Root [README.md](../../../README.md) - Development setup
- `docker-compose.dev.yml` - Development environment (project root)

---

## 📊 Current Infrastructure

### Production Environment

- **Platform:** Digital Ocean droplet (sertantai)
- **URL:** https://legal.sertantai.com
- **Port:** 4002 (internal)
- **Container:** `ehs_enforcement_app`
- **Image:** `ghcr.io/shotleybuilder/ehs-enforcement:latest`
- **Database:** PostgreSQL 16 (shared_postgres)
- **Cache:** Redis 7 (shared_redis)

### Tech Stack

- **Framework:** Phoenix 1.7+ with LiveView
- **Data Layer:** Ash Framework 3.0+
- **Database:** PostgreSQL 16
- **Deployment:** Docker + Docker Compose
- **Registry:** GitHub Container Registry (GHCR)
- **Proxy:** Nginx with Let's Encrypt SSL

---

## 🔗 Related Documentation

### In This Repository
- [Root README.md](../../../README.md) - Project overview and development setup
- [DOCKER_DEV_GUIDE.md](./current/DOCKER_DEV_GUIDE.md) - Local container development
- [CLAUDE.md](../../../CLAUDE.md) - Ash Framework patterns and conventions
- [scripts/deployment/](../../../scripts/deployment/) - Deployment automation scripts

### External Infrastructure
- Infrastructure repository: `~/infrastructure/docker` on production server
- Nginx configuration: `~/infrastructure/nginx/conf.d/ehs-enforcement.conf`

---

## 📈 Deployment History

- **2025-10-13:** Production migrated to shared infrastructure
- **2025-10-14:** Deployment scripts created and tested
- **2025-10-15:** Local development environment aligned with production
- **2025-10-15:** Documentation organized (current/reference/plan/archive structure)
- **2025-10-15:** Documentation consolidated - DEPLOYMENT_CURRENT.md is now the single source of truth

---

## 🆘 Getting Help

### Common Tasks
- **Deploy to production:** See [DEPLOYMENT_CURRENT.md](./current/DEPLOYMENT_CURRENT.md)
- **Run migrations:** `docker compose exec ehs-enforcement /app/bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"`
- **Check health:** `curl https://legal.sertantai.com/health`
- **View logs:** `docker compose logs -f ehs-enforcement`

### Troubleshooting
See the Troubleshooting section in [DEPLOYMENT_CURRENT.md](./current/DEPLOYMENT_CURRENT.md#troubleshooting)

### Support
- **Issues:** https://github.com/shotleybuilder/ehs_enforcement/issues
- **Production Server:** SSH to `sertantai` droplet
- **Deployment Path:** `~/infrastructure/docker`

---

## 📝 Document Maintenance

This README and the deployment documentation structure should be updated when:
- Deployment procedures change
- New infrastructure is added
- Tools or scripts are updated
- Historical documents are no longer relevant

**Maintainers:** Keep `current/` documents up to date and move superseded docs to `archive/`.
