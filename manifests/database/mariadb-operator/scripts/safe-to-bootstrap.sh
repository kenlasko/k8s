#!/bin/sh

# This script will set 'safe_to_bootstrap' on the selected node (or all)

NODES=("nuc4" "nuc5" "nuc6")
FILE_PATH="/host/var/mariadb-galera/storage/grastate.dat"

# Function to set 'safe_to_bootstrap' on a given node
set_bootstrap() {
  local NODE_NAME=$1
  echo "Setting 'safe_to_bootstrap' on node $NODE_NAME..."
  kubectl debug node/$NODE_NAME -it --image='nicolaka/netshoot' -n kube-system -- /bin/sh -c "sed -i -e 's/safe_to_bootstrap: 0/safe_to_bootstrap: 1/' $FILE_PATH; exit"
  # Delete debugger pod after completion
  kubectl get pods -n kube-system --no-headers=true | awk '/node-debugger/{print $1}' | xargs kubectl delete -n kube-system pod
}

# Check if a specific node is provided
if [ "$#" -eq 1 ]; then
  SPECIFIC_NODE=$1
  if [[ " ${NODES[@]} " =~ " ${SPECIFIC_NODE} " ]]; then
    set_bootstrap "$SPECIFIC_NODE"
  else
    echo "Error: Node $SPECIFIC_NODE is not in the list of known nodes (${NODES[*]})."
    exit 1
  fi
else
  # No specific node provided, ask for confirmation before running on all nodes
  read -p "No node specified. Do you want to run against all nodes (${NODES[*]})? [y/N] " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    for NODE_NAME in "${NODES[@]}"; do
      set_bootstrap "$NODE_NAME"
    done
  else
    echo "Operation canceled."
    exit 0
  fi
fi