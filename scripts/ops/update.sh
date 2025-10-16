#!/bin/bash

# EHS Enforcement Application Update Script
# Usage: ./scripts/update.sh [environment] [--skip-backup] [--force]

set -e

# Configuration
ENVIRONMENT=${1:-prod}
COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"
ENV_FILE=".env.${ENVIRONMENT}"
SKIP_BACKUP=false
FORCE_UPDATE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-backup)
      SKIP_BACKUP=true
      shift
      ;;
    --force)
      FORCE_UPDATE=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get current commit hash for rollback
get_current_commit() {
    git rev-parse HEAD
}

# Check if there are updates available
check_for_updates() {
    log_info "Checking for updates..."
    
    git fetch origin
    
    CURRENT_COMMIT=$(git rev-parse HEAD)
    LATEST_COMMIT=$(git rev-parse origin/main)
    
    if [ "$CURRENT_COMMIT" = "$LATEST_COMMIT" ]; then
        log_info "Application is already up to date"
        if [ "$FORCE_UPDATE" = false ]; then
            exit 0
        else
            log_warning "Forcing update despite being up to date"
        fi
    fi
    
    # Show what will be updated
    log_info "Changes to be deployed:"
    git log --oneline --graph "$CURRENT_COMMIT..$LATEST_COMMIT"
    echo
}

# Check for breaking changes
check_breaking_changes() {
    log_info "Checking for breaking changes..."
    
    CURRENT_COMMIT=$(git rev-parse HEAD)
    LATEST_COMMIT=$(git rev-parse origin/main)
    
    # Check for migration files
    if git diff "$CURRENT_COMMIT..$LATEST_COMMIT" --name-only | grep -E "priv/repo/migrations|priv/resource_snapshots" > /dev/null; then
        log_warning "Database migrations detected in this update!"
        log_warning "Migration files:"
        git diff "$CURRENT_COMMIT..$LATEST_COMMIT" --name-only | grep -E "priv/repo/migrations|priv/resource_snapshots" | sed 's/^/  - /'
        echo
    fi
    
    # Check for environment variable changes
    if git diff "$CURRENT_COMMIT..$LATEST_COMMIT" --name-only | grep -E "\.env\.example|config/" > /dev/null; then
        log_warning "Configuration changes detected!"
        log_warning "Please review environment variables after update"
        echo
    fi
    
    # Check for dependency changes
    if git diff "$CURRENT_COMMIT..$LATEST_COMMIT" --name-only | grep -E "mix.exs|mix.lock" > /dev/null; then
        log_warning "Dependency changes detected!"
        echo
    fi
}

# Create backup
create_backup() {
    if [ "$SKIP_BACKUP" = true ]; then
        log_warning "Skipping backup as requested"
        return
    fi
    
    log_info "Creating database backup..."
    
    # Create backup directory
    mkdir -p backups
    
    # Create backup filename with timestamp
    BACKUP_FILE="backups/pre_update_$(date +%Y%m%d_%H%M%S).sql"
    
    # Check if database is running
    if ! docker-compose -f "$COMPOSE_FILE" exec postgres pg_isready -U postgres > /dev/null 2>&1; then
        log_error "Database is not running. Cannot create backup."
        exit 1
    fi
    
    # Create backup
    docker-compose -f "$COMPOSE_FILE" exec -T postgres pg_dump -U postgres "${DATABASE_NAME:-ehs_enforcement_prod}" > "$BACKUP_FILE"
    
    # Compress backup
    gzip "$BACKUP_FILE"
    
    # Store backup filename in variable for potential rollback
    BACKUP_PATH="${BACKUP_FILE}.gz"
    
    log_success "Database backup created: $BACKUP_PATH"
}

# Check current application health
check_pre_update_health() {
    log_info "Checking current application health..."
    
    # Check if containers are running
    if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        log_error "Application containers are not running properly"
        docker-compose -f "$COMPOSE_FILE" ps
        exit 1
    fi
    
    # Check health endpoint if available
    if command -v curl &> /dev/null; then
        HEALTH_URL="http://localhost:${PORT:-4000}/health"
        if ! curl -f -s "$HEALTH_URL" > /dev/null; then
            log_warning "Health endpoint not responding, but containers are running"
        else
            log_success "Application health check passed"
        fi
    fi
}

# Pull latest changes
pull_updates() {
    log_info "Pulling latest changes..."
    
    # Store current commit for potential rollback
    PREVIOUS_COMMIT=$(get_current_commit)
    
    # Pull changes
    git pull origin main
    
    log_success "Code updated successfully"
}

