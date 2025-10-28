#!/usr/bin/env bash
set -euo pipefail

COMMIT_MSG_FILE="${1:-}"

if [[ -z "$COMMIT_MSG_FILE" ]]; then
    echo "Usage: validate-commit.sh <commit-msg-file>"
    exit 1
fi

COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# Conventional Commits regex
PATTERN='^(feat|fix|docs|style|refactor|perf|test|chore|build|ci|revert)(\(.+\))?: .{1,}'

if ! echo "$COMMIT_MSG" | grep -qE "$PATTERN"; then
    cat << EOF
❌ Invalid commit message format

Commit message must follow Conventional Commits:
  type(scope?): description

Types:
  feat     - New feature
  fix      - Bug fix
  docs     - Documentation changes
  style    - Code style changes (formatting, etc.)
  refactor - Code refactoring
  perf     - Performance improvements
  test     - Adding or updating tests
  chore    - Maintenance tasks
  build    - Build system changes
  ci       - CI/CD changes
  revert   - Revert previous commit

Examples:
  feat: add user authentication
  fix(api): correct response status code
  docs: update README with new examples

Your commit message:
  $COMMIT_MSG

EOF
    exit 1
fi

exit 0
