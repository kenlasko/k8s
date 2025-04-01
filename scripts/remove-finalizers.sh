#!/bin/sh

# Define the namespace you want to delete
NAMESPACE=$1

# Check if the namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "Namespace $NAMESPACE does not exist."
  exit 1
fi

# Remove finalizers from resources in the namespace
for resource in $(kubectl api-resources --verbs=list --namespaced -o name); do
  for name in $(kubectl -n "$NAMESPACE" get "$resource" -o name); do
    echo "Removing finalizers from $name in namespace $NAMESPACE..."
    kubectl -n "$NAMESPACE" patch "$name" -p '{"metadata":{"finalizers":[]}}' --type=merge
  done
done

# Remove finalizers from the namespace itself
echo "Removing finalizers from the namespace $NAMESPACE..."
kubectl patch namespace "$NAMESPACE" -p '{"metadata":{"finalizers":[]}}' --type=merge

# Finally, delete the namespace
echo "Deleting namespace $NAMESPACE..."
kubectl delete namespace "$NAMESPACE"
