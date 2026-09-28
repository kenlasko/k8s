#!/usr/bin/env bash
# Claude worker loop.
# Polls GitHub for open issues labelled $TRIGGER_LABEL and assigned to $ASSIGNEE, runs Claude Code headlessly against each one,
# then pushes the resulting branch and opens a PR that closes the issue.
#
# While Claude runs, a single progress comment is edited every $PROGRESS_INTERVAL seconds.
# If Claude needs input, its question is posted on the issue, the issue is labelled claude-question and the worker moves on.
# When $ASSIGNEE replies, the worker resumes the same Claude session (claude --resume) in the same worktree.
#
# Once a PR is open the issue is labelled claude-pr and the worker watches the PR until it is merged or closed.
# Failing checks, merge conflicts and review feedback from $ASSIGNEE are handed back to the same Claude session,
# and the fix is pushed. After $MAX_FIX_ROUNDS automatic rounds it waits for $ASSIGNEE to reply before continuing.
#
# Each StatefulSet replica only takes issues where (issue number % WORKER_COUNT) == its pod ordinal,
# so multiple workers never race for the same issue, and a resumed issue always lands on the pod holding its session.
set -uo pipefail

WORKER="${HOSTNAME}"
ORDINAL="${HOSTNAME##*-}"
REPO_ROOT=/workspace/repos         # one clone per repo, used as the base for worktrees
TREE_ROOT=/workspace/worktrees     # one git worktree per in-flight issue
STATE_ROOT=/workspace/state        # one JSON file per issue waiting on a question or a PR
LOG_ROOT=/workspace/logs
WORKER_LOG="${LOG_ROOT}/worker.log"  # copy of everything logged to stdout, read by claude-log / claude-status
STATUS_FILE=/workspace/status.json # what this worker is doing right now, read by claude-status
EVENTS_JQ="$(dirname "$(readlink -f "$0")")/events.jq"
LOG_FORMAT="${LOG_FORMAT:-json}"   # json (one object per line, for Loki) or text
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-14}"
TRIGGER_LABEL="${TRIGGER_LABEL:-claude}"
ASSIGNEE="${ASSIGNEE:-}"
WORKER_COUNT="${WORKER_COUNT:-1}"
POLL_INTERVAL="${POLL_INTERVAL:-120}"
PROGRESS_INTERVAL="${PROGRESS_INTERVAL:-60}"
QUESTION_TIMEOUT_DAYS="${QUESTION_TIMEOUT_DAYS:-7}"
MAX_FIX_ROUNDS="${MAX_FIX_ROUNDS:-3}"
MAX_TURNS="${MAX_TURNS:-250}"
MAX_CONTINUES="${MAX_CONTINUES:-2}"
TASK_TIMEOUT="${TASK_TIMEOUT:-2h}"
# Every comment the worker posts starts with this marker, so they are never mistaken for replies
# (the GitHub token may belong to the same account as ASSIGNEE).
BOT="🤖"

RULES="How to work:
- You are running unattended. Nobody can answer you mid-run, and interactive prompts are disabled.
- Commit your work on the current branch with clear commit messages. Do NOT push, open PRs, or switch branches; that is handled for you.
- Run whatever lint/tests the repo provides before finishing.
- Never end your turn to wait for something, and never run commands in the background: your run ends the moment you stop, and anything still running is lost. Run long commands (tests, coverage, builds) in the foreground with a long timeout and wait for them to finish.
- You have read-only kubectl access to the cluster if you need to inspect live state.
- Ask questions freely: whenever there is a meaningful choice (design, scope, naming, behaviour, or anything ambiguous), stop and ask instead of guessing. Commit any work in progress first. Your run ends when you ask; the question is posted on GitHub and you will be resumed in this same session with the answer.
- Your final message is posted on GitHub, so always write one, even if you are unsure whether the work is complete.
- End your final message with exactly one of these lines:
  STATUS: DONE             (work is complete and committed; the rest of your message is a summary of what you changed, written as described below)
  STATUS: QUESTION         (the rest of your message is your question(s): numbered, with options and your recommendation where useful)
  STATUS: CANNOT_COMPLETE  (explain why)"

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# --- Logging -------------------------------------------------------------------
# Every line goes to stdout (kubectl logs, Loki) and to WORKER_LOG. With LOG_FORMAT=json each line is an object:
#   {ts, level, worker, ref, repo, issue, source: worker|claude, event, tool?, msg}
# CUR_REF is the issue currently being handled (owner/repo#number), empty when idle.
CUR_REF=""
mkdir -p "${LOG_ROOT}"

log_event() { # level event message
  local line
  if [[ "${LOG_FORMAT}" == "json" ]]; then
    line=$(jq -nc --arg ts "$(now_iso)" --arg level "$1" --arg worker "${WORKER}" --arg ref "${CUR_REF}" \
      --arg event "$2" --arg msg "$3" \
      '{ts: $ts, level: $level, worker: $worker, ref: $ref, repo: ($ref | split("#")[0]), issue: ($ref | split("#")[1] // ""),
        source: "worker", event: $event, msg: $msg}')
  else
    line="$(now_iso) ${WORKER} ${CUR_REF:--} $([[ "$1" == "warn" ]] && echo "⚠️ " || echo "ℹ️ ")$3"
  fi
  printf '%s\n' "${line}"
  printf '%s\n' "${line}" >> "${WORKER_LOG}"
}
log()  { log_event info worker "$*"; }
warn() { log_event warn worker "$*"; }
event() { local e=$1; shift; log_event info "${e}" "$*"; } # event name for filtering, e.g. pr_opened

