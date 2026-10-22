#!/usr/bin/env bash
set -euo pipefail

# Provision this repo's 1Password items so every secret reference in
# .env.tpl / .npmrc.tpl / .envrc resolves, showcasing all three direnv
# strategies from the catalyst dotfiles' onepassword library:
#
#   1. use_onepassword      .env.tpl       → op:// refs become env vars
#   2. use_onepassword_tpl  .npmrc.tpl     → whole template → gitignored 0600 file
#   3. use_onepassword_file <ref> <dest>   → ONE whole vault item → 0600 file
#
# Reference grammar is op://<vault>/<item>/<field>, so strategies 1 and 3
# share a single item named after the repo — they are fields on it, not
# separate items. Strategy 2 reads a cross-project item (default: "shared"),
# because a registry token is not per-repo.
#
# NOT wired into .envrc or any hook, deliberately: creating vault items must
# never be a side effect of `cd`.
#
# Usage:
#   scripts/provision-1password.sh [--dry-run]
#
# Env overrides:
#   OP_VAULT        vault to write to            (default: dev)
#   OP_ITEM         repo item title              (default: catalyst_repo.yaml name)
#   OP_SHARED_ITEM  cross-project item title     (default: shared)

VAULT="${OP_VAULT:-dev}"
SHARED_ITEM="${OP_SHARED_ITEM:-shared}"
DRY_RUN=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}✓${NC} $*"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }
log_step() { echo -e "${BLUE}▶${NC} $*"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
    --dry-run) DRY_RUN=1 ;;
    -h | --help)
        sed -n '4,27p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        log_error "unknown argument: $1 (try --help)"
        exit 1
        ;;
    esac
    shift
done

# ── preflight ──────────────────────────────────────────────────────────────

if ! command -v op >/dev/null 2>&1; then
    log_error "op CLI not on PATH."
    echo "  op comes from home-manager (catalyst dotfiles), not this repo's flake —"
    echo "  it is machine-level identity, shared by every repo. Run a dotfiles switch."
    exit 1
fi

if ! op whoami >/dev/null 2>&1; then
    log_error "1Password CLI is not signed in."
    echo "  eval \"\$(op signin)\""
    echo "  (one-time per machine: 1Password app → Settings → Developer →"
    echo "   \"Integrate with 1Password CLI\")"
    exit 1
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    log_error "not inside a git repository"
    exit 1
}

# Item name follows the dotfiles convention dev/<repo-name>/<field>. The
# canonical source for this repo's name is catalyst_repo.yaml — the same file
# catalyst-operator reads — with the directory name as a fallback so this
# still works in a repo that hasn't filled its metadata in yet.
ITEM="${OP_ITEM:-}"
if [[ -z $ITEM ]]; then
    if [[ -f "$repo_root/catalyst_repo.yaml" ]] && command -v yq >/dev/null 2>&1; then
        ITEM="$(yq e '.name // ""' "$repo_root/catalyst_repo.yaml" 2>/dev/null || true)"
    fi
    if [[ -z $ITEM || $ITEM == "null" ]]; then
        ITEM="$(basename "$repo_root")"
    fi
fi

echo
log_step "vault=$VAULT  item=$ITEM  shared=$SHARED_ITEM$( ((DRY_RUN)) && echo "  (dry run)")"
echo

# ── helpers ────────────────────────────────────────────────────────────────

# A missing field makes `op read` exit non-zero, which is the whole
# idempotency story: we only ever ADD what is absent. Existing fields are
# never touched, so re-running this cannot clobber a real secret with a
# freshly generated demo one.
has_field() { # has_field <item> <field-path>
    op read "op://$VAULT/$1/$2" >/dev/null 2>&1
}

item_exists() { # item_exists <item>
    op item get "$1" --vault "$VAULT" >/dev/null 2>&1
}

# Values are never printed — dry-run masks everything after the first '='.
apply() { # apply <item> <assignment>...
    local item="$1"
    shift
    if ((DRY_RUN)); then
        local a
        for a in "$@"; do echo "    would set  ${a%%=*}=<value>"; done
        return 0
    fi
    if item_exists "$item"; then
        op item edit "$item" --vault "$VAULT" "$@" >/dev/null
    else
        op item create --category "Secure Note" --title "$item" \
            --vault "$VAULT" "$@" >/dev/null
    fi
}

# ── the repo item: strategies 1 and 3 ──────────────────────────────────────

repo_fields=()

if has_field "$ITEM" "demo-secret"; then
    log_info "demo-secret already set — left alone"
else
    repo_fields+=("demo-secret[concealed]=$(openssl rand -hex 24)")
    log_step "demo-secret → generating (strategy 1, via .env.tpl)"
fi

if has_field "$ITEM" "db/url"; then
    log_info "db/url already set — left alone"
else
    # Section assignment syntax is <section>.<field>, which is what makes the
    # reference op://<vault>/<item>/db/url resolve.
    repo_fields+=("db.url[concealed]=postgres://dev:dev@localhost:5432/${ITEM//-/_}")
    log_step "db/url → placeholder local postgres URL (strategy 1)"
fi

if has_field "$ITEM" "connect-credentials"; then
    log_info "connect-credentials already set — left alone"
else
    # Syntactically valid JSON so the file materializes and strategy 3 is
    # demonstrable, but NOT a working 1Password Connect credential. For a
    # real one: `op connect server create` emits 1password-credentials.json;
    # put its contents in this field.
    repo_fields+=('connect-credentials[concealed]={"placeholder":"not a real 1Password Connect credential - see: op connect server create","version":"2"}')
    log_step "connect-credentials → placeholder JSON (strategy 3)"
fi

if ((${#repo_fields[@]})); then
    apply "$ITEM" "${repo_fields[@]}"
    ((DRY_RUN)) || log_info "wrote ${#repo_fields[@]} field(s) to op://$VAULT/$ITEM"
else
    log_info "op://$VAULT/$ITEM already complete"
fi

# ── the shared item: strategy 2 ────────────────────────────────────────────

echo
if has_field "$SHARED_ITEM" "npm-registry-token"; then
    log_info "npm-registry-token already set — left alone"
else
    log_step "npm-registry-token → generating (strategy 2, via .npmrc.tpl)"
    apply "$SHARED_ITEM" "npm-registry-token[concealed]=$(openssl rand -hex 20)"
    ((DRY_RUN)) || log_info "wrote npm-registry-token to op://$VAULT/$SHARED_ITEM"
fi

# ── next steps ─────────────────────────────────────────────────────────────

echo
if ((DRY_RUN)); then
    log_warn "dry run — nothing was written"
    exit 0
fi

cat <<EOF
$(log_step "Render them:")

  # nix only sees git-TRACKED files, so an untracked flake.nix makes
  # \`use flake\` fail with "path does not exist"
  git add flake.nix flake.lock .envrc .env.tpl .npmrc.tpl

  direnv allow
  op_rotate      # op_cleanup + forced re-render, so all three render now

$(log_step "Verify each strategy:")

  printenv DEMO_SECRET DATABASE_URL        # 1 → env vars
  ls -l .npmrc                             # 2 → 0600 file
  ls -l .secrets/connect-credentials.json  # 3 → 0600 file
  cat .direnv/op/.manifest                 # both file flavours, for op_cleanup

Expect -rw------- on both files. The manifest is how op_cleanup finds and
removes rendered outputs later, wherever they landed.
EOF
