# Summary
[Mealie](https://github.com/mealie-recipes/mealie) is a self-hosted recipe manager, meal planner and shopping list application. I use it to keep my recipes in one place and plan meals. It is available at https://mealie.laskonet.com (also reachable via `recipes.laskonet.com`).

Logins are handled via OIDC against my [Pocket ID](/manifests/system/pocket-id) instance at `auth.laskonet.com`.

Stateful data is stored on the NAS via NFS and backed up nightly to Cloudflare S3 storage via [Volsync](/manifests/system/volsync).

It requires [PostgreSQL](/manifests/database/cnpg) to run.

Most configuration is done via my [custom Helm chart](/helm/baseline).
