#!/usr/bin/env bash
# Claude worker loop.
# Polls GitHub for open issues labelled $TRIGGER_LABEL and assigned to $ASSIGNEE, runs Claude Code headlessly against each one,
# then pushes the resulting branch and opens a PR that closes the issue.
#
# While Claude runs, a single progress comment on the issue is edited every $PROGRESS_INTERVAL seconds.
# If Claude needs input, its question is posted on the issue, the issue is labelled claude-question and the worker moves on.
# When $ASSIGNEE replies, the worker resumes the same Claude session (claude --resume) in the same worktree.
#
# Each StatefulSet replica only takes issues where (issue number % WORKER_COUNT) == its pod ordinal,
# so multiple workers never race for the same issue, and a resumed issue always lands on the pod holding its session.
set -uo pipefail

WORKER="${HOSTNAME}"
ORDINAL="${HOSTNAME##*-}"
REPO_ROOT=/workspace/repos         # one clone per repo, used as the base for worktrees
TREE_ROOT=/workspace/worktrees     # one git worktree per in-flight issue
STATE_ROOT=/workspace/state        # one JSON file per issue waiting on a question
LOG_ROOT=/workspace/logs
TRIGGER_LABEL="${TRIGGER_LABEL:-claude}"
ASSIGNEE="${ASSIGNEE:-}"
WORKER_COUNT="${WORKER_COUNT:-1}"
POLL_INTERVAL="${POLL_INTERVAL:-120}"
PROGRESS_INTERVAL="${PROGRESS_INTERVAL:-60}"
QUESTION_TIMEOUT_DAYS="${QUESTION_TIMEOUT_DAYS:-7}"
MAX_TURNS="${MAX_TURNS:-100}"
TASK_TIMEOUT="${TASK_TIMEOUT:-2h}"
# Every comment the worker posts starts with this marker, so they are never mistaken for replies
# (the GitHub token may belong to the same account as ASSIGNEE).
BOT="🤖"

RULES="How to work:
- You are running unattended. Nobody can answer you mid-run, and interactive prompts are disabled.
- Commit your work on the current branch with clear commit messages. Do NOT push, open PRs, or switch branches; that is handled for you.
- Run whatever lint/tests the repo provides before finishing.
- You have read-only kubectl access to the cluster if you need to inspect live state.
- Ask questions freely: whenever there is a meaningful choice (design, scope, naming, behaviour, or anything ambiguous in the issue), stop and ask instead of guessing. Commit any work in progress first. Your run ends when you ask; the question is posted on the GitHub issue and you will be resumed in this same session with the answer.
- End your final message with exactly one of these lines:
  STATUS: DONE             (work is complete and committed; the rest of your message becomes the PR description)
  STATUS: QUESTION         (the rest of your message is your question(s): numbered, with options and your recommendation where useful)
  STATUS: CANNOT_COMPLETE  (explain why)"

log() { echo "$(date -Is) [${WORKER}] $*"; }

stopping=0
trap 'stopping=1; log "SIGTERM received, will exit after the current task"' TERM

for v in CLAUDE_CODE_OAUTH_TOKEN GH_TOKEN REPOS ASSIGNEE; do
  if [[ -z "${!v:-}" ]]; then log "ERROR: ${v} is not set"; exit 1; fi
done

mkdir -p "${HOME}" "${REPO_ROOT}" "${TREE_ROOT}" "${STATE_ROOT}" "${LOG_ROOT}"
git config --global credential.https://github.com.helper '!gh auth git-credential'
git config --global init.defaultBranch main

for repo in ${REPOS}; do
  gh label create "${TRIGGER_LABEL}" --repo "${repo}" --color 7057ff --description "Queue this issue for a Claude worker" >/dev/null 2>&1
  gh label create claude-wip      --repo "${repo}" --color fbca04 --description "A Claude worker is on it" >/dev/null 2>&1
  gh label create claude-question --repo "${repo}" --color 1d76db --description "Claude is waiting for an answer" >/dev/null 2>&1
  gh label create claude-done     --repo "${repo}" --color 0e8a16 --description "Claude worker opened a PR" >/dev/null 2>&1
  gh label create claude-failed   --repo "${repo}" --color d93f0b --description "Claude worker could not complete this" >/dev/null 2>&1
done

# --- GitHub helpers ---------------------------------------------------------

post_comment() { # repo num body -> prints comment id
  gh api "repos/$1/issues/$2/comments" -f body="$3" --jq .id
}

edit_comment() { # repo comment-id body
  [[ -n "$2" ]] && gh api -X PATCH "repos/$1/issues/comments/$2" -f body="$3" >/dev/null
}

relabel() { # repo num from-label to-label
  gh issue edit "$2" --repo "$1" --remove-label "$3" --add-label "$4" >/dev/null
}

