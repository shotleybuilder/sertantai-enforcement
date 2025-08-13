# EHS Enforcement Docker Registry Deployment Checklist

This comprehensive checklist ensures reliable deployment using the Docker Registry approach. Each item references specific sections in the DEPLOYMENT-DOCKER-REGISTRY.md guide.

## 📋 Complete at First Deploy

### Local Development Setup
- [✅] **Install Docker and verify functionality** - Ensure Docker is installed locally and can build/push images
- [✅] **Set up container registry access** - Configure authentication for Docker Hub, GitHub Container Registry, or private registry using `docker login`
- [✅] **Optimize Dockerfile for Phoenix releases** - Verify multi-stage Dockerfile follows Phoenix best practices with hex, rebar, asset compilation, and release generation
- [✅] **Generate application secrets locally** - Run `mix phx.gen.secret` twice to generate SECRET_KEY_BASE and TOKEN_SIGNING_SECRET (64 characters each)
- [✅] **Test local Docker build** - build image locally with `docker build -f Dockerfile.debian -t ehs-enforcement:debian .`

### Production Server Preparation
- [ ] **Provision VPS with minimum 1GB RAM** - Set up Ubuntu 20.04+ server with adequate resources for Phoenix application
- [ ] **Install Docker on production server** - Run Docker installation script and add user to docker group: `curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker $USER`
- [ ] **Install additional server tools** - Install nginx, certbot, htop, and other monitoring tools: `sudo apt install -y nginx certbot python3-certbot-nginx htop`
- [ ] **Create application directory structure** - Set up `/opt/ehs_enforcement` with proper permissions and subdirectories for backups and configuration
- [ ] **Configure server firewall** - Enable UFW and allow SSH (22), HTTP (80), HTTPS (443): `sudo ufw allow 22/80/443`

### SSL Certificate Setup
- [ ] **Configure domain DNS** - Point your domain to the production server IP address and verify propagation
- [ ] **Obtain Let's Encrypt certificate** - Run `sudo certbot --nginx -d yourdomain.com` to get free SSL certificate
- [ ] **Set up automatic renewal** - Verify certbot renewal cron job is active: `sudo certbot renew --dry-run`
- [ ] **Test SSL configuration** - Verify HTTPS access and check certificate validity with browser or SSL testing tools

### Environment Configuration
- [ ] **Create production environment file** - Set up `.env.prod` with all required variables including database credentials, GitHub OAuth, and Airtable API keys
- [ ] **Configure GitHub OAuth application** - Create OAuth app in GitHub with correct redirect URI and note client ID/secret
- [ ] **Set up Airtable integration** - Obtain Airtable API key and configure base access for EHS enforcement data sync
- [ ] **Create docker-compose.yml** - Configure production compose file with app service, PostgreSQL, volumes, and health checks
- [ ] **Verify environment variable substitution** - Test that all environment variables are properly loaded and accessible in containers

### Nginx Reverse Proxy
- [ ] **Create nginx site configuration** - Set up reverse proxy configuration with SSL, security headers, and WebSocket support for Phoenix LiveView
- [ ] **Enable nginx site** - Create symbolic link from sites-available to sites-enabled and test configuration: `sudo nginx -t`
- [ ] **Configure security headers** - Add HSTS, X-Content-Type-Options, X-Frame-Options, and other security headers in nginx config
- [ ] **Test reverse proxy** - Verify nginx properly forwards requests to Phoenix application on port 4002

### Database Setup
- [ ] **Configure PostgreSQL container** - Set up PostgreSQL 16 container with proper environment variables and persistent volumes
- [ ] **Create backup directory structure** - Set up `/opt/ehs_enforcement/backups` with proper permissions for automated backups
- [ ] **Test database connectivity** - Verify PostgreSQL container starts and accepts connections from application container
- [ ] **Run initial migrations** - Execute `docker compose exec app bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"` to set up database schema

### Security Hardening
- [ ] **Secure environment files** - Set restrictive permissions on `.env.prod`: `chmod 600 .env.prod`
- [ ] **Configure container security** - Run application container as non-root user (phoenix:phoenix) with minimal privileges
- [ ] **Set up log rotation** - Configure logrotate for container logs to prevent disk space issues
- [ ] **Implement backup encryption** - Set up GPG encryption for database backups if storing sensitive data

