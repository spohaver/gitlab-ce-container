#!/bin/bash
#
# GitLab CE Update Script
#
# This script safely updates GitLab CE running in Docker
#

set -e

# Script configuration
GITLAB_DIR="/home/sohaver/workplace/gitlab-server"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="$GITLAB_DIR/logs/update_${TIMESTAMP}.log"

# Ensure log directory exists
mkdir -p "$(dirname $LOG_FILE)"

# Print to console and log file
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "Starting GitLab update process"

# Make sure we're in the correct directory
cd "$GITLAB_DIR"

# Check if GitLab is running
if ! docker ps | grep -q gitlab; then
  log "Error: GitLab container is not running"
  exit 1
fi

# Create backup before updating
log "Creating backup before update..."
bash "$GITLAB_DIR/scripts/backup.sh"
if [ $? -ne 0 ]; then
  log "Error: Backup failed, aborting update"
  exit 1
fi

# Pull the latest GitLab image
log "Pulling latest GitLab CE Docker image..."
docker-compose pull
if [ $? -ne 0 ]; then
  log "Error: Failed to pull latest GitLab image"
  exit 1
fi

# Stop and remove the container
log "Stopping GitLab..."
docker-compose down
if [ $? -ne 0 ]; then
  log "Warning: Issues stopping GitLab"
fi

# Start the container with the new image
log "Starting GitLab with new image..."
docker-compose up -d
if [ $? -ne 0 ]; then
  log "Error: Failed to start GitLab with new image"
  exit 1
fi

# Wait for GitLab to be fully operational
log "Waiting for GitLab to become available..."
attempts=0
max_attempts=30
sleep_time=10

while [ $attempts -lt $max_attempts ]; do
  attempts=$((attempts + 1))
  log "Attempt $attempts of $max_attempts..."
  
  # Check if GitLab is healthy
  if docker exec gitlab gitlab-healthcheck --fail --max-time 10; then
    log "GitLab is up and running"
    break
  fi
  
  # If we've reached max attempts, report failure
  if [ $attempts -eq $max_attempts ]; then
    log "GitLab did not become healthy after update. Please check logs."
    exit 1
  fi
  
  log "Still waiting for GitLab to become available, sleeping for ${sleep_time}s..."
  sleep $sleep_time
done

log "GitLab update completed successfully"

# Optional: Send notification
# mail -s "GitLab Update Completed" admin@example.com < "$LOG_FILE"

exit 0
