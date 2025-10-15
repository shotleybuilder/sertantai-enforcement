# EHS Enforcement Production Deployment - GitHub Actions CI/CD

This guide provides a fully automated deployment pipeline using GitHub Actions for continuous integration and deployment. This approach combines the benefits of containerized deployment with automated testing, building, and deployment triggered by code changes.

## Overview

**GitHub → Actions → Registry → Production Server**

1. **Push/Tag**: Push code or create release tag
2. **CI/CD**: GitHub Actions builds, tests, and pushes container
3. **Deploy**: Automatically deploy to production server
4. **Verify**: Health checks and rollback if needed

## Benefits

- ✅ **Fully automated** deployments on git push/tag
- ✅ **Built-in testing** pipeline before deployment
- ✅ **Zero-downtime deployments** with health checks
- ✅ **Automatic rollback** on deployment failure
- ✅ **Version tracking** with git tags
- ✅ **Secrets management** via GitHub Secrets
- ✅ **Multi-environment** support (staging, production)
- ✅ **Deployment notifications** (Slack, Discord, email)

## Prerequisites

### GitHub Repository
- EHS Enforcement codebase in GitHub repository
- GitHub Actions enabled
- Proper Dockerfile in repository root

### Production Server
- Ubuntu 20.04+ VPS with Docker installed
- SSH access configured
- Domain name pointed to server

### Required Secrets
- Production server access credentials
- Container registry authentication
- Application environment variables

## Step 1: Production Server Setup

### Server Preparation
```bash
# Update system and install Docker
sudo apt update && sudo apt upgrade -y
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install additional tools
sudo apt install -y nginx certbot python3-certbot-nginx htop

# Create deployment directory
sudo mkdir -p /opt/ehs_enforcement
sudo chown $USER:$USER /opt/ehs_enforcement
cd /opt/ehs_enforcement
```

### SSH Key Setup for GitHub Actions
```bash
# Generate deployment key (on your local machine)
ssh-keygen -t ed25519 -C "github-actions@ehs-enforcement" -f ~/.ssh/ehs_deployment_key

# Copy public key to server
ssh-copy-id -i ~/.ssh/ehs_deployment_key.pub user@your-server.com

# Test connection
ssh -i ~/.ssh/ehs_deployment_key user@your-server.com "docker --version"
```

### Production Environment Files
```bash
# Create environment template
cat > /opt/ehs_enforcement/.env.template << 'EOF'
# Database
DATABASE_URL=ecto://postgres:${DB_PASSWORD}@postgres:5432/ehs_enforcement_prod
DATABASE_NAME=ehs_enforcement_prod
DATABASE_USER=postgres
DATABASE_PASSWORD=${DB_PASSWORD}
POOL_SIZE=10

# Application
SECRET_KEY_BASE=${SECRET_KEY_BASE}
PHX_HOST=${PHX_HOST}
PORT=4002
TOKEN_SIGNING_SECRET=${TOKEN_SIGNING_SECRET}
PHX_SERVER=true

# GitHub OAuth
GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID}
GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET}
GITHUB_REDIRECT_URI=https://${PHX_HOST}/auth/user/github/callback
GITHUB_REPO_OWNER=${GITHUB_REPO_OWNER}
GITHUB_REPO_NAME=${GITHUB_REPO_NAME}
GITHUB_ACCESS_TOKEN=${GITHUB_ACCESS_TOKEN}
GITHUB_ALLOWED_USERS=${GITHUB_ALLOWED_USERS}

# Integrations
AT_UK_E_API_KEY=${AT_UK_E_API_KEY}
EOF
```

### Docker Compose Template
```yaml
# /opt/ehs_enforcement/docker-compose.yml
version: '3.8'

services:
  app:
    image: ghcr.io/yourusername/ehs-enforcement:${APP_VERSION:-latest}
    restart: unless-stopped
    ports:
      - "4002:4002"
    env_file:
      - .env.prod
    depends_on:
      - postgres
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4002/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
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
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - app-network

volumes:
  postgres_data:

networks:
  app-network:
    driver: bridge
```

## Step 2: GitHub Secrets Configuration

### Repository Secrets Setup
Go to GitHub → Repository → Settings → Secrets and Variables → Actions

**Production Server Access:**
```bash
# Required secrets
PROD_HOST=your-server.com
PROD_USER=your-username
PROD_SSH_KEY=<contents-of-private-key-file>
```

