# Introduction
UCDialplans is my website that allows users to automatically create Teams dialplans for any country in the world. The image is built using Mono and is hosted locally on the internal image registry and on a private Docker repository.

It is accessible to the world via my ~~[Cloudflare Tunnel](/manifests/network/cloudflare)~~ Oracle Cloud-based [Pangolin](https://github.com/kenlasko/pangolin) deployment.

Backend storage is provided by [PostgreSQL](/manifests/database/postgresql).

Most configuration is done via my [custom Helm chart](/helm/baseline).

# Prerequisites
## Database
* Requires access to `ucdialplans` database on [PostgreSQL](/manifests/database/postgresql) via `ucdialplans` user account. 
* Requires [InfoCache_Update](/manifests/apps/ucdialplans/cronjob-statupdate.yaml) procedure for periodically updating website usage numbers. 

# Disaster Recovery
Should the home cluster become unavailable for an extended period, UCDialplans.com can be switched to use my Oracle Cloud-based cluster. [PostgreSQL](/manifests/database/postgresql) is continuously backed up from on-prem, so a switch should be relatively easy. 

## Pangolin
Very simple process:
1. Login to [Pangolin](https://pangolin.ucdialplans.com)
2. On the left side, select `Resources` and click on `Edit` beside `UCDialplans Website`
3. Under `Targets List`, change the `Site` from `K8S Home` to `K8S Cloud` and then click on `Save Settings`

## Cloudflare Tunnel (Deprecated)
The only thing required is to switch the FQDNs for the Cloudflare Tunnel so that the Cloud tunnel is set to use www.ucdialplans.com and on-prem is switched to www2.ucdialplans.com.

1. Log onto https://dash.cloudflare.com/
2. Navigate to **Zero Trust**
3. Navigate to **Networks** - **Tunnels**
4. Edit the **20 Spring** tunnel 
5. Click on **Public hostname** and edit **www.ucdialplans.com**
6. Change the subdomain to **www3** and save
7. Edit the **20 Spring DR** tunnel and repeat the same steps, except change the subdomain from **www2** to **wwww**.
8. Save and exit

When the main cluster comes back online, simply reverse the steps when ready.