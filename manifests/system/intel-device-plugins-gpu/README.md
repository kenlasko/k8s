# Summary
The [Intel GPU Operator](https://intel.github.io/intel-device-plugins-for-kubernetes/cmd/gpu_plugin/README.html) loads the necessary drivers onto nodes that have Intel GPUs (NUC4-7). This allows [Plex](/manifests/media/plex) to use GPU transcoding instead of the less-efficient and more CPU-intensive transcoding.

The operator attempts to load drivers on any nodes that have the following node label: `intel.feature.node.kubernetes.io/gpu: true `