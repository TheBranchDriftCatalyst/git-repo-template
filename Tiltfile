# -*- mode: Python -*-
# Local k8s dev loop for the reference app: `tilt up`
# Expects a local cluster context (kind / docker-desktop / orbstack).

# Guardrail: never let this Tiltfile touch a real cluster. Tilt refuses to
# apply anything when the current context is not in this list.
allow_k8s_contexts(['kind-git-repo-template', 'docker-desktop', 'orbstack'])

docker_build(
    'git-repo-template-backend',
    './backend',
    live_update=[
        # code changes sync straight into the pod; uvicorn --reload picks them up
        sync('./backend', '/app'),
        # dep changes re-sync the venv inside the container
        run('uv sync --frozen --no-dev', trigger=['./backend/pyproject.toml', './backend/uv.lock']),
    ],
)

docker_build(
    'git-repo-template-frontend',
    './frontend',
    live_update=[
        # vite HMR picks up synced source instantly
        sync('./frontend', '/app'),
        # yarn, not pnpm — the trigger must name yarn.lock, or a dependency
        # change would sync the source and silently leave node_modules stale
        run('yarn install --frozen-lockfile', trigger=['./frontend/package.json', './frontend/yarn.lock']),
    ],
)

k8s_yaml(['k8s/backend.yaml', 'k8s/frontend.yaml'])

k8s_resource('backend', port_forwards='8000:8000')
k8s_resource('frontend', port_forwards='5173:5173')

# ── catalyst-operator dev-loop sandbox (op-i46) ──────────────────────
# The catalyst-operator agent runs python in a per-project k3d pod instead of
# on your host. The pod uses the catalyst-dev:full image, mounts a git worktree
# of THIS repo (branch dev-loop/main) at /workspace, and is reachable from the
# operator via `kubectl exec`.
#
# Guarded on existence rather than included unconditionally: .dev-loop/ is
# gitignored, so a fresh clone does not have it and a bare include() would
# fail `tilt up` for anyone who has never run the operator. Opt out by
# deleting this block.
if os.path.exists('.dev-loop/sandbox.tiltfile.py'):
    include('.dev-loop/sandbox.tiltfile.py')
# ── end catalyst-operator dev-loop sandbox ───────────────────────────