# --- Worktree / state helpers -----------------------------------------------

key_for() { echo "${1//\//_}-$2"; } # repo num -> filesystem-safe key

cleanup() { # repo num branch
  local clone="${REPO_ROOT}/$1" key
  key=$(key_for "$1" "$2")
  git -C "${clone}" worktree remove --force "${TREE_ROOT}/${key}" >/dev/null 2>&1
  rm -rf "${TREE_ROOT:?}/${key}"
  git -C "${clone}" worktree prune >/dev/null 2>&1
  git -C "${clone}" branch -D "$3" >/dev/null 2>&1
  rm -f "${STATE_ROOT}/${key}.json"
}

# --- Progress reporting ------------------------------------------------------

progress_body() { # stream-json log, status text
  local logfile=$1 status=$2 calls narration actions
  calls=$(jq -Rn '[inputs | fromjson? | select(.type=="assistant") | .message.content[]? | select(.type=="tool_use")] | length' "${logfile}" 2>/dev/null)
  narration=$(jq -Rrn '[inputs | fromjson? | select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text] | last // "" | .[0:500]' "${logfile}" 2>/dev/null | sed 's/^/> /')
  actions=$(jq -Rrn '[inputs | fromjson? | select(.type=="assistant") | .message.content[]? | select(.type=="tool_use")
      | "- **\(.name)** " + ((.input.description // .input.command // .input.file_path // .input.pattern // .input.url // .input.prompt // "")
      | tostring | gsub("[`\n]"; " ") | .[0:120])] | .[-8:] | .[]' "${logfile}" 2>/dev/null)
  printf '%s **%s** on `%s` · %s tool calls · updated %s\n\n%s\n\n**Recent actions**\n%s' \
    "${BOT}" "${status}" "${WORKER}" "${calls:-0}" "$(date -u +'%Y-%m-%d %H:%M UTC')" "${narration}" "${actions:-_none yet_}"
}

# Runs Claude in the background while keeping the progress comment up to date.
# Sets RESULT_LOG, PROGRESS_ID and RC for handle_result.
run_claude() { # repo num worktree prompt [session-id-to-resume]
  local repo=$1 num=$2 dir=$3 prompt=$4 resume=${5:-}
  RESULT_LOG="${LOG_ROOT}/$(key_for "${repo}" "${num}")-$(date +%Y%m%d-%H%M%S).jsonl"
  local args=(-p --output-format stream-json --verbose --max-turns "${MAX_TURNS}"
    --dangerously-skip-permissions --disallowedTools AskUserQuestion)
  [[ -n "${resume}" ]] && args+=(--resume "${resume}")

  PROGRESS_ID=$(post_comment "${repo}" "${num}" "${BOT} **Starting** on \`${WORKER}\`…")
  log "Running Claude on ${repo}#${num}${resume:+ (resuming ${resume})} (log: ${RESULT_LOG})"

  ( cd "${dir}" && printf '%s' "${prompt}" | timeout "${TASK_TIMEOUT}" claude "${args[@]}" ) \
    > "${RESULT_LOG}" 2> "${RESULT_LOG%.jsonl}.err" &
  local pid=$!
  while kill -0 "${pid}" 2>/dev/null; do
    sleep "${PROGRESS_INTERVAL}" & wait $!
    kill -0 "${pid}" 2>/dev/null && edit_comment "${repo}" "${PROGRESS_ID}" "$(progress_body "${RESULT_LOG}" Working)"
  done
  wait "${pid}"
  RC=$?
}

# Decides what to do once a Claude run ends: open a PR, post a question, or give up.
handle_result() { # repo num branch base
  local repo=$1 num=$2 branch=$3 base=$4
  local key dir res summary sid stats status commits
  key=$(key_for "${repo}" "${num}")
  dir="${TREE_ROOT}/${key}"

  res=$(jq -Rcn '[inputs | fromjson? | select(.type=="result")] | last // {}' "${RESULT_LOG}")
  sid=$(jq -Rrn '[inputs | fromjson? | .session_id? // empty] | last // ""' "${RESULT_LOG}")
  summary=$(jq -r '.result // ""' <<<"${res}")
  stats=$(jq -r '"\(.num_turns // "?") turns, \((.duration_ms // 0) / 60000 | floor) min" + (if (.subtype // "success") != "success" then ", \(.subtype)" else "" end)' <<<"${res}")
  status=$(grep -oE '^STATUS: (DONE|QUESTION|CANNOT_COMPLETE)' <<<"${summary}" | tail -n1 | cut -d' ' -f2)
  summary=$(grep -vE '^STATUS: ' <<<"${summary}")
  [[ -z "${summary}" ]] && summary="(no summary returned, exit code ${RC})"
  commits=$(git -C "${dir}" rev-list --count "origin/${base}..HEAD" 2>/dev/null || echo 0)
  log "Claude finished ${repo}#${num}: status=${status:-none} rc=${RC} commits=${commits} (${stats})"

  if [[ "${status}" == "QUESTION" && -n "${sid}" ]]; then
    edit_comment "${repo}" "${PROGRESS_ID}" "$(progress_body "${RESULT_LOG}" 'Paused: waiting for your answer')"
    relabel "${repo}" "${num}" claude-wip claude-question
    post_comment "${repo}" "${num}" "$(printf '%s **Question from `%s`**\n\n%s\n\n---\n_Reply in a comment and I will resume where I left off. Only replies from @%s count. No reply within %s days and I will give up._' \
      "${BOT}" "${WORKER}" "${summary}" "${ASSIGNEE}" "${QUESTION_TIMEOUT_DAYS}")" >/dev/null
    # asked_at is recorded after posting, so only comments made after the question count as answers
    jq -n --arg repo "${repo}" --arg num "${num}" --arg branch "${branch}" --arg base "${base}" \
      --arg sid "${sid}" --arg asked "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{repo: $repo, num: ($num | tonumber), branch: $branch, base: $base, session_id: $sid, asked_at: $asked}' \
      > "${STATE_ROOT}/${key}.json"
    return
  fi

  if (( commits > 0 )); then
    edit_comment "${repo}" "${PROGRESS_ID}" "$(progress_body "${RESULT_LOG}" "Finished (${stats})")"
    git -C "${dir}" push -q --force -u origin "${branch}"
    local title pr
    title=$(gh issue view "${num}" --repo "${repo}" --json title --jq .title)
    pr=$(gh pr view "${branch}" --repo "${repo}" --json url --jq .url 2>/dev/null)
    if [[ -z "${pr}" ]]; then
      pr=$(gh pr create --repo "${repo}" --base "${base}" --head "${branch}" --title "${title}" \
        --body "$(printf 'Closes #%s\n\n%s\n\n---\n_Generated by `%s` using Claude Code (%s)_' "${num}" "${summary}" "${WORKER}" "${stats}")")
    fi
    relabel "${repo}" "${num}" claude-wip claude-done
    post_comment "${repo}" "${num}" "${BOT} \`${WORKER}\` opened ${pr}" >/dev/null
  else
    edit_comment "${repo}" "${PROGRESS_ID}" "$(progress_body "${RESULT_LOG}" "Stopped (${stats})")"
    relabel "${repo}" "${num}" claude-wip claude-failed
    post_comment "${repo}" "${num}" "$(printf '%s `%s` made no commits (status: %s, exit code %s).\n\n%s' \
      "${BOT}" "${WORKER}" "${status:-none}" "${RC}" "${summary}")" >/dev/null
  fi
  cleanup "${repo}" "${num}" "${branch}"
}

# --- Task entry points -------------------------------------------------------

start_task() { # repo num
  local repo=$1 num=$2
  local clone="${REPO_ROOT}/${repo}" branch="claude/issue-${num}" key base dir
  key=$(key_for "${repo}" "${num}")
  dir="${TREE_ROOT}/${key}"

  log "Claiming ${repo}#${num}"
  relabel "${repo}" "${num}" "${TRIGGER_LABEL}" claude-wip || return 1

  if [[ ! -d "${clone}/.git" ]] && ! gh repo clone "${repo}" "${clone}" -- -q; then
    relabel "${repo}" "${num}" claude-wip claude-failed
    post_comment "${repo}" "${num}" "${BOT} \`${WORKER}\` could not clone \`${repo}\`." >/dev/null
    return 1
  fi
  base=$(gh repo view "${repo}" --json defaultBranchRef --jq .defaultBranchRef.name)

  # A re-queued issue starts over: drop any earlier worktree or pending question
  cleanup "${repo}" "${num}" "${branch}"
  git -C "${clone}" fetch -q --prune origin
  if ! git -C "${clone}" worktree add -q -f -B "${branch}" "${dir}" "origin/${base}"; then
    relabel "${repo}" "${num}" claude-wip claude-failed
    post_comment "${repo}" "${num}" "${BOT} \`${WORKER}\` could not create a worktree for \`${branch}\`." >/dev/null
    return 1
  fi

  local issue
  issue=$(gh issue view "${num}" --repo "${repo}" --json title,body,comments \
    --jq '"# " + .title + "\n\n" + (.body // "") + "\n\n" + ([.comments[] | "---\nComment from " + .author.login + ":\n" + .body] | join("\n\n"))')

  run_claude "${repo}" "${num}" "${dir}" "You are working in a git worktree of ${repo} on branch ${branch}. Resolve GitHub issue #${num}, shown below.

${RULES}

Issue #${num}:
${issue}"
  handle_result "${repo}" "${num}" "${branch}" "${base}"
}

# Checks a waiting issue for an answer. Returns 0 only if Claude was run.
resume_task() { # state-file
  local sf=$1 repo num branch base sid asked info
  repo=$(jq -r .repo "${sf}"); num=$(jq -r .num "${sf}"); branch=$(jq -r .branch "${sf}")
  base=$(jq -r .base "${sf}"); sid=$(jq -r .session_id "${sf}"); asked=$(jq -r .asked_at "${sf}")

  info=$(gh issue view "${num}" --repo "${repo}" --json state,labels,comments 2>/dev/null) || return 1
  if [[ $(jq -r .state <<<"${info}") != "OPEN" ]] || ! jq -e '.labels | any(.name == "claude-question")' <<<"${info}" >/dev/null; then
    log "${repo}#${num} was closed or un-labelled while waiting; dropping it"
    cleanup "${repo}" "${num}" "${branch}"
    return 1
  fi

  local replies
  replies=$(jq -r --arg who "${ASSIGNEE}" --arg asked "${asked}" --arg bot "${BOT}" \
    '[.comments[] | select(.author.login == $who and .createdAt > $asked and (.body | startswith($bot) | not)) | .body] | join("\n\n---\n\n")' <<<"${info}")

  if [[ -z "${replies}" ]]; then
    if (( $(date +%s) - $(date -d "${asked}" +%s) > QUESTION_TIMEOUT_DAYS * 86400 )); then
      log "${repo}#${num}: no answer in ${QUESTION_TIMEOUT_DAYS} days, giving up"
      relabel "${repo}" "${num}" claude-question claude-failed
      post_comment "${repo}" "${num}" "${BOT} No answer within ${QUESTION_TIMEOUT_DAYS} days, so \`${WORKER}\` has dropped this. Re-add the \`${TRIGGER_LABEL}\` label to start over." >/dev/null
      cleanup "${repo}" "${num}" "${branch}"
    fi
    return 1
  fi

  log "${repo}#${num}: answer received, resuming session ${sid}"
  relabel "${repo}" "${num}" claude-question claude-wip
  run_claude "${repo}" "${num}" "${TREE_ROOT}/$(key_for "${repo}" "${num}")" "@${ASSIGNEE} replied on the issue:

${replies}

Continue the task with this answer. The same rules apply, including ending with a STATUS line.

${RULES}" "${sid}"
  handle_result "${repo}" "${num}" "${branch}" "${base}"
  return 0
}

# --- Main loop ---------------------------------------------------------------

log "Worker ${ORDINAL}/${WORKER_COUNT} started, watching issues assigned to ${ASSIGNEE} in: ${REPOS}"

# Recover from a restart mid-task: anything still claude-wip in this shard is no longer running.
for repo in ${REPOS}; do
  for num in $(gh issue list --repo "${repo}" --label claude-wip --assignee "${ASSIGNEE}" --state open --limit 100 --json number \
      --jq ".[] | select(.number % ${WORKER_COUNT} == ${ORDINAL}) | .number" 2>/dev/null); do
    if [[ -f "${STATE_ROOT}/$(key_for "${repo}" "${num}").json" ]]; then
      log "${repo}#${num} was interrupted while resuming; back to waiting on its question"
      relabel "${repo}" "${num}" claude-wip claude-question
    else
      log "${repo}#${num} was interrupted; re-queueing"
      relabel "${repo}" "${num}" claude-wip "${TRIGGER_LABEL}"
      post_comment "${repo}" "${num}" "${BOT} \`${WORKER}\` restarted mid-task, so this has been re-queued." >/dev/null
    fi
  done
done

while (( ! stopping )); do
  did_work=0
  # Answered questions first, so paused work is picked back up before new issues
  for sf in "${STATE_ROOT}"/*.json; do
    [[ -e "${sf}" ]] || continue
    if resume_task "${sf}"; then did_work=1; break; fi
  done
  if (( ! did_work )); then
    for repo in ${REPOS}; do
      num=$(gh issue list --repo "${repo}" --label "${TRIGGER_LABEL}" --assignee "${ASSIGNEE}" --state open --limit 100 --json number \
        --jq ".[] | select(.number % ${WORKER_COUNT} == ${ORDINAL}) | .number" 2>/dev/null | tail -n1)
      if [[ -n "${num}" ]]; then
        start_task "${repo}" "${num}"
        did_work=1
        break
      fi
    done
  fi
  (( stopping )) && break
  # Background sleep + wait so SIGTERM interrupts idle polling immediately
  (( did_work )) || { sleep "${POLL_INTERVAL}" & wait $!; }
done
log "Worker stopped"
