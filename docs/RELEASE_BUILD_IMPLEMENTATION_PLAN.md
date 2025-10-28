# Release & Build System Implementation Plan

## Goal
Build a fully functional release and build system for `@git-repo-template` itself as the MVP. Once working, we'll replicate it to other repos.

---

## Tooling Stack (Language-Agnostic)
- **Release Automation**: `release-please` (GitHub Actions, supports Python/TypeScript/Go)
- **Git Hooks**: `lefthook` (Go-based, no Node.js required)
- **Docker**: Multi-arch builds via buildx (amd64 + arm64)
- **Registries**: Docker Hub + GitHub Container Registry (GHCR)

---

## Phase 1: Enhance `@git-repo-template` with Release Tooling

### 1.1 Directory Structure (Final State)
```
workspace/@git-repo-template/
├── .catalyst/
│   ├── repo.yaml                   # MOVED from catalyst_repo.yaml
│   └── tooling/                    # NEW: Shared scripts/configs
│       ├── scripts/
│       │   ├── build-release.sh    # Main release script
│       │   ├── docker-build.sh     # Docker multi-arch helper
│       │   └── validate-commit.sh  # Commit validation
│       ├── configs/
│       │   ├── lefthook.yml        # Git hooks config
│       │   ├── release-please-config.json
│       │   └── .release-please-manifest.json
│       ├── taskfiles/
│       │   ├── Release.taskfile.yml
│       │   └── Docker.taskfile.yml
│       └── templates/
│           ├── Dockerfile.production.python
│           ├── Dockerfile.production.go
│           └── CHANGELOG.md.template
├── .github/
│   └── workflows/
│       ├── release-please.yml      # NEW: Auto release PRs
│       └── docker-publish.yml      # NEW: Multi-arch build on release
├── docs/
│   ├── RELEASE_PROCESS.md          # NEW: Release documentation
│   └── SUBMODULE_USAGE.md          # NEW: How to use as submodule
├── Taskfile.yml                    # UPDATED: Include release tasks
├── VERSION                         # NEW: Current version (0.1.0)
├── CHANGELOG.md                    # NEW: Auto-generated changelog
├── lefthook.yml                    # NEW: Git hooks for commit validation
└── README.md                       # UPDATED: Document new features
```

---

## Phase 2: Implementation Steps for `@git-repo-template`

### Step 1: Move `catalyst_repo.yaml` → `.catalyst/repo.yaml`
```bash
cd workspace/@git-repo-template
mkdir -p .catalyst
git mv catalyst_repo.yaml .catalyst/repo.yaml
```

### Step 2: Create `.catalyst/tooling/` Structure
```bash
mkdir -p .catalyst/tooling/{scripts,configs,taskfiles,templates}
```

### Step 3: Create `build-release.sh`
**Location**: `.catalyst/tooling/scripts/build-release.sh`

**Features** (based on @swarm-graph + enhancements):
- Semantic version bumping (patch/minor/major)
- Read version from `VERSION` file
- Git tag creation with annotated metadata
- Docker multi-arch build support (optional)
- Rollback on failure
- Environment variable configuration:
  - `REGISTRY_URL` - Docker registry
  - `IMAGE_NAME` - Docker image name
  - `PUSH_GIT_TAGS` - Push tags to remote (default: true)
  - `BUILDX_ENABLED` - Enable multi-arch (default: false)
  - `BUILD_ARCHS` - Platforms (default: linux/amd64,linux/arm64)

**Basic Script Structure**:
```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION_FILE="VERSION"
BUMP_TYPE="${1:-patch}"  # patch, minor, major

increment_version() {
  # Read current version, bump based on type, write back
}

create_git_tag() {
  # Create annotated tag with metadata
}

build_docker_image() {
  # Optional: buildx multi-arch build
}

rollback() {
  # Revert changes on failure
}

main() {
  # Check clean repo
  # Increment version
  # Commit VERSION file
  # Build Docker (if enabled)
  # Create git tag
  # Push tag
}

main "$@"
```

### Step 4: Create Lefthook Config
**Location**: `.catalyst/tooling/configs/lefthook.yml`

```yaml
pre-commit:
  commands:
    validate-commit-message:
      run: .catalyst/tooling/scripts/validate-commit.sh {1}

commit-msg:
  commands:
    conventional-commit:
      run: |
        if ! grep -qE '^(feat|fix|docs|style|refactor|perf|test|chore)(\(.+\))?: .+' {1}; then
          echo "❌ Commit message must follow Conventional Commits format:"
          echo "   type(scope?): description"
          echo ""
          echo "Types: feat, fix, docs, style, refactor, perf, test, chore"
          exit 1
        fi
```

