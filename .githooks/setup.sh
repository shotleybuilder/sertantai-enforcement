#!/bin/bash
# Setup script to install git hooks

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Installing git hooks...${NC}"

# Get the root directory of the git repository
GIT_DIR=$(git rev-parse --git-dir)

if [ $? -ne 0 ]; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Configure git to use our hooks directory
git config core.hooksPath .githooks

echo -e "${GREEN}✓ Git hooks installed successfully!${NC}"
echo -e "${BLUE}Hooks are now active:${NC}"
echo "  - pre-commit: Fast checks (formatting, compilation, credo)"
echo "  - pre-push: Thorough checks (dialyzer, sobelow, tests)"
echo ""
echo "To bypass hooks:"
echo "  git commit --no-verify"
echo "  git push --no-verify"
