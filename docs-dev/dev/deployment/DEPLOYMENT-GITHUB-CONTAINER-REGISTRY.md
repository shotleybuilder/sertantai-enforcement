# GitHub Container Registry Setup Guide

This guide provides step-by-step instructions for setting up GitHub Container Registry (GHCR) for the EHS Enforcement application. GHCR is free, integrated with GitHub, and provides excellent performance for containerized deployments.

## Overview

GitHub Container Registry (ghcr.io) offers several advantages:
- ✅ **Free for public repositories** and generous limits for private repos
- ✅ **Integrated with GitHub** - no additional account setup needed
- ✅ **Fine-grained permissions** using GitHub's access control
- ✅ **Excellent performance** with global CDN
- ✅ **Built-in security scanning** for vulnerabilities
- ✅ **Package management** directly in GitHub repository

## Prerequisites

- GitHub account with repository access
- Docker installed locally (`docker --version` should work)
- Git repository for EHS Enforcement application
- Terminal access for command line operations

## Step 1: GitHub Personal Access Token Setup

### Create Personal Access Token

1. **Navigate to GitHub Settings**
   - Go to GitHub.com → Profile Picture → Settings
   - Scroll down to "Developer settings" (left sidebar)
   - Click "Personal access tokens" → "Tokens (classic)"

2. **Generate New Token**
   - Click "Generate new token (classic)"
   - Give it a descriptive name: "EHS Enforcement GHCR Access"
   - Set expiration: Choose appropriate timeframe (90 days recommended)

3. **Select Required Scopes**
   ```
   ✅ write:packages - Upload packages to GitHub Package Registry
   ✅ read:packages - Download packages from GitHub Package Registry
   ✅ delete:packages - Delete packages from GitHub Package Registry
   ✅ repo - Full control of private repositories (if using private repo)
   ```

4. **Generate and Copy Token**
   - Click "Generate token"
   - **IMPORTANT**: Copy the token immediately - you won't see it again!
   - Store securely in password manager or secure note

### Save Token Securely

```bash
# Option 1: Save to environment variable (temporary)
export GITHUB_TOKEN=ghp_your_token_here

# Option 2: Save to file (more permanent)
echo "ghp_your_token_here" > ~/.github_ghcr_token
chmod 600 ~/.github_ghcr_token
```

## Step 1b:

  **Install pass if not already installed**
  sudo apt update && sudo apt install pass

  **Generate a GPG key if you don't have one**
  gpg --gen-key
  _Follow prompts to create key_

  **Location of GPG key**
  gpg: directory '/home/jason/.gnupg/openpgp-revocs.d' created
  gpg: revocation certificate stored as '/home/jason/.gnupg/openpgp-revocs.d/CE0DB5C91C8C6A7BF5F753A268832D0BCC58D10B.rev'

  **Initialize pass with your GPG key**
  pass init "your-email@example.com"

## Step 2: Docker Login to GitHub Container Registry

### Authenticate Docker with GHCR

```bash
# Method 1: Using environment variable
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin

# Method 2: Using saved token file
cat ~/.github_ghcr_token | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin

# Method 3: Interactive login (will prompt for token)
docker login ghcr.io -u YOUR_GITHUB_USERNAME
# Enter your token when prompted for password
```

**Replace `YOUR_GITHUB_USERNAME` with your actual GitHub username**

### Verify Login Success

```bash
# Check Docker credentials
docker system info | grep -i registry

# Test authentication (should not show "unauthorized" error)
docker pull ghcr.io/YOUR_GITHUB_USERNAME/test:latest 2>&1 || echo "Login verified - 404 is expected for non-existent image"
```
```
Error response from daemon: manifest unknown
Login verified - 404 is expected for non-existent image
```
What this means:
- Error response from daemon: manifest unknown is the expected response
- This confirms Docker successfully authenticated with GHCR
- If authentication failed, you'd see unauthorized or permission denied
- The "manifest unknown" means the image doesn't exist (which is correct)

## Step 3: Configure Repository for Container Registry

### Update Repository Settings

1. **Enable Package Permissions**
   - Go to your EHS Enforcement repository on GitHub
   - Click "Settings" tab
   - Scroll to "Actions" → "General" in left sidebar
   - Under "Workflow permissions" ensure:
     - ✅ "Read and write permissions" is selected
     - ✅ "Allow GitHub Actions to create and approve pull requests" is checked

