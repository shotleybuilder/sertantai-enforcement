#!/bin/bash
#
# push.sh - Push EHS Enforcement Docker image to GitHub Container Registry
#
# This script pushes the built Docker image to GHCR. You must be logged in
# to GHCR before running this script.
#
# Usage:
#   ./scripts/push.sh [tag]
#
#   If no tag is specified, defaults to 'latest'
#
# Prerequisites:
#   - Docker image built: ./scripts/build.sh
#   - Logged in to GHCR: echo $GITHUB_PAT | docker login ghcr.io -u USERNAME --password-stdin
#
# Next steps after successful push:
#   - Deploy to production: ./scripts/deploy-prod.sh
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Image configuration
IMAGE_NAME="ghcr.io/shotleybuilder/ehs-enforcement"
IMAGE_TAG="${1:-latest}"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  EHS Enforcement - Push to GHCR${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Image:${NC} ${FULL_IMAGE}"
echo ""

# Check if image exists locally
if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${FULL_IMAGE}$"; then
    echo -e "${RED}✗ Error: Image not found locally${NC}"
    echo -e "${YELLOW}  Build it first: ./scripts/build.sh${NC}"
    exit 1
fi

# Check Docker registry authentication
echo -e "${BLUE}Checking GHCR authentication...${NC}"
if ! docker info 2>/dev/null | grep -q "ghcr.io"; then
    echo -e "${YELLOW}⚠ Warning: May not be logged in to GHCR${NC}"
    echo -e "${YELLOW}  If push fails, login with:${NC}"
    echo -e "${YELLOW}  echo \$GITHUB_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin${NC}"
    echo ""

    # Ask for confirmation
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Push cancelled${NC}"
        exit 0
    fi
fi

# Push the image
echo ""
echo -e "${BLUE}Pushing to GitHub Container Registry...${NC}"
echo ""

docker push "${FULL_IMAGE}"

# Check push success
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ Push successful!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Image:${NC} ${FULL_IMAGE}"
    echo -e "${YELLOW}Registry:${NC} GitHub Container Registry (GHCR)"
    echo ""

    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  ${GREEN}→${NC} Deploy to production: ${YELLOW}./scripts/deployment/deploy-prod.sh${NC}"
    echo -e "  ${GREEN}→${NC} Or SSH manually:      ${YELLOW}ssh sertantai${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}✗ Push failed${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Common issues:${NC}"
    echo -e "  • Not logged in to GHCR"
    echo -e "  • Insufficient permissions"
    echo -e "  • Network connectivity issues"
    echo ""
    echo -e "${YELLOW}Login command:${NC}"
    echo -e "  ${BLUE}echo \$GITHUB_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin${NC}"
    echo ""
    exit 1
fi
