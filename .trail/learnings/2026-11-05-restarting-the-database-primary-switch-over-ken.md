---
title: "Restarting the database primary: switch over first, and keep smart shutdown short"
author: Ken
date: 2026-11-05
branch: main
cost: { minutes: 1, tokens: 52533 }
id: l-b98563c6
scope: repo
status: active
src: agent
touches:
  - manifests/database/cnpg/overlays/home/cluster-home.yaml
---

## Decided
The home CNPG cluster's smart shutdown is capped at 10s. With CNPG's 180s default, a stopping primary refused every new connection for the full 3 minutes, because pooled clients never disconnect on their own. The operator also can't promote a replica until the old primary is fully down, so nothing could connect anywhere during that time. The outage was measured on 2026-11-05: the primary got SIGTERM at 00:56:24, Postgres stopped at 00:59:24, and a replica was promoted at 00:59:36.

## Tried and ruled out
- stopDelay (1800) is not what makes it slow. It is only the upper limit, and the shutdown finished long before reaching it.
- failoverDelay 30 stays. It deliberately gives an OOM-killed primary time to restart in place, so it doesn't fork the replicas onto another timeline.

## Watch out
- Before a planned node reboot, drain the node. CNPG sees the primary's node draining and switches over by itself, and the primary PDB (0 allowed disruptions) holds the eviction until that's done. Uncordon afterwards. Restarting or rebooting without a drain still costs about 10s plus failoverDelay.
- To restart only the primary pod, promote a replica first.
- primaryUpdateMethod is still "restart", so operator-driven updates restart the primary in place. "switchover" would avoid that, but it hasn't been adopted.
- The cloud overlay and the standby cluster still use the 180s default.

In the code:
- manifests/database/cnpg/overlays/home/cluster-home.yaml: smartShutdownTimeout: 10
- Drain the node: kubectl drain <node> --ignore-daemonsets --delete-emptydir-data, then kubectl uncordon <node>
- Promote a replica: kubectl cnpg promote home <replica-pod>