2. **Configure Package Visibility**
   - Repository Settings → "Actions" → "General"
   - Scroll to "Fork pull request workflows from outside collaborators"
   - Choose appropriate security level for your needs

   ● Solo Developer Recommendation: First Option Only ✅

     As a solo developer, select only the first checkbox:

     ✅ Run workflows from fork pull requests
     ❌ Send write tokens to workflows from fork pull requests
     ❌ Send secrets and variables to workflows from fork pull requests
     ❌ Require approval for fork pull request workflows

     Why This Configuration?

     For Solo Development:
     - ✅ Simple and secure - No unnecessary permissions
     - ✅ No secrets exposure - Protects your tokens and API keys
     - ✅ Basic functionality - Allows workflows to run for testing
     - ✅ No write access needed - Forks can't modify your repository

     What each option means:
     1. Run workflows - Allows basic CI/CD testing (safe)
     2. Send write tokens - Gives forks ability to modify your repo (risky)
     3. Send secrets - Exposes your API keys/tokens to forks (dangerous)
     4. Require approval - Manual approval for each fork PR (unnecessary overhead)

     Complete Configuration:

     After selecting only the first option, click "Save".

     Your repository is now configured with:
     - ✅ Basic fork PR workflows enabled
     - ✅ Secrets and write permissions protected
     - ✅ No manual approval overhead
     - ✅ Secure for solo development

     This gives you the benefits of automated testing on PRs without exposing sensitive credentials
     or allowing unauthorized modifications to your repository.

### Repository Secrets (for GitHub Actions)

If planning to use GitHub Actions later, set up these repository secrets:

1. **Navigate to Repository Secrets**
   - Repository → Settings → Secrets and variables → Actions

2. **Add Registry Secrets**
   ```
   REGISTRY_USERNAME = your-github-username
   REGISTRY_TOKEN = your-personal-access-token
   ```

## Step 4: Build and Push Your First Image

### Verify Dockerfile Exists

Ensure your EHS Enforcement repository has a proper Dockerfile:

```dockerfile
# Example structure - verify yours is similar
FROM hexpm/elixir:1.18.4-erlang-27.2.4-alpine-3.21.2 AS build
# ... build stages ...
FROM alpine:3.21.2 AS app
# ... runtime configuration ...
```

### Build and Tag Image

```bash
# Navigate to your repository
cd /path/to/ehs_enforcement

# Build image with GHCR naming convention
docker build -t ghcr.io/YOUR_GITHUB_USERNAME/ehs-enforcement:latest .

# Build with specific version tag as well
docker build -t ghcr.io/YOUR_GITHUB_USERNAME/ehs-enforcement:v1.0.0 .

# Or tag existing image
docker tag your-existing-image ghcr.io/YOUR_GITHUB_USERNAME/ehs-enforcement:latest
```

### Push Image to GitHub Container Registry

```bash
# Push latest tag
docker push ghcr.io/YOUR_GITHUB_USERNAME/ehs-enforcement:latest

# Push version tag
docker push ghcr.io/YOUR_GITHUB_USERNAME/ehs-enforcement:v1.0.0

# Push all tags for the image
docker push ghcr.io/YOUR_GITHUB_USERNAME/ehs-enforcement --all-tags
```

## Step 5: Verify Registry Setup

### Check Package in GitHub

1. **View in Repository**
   - Go to your repository on GitHub
   - Look for "Packages" section on right sidebar
   - Should see "ehs-enforcement" container listed

2. **Package Details**
   - Click on package name
   - Verify tags (latest, v1.0.0) are present
   - Check package size and upload date

### Test Pull from Registry

```bash
# Remove local image to test pull
docker rmi ghcr.io/YOUR_GITHUB_USERNAME/ehs-enforcement:latest

# Pull from registry
docker pull ghcr.io/YOUR_GITHUB_USERNAME/ehs-enforcement:latest

# Verify image exists locally
docker images | grep ehs-enforcement
```

## Step 6: Production Server Configuration

### Configure Production Docker Login

On your production server, set up GHCR access:

