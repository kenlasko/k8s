# Summary
[Pocket-ID](https://github.com/pocket-id/pocket-id) is a simple and easy-to-use OIDC provider that allows users to authenticate with their passkeys to your services. As its description notes, it does exactly what it says on the tin. No muss, no fuss. I'm using this to provide OIDC logins for all apps that support it, including:
- [Grafana](/manifests/monitoring/promstack)
- [Home Assistant](manifests/homeops/homeassist)
- [Kite](/manifests/system/kite)
- [Mealie](/manifests/apps/mealie)
- [Pangolin](https://github.com/kenlasko/pangolin)
- [Paperless](/manifests/apps/paperless)
- [PGAdmin](/manifests/database/pgadmin)
- [Portainer](/manifests/apps/portainer)
- [Vaultwarden](/manifests/apps/vaultwarden)

# OAuth2Proxy
For workloads that don't support OIDC directly, I employ [OAuth2Proxy](https://oauth2-proxy.github.io/oauth2-proxy/) to act as a gatekeeper. This works by adding an OAuth2Proxy sidecar container to the application's pod. An additional service is created for OAuth and the HTTPRoute is pointed to this service. This ensures that any existing integrations that are likely not OIDC-compatible will continue functioning without error.

The authentication flow looks like this:
```
                                                                   Pocket-ID 
                                                                       | 
User Browser --> Cilium Gateway API --> HTTPRoute --> Service --> OAuth2Proxy --> Application
```

My [custom Helm chart](/helm/baseline) includes all the necessary services, HTTPRoutes and deployment changes to add OAuth2Proxy support to any application:
```
oidc:
  enabled: true
  secretName: env-secrets
```

The secret must include the following values:
- `OAUTH2_PROXY_CLIENT_ID` (from OIDC provider ie Pocket-ID)
- `OAUTH2_PROXY_CLIENT_SECRET` (from OIDC provider)
- `OAUTH2_PROXY_COOKIE_SECRET` (generated from below)

The `OAUTH2_PROXY_COOKIE_SECRET` can be generated via the following:
```
dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 | tr -d -- '\n' | tr -- '+/' '-_' ; echo
```