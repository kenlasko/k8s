---
title: Claude workers report a failed push or PR instead of claiming the work is complete
author: Ken
date: 2026-11-03
branch: main
cost: { minutes: 5, tokens: 43012 }
id: l-a4e926f3
scope: repo
status: active
src: agent
touches:
  - manifests/apps/claude-workers/base/worker.sh
  - README.md
---

## Decided
The worker checks whether the push and the PR creation worked. If either fails, it labels the issue claude-failed, posts the real git or GitHub error with Claude's summary, and keeps the worktree so the commits can be recovered. The cause that prompted this: the fine-grained PAT had no Workflows permission, so GitHub rejected every push that touched .github/workflows/. Monize's Bearer-exception renewals always edit ci.yml, so they failed twice (issues 1877 and 1994). Each time the worker still posted "Work complete" with an empty PR link.

## Tried and ruled out
Recovering the unpushed commits by kubectl exec into the worker pod: blocked by the auto-mode classifier, so the work was redone by hand.

## Watch out
worker.sh runs with `set -uo pipefail` and no `-e`, so a failed command does not stop it; check each result yourself. When testing handle_result with stubbed helpers, stub build_pr_body too: an unbound PR_BODY aborts the command substitution before gh runs, which looks like a gh failure with no output.

In the code: manifests/apps/claude-workers/base/worker.sh (fail_publish, handle_result, the fix-round push); the PAT note in base/external-secrets.yaml and README.md step 3. The rejection reads "refusing to allow a Personal Access Token to create or update workflow ... without `workflow` scope"; find it with `kubectl -n claude-workers logs <pod> --all-containers | grep -i refusing`.
