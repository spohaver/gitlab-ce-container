#!/bin/bash
#
# GitLab CE Update Script
#
# This script safely updates GitLab CE running in Docker
#

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITLAB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="$GITLAB_DIR/logs/update_${TIMESTAMP}.log"

# Container name - auto-detect or use environment variable
CONTAINER_NAME="${GITLAB_CONTAINER_NAME:-gitlab}"

# Compose file - accept as argument, fall back to COMPOSE_FILE env var, then default
COMPOSE_FILE="${1:-${COMPOSE_FILE:-docker-compose.yml}}"
if [ ! -f "$GITLAB_DIR/$COMPOSE_FILE" ]; then
  echo "Error: Compose file not found: $GITLAB_DIR/$COMPOSE_FILE"
  echo "Usage: $0 [docker-compose-file]"
  echo "Example: $0 docker-compose.production.yml"
  exit 1
fi
COMPOSE_FLAG="-f $COMPOSE_FILE"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Print to console and log file
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "Starting GitLab update process"

# Make sure we're in the correct directory
cd "$GITLAB_DIR"

# Check if GitLab is running
if ! docker ps --filter "name=^${CONTAINER_NAME}$" --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
  log "Error: GitLab container '${CONTAINER_NAME}' is not running"
  exit 1
fi

log "Using compose file: $COMPOSE_FILE"

# Create backup before updating
log "Creating backup before update..."
if ! bash "$GITLAB_DIR/scripts/backup.sh"; then
  log "Error: Backup failed, aborting update"
  exit 1
fi

# Pull the latest GitLab image
log "Pulling latest GitLab CE Docker image..."
if ! docker-compose $COMPOSE_FLAG pull; then
  log "Error: Failed to pull latest GitLab image"
  exit 1
fi

# Stop and remove the container
log "Stopping GitLab..."
if ! docker-compose $COMPOSE_FLAG down; then
  log "Warning: Issues stopping GitLab, continuing anyway"
fi

# Start the container with the new image
log "Starting GitLab with new image..."
if ! docker-compose $COMPOSE_FLAG up -d; then
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
  if docker exec "$CONTAINER_NAME" gitlab-healthcheck --fail --max-time 10; then
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
