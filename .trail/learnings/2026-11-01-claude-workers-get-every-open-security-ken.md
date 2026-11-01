---
title: "Claude workers get every open security alert in a file before each run, because matching the issue's wording missed real requests"
author: Ken
date: 2026-11-01
branch: main
cost: { minutes: 7, tokens: 21921 }
id: l-76647625
scope: repo
status: active
src: agent
touches:
  - manifests/apps/claude-workers/README.md
  - manifests/apps/claude-workers/base/worker.sh
---

## Decided
- Before every Claude run (fresh start, resumed question, PR fix round, review), the worker writes all of the repo's open Dependabot and code scanning alerts to a file outside the worktree and names it in the prompt. Claude reads it when the task involves alerts.
- The pattern-based inline alerts stay, for alerts an issue names explicitly.

## Tried and ruled out
- Relying only on the issue naming alerts in fixed patterns. Issue #1982 said "the two code scanning and dependabot alerts recently found", which matched nothing. And alerts were only added at a fresh start and at the review, so a reply on the issue didn't reach them either. More patterns would still miss plain wording, and "dependabot" plus a number also appears in ordinary prose.

## Watch out
- If the alerts can't be read, the file is removed rather than left stale, and a warning is logged per alert kind.

In the code:
- manifests/apps/claude-workers/base/worker.sh: write_alerts_file(), called at the top of run_claude; ALERTS_ROOT=/workspace/alerts, one <owner>_<repo>.md per repo