## 🚀 Complete at Each Deploy

### Pre-deployment Preparation
- [ ] **Pull latest code changes** - Ensure local repository is up to date with `git pull origin main`
- [ ] **Run test suite locally** - Execute `mix test` to verify all tests pass before building production image
- [ ] **Check for Ash resource changes** - Run `mix ash.codegen --check` to ensure Ash migrations are generated and committed
- [ ] **Verify environment variables** - Review `.env.prod` for any new required configuration or updated secrets

### Container Build and Push
- [ ] **Build production Docker image** - Create optimized image with current code: `docker build -t registry/ehs-enforcement:latest .`
- [ ] **Tag image with version** - Apply semantic version tag: `docker tag registry/ehs-enforcement:latest registry/ehs-enforcement:v1.2.3`
- [ ] **Test image locally (optional)** - Run `docker run -p 4002:4002 --env-file .env.local` to verify image works
- [ ] **Push image to registry** - Upload both latest and versioned tags: `docker push registry/ehs-enforcement:latest && docker push registry/ehs-enforcement:v1.2.3`
- [ ] **Verify image push success** - Confirm image is available in registry and can be pulled

### Production Deployment
- [ ] **Pull latest image on server** - Download new image: `docker pull registry/ehs-enforcement:latest`
- [ ] **Stop application gracefully** - Use `docker compose stop app` to allow connections to finish
- [ ] **Start database if stopped** - Ensure PostgreSQL is running: `docker compose up -d postgres`
- [ ] **Wait for database readiness** - Verify PostgreSQL is accepting connections before proceeding
- [ ] **Run database migrations** - Execute `docker compose run --rm app bin/ehs_enforcement eval "EhsEnforcement.Release.migrate"` for schema updates

### Post-deployment Verification
- [ ] **Start application container** - Launch new version: `docker compose up -d app`
- [ ] **Wait for application startup** - Allow 60-90 seconds for Phoenix application to fully initialize
- [ ] **Verify health endpoint** - Test `curl http://localhost:4002/health` returns 200 OK status
- [ ] **Test HTTPS access** - Confirm `curl https://yourdomain.com/health` works through nginx proxy
- [ ] **Check application logs** - Review `docker compose logs app` for startup errors or warnings

### Functional Testing
- [ ] **Test user authentication** - Verify GitHub OAuth login flow works correctly
- [ ] **Verify database connectivity** - Test that application can read/write to PostgreSQL
- [ ] **Check Airtable integration** - Ensure API calls to Airtable succeed if applicable to deployment
- [ ] **Test LiveView functionality** - Verify WebSocket connections work through nginx proxy
- [ ] **Validate Ash operations** - Test core Ash resource operations work correctly

### Cleanup and Documentation
- [ ] **Remove old Docker images** - Clean up disk space: `docker image prune -f`
- [ ] **Update deployment log** - Record deployment version, timestamp, and any issues in team documentation
- [ ] **Notify team of deployment** - Inform team members of successful deployment via Slack/email if applicable
- [ ] **Tag git commit** - Create git tag for deployed version: `git tag v1.2.3 && git push origin v1.2.3`

## 🔄 Complete Whilst Deployed

### Daily Operations
- [ ] **Monitor application health** - Check health endpoint: `curl https://yourdomain.com/health` returns 200 OK
- [ ] **Review application logs** - Check `docker compose logs --tail=100 app` for errors or unusual activity
- [ ] **Monitor server resources** - Verify CPU, memory, and disk usage are within acceptable limits using `htop` and `df -h`
- [ ] **Check SSL certificate status** - Ensure certificate is valid and not approaching expiration
- [ ] **Verify database connectivity** - Test PostgreSQL is responsive: `docker compose exec postgres pg_isready -U postgres`

### Weekly Maintenance
- [ ] **Update Docker images** - Pull latest base images: `docker compose pull` to get security updates
- [ ] **Review backup integrity** - Verify database backups are being created and are restorable
- [ ] **Check disk space usage** - Monitor `/opt/ehs_enforcement` and `/var/lib/docker` disk usage
- [ ] **Review security logs** - Check `/var/log/auth.log` for suspicious authentication attempts
- [ ] **Test backup restoration** - Periodically verify backup files can be successfully restored

