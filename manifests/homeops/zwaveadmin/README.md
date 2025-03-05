# Summary
The [Z-Wave JS UI](https://github.com/zwave-js/zwave-js-ui) application controls all my Z-Wave lights in the house. It integrates with [Home Assistant](/manifests/homeops/homeassist) for easy control and management of all my lights.

It has to run on the node where the Z-Wave dongle is plugged into (currently NUC4). Accessing USB from a pod requires the [Smarter Device Manager](/manifests/system/smarter-device-manager) to expose USB ports to the pod.

All files are stored on the NAS, under `/share/appdata/vol/zwaveadmin` and are regularly backed up.