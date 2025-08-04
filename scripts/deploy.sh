#!/bin/bash

# EHS Enforcement Production Deployment Script
# Usage: ./scripts/deploy.sh [environment]

set -e

# Configuration
ENVIRONMENT=${1:-prod}
COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"
ENV_FILE=".env.${ENVIRONMENT}"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if environment file exists
    if [ ! -f "$ENV_FILE" ]; then
        log_error "Environment file $ENV_FILE not found. Please create it from .env.example"
        exit 1
    fi
    
    # Check if compose file exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "Docker Compose file $COMPOSE_FILE not found."
        exit 1
    fi
    
    log_success "Prerequisites check completed"
}

# Validate environment variables
validate_environment() {
    log_info "Validating environment variables..."
    
    # Source the environment file
    set -a
    source "$ENV_FILE"
    set +a
    
    # Required variables
    REQUIRED_VARS=(
        "SECRET_KEY_BASE"
        "DATABASE_URL"
        "PHX_HOST"
        "GITHUB_CLIENT_ID"
        "GITHUB_CLIENT_SECRET"
        "TOKEN_SIGNING_SECRET"
    )
    
    for var in "${REQUIRED_VARS[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    log_success "Environment validation completed"
}

# Build application
build_application() {
    log_info "Building application..."
    
    # Build Docker images
    docker-compose -f "$COMPOSE_FILE" build --no-cache
    
    log_success "Application build completed"
}

# Deploy application
deploy_application() {
    log_info "Deploying application..."
    
    # Stop existing containers
    docker-compose -f "$COMPOSE_FILE" down
    
    # Start new containers
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # Wait for database to be ready
    log_info "Waiting for database to be ready..."
    sleep 30
    
    # Run database setup/migrations
    log_info "Running database setup..."
    docker-compose -f "$COMPOSE_FILE" exec -T app bin/migrate
    
    log_success "Application deployment completed"
}

# Health check
health_check() {
    log_info "Performing health check..."
    
    # Wait for application to start
    sleep 10
    
    # Check if containers are running
    if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        log_error "Some containers are not running"
        docker-compose -f "$COMPOSE_FILE" logs
        exit 1
    fi
    
    # Check application health endpoint
    if command -v curl &> /dev/null; then
        HEALTH_URL="http://localhost:${PORT:-4000}/health"
        if curl -f -s "$HEALTH_URL" > /dev/null; then
            log_success "Health check passed"
        else
            log_warning "Health check endpoint not responding, but containers are running"
        fi
    else
        log_info "curl not available, skipping HTTP health check"
    fi
}

# Backup database
backup_database() {
    log_info "Creating database backup..."
    
    # Create backup directory
    mkdir -p backups
    
    # Create backup filename with timestamp
    BACKUP_FILE="backups/backup_$(date +%Y%m%d_%H%M%S).sql"
    
    # Create backup
    docker-compose -f "$COMPOSE_FILE" exec -T postgres pg_dump -U postgres "${DATABASE_NAME:-ehs_enforcement_prod}" > "$BACKUP_FILE"
    
    # Compress backup
    gzip "$BACKUP_FILE"
    
    log_success "Database backup created: ${BACKUP_FILE}.gz"
}

# Show deployment status
show_status() {
    log_info "Deployment Status:"
    echo
    
    # Show running containers
    docker-compose -f "$COMPOSE_FILE" ps
    echo
    
    # Show recent logs
    log_info "Recent application logs:"
    docker-compose -f "$COMPOSE_FILE" logs --tail=20 app
}

# Cleanup old Docker images
cleanup() {
    log_info "Cleaning up old Docker images..."
    
    # Remove dangling images
    docker image prune -f
    
    # Remove old containers
    docker container prune -f
    
    log_success "Cleanup completed"
}

# Main deployment process
main() {
    log_info "Starting EHS Enforcement deployment to $ENVIRONMENT environment"
    echo
    
    check_prerequisites
    validate_environment
    
    # Create backup before deployment (production only)
    if [ "$ENVIRONMENT" = "prod" ]; then
        backup_database
    fi
    
    build_application
    deploy_application
    health_check
    show_status
    cleanup
    
    echo
    log_success "Deployment completed successfully!"
    log_info "Application should be available at: https://${PHX_HOST:-localhost}"
    
    # Show useful commands
    echo
    log_info "Useful commands for managing the deployment:"
    echo "  View logs:     docker-compose -f $COMPOSE_FILE logs -f app"
    echo "  Restart app:   docker-compose -f $COMPOSE_FILE restart app"
    echo "  Stop app:      docker-compose -f $COMPOSE_FILE down"
    echo "  Shell access:  docker-compose -f $COMPOSE_FILE exec app sh"
    echo "  Run migrations: docker-compose -f $COMPOSE_FILE exec app bin/migrate"
}

# Handle script interruption
trap 'log_error "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"