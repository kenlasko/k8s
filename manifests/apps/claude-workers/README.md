# Summary
A fixed pool of [Claude Code](https://code.claude.com/docs/en/headless) workers that pick up GitHub issues and turn them into pull requests, several at a time.

Each worker is a pod in a 3-replica StatefulSet with its own 20Gi Longhorn workspace. The workspace holds the repo clones, dependency caches, `~/.claude` and the task logs. Workers run [worker.sh](base/worker.sh) in a loop:

1. Poll the repos in `REPOS` for open issues labelled `claude` **and** assigned to `ASSIGNEE`
2. Claim one by swapping the label for `claude-wip`
3. Check out a fresh `claude/issue-<n>` branch from the default branch
4. Run `claude -p` headlessly with the issue (title, body and comments) as the prompt
5. If Claude committed anything, push the branch, open a PR that `Closes #<n>`, and label the issue `claude-done`. If not, post Claude's explanation and label it `claude-failed`

Issues are sharded by `issue number % WORKER_COUNT`, so each worker only takes issues in its own shard and two workers never grab the same one. The catch is that a worker busy with a long task holds up the rest of its shard, even if the other workers are idle.

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
3. **Create a fine-grained GitHub PAT** limited to the repos in `REPOS`, with **Contents**, **Issues** and **Pull requests** set to read/write. Protect your default branches so that the token can't push to them directly.
4. **Store both in Akeyless** as a secret at `/claude-workers` with the properties `oauthToken` and `githubToken`.
5. Merge. The `apps` ApplicationSet picks up the app automatically.

## Usage
Open an issue in one of the watched repos, describe the task, assign it to yourself, and add the `claude` label. Labelled issues that aren't assigned to `ASSIGNEE` are ignored. To retry a `claude-failed` issue, add a comment with clarification and put the `claude` label back.

Watch progress with:
```
kubectl -n claude-workers logs -f claude-worker-0
kubectl -n claude-workers exec -it claude-worker-0 -- ls /workspace/logs
```

## Configuration
Settings live in [env-vars.yaml](base/env-vars.yaml):
| Variable | Purpose |
|:---------|:--------|
| `REPOS` | Space-separated `owner/repo` list to watch |
| `TRIGGER_LABEL` | Label that queues an issue (default `claude`) |
| `ASSIGNEE` | GitHub user an issue must be assigned to (default `kenlasko`) |
| `WORKER_COUNT` | Must match the StatefulSet `replicas` |
| `MAX_TURNS` / `TASK_TIMEOUT` | Limits for a single task |
| `POLL_INTERVAL` | Seconds between GitHub polls when idle |

To scale, change `replicas` in [statefulset.yaml](base/statefulset.yaml) and `WORKER_COUNT` together. All workers share one Claude subscription, so its usage limits are shared across the pool as well.

## Security notes
* Claude runs with `--dangerously-skip-permissions`, since there is no one around to approve tool calls. The guardrails are the container itself:
  * non-root, read-only root filesystem, `restricted` Pod Security
  * a **read-only** ClusterRole that excludes Secrets ([rbac.yaml](base/rbac.yaml)). Cluster changes still go through a PR and ArgoCD.
  * a fine-grained GitHub token and branch protection on the default branches
* Issue text becomes Claude's prompt. Requiring the issue to be assigned to `ASSIGNEE` means random issues are never acted on, but comments from anyone on an assigned issue are still included in the prompt.
