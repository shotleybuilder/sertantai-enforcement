#!/bin/bash

# EHS Enforcement Database Backup Script
# Usage: ./scripts/backup.sh [environment] [--restore <backup_file>]

set -e

# Configuration
ENVIRONMENT=${1:-prod}
COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"
ENV_FILE=".env.${ENVIRONMENT}"
BACKUP_DIR="backups"
RESTORE_MODE=false
RESTORE_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --restore)
      RESTORE_MODE=true
      RESTORE_FILE="$2"
      shift 2
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

# Load environment variables
load_env() {
    if [ -f "$ENV_FILE" ]; then
        set -a
        source "$ENV_FILE"
        set +a
    else
        log_error "Environment file $ENV_FILE not found"
        exit 1
    fi
}

# Check if database is running
check_database() {
    log_info "Checking database connection..."
    
    if ! docker-compose -f "$COMPOSE_FILE" exec postgres pg_isready -U postgres > /dev/null 2>&1; then
        log_error "Database is not running or not accessible"
        exit 1
    fi
    
    log_success "Database connection verified"
}

# Create backup
create_backup() {
    log_info "Creating database backup..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Generate backup filename
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.sql"
    
    # Get database name
    DB_NAME="${DATABASE_NAME:-ehs_enforcement_${ENVIRONMENT}}"
    
    # Create backup
    log_info "Backing up database: $DB_NAME"
    docker-compose -f "$COMPOSE_FILE" exec -T postgres pg_dump -U postgres --verbose --no-password "$DB_NAME" > "$BACKUP_FILE"
    
    # Compress backup
    gzip "$BACKUP_FILE"
    COMPRESSED_BACKUP="${BACKUP_FILE}.gz"
    
    # Get backup size
    BACKUP_SIZE=$(du -h "$COMPRESSED_BACKUP" | cut -f1)
    
    log_success "Backup created successfully!"
    log_info "File: $COMPRESSED_BACKUP"
    log_info "Size: $BACKUP_SIZE"
    
    # Cleanup old backups (keep last 10)
    cleanup_old_backups
    
    echo "$COMPRESSED_BACKUP"
}

# Restore from backup
restore_backup() {
    if [ ! -f "$RESTORE_FILE" ]; then
        log_error "Backup file not found: $RESTORE_FILE"
        exit 1
    fi
    
    log_warning "This will completely replace the current database!"
    log_warning "Backup file: $RESTORE_FILE"
    
    # Ask for confirmation
    echo -e "${YELLOW}Are you sure you want to restore from this backup? (type 'yes' to confirm)${NC}"
    read -r response
    if [ "$response" != "yes" ]; then
        log_info "Restore cancelled"
        exit 0
    fi
    
    log_info "Starting database restore..."
    
    # Get database name
    DB_NAME="${DATABASE_NAME:-ehs_enforcement_${ENVIRONMENT}}"
    
    # Create a backup of current state before restore
    log_info "Creating safety backup of current database..."
    SAFETY_BACKUP="${BACKUP_DIR}/pre_restore_$(date +%Y%m%d_%H%M%S).sql"
    docker-compose -f "$COMPOSE_FILE" exec -T postgres pg_dump -U postgres "$DB_NAME" > "$SAFETY_BACKUP"
    gzip "$SAFETY_BACKUP"
    log_info "Safety backup created: ${SAFETY_BACKUP}.gz"
    
    # Drop existing connections
    log_info "Terminating database connections..."
    docker-compose -f "$COMPOSE_FILE" exec postgres psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();"
    
    # Drop and recreate database
    log_info "Dropping and recreating database..."
    docker-compose -f "$COMPOSE_FILE" exec postgres dropdb -U postgres "$DB_NAME" || true
    docker-compose -f "$COMPOSE_FILE" exec postgres createdb -U postgres "$DB_NAME"
    
    # Restore from backup
    log_info "Restoring from backup..."
    if [[ "$RESTORE_FILE" == *.gz ]]; then
        gunzip -c "$RESTORE_FILE" | docker-compose -f "$COMPOSE_FILE" exec -T postgres psql -U postgres "$DB_NAME"
    else
        docker-compose -f "$COMPOSE_FILE" exec -T postgres psql -U postgres "$DB_NAME" < "$RESTORE_FILE"
    fi
    
    log_success "Database restore completed!"
    log_info "Safety backup available at: ${SAFETY_BACKUP}.gz"
}

# List available backups
list_backups() {
    log_info "Available backups:"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_warning "No backup directory found"
        return
    fi
    
    # List backup files with details
    find "$BACKUP_DIR" -name "*.sql.gz" -o -name "*.sql" | sort -r | head -20 | while read -r backup; do
        SIZE=$(du -h "$backup" | cut -f1)
        MODIFIED=$(stat -c %y "$backup" | cut -d' ' -f1,2 | cut -d'.' -f1)
        echo "  $(basename "$backup") - $SIZE - $MODIFIED"
    done
}

