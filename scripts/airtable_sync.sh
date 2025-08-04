#!/bin/bash

# EHS Enforcement Airtable Sync Script  
# Usage: ./scripts/airtable_sync.sh [environment] [--incremental|--full] [--schedule]

set -e

# Configuration
ENVIRONMENT=${1:-prod}
COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"
ENV_FILE=".env.${ENVIRONMENT}"
SYNC_TYPE="incremental"
SCHEDULE_MODE=false
LOG_FILE="/var/log/airtable_sync.log"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --incremental)
      SYNC_TYPE="incremental"
      shift
      ;;
    --full)
      SYNC_TYPE="full"
      shift
      ;;
    --schedule)
      SCHEDULE_MODE=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Colors for output (disabled in schedule mode)
if [ "$SCHEDULE_MODE" = true ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

# Logging functions
log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Setup logging for scheduled runs
setup_logging() {
    if [ "$SCHEDULE_MODE" = true ]; then
        # Create log directory if it doesn't exist
        mkdir -p "$(dirname "$LOG_FILE")"
        
        # Redirect all output to log file
        exec 1> >(tee -a "$LOG_FILE")
        exec 2> >(tee -a "$LOG_FILE" >&2)
        
        log_info "=== Starting scheduled Airtable sync ==="
    fi
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

# Check if sync should run
should_sync() {
    # For incremental syncs, check if enough time has passed
    if [ "$SYNC_TYPE" = "incremental" ]; then
        LAST_SYNC_FILE="/tmp/last_airtable_sync"
        
        if [ -f "$LAST_SYNC_FILE" ]; then
            LAST_SYNC=$(cat "$LAST_SYNC_FILE")
            CURRENT_TIME=$(date +%s)
            TIME_DIFF=$((CURRENT_TIME - LAST_SYNC))
            
            # Don't sync more than once per hour (3600 seconds)
            if [ $TIME_DIFF -lt 3600 ]; then
                log_info "Last sync was $((TIME_DIFF / 60)) minutes ago. Skipping sync."
                return 1
            fi
        fi
    fi
    
    return 0
}

# Update last sync timestamp
update_last_sync() {
    echo "$(date +%s)" > /tmp/last_airtable_sync
}

# Check application health
check_application_health() {
    log_info "Checking application health before sync..."
    
    # Check if containers are running
    if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        log_error "Application containers are not running"
        return 1
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
    
    return 0
}

# Get sync statistics
get_sync_stats() {
    log_info "Getting current sync statistics..."
    
    ELIXIR_CMD="
    {:ok, case_stats} = EhsEnforcement.Sync.get_case_import_stats()
    {:ok, notice_stats} = EhsEnforcement.Sync.get_notice_import_stats()
    
    IO.puts(\"TOTAL_CASES=#{case_stats.total_cases}\")
    IO.puts(\"TOTAL_NOTICES=#{notice_stats.total_notices}\")
    IO.puts(\"CASE_ERROR_RATE=#{case_stats.error_rate}\")
    IO.puts(\"NOTICE_ERROR_RATE=#{notice_stats.error_rate}\")
    "
    
    STATS=$(docker-compose -f "$COMPOSE_FILE" exec -T app bin/ehs_enforcement eval "$ELIXIR_CMD" | grep "TOTAL_\|ERROR_RATE")
    
    if [ -n "$STATS" ]; then
        eval "$STATS"
        log_info "Current statistics:"
        log_info "  Total Cases: ${TOTAL_CASES:-0}"
        log_info "  Total Notices: ${TOTAL_NOTICES:-0}"
        log_info "  Case Error Rate: ${CASE_ERROR_RATE:-0}%"
        log_info "  Notice Error Rate: ${NOTICE_ERROR_RATE:-0}%"
    fi
}

# Run incremental sync
run_incremental_sync() {
    log_info "Running incremental sync (new records only)..."
    
    # For incremental sync, use smaller limits to get recent records
    INCREMENTAL_LIMIT=500
    BATCH_SIZE=50
    
    log_info "Incremental sync - Cases (limit: $INCREMENTAL_LIMIT)..."
    CASE_ELIXIR_CMD="
    case EhsEnforcement.Sync.import_cases(limit: $INCREMENTAL_LIMIT, batch_size: $BATCH_SIZE) do
      {:ok, stats} ->
        IO.puts(\"CASE_IMPORTED=#{stats.imported}\")
        IO.puts(\"CASE_ERRORS=#{stats.errors}\")
        System.halt(0)
      {:error, reason} ->
        IO.puts(\"ERROR: #{inspect(reason)}\")
        System.halt(1)
    end
    "
    
    if CASE_RESULT=$(docker-compose -f "$COMPOSE_FILE" exec -T app bin/ehs_enforcement eval "$CASE_ELIXIR_CMD"); then
        eval "$(echo "$CASE_RESULT" | grep "CASE_")"
        log_success "Cases: imported ${CASE_IMPORTED:-0}, errors ${CASE_ERRORS:-0}"
    else
        log_error "Case incremental sync failed"
        return 1
    fi
    
    log_info "Incremental sync - Notices (limit: $INCREMENTAL_LIMIT)..."
    NOTICE_ELIXIR_CMD="
    case EhsEnforcement.Sync.import_notices(limit: $INCREMENTAL_LIMIT, batch_size: $BATCH_SIZE) do
      {:ok, stats} ->
        IO.puts(\"NOTICE_IMPORTED=#{stats.imported}\")
        IO.puts(\"NOTICE_ERRORS=#{stats.errors}\")
        System.halt(0)
      {:error, reason} ->
        IO.puts(\"ERROR: #{inspect(reason)}\")
        System.halt(1)
    end
    "
    
    if NOTICE_RESULT=$(docker-compose -f "$COMPOSE_FILE" exec -T app bin/ehs_enforcement eval "$NOTICE_ELIXIR_CMD"); then
        eval "$(echo "$NOTICE_RESULT" | grep "NOTICE_")"
        log_success "Notices: imported ${NOTICE_IMPORTED:-0}, errors ${NOTICE_ERRORS:-0}"
    else
        log_error "Notice incremental sync failed"
        return 1
    fi
    
    # Update last sync timestamp
    update_last_sync
    
    return 0
}

# Run full sync
run_full_sync() {
    log_info "Running full sync (all records)..."
    
    # Use the full import script for comprehensive sync
    if ./scripts/airtable_import.sh "$ENVIRONMENT" --full --limit 10000; then
        log_success "Full sync completed successfully"
        update_last_sync
        return 0
    else
        log_error "Full sync failed"
        return 1
    fi
}

# Send notification (placeholder for your notification system)
send_notification() {
    local message="$1"
    local level="$2"
    
    log_info "NOTIFICATION [$level]: $message"
    
    # Example integrations (uncomment and configure as needed):
    
    # Slack webhook
    # if [ -n "$SLACK_WEBHOOK_URL" ]; then
    #     curl -X POST -H 'Content-type: application/json' \
    #       --data "{\"text\":\"EHS Enforcement Sync [$level]: $message\"}" \
    #       "$SLACK_WEBHOOK_URL"
    # fi
    
    # Email notification
    # if command -v mail &> /dev/null && [ -n "$ADMIN_EMAIL" ]; then
    #     echo "$message" | mail -s "EHS Enforcement Sync [$level]" "$ADMIN_EMAIL"
    # fi
}

# Cleanup and maintenance
run_maintenance() {
    log_info "Running post-sync maintenance..."
    
    # Clean up orphaned offenders
    CLEANUP_CMD="
    case EhsEnforcement.Sync.cleanup_orphaned_offenders(dry_run: false) do
      {:ok, stats} ->
        IO.puts(\"CLEANUP_ORPHANED=#{stats.orphaned_count}\")
        IO.puts(\"CLEANUP_DELETED=#{stats.deleted_count}\")
        System.halt(0)
      {:error, reason} ->
        IO.puts(\"ERROR: #{inspect(reason)}\")
        System.halt(1)
    end
    "
    
    if CLEANUP_RESULT=$(docker-compose -f "$COMPOSE_FILE" exec -T app bin/ehs_enforcement eval "$CLEANUP_CMD"); then
        eval "$(echo "$CLEANUP_RESULT" | grep "CLEANUP_")"
        if [ "${CLEANUP_DELETED:-0}" -gt 0 ]; then
            log_info "Maintenance: cleaned up ${CLEANUP_DELETED} orphaned offenders"
        fi
    else
        log_warning "Maintenance cleanup had issues (non-critical)"
    fi
}

# Generate sync report
generate_sync_report() {
    local sync_result=$1
    
    log_info "Generating sync report..."
    
    # Get final statistics
    get_sync_stats
    
    if [ $sync_result -eq 0 ]; then
        REPORT_MESSAGE="Airtable sync completed successfully for $ENVIRONMENT environment.
Type: $SYNC_TYPE
Cases: ${CASE_IMPORTED:-0} imported, ${CASE_ERRORS:-0} errors
Notices: ${NOTICE_IMPORTED:-0} imported, ${NOTICE_ERRORS:-0} errors
Total Database Records: ${TOTAL_CASES:-0} cases, ${TOTAL_NOTICES:-0} notices"
        
        send_notification "$REPORT_MESSAGE" "SUCCESS"
    else
        REPORT_MESSAGE="Airtable sync failed for $ENVIRONMENT environment.
Type: $SYNC_TYPE
Check logs for detailed error information."
        
        send_notification "$REPORT_MESSAGE" "ERROR"
    fi
}

# Main sync function
main() {
    setup_logging
    
    log_info "Starting Airtable sync for $ENVIRONMENT environment (type: $SYNC_TYPE)"
    
    # Load environment and check prerequisites
    load_env
    
    # Check if sync should run (for scheduled runs)
    if ! should_sync; then
        if [ "$SCHEDULE_MODE" = true ]; then
            exit 0  # Silent exit for cron jobs
        else
            log_info "Sync skipped due to timing restrictions"
            exit 0
        fi
    fi
    
    # Check application health
    if ! check_application_health; then
        log_error "Application health check failed. Aborting sync."
        generate_sync_report 1
        exit 1
    fi
    
    # Get pre-sync statistics
    get_sync_stats
    
    # Run the appropriate sync type
    if [ "$SYNC_TYPE" = "incremental" ]; then
        run_incremental_sync
        SYNC_RESULT=$?
    else
        run_full_sync
        SYNC_RESULT=$?
    fi
    
    # Post-sync maintenance
    if [ $SYNC_RESULT -eq 0 ]; then
        run_maintenance
    fi
    
    # Generate report
    generate_sync_report $SYNC_RESULT
    
    if [ $SYNC_RESULT -eq 0 ]; then
        log_success "Airtable sync completed successfully!"
    else
        log_error "Airtable sync failed!"
        exit 1
    fi
}

# Handle script interruption
trap 'log_error "Sync interrupted"; exit 1' INT TERM

# Show usage if --help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [environment] [options]"
    echo
    echo "Options:"
    echo "  --incremental       Run incremental sync (default, gets recent records)"
    echo "  --full              Run full sync (all records)"
    echo "  --schedule          Run in scheduled mode (for cron jobs)"
    echo
    echo "Examples:"
    echo "  $0 prod --incremental           # Manual incremental sync"
    echo "  $0 prod --full                  # Manual full sync"
    echo "  $0 prod --incremental --schedule # Scheduled incremental sync (for cron)"
    echo
    echo "Cron job example (daily at 2 AM):"
    echo "  0 2 * * * /opt/ehs_enforcement/scripts/airtable_sync.sh prod --incremental --schedule"
    echo
    exit 0
fi

# Run main function
main "$@"