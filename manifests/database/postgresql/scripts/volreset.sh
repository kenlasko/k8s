#!/bin/sh

# This script will delete the contents of a given folder on all the selected nodes. Used for clearing out mariadb folders before a new cluster build

NODES=("nuc4" "nuc5" "nuc6")
FOLDER_PATH="/host/var/postgresql"

# Function to clean up the folder on a given node
clean_node() {
  local NODE_NAME=$1
  echo "Cleaning folder $FOLDER_PATH on node $NODE_NAME..."
  kubectl debug node/$NODE_NAME -it --image='nicolaka/netshoot' -n kube-system -- /bin/sh -c "rm -rf $FOLDER_PATH/* $FOLDER_PATH/.* 2>/dev/null; exit"
  # Delete debugger pod after completion
  kubectl get pods -n kube-system --no-headers=true | awk '/node-debugger/{print $1}' | xargs kubectl delete -n kube-system pod
}

# Check if a specific node is provided
if [ "$#" -eq 1 ]; then
  SPECIFIC_NODE=$1
  if [[ " ${NODES[@]} " =~ " ${SPECIFIC_NODE} " ]]; then
    clean_node "$SPECIFIC_NODE"
  else
    echo "Error: Node $SPECIFIC_NODE is not in the list of known nodes (${NODES[*]})."
    exit 1
  fi
else
  # No specific node provided, ask for confirmation before running on all nodes
  read -p "No node specified. Do you want to run against all nodes (${NODES[*]})? [y/N] " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    for NODE_NAME in "${NODES[@]}"; do
      clean_node "$NODE_NAME"
    done
  else
    echo "Operation canceled."
    exit 0
  fi
fi
