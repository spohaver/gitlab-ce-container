#!/bin/bash
#
# GitLab CE Local Status Script
#
# This script checks the status of the local GitLab instance and retrieves the root password
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
echo "  GitLab CE Local Instance Status"
echo "===================================================="
echo -e "${NC}"

# Check if GitLab container is running
if docker ps | grep -q gitlab-local; then
  echo -e "${GREEN}✓ GitLab container is running${NC}"
  
  # Check GitLab health
  if docker exec gitlab-local gitlab-healthcheck --fail &> /dev/null; then
    echo -e "${GREEN}✓ GitLab is healthy and ready to use${NC}"
  else
    echo -e "${YELLOW}⚠ GitLab is still starting up or has issues${NC}"
    echo -e "${YELLOW}Check logs with: docker logs gitlab-local${NC}"
  fi
  
  # Get container stats
  echo -e "\n${YELLOW}Container Resource Usage:${NC}"
  docker stats gitlab-local --no-stream --format "CPU: {{.CPUPerc}}, Memory: {{.MemUsage}}"
  
  # Get initial root password
  echo -e "\n${YELLOW}Initial Root Password:${NC}"
  if docker exec gitlab-local test -f /etc/gitlab/initial_root_password; then
    docker exec gitlab-local grep 'Password:' /etc/gitlab/initial_root_password
    
    # Check password expiry
    EXPIRY=$(docker exec gitlab-local grep 'Password' /etc/gitlab/initial_root_password | grep -o 'valid until.*')
    echo -e "${YELLOW}$EXPIRY${NC}"
    echo -e "${YELLOW}Be sure to change this password before it expires!${NC}"
  else
    echo -e "${RED}Initial root password file not found.${NC}"
    echo -e "${RED}This could mean GitLab is still starting up or the password has been reset.${NC}"
  fi
  
  # Show access URLs
  LOCAL_IP=$(hostname -I | awk '{print $1}')
  echo -e "\n${YELLOW}Access URLs:${NC}"
  echo -e "${GREEN}http://gitlab.local:8080${NC}"
  echo -e "${GREEN}http://$LOCAL_IP:8080${NC}"
  
  # Show SSH port
  echo -e "\n${YELLOW}Git SSH Access:${NC}"
  echo -e "${GREEN}ssh://git@gitlab.local:2224/username/repo.git${NC}"
  
else
  echo -e "${RED}✗ GitLab container is not running${NC}"
  echo -e "${YELLOW}Start GitLab with: ./setup-local-gitlab.sh${NC}"
fi
