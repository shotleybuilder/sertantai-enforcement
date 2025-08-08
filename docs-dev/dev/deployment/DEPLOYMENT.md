# EHS Enforcement Production Deployment Guide

This guide provides step-by-step instructions for deploying the EHS Enforcement application to a Digital Ocean VPS in production.

## Prerequisites

- Digital Ocean VPS with Ubuntu 20.04+ (minimum 2GB RAM, 2 CPU cores recommended)
- Domain name pointed to your VPS
- SSL certificate (Let's Encrypt recommended)
- PostgreSQL 16+ database
- Docker and Docker Compose installed

## Environment Setup

### 1. Server Preparation - COMPLETE

  ```bash
  # Update system
  ✅ sudo apt update && sudo apt upgrade -y

  # Install Docker
  ✅ curl -fsSL https://get.docker.com -o get-docker.sh
  ✅ sudo sh get-docker.sh
  ✅ sudo usermod -aG docker $USER

  # Install Docker Compose
  ✅ sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  ✅ sudo chmod +x /usr/local/bin/docker-compose

  # Install Nginx (if not using Docker for reverse proxy)
  ✅ sudo apt install nginx -y

  # Install additional dependencies
  ✅ sudo apt install -y unzip build-essential libpq-dev postgresql-client ufw
  ```

### 2. PostgreSQL Database Setup

  Since this deployment uses Docker Compose, PostgreSQL runs in a container. However, for production setups, you may also want to configure a standalone PostgreSQL instance.

  #### Option A: PostgreSQL via Docker (Recommended - Handled by docker-compose.prod.yml)

    The `docker-compose.prod.yml` file includes a PostgreSQL 16 container that will be automatically provisioned. No additional setup required - skip to step 3.

  #### Option B: Standalone PostgreSQL Installation (Alternative)

    If you prefer a standalone PostgreSQL installation on the Digital Ocean droplet:

    ```bash
    # Install PostgreSQL 16
    sudo apt update
    sudo apt install -y wget ca-certificates

    # Add PostgreSQL official repository
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list

    # Install PostgreSQL 16
    sudo apt update
    sudo apt install -y postgresql-16 postgresql-client-16

    # Start and enable PostgreSQL
    sudo systemctl start postgresql
    sudo systemctl enable postgresql

    # Create production database and user
    sudo -u postgres psql << 'EOF'
    -- Create production database
    CREATE DATABASE ehs_enforcement_prod;

    -- Create application user with strong password
    CREATE USER ehs_app WITH ENCRYPTED PASSWORD 'your-secure-database-password-here';

    -- Grant permissions
    GRANT ALL PRIVILEGES ON DATABASE ehs_enforcement_prod TO ehs_app;
    ALTER USER ehs_app CREATEDB;  -- Needed for running tests

    -- Set connection limits
    ALTER USER ehs_app CONNECTION LIMIT 20;
    EOF

    # Configure PostgreSQL for production
    sudo tee -a /etc/postgresql/16/main/postgresql.conf << 'EOF'

    # Production optimization settings
    listen_addresses = 'localhost'
    max_connections = 100
    shared_buffers = 256MB        # 25% of available RAM
    effective_cache_size = 1GB    # 75% of available RAM
    maintenance_work_mem = 64MB
    checkpoint_completion_target = 0.9
    wal_buffers = 16MB
    default_statistics_target = 100
    random_page_cost = 1.1
    effective_io_concurrency = 200
    work_mem = 4MB
    min_wal_size = 1GB
    max_wal_size = 4GB
    EOF

    # Configure authentication
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" /etc/postgresql/16/main/postgresql.conf

    # Restart PostgreSQL to apply settings
    sudo systemctl restart postgresql

    # Test connection
    sudo -u postgres psql -c "SELECT version();"

    # Create backup directory
    sudo mkdir -p /var/lib/postgresql/backups
    sudo chown postgres:postgres /var/lib/postgresql/backups
    ```

    #### Database Security Configuration (Standalone PostgreSQL)

    ```bash
    # Configure firewall for PostgreSQL (if using standalone)
    sudo ufw allow from 127.0.0.1 to any port 5432
    sudo ufw allow from ::1 to any port 5432

    # Edit pg_hba.conf for security
    sudo sed -i 's/local   all             all                                     peer/local   all             all                                     md5/' /etc/postgresql/16/main/pg_hba.conf

    # Restart PostgreSQL
    sudo systemctl restart postgresql
    ```

    #### Environment Configuration for Standalone PostgreSQL

    If using standalone PostgreSQL, update your `.env.prod` file:

    ```bash
    # For standalone PostgreSQL
    DATABASE_URL=ecto://ehs_app:your-secure-database-password-here@localhost:5432/ehs_enforcement_prod

    # For Docker PostgreSQL (default)
    DATABASE_URL=ecto://postgres:your-docker-db-password@postgres:5432/ehs_enforcement_prod
    ```

### 3. Application Setup - COMPLETE

  # Install asdf
    ```bash
    # Install essential build tools and dependencies
    # libwxgtk3.2-dev for ubuntu 22.04 and newer
    # running ubuntu 25.04
    ✅ sudo apt install -y \
        curl \
        git \
        build-essential \
        autoconf \
        m4 \
        libncurses5-dev \
        libwxgtk3.2-dev \
        libgl1-mesa-dev \
        libglu1-mesa-dev \
        libpng-dev \
        libssh-dev \
        unixodbc-dev \
        xsltproc \
        fop \
        libxml2-utils \
        libncurses-dev \
        openjdk-11-jdk

    # For Erlang compilation
    # libiodbc2-dev replaces iodbc for ubuntu 20.04 and newer
    ✅ sudo apt install -y \
        libssl-dev \
        automake \
        libtool \
        libiodbc2-dev \
        libc6-dev \
        gcc \
        make

    # For wxWidgets (needed for Erlang observer)
    # Note: wxWidgets is only needed for Erlang's GUI tools like Observer (:observer.start()). You can
    # install Erlang/Elixir without it and add it later if you need the GUI tools. Most Phoenix
    # development doesn't require these GUI tools.
    sudo apt install -y \
        libwxbase3.0-dev \
        libwxgtk3.0-gtk3-dev \
        libsctp1 \
        libsctp-dev

    # Install asdf
    ✅ git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0

    # Add to shell profile (for bash)
    ✅ echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
    ✅ echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc

    # Reload shell or source the file
    ✅ source ~/.bashrc
    ```

  # Install Erlang
    Note: Erlang compilation takes a while (15-30 minutes depending on your system).
    **Make sure not to interrupt it with Ctrl+C**.
    If you need to stop, use Ctrl+Z to suspend and then kill %1 to properly terminate.
    ```bash
    ✅ asdf plugin-add erlang
    ✅ asdf install erlang 27.2.4
    ✅ asdf global erlang 27.2.4
    ```

    ```bash
    # If you want to see progress during installation:
    # Install with verbose output
    KERL_BUILD_DOCS=yes asdf install erlang 27.2.4
    ```

    ```
    APPLICATIONS DISABLED (See: /root/.asdf/plugins/erlang/kerl-home/builds/asdf_27.2.4/otp_build_27.2.4.log)
    * odbc           : ODBC library - link check failed

    APPLICATIONS INFORMATION (See: /root/.asdf/plugins/erlang/kerl-home/builds/asdf_27.2.4/otp_build_27.2.4.log)
    * wx             : wxWidgets was not compiled with --enable-webview or wxWebView developer package is not installed, wxWebView will NOT be available
    ```
    ### Note
      ODBC Warning (Safe to Ignore):
      - What it means: ODBC database connectivity wasn't built
      - Impact: You can't use :odbc module from Erlang
      - For Phoenix/Elixir: Not needed - you'll use Ecto with PostgreSQL/MySQL drivers instead
      wxWidgets Warning (Safe to Ignore):
      - What it means: GUI tools built without web view support
      - Impact: :observer.start() will work, but without web view features
      - For Phoenix/Elixir: Rarely needed for web development

    ## sGot impatient and cancelled?
      ```bash
      # Remove the lock file and partial build:
      # Remove the lock file
      rm -f ~/.asdf/plugins/erlang/kerl-home/builds/asdf_27.2.4/build.lock
      # Remove the entire partial build directory
      rm -rf ~/.asdf/plugins/erlang/kerl-home/builds/asdf_27.2.4
      # Also clean up any partial install
      rm -rf ~/.asdf/installs/erlang/27.2.4
      # Clear kerl build cache (optional but recommended):
      # Clear all kerl builds to start fresh
      rm -rf ~/.asdf/plugins/erlang/kerl-home/builds/*
      ```

  # Install Elixir
      ```bash
      ✅ asdf plugin-add elixir
      ✅ asdf install elixir 1.18.4
      ✅ asdf global elixir 1.18.4
      ```

      ```bash
      # Clone repository
      git clone <your-repository-url> /opt/ehs_enforcement
      cd /opt/ehs_enforcement

      # Copy environment template
      cp .env.example .env.prod
      ```

### 4. Environment Configuration
    **DB Notes**
      Based on the docker-compose.prod.yml, here's how the Docker PostgreSQL database gets
      automatically configured:

      Docker Compose Database Configuration

      The Docker container creates the database automatically using these environment variables from your
      .env.prod:

      Your .env.prod should contain:

      # Database Configuration (Docker PostgreSQL)
      DATABASE_URL=ecto://postgres:your-strong-password@postgres:5432/ehs_enforcement_prod
      DATABASE_NAME=ehs_enforcement_prod
      DATABASE_USER=postgres
      DATABASE_PASSWORD=your-strong-password-here
      DATABASE_PORT=5432
      POOL_SIZE=10

      Key Points for Docker Setup:

      1. Host is postgres (not localhost) - This is the Docker service name
      2. User is postgres (default PostgreSQL superuser)
      3. Database ehs_enforcement_prod gets created automatically
      4. Password must match DATABASE_PASSWORD environment variable

      How It Works:

      1. Docker Compose starts PostgreSQL container with:
        - POSTGRES_DB=${DATABASE_NAME:-ehs_enforcement_prod} → Creates the database
        - POSTGRES_USER=${DATABASE_USER:-postgres} → Sets the user (defaults to 'postgres')
        - POSTGRES_PASSWORD=${DATABASE_PASSWORD} → Sets the password
      2. Your Phoenix app connects using:
        - DATABASE_URL=ecto://postgres:password@postgres:5432/ehs_enforcement_prod
        - The hostname postgres resolves to the PostgreSQL container via Docker network
      3. Database gets created automatically when the container first starts

  `touch .env.prod`

  Edit `.env.prod` with your production values:

  echo "DATABASE_URL=ecto://postgres:password@postgres:5432/ehs_enforcement_prod" >> .env.prod

  ```bash
  # Required Production Variables
  DATABASE_URL=ecto://postgres:password@postgres:5432/ehs_enforcement_prod
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

#### Docker PostgreSQL Backup
```bash
# Create backup directory
mkdir -p /opt/ehs_enforcement/backups

# Backup script (Docker)
docker-compose -f docker-compose.prod.yml exec postgres pg_dump -U postgres ehs_enforcement_prod > backups/backup_$(date +%Y%m%d_%H%M%S).sql

# Compressed backup (recommended for production)
docker-compose -f docker-compose.prod.yml exec postgres pg_dump -U postgres ehs_enforcement_prod | gzip > backups/backup_$(date +%Y%m%d_%H%M%S).sql.gz

# Backup with Docker volume
docker run --rm -v ehs_enforcement_postgres_data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/postgres_data_$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
```

#### Standalone PostgreSQL Backup
```bash
# Create backup directory
sudo mkdir -p /var/lib/postgresql/backups

# Backup script (Standalone)
sudo -u postgres pg_dump ehs_enforcement_prod > /var/lib/postgresql/backups/backup_$(date +%Y%m%d_%H%M%S).sql

# Compressed backup
sudo -u postgres pg_dump ehs_enforcement_prod | gzip > /var/lib/postgresql/backups/backup_$(date +%Y%m%d_%H%M%S).sql.gz

# Automated backup script
sudo tee /usr/local/bin/backup-ehs-db << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/lib/postgresql/backups"
DATABASE="ehs_enforcement_prod"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILENAME="backup_${TIMESTAMP}.sql.gz"

# Create backup
sudo -u postgres pg_dump ${DATABASE} | gzip > ${BACKUP_DIR}/${FILENAME}

# Keep only last 7 days of backups
find ${BACKUP_DIR} -name "backup_*.sql.gz" -type f -mtime +7 -delete

echo "Backup completed: ${BACKUP_DIR}/${FILENAME}"
EOF

sudo chmod +x /usr/local/bin/backup-ehs-db

# Set up daily backup cron job
sudo tee /etc/cron.d/ehs-backup << 'EOF'
# Daily backup at 2 AM
0 2 * * * root /usr/local/bin/backup-ehs-db >> /var/log/ehs-backup.log 2>&1
EOF
```

### Database Restore

#### Docker PostgreSQL Restore
```bash
# Stop application
docker-compose -f docker-compose.prod.yml stop app

# Restore from backup
gunzip -c backups/backup_YYYYMMDD_HHMMSS.sql.gz | docker-compose -f docker-compose.prod.yml exec -T postgres psql -U postgres ehs_enforcement_prod

# Or restore uncompressed backup
docker-compose -f docker-compose.prod.yml exec -T postgres psql -U postgres ehs_enforcement_prod < backups/backup_YYYYMMDD_HHMMSS.sql

# Start application
docker-compose -f docker-compose.prod.yml start app
```

#### Standalone PostgreSQL Restore
```bash
# Create new database (if needed)
sudo -u postgres createdb ehs_enforcement_prod

# Restore from backup
sudo -u postgres psql ehs_enforcement_prod < /var/lib/postgresql/backups/backup_YYYYMMDD_HHMMSS.sql

# Or restore compressed backup
gunzip -c /var/lib/postgresql/backups/backup_YYYYMMDD_HHMMSS.sql.gz | sudo -u postgres psql ehs_enforcement_prod
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

**Docker PostgreSQL**:
```bash
# Check database status
docker-compose -f docker-compose.prod.yml exec postgres pg_isready -U postgres

# Check database logs
docker-compose -f docker-compose.prod.yml logs postgres

# Check database connections
docker-compose -f docker-compose.prod.yml exec postgres psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Check database size
docker-compose -f docker-compose.prod.yml exec postgres psql -U postgres -c "SELECT pg_database_size('ehs_enforcement_prod');"
```

**Standalone PostgreSQL**:
```bash
# Check PostgreSQL service status
sudo systemctl status postgresql

# Check if PostgreSQL is accepting connections
sudo -u postgres pg_isready

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-16-main.log

# Check active connections
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"

# Check database size
sudo -u postgres psql -c "SELECT pg_database_size('ehs_enforcement_prod');"

# Check disk space
df -h /var/lib/postgresql/

# Monitor PostgreSQL performance
sudo -u postgres psql -c "
SELECT
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
FROM pg_stats
WHERE schemaname = 'public'
ORDER BY schemaname, tablename, attname;
"
```

#### PostgreSQL Performance Monitoring

**Connection and Activity Monitoring**:
```bash
# For Docker PostgreSQL
docker-compose -f docker-compose.prod.yml exec postgres psql -U postgres -c "
SELECT
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';
"

# For Standalone PostgreSQL
sudo -u postgres psql -c "
SELECT
    datname,
    numbackends,
    xact_commit,
    xact_rollback,
    blks_read,
    blks_hit,
    tup_returned,
    tup_fetched,
    tup_inserted,
    tup_updated,
    tup_deleted
FROM pg_stat_database
WHERE datname = 'ehs_enforcement_prod';
"
```

**Database Maintenance**:
```bash
# For Docker PostgreSQL
docker-compose -f docker-compose.prod.yml exec postgres psql -U postgres ehs_enforcement_prod -c "VACUUM ANALYZE;"

# For Standalone PostgreSQL
sudo -u postgres psql ehs_enforcement_prod -c "VACUUM ANALYZE;"

# Check table sizes
sudo -u postgres psql ehs_enforcement_prod -c "
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
"
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
- Monitor application health endpoint: `curl https://yourdomain.com:4002/health`
- Check disk space usage: `df -h`
- Review error logs: `docker-compose -f docker-compose.prod.yml logs --tail=100 app`
- Verify database connectivity (Docker): `docker-compose -f docker-compose.prod.yml exec postgres pg_isready -U postgres`
- Verify database connectivity (Standalone): `sudo -u postgres pg_isready`

### Weekly
- Update Docker images: `docker-compose -f docker-compose.prod.yml pull`
- Database backup verification:
  - Docker: `ls -la /opt/ehs_enforcement/backups/`
  - Standalone: `ls -la /var/lib/postgresql/backups/`
- Security log review: `sudo tail -100 /var/log/auth.log`
- PostgreSQL log review:
  - Docker: `docker-compose -f docker-compose.prod.yml logs --tail=100 postgres`
  - Standalone: `sudo tail -100 /var/log/postgresql/postgresql-16-main.log`

### Monthly
- Security updates: `sudo apt update && sudo apt upgrade -y`
- SSL certificate renewal check: `sudo certbot renew --dry-run`
- Performance metrics review: Check application and database performance
- Database maintenance:
  - Docker: `docker-compose -f docker-compose.prod.yml exec postgres psql -U postgres ehs_enforcement_prod -c "VACUUM ANALYZE;"`
  - Standalone: `sudo -u postgres psql ehs_enforcement_prod -c "VACUUM ANALYZE;"`
- Clean old backups (if not automated):
  - `find /opt/ehs_enforcement/backups/ -name "*.sql.gz" -mtime +30 -delete`
  - `find /var/lib/postgresql/backups/ -name "*.sql.gz" -mtime +30 -delete`

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
