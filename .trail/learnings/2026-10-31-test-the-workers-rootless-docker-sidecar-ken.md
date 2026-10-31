---
title: "Test the workers' rootless Docker sidecar locally with root-owned volumes, not plain named volumes"
author: Ken
date: 2026-10-31
branch: main
cost: { minutes: 34, tokens: 131458 }
id: l-d21e79f9
scope: repo
status: active
src: agent
touches:
  - manifests/apps/claude-workers/base/statefulset.yaml
  - manifests/apps/claude-workers/README.md
  - manifests/apps/claude-workers/base/env-vars.yaml
  - manifests/apps/claude-workers/base/namespace.yaml
  - manifests/apps/claude-workers/base/worker.sh
  - manifests/apps/claude-workers/image/Dockerfile
---

## Decided
- The dind sidecar's data emptyDir is mounted one level above Docker's data root. The emptyDir itself is owned by root on the node, which is unmapped inside rootlesskit's user namespace, so dockerd can't chmod it and the sidecar crashloops.

## Tried and ruled out
- Testing the sidecar locally with an ordinary named Docker volume: it passed, yet crashlooped in the cluster. An empty named volume takes its ownership from the image (uid 1000), unlike an emptyDir. A test only reproduces the cluster when the volume is root-owned and mounted with volume-nocopy.

## Watch out
- An ad-hoc test container started through kubectl exec on an idle worker can disappear mid-test: the worker's between-task cleanup removes every container on each poll. Run the container and check it in one quick command. Real Claude runs aren't affected, since cleanup only runs between runs.
- Nodes already allow user namespaces (user.max_user_namespaces=11255), which rootless Docker needs. A Talos change that resets that sysctl would break the sidecar.

In the code:
- manifests/apps/claude-workers/base/statefulset.yaml: dind sidecar, docker-data mounted at /home/rootless/.local/share
- Local repro: chown a volume's root to 0:1000, then `docker run --privileged --user 1000:1000 --mount type=volume,src=<vol>,dst=/home/rootless/.local/share/docker,volume-nocopy docker:29.9.1-dind-rootless dockerd --host=unix:///tmp/d.sock`
- In-cluster smoke test: `kubectl -n claude-workers exec claude-worker-N -c claude-worker -- docker run --rm -d -p 3099:80 nginx:alpine` then curl localhost:3099 in the same exec
