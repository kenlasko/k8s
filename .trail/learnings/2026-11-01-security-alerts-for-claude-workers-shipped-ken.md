---
title: Security alerts for Claude workers shipped with known parsing gaps; the Alerts line can fail without any warning
author: Ken
date: 2026-11-01
branch: main
cost: { minutes: 10, tokens: 178587 }
id: l-714eec7d
scope: repo
status: active
src: agent
touches:
  - manifests/apps/claude-workers/README.md
  - manifests/apps/claude-workers/base/env-vars.yaml
  - manifests/apps/claude-workers/base/worker.sh
  - manifests/apps/monize/README.md
  - manifests/apps/monize/overlays/home/cronjob-build.yaml
  - manifests/apps/monize/overlays/home/rbac-build.yaml
  - scripts/monize-build.sh
  - manifests/media/media-config/base/cronjob-app-backup.yaml
  - manifests/apps/mealie/base/values.yaml
  - manifests/system/registry/base/cronjob-prune-cache.yaml
---

## Decided
- Shipped the security-alert prompt feature before fixing the review's findings, at Ken's request. Explicit alert mentions, alert URLs and GHSA/CVE IDs work; the gaps are in the "Alerts:" line and in what the review session sees.

## Watch out
- Issue bodies from GitHub's web editor usually have CRLF line endings. The trailing \r stops the "Alerts: all" line matching, so no alerts are fetched and nothing is logged. Strip \r before parsing.
- The code-review session builds its issue text from title and body only, so alerts named in the trusted user's comments don't reach the reviewer.
- The mention pattern also matches prose like "merge the dependabot 3 PRs", which fetches an unrelated alert #3.
- Markdown forms like "**Alerts:** all" or "- Alerts: dependabot" aren't recognised, and only the first Alerts line counts.
- "Alerts: all" reads one page of 100, so the "left out" count is low on repos with more open alerts.
- trail check flags the "no GitHub credentials" rule line against the discussions learning. That's a keyword match, not a real conflict.

In the code:
- manifests/apps/claude-workers/base/worker.sh: linked_alerts() and alert_text(); review prompt in run_review(); MAX_ALERTS in env-vars.yaml
