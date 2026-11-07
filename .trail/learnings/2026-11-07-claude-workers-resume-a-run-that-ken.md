---
title: Claude workers resume a run that hits the turn limit and keep unfinished work in a draft PR instead of deleting it
author: Ken
date: 2026-11-07
branch: main
cost: { minutes: 1, tokens: 2015 }
id: l-7f39269f
scope: repo
status: active
src: agent
touches:
  - manifests/apps/claude-workers/base/worker.sh
  - README.md
---

## Decided
Resume a run that uses up MAX_TURNS in the same session with another MAX_TURNS, up to MAX_TURN_CONTINUES (2) times per finish_run, because a big issue (backend + frontend + 18 locales) can outrun one run. When a run still ends without STATUS: DONE, commit the leftovers (Claude first, then the worker as a WIP commit with --no-verify), push them, open a draft PR and label the issue claude-failed. Re-adding the claude label while that draft PR is open carries on from its branch; closing the draft starts over. Claude is also told to commit as it goes. Why: issue 2050 hit 251 turns twice with nothing committed. The no-commits path ran cleanup (worktree remove --force), deleting about 1.5 h of tested work each time, and the retry rebuilt it from scratch.

## Tried and ruled out
Only raising MAX_TURNS: a big enough issue still runs out, and any uncommitted work is lost again.

## Watch out
Before this change, commits with any STATUS (including CANNOT_COMPLETE or none) opened a normal PR and posted "Work complete", which could auto-merge. Now only STATUS: DONE does, and unfinished work is never reviewed or watched. The summary request after a stopped run used to say "Do not make any more changes", which is what kept the work uncommitted. It now allows 10 turns so Claude can commit.

In the code: manifests/apps/claude-workers/base/worker.sh: hit_turn_limit, continue_turn_limit, finish_run, commit_leftovers, publish_unfinished, the carry_on block in start_task, gh pr ready in the DONE path; MAX_TURN_CONTINUES in base/env-vars.yaml; "Unfinished runs" in README.md.
