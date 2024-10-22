# Introduction
[AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) provides DNS ad-blocking for my internal network along with my devices when outside the home.

# Configuration
The [AdGuard Home instance](/adguard) on Kubernetes is the primary instance of a 3-instance "cluster" of sorts. The other two are running in Docker on standalone Raspberry Pis and are synced with the primary via [AdGuard-Sync](https://github.com/bakito/adguardhome-sync).

DNS is serviced from the primary via DNS port 53 and HTTPS port 853 on `192.168.1.16`. The RPis are serving DNS port 53 on `192.168.1.17` and `192.168.1.18`. 

HTTPS-based DNS is publically available via port 853 via `*.dns.ucdialplans.com`.  It is port-forwarded to `192.168.1.16` via my Unifi Dream Machine Pro. Only approved hosts are able to use it. Currently, only my Pixel phone is on the list.

Stateful files are stored and accessed on the NAS via NFS through `/appdata/vol/adguard`