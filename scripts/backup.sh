#!/bin/bash
#
# GitLab CE Backup Script
#
# This script performs a backup of GitLab CE running in Docker
# and can optionally upload the backup to remote storage
#

set -e

# Script configuration
BACKUP_DIR="/home/sohaver/workplace/gitlab-server/backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="/home/sohaver/workplace/gitlab-server/logs/backup_${TIMESTAMP}.log"

# Ensure log directory exists
mkdir -p "$(dirname $LOG_FILE)"

# Print to console and log file
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "Starting GitLab backup process"

# Check if GitLab is running
if ! docker ps | grep -q gitlab; then
  log "Error: GitLab container is not running"
  exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"
log "Backup directory: $BACKUP_DIR"

# Perform GitLab backup
log "Creating GitLab backup..."
docker exec gitlab gitlab-backup create SKIP=registry STRATEGY=copy
if [ $? -ne 0 ]; then
  log "Error: GitLab backup failed"
  exit 1
fi

log "Backing up GitLab configuration files..."
docker exec gitlab sh -c "mkdir -p /var/opt/gitlab/backups/config && cp -r /etc/gitlab/* /var/opt/gitlab/backups/config"
if [ $? -ne 0 ]; then
  log "Error: Configuration backup failed"
  exit 1
fi

# Optional: Upload to remote storage (S3, SFTP, etc.)
# Uncomment and configure as needed
#
# log "Uploading backup to remote storage..."
# rclone copy "$BACKUP_DIR" remote:gitlab-backups

# Cleanup old backups (GitLab's internal mechanism)
log "Cleaning up old backups..."
docker exec gitlab gitlab-backup cleanup

log "Backup completed successfully"

# Optional: Send notification
# mail -s "GitLab Backup Completed" admin@example.com < "$LOG_FILE"

exit 0