set_status() { # state [phase]
  jq -n --arg worker "${WORKER}" --arg state "$1" --arg ref "${CUR_REF}" --arg phase "${2:-}" \
    --arg since "$(now_iso)" --arg log "${RESULT_LOG:-}" \
    '{worker: $worker, state: $state, ref: $ref, phase: $phase, since: $since, log: $log}' > "${STATUS_FILE}.tmp" \
    && mv -f "${STATUS_FILE}.tmp" "${STATUS_FILE}"
}

rotate_logs() {
  if (( $(stat -c %s "${WORKER_LOG}" 2>/dev/null || echo 0) > 20 * 1024 * 1024 )); then
    mv -f "${WORKER_LOG}" "${WORKER_LOG}.1"
  fi
  find "${LOG_ROOT}" -maxdepth 1 \( -name '*.jsonl' -o -name '*.err' \) -mtime +"${LOG_RETENTION_DAYS}" -delete 2>/dev/null
}

stopping=0
trap 'stopping=1; log "SIGTERM received, will exit after the current task"' TERM

for v in CLAUDE_CODE_OAUTH_TOKEN GH_TOKEN REPOS ASSIGNEE; do
  if [[ -z "${!v:-}" ]]; then warn "${v} is not set"; exit 1; fi
done

mkdir -p "${HOME}" "${REPO_ROOT}" "${TREE_ROOT}" "${STATE_ROOT}"
if [[ ! -f "${EVENTS_JQ}" ]]; then
  warn "${EVENTS_JQ} not found; Claude's activity will not be streamed to the log"
  EVENTS_JQ=""
fi
git config --global credential.https://github.com.helper '!gh auth git-credential'
git config --global init.defaultBranch main

for repo in ${REPOS}; do
  gh label create "${TRIGGER_LABEL}" --repo "${repo}" --color 7057ff --description "Queue this issue for a Claude worker" >/dev/null 2>&1
  gh label create claude-wip      --repo "${repo}" --color fbca04 --description "A Claude worker is on it" >/dev/null 2>&1
  gh label create claude-question --repo "${repo}" --color 1d76db --description "Claude is waiting for an answer" >/dev/null 2>&1
  gh label create claude-pr       --repo "${repo}" --color 5319e7 --description "Claude opened a PR and is watching it" >/dev/null 2>&1
  gh label create claude-done     --repo "${repo}" --color 0e8a16 --description "Claude's PR was merged" >/dev/null 2>&1
  gh label create claude-failed   --repo "${repo}" --color d93f0b --description "Claude worker could not complete this" >/dev/null 2>&1
done

# --- GitHub helpers ---------------------------------------------------------