# Cleanup old backups
cleanup_old_backups() {
    log_info "Cleaning up old backups (keeping last 10)..."
    
    # Keep only the 10 most recent backups
    find "$BACKUP_DIR" -name "backup_*.sql.gz" -type f | sort -r | tail -n +11 | while read -r old_backup; do
        log_info "Removing old backup: $(basename "$old_backup")"
        rm "$old_backup"
    done
}

# Verify backup integrity
verify_backup() {
    local backup_file="$1"
    
    log_info "Verifying backup integrity..."
    
    if [[ "$backup_file" == *.gz ]]; then
        if gunzip -t "$backup_file" 2>/dev/null; then
            log_success "Backup file integrity verified"
        else
            log_error "Backup file is corrupted"
            return 1
        fi
    else
        if [ -f "$backup_file" ] && [ -s "$backup_file" ]; then
            log_success "Backup file exists and is not empty"
        else
            log_error "Backup file is missing or empty"
            return 1
        fi
    fi
}

# Test restore (dry run)
test_restore() {
    local backup_file="$1"
    
    log_info "Testing backup restore (dry run)..."
    
    # Create temporary database for testing
    TEST_DB="test_restore_$(date +%s)"
    
    docker-compose -f "$COMPOSE_FILE" exec postgres createdb -U postgres "$TEST_DB"
    
    # Attempt restore to test database
    if [[ "$backup_file" == *.gz ]]; then
        if gunzip -c "$backup_file" | docker-compose -f "$COMPOSE_FILE" exec -T postgres psql -U postgres "$TEST_DB" > /dev/null 2>&1; then
            log_success "Test restore successful"
        else
            log_error "Test restore failed"
            docker-compose -f "$COMPOSE_FILE" exec postgres dropdb -U postgres "$TEST_DB" || true
            return 1
        fi
    else
        if docker-compose -f "$COMPOSE_FILE" exec -T postgres psql -U postgres "$TEST_DB" < "$backup_file" > /dev/null 2>&1; then
            log_success "Test restore successful"
        else
            log_error "Test restore failed"
            docker-compose -f "$COMPOSE_FILE" exec postgres dropdb -U postgres "$TEST_DB" || true
            return 1
        fi
    fi
    
    # Cleanup test database
    docker-compose -f "$COMPOSE_FILE" exec postgres dropdb -U postgres "$TEST_DB"
}

# Show backup statistics
show_stats() {
    log_info "Backup Statistics:"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_warning "No backup directory found"
        return
    fi
    
    TOTAL_BACKUPS=$(find "$BACKUP_DIR" -name "*.sql.gz" -o -name "*.sql" | wc -l)
    TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "0")
    OLDEST_BACKUP=$(find "$BACKUP_DIR" -name "*.sql.gz" -o -name "*.sql" | xargs ls -t | tail -n1 | xargs basename 2>/dev/null || echo "None")
    NEWEST_BACKUP=$(find "$BACKUP_DIR" -name "*.sql.gz" -o -name "*.sql" | xargs ls -t | head -n1 | xargs basename 2>/dev/null || echo "None")
    
    echo "  Total backups: $TOTAL_BACKUPS"
    echo "  Total size: $TOTAL_SIZE"
    echo "  Oldest backup: $OLDEST_BACKUP"
    echo "  Newest backup: $NEWEST_BACKUP"
}

# Main function
main() {
    log_info "EHS Enforcement Database Management - $ENVIRONMENT environment"
    echo
    
    # Load environment variables
    load_env
    
    # Check database connection
    check_database
    
    if [ "$RESTORE_MODE" = true ]; then
        # Restore mode
        if [ -z "$RESTORE_FILE" ]; then
            log_error "Restore file not specified"
            echo "Usage: $0 $ENVIRONMENT --restore <backup_file>"
            echo
            list_backups
            exit 1
        fi
        
        verify_backup "$RESTORE_FILE"
        test_restore "$RESTORE_FILE"
        restore_backup
    else
        # Backup mode
        BACKUP_FILE=$(create_backup)
        verify_backup "$BACKUP_FILE"
        
        echo
        show_stats
        
        echo
        log_info "Backup completed successfully!"
        log_info "To restore from this backup, run:"
        log_info "  $0 $ENVIRONMENT --restore $BACKUP_FILE"
    fi
}

# Handle script interruption
trap 'log_error "Backup operation interrupted"; exit 1' INT TERM

# Show usage if no arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 [environment] [options]"
    echo
    echo "Options:"
    echo "  --restore <file>  Restore from backup file"
    echo
    echo "Examples:"
    echo "  $0 prod                           # Create backup"
    echo "  $0 prod --restore backup.sql.gz  # Restore from backup"
    echo
    exit 1
fi

# Run main function
main "$@"