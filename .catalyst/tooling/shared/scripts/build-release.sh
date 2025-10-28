#!/usr/bin/env bash
set -euo pipefail

# Configuration
VERSION_FILE="${VERSION_FILE:-VERSION}"
BUMP_TYPE="${1:-patch}"
REGISTRY_URL="${REGISTRY_URL:-}"
IMAGE_NAME="${IMAGE_NAME:-}"
PUSH_GIT_TAGS="${PUSH_GIT_TAGS:-true}"
BUILDX_ENABLED="${BUILDX_ENABLED:-false}"
BUILD_ARCHS="${BUILD_ARCHS:-linux/amd64,linux/arm64}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}✓${NC} $*"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }

# Check if git repo is clean
check_clean_repo() {
    if [[ -n $(git status --porcelain) ]]; then
        log_error "Git repository has uncommitted changes. Please commit or stash them first."
        exit 1
    fi
    log_info "Git repository is clean"
}

# Read current version
read_version() {
    if [[ ! -f "$VERSION_FILE" ]]; then
        echo "0.0.0"
    else
        cat "$VERSION_FILE"
    fi
}

# Increment version based on type
increment_version() {
    local version=$1
    local bump_type=$2

    IFS='.' read -r major minor patch <<< "$version"

    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            log_error "Invalid bump type: $bump_type (use: major, minor, patch)"
            exit 1
            ;;
    esac

    echo "$major.$minor.$patch"
}

# Create git tag
create_git_tag() {
    local version=$1
    local tag="v$version"
    local commit_hash=$(git rev-parse HEAD)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local tag_message="Release $tag

Build Information:
- Commit: $commit_hash
- Timestamp: $timestamp"

    if [[ -n "$IMAGE_NAME" ]]; then
        tag_message+="
- Docker Image: $IMAGE_NAME:$version"
    fi

    git tag -a "$tag" -m "$tag_message"
    log_info "Created git tag: $tag"
}

# Build Docker image (optional)
build_docker() {
    local version=$1

    if [[ -z "$REGISTRY_URL" || -z "$IMAGE_NAME" ]]; then
        log_warn "Skipping Docker build (REGISTRY_URL or IMAGE_NAME not set)"
        return 0
    fi

    local full_image="$REGISTRY_URL/$IMAGE_NAME"

    if [[ "$BUILDX_ENABLED" == "true" ]]; then
        log_info "Building multi-arch Docker image: $full_image:$version"
        docker buildx build \
            --platform "$BUILD_ARCHS" \
            --tag "$full_image:$version" \
            --tag "$full_image:latest" \
            --push \
            -f Dockerfile.production .
    else
        log_info "Building Docker image: $full_image:$version"
        docker build \
            -t "$full_image:$version" \
            -t "$full_image:latest" \
            -f Dockerfile.production .
    fi
}

# Rollback on failure
rollback() {
    log_error "Build failed, rolling back..."
    git reset --hard HEAD~1
    exit 1
}

# Main release process
main() {
    log_info "Starting release process (bump: $BUMP_TYPE)"

    # Check prerequisites
    check_clean_repo

    # Read and increment version
    local current_version=$(read_version)
    local new_version=$(increment_version "$current_version" "$BUMP_TYPE")

    log_info "Version: $current_version → $new_version"

    # Update VERSION file
    echo "$new_version" > "$VERSION_FILE"
    git add "$VERSION_FILE"
    git commit -m "chore: bump version to $new_version"

    # Build Docker (optional)
    if ! build_docker "$new_version"; then
        rollback
    fi

    # Create git tag
    create_git_tag "$new_version"

    # Push to remote
    if [[ "$PUSH_GIT_TAGS" == "true" ]]; then
        log_info "Pushing to remote..."
        git push origin main
        git push origin "v$new_version"
    else
        log_warn "Skipping git push (PUSH_GIT_TAGS=false)"
    fi

    log_info "Release $new_version completed successfully! 🎉"
}

trap rollback ERR
main "$@"
