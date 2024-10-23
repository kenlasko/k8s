# Introduction
UCDialplans is my website that allows users to automatically create Teams dialplans for any country in the world. The image is built using Mono and is hosted locally on the internal image registry.

It is accessible to the world via Cloudflare Tunnel.

# Prerequisites
## Database
* Requires access to `ucdialplans` database on MariaDB via `UCDialplans_Website` user account. 
* Requires [InfoCache_Update](/mariadb/procedures.yaml) procedure for periodically updating website usage numbers. 