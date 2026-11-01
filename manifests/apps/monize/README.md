# Summary
[Monize](https://github.com/kenlasko/monize) is my vibe-coded, self-hosted personal finance software to manage my finances. Check out that repo for more information about it.

# Building and deploying from source (home cluster)
The `monize-build` CronJob ([cronjob-build.yaml](overlays/home/cronjob-build.yaml)) builds the backend and frontend images from a branch of the Monize repo, in parallel and preferably on different nodes, pushes them to `registry.laskonet.com/monize/{backend,frontend}:latest`, and restarts both deployments. It's an in-cluster replacement for `build-push-deploy.sh`. It is suspended, so it only runs when triggered by hand.

To build `main`:
```
kubectl create job -n monize --from=cronjob/monize-build monize-build-$(date +%s)
```
The ArgoCD "Create Job" action on the CronJob does the same thing.

To build another branch, use [monize-build.sh](../../../scripts/monize-build.sh), which needs `kubectl` and `jq`. It follows the coordinator's log until the rollout finishes; `-d` starts the job and returns straight away. Each build's own log is in its Job (`kubectl logs -n monize -f job/<job>-backend -c build`, or `-frontend`); the coordinator prints the exact command.
```
scripts/monize-build.sh                  # main
scripts/monize-build.sh my-feature-branch
```

`monize-build` is a coordinator. Its pod:
1. `resolve`: pins the branch to its current commit, so both images come from the same source even if the branch moves during the build
2. `coordinate`: creates one Job from each of the suspended `monize-build-backend` and `monize-build-frontend` CronJobs for that commit, and waits for both. If one fails, it prints the tail of that build's log and deletes the other, so a half-finished release doesn't leave a `:latest` that nothing deployed. When both succeed, it runs `kubectl rollout restart` on both deployments and waits for both rollouts.

Each build Job's pod shallow-clones the commit, then builds the `production` target with [Kaniko](https://github.com/osscontainertools/kaniko) and pushes it. The two pods prefer different nodes (pod anti-affinity), but share one when no other node has room. `RUN` layers are cached in `registry.laskonet.com/monize/{backend,frontend}-cache`, so `npm ci` only re-runs when a `package*.json` changes. The build steps re-run on every source change. Triggering `monize-build-backend` or `monize-build-frontend` directly builds and pushes that image from `main` without restarting anything.

A failed job is not retried. Its pods and logs are kept for a day.

Kaniko must run as root, so the home overlay relaxes the namespace's Pod Security enforcement from `restricted` to `baseline` ([patch-namespace.yaml](overlays/home/patch-namespace.yaml)). The Monize pods still set their own restricted security contexts, and `audit: restricted` keeps any pod that doesn't visible in the audit log. The coordinator's service account ([rbac-build.yaml](overlays/home/rbac-build.yaml)) can create Jobs in the namespace, which in practice can run any pod there, so only the coordinator's own `git` and `kubectl` containers hold its token. The build pods, which run the branch's Dockerfile and npm install scripts, get no token.

The layer cache is pruned weekly by the registry's `registry-prune-cache` CronJob. See the [registry README](../../system/registry/README.md#kaniko-cache-pruning).
