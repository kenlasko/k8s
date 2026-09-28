# Summary
A fixed pool of [Claude Code](https://code.claude.com/docs/en/headless) workers that pick up GitHub issues and turn them into pull requests, several at a time.

Each worker is a pod in a 3-replica StatefulSet with its own 20Gi Longhorn workspace. The workspace holds a clone of each repo, a git worktree per in-flight issue, `~/.claude` (including saved sessions) and the task logs. Workers run [worker.sh](base/worker.sh) in a loop:

1. Poll the repos in `REPOS` for open issues labelled `claude` **and** assigned to `ASSIGNEE`
2. Claim one by swapping the label for `claude-wip`
3. Create a worktree on a fresh `claude/issue-<n>` branch from the default branch
4. Run `claude -p` headlessly with the issue (title, body and comments) as the prompt, editing a single **progress comment** on the issue every minute with Claude's latest narration and its recent tool calls
5. When Claude finishes, based on the `STATUS:` line its final message must end with:
   * **DONE** with commits: push the branch, open a PR that `Closes #<n>`, post a **work complete** comment on the issue (summary, commits, files changed) and label it `claude-pr`
   * **QUESTION**: post the question on the issue, label it `claude-question`, save the session ID and move on to other work
   * anything else, or no commits: post Claude's explanation and label it `claude-failed`
6. Watch the PR until it is merged (issue labelled `claude-done`) or closed. See [PR watching](#pr-watching)

PR descriptions follow the repo's **pull request template**, if it has one, found in the same places GitHub looks (`.github/`, `docs/` or the root, or the first file in `.github/PULL_REQUEST_TEMPLATE/`). The template is included in Claude's instructions, and Claude writes the description by filling it in. If its description is missing any of the template's headings, the worker asks it to rewrite the description before opening the PR. `Closes #<n>` is added if Claude left it out. When a re-queued issue reuses its open PR, the description is replaced too.

If a run ends without a final message (for example after hitting `MAX_TURNS`), the worker resumes the session briefly and asks Claude for a summary, so the PR and issue comments always get one.

**Testing is split between the worker and CI.** Claude is told not to run the full test suite, coverage or full builds on the worker, which is slow. It runs only the tests that cover the code it changed (plus any tests it added), with lint and type-checking scoped to the changed files where the tooling allows. The complete suite runs in GitHub CI on the PR. If it fails, [PR watching](#pr-watching) hands the failure logs back to Claude, which fixes the problem, re-runs only the failing tests locally and pushes. Each CI failure uses one of the `MAX_FIX_ROUNDS`.

If Claude stops without a `STATUS:` line, for example because it ended its turn to "check back" on something, the worker resumes the session and tells it to finish, up to `MAX_CONTINUES` (2) times. Background commands are disabled (`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`), since a headless run ends as soon as Claude stops. Command timeouts are raised to 60 minutes by default and 90 at most, so long test and build runs can finish in the foreground.

Issues are sharded by `issue number % WORKER_COUNT`, so each worker only takes issues in its own shard and two workers never grab the same one. This also guarantees a resumed issue lands on the pod that holds its saved session. The catch is that a worker busy with a long task holds up the rest of its shard, even if the other workers are idle.

## Questions
Claude is told to ask whenever there's a meaningful choice rather than guess. Its built-in question tool is disabled, since nobody could answer it in headless mode. Instead it commits any work in progress, ends its run with `STATUS: QUESTION`, and the worker posts the question on the issue.

On each poll, the worker checks its waiting issues first. Once **you** (`ASSIGNEE`) comment, it resumes the *same* Claude session with `claude -p --resume <session-id>` in the same worktree and passes your reply in. Claude keeps its full context and partial work, and can ask again if it needs to. Comments from anyone else, and the worker's own 🤖 comments, are ignored.

* No reply within `QUESTION_TIMEOUT_DAYS` (7): the issue is labelled `claude-failed` and the worktree is removed
* Closing the issue or removing the `claude-question` label cancels the task
* Re-adding the `claude` label starts the issue over from scratch

If a pod restarts mid-task, the issue is re-queued on startup. An issue that was mid-resume goes back to waiting on its question.

## PR watching
While the issue is labelled `claude-pr`, the worker checks the PR on every poll. It looks for:
* **Failing checks**, once every check on the latest commit has finished. For GitHub Actions jobs, the tail of the failed log is included.
* **Merge conflicts** with the base branch. Claude merges the base in; it never rebases.
* **Review feedback from you**: reviews that request changes or have text, inline review comments, and PR comments. Approvals, other people's comments and the worker's own 🤖 comments are ignored.

Anything it finds is handed to the same Claude session in the same worktree. The worker pushes the fix (never force-pushing) and posts a **fix round** comment on the PR with what changed. Commits pushed to the branch by someone else are pulled in first. CI failures and conflicts are each handled once per commit, so an unfixable failure doesn't loop.

After `MAX_FIX_ROUNDS` (3) automatic rounds, the worker posts a comment on the PR and pauses. Any reply or review from you resets the count and it carries on. If Claude has a question during a fix round, it asks on the PR, and your reply there is treated as review feedback.


## Setup
1. **Build the image** from [image/Dockerfile](image/Dockerfile) and push it to the local registry:
   ```
   cd manifests/apps/claude-workers/image
   docker buildx build --platform linux/amd64 -t registry.laskonet.com/claude-worker:latest --push .
   ```
   (Or move the Dockerfile to the [docker](https://github.com/kenlasko/docker) repo alongside the other private images.)
2. **Create a Claude token** on any machine logged into your Claude subscription:
   ```
   claude setup-token
   ```
3. **Create a fine-grained GitHub PAT** limited to the repos in `REPOS`, with **Contents**, **Issues** and **Pull requests** set to read/write, and **Actions** and **Commit statuses** set to read. Protect your default branches so that the token can't push to them directly.
4. **Store both in Akeyless** as a secret at `/claude-workers` with the properties `oauthToken` and `githubToken`.
5. Merge. The `apps` ApplicationSet picks up the app automatically.

## Usage
Open an issue in one of the watched repos, describe the task, assign it to yourself, and add the `claude` label. Labelled issues that aren't assigned to `ASSIGNEE` are ignored. To retry a `claude-failed` issue, add a comment with clarification and put the `claude` label back.

### Stopping a task
Add the **`claude-stop`** label to the issue, from the GitHub app, the web, or `kubectl -n claude-workers exec claude-worker-0 -- claude-stop <issue>` (use `owner/repo#number` when watching several repos). Within about a minute (`PROGRESS_INTERVAL`), the worker handling the issue:
* stops Claude immediately if it's running, along with anything it started, such as a test run
* discards the work: the issue's worktree and any commits that weren't pushed
* drops any pending question or PR watching
* swaps the labels for `claude-stopped` and posts a comment

If the issue already has an open PR, the PR is **left open** but is no longer watched; close it if you don't want it. To start over, remove `claude-stopped` and add `claude`.

### Choosing the model and effort
By default each run uses Claude Code's default model for your subscription (set `DEFAULT_MODEL` / `DEFAULT_EFFORT` to change that). An issue can pick its own in either of two ways; if both are present, the label wins:
* **Labels**: `model:opus`, `model:sonnet`, `model:haiku` or `model:fable` (the latest model in that family), and `effort:low`, `effort:medium`, `effort:high`, `effort:xhigh` or `effort:max`. The worker creates these labels.
* **A line in the issue body**: `Model: sonnet` or `Effort: high` at the start of a line. A full model ID also works here, e.g. `Model: claude-opus-5-5`.

The choice is re-read before every run, including resumed questions and PR fix rounds, so changing the label part-way through takes effect on the next run. The model actually used appears in the progress comment, the PR footer and the logs. Unknown values are ignored with a warning in the log.

Follow along in the GitHub app or web. The progress comment updates every minute while Claude works, and questions arrive as issue comments, so GitHub notifications on your phone tell you when a worker needs you. To see everything waiting on you, filter issues by `label:claude-question`.

See [Logging](#logging) for following a worker from the terminal or Grafana.

## Logging
Everything a worker does is logged to its pod's stdout, including Claude's activity streamed live as it happens: its messages (💬), each tool call with its command or file (🔧), failed tool calls (❌), and the result of each run (🏁). The worker's own steps are logged too, such as claiming an issue, questions, PRs opened, fix rounds, pushes, merges and warnings. Successful tool output isn't logged.

```
kubectl -n claude-workers logs -f claude-worker-0
```

With `LOG_FORMAT=json` (the default), each line is a JSON object with `ts`, `level`, `worker`, `ref` (`owner/repo#issue`), `repo`, `issue`, `source` (`worker` or `claude`), `event`, `tool` and `msg`. Alloy ships the lines to Loki, so in Grafana you can filter with, for example:
```
{namespace="claude-workers"} | json | issue="42"
{namespace="claude-workers"} | json | level="warn"
{namespace="claude-workers"} | json | event=~"pr_opened|fix_round|merged|failed|question"
```
Set `LOG_FORMAT=text` for plain lines instead.

Each pod also has helper commands (`claude-stop` is described under [Stopping a task](#stopping-a-task)):
```
kubectl -n claude-workers exec claude-worker-0 -- claude-status          # current task, questions waiting on you, watched PRs, recent activity
kubectl -n claude-workers exec -it claude-worker-0 -- claude-log -f      # follow the activity log live, pretty-printed
kubectl -n claude-workers exec claude-worker-0 -- claude-log -r 42       # replay Claude's latest run on issue/PR 42 (-f to follow one in progress)
kubectl -n claude-workers exec claude-worker-0 -- claude-log -l          # list recent runs
```
For all workers at once: `for i in 0 1 2; do kubectl -n claude-workers exec claude-worker-$i -- claude-status; echo; done`

When the worker goes idle it logs the disk usage of `/workspace` and `/tmp`, and warns above 85%.

The raw stream-json transcript of every run is kept in `/workspace/logs/*.jsonl` for `LOG_RETENTION_DAYS` (14), and the activity log in `/workspace/logs/worker.log`, rotated at 20MB. The helpers live in the `worker-script` ConfigMap next to `worker.sh`, so changes to them roll out without rebuilding the image.

## Configuration
Settings live in [env-vars.yaml](base/env-vars.yaml):
| Variable | Purpose |
|:---------|:--------|
| `REPOS` | Space-separated `owner/repo` list to watch |
| `TRIGGER_LABEL` | Label that queues an issue (default `claude`) |
| `ASSIGNEE` | GitHub user an issue must be assigned to (default `kenlasko`) |
| `WORKER_COUNT` | Must match the StatefulSet `replicas` |
| `MAX_TURNS` / `TASK_TIMEOUT` | Limits for a single Claude run (default 250 turns, 3h) |
| `POLL_INTERVAL` | Seconds between GitHub polls when idle |
| `PROGRESS_INTERVAL` | Seconds between progress comment updates |
| `QUESTION_TIMEOUT_DAYS` | Days to wait for an answer before giving up |
| `MAX_FIX_ROUNDS` | Automatic PR fix rounds before waiting for you |
| `MAX_CONTINUES` | Resumes of a run that stopped without a `STATUS:` line |
| `BASH_DEFAULT_TIMEOUT_MS` / `BASH_MAX_TIMEOUT_MS` | Claude's default and maximum command timeouts |
| `DEFAULT_MODEL` / `DEFAULT_EFFORT` | Model and effort when an issue doesn't choose (empty = Claude Code's default) |
| `LOG_FORMAT` | `json` (default, for Loki) or `text` |
| `TMP_CLEAN_MINUTES` | Files in `/tmp` older than this are removed between tasks |
| `LOG_RETENTION_DAYS` | Days to keep per-run transcripts |

### Storage and npm
* **npm** uses one shared cache per pod (`/workspace/home/.npm`), prefers it over the network and skips audit/fund lookups, so installs in a fresh worktree come mostly from local disk.
* **`/tmp`** is a 10Gi node-local `emptyDir` used by npm, test runners and coverage. Going over the limit evicts the pod. Leftovers older than `TMP_CLEAN_MINUTES` are removed between tasks.
* **`node_modules`** is deleted from an issue's worktree once its PR is opened, so worktrees kept for PR watching don't fill the workspace. Claude reinstalls dependencies from the cache when a fix round needs them.
* **The 20Gi workspace volume** can't be resized through the StatefulSet (Kubernetes doesn't allow changing `volumeClaimTemplates`). Expand each PVC directly instead; Longhorn supports online expansion:
  ```
  for i in 0 1 2; do kubectl -n claude-workers patch pvc workspace-claude-worker-$i -p '{"spec":{"resources":{"requests":{"storage":"40Gi"}}}}'; done
  ```

To scale, change `replicas` in [statefulset.yaml](base/statefulset.yaml) and `WORKER_COUNT` together. All workers share one Claude subscription, so its usage limits are shared across the pool as well.

## Security notes
* Claude runs with `--dangerously-skip-permissions`, since there is no one around to approve tool calls. The guardrails are the container itself:
  * non-root, read-only root filesystem, `restricted` Pod Security
  * a **read-only** ClusterRole that excludes Secrets ([rbac.yaml](base/rbac.yaml)). Cluster changes still go through a PR and ArgoCD.
  * a fine-grained GitHub token and branch protection on the default branches
* Issue text becomes Claude's prompt. Requiring the issue to be assigned to `ASSIGNEE` means random issues are never acted on, but comments from anyone on an assigned issue are still included in the prompt.
