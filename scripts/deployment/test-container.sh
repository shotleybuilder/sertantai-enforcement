#!/bin/bash
#
# test-container.sh - Test EHS Enforcement Docker container locally
#
# This script tests the production Docker build locally before pushing to GHCR.
# It uses docker-compose.dev.yml to create a local test environment that mimics
# production configuration.
#
# Usage:
#   ./scripts/test-container.sh
#
# Prerequisites:
#   - Docker image built: ./scripts/build.sh
#   - docker-compose.dev.yml exists (will be created if missing)
#
# What it does:
#   - Starts a local PostgreSQL container
#   - Runs the built Docker image
#   - Tests database connectivity
#   - Verifies health endpoint
#   - Shows logs for debugging
#
# Press Ctrl+C to stop the test environment
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.dev.yml"
IMAGE_NAME="ghcr.io/shotleybuilder/ehs-enforcement:latest"

# Navigate to project root (two levels up from scripts/deployment/)
cd "$(dirname "$0")/../.."

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  EHS Enforcement - Local Container Test${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if Docker image exists
if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${IMAGE_NAME}$"; then
    echo -e "${RED}✗ Docker image not found: ${IMAGE_NAME}${NC}"
    echo -e "${YELLOW}  Build it first: ./scripts/build.sh${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker image found${NC}"
echo ""

# Check if docker-compose.dev.yml exists
if [ ! -f "${COMPOSE_FILE}" ]; then
    echo -e "${YELLOW}⚠ docker-compose.dev.yml not found${NC}"
    echo -e "${YELLOW}  This file should exist for container testing${NC}"
    echo -e "${YELLOW}  See docs-dev/dev/deployment/DEPLOYMENT_WITH-SCRIPTS.md${NC}"
    echo ""

    read -p "Would you like to continue with a minimal test? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Test cancelled${NC}"
        exit 0
    fi

    # Run minimal test without docker-compose
    echo ""
    echo -e "${BLUE}Running minimal container test...${NC}"
    echo -e "${YELLOW}(Note: Database connectivity will not be tested)${NC}"
    echo ""

    # Run container with minimal config
    docker run --rm -it \
        -p 4002:4002 \
        -e PHX_HOST=localhost \
        -e SECRET_KEY_BASE=test_secret_key_base_at_least_64_chars_long_for_testing_purposes \
        -e PHX_SERVER=true \
        "${IMAGE_NAME}"

    exit 0
fi

echo -e "${GREEN}✓ Found ${COMPOSE_FILE}${NC}"
echo ""

# Clean up any previous test environment
echo -e "${BLUE}Cleaning up previous test environment...${NC}"
docker compose -f "${COMPOSE_FILE}" down -v > /dev/null 2>&1 || true
echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# Start the test environment
echo -e "${BLUE}Starting test environment...${NC}"
echo -e "${YELLOW}(This will start PostgreSQL and the application)${NC}"
echo ""

# Start services
docker compose -f "${COMPOSE_FILE}" up -d postgres

# Wait for PostgreSQL
echo -e "${BLUE}Waiting for PostgreSQL to be ready...${NC}"
for i in {1..30}; do
    if docker compose -f "${COMPOSE_FILE}" exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}✗ PostgreSQL failed to start within 30 seconds${NC}"
        docker compose -f "${COMPOSE_FILE}" logs postgres
        docker compose -f "${COMPOSE_FILE}" down -v
        exit 1
    fi
    sleep 1
done
echo ""

# Start the application
echo -e "${BLUE}Starting application container...${NC}"
docker compose -f "${COMPOSE_FILE}" up -d app

# Wait for application to start
echo -e "${BLUE}Waiting for application to start...${NC}"
sleep 5

# Check if container is running
if ! docker compose -f "${COMPOSE_FILE}" ps app | grep -q "Up"; then
    echo -e "${RED}✗ Application container failed to start${NC}"
    echo ""
    echo -e "${BLUE}Container logs:${NC}"
    docker compose -f "${COMPOSE_FILE}" logs app
    docker compose -f "${COMPOSE_FILE}" down -v
    exit 1
fi
echo -e "${GREEN}✓ Application container is running${NC}"
echo ""

# Check health endpoint
echo -e "${BLUE}Testing health endpoint...${NC}"
sleep 3  # Give it a moment more

HEALTH_CHECK=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:4002/health 2>/dev/null || echo "000")

if [ "$HEALTH_CHECK" = "200" ]; then
    echo -e "${GREEN}✓ Health check passed (HTTP 200)${NC}"

    # Get health details
    echo ""
    echo -e "${BLUE}Health endpoint response:${NC}"
    curl -s http://localhost:4002/health | jq . 2>/dev/null || curl -s http://localhost:4002/health
else
    echo -e "${YELLOW}⚠ Health check returned HTTP ${HEALTH_CHECK}${NC}"
    echo -e "${YELLOW}  Check logs below for details${NC}"
fi
echo ""

# Show logs
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Container Logs (last 20 lines):${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
docker compose -f "${COMPOSE_FILE}" logs --tail=20 app
echo ""

# Summary
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Container test environment is running!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Application:${NC} http://localhost:4002"
echo -e "${YELLOW}Health:${NC} http://localhost:4002/health"
echo -e "${YELLOW}Database:${NC} localhost:5434 (postgres/postgres)"
echo ""
echo -e "${BLUE}Commands:${NC}"
echo -e "  View logs:        ${YELLOW}docker compose -f ${COMPOSE_FILE} logs -f app${NC}"
echo -e "  Check status:     ${YELLOW}docker compose -f ${COMPOSE_FILE} ps${NC}"
echo -e "  Run migrations:   ${YELLOW}docker compose -f ${COMPOSE_FILE} exec app /app/bin/ehs_enforcement eval 'EhsEnforcement.Release.migrate'${NC}"
echo -e "  Stop environment: ${YELLOW}docker compose -f ${COMPOSE_FILE} down${NC}"
echo -e "  Clean up:         ${YELLOW}docker compose -f ${COMPOSE_FILE} down -v${NC}"
echo ""
echo -e "${BLUE}Press Ctrl+C to follow logs, or close this terminal to continue...${NC}"
echo ""

# Offer to follow logs
read -p "Follow logs? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Following logs (Ctrl+C to exit)...${NC}"
    echo ""
    docker compose -f "${COMPOSE_FILE}" logs -f app
fi

echo ""
echo -e "${GREEN}Test complete!${NC}"
echo ""
echo -e "${BLUE}To clean up:${NC} ${YELLOW}docker compose -f ${COMPOSE_FILE} down -v${NC}"
echo ""
