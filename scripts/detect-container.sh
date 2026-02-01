#!/bin/bash
# ============================================================================
# Container Name Detection Helper
# ============================================================================
# This script helps detect the GitLab container name based on running
# containers or docker-compose configuration.
#
# Usage:
#   source detect-container.sh
#   # Now $GITLAB_CONTAINER_NAME is available
#
# Or:
#   CONTAINER_NAME=$(./detect-container.sh)
# ============================================================================

detect_gitlab_container() {
    # Check if environment variable is already set
    if [ -n "$GITLAB_CONTAINER_NAME" ]; then
        echo "$GITLAB_CONTAINER_NAME"
        return 0
    fi
    
    # Try to find running GitLab container
    local container=$(docker ps --filter "ancestor=gitlab/gitlab-ce" --format "{{.Names}}" | head -1)
    
    if [ -n "$container" ]; then
        echo "$container"
        return 0
    fi
    
    # Check for common container names
    for name in gitlab-production gitlab-staging gitlab-sandbox gitlab-local gitlab; do
        if docker ps -a --filter "name=^${name}$" --format "{{.Names}}" | grep -q "^${name}$"; then
            echo "$name"
            return 0
        fi
    done
    
    # Default to 'gitlab'
    echo "gitlab"
    return 0
}

# If script is executed (not sourced), print the container name
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_gitlab_container
else
    # If sourced, export the variable
    export GITLAB_CONTAINER_NAME=$(detect_gitlab_container)
fi
