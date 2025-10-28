#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}✓${NC} $*"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }
log_step() { echo -e "${BLUE}▶${NC} $*"; }
log_header() { echo -e "${CYAN}$*${NC}"; }

echo ""
log_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_header "  Git Repository Template - Bootstrap"
log_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Not in a git repository. Please run 'git init' first."
    exit 1
fi

# Run the install script
log_step "Running installation..."
echo ""

if [[ -f scripts/install.sh ]]; then
    ./scripts/install.sh
else
    log_error "install.sh not found. Are you in the repository root?"
    exit 1
fi

echo ""
log_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_header "  Post-Installation Setup"
log_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test commit validation
log_step "Testing commit message validation..."

# Create a test commit to verify hooks work
if git diff --quiet && git diff --cached --quiet; then
    # Repo is clean, create an empty commit for testing
    if git commit --allow-empty -m "test: verify commit validation" --no-verify; then
        log_warn "Created test commit without validation (used --no-verify)"
        log_info "Now testing with validation enabled..."

        # Try an invalid commit
        if git commit --allow-empty -m "invalid commit message" 2>&1 | grep -q "Invalid commit message"; then
            log_info "Commit validation is working correctly!"
        else
            log_error "Commit validation may not be working"
        fi
    fi
else
    log_info "Repository has changes, skipping test commit"
fi

echo ""

# Display current version
if [[ -f VERSION ]]; then
    CURRENT_VERSION=$(cat VERSION)
    log_info "Current version: $CURRENT_VERSION"
fi

echo ""
log_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_header "  Bootstrap Complete!"
log_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Your repository is now configured with:"
echo ""
log_info "Conventional commit enforcement"
log_info "Semantic versioning (via VERSION file)"
log_info "Automated changelog generation"
log_info "Release automation (task commands)"
log_info "GitHub Actions (release-please)"
echo ""

echo "Available commands:"
echo ""
echo "  ${CYAN}task --list${NC}            List all available tasks"
echo "  ${CYAN}task release:patch${NC}     Create a patch release (0.0.X)"
echo "  ${CYAN}task release:minor${NC}     Create a minor release (0.X.0)"
echo "  ${CYAN}task release:major${NC}     Create a major release (X.0.0)"
echo ""

echo "Commit message format:"
echo ""
echo "  ${CYAN}type(scope): description${NC}"
echo ""
echo "  Types: feat, fix, docs, style, refactor, perf, test, chore, build, ci, revert"
echo ""

echo "Examples:"
echo ""
echo "  ${GREEN}git commit -m \"feat: add user authentication\"${NC}"
echo "  ${GREEN}git commit -m \"fix: resolve memory leak\"${NC}"
echo "  ${GREEN}git commit -m \"docs: update README\"${NC}"
echo ""

echo "Quick start:"
echo ""
echo "  1. Make changes to your code"
echo "  2. Stage and commit with conventional format:"
echo "     ${CYAN}git add .${NC}"
echo "     ${CYAN}git commit -m \"feat: your feature description\"${NC}"
echo ""
echo "  3. Create a release:"
echo "     ${CYAN}task release:patch${NC}"
echo ""
echo "  4. Push to GitHub:"
echo "     ${CYAN}git push origin main --tags${NC}"
echo ""

echo "For more information:"
echo "  📖 README.md - Full documentation"
echo "  📖 CLAUDE.md - Technical architecture guide"
echo "  📖 docs/RELEASE_BUILD_IMPLEMENTATION_PLAN.md - Implementation details"
echo ""
