---
title: "Some volsync ReplicationSources are hand-written backup.yaml files, not the baseline chart; fsGroup must be set there too"
author: Ken
date: 2026-10-26
branch: main
cost: { minutes: 6, tokens: 10216 }
id: l-456ad443
scope: repo
status: active
src: agent
touches:
  - helm/baseline/templates/volsync-backup.yaml
  - manifests/database/pgadmin/base/backup.yaml
  - manifests/apps/adguard/overlays/cloud/backup.yaml
  - manifests/apps/garmin-upload/base/backup.yaml
---

## Decided
Every non-root moverSecurityContext gets `fsGroup` (= runAsGroup) + `fsGroupChangePolicy: OnRootMismatch`, whether rendered by helm/baseline/templates/volsync-backup.yaml or written by hand in an app's backup.yaml (pgadmin uid 5050, adguard cloud overlay, garmin-upload).

## Tried and ruled out
Fixing only the baseline chart template: pgadmin (manifests/database/pgadmin/base/backup.yaml) kept failing with the same restic "open /cache/CACHEDIR.TAG: permission denied". Assuming a `local-path` cache (adguard cloud, cacheStorageClassName: local-path) is exempt: it failed the same way; local-path PVs are `local` type, which kubelet applies fsGroup to.

## Watch out
To find all of them: `grep -rl "kind: ReplicationSource" manifests --include=backup.yaml` plus the baseline template. A new non-root backup.yaml without fsGroup fails on volsync >= 0.17 (restic 0.19).
