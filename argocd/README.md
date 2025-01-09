# Introduction
[Argo CD](https://github.com/argoproj/argo-cd) is the tool that declaratively manages every application running in the Kubernetes cluster. Every configuration setting is stored in this Github repo, which means that the entire cluster can be rapidly rebuilt without much work.

This deployment makes use of the Argo CD "app of apps" approach, which theoretically means that once Argo CD is bootstrapped and connected to the repository, every other application can automatically be installed and configured. In actual fact, this is only partially true. Once Argo CD is running, the remaining applications have to be installed in a rather specific order, owing to the requirement of restoring [MariaDB databases](/mariadb) and [Longhorn](/longhorn) volumes before many workloads can function. I am working towards full automation, but am not there yet.

The app-of-apps approach has two "sections": 

## argocd-apps
The [argocd-apps](/argocd/argocd-apps) folder contains the application definitions for all the applications that do not depend on Longhorn volumes. This also includes Longhorn, ironically. This is "generated" by the [argocd-apps](/argocd/argocd-apps.yaml) application. Each application has to be manually triggered and generally follows the pattern of:
* app prerequisites such as [sealed-secrets](/sealed-secrets), [cert-manager](/cert-manager), [cloudflare-tunnel](/cloudflare-tunnel) etc.
* [MariaDB](/mariadb) databases and [Longhorn](/longhorn) volumes
* other applications such as [Home Assistant and supporting apps](/home-automation), [VaultWarden](/vaultwarden), [UCDialplans](/ucdialplans) etc which rely on databases but can start without the databases present without much ill-effect (other than a possible pod restart once the database is restored)

I am experimenting with [Argo CD sync-waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/) to control the order of installation of these tools, so the installation can be automated.

## media-tools
The [media-tools](/media-tools) group of applications are all related to media, including [Plex](/media-tools/plex), [Sonarr](/media-tools/sonarr), [Radarr](/media-tools/radarr) etc. This is "generated" by the [media-tools](/argocd-apps/media-tools.yaml) application. They **REQUIRE** the restoration of the backed-up Longhorn volumes is complete before starting up, otherwise they will create new empty volumes with default settings. It isn't impossible to recover from this, but its a waste of time that can be avoided. Once Longhorn is up and running and all the media-tools volumes are restored from NFS, then the media-tools application can be triggered, which will build all the media-tools applications.

# Adding a new Helm chart installation
1. Edit [values.yaml](/argocd/values.yaml) and add a Helm repository under `configs.repositories`
2. Create an Argo CD application in [argocd-apps](/argocd-apps) using an existing yaml as a template

# Troubleshooting
## ArgoCD apps showing as `Unknown`
Restart ArgoCD pods in this order:
1. argocd-dex-server
2. argocd-application-controller
3. argocd-server

# Other Info
## Temporarily Disabling Updates
When going on vacation, its prudent to disable auto-updates of resources. This can be relatively easily done en-masse by doing a `Find in Folder` in VSCode for `selfHeal: true` with `null #temporarily disabled for vacation`. The comment helps to avoid accidentally replacing nulls from other manifests when reverting. Make sure to exclude `README.md` or else it will screw up this document. To resume auto-updates, do the opposite.

## Get Initial Password
When ArgoCD is first installed, it auto-generates the admin password. Running this command will get the initial password so you can login for the first time.
```
kubectl -n argocd get secret argocd-initial-admin-secret \
          -o jsonpath="{.data.password}" | base64 -d; echo
```