**Application Secrets:**
```bash
SECRET_KEY_BASE=<64-char-secret-from-mix-phx-gen-secret>
TOKEN_SIGNING_SECRET=<64-char-secret-from-mix-phx-gen-secret>
DB_PASSWORD=<strong-database-password>
PHX_HOST=your-domain.com
```

**Integration Secrets:**
```bash
GITHUB_CLIENT_ID=<oauth-app-client-id>
GITHUB_CLIENT_SECRET=<oauth-app-client-secret>
GITHUB_REPO_OWNER=<your-github-username>
GITHUB_REPO_NAME=<your-repo-name>
GITHUB_ACCESS_TOKEN=<personal-access-token>
GITHUB_ALLOWED_USERS=user1,user2,user3
AT_UK_E_API_KEY=<airtable-api-key>
```

**Registry Access (if using private registry):**
```bash
REGISTRY_USERNAME=<docker-registry-username>
REGISTRY_TOKEN=<docker-registry-token>
```

## Step 3: GitHub Actions Workflows

### Main Deployment Workflow
```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]
    tags: ['v*']
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'production'
        type: choice
        options:
          - production
          - staging

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    name: Test Suite
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: ehs_enforcement_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.4'
          otp-version: '27.2.4'

      - name: Cache deps
        uses: actions/cache@v3
        with:
          path: deps
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}

      - name: Cache _build
        uses: actions/cache@v3
        with:
          path: _build
          key: ${{ runner.os }}-build-${{ hashFiles('**/mix.lock') }}

      - name: Install dependencies
        run: mix deps.get

      - name: Check formatting
        run: mix format --check-formatted

      - name: Compile code (warnings as errors)
        run: mix compile --warnings-as-errors

      - name: Run tests
        run: mix test
        env:
          DATABASE_URL: ecto://postgres:postgres@localhost:5432/ehs_enforcement_test

      - name: Run Ash migrations check
        run: mix ash.codegen --check

  security:
    name: Security Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

  build:
    name: Build and Push Container
    runs-on: ubuntu-latest
    needs: [test, security]
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      image-digest: ${{ steps.build.outputs.digest }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push Docker image
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          platforms: linux/amd64,linux/arm64
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v')
    environment: production

    steps:
      - name: Deploy to production server
        uses: appleboy/ssh-action@v1.0.0
        env:
          APP_VERSION: ${{ needs.build.outputs.image-tag }}
        with:
          host: ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key: ${{ secrets.PROD_SSH_KEY }}
          envs: APP_VERSION
          script_stop: true
          script: |
            set -e
            cd /opt/ehs_enforcement
            
            # Create environment file from template
            envsubst < .env.template > .env.prod << EOF
            SECRET_KEY_BASE=${{ secrets.SECRET_KEY_BASE }}
            TOKEN_SIGNING_SECRET=${{ secrets.TOKEN_SIGNING_SECRET }}
            DB_PASSWORD=${{ secrets.DB_PASSWORD }}
            PHX_HOST=${{ secrets.PHX_HOST }}
            GITHUB_CLIENT_ID=${{ secrets.GITHUB_CLIENT_ID }}
            GITHUB_CLIENT_SECRET=${{ secrets.GITHUB_CLIENT_SECRET }}
            GITHUB_REPO_OWNER=${{ secrets.GITHUB_REPO_OWNER }}
            GITHUB_REPO_NAME=${{ secrets.GITHUB_REPO_NAME }}
            GITHUB_ACCESS_TOKEN=${{ secrets.GITHUB_ACCESS_TOKEN }}
            GITHUB_ALLOWED_USERS=${{ secrets.GITHUB_ALLOWED_USERS }}
            AT_UK_E_API_KEY=${{ secrets.AT_UK_E_API_KEY }}
            EOF
            
            # Pull new image
            docker compose pull app
            
            # Start services
            docker compose up -d postgres
            
            # Wait for database
            echo "Waiting for database..."
            until docker compose exec -T postgres pg_isready -U postgres; do
              sleep 2
            done
            
            # Run migrations
            docker compose run --rm app bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"
            
            # Deploy new version
            docker compose up -d app
            
            # Health check
            echo "Waiting for app to be healthy..."
            for i in {1..30}; do
              if curl -f http://localhost:4002/health > /dev/null 2>&1; then
                echo "✓ Application is healthy"
                break
              fi
              echo "Waiting for health check... ($i/30)"
              sleep 10
            done
            
            # Final verification
            if ! curl -f http://localhost:4002/health > /dev/null 2>&1; then
              echo "❌ Health check failed, rolling back"
              docker compose logs app
              exit 1
            fi
            
            # Cleanup old images
            docker image prune -f

  notify:
    name: Notify Deployment
    runs-on: ubuntu-latest
    needs: [deploy]
    if: always()
    
    steps:
      - name: Notify success
        if: needs.deploy.result == 'success'
        run: |
          echo "✅ Deployment successful"
          # Add Slack/Discord/email notification here
          
      - name: Notify failure
        if: needs.deploy.result == 'failure'
        run: |
          echo "❌ Deployment failed"
          # Add failure notification here
```