# Check for new environment variables
check_env_variables() {
    log_info "Checking for new environment variables..."
    
    if [ ! -f "$ENV_FILE" ]; then
        log_error "Environment file $ENV_FILE not found"
        exit 1
    fi
    
    # Check if there are new variables in .env.example
    if [ -f ".env.example" ]; then
        # Extract variable names from both files
        EXAMPLE_VARS=$(grep -E "^[A-Z_]+" .env.example | cut -d'=' -f1 | sort)
        CURRENT_VARS=$(grep -E "^[A-Z_]+" "$ENV_FILE" | cut -d'=' -f1 | sort)
        
        # Find missing variables
        MISSING_VARS=$(comm -23 <(echo "$EXAMPLE_VARS") <(echo "$CURRENT_VARS"))
        
        if [ -n "$MISSING_VARS" ]; then
            log_warning "New environment variables found:"
            echo "$MISSING_VARS" | sed 's/^/  - /'
            log_warning "Please update $ENV_FILE with these variables"
            echo
        fi
    fi
}

# Build updated application
build_update() {
    log_info "Building updated application..."
    
    # Build new images
    docker-compose -f "$COMPOSE_FILE" build --no-cache app
    
    log_success "Application build completed"
}

# Deploy update
deploy_update() {
    log_info "Deploying update..."
    
    # Rolling update: start new containers
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # Wait for application to be ready
    log_info "Waiting for application to initialize..."
    sleep 30
    
    # Run migrations
    log_info "Running database migrations..."
    docker-compose -f "$COMPOSE_FILE" exec -T app bin/migrate
    
    log_success "Update deployment completed"
}

# Post-update health check
check_post_update_health() {
    log_info "Performing post-update health check..."
    
    # Wait for application to stabilize
    sleep 10
    
    # Check if containers are running
    if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        log_error "Containers are not running after update!"
        docker-compose -f "$COMPOSE_FILE" logs --tail=50 app
        return 1
    fi
    
    # Check application health endpoint
    if command -v curl &> /dev/null; then
        HEALTH_URL="http://localhost:${PORT:-4000}/health"
        
        # Try health check multiple times
        for i in {1..5}; do
            if curl -f -s "$HEALTH_URL" > /dev/null; then
                log_success "Post-update health check passed"
                return 0
            fi
            log_info "Health check attempt $i/5 failed, retrying..."
            sleep 10
        done
        
        log_error "Health check failed after update"
        return 1
    else
        log_warning "curl not available, skipping HTTP health check"
        return 0
    fi
}

# Rollback function
rollback_update() {
    log_error "Rolling back update..."
    
    # Stop current containers
    docker-compose -f "$COMPOSE_FILE" down
    
    # Rollback to previous commit
    if [ -n "$PREVIOUS_COMMIT" ]; then
        log_info "Rolling back to commit: $PREVIOUS_COMMIT"
        git reset --hard "$PREVIOUS_COMMIT"
        
        # Rebuild with previous version
        docker-compose -f "$COMPOSE_FILE" build app
        docker-compose -f "$COMPOSE_FILE" up -d
        
        log_warning "Code rollback completed"
    fi
    
    # Restore database if backup exists
    if [ -n "$BACKUP_PATH" ] && [ -f "$BACKUP_PATH" ]; then
        log_warning "Database restore may be needed. Backup available at: $BACKUP_PATH"
        log_warning "To restore database, run:"
        log_warning "  gunzip -c $BACKUP_PATH | docker-compose -f $COMPOSE_FILE exec -T postgres psql -U postgres ${DATABASE_NAME:-ehs_enforcement_prod}"
    fi
}

# Cleanup old images
cleanup() {
    log_info "Cleaning up old Docker images..."
    
    # Remove dangling images
    docker image prune -f
    
    # Remove old containers
    docker container prune -f
    
    log_success "Cleanup completed"
}

# Show update status
show_status() {
    log_info "Update Status:"
    echo
    
    # Show running containers
    docker-compose -f "$COMPOSE_FILE" ps
    echo
    
    # Show recent logs
    log_info "Recent application logs:"
    docker-compose -f "$COMPOSE_FILE" logs --tail=20 app
}

# Main update process
main() {
    log_info "Starting EHS Enforcement update for $ENVIRONMENT environment"
    echo
    
    # Pre-update checks
    check_for_updates
    check_breaking_changes
    
    # Ask for confirmation unless forced
    if [ "$FORCE_UPDATE" = false ]; then
        echo -e "${YELLOW}Do you want to proceed with the update? (y/N)${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Update cancelled by user"
            exit 0
        fi
    fi
    
    # Pre-update safety checks
    check_pre_update_health
    create_backup
    
    # Perform update
    pull_updates
    check_env_variables
    build_update
    deploy_update
    
    # Post-update verification
    if check_post_update_health; then
        show_status
        cleanup
        
        echo
        log_success "Update completed successfully!"
        log_info "Application is running the latest version"
        
        # Show current version info
        CURRENT_COMMIT=$(get_current_commit)
        log_info "Current commit: $CURRENT_COMMIT"
        log_info "Application URL: https://${PHX_HOST:-localhost}"
    else
        log_error "Update failed health checks!"
        rollback_update
        exit 1
    fi
}

# Handle script interruption
trap 'log_error "Update interrupted"; rollback_update; exit 1' INT TERM

# Run main function
main "$@"