```bash
# SSH into your production server
ssh user@your-production-server.com

# Create GitHub token file (use read-only token for production)
echo "ghp_readonly_token_here" > ~/.github_token
chmod 600 ~/.github_token

# Login to GHCR on production server
cat ~/.github_token | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

### Update Production docker-compose.yml

```yaml
# /opt/ehs_enforcement/docker-compose.yml
version: '3.8'

services:
  app:
    image: ghcr.io/YOUR_GITHUB_USERNAME/ehs-enforcement:latest
    restart: unless-stopped
    ports:
      - "4002:4002"
    env_file:
      - .env.prod
    depends_on:
      - postgres
    networks:
      - app-network

  postgres:
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${DATABASE_NAME:-ehs_enforcement_prod}
      POSTGRES_USER: ${DATABASE_USER:-postgres}
      POSTGRES_PASSWORD: ${DATABASE_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    networks:
      - app-network

volumes:
  postgres_data:

networks:
  app-network:
    driver: bridge
```

### Test Production Deployment

```bash
# On production server
cd /opt/ehs_enforcement

# Pull latest image
docker-compose pull app

# Start services
docker-compose up -d

# Check logs
docker-compose logs app
```

## Step 7: GitHub Container Registry Management

### Image Management Commands

```bash
# List all images for your user
docker search ghcr.io/YOUR_GITHUB_USERNAME

# View image details
docker inspect ghcr.io/YOUR_GITHUB_USERNAME/ehs-enforcement:latest

# Remove old local images
docker rmi ghcr.io/YOUR_GITHUB_USERNAME/ehs-enforcement:old-tag

# Pull specific version
docker pull ghcr.io/YOUR_GITHUB_USERNAME/ehs-enforcement:v1.2.3
```

### Package Cleanup

GitHub provides package management through web interface:

1. **Delete Old Versions**
   - Repository → Packages → ehs-enforcement
   - Click on specific version
   - "Delete package version"

2. **Retention Policies**
   - Repository → Settings → Actions → General
   - Configure artifact and log retention
   - Set up automatic cleanup rules

## Step 8: Security Best Practices

### Token Security

```bash
# Create read-only token for production
# Only grant 'read:packages' scope for production servers

# Rotate tokens regularly
# Set expiration dates and calendar reminders

# Use different tokens for different environments
# development-token: read/write packages
# production-token: read packages only
```

### Image Security

```bash
# Enable vulnerability scanning (automatic in GHCR)
# Review security advisories in package view

# Use specific tags in production, not 'latest'
# image: ghcr.io/username/ehs-enforcement:v1.2.3

# Keep base images updated
# Regularly rebuild with latest Alpine/Ubuntu versions
```

### Access Control

```bash
# Repository Settings → Manage access
# Grant minimum required permissions
# Review access regularly
```

## Step 9: Automation Scripts

### Build and Push Script

Create `scripts/deploy-to-ghcr.sh`:

```bash
#!/bin/bash
set -e

# Configuration
GITHUB_USERNAME="YOUR_GITHUB_USERNAME"
IMAGE_NAME="ehs-enforcement"
REGISTRY="ghcr.io"

# Get version from git
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.1.0")
COMMIT_SHA=$(git rev-parse --short HEAD)

echo "🔨 Building $IMAGE_NAME version $VERSION..."

# Build image
docker build \
  -t $REGISTRY/$GITHUB_USERNAME/$IMAGE_NAME:latest \
  -t $REGISTRY/$GITHUB_USERNAME/$IMAGE_NAME:$VERSION \
  -t $REGISTRY/$GITHUB_USERNAME/$IMAGE_NAME:$COMMIT_SHA \
  .

echo "📤 Pushing to GitHub Container Registry..."

# Push all tags
docker push $REGISTRY/$GITHUB_USERNAME/$IMAGE_NAME:latest
docker push $REGISTRY/$GITHUB_USERNAME/$IMAGE_NAME:$VERSION
docker push $REGISTRY/$GITHUB_USERNAME/$IMAGE_NAME:$COMMIT_SHA

echo "✅ Successfully pushed $IMAGE_NAME:$VERSION to GHCR"
echo "🔗 View at: https://github.com/$GITHUB_USERNAME?tab=packages"
```

Make it executable:
```bash
chmod +x scripts/deploy-to-ghcr.sh
```

### Production Deploy Script

Create `scripts/deploy-production.sh`:

```bash
#!/bin/bash
set -e

# Configuration
GITHUB_USERNAME="YOUR_GITHUB_USERNAME"
IMAGE_NAME="ehs-enforcement"
REGISTRY="ghcr.io"
DEPLOY_DIR="/opt/ehs_enforcement"

echo "🚀 Deploying to production..."

# Pull latest image
docker pull $REGISTRY/$GITHUB_USERNAME/$IMAGE_NAME:latest

# Navigate to deployment directory
cd $DEPLOY_DIR

# Update docker-compose.yml with new image
sed -i "s|image: $REGISTRY/$GITHUB_USERNAME/$IMAGE_NAME:.*|image: $REGISTRY/$GITHUB_USERNAME/$IMAGE_NAME:latest|g" docker-compose.yml

# Deploy
docker-compose pull app
docker-compose up -d app

# Run migrations
docker-compose run --rm app bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"

# Health check
echo "⏳ Waiting for application to start..."
sleep 30

if curl -f http://localhost:4002/health > /dev/null 2>&1; then
    echo "✅ Deployment successful!"
    echo "🌐 Application is running at http://localhost:4002"
else
    echo "❌ Deployment failed - health check failed"
    exit 1
fi
```

## Step 10: Troubleshooting

### Common Issues and Solutions

**Authentication Errors:**
```bash
# Error: unauthorized: unauthenticated
# Solution: Re-login to GHCR
cat ~/.github_token | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

**Permission Denied:**
```bash
# Error: denied: permission_denied
# Solution: Check token scopes include write:packages
# Regenerate token with correct permissions
```

**Image Not Found:**
```bash
# Error: pull access denied, repository does not exist
# Solution: Verify image name and case sensitivity
docker images | grep ghcr.io
```

**Token Expired:**
```bash
# Error: unauthorized: token_expired
# Solution: Generate new token and update credentials
# Check token expiration in GitHub Settings
```

### Debug Commands

```bash
# Check Docker login status
cat ~/.docker/config.json | jq '.auths."ghcr.io"'

# Verify image exists in registry
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://ghcr.io/v2/YOUR_USERNAME/ehs-enforcement/tags/list

# Test registry connectivity
docker pull hello-world
docker tag hello-world ghcr.io/YOUR_USERNAME/test:latest
docker push ghcr.io/YOUR_USERNAME/test:latest
```

## Step 11: Integration with Existing Deployment

### Update Existing Scripts

If you have existing deployment scripts, update them to use GHCR:

```bash
# Find and replace in deployment files
find . -name "*.yml" -o -name "*.sh" | \
  xargs sed -i 's|your-old-registry|ghcr.io/YOUR_USERNAME|g'
```

### Environment Variables

Update your `.env.prod` if it references registry URLs:

```bash
# .env.prod
CONTAINER_REGISTRY=ghcr.io/YOUR_USERNAME
IMAGE_NAME=ehs-enforcement
IMAGE_TAG=latest
```

### Backup Strategy

```bash
# Export images for backup
docker save ghcr.io/YOUR_USERNAME/ehs-enforcement:latest | gzip > ehs-enforcement-backup.tar.gz

# Import from backup
docker load < ehs-enforcement-backup.tar.gz
```

## Conclusion

GitHub Container Registry is now configured for your EHS Enforcement application. You can:

- ✅ Build and push images locally: `docker push ghcr.io/YOUR_USERNAME/ehs-enforcement:latest`
- ✅ Pull images on production: `docker pull ghcr.io/YOUR_USERNAME/ehs-enforcement:latest`
- ✅ Manage packages through GitHub web interface
- ✅ Use automated deployment scripts
- ✅ Integrate with GitHub Actions workflows

**Next Steps:**
1. Update your deployment documentation to reference GHCR URLs
2. Set up automated builds with GitHub Actions (optional)
3. Configure monitoring and alerting for failed deployments
4. Implement backup strategies for critical images

**Registry URL Format:**
```
ghcr.io/YOUR_GITHUB_USERNAME/ehs-enforcement:TAG
```

Your GitHub Container Registry is ready for production use!
