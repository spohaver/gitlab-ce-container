#!/bin/bash
#
# GitLab CE Restore Script
#
# This script restores a GitLab backup to a Docker-based GitLab CE instance
#

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITLAB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$GITLAB_DIR/backups"
LOG_FILE="$GITLAB_DIR/logs/restore_$(date +"%Y-%m-%d_%H-%M-%S").log"

# Container name - auto-detect or use environment variable
CONTAINER_NAME="${GITLAB_CONTAINER_NAME:-gitlab}"

# Ensure log directory exists
mkdir -p "$(dirname $LOG_FILE)"

# Print to console and log file
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

show_usage() {
  echo "Usage: $0 <backup_file>"
  echo "Example: $0 1632648838_2021_09_26_14.2.3_gitlab_backup.tar"
  exit 1
}

# Check arguments
if [ "$#" -ne 1 ]; then
  show_usage
fi

BACKUP_FILE="$1"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"

# Validate backup file
if [ ! -f "$BACKUP_PATH" ]; then
  log "Error: Backup file not found: $BACKUP_PATH"
  exit 1
fi

log "Starting GitLab restore process using backup: $BACKUP_FILE"

# Make sure we're in the correct directory
cd "$GITLAB_DIR"

# Check if GitLab is running
if ! docker ps | grep -q gitlab; then
  log "Error: GitLab container is not running"
  exit 1
fi

# Create a backup of current state before restore (optional)
log "Creating a backup of current state before restore..."
bash "$GITLAB_DIR/scripts/backup.sh"

# Stop GitLab processes before restore
log "Stopping GitLab processes..."
docker exec "$CONTAINER_NAME" gitlab-ctl stop puma
docker exec "$CONTAINER_NAME" gitlab-ctl stop sidekiq

# Copy backup file into container if not already present (e.g. via bind mount)
if docker exec "$CONTAINER_NAME" test -f "/var/opt/gitlab/backups/$BACKUP_FILE"; then
  log "Backup file already present in container (bind mount), skipping copy"
else
  log "Copying backup file to GitLab container..."
  docker cp "$BACKUP_PATH" "$CONTAINER_NAME":/var/opt/gitlab/backups/
fi

# Extract backup identifier (everything before _gitlab_backup.tar)
TIMESTAMP=$(echo "$BACKUP_FILE" | sed -E 's/_gitlab_backup\.tar$//')

# Perform restore
log "Restoring GitLab from backup..."
if ! docker exec -e GITLAB_ASSUME_YES=1 "$CONTAINER_NAME" gitlab-backup restore BACKUP=$TIMESTAMP FORCE=yes; then
  log "Error: GitLab restore failed"
  docker exec "$CONTAINER_NAME" gitlab-ctl restart
  exit 1
fi

# Restore configuration files if available
if [ -d "$BACKUP_DIR/config" ]; then
  log "Restoring GitLab configuration files..."
  docker exec "$CONTAINER_NAME" sh -c "cp -r /var/opt/gitlab/backups/config/* /etc/gitlab/"
fi

# Reconfigure and restart GitLab
log "Reconfiguring GitLab..."
docker exec "$CONTAINER_NAME" gitlab-ctl reconfigure

log "Starting GitLab processes..."
docker exec "$CONTAINER_NAME" gitlab-ctl restart

# Wait for GitLab to be fully operational
log "Waiting for GitLab to become available..."
attempts=0
max_attempts=30
sleep_time=10

while [ $attempts -lt $max_attempts ]; do
  attempts=$((attempts + 1))
  log "Attempt $attempts of $max_attempts..."
  
  # Check if GitLab is healthy
  if docker exec "$CONTAINER_NAME" gitlab-healthcheck --fail --max-time 10; then
    log "GitLab is up and running"
    break
  fi
  
  # If we've reached max attempts, report failure
  if [ $attempts -eq $max_attempts ]; then
    log "GitLab did not become healthy after restore. Please check logs."
    exit 1
  fi
  
  log "Still waiting for GitLab to become available, sleeping for ${sleep_time}s..."
  sleep $sleep_time
done

log "GitLab restore completed successfully"

# Optional: Send notification
# mail -s "GitLab Restore Completed" admin@example.com < "$LOG_FILE"

exit 0
