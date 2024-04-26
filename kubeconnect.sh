#!/bin/sh
kubectl debug node/$1 -it --image='nicolaka/netshoot' -n kube-system
# Delete debugger pod after completion
kubectl get pods -n kube-system --no-headers=true  | awk '/node-debugger/{print $1}' | xargs kubectl delete -n kube-system pod
