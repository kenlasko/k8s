---
title: Claude workers claim issues with a Kubernetes Lease per issue instead of splitting them by issue number
author: Ken
date: 2026-11-15
branch: claude-workers-lease-claims
cost: { minutes: 7, tokens: 72916 }
id: l-8dd2d90b
scope: repo
status: active
src: agent
touches:
  - manifests/apps/claude-workers/base/worker.sh
  - manifests/apps/claude-workers/base/rbac.yaml
---

## Decided
Any idle claude-worker takes the oldest queued issue. It claims it by creating a coordination.k8s.io Lease named issue-<owner>-<repo>-<number> in the claude-workers namespace; create fails with AlreadyExists for everyone but the first worker, so it is an atomic claim. Ken asked for this (2026-11-14) after issue #2186 waited behind #2141 on claude-worker-2 while workers 0 and 1 sat idle: the old `issue number % WORKER_COUNT` split had no work stealing.
The Lease's holder keeps it while it has local state for the issue (question, watched PR, sub-issue sequence), so resumes, PR fixes and claude-stop still land on the pod with the session. It is released between tasks once that state is gone. Leases are never taken over: StatefulSet pods come back under the same name.
After claiming, the worker re-checks the issue still has the trigger label, because another worker may have finished it and released the Lease between the list and the claim.

## Tried and ruled out
Claim comments on the issue (post, re-read, earliest wins): no cluster change needed, but every claim leaves comments behind and losers must delete theirs. A label swap alone is not atomic on GitHub, so it can't be the claim.

## Watch out
Unleased claude-wip issues from before the switch are adopted only by the pod the old modulo split gave them to; any pod adopting them at startup would break a sub-issue sequence parent whose state lives on another pod that hasn't adopted its leases yet. Remove that fallback (owns_wip) and WORKER_COUNT once nothing from before leases is in flight.
During a rolling update, old (modulo) and new (lease) pods run side by side for a few minutes, and an issue queued in that window can be started twice.
This is the workers' only write permission; Claude's runs share the pod token, so they can touch these Leases too.

In the code:
- manifests/apps/claude-workers/base/worker.sh: "Issue leases" section (claim_lease, claim_issue, release_idle_leases, adopt_local_state, owns_wip), stop_sweep, startup recovery, main poll loop
- manifests/apps/claude-workers/base/rbac.yaml: Role claude-worker-issue-leases
- `kubectl -n claude-workers get lease -L claude-workers/holder`
