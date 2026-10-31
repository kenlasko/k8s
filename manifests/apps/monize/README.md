# Summary
[Monize](https://github.com/kenlasko/monize) is my vibe-coded, self-hosted personal finance software to manage my finances. Check out that repo for more information about it.

# Building and deploying from source (home cluster)
The `monize-build` CronJob ([cronjob-build.yaml](overlays/home/cronjob-build.yaml)) builds the backend and frontend images from a branch of the Monize repo, pushes them to `registry.laskonet.com/monize/{backend,frontend}:latest`, and restarts both deployments. It's an in-cluster replacement for `build-push-deploy.sh`. It is suspended, so it only runs when triggered by hand.

To build `main`:
```
kubectl create job -n monize --from=cronjob/monize-build monize-build-$(date +%s)
```
The ArgoCD "Create Job" action on the CronJob does the same thing.

To build another branch, use [monize-build.sh](../../../scripts/monize-build.sh), which needs `kubectl` and `jq`. It follows the logs until the rollout finishes; `-d` starts the job and returns straight away.
```
scripts/monize-build.sh                  # main
scripts/monize-build.sh my-feature-branch
```

The job runs as one pod. Its init containers run in order, and each must succeed before the next starts:
1. `clone`: shallow-clones the branch
2. `build-backend`, `build-frontend`: build the `production` target with [Kaniko](https://github.com/osscontainertools/kaniko) and push it. No layer cache, so each run is a full build.
3. `deploy`: `kubectl rollout restart` on both deployments, then waits for both rollouts

A failed job is not retried. Its pod and logs are kept for a day.

Kaniko must run as root, so the home overlay relaxes the namespace's Pod Security enforcement from `restricted` to `baseline` ([patch-namespace.yaml](overlays/home/patch-namespace.yaml)). The Monize pods still set their own restricted security contexts, and `audit: restricted` keeps any pod that doesn't visible in the audit log. The job's service account ([rbac-build.yaml](overlays/home/rbac-build.yaml)) can only patch the two Monize deployments.