**Root `lefthook.yml`** (sources from tooling):
```yaml
# Use shared config from .catalyst/tooling
remote:
  git_url: .catalyst/tooling
  ref: HEAD
  config: configs/lefthook.yml
```

### Step 5: Create Release-Please Configs
**Location**: `.catalyst/tooling/configs/release-please-config.json`

```json
{
  "release-type": "simple",
  "include-v-in-tag": true,
  "changelog-sections": [
    {"type": "feat", "section": "Features"},
    {"type": "fix", "section": "Bug Fixes"},
    {"type": "perf", "section": "Performance Improvements"},
    {"type": "docs", "section": "Documentation"},
    {"type": "refactor", "section": "Code Refactoring"},
    {"type": "chore", "section": "Miscellaneous"}
  ],
  "extra-files": ["VERSION"]
}
```

**Location**: `.catalyst/tooling/configs/.release-please-manifest.json`

```json
{
  ".": "0.1.0"
}
```

### Step 6: Create Shared Taskfiles
**Location**: `.catalyst/tooling/taskfiles/Release.taskfile.yml`

```yaml
version: '3'

tasks:
  release:
    desc: "Create patch release (alias for release:patch)"
    cmds:
      - task: release:patch

  release:patch:
    desc: "Bump patch version (0.0.X)"
    cmds:
      - .catalyst/tooling/scripts/build-release.sh patch

  release:minor:
    desc: "Bump minor version (0.X.0)"
    cmds:
      - .catalyst/tooling/scripts/build-release.sh minor

  release:major:
    desc: "Bump major version (X.0.0)"
    cmds:
      - .catalyst/tooling/scripts/build-release.sh major
```

**Location**: `.catalyst/tooling/taskfiles/Docker.taskfile.yml`

```yaml
version: '3'

vars:
  REGISTRY_URL: '{{.REGISTRY_URL | default "docker.io"}}'
  IMAGE_NAME: '{{.IMAGE_NAME | default "git-repo-template"}}'

tasks:
  docker:build:
    desc: "Build Docker image (single-arch)"
    cmds:
      - docker build -t {{.REGISTRY_URL}}/{{.IMAGE_NAME}}:latest -f Dockerfile.production .

  docker:build:multiarch:
    desc: "Build multi-arch Docker image (amd64 + arm64)"
    cmds:
      - |
        docker buildx build \
          --platform linux/amd64,linux/arm64 \
          --tag {{.REGISTRY_URL}}/{{.IMAGE_NAME}}:latest \
          --push \
          -f Dockerfile.production .
```

### Step 7: Update Root `Taskfile.yml`
```yaml
version: '3'

includes:
  release: .catalyst/tooling/taskfiles/Release.taskfile.yml
  docker: .catalyst/tooling/taskfiles/Docker.taskfile.yml

tasks:
  # Existing tasks remain...
```

### Step 8: Create GitHub Actions
**Location**: `.github/workflows/release-please.yml`

```yaml
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
          package-name: git-repo-template
```

**Location**: `.github/workflows/docker-publish.yml` (Optional - only if Dockerfile exists)

```yaml
name: Docker Multi-Arch Build

on:
  release:
    types: [published]

env:
  REGISTRY_DOCKERHUB: docker.io
  REGISTRY_GHCR: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          token: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Login to GitHub Container Registry
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: |
            ${{ secrets.DOCKERHUB_USERNAME }}/${{ env.IMAGE_NAME }}
            ghcr.io/${{ env.IMAGE_NAME }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}
            type=raw,value=latest

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          file: Dockerfile.production
          platforms: linux/amd64,linux/arm64
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

### Step 9: Create Initial Files
**`VERSION`**:
```
0.1.0
```

**`CHANGELOG.md`**:
```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
```

### Step 10: Create Documentation
**`docs/RELEASE_PROCESS.md`**:
Document the full release workflow, including:
- Conventional commit format
- How to create releases (manual vs automated)
- Version bumping strategy
- Docker build process

**`docs/SUBMODULE_USAGE.md`**:
Document how other repos should use this as a submodule:
- Adding submodule to `.catalyst/`
- Creating repo-specific branches
- Updating submodule
- Syncing changes from main

### Step 11: Update README.md
Add sections:
- Release Process
- Using as Submodule
- Conventional Commits Guide

---

## Phase 3: Testing the MVP

### Test 1: Manual Release
```bash
cd workspace/@git-repo-template

# Install lefthook
lefthook install

# Test commit validation
git commit -m "invalid message"  # Should fail
git commit -m "feat: add release tooling"  # Should succeed

