#!/usr/bin/env bash
set -euo pipefail

# Pre-push validation script
# Detects project type and runs appropriate checks before push.
# Repos can override by defining their own pre-push commands in lefthook.yml.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}✓${NC} $*"; }
log_warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }

FAILED=0

# Node.js / TypeScript projects
if [[ -f "package.json" ]]; then
    # Type checking
    if grep -q '"type-check"' package.json 2>/dev/null; then
        log_info "Running type-check..."
        if ! npm run type-check --silent 2>&1; then
            log_error "Type checking failed"
            FAILED=1
        fi
    fi

    # Build validation
    if grep -q '"build"' package.json 2>/dev/null; then
        log_info "Running build validation..."
        if ! npm run build --silent 2>&1; then
            log_error "Build failed"
            FAILED=1
        fi
    fi
fi

# Python projects
if [[ -f "pyproject.toml" ]]; then
    if command -v mypy &>/dev/null && [[ -f "mypy.ini" || -f "setup.cfg" || -f "pyproject.toml" ]]; then
        log_info "Running mypy type-check..."
        if ! mypy . 2>&1; then
            log_error "Type checking failed"
            FAILED=1
        fi
    fi
fi

# Go projects
if [[ -f "go.mod" ]]; then
    log_info "Running go vet..."
    if ! go vet ./... 2>&1; then
        log_error "go vet failed"
        FAILED=1
    fi

    log_info "Running go build..."
    if ! go build ./... 2>&1; then
        log_error "go build failed"
        FAILED=1
    fi
fi

if [[ $FAILED -eq 1 ]]; then
    log_error "Pre-push validation failed. Use 'git push --no-verify' to bypass."
    exit 1
fi

log_info "Pre-push validation passed"
exit 0