post_comment() { # repo issue-or-pr-num body -> prints comment id
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

update_state() { # state-file jq-args... (applies a jq filter to the state file in place)
  local sf=$1 tmp
  shift
  tmp=$(jq "$@" "${sf}") && printf '%s\n' "${tmp}" > "${sf}"
}

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

# Runs Claude in the background while keeping a progress comment on issue/PR <num> up to date.
# Sets RESULT_LOG, PROGRESS_ID and RC.
run_claude() { # repo issue-or-pr-num worktree prompt [session-id-to-resume] [progress-comment-id-to-reuse]
  local repo=$1 num=$2 dir=$3 prompt=$4 resume=${5:-} reuse=${6:-}
  RESULT_LOG="${LOG_ROOT}/$(key_for "${repo}" "${num}")-$(date +%Y%m%d-%H%M%S).jsonl"
  local args=(-p --output-format stream-json --verbose --max-turns "${MAX_TURNS}"
    --dangerously-skip-permissions --disallowedTools AskUserQuestion)
  [[ -n "${resume}" ]] && args+=(--resume "${resume}")

  if [[ -n "${reuse}" ]]; then
    PROGRESS_ID="${reuse}"
    edit_comment "${repo}" "${PROGRESS_ID}" "${BOT} **Continuing** on \`${WORKER}\`…"
  else
    PROGRESS_ID=$(post_comment "${repo}" "${num}" "${BOT} **Starting** on \`${WORKER}\`…")
  fi
  event claude_start "Running Claude on ${repo}#${num}${CUR_PHASE:+ (${CUR_PHASE})}${resume:+, resuming session ${resume}}; transcript: ${RESULT_LOG}"
  set_status working "${CUR_PHASE:-}"

  # Raw stream-json goes to RESULT_LOG; events.jq turns it into readable log lines as it arrives.
  # tee -p keeps the transcript going even if the formatter dies.
  (
    cd "${dir}" || exit 1
    printf '%s' "${prompt}" | timeout "${TASK_TIMEOUT}" claude "${args[@]}" 2> "${RESULT_LOG%.jsonl}.err" \
      | tee -p "${RESULT_LOG}" \
      | if [[ -n "${EVENTS_JQ}" ]]; then
          jq -Rrc --unbuffered --arg format "${LOG_FORMAT}" --arg worker "${WORKER}" --arg ref "${CUR_REF}" \
            --arg root "${dir}" -f "${EVENTS_JQ}" | tee -a "${WORKER_LOG}"
        else
          cat > /dev/null
        fi
    exit "${PIPESTATUS[1]}"
  ) &
  local pid=$!
  while kill -0 "${pid}" 2>/dev/null; do
    sleep "${PROGRESS_INTERVAL}" & wait $!
    kill -0 "${pid}" 2>/dev/null && edit_comment "${repo}" "${PROGRESS_ID}" "$(progress_body "${RESULT_LOG}" Working)"
  done
  wait "${pid}"
  RC=$?
  if [[ -s "${RESULT_LOG%.jsonl}.err" ]]; then
    warn "Claude stderr: $(tail -n 5 "${RESULT_LOG%.jsonl}.err" | tr '\n' ' ' | cut -c1-500)"
  fi
  (( RC == 124 )) && warn "Claude run hit TASK_TIMEOUT (${TASK_TIMEOUT})"
  event claude_end "Claude exited with code ${RC}"
}

# Extracts the outcome of the last run_claude. Sets SID, SUMMARY, STATUS and STATS.
# If the run ended without a final message (e.g. it hit MAX_TURNS), the session is resumed briefly to ask for one.
parse_result() { # worktree
  local dir=$1 res subtype
  res=$(jq -Rcn '[inputs | fromjson? | select(.type=="result")] | last // {}' "${RESULT_LOG}")
  SID=$(jq -Rrn '[inputs | fromjson? | .session_id? // empty] | last // ""' "${RESULT_LOG}")
  subtype=$(jq -r '.subtype // "no result"' <<<"${res}")
  SUMMARY=$(jq -r '.result // ""' <<<"${res}")
  STATS=$(jq -r '"\(.num_turns // "?") turns, \((.duration_ms // 0) / 60000 | floor) min" + (if (.subtype // "success") != "success" then ", \(.subtype // "no result")" else "" end)' <<<"${res}")

  if [[ -z "${SUMMARY//[[:space:]]/}" && -n "${SID}" ]]; then
    warn "Run ended without a final message (${subtype}, exit code ${RC}); asking the session for a summary"
    SUMMARY=$( cd "${dir}" && printf '%s' "Your previous run stopped before you wrote a final message (reason: ${subtype}). Do not make any more changes. Reply with a concise summary of what you changed and anything left unfinished, ending with a STATUS line as instructed earlier." \
      | timeout 10m claude -p --resume "${SID}" --output-format json --max-turns 3 --dangerously-skip-permissions --disallowedTools AskUserQuestion \
          2>> "${RESULT_LOG%.jsonl}.err" | jq -r '.result // ""' 2>/dev/null )
  fi
  if [[ -z "${SUMMARY//[[:space:]]/}" ]]; then
    SUMMARY=$(jq -Rrn '[inputs | fromjson? | select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text] | last // ""' "${RESULT_LOG}")
  fi
  STATUS=$(grep -oE '^STATUS: (DONE|QUESTION|CANNOT_COMPLETE)' <<<"${SUMMARY}" | tail -n1 | cut -d' ' -f2)
  SUMMARY=$(grep -vE '^STATUS: ' <<<"${SUMMARY}")
  [[ -z "${SUMMARY//[[:space:]]/}" ]] && SUMMARY="_Claude returned no summary (${subtype}, exit code ${RC})._"
}

# parse_result, plus: if Claude stopped without a STATUS line (e.g. it ended its turn to "check back" on a
# background command), resume the session and tell it to finish, up to MAX_CONTINUES times.
finish_run() { # repo issue-or-pr-num worktree
  local attempt=0
  parse_result "$3"
  while [[ -z "${STATUS}" && -n "${SID}" ]] && (( attempt < MAX_CONTINUES )); do
    attempt=$((attempt + 1))
    warn "Run ended without a STATUS line; resuming it (${attempt}/${MAX_CONTINUES})"
    CUR_PHASE="continue ${attempt}/${MAX_CONTINUES}"
    run_claude "$1" "$2" "$3" "Your last message did not end with a STATUS line, so your run was treated as unfinished and you have been resumed.
Anything you started in the background during the previous run is no longer running and its output is lost.
If you were waiting on something (tests, coverage, a build), run it again now in the foreground and wait for it to finish.
Then commit your work and end your final message with a STATUS line as instructed earlier." "${SID}" "${PROGRESS_ID}"
    parse_result "$3"
  done
}

# --- PR template -----------------------------------------------------------------

# Prints the repo's pull request template, if it has one (the same locations GitHub checks).
# With a .github/PULL_REQUEST_TEMPLATE/ directory of several templates, the first one alphabetically is used.
find_pr_template() { # worktree
  local f
  f=$(find "$1/.github" "$1/docs" "$1" -maxdepth 1 -type f -iname 'pull_request_template.md' 2>/dev/null | sort | head -n1)
  [[ -z "${f}" ]] && f=$(find "$1/.github/PULL_REQUEST_TEMPLATE" -maxdepth 1 -type f -iname '*.md' 2>/dev/null | sort | head -n1)
  [[ -n "${f}" ]] && echo "${f}"
}

# Prompt text telling Claude how to write the PR description
pr_instructions() { # worktree issue-num
  local tpl
  tpl=$(find_pr_template "$1")
  if [[ -n "${tpl}" ]]; then
    printf '%s' "When you finish with STATUS: DONE, the rest of your final message becomes the pull request description.
This repository has a pull request template (${tpl#"$1"/}). Write the description by filling in that template:
keep all of its headings and sections in the same order, fill each one in from your changes, tick the checkboxes that apply,
and write N/A under sections that don't apply. Replace the template's placeholder text and HTML comments with real content.
Skip anything that asks for credentials, tokens or other secrets. Include 'Closes #$2'.

The template:
$(cat "${tpl}")"
  else
    printf '%s' "When you finish with STATUS: DONE, the rest of your final message becomes the pull request description. Include 'Closes #$2'."
  fi
}

# True if <body> contains every heading of <template> (or the template has no headings)
follows_template() { # template-file body
  local heading missing=0
  while IFS= read -r heading; do
    [[ -z "${heading}" ]] && continue
    grep -qiF -- "${heading}" <<<"$2" || missing=1
  done < <(sed -n 's/^#\{1,6\}[[:space:]]\{1,\}//p' "$1" | sed 's/[[:space:]]*$//')
  (( ! missing ))
}

# Builds PR_BODY from SUMMARY, making sure it follows the repo's PR template and references the issue.
build_pr_body() { # worktree issue-num
  local dir=$1 num=$2 tpl rewrite
  PR_BODY="${SUMMARY}"
  tpl=$(find_pr_template "${dir}")
  if [[ -n "${tpl}" ]] && ! follows_template "${tpl}" "${PR_BODY}" && [[ -n "${SID}" ]]; then
    warn "PR description does not follow ${tpl#"${dir}"/}; asking Claude to rewrite it"
    rewrite=$( cd "${dir}" && printf '%s' "Your summary will be used as the pull request description, but it does not follow the repository's pull request template. Do not make any more changes to the code. Reply with ONLY the pull request description, filling in the template as described below, and nothing else (no STATUS line).

$(pr_instructions "${dir}" "${num}")" \
      | timeout 10m claude -p --resume "${SID}" --output-format json --max-turns 3 --dangerously-skip-permissions --disallowedTools AskUserQuestion \
          2>> "${RESULT_LOG%.jsonl}.err" | jq -r '.result // ""' 2>/dev/null | grep -vE '^STATUS: ' )
    if [[ -n "${rewrite//[[:space:]]/}" ]]; then
      PR_BODY="${rewrite}"
      follows_template "${tpl}" "${PR_BODY}" || warn "Rewritten PR description still misses some template headings; using it anyway"
    else
      warn "Could not get a rewritten PR description; using the summary as-is"
    fi
  fi
  if ! grep -qiE "(close[sd]?|fix(e[sd])?|resolve[sd]?):? +#${num}([^0-9]|$)" <<<"${PR_BODY}"; then
    PR_BODY="Closes #${num}"$'\n\n'"${PR_BODY}"
  fi
  PR_BODY=$(printf '%s\n\n---\n_Generated by `%s` using Claude Code (%s)_' "${PR_BODY}" "${WORKER}" "${STATS}")
}

# Markdown list of commits and a diffstat for the range <from>..HEAD
change_list() { # worktree from-ref
  local commits files
  commits=$(git -C "$1" log --reverse --format='- `%h` %s' "$2..HEAD")
  files=$(git -C "$1" diff --stat=90 "$2...HEAD" | tail -n 40)
  printf '### Commits\n%s\n\n### Files changed\n```\n%s\n```' "${commits:-_none_}" "${files}"
}

# Decides what to do once an issue run ends: open a PR, post a question, or give up.
handle_result() { # repo num branch base
  local repo=$1 num=$2 branch=$3 base=$4
  local key dir commits
  key=$(key_for "${repo}" "${num}")
  dir="${TREE_ROOT}/${key}"

  finish_run "${repo}" "${num}" "${dir}"
  commits=$(git -C "${dir}" rev-list --count "origin/${base}..HEAD" 2>/dev/null || echo 0)
  event claude_result "Claude finished: status=${STATUS:-none} rc=${RC} commits=${commits} (${STATS})"

  if [[ "${STATUS}" == "QUESTION" && -n "${SID}" ]]; then
    edit_comment "${repo}" "${PROGRESS_ID}" "$(progress_body "${RESULT_LOG}" 'Paused: waiting for your answer')"
    relabel "${repo}" "${num}" claude-wip claude-question
    event question "Posted a question; waiting for ${ASSIGNEE}: $(head -c 300 <<<"${SUMMARY}" | tr '\n' ' ')"
    post_comment "${repo}" "${num}" "$(printf '%s **Question from `%s`**\n\n%s\n\n---\n_Reply in a comment and I will resume where I left off. Only replies from @%s count. No reply within %s days and I will give up._' \
      "${BOT}" "${WORKER}" "${SUMMARY}" "${ASSIGNEE}" "${QUESTION_TIMEOUT_DAYS}")" >/dev/null
    # asked_at is recorded after posting, so only comments made after the question count as answers
    jq -n --arg repo "${repo}" --arg num "${num}" --arg branch "${branch}" --arg base "${base}" \
      --arg sid "${SID}" --arg asked "$(now_iso)" \
      '{phase: "question", repo: $repo, num: ($num | tonumber), branch: $branch, base: $base, session_id: $sid, asked_at: $asked}' \
      > "${STATE_ROOT}/${key}.json"
    return
  fi

  if (( commits > 0 )); then
    edit_comment "${repo}" "${PROGRESS_ID}" "$(progress_body "${RESULT_LOG}" "Finished (${STATS})")"
    git -C "${dir}" push -q --force -u origin "${branch}"
    local title pr
    title=$(gh issue view "${num}" --repo "${repo}" --json title --jq .title)
    build_pr_body "${dir}" "${num}"
    pr=$(gh pr view "${branch}" --repo "${repo}" --json url,state --jq 'select(.state == "OPEN") | .url' 2>/dev/null)
    if [[ -z "${pr}" ]]; then
      pr=$(gh pr create --repo "${repo}" --base "${base}" --head "${branch}" --title "${title}" --body "${PR_BODY}")
    else
      # A re-queued issue reuses its open PR; refresh the description so it matches the new work
      gh pr edit "${pr}" --repo "${repo}" --body "${PR_BODY}" >/dev/null
    fi
    relabel "${repo}" "${num}" claude-wip claude-pr
    event pr_opened "Opened ${pr}; watching it"
    post_comment "${repo}" "${num}" "$(printf '%s **Work complete**: %s\n\n### Summary\n%s\n\n%s\n\n---\n_`%s` · %s · I will keep watching the PR for failing checks, merge conflicts and your review comments._' \
      "${BOT}" "${pr}" "${SUMMARY}" "$(change_list "${dir}" "origin/${base}")" "${WORKER}" "${STATS}")" >/dev/null
    # Keep the worktree and session so the PR can be watched and fixed
    jq -n --arg repo "${repo}" --arg num "${num}" --arg branch "${branch}" --arg base "${base}" \
      --arg sid "${SID}" --arg pr "${pr##*/}" --arg now "$(now_iso)" \
      '{phase: "pr", repo: $repo, num: ($num | tonumber), branch: $branch, base: $base, session_id: $sid,
        pr: ($pr | tonumber), handled_at: $now, fix_rounds: 0, ci_sha: "", conflict_sha: "", paused: false}' \
      > "${STATE_ROOT}/${key}.json"
    return
  fi

  edit_comment "${repo}" "${PROGRESS_ID}" "$(progress_body "${RESULT_LOG}" "Stopped (${STATS})")"
  relabel "${repo}" "${num}" claude-wip claude-failed
  log_event warn failed "No commits (status: ${STATUS:-none}, exit code ${RC}); labelled claude-failed"
  post_comment "${repo}" "${num}" "$(printf '%s `%s` made no commits (status: %s, exit code %s).\n\n%s' \
    "${BOT}" "${WORKER}" "${STATUS:-none}" "${RC}" "${SUMMARY}")" >/dev/null
  cleanup "${repo}" "${num}" "${branch}"
}

# --- Task entry points -------------------------------------------------------

start_task() { # repo num
  local repo=$1 num=$2
  local clone="${REPO_ROOT}/${repo}" branch="claude/issue-${num}" key base dir
  key=$(key_for "${repo}" "${num}")
  dir="${TREE_ROOT}/${key}"
  CUR_REF="${repo}#${num}"
  CUR_PHASE="new issue"

  event claim "Claiming ${repo}#${num}: $(gh issue view "${num}" --repo "${repo}" --json title --jq .title 2>/dev/null)"
  relabel "${repo}" "${num}" "${TRIGGER_LABEL}" claude-wip || return 1

  if [[ ! -d "${clone}/.git" ]] && ! gh repo clone "${repo}" "${clone}" -- -q; then
    relabel "${repo}" "${num}" claude-wip claude-failed
    warn "Could not clone ${repo}"
    post_comment "${repo}" "${num}" "${BOT} \`${WORKER}\` could not clone \`${repo}\`." >/dev/null
    return 1
  fi
  base=$(gh repo view "${repo}" --json defaultBranchRef --jq .defaultBranchRef.name)

  # A re-queued issue starts over: drop any earlier worktree, pending question or PR watch
  cleanup "${repo}" "${num}" "${branch}"
  git -C "${clone}" fetch -q --prune origin
  if ! git -C "${clone}" worktree add -q -f -B "${branch}" "${dir}" "origin/${base}"; then
    relabel "${repo}" "${num}" claude-wip claude-failed
    warn "Could not create a worktree for ${branch}"
    post_comment "${repo}" "${num}" "${BOT} \`${WORKER}\` could not create a worktree for \`${branch}\`." >/dev/null
    return 1
  fi

  local issue
  issue=$(gh issue view "${num}" --repo "${repo}" --json title,body,comments \
    --jq '"# " + .title + "\n\n" + (.body // "") + "\n\n" + ([.comments[] | "---\nComment from " + .author.login + ":\n" + .body] | join("\n\n"))')

  run_claude "${repo}" "${num}" "${dir}" "You are working in a git worktree of ${repo} on branch ${branch}. Resolve GitHub issue #${num}, shown below.

${RULES}

$(pr_instructions "${dir}" "${num}")

Issue #${num}:
${issue}"
  handle_result "${repo}" "${num}" "${branch}" "${base}"
}

# Checks a waiting issue for an answer. Returns 0 only if Claude was run.
resume_task() { # state-file
  local sf=$1 repo num branch base sid asked info
  repo=$(jq -r .repo "${sf}"); num=$(jq -r .num "${sf}"); branch=$(jq -r .branch "${sf}")
  base=$(jq -r .base "${sf}"); sid=$(jq -r .session_id "${sf}"); asked=$(jq -r .asked_at "${sf}")
  CUR_REF="${repo}#${num}"

  info=$(gh issue view "${num}" --repo "${repo}" --json state,labels,comments 2>/dev/null) || return 1
  if [[ $(jq -r .state <<<"${info}") != "OPEN" ]] || ! jq -e '.labels | any(.name == "claude-question")' <<<"${info}" >/dev/null; then
    event dropped "Closed or un-labelled while waiting on a question; dropping it"
    cleanup "${repo}" "${num}" "${branch}"
    return 1
  fi

  local replies
  replies=$(jq -r --arg who "${ASSIGNEE}" --arg asked "${asked}" --arg bot "${BOT}" \
    '[.comments[] | select(.author.login == $who and .createdAt > $asked and (.body | startswith($bot) | not)) | .body] | join("\n\n---\n\n")' <<<"${info}")

  if [[ -z "${replies}" ]]; then
    if (( $(date +%s) - $(date -d "${asked}" +%s) > QUESTION_TIMEOUT_DAYS * 86400 )); then
      log_event warn failed "No answer in ${QUESTION_TIMEOUT_DAYS} days; giving up"
      relabel "${repo}" "${num}" claude-question claude-failed
      post_comment "${repo}" "${num}" "${BOT} No answer within ${QUESTION_TIMEOUT_DAYS} days, so \`${WORKER}\` has dropped this. Re-add the \`${TRIGGER_LABEL}\` label to start over." >/dev/null
      cleanup "${repo}" "${num}" "${branch}"
    fi
    return 1
  fi

  event answer "Answer received from ${ASSIGNEE}; resuming session ${sid}"
  CUR_PHASE="answer"
  relabel "${repo}" "${num}" claude-question claude-wip
  run_claude "${repo}" "${num}" "${TREE_ROOT}/$(key_for "${repo}" "${num}")" "@${ASSIGNEE} replied on the issue:

${replies}

Continue the task with this answer. The same rules apply, including ending with a STATUS line.

${RULES}

$(pr_instructions "${TREE_ROOT}/$(key_for "${repo}" "${num}")" "${num}")" "${sid}"
  handle_result "${repo}" "${num}" "${branch}" "${base}"
  return 0
}

# --- PR watching ---------------------------------------------------------------

# Reviews, inline review comments and PR comments from ASSIGNEE newer than <since>, as markdown
pr_feedback() { # repo pr since
  {
    gh api --paginate "repos/$1/pulls/$2/reviews" \
      --jq '.[] | {kind: "review", who: .user.login, at: .submitted_at, state: .state, body: (.body // "")}'
    gh api --paginate "repos/$1/pulls/$2/comments" \
      --jq '.[] | {kind: "inline", who: .user.login, at: .created_at, body: .body, path: .path, line: (.line // .original_line)}'
    gh api --paginate "repos/$1/issues/$2/comments" \
      --jq '.[] | {kind: "comment", who: .user.login, at: .created_at, body: .body}'
  } 2>/dev/null | jq -rs --arg who "${ASSIGNEE}" --arg since "$3" --arg bot "${BOT}" '
    [.[] | select(.who == $who and .at != null and .at > $since and (.body | startswith($bot) | not))
         | select(.kind != "review" or (.state != "APPROVED" and (.body != "" or .state == "CHANGES_REQUESTED")))]
    | sort_by(.at)
    | map(if .kind == "inline" then "Inline review comment on `\(.path)` line \(.line):\n\(.body)"
          elif .kind == "review" then "Review (\(.state)):\n\(if .body == "" then "(no text; see the inline comments)" else .body end)"
          else "PR comment:\n\(.body)" end)
    | join("\n\n---\n\n")'
}

# Name, URL and (for GitHub Actions jobs) the tail of the failed log for each failing check
ci_failure_details() { # repo tsv-of-name-and-url
  local name url
  while IFS=$'\t' read -r name url; do
    [[ -z "${name}" ]] && continue
    printf '### %s\n%s\n' "${name}" "${url}"
    if [[ "${url}" =~ /actions/runs/[0-9]+/job/([0-9]+) ]]; then
      printf '```\n%s\n```\n' "$(gh run view --repo "$1" --job "${BASH_REMATCH[1]}" --log-failed 2>/dev/null | tail -n 150 | cut -c1-400)"
    fi
    printf '\n'
  done <<<"$2"
}

# Checks a watched PR. Returns 0 only if Claude was run.
check_pr() { # state-file
  local sf=$1 repo num branch base sid pr handled rounds ci_sha conflict_sha paused
  repo=$(jq -r .repo "${sf}"); num=$(jq -r .num "${sf}"); branch=$(jq -r .branch "${sf}"); base=$(jq -r .base "${sf}")
  sid=$(jq -r .session_id "${sf}"); pr=$(jq -r .pr "${sf}"); handled=$(jq -r .handled_at "${sf}")
  rounds=$(jq -r .fix_rounds "${sf}"); ci_sha=$(jq -r .ci_sha "${sf}"); conflict_sha=$(jq -r .conflict_sha "${sf}")
  paused=$(jq -r .paused "${sf}")
  CUR_REF="${repo}#${num}"
  local dir
  dir="${TREE_ROOT}/$(key_for "${repo}" "${num}")"

  local info
  info=$(gh pr view "${pr}" --repo "${repo}" --json state,mergeable,headRefOid,statusCheckRollup 2>/dev/null) || return 1
  case $(jq -r .state <<<"${info}") in
    MERGED)
      event merged "PR #${pr} merged; done"
      relabel "${repo}" "${num}" claude-pr claude-done
      cleanup "${repo}" "${num}" "${branch}"
      return 1 ;;
    CLOSED)
      event closed "PR #${pr} closed without merging; dropping it"
      gh issue edit "${num}" --repo "${repo}" --remove-label claude-pr >/dev/null
      cleanup "${repo}" "${num}" "${branch}"
      return 1 ;;
  esac

  local head mergeable since pending failures feedback sections=""
  head=$(jq -r .headRefOid <<<"${info}")
  mergeable=$(jq -r .mergeable <<<"${info}")
  since=$(now_iso) # captured before reading feedback, so nothing posted from here on is missed next time
  pending=$(jq '[.statusCheckRollup[]? | select((.status // "COMPLETED") != "COMPLETED" or ((.state // "") | test("^(PENDING|EXPECTED)$")))] | length' <<<"${info}")
  failures=$(jq -r '.statusCheckRollup[]?
    | select(((.conclusion // "") | test("^(FAILURE|TIMED_OUT|ACTION_REQUIRED|STARTUP_FAILURE)$")) or ((.state // "") | test("^(FAILURE|ERROR)$")))
    | [(.name // .context), (.detailsUrl // .targetUrl // "")] | @tsv' <<<"${info}")
  feedback=$(pr_feedback "${repo}" "${pr}" "${handled}")

  local new_ci="${ci_sha}" new_conflict="${conflict_sha}"
  if [[ -n "${feedback}" ]]; then
    sections+="## Review feedback from @${ASSIGNEE}
${feedback}

"
  fi
  # Only act on CI once every check has finished, and only once per commit
  if (( pending == 0 )) && [[ -n "${failures}" && "${head}" != "${ci_sha}" ]]; then
    sections+="## Failing checks on ${head:0:7}
$(ci_failure_details "${repo}" "${failures}")
"
    new_ci="${head}"
  fi
  if [[ "${mergeable}" == "CONFLICTING" && "${head}" != "${conflict_sha}" ]]; then
    sections+="## Merge conflict
The PR no longer merges cleanly into ${base}. Run \`git fetch origin && git merge origin/${base}\`, resolve the conflicts and commit the merge. Do not rebase.

"
    new_conflict="${head}"
  fi
  [[ -z "${sections}" ]] && return 1

  if [[ -n "${feedback}" ]]; then
    rounds=0 # a reply from ASSIGNEE resets the automatic fix budget
  elif (( rounds >= MAX_FIX_ROUNDS )); then
    if [[ "${paused}" != "true" ]]; then
      log_event warn paused "PR #${pr}: ${MAX_FIX_ROUNDS} automatic fix rounds used; waiting for ${ASSIGNEE}"
      post_comment "${repo}" "${pr}" "${BOT} \`${WORKER}\` has made ${MAX_FIX_ROUNDS} automatic fix attempts and the PR still needs attention, so it is pausing. Reply here (a comment or a review) to tell me how to proceed and I will pick it back up." >/dev/null
      update_state "${sf}" '.paused = true'
    fi
    return 1
  fi
  rounds=$((rounds + 1))

  # Pick up any commits pushed to the PR branch by someone else, so they are never overwritten
  git -C "${dir}" fetch -q origin
  if git -C "${dir}" merge-base --is-ancestor HEAD "origin/${branch}" 2>/dev/null; then
    git -C "${dir}" merge -q --ff-only "origin/${branch}"
  fi
  local before after
  before=$(git -C "${dir}" rev-parse HEAD)

  event fix_round "PR #${pr}: fix round ${rounds} for:$([[ -n "${feedback}" ]] && echo " review feedback")$([[ "${new_ci}" != "${ci_sha}" ]] && echo " failing checks")$([[ "${new_conflict}" != "${conflict_sha}" ]] && echo " merge conflict")"
  CUR_PHASE="PR #${pr} fix round ${rounds}"
  run_claude "${repo}" "${pr}" "${dir}" "Your pull request #${pr} for issue #${num} (branch ${branch}) needs attention:

${sections}
Fix these in this worktree and commit the fixes. Do not push; that is handled for you.
For review feedback: make the requested changes. If a comment is a question, answer it in your final message.
Your final message is posted on the PR, so summarize what you changed in this round.
Use STATUS: QUESTION only if you need an answer from the reviewer before you can continue.

${RULES}" "${sid}"
  finish_run "${repo}" "${pr}" "${dir}"
  after=$(git -C "${dir}" rev-parse HEAD)

  local heading body
  case "${STATUS}" in
    QUESTION) heading="Question from \`${WORKER}\` (fix round ${rounds}). Reply here to answer." ;;
    *)        heading="Fix round ${rounds} by \`${WORKER}\`" ;;
  esac
  if [[ "${after}" != "${before}" ]]; then
    if git -C "${dir}" push -q origin "HEAD:${branch}"; then
      event pushed "Pushed ${after:0:7} to ${branch}"
      body=$(printf '%s **%s**\n\n%s\n\n%s\n\n---\n_%s_' "${BOT}" "${heading}" "${SUMMARY}" "$(change_list "${dir}" "${before}")" "${STATS}")
    else
      warn "Pushing ${after:0:7} to ${branch} failed"
      body=$(printf '%s **%s**\n\n%s\n\n**Pushing the fix failed.** The branch may have been changed elsewhere.\n\n---\n_%s_' "${BOT}" "${heading}" "${SUMMARY}" "${STATS}")
    fi
  else
    body=$(printf '%s **%s**: no new commits.\n\n%s\n\n---\n_%s_' "${BOT}" "${heading}" "${SUMMARY}" "${STATS}")
  fi
  edit_comment "${repo}" "${PROGRESS_ID}" "$(progress_body "${RESULT_LOG}" "Finished fix round ${rounds} (${STATS})")"
  post_comment "${repo}" "${pr}" "${body}" >/dev/null
  event fix_result "PR #${pr}: fix round ${rounds} finished: status=${STATUS:-none} rc=${RC}, $([[ "${after}" != "${before}" ]] && echo "pushed ${after:0:7}" || echo "no new commits") (${STATS})"

  update_state "${sf}" --arg since "${since}" --arg ci "${new_ci}" --arg conflict "${new_conflict}" \
    --arg sid "${SID:-${sid}}" --argjson rounds "${rounds}" \
    '.handled_at = $since | .ci_sha = $ci | .conflict_sha = $conflict | .session_id = $sid | .fix_rounds = $rounds | .paused = false'
  return 0
}

# --- Main loop ---------------------------------------------------------------

rotate_logs
set_status starting
event worker_start "Worker ${ORDINAL}/${WORKER_COUNT} started (claude $(claude --version 2>/dev/null | head -n1)), watching issues assigned to ${ASSIGNEE} in: ${REPOS}"

# Recover from a restart mid-task: anything still claude-wip in this shard is no longer running.
for repo in ${REPOS}; do
  for num in $(gh issue list --repo "${repo}" --label claude-wip --assignee "${ASSIGNEE}" --state open --limit 100 --json number \
      --jq ".[] | select(.number % ${WORKER_COUNT} == ${ORDINAL}) | .number" 2>/dev/null); do
    sf="${STATE_ROOT}/$(key_for "${repo}" "${num}").json"
    CUR_REF="${repo}#${num}"
    if [[ -f "${sf}" && $(jq -r '.phase // "question"' "${sf}") == "question" ]]; then
      warn "Interrupted while resuming; back to waiting on its question"
      relabel "${repo}" "${num}" claude-wip claude-question
    else
      warn "Interrupted mid-task; re-queueing"
      relabel "${repo}" "${num}" claude-wip "${TRIGGER_LABEL}"
      post_comment "${repo}" "${num}" "${BOT} \`${WORKER}\` restarted mid-task, so this has been re-queued." >/dev/null
    fi
  done
done

CUR_REF=""
was_idle=0
while (( ! stopping )); do
  did_work=0
  CUR_REF=""
  CUR_PHASE=""
  rotate_logs
  # Watched PRs and answered questions first, so in-flight work is finished before new issues are started
  for sf in "${STATE_ROOT}"/*.json; do
    [[ -e "${sf}" ]] || continue
    case $(jq -r '.phase // "question"' "${sf}") in
      pr) check_pr "${sf}" && { did_work=1; break; } ;;
      *)  resume_task "${sf}" && { did_work=1; break; } ;;
    esac
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
  CUR_REF=""
  if (( did_work )); then
    was_idle=0
  else
    if (( ! was_idle )); then
      # Log once when going idle rather than on every poll
      waiting=$(grep -l '"phase": "question"' "${STATE_ROOT}"/*.json 2>/dev/null | wc -l)
      watching=$(grep -l '"phase": "pr"' "${STATE_ROOT}"/*.json 2>/dev/null | wc -l)
      event idle "Idle: ${watching} PR(s) watched, ${waiting} question(s) waiting; polling every ${POLL_INTERVAL}s"
      was_idle=1
    fi
    set_status idle
  fi
  # Background sleep + wait so SIGTERM interrupts idle polling immediately
  (( did_work )) || { sleep "${POLL_INTERVAL}" & wait $!; }
done
set_status stopped
event worker_stop "Worker stopped"
