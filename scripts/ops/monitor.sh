#!/bin/bash

# EHS Enforcement Production Monitoring Script
# Usage: ./scripts/monitor.sh [environment] [--continuous] [--alert]

set -e

# Configuration
ENVIRONMENT=${1:-prod}
COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"
ENV_FILE=".env.${ENVIRONMENT}"
CONTINUOUS=false
ALERT_MODE=false
CHECK_INTERVAL=30

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --continuous)
      CONTINUOUS=true
      shift
      ;;
    --alert)
      ALERT_MODE=true
      shift
      ;;
    --interval)
      CHECK_INTERVAL="$2"
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
    fi
}

# Check container status
check_containers() {
    local status=0
    
    log_info "Checking container status..."
    
    # Get container status
    CONTAINER_STATUS=$(docker-compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}")
    
    # Check if all containers are running
    if echo "$CONTAINER_STATUS" | grep -v "Up" | grep -v "Name" | grep -q .; then
        log_error "Some containers are not running:"
        echo "$CONTAINER_STATUS"
        status=1
    else
        log_success "All containers are running"
    fi
    
    return $status
}

# Check application health
check_app_health() {
    local status=0
    
    log_info "Checking application health..."
    
    if command -v curl &> /dev/null; then
        HEALTH_URL="http://localhost:${PORT:-4000}/health"
        
        # Try health check
        if HEALTH_RESPONSE=$(curl -s -w "HTTP_CODE:%{http_code}" "$HEALTH_URL" 2>/dev/null); then
            HTTP_CODE=$(echo "$HEALTH_RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
            HEALTH_DATA=$(echo "$HEALTH_RESPONSE" | sed 's/HTTP_CODE:[0-9]*$//')
            
            if [ "$HTTP_CODE" = "200" ]; then
                log_success "Application health check passed"
                
                # Parse health data if it's JSON
                if command -v jq &> /dev/null && echo "$HEALTH_DATA" | jq . > /dev/null 2>&1; then
                    DATABASE_STATUS=$(echo "$HEALTH_DATA" | jq -r '.database // "unknown"')
                    APP_VERSION=$(echo "$HEALTH_DATA" | jq -r '.version // "unknown"')
                    log_info "Database: $DATABASE_STATUS, Version: $APP_VERSION"
                fi
            else
                log_error "Health check failed with HTTP $HTTP_CODE"
                status=1
            fi
        else
            log_error "Cannot reach health endpoint"
            status=1
        fi
    else
        log_warning "curl not available, skipping HTTP health check"
    fi
    
    return $status
}

# Check database connectivity
check_database() {
    local status=0
    
    log_info "Checking database connectivity..."
    
    if docker-compose -f "$COMPOSE_FILE" exec postgres pg_isready -U postgres > /dev/null 2>&1; then
        log_success "Database is accessible"
        
        # Get database stats
        DB_CONNECTIONS=$(docker-compose -f "$COMPOSE_FILE" exec postgres psql -U postgres -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | tr -d ' ' || echo "unknown")
        log_info "Active database connections: $DB_CONNECTIONS"
    else
        log_error "Database is not accessible"
        status=1
    fi
    
    return $status
}

# Check disk space
check_disk_space() {
    local status=0
    
    log_info "Checking disk space..."
    
    # Check root filesystem
    ROOT_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$ROOT_USAGE" -gt 85 ]; then
        log_error "Root filesystem usage is ${ROOT_USAGE}% (threshold: 85%)"
        status=1
    else
        log_success "Root filesystem usage: ${ROOT_USAGE}%"
    fi
    
    # Check Docker space
    if command -v docker &> /dev/null; then
        DOCKER_USAGE=$(df $(docker info --format '{{.DockerRootDir}}') 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//' || echo "0")
        if [ "$DOCKER_USAGE" -gt 85 ]; then
            log_warning "Docker storage usage is ${DOCKER_USAGE}% (threshold: 85%)"
        else
            log_info "Docker storage usage: ${DOCKER_USAGE}%"
        fi
    fi
    
    return $status
}

# Check memory usage
check_memory() {
    local status=0
    
    log_info "Checking memory usage..."
    
    # System memory
    if command -v free &> /dev/null; then
        MEMORY_USAGE=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
        if [ "$MEMORY_USAGE" -gt 90 ]; then
            log_error "System memory usage is ${MEMORY_USAGE}% (threshold: 90%)"
            status=1
        else
            log_success "System memory usage: ${MEMORY_USAGE}%"
        fi
    fi
    
    # Container memory usage
    if command -v docker &> /dev/null; then
        log_info "Container memory usage:"
        docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}" | grep -E "(ehs_enforcement|postgres)" || true
    fi
    
    return $status
}

# Check log files for errors
check_logs() {
    local status=0
    
    log_info "Checking recent logs for errors..."
    
    # Check application logs for errors in last 5 minutes
    ERROR_COUNT=$(docker-compose -f "$COMPOSE_FILE" logs --since=5m app 2>/dev/null | grep -i error | wc -l || echo "0")
    
    if [ "$ERROR_COUNT" -gt 0 ]; then
        log_warning "Found $ERROR_COUNT error(s) in application logs (last 5 minutes)"
        if [ "$ERROR_COUNT" -gt 10 ]; then
            status=1
        fi
    else
        log_success "No errors in recent application logs"
    fi
    
    return $status
}

# Send alert (placeholder - integrate with your notification system)
send_alert() {
    local message="$1"
    local severity="$2"
    
    log_error "ALERT [$severity]: $message"
    
    # Example integrations (uncomment and configure as needed):
    
    # Slack webhook
    # curl -X POST -H 'Content-type: application/json' \
    #   --data "{\"text\":\"EHS Enforcement Alert [$severity]: $message\"}" \
    #   "$SLACK_WEBHOOK_URL"
    
    # Email (requires mailutils)
    # echo "$message" | mail -s "EHS Enforcement Alert [$severity]" admin@example.com
    
    # Discord webhook
    # curl -H "Content-Type: application/json" \
    #   -X POST \
    #   -d "{\"content\": \"**EHS Enforcement Alert [$severity]:** $message\"}" \
    #   "$DISCORD_WEBHOOK_URL"
}

# Comprehensive health check
run_health_check() {
    local overall_status=0
    local failed_checks=()
    
    log_info "Running comprehensive health check..."
    echo
    
    # Run all checks
    if ! check_containers; then
        failed_checks+=("containers")
        overall_status=1
    fi
    
    if ! check_app_health; then
        failed_checks+=("application")
        overall_status=1
    fi
    
    if ! check_database; then
        failed_checks+=("database")
        overall_status=1
    fi
    
    if ! check_disk_space; then
        failed_checks+=("disk_space")
        overall_status=1
    fi
    
    if ! check_memory; then
        failed_checks+=("memory")
        overall_status=1
    fi
    
    if ! check_logs; then
        failed_checks+=("logs")
        overall_status=1
    fi
    
    echo
    
    if [ $overall_status -eq 0 ]; then
        log_success "All health checks passed!"
    else
        log_error "Health check failed for: ${failed_checks[*]}"
        
        if [ "$ALERT_MODE" = true ]; then
            send_alert "Health check failed for: ${failed_checks[*]}" "HIGH"
        fi
    fi
    
    return $overall_status
}

# Show system information
show_system_info() {
    log_info "System Information:"
    echo "  Hostname: $(hostname)"
    echo "  Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo "  Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    echo "  Docker Version: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
    echo "  Environment: $ENVIRONMENT"
    echo
}

# Main monitoring function
main() {
    log_info "Starting EHS Enforcement monitoring - $ENVIRONMENT environment"
    echo
    
    # Load environment variables
    load_env
    
    if [ "$CONTINUOUS" = true ]; then
        log_info "Running continuous monitoring (interval: ${CHECK_INTERVAL}s)"
        log_info "Press Ctrl+C to stop"
        echo
        
        while true; do
            run_health_check
            echo
            log_info "Next check in ${CHECK_INTERVAL} seconds..."
            sleep "$CHECK_INTERVAL"
            echo "===========================================" 
        done
    else
        show_system_info
        run_health_check
        
        echo
        log_info "Monitoring completed"
        log_info "For continuous monitoring, run: $0 $ENVIRONMENT --continuous"
    fi
}

# Handle script interruption
trap 'echo; log_info "Monitoring stopped"; exit 0' INT TERM

# Show usage if --help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [environment] [options]"
    echo
    echo "Options:"
    echo "  --continuous        Run continuous monitoring"
    echo "  --alert            Enable alert notifications"
    echo "  --interval <secs>   Check interval for continuous mode (default: 30)"
    echo
    echo "Examples:"
    echo "  $0 prod                     # Single health check"
    echo "  $0 prod --continuous        # Continuous monitoring"
    echo "  $0 prod --continuous --alert --interval 60  # Monitoring with alerts"
    echo
    exit 0
fi

# Run main function
main "$@"