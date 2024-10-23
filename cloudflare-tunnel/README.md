# Introduction
[Cloudflared Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deploy-tunnels/deployment-guides/kubernetes/) allows me to expose web services to the Internet without having to open any ports on my Unifi firewall. This is much preferred, as Cloudflare provides security and protection for services. Follow the steps in the above link to get it installed. 

# Application Deployment
Exposing a service to the Internet requires two Cloudflare objects:
* a public hostname exposed through the tunnel that connects to the relevent Kubernetes service
* an Access application to control access to the app

## Access Application
This feature allows for controlling access to applications using Cloudflare's security services. 

### Prerequisites
* Setup one or more [Identity Providers](https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/)
* Setup one or more [Access groups](https://developers.cloudflare.com/cloudflare-one/identity/users/groups/)

### Access app setup (for applications to be kept private)
1. In the [Cloudflare Dashboard](https://dash.cloudflare.com), navigate to `Zero-Trust` - `Access` - `Applications`
2. Click on `Add an application`
3. Click on `Select` underneath `Self-hosted`
4. Enter a name for the application, such as `Sonarr` or `Radarr`
5. Enter an appropriate subdomain/domain/path, such as `sonarr.ucdialplans.com`
6. For Application Appearance, you can enable the app to show in the [App Launcher](https://kenlasko.cloudflareaccess.com/) and modify the icon and tags if desired
7. Select the appropriate identity provider
8. Click `Next`
9. Enter a `Policy name`, such as `Default`, and assign a group
10. Click `Next`
11. Under `Cookie settings`, enable the following:
    * HTTP Only
    * Enable Binding Cookie
    * Enforce cookie path attribute
    * Same Site Attribute = Lax
12. Click `Add application`


## Public Hostname
1. In the [Cloudflare Dashboard](https://dash.cloudflare.com), navigate to `Zero-Trust` - `Networks` - `Tunnels`
2. Select the appropriate tunnel and click `Edit`
3. Navigate to the `Public Hostname` tab, and select `Add a public hostname`
4. Add a subdomain appropriate for the app, such as `sonarr` or `radarr`. Select the appropriate domain from the dropdown
5. Under `Service`, select `HTTP` for the type and type in the internal Kubernetes cluster URL to the service, including the port. Examples:
    * radarr-service.media-tools.svc.cluster.local:7878
    * homeassist-service.homeassist.svc.cluster.local:8123
6. Under `Additional application settings`, expand `Access`, turn it on and select the Access application created in the previous section.
7. Press `Save hostname`