#!/bin/sh

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not found" >&2; exit 1; }

kubectl get svc --all-namespaces -o json | jq -r '
  .items[]
  | select(.spec.type == "LoadBalancer")
  | select(.status.loadBalancer.ingress != null and (.status.loadBalancer.ingress | length > 0))
  | [.metadata.namespace, .metadata.name, (.status.loadBalancer.ingress[]?.ip // .hostname // "unknown")] | @tsv' | \
while IFS="$(printf '\t')" read -r ns name ip; do
  echo "Deleting service: $ns/$name (LoadBalancer IP/hostname: $ip)"
  kubectl delete svc "$name" -n "$ns"
done
