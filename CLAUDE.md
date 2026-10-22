# CLAUDE.md

Guidance for AI agents working in this repository.

This file describes **only what exists on disk**. Planned work and open
decisions live in [docs/ROADMAP.md](docs/ROADMAP.md); do not implement from
here anything that file lists as unbuilt.

## What this repo is

A base git repository template: a nix-provisioned dev shell, 1Password-backed
secrets, git hooks, conventional commits, and config-driven releases. Clone it
to start a new repo.

It is **not** a shared-tooling submodule. There used to be a `.catalyst/`
directory mounted into other repos; it is gone, and nothing should reintroduce
it. Shared behaviour now comes from three standard mechanisms instead: pinned
versions in `flake.nix` and `yarn.lock`, GitHub's template-repository
feature, and alignment with the canonical repo below.

## Canonical alignment

Tooling patterns here mirror **catalyst-agentic-sdlc**, which is the canonical
source. `package.json` (scripts, `prettier`, `commitlint`,
`commit-and-tag-version`), `lefthook.yml`, `.markdownlint-cli2.jsonc`,
`.prettierignore`, `ci.yml` and `release.yml` all came from there.

When changing any of those, prefer matching canonical over inventing a local
variant — the point is that changes backport cleanly in either direction. If a
divergence is genuinely necessary, comment why in the file itself.

Known deliberate divergences:

- **yarn, not npm.** Canonical uses npm. This repo uses yarn at the root and in
  `frontend/`, as two independent trees each with their own `yarn.lock` and
  `node_modules`. Only the install lines differ — the tooling config keys in
  `package.json` are package-manager agnostic, so changes still backport
  cleanly.
- **uv owns Python; nix does not provide it.** `flake.nix` ships `uv` but no
  `python*`. The interpreter is declared once, in `backend/.python-version`.
- **A nix flake.** Canonical has none. This repo provisions its toolchain
  through `flake.nix` + `.envrc`.
- **gitleaks from the flake.** A Go binary with no npm or yarn equivalent.

## Invariants

Break these and things corrupt silently rather than failing loudly.

### One writer per artifact

| Artifact                    | Sole writer                         |
| --------------------------- | ----------------------------------- |
| `CHANGELOG.md`              | `commit-and-tag-version`            |
| version (in `package.json`) | `commit-and-tag-version`            |
| `v*` git tags               | `commit-and-tag-version`            |
| GitHub Release page         | `release.yml`, from an existing tag |

This repo once ran `release-please` _and_ a local `build-release.sh`, both
bumping the version and pushing `v*` tags, which desynced the version file
(`0.1.1`) from release-please's manifest (`0.1.0`). Both are deleted. Do not
add a second changelog generator, a second version bumper, or a CI step that
computes a version. See [docs/RELEASE.md](docs/RELEASE.md).

### `catalyst_repo.yaml` lives at the repo root

catalyst-operator's loader
(`packages/catalyst-repo/src/catalyst_repo/loader.py`) sets
`MANIFEST_FILENAME = "catalyst_repo.yaml"` and resolves it at the repo root
**with no upward walk**, writing back to the same path. Do not move it, rename
it, or add a second copy — there used to be one at `.catalyst/repo.yaml` that
nothing read while it quietly diverged from the live file.

### lefthook is the only git-hook framework

No `pre-commit`, no husky, no `core.hooksPath` override. There were once two
frameworks both installing into `.git/hooks/pre-commit`, where the last
`install` to run wins — so one was always a silent no-op. That is why 11
tracked files had trailing whitespace while a `trailing-whitespace` hook was
nominally configured.

Hooks are installed by `yarn install` via the `prepare` script.

### Git hooks and Claude Code hooks are different layers

Two hook systems are in play and they are not interchangeable:

- **lefthook** fires on git operations (`pre-commit`, `commit-msg`)
- **Claude Code hooks** fire on agent tool calls — `git-guard.sh` as
  `PreToolUse`/`Bash` from the catalyst-meta plugin, plus the GateGuard checks

They overlap in intent in exactly one place: `git-guard.sh` blocks AI
attribution in commit messages, and lefthook's `commit-msg` has its own
`no-ai-attribution` command. **Keep both.** git-guard stops the agent before
the command runs; lefthook stops any commit, including a human's or one made
outside Claude Code. Different surfaces, same rule — this duplication is
deliberate, not an oversight to clean up.

### Hooks must not require a task runner

