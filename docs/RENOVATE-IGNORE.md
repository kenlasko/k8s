# Excluding an app from Renovate auto-upgrades

Sometimes an automatic image update breaks an app and the fix is to pin the image back to a known-good version. Renovate's built-in managers (`kubernetes`, `helm-values`, `kustomize`) cannot read comments or Kubernetes annotations, so on its own Renovate would immediately try to upgrade the pinned image again. Instead of hand-editing `renovate.json` every time, this repo uses a `# renovate: ignore` annotation directly in the manifest.

## How to use it

Pin the image to the working version and append `# renovate: ignore` to the version line:

**Baseline Helm chart `values.yaml` (helm-values manager):**
```yaml
image:
  repository: 11notes/radarr
  tag: 6.2.0 # renovate: ignore
  registry: ghcr.io
```

**Plain deployment/cronjob manifest (kubernetes manager):**
```yaml
image: ghcr.io/foo/bar:v1.2.3 # renovate: ignore
```

**Kustomize image override (kustomize manager):**
```yaml
images:
  - name: ghcr.io/foo/bar
    newTag: v1.2.3 # renovate: ignore
```

**Explicit form** (anywhere in any YAML file, for cases where the image name can't be inferred from the surrounding lines, e.g. custom regex managers):
```yaml
# renovate: ignore=ghcr.io/foo/bar
```

Then commit and push to `main`. The [renovate-ignore-sync GitHub Action](/.github/workflows/renovate-ignore-sync.yaml) runs [scripts/update-renovate-ignores.py](/scripts/update-renovate-ignores.py) on every push to `main` that touches manifests, and auto-commits the result. The script regenerates a managed rule at the end of `packageRules` in [renovate.json](/renovate.json):

```json
{
  "description": "Managed by scripts/update-renovate-ignores.py - do not edit. ...",
  "matchPackageNames": [
    "11notes/radarr",
    "ghcr.io/11notes/radarr"
  ],
  "enabled": false
}
```

Once that sync commit lands on `main`, Renovate stops proposing any updates for those images.

The same sync also runs locally as a [pre-commit](/docs/COMMIT-PRECHECK.md) hook (requires `pre-commit install` in the clone), which keeps `renovate.json` in the same commit as the annotation and closes the small window where Renovate could re-upgrade the image before the Action's sync commit lands. If the hook modifies `renovate.json`, pre-commit stops the commit; re-stage the file (`git add renovate.json`) and commit again. The script can also be run manually at any time:

```sh
python3 scripts/update-renovate-ignores.py
```

## Re-enabling updates

Delete the `# renovate: ignore` comment from the manifest and commit. The hook removes the image from the managed rule and Renovate resumes upgrading it as usual.

## Notes

* The script scans `manifests/`, `argocd/`, `argocd-appsets/` and `helm/` (skipping `archive/`).
* For `values.yaml` files with a separate `registry:` key, both `repository` and `registry/repository` forms are added to the rule, so it matches regardless of how Renovate names the dependency.
* The managed rule is placed last in `packageRules` so it takes precedence over the automerge rules, and it is entirely owned by the script — don't edit it manually, and don't add your own rules with the same description.
* `enabled: false` disables *all* update types (major/minor/patch/digest) for the image everywhere in the repo.
