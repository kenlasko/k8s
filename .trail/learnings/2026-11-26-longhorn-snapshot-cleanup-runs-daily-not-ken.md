---
title: "Longhorn snapshot cleanup runs daily, not hourly; snapshot-delete job dropped"
author: Ken
date: 2026-11-26
branch: main
id: l-1ebabba1
scope: repo
status: active
src: agent
touches:
  - manifests/apps/claude-workers/image/Dockerfile
  - manifests/system/longhorn/base/longhorn-vol-management.yaml
  - manifests/apps/claude-workers/base/statefulset.yaml
---

## Decided
The snapshot-cleanup recurring job runs once a day. The snapshot-delete job is removed. Both went hourly during testing in Nov 2024 and were never set back. snapshot-delete (retain 7) never deleted anything: volumes in the default group hold at most about 6 snapshots, because the 24-hour job retains 2 and auto-cleanup-recurring-job-backup-snapshot keeps 1 backup snapshot. Rebuild-generated snapshots are already handled by auto-cleanup-system-generated-snapshot.

## Tried and ruled out
Hourly cleanup as a fix for snapshot buildup. It doesn't help: the buildup came from orphaned snapshots that no retention rule covers.

## Watch out
- restoreVolumeRecurringJobs=true creates restored-recurring-job-<hash> jobs when a volume is restored from backup. Their restored-* snapshots carry that job's label, so the 24-hour job's retention never removes them. Once that restored job is gone, the snapshots stay forever. Delete them by hand after a restore.
- When a volume leaves the default group (as the claude-worker workspaces did), its existing 24-hour/default/restored snapshots become orphans. Delete them by hand.
- A purge fails with "cannot purge snapshots because <replica> is rebuilding" if it runs during a rebuild. A replica can also report this after its rebuild has finished, even while the engine shows it RW. Deleting that replica so it rebuilds fresh clears it.
- A removed snapshot whose child is volume-head can't be purged until another snapshot is taken.

In the code: manifests/system/longhorn/base/longhorn-vol-management.yaml (snapshot-cleanup cron "20 7 * * *"); manifests/apps/claude-workers/base/statefulset.yaml keeps the recurring-job.longhorn.io/snapshot-cleanup label, so the job must stay.
