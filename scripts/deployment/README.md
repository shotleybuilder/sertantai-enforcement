# EHS Enforcement Deployment Scripts

Automated deployment scripts for building, testing, and deploying the EHS Enforcement application.

## Quick Start

```bash
# Complete deployment in 3 commands
./scripts/deployment/build.sh
./scripts/deployment/push.sh
./scripts/deployment/deploy-prod.sh --migrate --logs
```

## Available Scripts

| Script | Purpose | Time |
|--------|---------|------|
| **build.sh** | Build production Docker image | 5-10 min |
| **push.sh** | Push image to GitHub Container Registry | 1-2 min |
| **deploy-prod.sh** | Deploy to production server | 30-60 sec |
| **test-container.sh** | Test container locally (optional) | 2-5 min |

## Script Details

### build.sh

Build the production Docker image locally.

```bash
./scripts/deployment/build.sh [tag]

# Examples:
./scripts/deployment/build.sh           # Build with 'latest' tag
./scripts/deployment/build.sh v1.2.3    # Build with version tag
```

**What it does:**
- Validates Dockerfile exists
- Checks Docker is running
- Builds image with proper tagging
- Shows image size and ID

---

### push.sh

Push the built image to GitHub Container Registry.

```bash
./scripts/deployment/push.sh [tag]

# Examples:
./scripts/deployment/push.sh           # Push 'latest' tag
./scripts/deployment/push.sh v1.2.3    # Push version tag
```

**Prerequisites:**
```bash
# One-time GHCR login
echo $GITHUB_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

---

### deploy-prod.sh

Deploy to the production server (sertantai).

```bash
./scripts/deployment/deploy-prod.sh [options]

# Options:
#   --migrate      Run database migrations
#   --check-only   Check status without deploying
#   --logs         Follow logs after deployment
#   --help         Show help message

# Examples:
./scripts/deployment/deploy-prod.sh                    # Standard deploy
./scripts/deployment/deploy-prod.sh --migrate          # Deploy with migrations
./scripts/deployment/deploy-prod.sh --migrate --logs   # Deploy and watch logs
./scripts/deployment/deploy-prod.sh --check-only       # Check status only
```

**What it does:**
1. Verifies SSH connectivity
2. Pulls latest image from GHCR
3. Checks migration status
4. Runs migrations (if --migrate)
5. Restarts container
6. Validates health endpoint
7. Shows recent logs

---

### test-container.sh

Test the Docker container locally before pushing to production.

```bash
./scripts/deployment/test-container.sh
```

**What it does:**
- Starts local PostgreSQL container
- Runs application container
- Tests database connectivity
- Verifies health endpoint
- Shows application logs

**Clean up after testing:**
```bash
docker compose -f docker-compose.dev.yml down -v
```

---

## Typical Workflow

### Daily Development Deployment

```bash
# 1. Make your changes
git pull origin main
# ... make code changes ...
git add . && git commit -m "feat: add feature" && git push

# 2. Build and deploy
./scripts/deployment/build.sh
./scripts/deployment/push.sh
./scripts/deployment/deploy-prod.sh --migrate --logs
```

### Pre-deployment Testing

```bash
# 1. Build
./scripts/deployment/build.sh

# 2. Test locally first
./scripts/deployment/test-container.sh

# 3. Clean up test environment
docker compose -f docker-compose.dev.yml down -v

# 4. Push and deploy
./scripts/deployment/push.sh
./scripts/deployment/deploy-prod.sh --migrate
```

### Version Release

```bash
# Build and tag version
./scripts/deployment/build.sh v1.2.3

# Test the versioned image
./scripts/deployment/test-container.sh

# Push version
./scripts/deployment/push.sh v1.2.3

# Deploy (after updating docker-compose.yml to use v1.2.3)
./scripts/deployment/deploy-prod.sh --migrate --logs
```

---

## Script Features

All scripts include:
- ✅ Colored terminal output
- ✅ Progress indicators
- ✅ Built-in validation
- ✅ Error handling with helpful messages
- ✅ Next-step suggestions
- ✅ Comprehensive help text

---

## Prerequisites

### For Building (build.sh)
- Docker installed and running
- Dockerfile in project root

### For Pushing (push.sh)
- Image built locally
- GHCR authentication configured
- Network connectivity

### For Deploying (deploy-prod.sh)
- SSH access to sertantai server
- Image pushed to GHCR
- SSH key configured

### For Testing (test-container.sh)
- Image built locally
- Docker Compose installed
- Optional: docker-compose.dev.yml

---

## Troubleshooting

### Build fails
```bash
# Check Docker is running
docker info

# Check Dockerfile exists
ls -la Dockerfile
```

### Push fails
```bash
# Login to GHCR
echo $GITHUB_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# Verify image exists
docker images | grep ehs-enforcement
```

### Deploy fails
```bash
# Test SSH connection
ssh sertantai

# Check script has execute permission
ls -la scripts/deployment/deploy-prod.sh
chmod +x scripts/deployment/deploy-prod.sh
```

### Test fails
```bash
# Check docker-compose.dev.yml exists
ls -la docker-compose.dev.yml

# Check image exists
docker images | grep ehs-enforcement

# Clean up and retry
docker compose -f docker-compose.dev.yml down -v
./scripts/deployment/test-container.sh
```

---

## Production Details

**Server:** sertantai (Digital Ocean droplet)
**URL:** https://legal.sertantai.com
**Infrastructure Path:** `~/infrastructure/docker`
**Container Name:** `ehs_enforcement_app`
**Port:** 4002 (internal, proxied by nginx)

---

## Documentation

**Detailed Guides:**
- [DEPLOYMENT_WITH-SCRIPTS.md](../../docs-dev/dev/deployment/DEPLOYMENT_WITH-SCRIPTS.md) - Complete scripted workflow guide
- [DEPLOYMENT_CURRENT.md](../../docs-dev/dev/deployment/DEPLOYMENT_CURRENT.md) - Manual deployment workflow

**Need help?**
```bash
# Show script help
./scripts/deployment/deploy-prod.sh --help

# Check production status
./scripts/deployment/deploy-prod.sh --check-only
```

---

**Last Updated:** 2025-10-14
**Scripts Version:** 1.0
