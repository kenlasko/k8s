#!/bin/sh

# This script lists all PVCs that are bound to a specific storage class and outputs the pvc names to a file.
# This is then used on NAS01 to delete all the unused PVCs via the script delete-unused-pvc.sh

kubectl get pvc --all-namespaces -o json |   jq -r '.items[] | select(.spec.storageClassName == "nfs-csi-dynamic" and .status.phase == "Bound") | .spec.volumeName' > pvc.txt