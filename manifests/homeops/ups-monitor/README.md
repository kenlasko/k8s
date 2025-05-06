# Summary
This is a pod that pulls UPS statistics from my "main" UPS, which is attached via USB. These statistics are used in Home Assistant for alerting and management of pods when on battery power.

It has to run on the node where the USB cable attached to the UPS is plugged into (currently NUC4). Accessing USB from a pod requires the [Smarter Device Manager](/manifests/system/smarter-device-manager) to expose USB ports to the pod.

All files are stored on the NAS, under `/share/appdata/vol/ups-monitor` and are regularly backed up via [Volsync](/manifests/system/volsync).

Most configuration is done via my [custom Helm chart](/helm/baseline).