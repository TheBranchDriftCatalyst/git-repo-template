set shell := ["bash", "-uc"]

# Thin delegates to the yarn scripts in package.json, which are the single
# definition of every operation. Mirrors Taskfile.yml; neither runner is
# required — `yarn <script>` always works on its own.
#
# Nothing here reimplements logic. If a recipe would need more than a
# delegation, it belongs in package.json's scripts instead, so that CI, the
# git hooks and both runners all invoke the same thing.

default:
    @just --list

# Install tooling and git hooks (yarn `prepare` runs lefthook install)
install:
    yarn install

# Prettier check + markdown lint
test:
    yarn test

# Lint markdown
lint:
    yarn lint:md

# Lint markdown, fixing what can be fixed
lint-fix:
    yarn lint:md:fix

# Format md/json/yaml with prettier
format:
    yarn format

# Check formatting without writing
format-check:
    yarn format:check

# ─── Release ───────────────────────────────────────────────────────────────
# commit-and-tag-version bumps package.json, writes CHANGELOG.md, commits and
# tags — all configured under the "commit-and-tag-version" key in
# package.json. Pushing the tag is what triggers the GitHub Release workflow.
# See RELEASE.md.

# Preview the next version and changelog entry — writes nothing
release-dry:
    yarn release:dry

# Bump version, write CHANGELOG.md, commit and tag
release:
    yarn release

# Force a patch release
release-patch:
    yarn release:patch

# Force a minor release
release-minor:
    yarn release:minor

# Force a major release
release-major:
    yarn release:major

# Push the release commit and tag (triggers the GitHub Release)
release-push:
    yarn release:push
