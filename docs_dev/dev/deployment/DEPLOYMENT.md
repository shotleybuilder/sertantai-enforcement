# EHS Enforcement Production Deployment Guide

This guide provides step-by-step instructions for deploying the EHS Enforcement application to a Digital Ocean VPS in production.

## Prerequisites

- Digital Ocean VPS with Ubuntu 20.04+ (minimum 2GB RAM, 2 CPU cores recommended)  
- Domain name pointed to your VPS
- SSL certificate (Let's Encrypt recommended)
- PostgreSQL 16+ database
- Docker and Docker Compose installed

## Environment Setup

### 1. Server Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Nginx (if not using Docker for reverse proxy)
sudo apt install nginx -y
```

### 2. Application Setup

```bash
# Clone repository
git clone <your-repository-url> /opt/ehs_enforcement
cd /opt/ehs_enforcement

# Copy environment template
cp .env.example .env.prod
```

### 3. Environment Configuration

Edit `.env.prod` with your production values:

```bash
# Required Production Variables
DATABASE_URL=ecto://username:password@postgres:5432/ehs_enforcement_prod
SECRET_KEY_BASE=<generate-with-mix-phx-gen-secret>
PHX_HOST=yourdomain.com
PORT=4002  # Using 4002 to avoid conflicts with other Phoenix apps
TOKEN_SIGNING_SECRET=<generate-with-mix-phx-gen-secret>

# GitHub OAuth (required for authentication)
GITHUB_CLIENT_ID=your-github-oauth-client-id
GITHUB_CLIENT_SECRET=your-github-oauth-client-secret
GITHUB_REDIRECT_URI=https://yourdomain.com/auth/user/github/callback

# GitHub Admin
GITHUB_REPO_OWNER=your-github-username
GITHUB_REPO_NAME=your-repo-name
GITHUB_ACCESS_TOKEN=your-github-personal-access-token
GITHUB_ALLOWED_USERS=user1,user2,user3

# Airtable Integration
AT_UK_E_API_KEY=your-airtable-api-key

# Database Configuration
DATABASE_NAME=ehs_enforcement_prod
DATABASE_USER=postgres
DATABASE_PASSWORD=<strong-password>
POOL_SIZE=10

# Optional SSL Configuration
SSL_KEY_PATH=/etc/nginx/ssl/key.pem
SSL_CERT_PATH=/etc/nginx/ssl/cert.pem
```

### 4. SSL Certificate Setup

#### Using Let's Encrypt (Recommended)

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx -y

# Obtain certificate
sudo certbot --nginx -d yourdomain.com

# Copy certificates for Docker
sudo mkdir -p /opt/ehs_enforcement/ssl
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem /opt/ehs_enforcement/ssl/cert.pem
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem /opt/ehs_enforcement/ssl/key.pem
sudo chmod 644 /opt/ehs_enforcement/ssl/*.pem
```

## Deployment Options

### Option 1: Docker Compose (Recommended)

```bash
# Build and start services
docker-compose -f docker-compose.prod.yml up --build -d

# Run database setup
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"

# Check logs
docker-compose -f docker-compose.prod.yml logs -f app
```

### Option 2: Manual Deployment

```bash
# Build release
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release

# Set up database
_build/prod/rel/ehs_enforcement/bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"

# Start application  
PORT=4002 PHX_SERVER=true _build/prod/rel/ehs_enforcement/bin/ehs_enforcement start
```

## Phoenix 1.8.0 Release Commands

This deployment uses Phoenix 1.8.0 release patterns. Key differences from older Phoenix versions:

### Release Binary Structure
- **New**: `bin/ehs_enforcement eval "Module.function()"`
- **Old**: `bin/setup`, `bin/migrate` (deprecated)

### Common Commands
```bash
# Start the application
bin/ehs_enforcement start

# Run in daemon mode
bin/ehs_enforcement daemon

# Connect to running application
bin/ehs_enforcement remote

# Stop the application
bin/ehs_enforcement stop

# Run database migrations
bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"

# Run custom release tasks
bin/ehs_enforcement eval "EhsEnforcement.Release.seed"

# Check application and database status
bin/ehs_enforcement eval "EhsEnforcement.Release.status"

# Create database (if not exists)
bin/ehs_enforcement eval "EhsEnforcement.Release.create"

# Full setup (create + migrate + seed)
bin/ehs_enforcement eval "EhsEnforcement.Release.setup"
```

### Available Release Tasks
The `EhsEnforcement.Release` module provides these functions:

- **`migrate/0`** - Runs both Ecto and Ash migrations
- **`migrate_ash/0`** - Handles Ash domain loading and verification
- **`create/0`** - Creates the database if it doesn't exist
- **`seed/0`** - Runs database seed scripts
- **`setup/0`** - Complete setup (create + migrate + seed)
- **`status/0`** - Shows database connectivity and migration status
- **`rollback/2`** - Rolls back migrations to a specific version

### Environment Variables
- `PHX_SERVER=true` - Enables web server in release mode
- `PORT=4002` - Application port (custom for multi-app server)

## Ash Framework Deployment Considerations

This application uses the [Ash Framework](https://ash-hq.org/) for data modeling and business logic. Ash deployment differs from standard Phoenix/Ecto applications in several key areas:

### Ash Domains and Resources
The application includes 6 Ash domains with their respective resources:

- **EhsEnforcement.Accounts** - User authentication and management
- **EhsEnforcement.Configuration** - Application configuration settings  
- **EhsEnforcement.Enforcement** - Core enforcement data (Cases, Notices, Agencies, etc.)
- **EhsEnforcement.Events** - Event tracking and logging
- **EhsEnforcement.Scraping** - Web scraping coordination and results
- **EhsEnforcement.Sync** - Data synchronization with external services

### Critical Ash Migration Commands

**⚠️ IMPORTANT**: Always use `mix ash.migrate` instead of `mix ecto.migrate` for development:

```bash
# Development - Generate and run Ash migrations
mix ash.codegen --check      # Generate needed migrations
mix ash.migrate             # Apply Ash-generated migrations

# Production - Use Release module (includes Ash domain loading)
bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"
```

### Ash Migration Workflow

1. **Development Phase**:
   ```bash
   # After modifying Ash resources
   mix ash.codegen --check    # Check for needed migrations
   mix ash.migrate           # Apply migrations
   mix phx.server           # Start server
   ```

2. **Pre-Deployment**:
   ```bash
   # Ensure all Ash migrations are generated
   mix ash.codegen --check
   
   # Verify no pending migrations
   mix ash.migrate --dry-run
   ```

3. **Production Deployment**:
   ```bash
   # Docker deployment handles this automatically via Release module
   docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"
   ```

### Ash Resource Snapshot Management

Ash maintains resource snapshots in `priv/resource_snapshots/`. These must be committed to version control:

```bash
# After Ash resource changes, commit snapshots
git add priv/resource_snapshots/
git commit -m "Update Ash resource snapshots"
```

### Ash Authorization in Production

Ash enforces authorization policies in production. Ensure environment variables support this:

```bash
# Production environment should include
PHX_SERVER=true
PORT=4002
SECRET_KEY_BASE=<secure-key>

# Authentication-related (required for Ash policies)
GITHUB_CLIENT_ID=<oauth-client-id>
GITHUB_CLIENT_SECRET=<oauth-secret>
GITHUB_ALLOWED_USERS=user1,user2,user3
```

### Troubleshooting Ash Issues

**Ash Domain Loading Issues**:
```bash
# Check Ash domain status
bin/ehs_enforcement eval "EhsEnforcement.Release.status"

# Verify specific domain
bin/ehs_enforcement eval "Code.ensure_loaded(EhsEnforcement.Enforcement)"
```

**Migration Conflicts**:
```bash
# If Ash and Ecto migrations conflict, run in order:
bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"  # Handles both

# Check migration status
mix ecto.migrations  # Development only
```

**Resource Loading Problems**:
```bash
# Test resource loading
bin/ehs_enforcement eval "Ash.read(EhsEnforcement.Enforcement.Case, actor: nil)"
```

## Database Management

### Initial Setup
```bash
# Using Docker
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"

# Using release binary
_build/prod/rel/ehs_enforcement/bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"
```

### Running Migrations
```bash
# Using Docker
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"

# Using release binary
_build/prod/rel/ehs_enforcement/bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"
```

### Backup Database
```bash
# Create backup directory
mkdir -p /opt/ehs_enforcement/backups

# Backup script
docker-compose -f docker-compose.prod.yml exec postgres pg_dump -U postgres ehs_enforcement_prod > backups/backup_$(date +%Y%m%d_%H%M%S).sql
```

## Monitoring and Maintenance

### Health Checks
```bash
# Check application health
curl https://yourdomain.com:4002/health

# Check container status  
docker-compose -f docker-compose.prod.yml ps
```

### Log Management
```bash
# View application logs
docker-compose -f docker-compose.prod.yml logs -f app

# View database logs
docker-compose -f docker-compose.prod.yml logs -f postgres

# View nginx logs (if using Docker nginx)
docker-compose -f docker-compose.prod.yml logs -f nginx
```

### Application Updates
```bash
# Pull latest changes
git pull origin main

# Rebuild and deploy
docker-compose -f docker-compose.prod.yml build app
docker-compose -f docker-compose.prod.yml up -d app

# Run any new migrations (includes Ash migrations)
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"

# Verify Ash domains loaded correctly
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement eval "EhsEnforcement.Release.status"
```

### Ash-Specific Update Considerations

When updating an Ash application:

1. **Check for Ash Resource Changes**:
   ```bash
   # Before pulling updates, check current snapshots
   ls priv/resource_snapshots/
   
   # After pulling updates, verify new snapshots
   git status priv/resource_snapshots/
   ```

2. **Handle Ash Migration Changes**:
   ```bash
   # If new Ash resources were added, ensure they're loaded
   docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement eval "
   domains = [EhsEnforcement.Accounts, EhsEnforcement.Enforcement, EhsEnforcement.Scraping, EhsEnforcement.Configuration, EhsEnforcement.Events, EhsEnforcement.Sync]
   Enum.each(domains, &Code.ensure_loaded/1)
   "
   ```

3. **Test Ash Functionality Post-Update**:
   ```bash
   # Test a simple Ash operation
   docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement eval "
   case Ash.read(EhsEnforcement.Enforcement.Agency) do
     {:ok, agencies} -> IO.puts(\"✓ Ash operations working, found #{length(agencies)} agencies\")
     {:error, error} -> IO.puts(\"✗ Ash error: #{inspect(error)}\")
   end
   "

## Security Considerations

### Firewall Configuration
```bash
# Enable UFW
sudo ufw enable

# Allow SSH (replace 22 with your SSH port)
sudo ufw allow 22

# Allow HTTP and HTTPS
sudo ufw allow 80
sudo ufw allow 443

# Allow only necessary database connections
sudo ufw allow from <app-server-ip> to any port 5432
```

### SSL Security
- Use strong SSL ciphers (configured in nginx.conf)
- Enable HSTS headers
- Regular certificate renewal with Let's Encrypt

### Application Security
- Regular security updates: `docker-compose pull && docker-compose up -d`
- Monitor logs for suspicious activity
- Use strong, unique passwords for all services
- Limit GitHub OAuth app permissions
- Regularly rotate secrets and API keys

## Performance Optimization

### Database Optimization
```bash
# Tune PostgreSQL settings based on server resources
# Edit postgresql.conf:
shared_buffers = 256MB           # 25% of RAM
effective_cache_size = 1GB       # 75% of RAM  
max_connections = 100

# Application runs on port 4002 to avoid conflicts with other Phoenix apps
```

### Application Optimization
- Use connection pooling (configured in runtime.exs)
- Monitor memory usage with telemetry
- Enable Gzip compression in Nginx
- Use CDN for static assets if needed

## Troubleshooting

### Common Issues

#### Application Won't Start
```bash
# Check environment variables
docker-compose -f docker-compose.prod.yml exec app env | grep -E "(SECRET_KEY_BASE|DATABASE_URL|PHX_HOST)"

# Check database connectivity
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement remote
```

#### Database Connection Issues
```bash
# Check database status
docker-compose -f docker-compose.prod.yml exec postgres pg_isready -U postgres

# Check database logs
docker-compose -f docker-compose.prod.yml logs postgres
```

#### SSL Certificate Issues
```bash
# Check certificate validity
openssl x509 -in ssl/cert.pem -text -noout

# Renew Let's Encrypt certificate
sudo certbot renew
```

#### Ash Framework Issues

**Ash Domain Loading Failures**:
```bash
# Check which domains failed to load
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement eval "
domains = [EhsEnforcement.Accounts, EhsEnforcement.Configuration, EhsEnforcement.Enforcement, EhsEnforcement.Events, EhsEnforcement.Scraping, EhsEnforcement.Sync]
for domain <- domains do
  try do
    Code.ensure_loaded(domain)
    IO.puts(\"✓ #{inspect(domain)} loaded successfully\")
  rescue
    error -> IO.puts(\"✗ #{inspect(domain)} failed: #{inspect(error)}\")
  end
end
"
```

**Ash Resource Migration Issues**:
```bash
# Check if Ash-generated migrations are present
docker-compose -f docker-compose.prod.yml exec app ls -la priv/repo/migrations/

# Check Ash resource snapshots
docker-compose -f docker-compose.prod.yml exec app ls -la priv/resource_snapshots/

# Verify specific resource
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement eval "
case Ash.Resource.Info.attributes(EhsEnforcement.Enforcement.Case) do
  attributes when is_list(attributes) -> IO.puts(\"✓ Case resource loaded, #{length(attributes)} attributes\")
  error -> IO.puts(\"✗ Case resource error: #{inspect(error)}\")
end
"
```

**Ash Authorization Policy Issues**:
```bash
# Test Ash authorization with nil actor
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement eval "
case Ash.read(EhsEnforcement.Enforcement.Agency, actor: nil) do
  {:ok, _} -> IO.puts(\"✓ Public read access working\")
  {:error, %Ash.Error.Forbidden{}} -> IO.puts(\"✓ Authorization policies active (expected for protected resources)\")
  {:error, error} -> IO.puts(\"✗ Unexpected error: #{inspect(error)}\")
end
"

# Check authentication configuration
docker-compose -f docker-compose.prod.yml exec app bin/ehs_enforcement eval "
config = Application.get_env(:ehs_enforcement, :github_oauth, [])
IO.puts(\"GitHub OAuth configured: #{not is_nil(config[:client_id])}\")
"
```

### Log Locations
- Application logs: `docker-compose logs app`
- Database logs: `docker-compose logs postgres`  
- Nginx logs: `/var/log/nginx/` (if using system nginx)
- System logs: `/var/log/syslog`

## Maintenance Tasks

### Daily
- Monitor application health endpoint
- Check disk space usage
- Review error logs

### Weekly
- Update Docker images
- Database backup verification
- Security log review

### Monthly
- Security updates
- SSL certificate renewal check
- Performance metrics review
- Database maintenance (VACUUM, ANALYZE)

## Support

For issues specific to the EHS Enforcement application:
1. Check application logs for error details
2. Verify environment configuration  
3. Test database connectivity
4. Check GitHub OAuth configuration
5. Verify SSL certificate validity
6. **Ash Framework**: Verify domain loading and resource accessibility
7. **Ash Migrations**: Ensure `priv/resource_snapshots/` are committed and up-to-date

### Ash Framework Support Resources
- [Ash Framework Documentation](https://ash-hq.org/)
- [Ash Forum](https://elixirforum.com/c/ash-framework/123) 
- [Ash GitHub Issues](https://github.com/ash-hq/ash/issues)

Remember to never commit sensitive environment variables or secrets to version control.