# Test release
task release:patch  # Should bump 0.1.0 → 0.1.1
```

### Test 2: GitHub Actions (after pushing)
```bash
# Push to main
git push origin main

# Watch for release-please to create PR
# Merge PR
# Watch for docker-publish to build images
```

---

## Git Submodule Strategy for Other Repos

### Architecture
Once `@git-repo-template` MVP is complete, other repos will use it as a submodule:

```
workspace/@kasa-exporter/
├── .catalyst/          <- git submodule → @git-repo-template:kasa-exporter
│   ├── repo.yaml      # Repo metadata
│   └── tooling/       # All shared scripts/configs
├── Taskfile.yml       # includes: .catalyst/tooling/taskfiles/*.yml
└── scripts/
    └── release.sh     # Sources .catalyst/tooling/scripts/build-release.sh
```

### Per-Repo Branches in `@git-repo-template`
```
workspace/@git-repo-template/
├── branches/
│   ├── main                    # Base template for all repos
│   ├── kasa-exporter          # Kasa-specific tooling
│   ├── swarm-graph            # Swarm-specific tooling
│   └── catalyst-ui            # UI-specific tooling
```

### Workflow for Adding to New Repo
```bash
cd workspace/@new-repo
git submodule add -b new-repo-branch \
  ../workspace/@git-repo-template \
  .catalyst
```

---

## Checklist

### Setup
- [ ] Move `catalyst_repo.yaml` → `.catalyst/repo.yaml`
- [ ] Create `.catalyst/tooling/` directory structure
- [ ] Create `build-release.sh` script
- [ ] Create `validate-commit.sh` script
- [ ] Create `docker-build.sh` helper (optional)
- [ ] Create lefthook configs
- [ ] Create release-please configs
- [ ] Create shared Taskfiles
- [ ] Update root Taskfile.yml
- [ ] Install lefthook: `lefthook install`

### GitHub Actions
- [ ] Create `.github/workflows/release-please.yml`
- [ ] Create `.github/workflows/docker-publish.yml` (optional)
- [ ] Configure GitHub secrets if using Docker:
  - `DOCKERHUB_USERNAME`
  - `DOCKERHUB_TOKEN`

### Documentation
- [ ] Create `docs/RELEASE_PROCESS.md`
- [ ] Create `docs/SUBMODULE_USAGE.md`
- [ ] Update `README.md`

### Initial Files
- [ ] Create `VERSION` file (0.1.0)
- [ ] Create `CHANGELOG.md` with header
- [ ] Create root `lefthook.yml`

### Testing
- [ ] Test lefthook commit validation
- [ ] Test `task release:patch` manually
- [ ] Push to main and verify release-please creates PR
- [ ] Merge release PR and verify release creation
- [ ] Verify Docker build (if applicable)

---

## Success Criteria

✅ Conventional commits are enforced via lefthook
✅ `task release:patch/minor/major` creates version bump + git tag
✅ Pushing to main triggers release-please PR creation
✅ Merging release PR creates GitHub release
✅ CHANGELOG.md is auto-generated
✅ Multi-arch Docker images published (if enabled)
✅ Documentation is complete for replication to other repos

---

## Next Steps (After MVP)

1. Create per-repo branches in `@git-repo-template` (kasa-exporter, swarm-graph, etc.)
2. Add `@git-repo-template` as submodule to other repos
3. Update `@TheBranchDriftCatalyst` to use `.catalyst/repo.yaml`
4. Replicate release process to `@kasa-exporter`
5. Replicate release process to `@swarm-graph`

---

## Environment Variables

### GitHub Secrets Required
```bash
DOCKERHUB_USERNAME=<username>
DOCKERHUB_TOKEN=<personal_access_token>
GITHUB_TOKEN=<auto_provided_by_actions>
```

### Local Development (optional)
```bash
REGISTRY_URL=docker.io/username  # or ghcr.io/username
IMAGE_NAME=repo-name
BUILDX_ENABLED=true
BUILD_ARCHS=linux/amd64,linux/arm64
```

---

## Benefits

✅ **No Symlinks** - Real files via git submodules
✅ **Version Controlled** - Submodule commits are tracked
✅ **Per-Repo Customization** - Branch-based overrides
✅ **Easy Syncing** - `git submodule update` or merge from main
✅ **Rollback Safe** - Pin to specific submodule commits
✅ **CI/CD Friendly** - Well-supported in GitHub Actions
✅ **Language Agnostic** - Works for Python/TypeScript/Go
✅ **Standardized** - Same workflow across all repos
✅ **Automated Changelog** - No manual CHANGELOG.md updates
✅ **Multi-Arch Docker** - amd64 + arm64 support
✅ **Multi-Registry** - Docker Hub + GHCR redundancy
