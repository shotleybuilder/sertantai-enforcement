# EHS Enforcement Deployment Guide (Scripted Workflow)

**Last Updated:** 2025-10-14
**Alternative to:** [DEPLOYMENT_CURRENT.md](./DEPLOYMENT_CURRENT.md) (manual workflow)
**Production URL:** https://legal.sertantai.com

---

## Overview

This guide describes the **scripted deployment workflow** using automation scripts. This is an alternative to the manual deployment process described in `DEPLOYMENT_CURRENT.md`.

**Benefits of scripted workflow:**
- ✅ Consistent, repeatable deployments
- ✅ Reduced human error
- ✅ Built-in validation and health checks
- ✅ Colored output and progress indicators
- ✅ Easier for team members to deploy

**When to use manual workflow:**
- First-time deployment
- Troubleshooting deployment issues
- Learning the deployment process
- Custom deployment scenarios

---

## Quick Start

### Complete deployment in 3 commands:

```bash
# 1. Build production image
./scripts/deployment/build.sh

# 2. Push to GitHub Container Registry
./scripts/deployment/push.sh

# 3. Deploy to production
./scripts/deployment/deploy-prod.sh --migrate --logs
```

---

## Table of Contents

1. [Available Scripts](#available-scripts)
2. [Standard Deployment Workflow](#standard-deployment-workflow)
3. [Script Reference](#script-reference)
4. [Advanced Usage](#advanced-usage)
5. [Troubleshooting](#troubleshooting)
6. [Comparison with Manual Workflow](#comparison-with-manual-workflow)

---

## Available Scripts

All scripts are located in `scripts/deployment/` directory:

| Script | Purpose | Prerequisites |
|--------|---------|---------------|
| `build.sh` | Build Docker image locally | Docker running |
| `push.sh` | Push image to GHCR | Built image, GHCR login |
| `deploy-prod.sh` | Deploy to production server | SSH access, pushed image |
| `test-container.sh` | Test container locally | Built image, docker-compose.dev.yml |

---

## Standard Deployment Workflow

### Step 1: Build Production Image

Build the Docker image locally:

```bash
cd ~/Desktop/ehs_enforcement
./scripts/deployment/build.sh
```

**Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EHS Enforcement - Docker Build
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Image: ghcr.io/shotleybuilder/ehs-enforcement:latest
Dockerfile: ./Dockerfile

Building Docker image...
[... build output ...]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Build complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Image: ghcr.io/shotleybuilder/ehs-enforcement:latest
Size: 512MB
ID: abc123def456

Next steps:
  → Test locally:  ./scripts/deployment/test-container.sh
  → Push to GHCR:  ./scripts/deployment/push.sh
```

**What it does:**
- ✅ Navigates to project root
- ✅ Validates Dockerfile exists
- ✅ Checks Docker is running
- ✅ Builds image with proper tagging
- ✅ Shows image size and ID
- ✅ Suggests next steps

**Build time:** ~5-10 minutes (first time), ~2-5 minutes (cached)

**⚠️ CRITICAL: Compile-Time Config Changes**

When you change compile-time configuration files like `config/prod.exs`, Docker's layer cache may prevent your changes from being included in the build. This happens because Docker caches the `COPY config/config.exs config/prod.exs` layer.

**Symptoms of cached config:**
- ✅ Application starts successfully
- ❌ Your configuration changes don't take effect
- ❌ Production behaves as if old config is still active
- ❌ No errors in logs (config just isn't updated)

**When to use `--no-cache`:**
- ✅ After changing `config/prod.exs` (compile-time config)
- ✅ After changing session cookie settings
- ✅ After changing SSL/force_ssl settings
- ✅ After changing compile-time endpoint configuration
- ✅ After changing any `Application.compile_env()` values

**How to force rebuild:**
```bash
# Option 1: Use build-cacheless.sh script (RECOMMENDED)
# First, clear Docker build cache
docker builder prune -f

# Then build without cache
./scripts/deployment/build-cacheless.sh

# Option 2: Manual build with --no-cache
docker builder prune -f
docker build --no-cache -t ghcr.io/shotleybuilder/ehs-enforcement:latest .
```

**⚠️ CRITICAL:** Always run `docker builder prune -f` BEFORE using `--no-cache` flag. Docker BuildKit can still use cached layers even with `--no-cache` if the build cache isn't cleared first.

**Safe to use cache when:**
- ✅ Only code changes (`.ex`, `.exs` files in `lib/`)
- ✅ Only template changes (`.heex` files)
- ✅ Only JavaScript/CSS changes (`assets/`)
- ✅ Runtime config changes in `config/runtime.exs` (environment variables)

**Example scenario:**
```bash
# 1. You change config/prod.exs to enable force_ssl
# 2. You run ./scripts/deployment/build.sh
# 3. Docker uses cached config layer (OLD config!)
# 4. You deploy - app starts but SSL settings don't work
# 5. Solution: Rebuild with --no-cache
./scripts/deployment/build-cacheless.sh
```

**Key rule:** If using `Application.compile_env()` anywhere in your code, changes to those configs REQUIRE `--no-cache` rebuild.

---

### Step 2: Test Container (Optional but Recommended)

Test the built image locally before pushing:

```bash
./scripts/deployment/test-container.sh
```

**Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EHS Enforcement - Local Container Test
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Docker image found
✓ Found docker-compose.dev.yml

Cleaning up previous test environment...
✓ Cleanup complete

Starting test environment...
✓ PostgreSQL is ready
✓ Application container is running

Testing health endpoint...
✓ Health check passed (HTTP 200)

Health endpoint response:
{
  "status": "ok",
  "database": "connected",
  "timestamp": "2025-10-14T21:45:00Z"
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Container test environment is running!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Application: http://localhost:4002
Health: http://localhost:4002/health

Follow logs? (y/N)
```

**What it does:**
- ✅ Verifies image exists
- ✅ Starts local PostgreSQL container
- ✅ Runs application container
- ✅ Tests database connectivity
- ✅ Verifies health endpoint
- ✅ Shows logs
- ✅ Offers to follow logs

**To clean up after testing:**
```bash
docker compose -f docker-compose.dev.yml down -v
```

---

### Step 3: Push to GitHub Container Registry

Push the tested image to GHCR:

```bash
./scripts/deployment/push.sh
```

**Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EHS Enforcement - Push to GHCR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Image: ghcr.io/shotleybuilder/ehs-enforcement:latest

Checking GHCR authentication...

Pushing to GitHub Container Registry...
[... push output ...]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Push successful!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Image: ghcr.io/shotleybuilder/ehs-enforcement:latest
Registry: GitHub Container Registry (GHCR)

Next steps:
  → Deploy to production: ./scripts/deployment/deploy-prod.sh
  → Or SSH manually:      ssh sertantai
```

**What it does:**
- ✅ Validates image exists locally
- ✅ Checks GHCR authentication
- ✅ Pushes image to registry
- ✅ Confirms success
- ✅ Suggests deployment

**If not logged in to GHCR:**
```bash
echo $GITHUB_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

---

### Step 4: Deploy to Production

Deploy the pushed image to the production server:

```bash
# Standard deployment
./scripts/deployment/deploy-prod.sh

# With migrations
./scripts/deployment/deploy-prod.sh --migrate

# With migrations and log following
./scripts/deployment/deploy-prod.sh --migrate --logs
```

**Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EHS Enforcement - Production Deployment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Server: sertantai
Service: ehs-enforcement
URL: https://legal.sertantai.com

Checking SSH connection to sertantai...
✓ SSH connection OK

Starting deployment...

[1/4] Pulling latest image from GHCR...
✓ Image pulled successfully

[2/4] Checking migration status...
Migrations already up
✓ Ash domains loaded successfully

[3/4] Running migrations...
✓ Migrations complete

[4/4] Restarting container...
✓ Container restarted

Waiting for startup...
Checking health endpoint...
✓ Health check passed (HTTP 200)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Deployment complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Application: https://legal.sertantai.com
Health: https://legal.sertantai.com/health

Recent logs:
[info] Running EhsEnforcementWeb.Endpoint with Bandit at :::4002
[info] Access EhsEnforcementWeb.Endpoint at https://legal.sertantai.com
[info] GET /health
[info] Sent 200 in 2ms

Deployment successful! 🚀
```

**What it does:**
- ✅ Verifies SSH connectivity
- ✅ Pulls latest image from GHCR
- ✅ Checks migration status
- ✅ Runs migrations (if --migrate flag)
- ✅ Restarts container
- ✅ Waits for startup
- ✅ Checks health endpoint
- ✅ Shows recent logs
- ✅ Optionally follows logs

**Deployment time:** ~30-60 seconds

---

## Script Reference

### build.sh

**Purpose:** Build production Docker image locally

**Usage:**
```bash
./scripts/deployment/build.sh [tag]
```

**Options:**
- `tag` - Optional image tag (defaults to "latest")

**Examples:**
```bash
# Build with latest tag
./scripts/deployment/build.sh

# Build with version tag
./scripts/deployment/build.sh v1.2.3

# Build with custom tag
./scripts/deployment/build.sh feature-branch
```

**Environment:**
- Requires Docker running
- Requires Dockerfile in project root

**Output:**
- Colored terminal output
- Build progress
- Image size and ID
- Next step suggestions

---

### push.sh

**Purpose:** Push Docker image to GitHub Container Registry

**Usage:**
```bash
./scripts/deployment/push.sh [tag]
```

**Options:**
- `tag` - Optional image tag (defaults to "latest")

**Examples:**
```bash
# Push latest tag
./scripts/deployment/push.sh

# Push specific version
./scripts/deployment/push.sh v1.2.3
```

**Prerequisites:**
```bash
# Login to GHCR first (one-time setup)
echo $GITHUB_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

**Environment:**
- Requires built Docker image
- Requires GHCR authentication
- Requires network connectivity

**Output:**
- Push progress
- Success/failure confirmation
- Next step suggestions

---

### deploy-prod.sh

**Purpose:** Deploy to production server

**Usage:**
```bash
./scripts/deployment/deploy-prod.sh [options]
```

**Options:**
- `--migrate` - Run database migrations after deployment
- `--check-only` - Only check status, don't deploy
- `--logs` - Follow logs after deployment
- `--help` - Show help message

**Examples:**
```bash
# Standard deployment
./scripts/deployment/deploy-prod.sh

# Deploy with migrations
./scripts/deployment/deploy-prod.sh --migrate

# Deploy with migrations and log following
./scripts/deployment/deploy-prod.sh --migrate --logs

# Check production status without deploying
./scripts/deployment/deploy-prod.sh --check-only

# Full deployment with all options
./scripts/deployment/deploy-prod.sh --migrate --logs
```

**Prerequisites:**
- SSH access to sertantai server
- Image pushed to GHCR
- Proper SSH key configuration

**What it does:**
1. Verifies SSH connectivity
2. Pulls latest image from GHCR
3. Checks migration status
4. Runs migrations (if requested)
5. Restarts container
6. Validates health endpoint
7. Shows recent logs
8. Optionally follows logs

**Deployment phases:**
- `[1/4]` Pull image - Downloads latest from GHCR
- `[2/4]` Check migrations - Verifies database state
- `[3/4]` Run migrations - Applies schema changes (if --migrate)
- `[4/4]` Restart container - Deploys new version

**Output:**
- Step-by-step progress
- Health check results
- Recent application logs
- Deployment confirmation

---

### test-container.sh

**Purpose:** Test Docker container locally before pushing to production

**Usage:**
```bash
./scripts/deployment/test-container.sh
```

**Prerequisites:**
- Built Docker image
- `docker-compose.dev.yml` (optional, will run minimal test without it)

**What it does:**
1. Validates image exists
2. Checks for docker-compose.dev.yml
3. Cleans up previous test environment
4. Starts PostgreSQL container
5. Starts application container
6. Tests health endpoint
7. Shows application logs
8. Offers to follow logs

**Testing features:**
- Local PostgreSQL on port 5434
- Application on port 4002
- Database connectivity test
- Health endpoint verification
- Log inspection

**After testing:**
```bash
# Stop containers
docker compose -f docker-compose.dev.yml down

# Stop and remove volumes
docker compose -f docker-compose.dev.yml down -v
```

**Minimal test mode:**
If `docker-compose.dev.yml` doesn't exist, the script offers to run a minimal container test without database connectivity.

---

## Advanced Usage

### Custom Tags

Deploy specific versions:

```bash
# Build with version tag
./scripts/deployment/build.sh v1.2.3

# Push versioned image
./scripts/deployment/push.sh v1.2.3

# Update production docker-compose.yml to use v1.2.3
# Then deploy
./scripts/deployment/deploy-prod.sh --migrate
```

### Parallel Testing

Test while building next version:

```bash
# Terminal 1: Test current version
./scripts/deployment/test-container.sh

# Terminal 2: Build next version
./scripts/deployment/build.sh v1.2.4
```

### Deployment with Verification

Deploy and immediately verify:

```bash
./scripts/deployment/deploy-prod.sh --migrate --logs &
DEPLOY_PID=$!

# Wait for deployment to complete
wait $DEPLOY_PID

# Test health endpoint
curl https://legal.sertantai.com/health
```

### Quick Rebuild and Deploy

Full cycle in one command:

```bash
./scripts/deployment/build.sh && ./scripts/deployment/push.sh && ./scripts/deployment/deploy-prod.sh --migrate
```

### Check Production Status

Verify production without deploying:

```bash
./scripts/deployment/deploy-prod.sh --check-only
```

**Output:**
- Current container status
- Recent logs
- No changes made

---

## Troubleshooting

### Build Script Issues

**Problem:** "Dockerfile not found"
```bash
# Solution: Ensure you're in project root
cd ~/Desktop/ehs_enforcement
./scripts/deployment/build.sh
```

**Problem:** "Docker is not running"
```bash
# Solution: Start Docker
sudo systemctl start docker  # Linux
# Or start Docker Desktop on macOS/Windows
```

**Problem:** Build is slow
```bash
# Solution: Use BuildKit for faster builds
DOCKER_BUILDKIT=1 ./scripts/deployment/build.sh
```

---

### Push Script Issues

**Problem:** "Image not found locally"
```bash
# Solution: Build first
./scripts/deployment/build.sh
```

**Problem:** "Authentication required"
```bash
# Solution: Login to GHCR
echo $GITHUB_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# Verify login
docker info | grep -i ghcr
```

**Problem:** "Permission denied"
```bash
# Solution: Check GitHub PAT has correct permissions
# Required scopes: write:packages, read:packages
```

---

### Deploy Script Issues

**Problem:** "Cannot connect to sertantai"
```bash
# Solution: Check SSH configuration
ssh sertantai  # Should connect without password

# Debug SSH
ssh -v sertantai
```

**Problem:** "Health check failed"
```bash
# Solution: Check application logs
ssh sertantai 'cd ~/infrastructure/docker && docker compose logs ehs-enforcement'

# Check if container is running
ssh sertantai 'cd ~/infrastructure/docker && docker compose ps ehs-enforcement'
```

**Problem:** "Migrations failed"
```bash
# Solution: Check migration status manually
ssh sertantai
cd ~/infrastructure/docker
docker compose exec ehs-enforcement /app/bin/ehs_enforcement eval "EhsEnforcement.Release.status"
```

---

### Test Script Issues

**Problem:** "docker-compose.dev.yml not found"
```bash
# Solution: The script will offer minimal test mode
# Or create docker-compose.dev.yml (see DEPLOYMENT_CURRENT.md)
```

**Problem:** "PostgreSQL failed to start"
```bash
# Solution: Check Docker resources
docker system df  # Check disk space
docker system prune  # Clean up if needed
```

**Problem:** "Health check returns 503"
```bash
# Solution: Check database connectivity
docker compose -f docker-compose.dev.yml logs postgres
docker compose -f docker-compose.dev.yml logs app
```

---

## Comparison with Manual Workflow

### Scripted Workflow (This Document)

**Pros:**
- ✅ Faster (3 commands vs 10+ commands)
- ✅ Consistent and repeatable
- ✅ Built-in validation
- ✅ Better error handling
- ✅ Colored output and progress
- ✅ Suitable for team deployments
- ✅ Less prone to human error

**Cons:**
- ❌ Less visibility into individual steps
- ❌ Harder to customize for edge cases
- ❌ Requires learning script options

### Manual Workflow (DEPLOYMENT_CURRENT.md)

**Pros:**
- ✅ Full visibility into each step
- ✅ Easy to customize
- ✅ Better for learning
- ✅ Better for troubleshooting
- ✅ No script dependencies

**Cons:**
- ❌ More commands to type
- ❌ Easy to forget steps
- ❌ Inconsistent across team members
- ❌ More prone to human error

### Recommendation

**For daily deployments:** Use scripted workflow (this document)
**For first-time deployment:** Use manual workflow (DEPLOYMENT_CURRENT.md)
**For troubleshooting:** Use manual workflow
**For learning:** Use manual workflow first, then scripts

---

## Script Workflow Diagram

```
┌─────────────────┐
│  Development    │
│  make changes   │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  ./build.sh     │ ← Build production image
│  (5-10 min)     │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  ./test-        │ ← Optional: Test locally
│   container.sh  │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  ./push.sh      │ ← Push to GHCR
│  (1-2 min)      │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  ./deploy-      │ ← Deploy to production
│   prod.sh       │   with migrations
│  --migrate      │
│  (30-60 sec)    │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  Production     │
│  ✓ Running      │
└─────────────────┘
```

---

## Complete Example Session

```bash
# Start from project root
cd ~/Desktop/ehs_enforcement

# Make your changes
git pull origin main
# ... make code changes ...
git add .
git commit -m "feat: add new feature"
git push origin main

# 1. Build production image
./scripts/deployment/build.sh
# ✓ Build complete! (Size: 512MB, ID: abc123)

# 2. Optional: Test locally
./scripts/deployment/test-container.sh
# ✓ Health check passed (HTTP 200)
# Follow logs? (y/N) n

# Clean up test environment
docker compose -f docker-compose.dev.yml down -v

# 3. Push to GHCR
./scripts/deployment/push.sh
# ✓ Push successful!

# 4. Deploy to production
./scripts/deployment/deploy-prod.sh --migrate --logs
# ✓ Deployment complete!
# Following logs (Ctrl+C to exit)...
# [info] Running EhsEnforcementWeb.Endpoint
# ^C

# 5. Verify deployment
curl https://legal.sertantai.com/health
# {"status":"ok","database":"connected"}
```

**Total time:** ~10-15 minutes (including build)

---

## Next Steps & Future Improvements

### Planned Enhancements

1. **CI/CD Integration**
   - GitHub Actions workflow for automated builds
   - Automatic deployment on merge to main
   - Integration tests before deployment

2. **Additional Scripts**
   - `rollback.sh` - Quick rollback to previous version
   - `health-check.sh` - Comprehensive health monitoring
   - `backup-db.sh` - Database backup before deployment

3. **Enhanced Logging**
   - Save deployment logs to file
   - Deployment history tracking
   - Slack/Discord notifications

4. **Staging Environment**
   - `deploy-staging.sh` script
   - Test before production deployment
   - Blue-green deployment strategy

---

## Support

### Documentation
- **Manual Workflow:** [DEPLOYMENT_CURRENT.md](./DEPLOYMENT_CURRENT.md)
- **Migration Plan:** [DEPLOYMENT_MIGRATION_PLAN.md](./DEPLOYMENT_MIGRATION_PLAN.md)
- **Old Deployment:** [DEPLOYMENT_OLD.md](./DEPLOYMENT_OLD.md)

### Getting Help

**Script issues:**
1. Check script help: `./scripts/deployment/deploy-prod.sh --help`
2. Review troubleshooting section above
3. Check manual workflow documentation

**Production issues:**
1. Check application logs: `ssh sertantai 'cd ~/infrastructure/docker && docker compose logs -f ehs-enforcement'`
2. Review [DEPLOYMENT_CURRENT.md](./DEPLOYMENT_CURRENT.md) troubleshooting section
3. Check health endpoint: `curl https://legal.sertantai.com/health`

---

**Last Updated:** 2025-10-14
**Scripts Version:** 1.0
**Production URL:** https://legal.sertantai.com