### Staging Environment Workflow
```yaml
# .github/workflows/staging.yml
name: Deploy to Staging

on:
  pull_request:
    branches: [main]
    types: [opened, synchronize]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    name: Test Suite
    runs-on: ubuntu-latest
    # ... same as production test job

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: test
    environment: staging
    if: github.event.pull_request.draft == false

    steps:
      - name: Deploy to staging server
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.STAGING_HOST }}
          username: ${{ secrets.STAGING_USER }}
          key: ${{ secrets.STAGING_SSH_KEY }}
          script: |
            cd /opt/ehs_enforcement_staging
            export APP_VERSION=pr-${{ github.event.number }}
            docker compose pull app
            docker compose up -d
            docker compose run --rm app bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"

      - name: Comment on PR
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `🚀 Staging deployment complete!\n\n**Preview URL:** https://staging-${{ github.event.number }}.yourdomain.com\n\n**Docker Image:** \`ghcr.io/${{ github.repository }}:pr-${{ github.event.number }}\``
            })
```

### Database Migration Workflow
```yaml
# .github/workflows/migrate.yml
name: Database Migration

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'production'
        type: choice
        options:
          - production
          - staging
      migration_type:
        description: 'Migration type'
        required: true
        default: 'migrate'
        type: choice
        options:
          - migrate
          - rollback
          - status
      rollback_version:
        description: 'Rollback version (for rollback only)'
        required: false

jobs:
  migrate:
    name: Database Migration
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment }}
    
    steps:
      - name: Run migration
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key: ${{ secrets.PROD_SSH_KEY }}
          script: |
            cd /opt/ehs_enforcement
            
            case "${{ github.event.inputs.migration_type }}" in
              "migrate")
                echo "Running migrations..."
                docker compose exec -T app bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"
                ;;
              "status")
                echo "Checking migration status..."
                docker compose exec -T app bin/ehs_enforcement eval "EhsEnforcement.Release.status"
                ;;
              "rollback")
                echo "Rolling back to version ${{ github.event.inputs.rollback_version }}..."
                docker compose exec -T app bin/ehs_enforcement eval "EhsEnforcement.Release.rollback(EhsEnforcement.Repo, ${{ github.event.inputs.rollback_version }})"
                ;;
            esac
```

## Step 4: SSL and Nginx Configuration

### Automated SSL Setup
```bash
# Install and configure SSL
sudo certbot --nginx -d yourdomain.com

