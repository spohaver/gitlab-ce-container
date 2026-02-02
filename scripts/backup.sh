#!/bin/bash
#
# GitLab CE Backup Script
#
# This script performs a backup of GitLab CE running in Docker
# and can optionally upload the backup to remote storage
#

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITLAB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$GITLAB_DIR/backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="$GITLAB_DIR/logs/backup_${TIMESTAMP}.log"

# Container name - auto-detect or use environment variable
CONTAINER_NAME="${GITLAB_CONTAINER_NAME:-gitlab}"

# Ensure log directory exists
mkdir -p "$(dirname $LOG_FILE)"

# Print to console and log file
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "Starting GitLab backup process"

# Check if GitLab is running
if ! docker ps --filter "name=^${CONTAINER_NAME}$" --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
  log "Error: GitLab container '${CONTAINER_NAME}' is not running"
  exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"
log "Backup directory: $BACKUP_DIR"

# Perform GitLab backup
log "Creating GitLab backup..."
if ! docker exec "$CONTAINER_NAME" gitlab-backup create SKIP=registry STRATEGY=copy; then
  log "Error: GitLab backup failed"
  exit 1
fi

log "Backing up GitLab configuration files..."
if ! docker exec "$CONTAINER_NAME" sh -c "mkdir -p /var/opt/gitlab/backups/config && cp -r /etc/gitlab/* /var/opt/gitlab/backups/config"; then
  log "Error: Configuration backup failed"
  exit 1
fi

# =============================================================================
# REMOTE/OFFSITE BACKUP OPTIONS (Recommended for Production)
# =============================================================================
# IMPORTANT: Implement 3-2-1 backup strategy:
# - 3 copies of data
# - 2 different storage types
# - 1 offsite copy
#
# Uncomment ONE of the methods below and configure as needed:

# --- Option 1: AWS S3 (Recommended for production) ---
# Requires: aws-cli installed and configured
# log "Uploading backup to AWS S3..."
# LATEST_BACKUP=$(ls -t /var/opt/gitlab/backups/*_gitlab_backup.tar | head -1)
# docker exec gitlab bash -c "aws s3 sync /var/opt/gitlab/backups/ s3://YOUR-BUCKET-NAME/gitlab-backups/ --exclude '*' --include '*_gitlab_backup.tar'"
# if [ $? -eq 0 ]; then
#   log "Successfully uploaded to S3"
# else
#   log "ERROR: S3 upload failed"
# fi

# --- Option 2: Rclone (supports S3, Google Drive, Dropbox, etc.) ---
# Requires: rclone installed and configured
# log "Uploading backup to remote storage..."
# rclone copy "$BACKUP_DIR" remote:gitlab-backups --include "*_gitlab_backup.tar"
# if [ $? -eq 0 ]; then
#   log "Successfully uploaded via rclone"
# else
#   log "ERROR: Rclone upload failed"
# fi

# --- Option 3: rsync to remote server ---
# Requires: SSH key authentication set up
# log "Syncing backup to remote server..."
# rsync -avz --progress "$BACKUP_DIR/" user@backup-server:/path/to/gitlab-backups/
# if [ $? -eq 0 ]; then
#   log "Successfully synced to remote server"
# else
#   log "ERROR: rsync failed"
# fi

# --- Option 4: SFTP ---
# Requires: lftp installed
# log "Uploading backup via SFTP..."
# LATEST_BACKUP=$(ls -t $BACKUP_DIR/*_gitlab_backup.tar | head -1)
# lftp -e "put $LATEST_BACKUP; bye" -u user,password sftp://backup-server/gitlab-backups/
# if [ $? -eq 0 ]; then
#   log "Successfully uploaded via SFTP"
# else
#   log "ERROR: SFTP upload failed"
# fi

# --- Backup Encryption (Recommended for sensitive data) ---
# Encrypt backups before uploading to untrusted storage
# LATEST_BACKUP=$(ls -t $BACKUP_DIR/*_gitlab_backup.tar | head -1)
# log "Encrypting backup..."
# gpg --symmetric --cipher-algo AES256 "$LATEST_BACKUP"
# # Then upload the .gpg file instead

log "Backup completed successfully"

# =============================================================================
# NOTIFICATION OPTIONS (Recommended for Production)
# =============================================================================
# Uncomment and configure ONE of the notification methods below:

# --- Option 1: Email notification ---
# Requires: mailutils or similar mail command configured
# mail -s "GitLab Backup Completed - $TIMESTAMP" admin@example.com < "$LOG_FILE"

# --- Option 2: Slack notification ---
# Requires: SLACK_WEBHOOK_URL configured
# SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
# curl -X POST -H 'Content-type: application/json' \
#   --data "{\"text\":\"GitLab backup completed successfully at $TIMESTAMP\"}" \
#   "$SLACK_WEBHOOK_URL"

# --- Option 3: PagerDuty (for failures only) ---
# Send alert only if backup fails (add this in error handling above)
# PAGERDUTY_KEY="your-integration-key"
# curl -X POST https://events.pagerduty.com/v2/enqueue \
#   -H 'Content-Type: application/json' \
#   -d "{\"routing_key\":\"$PAGERDUTY_KEY\",\"event_action\":\"trigger\",\"payload\":{\"summary\":\"GitLab backup failed\",\"severity\":\"error\"}}"

# --- Option 4: Discord webhook ---
# DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/YOUR/WEBHOOK"
# curl -X POST -H 'Content-Type: application/json' \
#   --data "{\"content\":\"✅ GitLab backup completed successfully at $TIMESTAMP\"}" \
#   "$DISCORD_WEBHOOK_URL"

exit 0
