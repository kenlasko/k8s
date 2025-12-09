#!/bin/sh

# Check for required tools
for tool in kubectl kustomize; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Error: '$tool' is not installed or not in PATH. Please install it before running this script."
    exit 1
  fi
done

requested_context="$1"

# Get list of available contexts
available_contexts=$(kubectl config get-contexts -o name)
current_context=$(kubectl config current-context)

# Function to let user select a context from the list
select_context_from_list() {
  while :; do
    echo "Available kubectl contexts:"
    i=1
    for ctx in $available_contexts; do
      echo "$i. $ctx"
      eval context_$i=\$ctx
      i=$((i + 1))
    done

    total=$((i - 1))
    while :; do
      printf "Select the number of the kubectl context to use [1-$total]: "
      read context_number

      case "$context_number" in
        ''|*[!0-9]*) echo "Please enter a valid number."; continue ;;
      esac

      if [ "$context_number" -ge 1 ] && [ "$context_number" -le "$total" ]; then
        eval temp_context=\$context_"$context_number"
        break
      else
        echo "Invalid selection. Try again."
      fi
    done

    printf "Use context '$temp_context'? [y/N]: "
    read confirm
    case "$confirm" in
      y|Y)
        selected_context="$temp_context"
        echo "Switching to selected context: $selected_context"
        kubectl config use-context "$selected_context"
        break
        ;;
      *)
        echo "Let's try again."
        ;;
    esac
  done
}

# Logic to determine context
if [ -n "$requested_context" ]; then
    for ctx in $available_contexts; do
        if [ "$ctx" = "$requested_context" ]; then
           selected_context="$ctx"
           break
        fi
    done
    if [ -z "$selected_context" ]; then
        echo "Context '$requested_context' not found."
        select_context_from_list
    fi
else
    echo "Current context is: $current_context"
    printf "Use current context? [Y/n]: "
    read use_current
    case "$use_current" in
    n|N)
        select_context_from_list
    ;;
    *)
        selected_context="$current_context"
    ;;
  esac
fi


# Determine GIT_CLUSTER from selected context
case "$selected_context" in
    omni-*)
        GIT_CLUSTER=${selected_context#omni-}
    ;;
    *)
        GIT_CLUSTER=$selected_context
    ;;
esac

echo "GIT_CLUSTER set to: $GIT_CLUSTER"
echo "Checking if cluster '$selected_context' is reachable..."

if kubectl get nodes --context="$selected_context" >/dev/null 2>&1; then
    echo "Cluster '$selected_context' is up and reachable."
else
    echo "Creating $GIT_CLUSTER cluster..."
    omnictl cluster template sync -f ~/omni/cluster-template-$GIT_CLUSTER.yaml
fi

echo "Building manifest lists..."

kustomize build ~/k8s/manifests/network/cilium/overlays/$GIT_CLUSTER/ --enable-helm --load-restrictor LoadRestrictionsNone > ~/cilium.yaml
kustomize build ~/k8s/manifests/system/external-secrets/overlays/$GIT_CLUSTER/ --enable-helm --load-restrictor LoadRestrictionsNone > ~/external-secrets.yaml
kustomize build ~/k8s/manifests/system/cert-manager/overlays/$GIT_CLUSTER/ --enable-helm --load-restrictor LoadRestrictionsNone > ~/cert-manager.yaml
kustomize build ~/k8s/manifests/system/csi-drivers/overlays/$GIT_CLUSTER/ --enable-helm --load-restrictor LoadRestrictionsNone > ~/csi-drivers.yaml
kustomize build ~/k8s/manifests/database/redis/overlays/$GIT_CLUSTER/ --enable-helm --load-restrictor LoadRestrictionsNone > ~/redis.yaml
kustomize build ~/k8s/argocd/overlays/$GIT_CLUSTER/ --enable-helm --load-restrictor LoadRestrictionsNone > ~/argocd.yaml

# Delete the build charts
echo "Deleting temporary build charts..."
rm -rf ~/k8s/manifests/network/cilium/overlays/$GIT_CLUSTER/charts
rm -rf ~/k8s/manifests/system/external-secrets/overlays/$GIT_CLUSTER/charts
rm -rf ~/k8s/manifests/system/cert-manager/overlays/$GIT_CLUSTER/charts
rm -rf ~/k8s/manifests/system/csi-drivers/overlays/$GIT_CLUSTER/charts
rm -rf ~/k8s/manifests/database/redis/overlays/$GIT_CLUSTER/charts
rm -rf ~/k8s/argocd/overlays/$GIT_CLUSTER/charts

# Wait for the cluster to respond before continuing
echo "Waiting for cluster '$selected_context' to become reachable..."
# Retry for up to 3 minutes (12 tries with 15s interval)
for i in $(seq 1 12); do
    if kubectl get nodes --context="$selected_context" >/dev/null 2>&1; then
        echo "Cluster '$selected_context' is now reachable."
        break
    fi
    echo "Still waiting... ($i/12)"
    sleep 15
done

# Final check
if ! kubectl get nodes --context="$selected_context" >/dev/null 2>&1; then
    echo "Error: Cluster '$selected_context' is still not reachable after trying to start it."
    exit 1
fi

# Apply secretstore secrets from /run/secrets/eso-secretstore-secrets.yaml
echo "Applying External-Secrets secretstore secrets..."
kubectl apply -f ~/k8s/manifests/system/external-secrets/base/namespace.yaml
kubectl apply -f /run/secrets/eso-secretstore-secrets.yaml

# Track per-manifest success
cilium_ok=false
external_ok=false
cert_ok=false

while true; do
    if [ "$cilium_ok" = false ]; then
        echo "Applying Cilium manifests..."
        if kubectl apply -f ~/cilium.yaml; then
            cilium_ok=true
            echo "✅ Cilium manifests applied successfully."
        else
            echo "❌ Cilium apply failed. Will retry."
        fi
    fi

    if [ "$external_ok" = false ]; then
        echo "Applying External-Secrets manifests..."
        if kubectl apply --server-side -f ~/external-secrets.yaml; then
            external_ok=true
            echo "✅ External-Secrets manifests applied successfully."
        else
            echo "❌ External-Secrets apply failed. Will retry."
        fi
    fi

    if [ "$cert_ok" = false ]; then
        echo "Applying Cert-Manager manifests..."
        if kubectl apply -f ~/cert-manager.yaml; then
            cert_ok=true
            echo "✅ Cert-Manager manifests applied successfully."
        else
            echo "❌ Cert-Manager apply failed. Will retry."
        fi
    fi

    if [ "$cilium_ok" = true ] && [ "$external_ok" = true ] && [ "$cert_ok" = true ]; then
        echo "🎉 All manifests applied successfully!"
        break
    fi

    echo "🔁 Some resources not ready. Waiting 30 seconds before retry to give existing resources time to settle..."
    sleep 30
done

echo "Applying CSI Drivers, Redis, and ArgoCD manifests..."
if [ "$GIT_CLUSTER" != "cloud" ]; then
    kubectl apply -f ~/csi-drivers.yaml
else
    echo "Skipping CSI Drivers for cluster '$GIT_CLUSTER'"
fi

kubectl apply -f ~/redis.yaml
kubectl apply -f ~/argocd.yaml

echo "✅ All manifests applied successfully!"