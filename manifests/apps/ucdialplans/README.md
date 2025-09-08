# Introduction
UCDialplans is my website that allows users to automatically create Teams dialplans for any country in the world. The image is built using Mono and is hosted locally on the internal image registry and on a private Docker repository.

It is accessible to the world via Cloudflare Tunnel.

Most configuration is done via my [custom Helm chart](/helm/baseline).

# Prerequisites
## Database
* Requires access to `ucdialplans` database on MariaDB via `UCDialplans_Website` user account. 
* Requires [InfoCache_Update](/manifests/database/mariadb/procedures.sql) procedure for periodically updating website usage numbers. 

# Disaster Recovery
Should the home cluster become unavailable for an extended period, UCDialplans.com can be switched to use my Oracle Cloud-based cluster. [MariaDB](/manifests/database/mariadb) is continuously backed up from on-prem, so a switch should be relatively easy. The only thing required is to switch the FQDNs for the Cloudflare Tunnel so that the Cloud tunnel is set to use www.ucdialplans.com and on-prem is switched to www2.ucdialplans.com.

1. Log onto https://dash.cloudflare.com/
2. Navigate to **Zero Trust**
3. Navigate to **Networks** - **Tunnels**
4. Edit the **20 Spring** tunnel 
5. Click on **Public hostname** and edit **www.ucdialplans.com**
6. Change the subdomain to **www3** and save
7. Edit the **20 Spring DR** tunnel and repeat the same steps, except change the subdomain from **www2** to **wwww**.
8. Save and exit

When the main cluster comes back online, simply reverse the steps when ready.
