---
title: "Claude workers get linked GitHub Discussions from the worker, because Claude has no GitHub access of its own"
author: Ken
date: 2026-10-31
branch: main
cost: { minutes: 4, tokens: 134049 }
id: l-41a38f08
scope: repo
status: active
src: agent
touches:
  - manifests/apps/claude-workers/base/worker.sh
---

## Decided
- The worker, not Claude, fetches discussions that an issue links to and puts them in the prompt as untrusted reference material. Claude gave up on issue #1970 because its rules say it has no GitHub credentials and that everything it needs is given to it, and back then linked discussions never were. It didn't try anything else and asked instead.
- A bare #N is looked up as a discussion too, since issues and discussions share one number sequence and issues often say just "#1955".

## Tried and ruled out
- Telling Claude to read public GitHub pages itself with curl: only works on public repos, relies on scraping HTML, and the content arrives with no "untrusted" framing. A review session did read #1955 this way, which is how we know the network allows it.

## Watch out
- gh api graphql exits non-zero on any GraphQL error but still prints the JSON response on stdout. A #N that is an issue comes back as an error of type NOT_FOUND and must be skipped quietly. Any other error type (e.g. a token without access) is a real problem.
- The worker's log/warn helpers print to stdout, so a function whose output is captured into the prompt must send them to stderr.
- A fine-grained PAT reads discussions on public repos without the Discussions permission. Private repos need Discussions: read.
- Discussions are often opened by other people (#1955 was), so fetching them reopens the prompt-injection path that the trusted-user rule closes for issue comments. The labelling reduces that risk but doesn't remove it.

In the code:
- manifests/apps/claude-workers/base/worker.sh: linked_discussions(), used in start_task and run_review prompts; MAX_DISCUSSIONS (5) in env-vars.yaml
