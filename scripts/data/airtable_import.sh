#!/bin/bash

# EHS Enforcement Airtable Import Script
# Usage: ./scripts/airtable_import.sh [environment] [--full|--cases|--notices] [--limit N]

set -e

# Configuration
ENVIRONMENT=${1:-prod}
COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"
ENV_FILE=".env.${ENVIRONMENT}"
IMPORT_TYPE="full"
LIMIT=1000
BATCH_SIZE=100

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --full)
      IMPORT_TYPE="full"
      shift
      ;;
    --cases)
      IMPORT_TYPE="cases"
      shift
      ;;
    --notices)
      IMPORT_TYPE="notices"
      shift
      ;;
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    --batch-size)
      BATCH_SIZE="$2"
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites for Airtable import..."
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker is not running"
        exit 1
    fi
    
    # Check if application is running
    if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        log_error "Application containers are not running"
        log_info "Start the application first: docker-compose -f $COMPOSE_FILE up -d"
        exit 1
    fi
    
    # Check Airtable API key
    if [ -z "$AT_UK_E_API_KEY" ]; then
        log_error "AT_UK_E_API_KEY environment variable is not set"
        exit 1
    fi
    
    log_success "Prerequisites check completed"
}

# Test Airtable connectivity
test_airtable_connection() {
    log_info "Testing Airtable connectivity..."
    
    # Use Elixir to test connection
    ELIXIR_CMD="
    path = \"/appq5OQW9bTHC1zO5/tbl6NZm9bLU2ijivf\"
    case EhsEnforcement.Integrations.Airtable.ReqClient.get(path, %{maxRecords: 1}) do
      {:ok, _response} -> 
        IO.puts(\"SUCCESS: Airtable connection verified\")
        System.halt(0)
      {:error, error} -> 
        IO.puts(\"ERROR: #{inspect(error)}\")
        System.halt(1)
    end
    "
    
    if docker-compose -f "$COMPOSE_FILE" exec -T app bin/ehs_enforcement eval "$ELIXIR_CMD"; then
        log_success "Airtable connection verified"
    else
        log_error "Failed to connect to Airtable API"
        exit 1
    fi
}

# Get current record counts
get_current_counts() {
    log_info "Getting current database record counts..."
    
    ELIXIR_CMD="
    {:ok, cases} = Ash.read(EhsEnforcement.Enforcement.Case)
    {:ok, notices} = Ash.read(EhsEnforcement.Enforcement.Notice)
    {:ok, offenders} = Ash.read(EhsEnforcement.Enforcement.Offender)
    
    IO.puts(\"CURRENT_CASES=#{length(cases)}\")
    IO.puts(\"CURRENT_NOTICES=#{length(notices)}\")
    IO.puts(\"CURRENT_OFFENDERS=#{length(offenders)}\")
    "
    
    COUNTS=$(docker-compose -f "$COMPOSE_FILE" exec -T app bin/ehs_enforcement eval "$ELIXIR_CMD" | grep "CURRENT_")
    
    eval "$COUNTS"
    
    log_info "Current database state:"
    log_info "  Cases: ${CURRENT_CASES:-0}"
    log_info "  Notices: ${CURRENT_NOTICES:-0}"  
    log_info "  Offenders: ${CURRENT_OFFENDERS:-0}"
}

# Import cases from Airtable
import_cases() {
    log_info "Starting case import from Airtable (limit: $LIMIT, batch_size: $BATCH_SIZE)..."
    
    ELIXIR_CMD="
    case EhsEnforcement.Sync.import_cases(limit: $LIMIT, batch_size: $BATCH_SIZE) do
      {:ok, stats} ->
        IO.puts(\"SUCCESS: Imported #{stats.imported} cases, #{stats.errors} errors\")
        System.halt(0)
      {:error, reason} ->
        IO.puts(\"ERROR: #{inspect(reason)}\")
        System.halt(1)
    end
    "
    
    if docker-compose -f "$COMPOSE_FILE" exec -T app bin/ehs_enforcement eval "$ELIXIR_CMD"; then
        log_success "Case import completed successfully"
    else
        log_error "Case import failed"
        return 1
    fi
}

# Import notices from Airtable
import_notices() {
    log_info "Starting notice import from Airtable (limit: $LIMIT, batch_size: $BATCH_SIZE)..."
    
    ELIXIR_CMD="
    case EhsEnforcement.Sync.import_notices(limit: $LIMIT, batch_size: $BATCH_SIZE) do
      {:ok, stats} ->
        IO.puts(\"SUCCESS: Imported #{stats.imported} notices, #{stats.errors} errors\")
        System.halt(0)
      {:error, reason} ->
        IO.puts(\"ERROR: #{inspect(reason)}\")
        System.halt(1)
    end
    "
    
    if docker-compose -f "$COMPOSE_FILE" exec -T app bin/ehs_enforcement eval "$ELIXIR_CMD"; then
        log_success "Notice import completed successfully"
    else
        log_error "Notice import failed"
        return 1
    fi
}

# Get final record counts and statistics
show_import_results() {
    log_info "Getting final import statistics..."
    
    ELIXIR_CMD="
    {:ok, cases} = Ash.read(EhsEnforcement.Enforcement.Case)
    {:ok, notices} = Ash.read(EhsEnforcement.Enforcement.Notice) 
    {:ok, offenders} = Ash.read(EhsEnforcement.Enforcement.Offender)
    
    IO.puts(\"FINAL_CASES=#{length(cases)}\")
    IO.puts(\"FINAL_NOTICES=#{length(notices)}\")
    IO.puts(\"FINAL_OFFENDERS=#{length(offenders)}\")
    
    # Show sample records
    IO.puts(\"\\nSample case IDs:\")
    cases |> Enum.take(5) |> Enum.each(fn case -> 
      IO.puts(\"  #{case.regulator_id} - #{case.offender.name}\")
    end)
    
    IO.puts(\"\\nSample notice IDs:\")
    notices |> Enum.take(5) |> Enum.each(fn notice -> 
      IO.puts(\"  #{notice.regulator_id} - #{notice.offender.name}\")
    end)
    "
    
    FINAL_COUNTS=$(docker-compose -f "$COMPOSE_FILE" exec -T app bin/ehs_enforcement eval "$ELIXIR_CMD")
    
    echo "$FINAL_COUNTS"
    
    # Parse final counts for summary
    eval "$(echo "$FINAL_COUNTS" | grep "FINAL_")"
    
    echo
    log_success "Import Summary:"
    log_info "  Cases: ${CURRENT_CASES:-0} → ${FINAL_CASES:-0} (+$((${FINAL_CASES:-0} - ${CURRENT_CASES:-0})))"
    log_info "  Notices: ${CURRENT_NOTICES:-0} → ${FINAL_NOTICES:-0} (+$((${FINAL_NOTICES:-0} - ${CURRENT_NOTICES:-0})))"
    log_info "  Offenders: ${CURRENT_OFFENDERS:-0} → ${FINAL_OFFENDERS:-0} (+$((${FINAL_OFFENDERS:-0} - ${CURRENT_OFFENDERS:-0})))"
}

# Cleanup orphaned records
cleanup_orphaned_offenders() {
    log_info "Cleaning up orphaned offenders..."
    
    ELIXIR_CMD="
    case EhsEnforcement.Sync.cleanup_orphaned_offenders() do
      {:ok, stats} ->
        IO.puts(\"SUCCESS: Found #{stats.orphaned_count} orphaned, deleted #{stats.deleted_count}\")
        System.halt(0)
      {:error, reason} ->
        IO.puts(\"ERROR: #{inspect(reason)}\")
        System.halt(1)
    end
    "
    
    if docker-compose -f "$COMPOSE_FILE" exec -T app bin/ehs_enforcement eval "$ELIXIR_CMD"; then
        log_success "Orphaned offender cleanup completed"
    else
        log_warning "Orphaned offender cleanup had issues (non-critical)"
    fi
}

# Main import function
run_import() {
    log_info "Starting Airtable import for $ENVIRONMENT environment"
    log_info "Import type: $IMPORT_TYPE, Limit: $LIMIT, Batch size: $BATCH_SIZE"
    echo
    
    # Prerequisites and setup
    load_env
    check_prerequisites
    test_airtable_connection
    get_current_counts
    
    echo
    log_info "Starting import process..."
    
    # Run imports based on type
    case $IMPORT_TYPE in
        "full")
            log_info "Running full import (cases + notices)..."
            if import_cases && import_notices; then
                log_success "Full import completed successfully"
            else
                log_error "Full import encountered errors"
                exit 1
            fi
            ;;
        "cases")
            log_info "Running cases-only import..."
            if import_cases; then
                log_success "Cases import completed successfully"
            else
                log_error "Cases import failed"
                exit 1
            fi
            ;;
        "notices")
            log_info "Running notices-only import..."
            if import_notices; then
                log_success "Notices import completed successfully"
            else
                log_error "Notices import failed"
                exit 1
            fi
            ;;
    esac
    
    # Post-import cleanup and statistics
    echo
    cleanup_orphaned_offenders
    show_import_results
    
    echo
    log_success "Airtable import process completed!"
    log_info "Check the application logs for detailed import information"
}

# Handle script interruption
trap 'log_error "Import interrupted"; exit 1' INT TERM

# Show usage if --help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [environment] [options]"
    echo
    echo "Options:"
    echo "  --full              Import both cases and notices (default)"
    echo "  --cases             Import only cases"
    echo "  --notices           Import only notices"
    echo "  --limit N           Maximum records to import (default: 1000)"
    echo "  --batch-size N      Records per batch (default: 100)"
    echo
    echo "Examples:"
    echo "  $0 prod --full --limit 5000              # Full import with 5000 record limit"
    echo "  $0 prod --cases --limit 2000             # Import only cases"
    echo "  $0 prod --notices --batch-size 50        # Import notices with smaller batches"
    echo
    exit 0
fi

# Run main function
run_import "$@"