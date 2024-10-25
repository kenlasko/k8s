# Introduction
[Velero](https://velero.io/) is the chosen backup system for the cluster.

# Configuration
The default backup location is an S3 bucket called `kube` on the NAS. Ensure this bucket exists before deploying Velero.