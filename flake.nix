{
  description = "git-repo-template: repo tooling + reference app dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      # one dev shell per platform, so it works on your mac and on linux CI
      forEachSystem =
        f:
        nixpkgs.lib.genAttrs [
          "aarch64-darwin"
          "x86_64-darwin"
          "x86_64-linux"
          "aarch64-linux"
        ] (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            # ── repo tooling ────────────────────────────────────────────
            # Everything the hooks, runners and release flow need. This is
            # why the README has no "install Task / install lefthook with
            # brew" section: the dev shell IS the prerequisite, and it pins
            # the whole closure via flake.lock rather than trusting whatever
            # version brew happens to have.
            # lefthook, commitlint, prettier, markdownlint-cli2 and
            # commit-and-tag-version are NOT here on purpose: they arrive via
            # npm devDependencies, pinned by package-lock.json, exactly as in
            # catalyst-agentic-sdlc. Duplicating them in the flake would mean
            # two pinnings of the same tool, and the npm one is what the hooks
            # and CI actually invoke.
            nodejs_22 # npm — the entrypoint for all repo tooling above
            gitleaks # secret scanning on pre-commit; a Go binary, no npm equivalent
            go-task # provides `task`
            just # provides `just` — mirrored recipes, pick either
            yq-go # provides `yq`, used by scripts/provision-1password.sh

            # ── reference app toolchain ─────────────────────────────────
            # backend — uv only, no python312.
            #
            # uv IS a Python version manager, so letting it own the
            # interpreter keeps the version declared in exactly one place
            # (backend/.python-version). Pinning python here as well meant two
            # sources of truth that promptly disagreed: the shell provided
            # 3.12 while uv satisfied `requires-python = ">=3.12"` by fetching
            # its own 3.14, and the venv was built against the one nix did not
            # pin.
            #
            # Same division of labour as the frontend: nix provides the
            # package manager, the package manager owns what it manages.
            uv

            # frontend — nodejs_22 is already above, for npm.
            #
            # Two package managers, two scopes, on purpose:
            #   npm  at the repo root → tooling (matches the canonical repo,
            #                           so tooling changes backport cleanly)
            #   yarn in frontend/     → the reference app's own dependencies
            # They never share a lockfile or a node_modules tree.
            yarn

            # local k8s dev loop
            tilt
            kubectl
            kind
          ];

          # Deliberately NOT in this shell: the `op` CLI and the
          # use_onepassword* direnv functions. Both come from home-manager
          # (catalyst dotfiles), because they are machine-level identity, not
          # per-repo toolchain — the same `op` session serves every repo. See
          # .envrc for how this repo consumes them, and the soft-fail
          # branches there for what happens on a machine without them.
          shellHook = ''
            echo "⚗️  git-repo-template · node $(node --version) · uv $(uv --version | cut -d' ' -f2)"
          '';
        };
      });
    };
}
