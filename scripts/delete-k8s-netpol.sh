#!/bin/sh

# Get all namespaces
kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | while IFS= read -r ns; do
  echo "Checking namespace: $ns"
  # Get all NetworkPolicies in this namespace
  netpols=$(kubectl get networkpolicy -n "$ns" -o name 2>/dev/null)
  if [ -n "$netpols" ]; then
    echo "$netpols" | while IFS= read -r netpol; do
      echo "Deleting $netpol in namespace $ns"
      kubectl delete "$netpol" -n "$ns"
    done
  fi
done
