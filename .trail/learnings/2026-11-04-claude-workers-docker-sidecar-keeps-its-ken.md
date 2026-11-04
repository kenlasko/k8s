---
title: "Claude workers' Docker sidecar keeps its rootlesskit state outside the shared /tmp, because the worker's temp cleanup broke port publishing"
author: Ken
date: 2026-11-04
branch: main
id: l-900223ea
scope: repo
status: active
src: agent
touches:
  - manifests/apps/claude-workers/README.md
  - manifests/apps/claude-workers/base/statefulset.yaml
---

## Decided
rootlesskit's state dir (holding api.sock, which dockerd calls for every published port) is pinned to the sidecar's own filesystem, and a liveness probe restarts the sidecar if the socket disappears.

## Tried and ruled out
Blaming the machine: workers reported "Docker can't publish ports" and gave up on screenshots. It looked intermittent because a sidecar younger than an hour worked fine; after that every `docker run -p` failed.

## Watch out
The dind-rootless entrypoint exports XDG_RUNTIME_DIR but never passes --state-dir, so rootlesskit falls back to a random dir under /tmp. /tmp is an emptyDir shared with the worker so bind mounts resolve, and the worker's clean_tmp removes anything in /tmp older than TMP_CLEAN_MINUTES (60), including that dir. Anything else the sidecar keeps in /tmp has the same exposure.

In the code:
- statefulset.yaml dind env DOCKERD_ROOTLESS_ROOTLESSKIT_FLAGS=--state-dir=/home/rootless/.rootlesskit; livenessProbe `test -S /home/rootless/.rootlesskit/api.sock`
- Symptom: `error while calling RootlessKit PortManager.AddPort(): ... dial unix /tmp/rootlesskit<N>/api.sock: connect: no such file or directory`
- worker.sh clean_tmp: find /tmp -mindepth 1 -maxdepth 1 -mmin +TMP_CLEAN_MINUTES -exec rm -rf
