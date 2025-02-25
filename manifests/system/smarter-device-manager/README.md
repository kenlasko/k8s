# Summary
The [Smarter Device Manager] makes local devices available in pods that require it. It is used in this cluster for the following:
* USB devices
    * [Home Assistant](/manifests/home-automation/homeassist)
    * [UPS Monitor](/manifests/home-automation/ups-monitor)
    * [ZWave Admin](/manifests/home-automation/zwaveadmin)
* /dev/tun devices
    * [Tailscale](/manifests/network/tailscale)

# Configuration
To make USB devices available to pods, add `smarter-devices/<USB-Device-Name>: 1` to the pod's `spec.template.spec.resources.requests` and `spec.template.spec.resources.limits`

To make /dev/tun devices available to pods, add `smarter-devices/net_tun: "1"` to the container limits. This currently only applies to [Tailscale](/manifests/network/tailscale).