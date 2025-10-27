# Introduction
Redis is a fast, in-memory key-value database often used for caching, real-time data, and message brokering. Redis is used by the following applications:
- [ArgoCD](/argocd)
- [NextCloud](/manifests/apps/nextcloud)
- [Paperless](/manifests/apps/paperless)
- [Immich](/manifests/media/immich)

Since it is an app that is required by ArgoCD, it is part of the initial [cluster bootstrapping process](/#initial-cluster-setup).

## Tips and Tricks
### Deleting a tree
The following safely deletes the entire `immich_bull` tree without blocking Redis:
```
EVAL "local c='0' repeat local r=redis.call('SCAN',c,'MATCH',ARGV[1],'COUNT',1000) c=r[1] for _,k in ipairs(r[2]) do redis.call('DEL',k) end until c=='0' return true" 0 "immich_bull:*"

```