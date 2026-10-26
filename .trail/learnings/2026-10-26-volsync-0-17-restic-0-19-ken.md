---
title: Volsync 0.17 (restic 0.19) movers fail when NFS cache PVC not writable by non-root mover uid
author: Ken
date: 2026-10-26
branch: main
id: l-3ade993d
scope: repo
status: active
src: agent
touches:
  - helm/baseline/templates/volsync-backup.yaml
  - manifests/system/volsync/base/values.yaml
---

## Decided
Mover pods from helm/baseline/templates/volsync-backup.yaml get `fsGroup` (= runAsGroup) + `fsGroupChangePolicy: OnRootMismatch` in moverSecurityContext. nfs.csi.k8s.io CSIDriver has `fsGroupPolicy: File`, so kubelet chgrps the cache/data volumes to the mover group with setgid + g+rwx.

## Tried and ruled out
Not an S3/Cloudflare/repo problem despite the final line "ERROR: failure checking existence of repository". Real error is first in the log: "unable to open cache: open /cache/CACHEDIR.TAG: permission denied".

## Watch out
csi-driver-nfs creates PVC subdirs as root:root 0755. Non-root movers (runAsUser 1000) never wrote the restic cache: cache PVCs sat empty since creation. restic before 0.19 only warned and backed up without cache; restic 0.19.1 (shipped with volsync 0.17.0, upgraded 2026-10-26) treats it as fatal, so every non-root ReplicationSource failed and root ones (homeassist, paperless, nextcloud) kept working. The `moverSecurityContext` in manifests/system/volsync/base/values.yaml does not reach per-RS mover pods.
