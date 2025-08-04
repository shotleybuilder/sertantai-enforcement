#!/bin/bash
# Install Git hooks for EHS Enforcement project

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[Git Hooks]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[Git Hooks]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[Git Hooks]${NC} $1"
}

print_error() {
    echo -e "${RED}[Git Hooks]${NC} $1"
}

# Check if we're in the project root
if [ ! -f "mix.exs" ] || [ ! -d ".githooks" ]; then
    print_error "Please run this script from the EHS Enforcement project root"
    exit 1
fi

print_status "Installing Git hooks for EHS Enforcement project..."

# Get the Git hooks directory
GIT_HOOKS_DIR=".git/hooks"

if [ ! -d "$GIT_HOOKS_DIR" ]; then
    print_error "Git hooks directory not found. Are you in a Git repository?"
    exit 1
fi

# List of hooks to install
HOOKS_TO_INSTALL=(
    "post-commit"
)

INSTALLED_COUNT=0

for hook in "${HOOKS_TO_INSTALL[@]}"; do
    SOURCE_HOOK=".githooks/$hook"
    TARGET_HOOK="$GIT_HOOKS_DIR/$hook"
    
    if [ -f "$SOURCE_HOOK" ]; then
        # Check if hook already exists
        if [ -f "$TARGET_HOOK" ]; then
            print_warning "Hook $hook already exists"
            read -p "$(echo -e "${YELLOW}[Git Hooks]${NC} Overwrite existing $hook hook? (y/N): ")" -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_status "Skipping $hook hook"
                continue
            fi
        fi
        
        # Copy and make executable
        cp "$SOURCE_HOOK" "$TARGET_HOOK"
        chmod +x "$TARGET_HOOK"
        
        print_success "Installed $hook hook"
        ((INSTALLED_COUNT++))
    else
        print_error "Source hook $SOURCE_HOOK not found"
    fi
done

if [ $INSTALLED_COUNT -gt 0 ]; then
    print_success "Successfully installed $INSTALLED_COUNT Git hook(s)"
    echo
    print_status "Hooks installed:"
    for hook in "${HOOKS_TO_INSTALL[@]}"; do
        if [ -f "$GIT_HOOKS_DIR/$hook" ]; then
            echo "  ✓ $hook - Regenerates ExDoc when lib/ files change"
        fi
    done
    echo
    print_status "What happens now:"
    echo "  • When you commit changes to lib/ files, ExDoc will regenerate automatically"
    echo "  • You'll be prompted to commit the updated documentation"
    echo "  • Other files won't trigger documentation regeneration"
    echo
    print_status "To test: Make a change to any file in lib/ and commit it"
else
    print_warning "No hooks were installed"
fi

# Check if ex_doc dependency is available
echo
print_status "Checking ExDoc dependency..."
if mix help docs > /dev/null 2>&1; then
    print_success "ExDoc is available and ready"
else
    print_warning "ExDoc not found - hooks will skip documentation generation"
    print_status "To install: run 'mix deps.get'"
fi