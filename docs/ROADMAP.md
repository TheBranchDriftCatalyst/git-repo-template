# Roadmap

Everything here is **not built yet**. `README.md` and `CLAUDE.md` describe only
what exists on disk; anything aspirational lives here so the reference docs
stay trustworthy.

## Blocking

### Submodule into `.dotfiles`

Add this repo to `.dotfiles` as `examples/git-repo-template` and delete
`example/test-flake-direvn`. It will be the first `.gitmodules` entry there.

Open: whether to fix the `direvn` → `direnv` typo in the source directory name.
The vault items were already renamed to `op://dev/git-repo-template/*` and
verified resolving, so nothing is blocked on it.

## Planned

### `docker-publish.yml`

Multi-arch image build on GitHub Release, publishing to Docker Hub + GHCR.
Needs `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` secrets.

This is now the _only_ path to a published image: the deleted
`build-release.sh` held the local buildx half, and nothing replaced it.

### Dockerfile templates

Starting points per language. Referenced by the old README and never created;
if revived they belong somewhere that is not a resurrected `.catalyst/`.

### `treefmt`

`prettier` covers md/json/yaml. Actual source formatting (nix, python, shell,
ts) has no entry point. `treefmt` is the nix-ecosystem answer and multiplexes
`nixfmt` / `ruff` / `shfmt` / `prettier` behind one command.

Deferred because the formatter set is per-language and the reference app isn't
here yet. Note that canonical does not use treefmt, so this would be a
deliberate divergence.

### `scope-enum` for commitlint

Canonical pins valid commit scopes:

```json
"scope-enum": [2, "always", ["marketplace", "sdlc-framework", "tooling", "docs", "deps", "ci", "release"]]
```

Deliberately omitted here — a template shouldn't ship another repo's scope
list. Worth adding once this repo's own scopes settle.

### Adopt the canonical tooling in older repos

Roll `package.json` + `lefthook.yml` + the two workflows into repos predating
this pattern. Now a copy-the-files job rather than a submodule rollout.

## Resolved

Kept as a record so these are not relitigated.

- **Toolchain install.** `yarn install` has run: `yarn.lock` committed, and
  the `prepare` script installed lefthook's `commit-msg` and `pre-commit`
  hooks. `yarn test` passes — prettier clean, markdownlint 0 errors over 18
  files, link check clean.
- **npm → yarn at the root.** Canonical uses npm; this repo now uses yarn
  everywhere. Only the install lines differ (`cache: yarn`, `yarn install
--frozen-lockfile`); the `prettier` / `commitlint` /
  `commit-and-tag-version` config keys are package-manager agnostic, so
  tooling still backports cleanly.
- **uv ignoring the flake's Python.** `flake.nix` pinned `python312` while uv
  fetched its own 3.14 to satisfy `requires-python = ">=3.12"`. Resolved by
  going the other way: nix no longer ships python at all, uv owns the
  interpreter, and `backend/.python-version` pins 3.12 as the single source of
  truth. Verified — the venv rebuilt on 3.12.15 and tests pass.
- **`flake-demo-*` image names.** Renamed to `git-repo-template-{backend,frontend}`
  across the `Tiltfile` and both k8s manifests together, plus the
  `kind-git-repo-template` context. Verified that every `docker_build` name has
  a matching manifest `image:`.
- **`lint:links` crashing on deleted files.** `git ls-files '*.md'` lists
  tracked-but-deleted paths, which made markdown-link-check `stat` a missing
  file and abort the whole hook. Now filters to files that exist.
- **The demo app merge.** `backend/`, `frontend/`, `k8s/` and the real
  `Tiltfile` are now here. Copied via `git ls-files` so no `.venv/`,
  `node_modules/`, `__pycache__/` or `.direnv/` came along. Verified: `yarn
build` succeeds (esbuild's postinstall needed no `allowBuilds` replacement
  for the dropped `pnpm-workspace.yaml`) and `uv run pytest` passes.
- **pnpm → yarn.** `frontend/yarn.lock` generated, `pnpm-lock.yaml` and
  `pnpm-workspace.yaml` dropped, `frontend/Dockerfile` switched to `corepack
enable` + `yarn install --frozen-lockfile`, and the `Tiltfile` `live_update`
  trigger now names `yarn.lock`.
- **The unguarded dev-loop include.** `Tiltfile` called
  `include('.dev-loop/sandbox.tiltfile.py')` unconditionally while `.dev-loop/`
  is gitignored, so `tilt up` would fail in any fresh clone. Now guarded on
  `os.path.exists`.

- **1Password direnv library portability.** Was an open three-way choice
  (soft-fail / vendor / flake output). Closed: the library stays in `.dotfiles`
  and `.envrc` calls into it, because the machine consuming this template is by
  definition the one home-manager provisioned. The `declare -F` guards already
  handle the degraded case.
- **Shared-tooling submodule.** `.catalyst/` deleted. Standard packaged tools
  replaced every bespoke script in it.
- **copier / templating.** Dropped. Its `_subdirectory` duplicated every file
  it templated — the same two-sources-of-truth problem as the old `install.sh`
  heredocs. GitHub's template-repository feature instead.
- **Release tooling.** release-please, `git-cliff` and `build-release.sh` all
  removed in favour of `commit-and-tag-version`, matching canonical.
- **Per-repo tooling overrides.** `.catalyst/tooling/repos/<name>/` was
  documented with `kasa-exporter` / `swarm-graph` / `catalyst-ui` examples and
  never existed on disk. Moot without a submodule, and it inverted the
  dependency anyway — a shared repo holding per-consumer config.
- **Project-type detection in CI.** The old `ci.yml` grepped the repo root for
  `package.json` / `pyproject.toml` / `go.mod` and skipped every job when the
  manifests lived in subdirectories, reporting green having run nothing. Jobs
  now run unconditionally.
- **`install.sh` / `bootstrap.sh`.** Deleted. `bootstrap.sh` probed the hooks
  by making two commits, one of them literally titled "invalid commit message".
  `install.sh` heredoc-generated five files that had already drifted from their
  real counterparts.
