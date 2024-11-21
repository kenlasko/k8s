#!/bin/bash
# This script will setup replication between the primary Galera cluster and the mariadb-standalone and cloud mariadb instances
# This script is to be run after the primary database cluster is up and running. 

# Set namespace and job names
BACKUP_NAMESPACE="mariadb"
BACKUP_JOB_NAME="mariadb-backup-sync"
RESTORE_JOB_NAME="mariadb-restore-sync"

# Check if the backup job exists
echo "Checking if job $BACKUP_JOB_NAME exists in namespace $BACKUP_NAMESPACE..."
if kubectl get job -n "$BACKUP_NAMESPACE" "$BACKUP_JOB_NAME" > /dev/null 2>&1; then
  echo "Job $BACKUP_JOB_NAME exists. Deleting it..."
  kubectl delete job -n "$BACKUP_NAMESPACE" "$BACKUP_JOB_NAME"
else
  echo "Job $BACKUP_JOB_NAME does not exist in namespace $BACKUP_NAMESPACE."
fi

# Create the backup job
echo "Creating backup job in namespace ${BACKUP_NAMESPACE}..."
kubectl create job -n "$BACKUP_NAMESPACE" --from=cronjob/mariadb-backup-sync "$BACKUP_JOB_NAME"

# Wait for the backup job to complete
echo "Waiting for backup job to complete..."
while true; do
  JOB_STATUS=$(kubectl get job -n "$BACKUP_NAMESPACE" "$BACKUP_JOB_NAME" -o jsonpath='{.status.succeeded}')
  if [ "$JOB_STATUS" == "1" ]; then
    echo "Backup job completed successfully."
    break
  fi
  FAILED_STATUS=$(kubectl get job -n "$BACKUP_NAMESPACE" "$BACKUP_JOB_NAME" -o jsonpath='{.status.terminating}')
  if [ "$FAILED_STATUS" -ge 1 ]; then
    echo "Backup job failed."
    exit 1
  fi
  sleep 5
done

# Create the restore jobs
echo "Creating restore job in mariadb-standalone namespace..."
kubectl create job --context home -n mariadb-standalone --from=cronjob/mariadb-restore "$RESTORE_JOB_NAME"
echo "Creating restore job on NAS01..."
kubectl create job --context home -n "$BACKUP_NAMESPACE" --from=cronjob/mariadb-restore-nas01 "$RESTORE_JOB_NAME"
echo "Creating restore job in mariadb namespace in cloud context..."
kubectl create job --context cloud -n mariadb --from=cronjob/mariadb-restore "$RESTORE_JOB_NAME"

echo "All restore jobs triggered successfully."
