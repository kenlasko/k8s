#!/bin/sh

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
  printf "Use current context? [y/N]: "
  read use_current
  case "$use_current" in
    y|Y)
      selected_context="$current_context"
      ;;
    *)
      select_context_from_list
      ;;
  esac
fi


# Create namespaces once (skip if already exists)
kubectl create namespace cilium --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace redis --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
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
    if kubectl apply -f ~/external-secrets.yaml; then
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

  echo "🔁 Some resources not ready. Waiting 10 seconds before retry..."
  sleep 10
done

kubectl apply -f ~/csi-drivers.yaml
kubectl apply -f ~/redis.yaml
kubectl apply -f ~/argocd.yaml