---
title: "Security alerts for Claude workers: how issue text is parsed, and why"
author: Ken
date: 2026-11-01
branch: main
cost: { minutes: 3, tokens: 28393 }
id: l-cb84c028
scope: repo
status: active
replaces: l-714eec7d
src: agent
touches:
  - manifests/apps/claude-workers/base/worker.sh
---

## Decided
- The worker reads alert references from the issue body, the trusted user's comments and a sub-issue's parent body, and the code review gets the same set. The review reuses what the run fetched during the same poll, so alerts aren't fetched twice.
- A mention needs the word "alert" ("Dependabot alert #12"). Without it, prose like "merge the dependabot 3 PRs" pulled in unrelated alert #3.
- "Alerts:" lines are matched after removing Markdown list markers, quotes and bold, and every such line counts, not just the first.
- "Alerts: all" pages through every open alert, so the "left out" count is right. An alert reached more than once (by a mention, a list and its GHSA ID) is counted once, whether it was included or left out.

## Watch out
- Issue bodies from GitHub's web editor have CRLF line endings. Strip \r before matching anything line-based, or the "Alerts:" line silently never matches.
- The bulk code scanning list includes rule help and full_description, the same as a single-alert fetch. The review suggested otherwise; I checked and it doesn't need a separate fetch.
- In the per-alert TSV, an empty field would collapse because tab counts as whitespace in IFS, so "no GHSA" is written as "-".
- trail check flags the "no GitHub credentials" rule line against the discussions learning. That's a keyword match, not a real conflict.

In the code:
- manifests/apps/claude-workers/base/worker.sh: ALERT_JQ, linked_alerts(), issue_text(), set_linked_context() (LINKED_FOR/LINKED_CONTEXT, reset every poll), used by start_task and run_review
