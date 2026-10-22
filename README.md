# git-repo-template

[![License](https://img.shields.io/github/license/TheBranchDriftCatalyst/git-repo-template)](LICENSE)
[![Release](https://img.shields.io/github/v/release/TheBranchDriftCatalyst/git-repo-template)](https://github.com/TheBranchDriftCatalyst/git-repo-template/releases)

Base git repository template: a nix-provisioned dev shell, 1Password-backed
secrets, git hooks, conventional commits, and config-driven releases.

Tooling patterns here mirror
[catalyst-agentic-sdlc](https://github.com/TheBranchDriftCatalyst/catalyst-agentic-sdlc),
which is the **canonical source** for them. Keep the two aligned so changes
backport cleanly in either direction.

This README describes only what exists on disk. Planned work is in
[docs/ROADMAP.md](docs/ROADMAP.md).

## The stack, and why each piece is here

| Concern                 | Tool                                        | Problem it solves                                                                                                                         | Why this tool                                                                                                                                                                          |
| ----------------------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Dev toolchain**       | nix flake + `direnv`                        | Per-repo tool versions drift from CI's, and global installs collide between projects.                                                     | `flake.lock` pins the whole closure. `cd` in loads the shell, `cd` out unloads it. This is why there is no "install X with brew" section.                                              |
| **Secrets**             | 1Password + `direnv`                        | `.env` files holding real values get committed sooner or later.                                                                           | Only `op://` _references_ are committed; values materialize on entry into gitignored `0600` files. Soft-fail — no `op`, no session, or a missing item warns and the shell still loads. |
| **Secret scanning**     | `gitleaks`                                  | Being careful is not a control. One bad `.gitignore` edit stages a rendered credential.                                                   | Blocking `pre-commit` scan of the staged diff, `--redact` so a finding isn't itself leaked into logs. Go binary from the flake — no npm or yarn equivalent.                            |
| **Git hooks**           | `lefthook`                                  | Checks that only run in CI are found after you've pushed. And two hook frameworks silently fight over `.git/hooks` — last `install` wins. | One binary, parallel execution, and `stage_fixed: true` re-stages what the formatters rewrite, so a fix can't be left behind in the working tree.                                      |
| **Commit format**       | `commitlint`                                | Release and changelog automation needs machine-readable commits; humans don't supply them unprompted.                                     | `config-conventional` accepts `feat!:`, and rejects `FEAT:`, capitalised subjects and unknown types — each with a message naming the rule. Config lives in `package.json`.             |
| **Markdown**            | `markdownlint-cli2` + `markdown-link-check` | Docs rot silently: dead relative links and malformed structure.                                                                           | Auto-fixes what it can on commit. Link checking ignores external URLs on purpose, so a blocking hook stays offline and deterministic.                                                  |
| **Formatting**          | `prettier`                                  | Diff noise and bikeshedding over md/json/yaml style.                                                                                      | Config in `package.json`; auto-fixes and re-stages on commit.                                                                                                                          |
| **Conflict markers**    | `git diff --check`                          | `<<<<<<<` reaching `main`.                                                                                                                | Built into git. Nothing to maintain.                                                                                                                                                   |
| **Version + changelog** | `commit-and-tag-version`                    | Hand-bumped versions desync from tags and changelogs, and nobody remembers the steps.                                                     | Fully config-driven in `package.json`: changelog sections, URL formats, `bumpFiles` with custom updaters, and a `prerelease` hook that runs tests before anything is tagged.           |
| **GitHub Release**      | tag-triggered workflow                      | A git tag is not a release page.                                                                                                          | Fires on `v*`, extracts that version's notes from `CHANGELOG.md`, publishes. It never computes a version — one writer per artifact.                                                    |
| **CI**                  | GitHub Actions                              | Nothing above is trustworthy if it only ran on one laptop.                                                                                | Lint + format + commit-message checks, running unconditionally rather than behind project-type detection.                                                                              |
| **Dependencies**        | `renovate`                                  | Deps rot silently; naive config means one PR per package per week.                                                                        | Non-major updates grouped into one weekly automerged PR; majors isolated for review.                                                                                                   |
| **Repo metadata**       | `catalyst_repo.yaml`                        | The operator cockpit and profile generator need machine-readable repo facts.                                                              | Read _and written_ at the repo root by catalyst-operator's loader — root path only, no upward walk, so the location is load-bearing.                                                   |

`lefthook` is the only git-hook framework here. There is no `pre-commit`, no
husky, and nothing in `.git/hooks` but samples until `yarn install` runs.

## Quick start

```sh
git clone https://github.com/TheBranchDriftCatalyst/git-repo-template my-new-repo
cd my-new-repo

direnv allow    # builds the nix dev shell, loads secrets
yarn install     # installs tooling AND git hooks (via the `prepare` script)
```

`direnv allow` gives you the toolchain; `yarn install` gives you the hooks.
Neither step needs anything pre-installed beyond nix and direnv.

> **nix only sees git-tracked files.** In a fresh repo, `git add flake.nix
flake.lock` before `direnv allow`, or `use flake` fails with "path does not
> exist".

## Workflows

### Install hooks

```sh
yarn install              # `prepare` runs `lefthook install`
npx lefthook install     # or directly, if hooks are all you want
```

### Lint and format

```sh
yarn test                 # format:check + lint:md + lint:links — what CI runs
yarn lint:md          # markdownlint
yarn lint:md:fix      # markdownlint, fixing what it can
yarn lint:links       # broken relative links and heading anchors
yarn lint:secrets     # gitleaks over history
yarn format           # prettier --write over md/json/yml/yaml
yarn format:check     # prettier, no writes
```

Or through either runner: `task test` / `just test`, `task lint` / `just lint`,
`task format` / `just format`.

### Generate a changelog

```sh
yarn release:dry      # preview the next version + changelog entry, writes NOTHING
yarn changelog        # regenerate CHANGELOG.md from all history
```

`release:dry` is the preview — there is no separate preview tool, because a
second changelog generator would be a second writer of the same file.

### Release

```sh
yarn release          # bump version, write CHANGELOG.md, commit, tag
yarn release:push     # push commit + tag → triggers the GitHub Release
```

Force a level with `release:patch` / `release:minor` / `release:major`. The
`prerelease` hook runs `yarn test` first, so a failing check stops the release
before it tags anything. Full detail, including the one-writer-per-artifact
rule: [docs/RELEASE.md](docs/RELEASE.md).

### Secrets

```sh
scripts/provision-1password.sh --dry-run   # what's missing, values masked
scripts/provision-1password.sh             # create only what's absent
op_rotate                                  # re-render after rotating a secret
op_cleanup                                 # delete every rendered secret
```

`.env.tpl` and `.npmrc.tpl` commit `op://` references only. Three strategies
are exercised by `.envrc`:

| Strategy               | Renders to             | Used here for                                                              |
| ---------------------- | ---------------------- | -------------------------------------------------------------------------- |
| `use_onepassword`      | env vars               | `DEMO_SECRET`, `DATABASE_URL` from `.env.tpl`                              |
| `use_onepassword_tpl`  | gitignored `0600` file | `.npmrc`, since yarn/npm take a registry token only from a config file     |
| `use_onepassword_file` | gitignored `0600` file | one whole vault item `op inject` can't template, e.g. a Connect credential |

`op` and the `use_onepassword*` functions come from home-manager (catalyst
dotfiles), not this flake — they're machine-level, shared by every repo.

> The `.npmrc`, `.secrets/` and `.direnv/` entries in `.gitignore` are
> **load-bearing**, not hygiene: the helpers call `git check-ignore` and refuse
> to render to a path in the repo that isn't ignored.

## Commit format

Enforced by lefthook on `commit-msg`:

```
type(scope)?: description
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`,
`build`, `ci`, `revert`.

```sh
git commit -m "feat: add user authentication"    # ✅
git commit -m "fix(api): correct status code"    # ✅
git commit -m "feat!: drop API key support"      # ✅ breaking → major
git commit -m "added stuff"                      # ❌ rejected
git commit -m "FEAT: shouty"                     # ❌ type-case
```

## Layout

```
.envrc  flake.nix  flake.lock        nix dev shell + direnv entry
.env.tpl  .npmrc.tpl                 op:// secret references (safe to commit)
.config/starship.toml                repo-local prompt
.vscode/                             direnv + nix-ide recommendations

package.json                         yarn scripts + config for prettier,
                                     commitlint and commit-and-tag-version
lefthook.yml                         git hooks
.markdownlint-cli2.jsonc             markdown rules
.markdown-link-check.json            link checking (external URLs ignored)
.prettierignore                      incl. CHANGELOG.md and secret paths
renovate.json                        dependency update policy
catalyst_repo.yaml                   repo metadata (root path is load-bearing)
CHANGELOG.md                         generated — do not hand-edit

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

A deliberately small FastAPI + React pair, there to exercise the dev
environment rather than to be interesting: `flake.nix` pins its toolchain,
`.envrc` installs its deps on entry, and `Tiltfile` runs it in a local
cluster.

```sh
# two terminals, no cluster needed
cd backend  && uv run uvicorn main:app --reload   # :8000
cd frontend && yarn dev                           # :5173, proxies /api → :8000

# or the whole thing in a local k8s cluster
kind create cluster --name git-repo-template
tilt up            # builds images, applies k8s/, live-syncs code into pods
tilt down

# tests and build
cd backend  && uv run pytest
cd frontend && yarn build
```

`allow_k8s_contexts` in the `Tiltfile` restricts it to `kind-git-repo-template`,
`docker-desktop` and `orbstack` — Tilt refuses to apply anything if your
current context is a real cluster.

`.envrc` installs both dependency trees on directory entry, mtime-guarded
against the manifests, and each block is additionally guarded on its manifest
existing — so a repo created from this template that deletes `backend/` or
`frontend/` still loads cleanly.

## Docs

| File                               | What it covers                                                      |
| ---------------------------------- | ------------------------------------------------------------------- |
| [docs/RELEASE.md](docs/RELEASE.md) | Release and changelog workflow, version bump rules, troubleshooting |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Everything not built yet, and open decisions                        |
| [CLAUDE.md](CLAUDE.md)             | Invariants and settled decisions, for AI agents                     |

## License

MIT — see [LICENSE](LICENSE).