# Create nginx configuration
sudo tee /etc/nginx/sites-available/ehs-enforcement << 'EOF'
server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";

    # Health check endpoint (bypass auth)
    location /health {
        proxy_pass http://127.0.0.1:4002/health;
        access_log off;
    }

    location / {
        proxy_pass http://127.0.0.1:4002;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support for LiveView
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/ehs-enforcement /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## Step 5: Monitoring and Alerting

### Health Check Script
```bash
# /usr/local/bin/health-check.sh
#!/bin/bash
HEALTH_URL="https://yourdomain.com/health"
SLACK_WEBHOOK="your-slack-webhook-url"

if ! curl -f -s "$HEALTH_URL" > /dev/null; then
    # Send alert
    curl -X POST -H 'Content-type: application/json' \
        --data '{"text":"🚨 EHS Enforcement health check failed!"}' \
        "$SLACK_WEBHOOK"
    
    # Log failure
    echo "$(date): Health check failed" >> /var/log/ehs-health.log
    exit 1
fi

echo "$(date): Health check passed" >> /var/log/ehs-health.log
```

```bash
# Add to crontab
sudo crontab -e
# Add: */5 * * * * /usr/local/bin/health-check.sh
```

### Backup Automation
```bash
# /usr/local/bin/backup-ehs.sh
#!/bin/bash
BACKUP_DIR="/opt/ehs_enforcement/backups"
RETENTION_DAYS=30

# Create backup
docker compose -f /opt/ehs_enforcement/docker-compose.yml exec -T postgres \
    pg_dump -U postgres ehs_enforcement_prod | \
    gzip > "$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).sql.gz"

# Cleanup old backups
find "$BACKUP_DIR" -name "backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete

# Upload to S3 (optional)
# aws s3 cp "$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).sql.gz" s3://your-backup-bucket/
```

## Step 6: Advanced Features

### Feature Flags with Environment Variables
```yaml
# Add to docker-compose.yml
environment:
  - FEATURE_NEW_DASHBOARD=true
  - FEATURE_BETA_API=false
```

### Blue-Green Deployment
```bash
# Enhanced deployment script for zero downtime
#!/bin/bash
cd /opt/ehs_enforcement

# Start new version alongside current
docker compose -f docker-compose.blue.yml up -d app-blue

# Health check new version
for i in {1..30}; do
  if curl -f http://localhost:4003/health > /dev/null 2>&1; then
    echo "✓ Blue environment is healthy"
    break
  fi
  sleep 10
done

# Switch traffic (update nginx config)
sudo sed -i 's/proxy_pass http:\/\/127.0.0.1:4002/proxy_pass http:\/\/127.0.0.1:4003/' /etc/nginx/sites-available/ehs-enforcement
sudo nginx -s reload

# Stop old version
docker compose stop app
```

### Database Migration Safety
```yaml
# Add migration safety checks to workflow
- name: Check migration safety
  run: |
    # Check for dangerous operations
    git diff HEAD~1 priv/repo/migrations/ | grep -E "(DROP|ALTER.*DROP)" && exit 1 || true
    
    # Verify Ash resource snapshots are updated
    git status --porcelain priv/resource_snapshots/ | grep -E "^[AM]" && \
      echo "⚠️ Uncommitted Ash resource changes detected" && exit 1 || true
```

## Deployment Workflows

### Standard Development Flow
1. **Feature Development**: Create feature branch
2. **Pull Request**: Triggers staging deployment and tests
3. **Code Review**: Review changes and staging preview
4. **Merge**: Triggers production deployment
5. **Monitoring**: Automated health checks and alerts

### Release Flow
1. **Create Tag**: `git tag v1.2.3 && git push origin v1.2.3`
2. **Automated Build**: GitHub Actions builds release container
3. **Production Deploy**: Deploys tagged version to production
4. **Verification**: Health checks and smoke tests
5. **Notification**: Team notification of successful deployment

### Hotfix Flow
1. **Emergency Branch**: Create from main branch
2. **Quick Fix**: Implement minimal fix
3. **Fast Track**: Use workflow_dispatch for immediate deployment
4. **Post-Deployment**: Create proper PR for review

## Troubleshooting

### Deployment Failures
```bash
# Check GitHub Actions logs
# Go to: GitHub → Actions → Failed workflow → View logs

# Check production logs
ssh user@server.com
cd /opt/ehs_enforcement
docker compose logs app

# Manual rollback
docker compose exec app docker tag ghcr.io/repo/ehs-enforcement:previous-tag latest
docker compose up -d app
```

### Database Issues
```bash
# Check migration status
docker compose exec app bin/ehs_enforcement eval "EhsEnforcement.Release.status"

# Manual migration
docker compose exec app bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"

# Rollback migration
docker compose exec app bin/ehs_enforcement eval "EhsEnforcement.Release.rollback(EhsEnforcement.Repo, 20240101000000)"
```

### Performance Issues
```bash
# Monitor resources
docker stats

# Check app performance
docker compose exec app bin/ehs_enforcement remote
# In IEx: :observer.start()

# Database performance
docker compose exec postgres psql -U postgres -c "SELECT * FROM pg_stat_activity;"
```

This automated deployment approach provides enterprise-grade CI/CD while maintaining the simplicity and reliability of containerized deployments. It's perfect for teams that want to focus on development while having confidence in their deployment pipeline.