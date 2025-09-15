# Introduction
[AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) provides DNS ad-blocking for my internal network along with my devices when outside the home.

# Configuration
The [AdGuard Home instance](/manifests/apps/adguard) on Kubernetes is the primary instance of a 4-instance "cluster" of sorts synced with the primary via [AdGuard-Sync](https://github.com/bakito/adguardhome-sync).

For home, the primary instance along with 2 Docker-based instances on standalone Raspberry Pis provide highly-available DNS services. DNS is serviced from the primary via DNS port 53 and HTTPS port 853 on `192.168.1.16`. The RPis are serving DNS port 53 on `192.168.1.17` and `192.168.1.18`. 

For outside the home, an instance running on my [Oracle Cloud Omni cluster](https://github.com/kenlasko/k3s-cloud/adguard) provides DNS services over TLS (DoH). Only approved hosts are able to use it. Currently, only my Pixel phone is on the list.

Stateful files are stored and accessed on the NAS via NFS through `/appdata/vol/adguard`. It is regularly backed up to Cloudflare S3 storage via [Volsync](/manifests/system/volsync).

Most configuration is done via my [custom Helm chart](/helm/baseline).

# Notes
## Adguard Sync Error
Adguard Sync throws this error about cloud-adguard on every sync

```
ERROR sync sync/action-general.go:247 error setting tls config {"from": "adguard-service:3000", "to": "cloud-adguard-link:3000", "enabled": true, "error": "400 Bad Request(port 443 for HTTPS is not available\n)"}
```

It's trying to set TLS to enabled along with the port 443, but for whatever reason, the cloud instance does not allow port 443. I've manually set it to 8443 in `AdGuardHome.yaml`, which allows everything to work. Syncing works fine other than this one setting.

The error can be safely ignored.

