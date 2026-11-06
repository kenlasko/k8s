---
title: "Renovate bumps the TimescaleDB image tag but never its digest, so the cluster silently stays on the old build"
author: Ken
date: 2026-11-06
branch: main
cost: { minutes: 2, tokens: 48718 }
id: l-6f3e2c8b
scope: repo
status: active
src: agent
touches:
  - renovate.json
---

## Decided
The pinned digest is what CNPG actually pulls, so the tag in the reference means nothing on its own. After any TimescaleDB bump, check that the digest changed too. The fix is to make the Renovate regex capture the digest, so Renovate updates it along with the tag.

## Tried and ruled out
Restarting the pods does not help. All pods already mount the "2.31.0"-tagged reference, but the digest pins an Oct 1 build containing only 2.30.0/2.30.1.

## Watch out
- The image ships only the current release's libraries plus one previous release's. Tracearr's database is on 2.30.1, and the real 2.31.0 image carries 2.31.0 + 2.30.2. Jumping straight to it removes the library Tracearr's database is still loading. Go through the 2.30.2 image first (it carries 2.30.1 + 2.30.2), ALTER EXTENSION to 2.30.2, then move to 2.31.0.
- The symptom shows on the Tracearr Database resource as "database object reconciliation failed", with the extension message "has no update path from 2.30.1 to 2.31.0". Nothing on the Cluster resource looks wrong.

In the code:
- renovate.json custom regex for ghcr.io/kenlasko/timescaledb-cnpg matches only `(?<currentValue>[^@\s]+)`, with no currentDigest group
- manifests/database/cnpg/overlays/{home,cloud}/cluster-*.yaml: the digest has been sha256:3892e5fa... since the 2.30.1 pin (c05be64c3)
- Real digests: 2.30.2-18-trixie sha256:06f65e5c..., 2.31.0-18-trixie sha256:43817b1e...
- Only home/tracearr has the timescaledb extension installed
