#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}✓${NC} $*"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }
log_step() { echo -e "${BLUE}▶${NC} $*"; }

# Determine if we're running as submodule or standalone
if [[ -d .catalyst ]]; then
    # Running from parent repo with .catalyst as submodule
    CATALYST_DIR=".catalyst"
    IS_SUBMODULE=true
else
    # Running from within the template repo itself
    CATALYST_DIR="."
    IS_SUBMODULE=false
fi

TOOLING_DIR="$CATALYST_DIR/tooling/shared"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Build Tooling Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check prerequisites
log_step "Checking prerequisites..."

check_command() {
    if command -v "$1" &> /dev/null; then
        log_info "$1 is installed"
        return 0
    else
        log_error "$1 is not installed"
        return 1
    fi
}

MISSING_DEPS=0

if ! check_command git; then
    echo "  Install: https://git-scm.com/downloads"
    MISSING_DEPS=1
fi

if ! check_command task; then
    echo "  Install: https://taskfile.dev/installation/"
    MISSING_DEPS=1
fi

if ! check_command lefthook; then
    echo "  Install: brew install lefthook (macOS) or https://github.com/evilmartians/lefthook#install"
    MISSING_DEPS=1
fi

if [[ $MISSING_DEPS -eq 1 ]]; then
    log_error "Missing required dependencies. Please install them and try again."
    exit 1
fi

echo ""
log_step "Creating configuration files..."

# 1. Create Taskfile.yml if it doesn't exist
if [[ ! -f Taskfile.yml ]]; then
    log_info "Creating Taskfile.yml"
    cat > Taskfile.yml <<'EOF'
version: '3'

includes:
  release: .catalyst/tooling/shared/taskfiles/Release.taskfile.yml

tasks:
  default:
    desc: "Show available tasks"
    cmds:
      - task --list
EOF
else
    log_warn "Taskfile.yml already exists, skipping"

    # Check if it includes release tasks
    if ! grep -q "release.*\.catalyst/tooling" Taskfile.yml; then
        log_warn "Taskfile.yml does not include release tasks. Add this to your includes:"
        echo ""
        echo "  includes:"
        echo "    release: .catalyst/tooling/shared/taskfiles/Release.taskfile.yml"
        echo ""
    fi
fi

# 2. Create lefthook.yml if it doesn't exist
if [[ ! -f lefthook.yml ]]; then
    log_info "Creating lefthook.yml"
    cat > lefthook.yml <<'EOF'
# Git hooks managed by lefthook
# Run: lefthook install

commit-msg:
  commands:
    conventional-commit:
      run: .catalyst/tooling/shared/scripts/validate-commit.sh {1}
EOF
else
    log_warn "lefthook.yml already exists, skipping"
fi

# 3. Create VERSION file if it doesn't exist
if [[ ! -f VERSION ]]; then
    log_info "Creating VERSION file (0.1.0)"
    echo "0.1.0" > VERSION
else
    log_warn "VERSION file already exists ($(cat VERSION))"
fi

# 4. Create CHANGELOG.md if it doesn't exist
if [[ ! -f CHANGELOG.md ]]; then
    log_info "Creating CHANGELOG.md"
    cat > CHANGELOG.md <<'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
EOF
else
    log_warn "CHANGELOG.md already exists, skipping"
fi

# 5. Create .github/workflows directory and copy release-please workflow
if [[ ! -f .github/workflows/release-please.yml ]]; then
    log_info "Creating .github/workflows/release-please.yml"
    mkdir -p .github/workflows

    if [[ -f "$TOOLING_DIR/../../../.github/workflows/release-please.yml" && "$IS_SUBMODULE" == false ]]; then
        # Running from template itself
        cp .github/workflows/release-please.yml .github/workflows/release-please.yml.bak 2>/dev/null || true
    fi

    cat > .github/workflows/release-please.yml <<'EOF'
name: Release Please

on:
  push:
    branches:
      - main

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: googleapis/release-please-action@v4
        with:
          release-type: simple
          package-name: ${{ github.event.repository.name }}
          config-file: .catalyst/tooling/shared/configs/release-please-config.json
          manifest-file: .catalyst/tooling/shared/configs/.release-please-manifest.json
EOF
else
    log_warn ".github/workflows/release-please.yml already exists, skipping"
fi

# 6. Install lefthook hooks
echo ""
log_step "Installing git hooks..."
if lefthook install; then
    log_info "Git hooks installed successfully"
else
    log_error "Failed to install git hooks"
    exit 1
fi

# 7. Make scripts executable
log_step "Setting script permissions..."
chmod +x "$TOOLING_DIR/scripts/"*.sh
log_info "Scripts are now executable"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installation Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_info "Build tooling installed successfully"
echo ""
echo "Next steps:"
echo ""
echo "  1. Commit the new files:"
echo "     git add Taskfile.yml lefthook.yml VERSION CHANGELOG.md .github/"
if [[ "$IS_SUBMODULE" == true ]]; then
    echo "     git add .catalyst"
fi
echo "     git commit -m \"chore: add build tooling and release automation\""
echo ""
echo "  2. Test commit validation:"
echo "     git commit --allow-empty -m \"test: validation check\""
echo ""
echo "  3. Create your first release:"
echo "     task release:patch"
echo ""
echo "  4. View available tasks:"
echo "     task --list"
echo ""
echo "For more information, see:"
if [[ "$IS_SUBMODULE" == true ]]; then
    echo "  .catalyst/README.md"
else
    echo "  README.md"
fi
echo ""
