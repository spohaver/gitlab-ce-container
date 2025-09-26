#!/bin/bash
#
# GitLab CE Local Cleanup Script
#
# This script stops and optionally removes the local GitLab instance
#

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "===================================================="
echo "  GitLab CE Local Testing Environment Cleanup"
echo "===================================================="
echo -e "${NC}"

# Stop GitLab containers
echo -e "${YELLOW}Stopping GitLab containers...${NC}"
docker-compose -f docker-compose.local.yml down

# Ask if user wants to remove data
read -p "Do you want to remove all GitLab data? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}Removing GitLab local data directories...${NC}"
  rm -rf gitlab-local
  echo -e "${GREEN}GitLab data removed.${NC}"
fi

# Ask if user wants to remove gitlab.local from /etc/hosts
read -p "Do you want to remove gitlab.local from /etc/hosts? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}Removing gitlab.local from /etc/hosts (requires sudo)...${NC}"
  echo -e "${YELLOW}Your sudo password may be required:${NC}"
  sudo sed -i '/gitlab.local/d' /etc/hosts
  echo -e "${GREEN}Removed gitlab.local from /etc/hosts${NC}"
fi

echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}Cleanup completed!${NC}"
echo -e "${GREEN}=============================================${NC}"
