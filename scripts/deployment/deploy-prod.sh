#!/bin/bash
#
# deploy-prod.sh - Deploy EHS Enforcement to production server
#
# This script connects to the production server (sertantai) and deploys
# the latest Docker image from GHCR. It handles pulling the image,
# checking for migrations, and restarting the container.
#
# Usage:
#   ./scripts/deploy-prod.sh [options]
#
# Options:
#   --migrate      Run migrations after deployment
#   --check-only   Only check status, don't deploy
#   --logs         Follow logs after deployment
#
# Prerequisites:
#   - SSH access to sertantai server configured
#   - Image pushed to GHCR: ./scripts/push.sh
#
# Production server details:
#   - Server: sertantai (Digital Ocean droplet)
#   - Path: ~/infrastructure/docker
#   - URL: https://legal.sertantai.com
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER="sertantai"
DEPLOY_PATH="~/infrastructure/docker"
SERVICE_NAME="ehs-enforcement"

# Parse command line options
RUN_MIGRATIONS=false
CHECK_ONLY=false
FOLLOW_LOGS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --migrate)
            RUN_MIGRATIONS=true
            shift
            ;;
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        --logs)
            FOLLOW_LOGS=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --migrate      Run migrations after deployment"
            echo "  --check-only   Only check status, don't deploy"
            echo "  --logs         Follow logs after deployment"
            echo "  --help         Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  EHS Enforcement - Production Deployment${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Server:${NC} ${SERVER}"
echo -e "${YELLOW}Service:${NC} ${SERVICE_NAME}"
echo -e "${YELLOW}URL:${NC} https://legal.sertantai.com"
echo ""

# Check SSH connectivity
echo -e "${BLUE}Checking SSH connection to ${SERVER}...${NC}"
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "${SERVER}" "echo 'SSH OK'" > /dev/null 2>&1; then
    echo -e "${RED}✗ Cannot connect to ${SERVER}${NC}"
    echo -e "${YELLOW}  Check your SSH configuration and try again${NC}"
    exit 1
fi
echo -e "${GREEN}✓ SSH connection OK${NC}"
echo ""

# Check current status
if [ "$CHECK_ONLY" = true ]; then
    echo -e "${BLUE}Checking production status...${NC}"
    echo ""

    ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose ps ${SERVICE_NAME}"

    echo ""
    echo -e "${BLUE}Recent logs:${NC}"
    ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose logs --tail=20 ${SERVICE_NAME}"

    echo ""
    echo -e "${GREEN}Status check complete${NC}"
    exit 0
fi

# Start deployment
echo -e "${BLUE}Starting deployment...${NC}"
echo ""

# Pull latest image
echo -e "${BLUE}[1/4] Pulling latest image from GHCR...${NC}"
ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose pull ${SERVICE_NAME}"

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to pull image${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Image pulled successfully${NC}"
echo ""

# Check migration status
echo -e "${BLUE}[2/4] Checking migration status...${NC}"
ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose exec -T ${SERVICE_NAME} /app/bin/ehs_enforcement eval 'EhsEnforcement.Release.status'" || {
    echo -e "${YELLOW}⚠ Could not check migration status (container may not be running)${NC}"
}
echo ""

# Run migrations if requested
if [ "$RUN_MIGRATIONS" = true ]; then
    echo -e "${BLUE}[3/4] Running migrations...${NC}"
    ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose exec -T ${SERVICE_NAME} /app/bin/ehs_enforcement eval 'EhsEnforcement.Release.migrate'"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Migrations complete${NC}"
    else
        echo -e "${RED}✗ Migration failed${NC}"
        echo -e "${YELLOW}  Check logs for details${NC}"
        exit 1
    fi
    echo ""
else
    echo -e "${YELLOW}[3/4] Skipping migrations (use --migrate to run)${NC}"
    echo ""
fi

# Restart container
echo -e "${BLUE}[4/4] Restarting container...${NC}"
ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose up -d ${SERVICE_NAME}"

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to restart container${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Container restarted${NC}"
echo ""

# Wait a moment for startup
echo -e "${BLUE}Waiting for startup...${NC}"
sleep 5

# Check health
echo -e "${BLUE}Checking health endpoint...${NC}"
HEALTH_CHECK=$(ssh "${SERVER}" "curl -s -o /dev/null -w '%{http_code}' http://localhost:4002/health" || echo "000")

if [ "$HEALTH_CHECK" = "200" ]; then
    echo -e "${GREEN}✓ Health check passed (HTTP 200)${NC}"
else
    echo -e "${YELLOW}⚠ Health check returned HTTP ${HEALTH_CHECK}${NC}"
    echo -e "${YELLOW}  The application may still be starting up${NC}"
fi
echo ""

# Success summary
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Deployment complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Application:${NC} https://legal.sertantai.com"
echo -e "${YELLOW}Health:${NC} https://legal.sertantai.com/health"
echo ""

# Show recent logs
echo -e "${BLUE}Recent logs:${NC}"
ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose logs --tail=15 ${SERVICE_NAME}"
echo ""

# Follow logs if requested
if [ "$FOLLOW_LOGS" = true ]; then
    echo -e "${BLUE}Following logs (Ctrl+C to exit)...${NC}"
    echo ""
    ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose logs -f ${SERVICE_NAME}"
else
    echo -e "${BLUE}To follow logs:${NC}"
    echo -e "  ${YELLOW}ssh ${SERVER} 'cd ${DEPLOY_PATH} && docker compose logs -f ${SERVICE_NAME}'${NC}"
    echo -e "  ${YELLOW}Or run: ./scripts/deploy-prod.sh --logs${NC}"
    echo ""
fi

echo -e "${GREEN}Deployment successful!${NC} 🚀"
