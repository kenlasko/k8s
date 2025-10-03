#!/bin/sh

# Script to connect to a Kubernetes node using kubectl debug

# Check if node name was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <node-name> [cluster-name]"
    exit 1
fi

NODE_NAME="$1"
CLUSTER_NAME="$2"

# Function to check if node exists in a given context
check_node_exists() {
    local context="$1"
    if [ -n "$context" ]; then
        kubectl get node "$NODE_NAME" --context="$context" &>/dev/null
    else
        kubectl get node "$NODE_NAME" &>/dev/null
    fi
    return $?
}

# Function to run kubectl with optional context
run_kubectl() {
    local context="$1"
    shift
    if [ -n "$context" ]; then
        kubectl --context="$context" "$@"
    else
        kubectl "$@"
    fi
}

# Check if node exists in current/specified context
if ! check_node_exists "$CLUSTER_NAME"; then
    if [ -n "$CLUSTER_NAME" ]; then
        echo "Node '$NODE_NAME' not found in context: $CLUSTER_NAME"
        exit 1
    else
        echo "Node '$NODE_NAME' not found in current context: $(kubectl config current-context)"
        echo ""
        echo "Available contexts:"
        kubectl config get-contexts -o name
        echo ""
        printf "Enter cluster name/context to use (or press Enter to exit): "
        read -r CLUSTER_NAME
        
        if [ -z "$CLUSTER_NAME" ]; then
            echo "No cluster specified. Exiting."
            exit 1
        fi
        
        # Verify the context exists
        if ! kubectl config get-contexts "$CLUSTER_NAME" &>/dev/null; then
            echo "Error: Context '$CLUSTER_NAME' not found."
            exit 1
        fi
        
        # Check again if node exists in specified context
        if ! check_node_exists "$CLUSTER_NAME"; then
            echo "Error: Node '$NODE_NAME' not found in context '$CLUSTER_NAME' either."
            exit 1
        fi
    fi
fi

echo "Connecting to node: $NODE_NAME"
if [ -n "$CLUSTER_NAME" ]; then
    echo "Using context: $CLUSTER_NAME"
fi

run_kubectl "$CLUSTER_NAME" debug node/"$NODE_NAME" -it --image='nicolaka/netshoot' -n kube-system

# Delete debugger pod after completion
echo "Cleaning up debugger pods..."
DEBUGGER_PODS=$(run_kubectl "$CLUSTER_NAME" get pods -n kube-system --no-headers=true | awk '/node-debugger/{print $1}')
if [ -n "$DEBUGGER_PODS" ]; then
    echo "$DEBUGGER_PODS" | xargs -r -I {} sh -c "$(declare -f run_kubectl); run_kubectl '$CLUSTER_NAME' delete -n kube-system pod {}"
else
    echo "No debugger pods found to clean up."
fi