`task` and `just` are both supported and both are thin delegates to the yarn
scripts in `package.json`. The yarn scripts are the single definition of every
operation. A hook or CI step must invoke a binary or a yarn script directly, so
neither runner is ever a hard requirement.

If a recipe needs more than a delegation, it belongs in `package.json`'s
`scripts`, so CI, the hooks and both runners all invoke the same thing.

### Secret paths in `.gitignore` are load-bearing

`.direnv/`, `.npmrc` and `.secrets/` are not hygiene entries. The 1Password
direnv helpers call `git check-ignore` and **refuse to render** to a path
inside the repo that is not ignored, bailing with "secrets NOT loaded". Delete
any of those lines and secrets silently stop materializing.

`gitleaks` on `pre-commit` is the backstop for the day that goes wrong.

## Layout

```
.envrc  flake.nix  flake.lock        nix dev shell + direnv entry
.env.tpl  .npmrc.tpl                 op:// secret references (safe to commit)
.config/starship.toml  .vscode/      repo-local prompt, editor recommendations

package.json                         yarn scripts + config for prettier,
                                     commitlint, commit-and-tag-version
lefthook.yml                         git hooks
.markdownlint-cli2.jsonc             markdown rules
.markdown-link-check.json            link checking (external URLs ignored)
.prettierignore                      incl. CHANGELOG.md and secret paths
renovate.json  catalyst_repo.yaml    dependency policy, repo metadata
CHANGELOG.md                         generated — never hand-edit

Taskfile.yml  justfile               thin delegates to the yarn scripts
scripts/provision-1password.sh       create this repo's vault items
.github/workflows/ci.yml             lint + format + commitlint
.github/workflows/release.yml        tag → GitHub Release

backend/                             FastAPI + uv reference service
frontend/                            React + Vite reference UI (yarn)
k8s/                                 manifests for both services
Tiltfile                             local k8s dev loop, context-guarded
```

## The reference app

`backend/` (FastAPI, uv) and `frontend/` (React, Vite, yarn) exist to exercise
the dev environment, not as product code. Keep them minimal.

- **uv picks the interpreter, not nix.** `backend/.python-version` pins 3.12
  and `requires-python` is only a floor. Do not add `python*` to `flake.nix`:
  that produced two sources of truth, and uv ignored the flake's 3.12 to fetch
  its own 3.14.
- **yarn, never pnpm or npm, inside `frontend/`.** It was converted from pnpm;
  `pnpm-lock.yaml` and `pnpm-workspace.yaml` were dropped deliberately. The
  root tree also uses yarn, but the two are independent — never a shared
  `yarn.lock` or `node_modules`.
- **`Tiltfile` `live_update` triggers must name the lockfile.** The frontend
  trigger lists `frontend/yarn.lock`; if that drifts from the real lockfile
  name, a dependency change syncs source and silently leaves `node_modules`
  stale inside the pod.
- **The dev-loop `include()` is guarded on `os.path.exists`.** `.dev-loop/` is
  gitignored, so an unguarded include breaks `tilt up` in a fresh clone.
- **`allow_k8s_contexts` is a safety guardrail**, not configuration. Do not
  widen it to a real cluster context.
- Image names are still `git-repo-template-backend` / `git-repo-template-frontend`, matching
  `image:` in `k8s/*.yaml`. Rename in both places or not at all.

## Decisions already made

Do not relitigate without being asked:

- **Single `main`.** No variant or flavour branches.
- **No submodule.** `.catalyst/` is deleted; don't bring it back.
- **No copier / template subdirectory.** It duplicated every file it templated
  — the same two-sources-of-truth problem as the heredocs in the old
  `install.sh`. Use GitHub's template-repository feature.
- **lefthook** only, never a second hook framework.
- **commitlint** for commit messages, config in `package.json`.
- **commit-and-tag-version** for version + changelog. Not release-please, not
  git-cliff, not a bespoke release script.
- **gitleaks** blocking on `pre-commit`.
- **Both `task` and `just`**, as delegates only.
- **Toolchain provisioned by nix**, which is why there is no "install X with
  brew" documentation anywhere.

## Conventions

Commits must be conventional (`type(scope)?: description`), enforced by the
`commit-msg` hook. Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`,
`test`, `chore`, `build`, `ci`, `revert`. `feat!:` signals a breaking change.

Do not add AI attribution trailers to commit messages — two separate hooks
reject them.

Releases are local (`yarn release` then `yarn release:push`); CI only
publishes the pushed tag.
