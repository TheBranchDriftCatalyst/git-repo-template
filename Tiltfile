# -*- mode: Python -*-
# Tiltfile for @git-repo-template
#
# This is the project's own Tiltfile. Add your own k8s_yaml(...) /
# docker_build(...) / local_resource(...) declarations as needed.
#
# ── catalyst-operator dev-loop sandbox (op-i46) ──────────────────────
# The catalyst-operator agent runs python in a per-project k3d pod
# instead of on your host. To enable, keep the include() line below.
# To opt out, comment it out or delete it.
#
# The pod uses the catalyst-dev:full image, mounts a git worktree of
# THIS repo (on branch dev-loop/main) at /workspace, and is reachable
# from the operator via `kubectl exec`.
include('.dev-loop/sandbox.tiltfile.py')
# ── end catalyst-operator dev-loop sandbox ───────────────────────────
