#!/bin/sh

# This script will set grastate.dat safetoboostrap to 1 for enabling a Galera cluster

FILE_PATH="/host/var/mariadb-galera/storage/grastate.dat"

kubectl debug node/$1 -it --image='nicolaka/netshoot' -n kube-system -- /bin/sh -c "sed -i -e 's/safe_to_bootstrap: 0/safe_to_bootstrap: 1/' $FILE_PATH; exit"
# Delete debugger pod after completion
kubectl get pods -n kube-system --no-headers=true  | awk '/node-debugger/{print $1}' | xargs kubectl delete -n kube-system pod
