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
docker-compose -f docker-compose.prod.yml exec app bin/setup

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
_build/prod/rel/ehs_enforcement/bin/setup

# Start application
PHX_SERVER=true _build/prod/rel/ehs_enforcement/bin/server
```

## Database Management

### Initial Setup
```bash
# Using Docker
docker-compose -f docker-compose.prod.yml exec app bin/setup

# Using release binary
_build/prod/rel/ehs_enforcement/bin/setup
```

### Running Migrations
```bash
# Using Docker
docker-compose -f docker-compose.prod.yml exec app bin/migrate

# Using release binary
_build/prod/rel/ehs_enforcement/bin/migrate
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
curl https://yourdomain.com/health

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

# Run any new migrations
docker-compose -f docker-compose.prod.yml exec app bin/migrate
```

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

Remember to never commit sensitive environment variables or secrets to version control.