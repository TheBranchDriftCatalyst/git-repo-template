# git-repo-template

[![License](https://img.shields.io/github/license/TheBranchDriftCatalyst/git-repo-template)](LICENSE)
[![Release](https://img.shields.io/github/v/release/TheBranchDriftCatalyst/git-repo-template)](https://github.com/TheBranchDriftCatalyst/git-repo-template/releases)

**Common build tools and release automation for CI/CD across all your repositories.**

This repository provides standardized, language-agnostic tooling for:
- 🔄 **Automated Releases** - Semantic versioning with GitHub Actions
- 📝 **Conventional Commits** - Enforced commit message format via git hooks
- 📦 **Multi-arch Docker Builds** - amd64 + arm64 support (optional)
- 🚀 **CI/CD Ready** - Drop-in GitHub Actions workflows
- 🔧 **Multi-language Support** - Python, TypeScript, Go, and more

## Quick Start

### Option 1: Use as Template (New Repository)

```bash
# Clone this template
git clone https://github.com/TheBranchDriftCatalyst/git-repo-template my-new-repo
cd my-new-repo

# Run bootstrap script
./scripts/bootstrap.sh

# Make your first commit
git commit -m "feat: initial commit"

# Create your first release
task release:patch
```

### Option 2: Add to Existing Repository (As Submodule)

```bash
cd your-existing-repo

# Download and run the installer
curl -fsSL https://raw.githubusercontent.com/TheBranchDriftCatalyst/git-repo-template/main/scripts/install.sh | bash

# Or manually:
git submodule add https://github.com/TheBranchDriftCatalyst/git-repo-template .catalyst
.catalyst/scripts/install.sh
```

## Features

### ✅ Conventional Commits Enforcement

Git hooks automatically validate commit messages follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```bash
# ✅ Valid commits
git commit -m "feat: add user authentication"
git commit -m "fix: resolve memory leak in worker"
git commit -m "docs: update installation guide"

# ❌ Invalid commits (rejected by git hook)
git commit -m "added stuff"
git commit -m "fixing bugs"
```

**Supported types**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `build`, `ci`, `revert`

### 🔄 Automated Semantic Versioning

Manual releases with automatic version bumping:

```bash
# Patch release (0.1.0 → 0.1.1) - bug fixes
task release:patch

# Minor release (0.1.0 → 0.2.0) - new features
task release:minor

# Major release (0.1.0 → 1.0.0) - breaking changes
task release:major
```

### 📝 Automated Changelog Generation

Using [release-please](https://github.com/googleapis/release-please), changelogs are automatically generated from conventional commits:

1. Push commits to `main` branch
2. Release-please bot creates/updates a release PR
3. Merge the PR → automatic GitHub release with changelog
4. `CHANGELOG.md` is updated automatically

### 🐳 Multi-arch Docker Builds (Optional)

Build and publish Docker images for multiple architectures:

```bash
# Enable Docker builds
export REGISTRY_URL="docker.io/username"
export IMAGE_NAME="my-app"
export BUILDX_ENABLED="true"

# Release with Docker build
task release:patch
```

Supports:
- Docker Hub
- GitHub Container Registry (GHCR)
- Multiple architectures (amd64, arm64)

## Installation

### Prerequisites

- **Git** 2.x+
- **Task** (go-task) - [Install](https://taskfile.dev/installation/)
- **Lefthook** - [Install](https://github.com/evilmartians/lefthook#install)
- **Docker** (optional) - For Docker builds

### Bootstrap Script (Recommended)

For new repositories or this template:

```bash
# Clone and initialize
git clone https://github.com/TheBranchDriftCatalyst/git-repo-template my-repo
cd my-repo

# Run bootstrap (installs hooks, validates setup)
./scripts/bootstrap.sh
```

### Manual Installation

```bash
# 1. Install lefthook hooks
lefthook install

# 2. Verify installation
task --list

# 3. Test commit validation
git commit --allow-empty -m "test: validation check"
```

## Usage

### Daily Development

```bash
# Make changes to your code
git add .

# Commit with conventional format (enforced by git hook)
git commit -m "feat: add new API endpoint"

# Push to remote
git push origin main
```

### Creating Releases

#### Local Manual Releases

```bash
# Patch release (0.0.X) - bug fixes only
task release:patch

# Minor release (0.X.0) - new features, backward compatible
task release:minor

# Major release (X.0.0) - breaking changes
task release:major

# Short alias (defaults to patch)
task release
```

**What happens:**
1. `VERSION` file is updated
2. Git commit created with new version
3. Annotated git tag created (e.g., `v0.1.1`)
4. Tag pushed to remote (triggers GitHub Actions)
5. Optional: Docker image built and tagged

#### Automated Releases via GitHub

1. **Make conventional commits** and push to `main`:
   ```bash
   git commit -m "feat: add user profile page"
   git push origin main
   ```

2. **Release-please creates a PR** with:
   - Auto-generated CHANGELOG
   - Version bump based on commit types
   - Release notes

3. **Merge the release PR** → GitHub release created automatically

4. **Optional: Docker images published** (if workflow configured)

### Environment Variables

Configure release behavior with environment variables:

```bash
# Docker configuration
export REGISTRY_URL="docker.io/myusername"  # or ghcr.io/myorg
export IMAGE_NAME="my-app"
export BUILDX_ENABLED="true"                # Enable multi-arch builds
export BUILD_ARCHS="linux/amd64,linux/arm64"

# Git behavior
export PUSH_GIT_TAGS="true"                 # Auto-push tags to remote
export VERSION_FILE="VERSION"               # Version file location
```

## Project Structure

```
.catalyst/                                   # Build tooling (can be git submodule)
├── repo.yaml                               # Repository metadata
└── tooling/
    ├── shared/                             # Shared across all repos
    │   ├── configs/
    │   │   ├── lefthook.yml               # Git hooks config
    │   │   ├── release-please-config.json # Release automation
    │   │   └── .release-please-manifest.json
    │   ├── scripts/
    │   │   ├── build-release.sh           # Manual release script
    │   │   └── validate-commit.sh         # Commit validator
    │   └── taskfiles/
    │       └── Release.taskfile.yml       # Task definitions
    └── repos/                              # Repo-specific overrides
        ├── kasa-exporter/
        ├── swarm-graph/
        └── catalyst-ui/

.github/workflows/
└── release-please.yml                      # GitHub Actions for releases

scripts/
├── bootstrap.sh                            # Initial setup script
└── install.sh                              # Submodule installation script

Taskfile.yml                                # Task runner configuration
lefthook.yml                                # Git hooks configuration
VERSION                                     # Current version (0.1.0)
CHANGELOG.md                                # Auto-generated changelog
```

## Available Tasks

```bash
# List all available tasks
task --list

# Release tasks
task release              # Alias for release:patch
task release:patch        # Bump patch version (0.0.X)
task release:minor        # Bump minor version (0.X.0)
task release:major        # Bump major version (X.0.0)
```

## Using as Git Submodule

This repository is designed to be used as a git submodule in other projects, providing shared build tooling.

### Adding to Your Repository

```bash
cd your-repo

# Add as submodule
git submodule add https://github.com/TheBranchDriftCatalyst/git-repo-template .catalyst

# Run installer
.catalyst/scripts/install.sh

# Commit the integration
git add .catalyst Taskfile.yml lefthook.yml VERSION CHANGELOG.md .github/
git commit -m "chore: add build tooling via git submodule"
```

### Updating Submodule

```bash
# Update to latest version
git submodule update --remote .catalyst

# Or manually
cd .catalyst
git fetch origin
git checkout main
git pull
cd ..
git add .catalyst
git commit -m "chore: update build tooling"
```

### Integration Pattern

**In your `Taskfile.yml`:**
```yaml
version: '3'

includes:
  release: .catalyst/tooling/shared/taskfiles/Release.taskfile.yml

tasks:
  # Your custom tasks here
  build:
    desc: "Build your project"
    cmds:
      - echo "Building..."
```

**In your `lefthook.yml`:**
```yaml
commit-msg:
  commands:
    conventional-commit:
      run: .catalyst/tooling/shared/scripts/validate-commit.sh {1}
```

## GitHub Actions Setup

### Release-Please Workflow

Already included in `.github/workflows/release-please.yml`. No setup required!

**Permissions needed** (automatically granted in GitHub Actions):
- `contents: write` - Create releases and tags
- `pull-requests: write` - Create release PRs

### Docker Publishing (Optional)

To enable automated Docker builds on release:

1. **Add GitHub Secrets** (Settings → Secrets → Actions):
   - `DOCKERHUB_USERNAME` - Your Docker Hub username
   - `DOCKERHUB_TOKEN` - Docker Hub access token

2. **Create workflow** `.github/workflows/docker-publish.yml`:
   ```bash
   cp .catalyst/tooling/shared/templates/docker-publish.yml .github/workflows/
   ```

3. **Add Dockerfile.production** to your repo

## Conventional Commit Guide

### Format

```
type(scope?): description

[optional body]

[optional footer]
```

### Types

| Type | Description | Version Bump |
|------|-------------|--------------|
| `feat` | New feature | Minor |
| `fix` | Bug fix | Patch |
| `docs` | Documentation only | None |
| `style` | Code style (formatting, etc.) | None |
| `refactor` | Code refactoring | None |
| `perf` | Performance improvement | Patch |
| `test` | Adding/updating tests | None |
| `chore` | Maintenance tasks | None |
| `build` | Build system changes | None |
| `ci` | CI/CD changes | None |
| `revert` | Revert previous commit | Patch |

### Examples

```bash
# Simple feature
git commit -m "feat: add user authentication"

# Feature with scope
git commit -m "feat(api): add rate limiting to endpoints"

# Bug fix with body
git commit -m "fix: resolve memory leak in worker

The worker was not properly closing database connections.
This fix ensures all connections are closed on completion."

# Breaking change (triggers major version)
git commit -m "feat!: redesign API authentication

BREAKING CHANGE: API now requires JWT tokens instead of API keys.
Update your client code to use the new auth flow."
```

## Troubleshooting

### Commit message rejected

```bash
# Error: ❌ Invalid commit message format

# Solution: Use conventional commit format
git commit -m "feat: your description here"
```

### Lefthook not installed

```bash
# Error: lefthook: command not found

# Solution: Install lefthook
# macOS
brew install lefthook

# Or using go
go install github.com/evilmartians/lefthook@latest

# Then install hooks
lefthook install
```

### Task not found

```bash
# Error: task: command not found

# Solution: Install Task
# macOS
brew install go-task

# Linux
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin
```

### Release failed - dirty git repo

```bash
# Error: Git repository has uncommitted changes

# Solution: Commit or stash your changes first
git add .
git commit -m "feat: your changes"
# Then retry release
task release:patch
```

## Language-Specific Examples

### Python Project

```yaml
# Taskfile.yml
version: '3'

includes:
  release: .catalyst/tooling/shared/taskfiles/Release.taskfile.yml

tasks:
  install:
    desc: "Install dependencies"
    cmds:
      - poetry install

  test:
    desc: "Run tests"
    cmds:
      - poetry run pytest
```

### TypeScript/Node.js Project

```yaml
# Taskfile.yml
version: '3'

includes:
  release: .catalyst/tooling/shared/taskfiles/Release.taskfile.yml

tasks:
  install:
    desc: "Install dependencies"
    cmds:
      - npm install

  build:
    desc: "Build project"
    cmds:
      - npm run build

  test:
    desc: "Run tests"
    cmds:
      - npm test
```

### Go Project

```yaml
# Taskfile.yml
version: '3'

includes:
  release: .catalyst/tooling/shared/taskfiles/Release.taskfile.yml

tasks:
  build:
    desc: "Build binary"
    cmds:
      - go build -o bin/app .

  test:
    desc: "Run tests"
    cmds:
      - go test ./...
```

## Contributing

This is a template repository designed to be forked and customized. To contribute improvements:

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-improvement`
3. Make your changes with conventional commits
4. Push and create a pull request

## License

MIT License - see [LICENSE](LICENSE) for details

## Related Projects

- [@TheBranchDriftCatalyst](https://github.com/TheBranchDriftCatalyst) - GitHub profile page generator
- [catalyst-devspace](https://github.com/TheBranchDriftCatalyst/catalyst-devspace) - Personal development workspace

## Support

- 📖 [Documentation](docs/)
- 🐛 [Issues](https://github.com/TheBranchDriftCatalyst/git-repo-template/issues)
- 💬 [Discussions](https://github.com/TheBranchDriftCatalyst/git-repo-template/discussions)

---

**Built with ❤️ for standardized releases across all your projects.**
