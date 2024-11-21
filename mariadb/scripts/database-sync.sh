#!/bin/bash
# This script will setup replication between the primary Galera cluster and the mariadb-standalone and cloud mariadb instances
# This script is to be run after the primary database cluster is up and running. 

# Set namespace and job names
BACKUP_NAMESPACE="mariadb-test"
BACKUP_JOB_NAME="mariadb-backup-sync"
RESTORE_JOB_NAME="mariadb-restore-sync"

JOB_DATA=(
  "home,mariadb-standalone,mariadb-restore"
  "home,mariadb-test,mariadb-restore-nas01"
  "cloud,mariadb,mariadb-restore"
)

# Check if an old backup job exists, and delete it if it does.
if kubectl get job -n "$BACKUP_NAMESPACE" "$BACKUP_JOB_NAME" > /dev/null 2>&1; then
  echo "Job $BACKUP_JOB_NAME exists. Deleting it..."
  kubectl delete job -n "$BACKUP_NAMESPACE" "$BACKUP_JOB_NAME" --dry-run=server
fi

# Create the backup job
kubectl create job -n "$BACKUP_NAMESPACE" --from=cronjob/mariadb-backup-sync "$BACKUP_JOB_NAME" --dry-run=server

# Wait for the backup job to complete
echo "Waiting for backup job to complete..."
while true; do
  JOB_STATUS=$(kubectl get job -n "$BACKUP_NAMESPACE" "$BACKUP_JOB_NAME" -o jsonpath='{.status.succeeded}' --dry-run=client)
  if [ "$JOB_STATUS" == "1" ]; then
    echo "Backup job completed successfully."
    break
  fi
  FAILED_STATUS=$(kubectl get job -n "$BACKUP_NAMESPACE" "$BACKUP_JOB_NAME" -o jsonpath='{.status.terminating}' --dry-run=client)
  if [ "$FAILED_STATUS" -ge 1 ]; then
    echo "Backup job failed."
    exit 1
  fi
  sleep 5
done


for DATA in "${JOB_DATA[@]}"; do
  # Split the string into variables
  IFS=',' read -r CONTEXT NAMESPACE CRONJOB <<< "$DATA"

  # Check if the restore job exists
  if kubectl get job --context "$CONTEXT" -n "$NAMESPACE" "$RESTORE_JOB_NAME" > /dev/null 2>&1; then
    kubectl delete job --context "$CONTEXT" -n "$NAMESPACE" "$RESTORE_JOB_NAME" --dry-run=server
  fi

  kubectl create job --context "$CONTEXT" -n "$NAMESPACE" --from="cronjob/$CRONJOB" "$RESTORE_JOB_NAME" --dry-run=server
done

echo "All restore jobs triggered successfully."
