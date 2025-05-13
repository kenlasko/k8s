#!/bin/sh

# Define the namespace where Cilium is running
namespace="cilium"

# Define the name of the Cilium DaemonSet
daemonset_name="cilium"

# Get the names of the Cilium pods
cilium_pods=$(kubectl get daemonset "$daemonset_name" -n "$namespace" -o jsonpath='{.status.desiredNumberScheduled}' | xargs -I{} kubectl get pods -n "$namespace" -l k8s-app="$daemonset_name" -o jsonpath='{.items[*].metadata.name}')

if [ -z "$cilium_pods" ]; then
  echo "Error: Could not find any Cilium pods in namespace '$namespace'."
  exit 1
fi

echo "Restarting Cilium DaemonSet '$daemonset_name' in namespace '$namespace'..."

# Option 1: Rolling restart using kubectl rollout restart (Recommended)
# This is the safest and most graceful way to restart the DaemonSet.
# It will update pods one by one, ensuring minimal disruption.
kubectl rollout restart daemonset "$daemonset_name" -n "$namespace"

echo "Cilium DaemonSet restart initiated. You can check the status with:"
echo "kubectl rollout status daemonset/$daemonset_name -n $namespace"

# Option 2: Forcefully delete pods (Less Recommended, can cause temporary network issues)
# This will immediately terminate the pods, and the DaemonSet will recreate them.
# This can lead to temporary network connectivity issues.
#
# echo "Forcefully deleting Cilium pods..."
# kubectl delete pods -n "$namespace" "$cilium_pods"
# echo "Cilium pods are being recreated."

echo "Done."
exit 0
