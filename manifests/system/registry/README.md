# Summary
This is a locally-hosted container registry for hosting private images that aren't posted on DockerHub.

All data is stored on the NAS under `/share/appdata/vol/registry`. 

DockerFiles required for building the images are located on the [Docker](https://github.com/kenlasko/docker) repository.

# Kaniko cache pruning
The `registry-prune-cache` CronJob ([cronjob-prune-cache.yaml](base/cronjob-prune-cache.yaml)) runs Sundays at 4am (Toronto time). It keeps the Kaniko layer caches that Monize's `monize-build` job pushes (`monize/backend-cache` and `monize/frontend-cache`) from growing forever. In order:
1. `prune`: deletes every manifest in those repos that is older than 14 days, the age at which Kaniko stops using a cached layer. It lists the manifests from storage rather than by tag, so it also removes the untagged ones a re-pushed cache key leaves behind.
2. `garbage-collect`: `registry garbage-collect` frees the blobs nothing references any more.
3. `restart`: restarts the registry so its in-memory blob cache forgets the deleted blobs. The registry is unavailable for a few seconds.

Garbage collection runs against the live registry. A push that is in progress at that moment can lose blobs and would need repeating. That is why it runs at a quiet hour.

To run it now:
```
kubectl create job -n registry --from=cronjob/registry-prune-cache registry-prune-cache-$(date +%s)
```

