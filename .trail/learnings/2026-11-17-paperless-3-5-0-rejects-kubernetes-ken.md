---
title: Paperless 3.5.0 rejects Kubernetes health probes because it stopped allowing every host when the public URL is set
author: Ken
date: 2026-11-17
branch: main
cost: { minutes: 1, tokens: 33976 }
id: l-db2aff9a
scope: repo
status: active
src: agent
touches:
  - helm/baseline/templates/deploy.yaml
  - manifests/apps/paperless/base/values.yaml
---

## Decided
The "Invalid HTTP_HOST header: '<pod IP>:8000'" errors come from the kubelet liveness probe, not from real traffic. The kubelet's httpGet probe sends the pod IP as the Host header. Up to v3.4.x, Paperless allowed every host unless PAPERLESS_ALLOWED_HOSTS was set. From v3.5.0, setting PAPERLESS_URL is enough to drop that wildcard: the allowed hosts become only the URL's hostname plus localhost. The probe then gets a 400, liveness fails three times, and the pod restarts about every 3 minutes (exit 137).

The best fix is a Host: localhost header on the probe. localhost is always allowed for Docker's healthcheck. Setting PAPERLESS_ALLOWED_HOSTS="*" would bring back the old, looser behavior.

## Watch out
Any other app on the baseline chart that adds a host allowlist will break the same way, because the chart's default probe has no Host header.

In the code:
- paperless/settings/__init__.py `_get_allowed_hosts()` in the 3.5.0 image
- helm/baseline/templates/deploy.yaml default livenessProbe (httpGet / on port http); override with livenessProbe in manifests/apps/paperless/base/values.yaml