### Monthly Operations
- [ ] **System security updates** - Apply OS updates: `sudo apt update && sudo apt upgrade -y`
- [ ] **SSL certificate renewal check** - Test automatic renewal: `sudo certbot renew --dry-run`
- [ ] **Database maintenance** - Run `VACUUM ANALYZE` on PostgreSQL: `docker compose exec postgres psql -U postgres ehs_enforcement_prod -c "VACUUM ANALYZE;"`
- [ ] **Log rotation verification** - Ensure log files are being properly rotated and old logs cleaned up
- [ ] **Performance review** - Analyze application response times and database query performance

### Monitoring and Alerting
- [ ] **Health check automation** - Set up cron job to run health checks every 5 minutes: `*/5 * * * * curl -f https://yourdomain.com/health || echo "Health check failed"`
- [ ] **Backup verification** - Automated daily backup creation with `docker compose exec -T postgres pg_dump -U postgres ehs_enforcement_prod | gzip > backups/backup_$(date +%Y%m%d_%H%M%S).sql.gz`
- [ ] **Disk space monitoring** - Alert when disk usage exceeds 80%: `df -h / | awk 'NR==2{print $5}' | cut -d'%' -f1`
- [ ] **Container resource monitoring** - Track memory and CPU usage: `docker stats --no-stream`

### Security Maintenance
- [ ] **Review access logs** - Check nginx access logs for unusual patterns or potential attacks
- [ ] **Update application secrets** - Rotate SECRET_KEY_BASE and other sensitive credentials quarterly
- [ ] **Audit user permissions** - Review GitHub OAuth allowed users list and remove inactive users
- [ ] **Check container vulnerabilities** - Scan images for security issues: `docker scan registry/ehs-enforcement:latest`
- [ ] **Firewall rule review** - Verify UFW rules are still appropriate and no unnecessary ports are open

### Backup and Recovery
- [ ] **Test backup restoration** - Monthly verification that backups can be successfully restored to test environment
- [ ] **Offsite backup storage** - Ensure backups are copied to external storage (S3, external drive) for disaster recovery
- [ ] **Recovery procedure testing** - Quarterly full disaster recovery test from scratch using backups
- [ ] **Backup retention management** - Remove backups older than retention policy (30 days): `find backups/ -name "backup_*.sql.gz" -mtime +30 -delete`

### Performance Optimization
- [ ] **Database query analysis** - Review slow queries: `docker compose exec postgres psql -U postgres -c "SELECT query, mean_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"`
- [ ] **Connection pool monitoring** - Check Ecto connection pool usage and adjust POOL_SIZE if needed
- [ ] **Memory usage optimization** - Monitor Erlang VM memory usage and tune if necessary
- [ ] **Asset optimization** - Verify static assets are being properly compressed and cached by nginx

### Compliance and Documentation
- [ ] **Maintain deployment documentation** - Update deployment procedures based on lessons learned
- [ ] **Security compliance review** - Ensure deployment meets organizational security requirements
- [ ] **Change management logging** - Document all configuration changes and their rationale
- [ ] **Performance baseline tracking** - Maintain metrics on application performance over time

## 🚨 Emergency Procedures

### Rollback Checklist
- [ ] **Identify last working version** - Determine previous stable image tag from deployment logs
- [ ] **Stop current application** - `docker compose stop app`
- [ ] **Pull previous image** - `docker pull registry/ehs-enforcement:previous-version`
- [ ] **Update docker-compose.yml** - Change image tag to previous version
- [ ] **Start rolled-back version** - `docker compose up -d app`
- [ ] **Verify rollback success** - Test health endpoint and basic functionality

### Disaster Recovery
- [ ] **Assess damage scope** - Determine if issue is application, database, or infrastructure related
- [ ] **Notify stakeholders** - Inform team and users of service disruption
- [ ] **Implement temporary workaround** - If possible, provide limited functionality
- [ ] **Restore from backup** - Use most recent backup to restore database if corrupted
- [ ] **Document incident** - Record timeline, cause, and resolution for future prevention

This checklist ensures reliable, secure, and maintainable deployment of the EHS Enforcement application using the Docker Registry approach. Each item should be verified before proceeding to maintain system integrity and availability.
