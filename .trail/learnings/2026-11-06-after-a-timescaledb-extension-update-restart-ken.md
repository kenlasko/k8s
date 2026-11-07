---
title: "After a TimescaleDB extension update, restart Tracearr so its pooled connections pick up the new version"
author: Ken
date: 2026-11-06
branch: main
cost: { minutes: 2, tokens: 8426 }
id: l-28a85f5b
scope: repo
status: active
src: agent
touches:
  - manifests/database/cnpg/overlays/cloud/cluster-cloud.yaml
  - manifests/database/cnpg/overlays/home/cluster-home.yaml
  - manifests/database/cnpg/overlays/home/cluster-standby.yaml
  - manifests/media/tracearr/base/database.yaml
---

## Decided
Every TimescaleDB bump ends with a Tracearr restart once the CNPG Database resource reports applied. Restarting the pod is the clean way to make its connection pool reconnect.

## Tried and ruled out
Waiting it out does not work. The pool keeps its old connections indefinitely, so the errors never clear on their own.

## Watch out
- Connections opened before ALTER EXTENSION keep the old library loaded. Every query on them fails with `"timescaledb" already loaded with a different version` until they reconnect.
- The Database resource can keep an error from before the pod restart for a minute or so. Check observedGeneration against generation before trusting the message.
- With primaryUpdateMethod "restart", CNPG restarts the primary right after the replicas finish. There's no practical window to promote a replica first during an image rollout.

In the code:
- manifests/media/tracearr/base/database.yaml: extension version reconciled by CNPG
- kubectl -n media delete pod tracearr-0 (StatefulSet recreates it)
- kubectl -n cnpg get database tracearr -o jsonpath='{.metadata.generation} {.status.observedGeneration} {.status.applied}'
