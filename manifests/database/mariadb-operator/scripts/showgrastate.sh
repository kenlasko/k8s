#!/bin/bash

# This script will show the contents of grastate.dat on all nodes. Used for Galera cluster recovery

NODES=("nuc4" "nuc5" "nuc6")
FILE_PATH="/host/var/mariadb/data/grastate.dat"

for NODE_NAME in "${NODES[@]}"; do
        echo "===================== $NODE_NAME ====================="
        kubectl debug node/$NODE_NAME -it --image='nicolaka/netshoot' -n kube-system -- /bin/sh -c "cat $FILE_PATH; exit"
        # Delete debugger pod after completion
        kubectl get pods -n kube-system --no-headers=true  | awk '/node-debugger/{print $1}' | xargs kubectl delete -n kube-system pod
done
