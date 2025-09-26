#!/bin/bash
#
# GitLab CE Local Testing Setup Script
#
# This script prepares and launches a local GitLab CE instance for development and testing
#

set -e

# Configuration
GITLAB_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOCAL_IP=$(hostname -I | awk '{print $1}')
HOST_ENTRY="$LOCAL_IP gitlab.local"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "===================================================="
echo "  GitLab CE Local Testing Environment Setup"
echo "===================================================="
echo -e "${NC}"

# Create local directories
echo -e "${YELLOW}Creating local directories...${NC}"
mkdir -p "$GITLAB_DIR/gitlab-local/"{config,data,logs,ssl}

# Generate self-signed certificate for local testing
if [ ! -f "$GITLAB_DIR/gitlab-local/ssl/gitlab-local.key" ]; then
  echo -e "${YELLOW}Generating self-signed SSL certificate...${NC}"
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$GITLAB_DIR/gitlab-local/ssl/gitlab-local.key" \
    -out "$GITLAB_DIR/gitlab-local/ssl/gitlab-local.crt" \
    -subj "/CN=gitlab.local/O=GitLab Local/C=US" \
    -addext "subjectAltName = DNS:gitlab.local,IP:$LOCAL_IP"
fi

# Check if gitlab.local is in /etc/hosts
if ! grep -q "gitlab.local" /etc/hosts; then
  echo -e "${YELLOW}Adding gitlab.local to /etc/hosts (requires sudo)...${NC}"
  echo -e "${YELLOW}Your sudo password may be required:${NC}"
  echo "$HOST_ENTRY" | sudo tee -a /etc/hosts > /dev/null
  echo -e "${GREEN}Added gitlab.local to /etc/hosts${NC}"
else
  echo -e "${GREEN}gitlab.local already exists in /etc/hosts${NC}"
fi

# Launch GitLab
echo -e "${YELLOW}Starting GitLab local instance...${NC}"
cd "$GITLAB_DIR"
docker compose -f docker-compose.local.yml down || true
docker compose -f docker-compose.local.yml up -d

# Wait for GitLab to start
echo -e "${YELLOW}Waiting for GitLab to start (this may take several minutes)...${NC}"
echo -e "${YELLOW}You can follow the startup progress with:${NC}"
echo -e "${BLUE}docker logs -f gitlab-local${NC}"

echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}Local GitLab instance is starting!${NC}"
echo -e "${GREEN}It may take 5-10 minutes to fully initialize.${NC}"
echo -e "${GREEN}=============================================${NC}"
echo -e "${YELLOW}Access GitLab at: ${BLUE}http://gitlab.local:8080${NC}"
echo -e "${YELLOW}or using your local IP: ${BLUE}http://$LOCAL_IP:8080${NC}"
echo -e ""
echo -e "${YELLOW}The default username is: ${BLUE}root${NC}"
echo -e "${YELLOW}To get the initial root password, run:${NC}"
echo -e "${BLUE}docker exec -it gitlab-local grep 'Password:' /etc/gitlab/initial_root_password${NC}"
echo -e ""
echo -e "${YELLOW}To stop GitLab:${NC}"
echo -e "${BLUE}docker-compose -f docker-compose.local.yml down${NC}"
echo -e "${GREEN}=============================================${NC}"
