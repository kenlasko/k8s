# Introduction
[Pangolin](https://github.com/fosrl/pangolin) is a Wireguard-based replacement for [Cloudflared Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deploy-tunnels/deployment-guides/kubernetes/), which gives me more options for security and is performing much better than Cloudflare over the past week or so.

# Application Deployment
Pangolin Server is deployed in Oracle Cloud and the "Pangolin Agent" called Newt is installed in the cluster. Access to different apps is managed in much the same way as Cloudflare, where you specify the internal DNS address of the service (ie `appname.namespace.svc.cluster.local`). Right now, only the UCDialplans website is active on this.

