# Summary
[Vaultwarden](https://github.com/dani-garcia/vaultwarden) is an open-source implementation of the [Bitwarden](https://bitwarden.com) password vault server. It works with all Bitwarden clients and is available via https://vaultwarden.ucdialaplans.com. The database is hosted on [PostgreSQL](/manifests/database/postgresql).

Most configuration is done via my [custom Helm chart](/helm/baseline)

The [PostgreSQL](/manifests/database/postgresql) database cluster replicates all databases to my Oracle Cloud cluster. This means that Vaultwarden could be easily moved to the cloud should a disaster befall my home cluster. All that would be required would be to scale up the StatefulSet to 1 (disabled to save the limited resources on my cloud cluster) and to create a [Pangolin](https://github.com/kenlasko/pangolin) tunnel pointing to it.