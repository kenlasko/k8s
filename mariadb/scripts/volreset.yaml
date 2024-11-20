#!/bin/bash

# This script will delete the contents of a given folder on all the selected nodes. Used for clearing out mariadbfolders before a new cluster build

NODES=("nuc4" "nuc5" "nuc6")
FOLDER_PATH="/host/var/mariadb-galera/*"

for NODE_NAME in "${NODES[@]}"; do
        kubectl debug node/$NODE_NAME -it --image='nicolaka/netshoot' -n kube-system -- /bin/sh -c "rm -rf $FOLDER_PATH; rm -rf $FOLDER_PATH/.bootstrap; exit"
        # Delete debugger pod after completion
        kubectl get pods -n kube-system --no-headers=true  | awk '/node-debugger/{print $1}' | xargs kubectl delete -n kube-system pod
done
