# Deployment Flexibility Guide

This document explains how the GitLab template supports flexible deployment locations and configurations.

## Installation Location Flexibility

### You Can Install Anywhere

This template works from **any directory**. Common locations:

```bash
# System-wide installations
/opt/gitlab-server
/srv/gitlab
/usr/local/gitlab-server

# User installations
~/gitlab-server
/home/username/projects/gitlab-server

# Development locations
~/workspace/gitlab-server
~/dev/gitlab-server
```

All scripts use **relative paths** based on script location, so there are no hard-coded absolute paths to worry about.

## Container Name Flexibility

### Automatic Container Detection

Scripts automatically detect the GitLab container name:

1. **Environment Variable** (highest priority):
   ```bash
   export GITLAB_CONTAINER_NAME=my-custom-gitlab
   ./scripts/backup.sh
   ```

2. **Running Container Detection**:
   - Searches for running `gitlab/gitlab-ce` containers
   - Checks common names: `gitlab-production`, `gitlab-staging`, `gitlab-sandbox`, `gitlab-local`, `gitlab`

3. **Default Fallback**: `gitlab`

### Setting Custom Container Name

**Option 1: Environment Variable (Recommended)**
```bash
# Set once in your shell profile
echo 'export GITLAB_CONTAINER_NAME=gitlab-production' >> ~/.bashrc
source ~/.bashrc

# Or per-command
GITLAB_CONTAINER_NAME=gitlab-production ./scripts/backup.sh
```

**Option 2: Docker Compose Override**
```yaml
# docker-compose.override.yml
version: '3.6'
services:
  gitlab:
    container_name: my-company-gitlab
```

**Option 3: Modify Profile**
```yaml
# Edit docker-compose.production.yml
services:
  gitlab:
    container_name: my-custom-name
```

## Profile-Specific Container Names

Each deployment profile uses a unique container name by default:

| Profile | Default Container Name | Override Variable |
|---------|----------------------|-------------------|
| Sandbox | `gitlab-sandbox` | `GITLAB_CONTAINER_NAME` |
| Staging | `gitlab-staging` | `GITLAB_CONTAINER_NAME` |
| Production | `gitlab-production` | `GITLAB_CONTAINER_NAME` |
| Legacy | `gitlab` | `GITLAB_CONTAINER_NAME` |

This allows running multiple GitLab instances on the same server.

## Multi-Instance Setup

### Running Multiple Profiles Simultaneously

```bash
# Start sandbox for testing
docker-compose -f docker-compose.sandbox.yml up -d
# Container: gitlab-sandbox on ports 8080/8443/2224

# Start production on same server
docker-compose -f docker-compose.production.yml up -d
# Container: gitlab-production on ports 80/443/2222

# Backup specific instance
GITLAB_CONTAINER_NAME=gitlab-sandbox ./scripts/backup.sh
GITLAB_CONTAINER_NAME=gitlab-production ./scripts/backup.sh
```

### Port Separation

Profiles use different ports to avoid conflicts:

```
Sandbox:    HTTP=8080, HTTPS=8443, SSH=2224
Staging:    HTTP=80,   HTTPS=443,  SSH=2222
Production: HTTP=80,   HTTPS=443,  SSH=2222
```

## Path Configuration

### SSL Certificates

Flexible paths via environment variables:

```bash
# .env file
GITLAB_DOMAIN=gitlab.example.com

# Certificates expected at:
# config/ssl/${GITLAB_DOMAIN}.crt
# config/ssl/${GITLAB_DOMAIN}.key
```

### Backup Location

```bash
# Default: ./backups (relative to repository root)
# Customize in .env:
GITLAB_BACKUP_PATH=/mnt/backup-drive/gitlab-backups
```

### Log Files

```bash
# Default: ./logs (relative to repository root)
# All scripts use: $GITLAB_DIR/logs/
# No hard-coded paths
```

## Docker Volume Flexibility

### Named Volumes (Production/Staging)

Data stored in Docker volumes (portable across hosts):

```yaml
volumes:
  gitlab-data:
    driver: local
```

**Backup volumes:**
```bash
docker volume ls | grep gitlab
docker volume inspect gitlab-production_gitlab-data
```

### Local Directories (Sandbox)

Data stored in `./gitlab-local/` for easy inspection:

```bash
gitlab-local/
├── data/       # GitLab data
├── config/     # Configuration
├── logs/       # Log files
└── ssl/        # Certificates
```

## Deployment Scenarios

### Scenario 1: Developer Machine

```bash
# Install to home directory
cd ~/projects
git clone https://github.com/yourusername/gitlab-server.git
cd gitlab-server

# Run sandbox
./setup-wizard.py  # Select sandbox
./start-gitlab.sh
```

### Scenario 2: Shared Server

```bash
# Install to /srv for shared access
cd /srv
sudo git clone https://github.com/yourusername/gitlab-server.git
cd gitlab-server
sudo chown -R $USER:$USER .

# Run production
./setup-wizard.py  # Select production
docker-compose -f docker-compose.production.yml up -d
```

### Scenario 3: Multiple Environments

```bash
# One repository, multiple instances
cd /opt/gitlab-server

# Start all environments
docker-compose -f docker-compose.sandbox.yml up -d
docker-compose -f docker-compose.staging.yml up -d
docker-compose -f docker-compose.production.yml up -d

# Each uses unique:
# - Container name
# - Ports
# - Volumes
```

### Scenario 4: CI/CD Testing

```bash
# Temporary disposable instance
docker-compose -f docker-compose.sandbox.yml up -d
# Run tests
docker-compose -f docker-compose.sandbox.yml down -v
```

## Migration Between Servers

### Moving to New Server

```bash
# On old server
./scripts/backup.sh
scp backups/*.tar newserver:/path/to/gitlab-server/backups/

# On new server (any directory)
cd /new/installation/path
git clone https://github.com/yourusername/gitlab-server.git
cd gitlab-server
./setup-wizard.sh
./scripts/restore.sh backups/your-backup.tar
```

The repository works from any directory!

## Common Customizations

### Custom Ports

Edit the compose file or use override:

```yaml
# docker-compose.override.yml
services:
  gitlab:
    ports:
      - '8888:80'
      - '8889:443'
      - '2223:22'
```

### Custom Domain

```bash
# .env
GITLAB_DOMAIN=git.mycompany.com
```

### Custom Data Location

```yaml
# docker-compose.override.yml
services:
  gitlab:
    volumes:
      - /mnt/storage/gitlab-data:/var/opt/gitlab
```

## Troubleshooting

### Wrong Container Name

```bash
# Check running containers
docker ps

# Set explicitly
export GITLAB_CONTAINER_NAME=actual-container-name
./scripts/backup.sh
```

### Scripts Can't Find Container

```bash
# Auto-detect current container
source scripts/detect-container.sh
echo $GITLAB_CONTAINER_NAME

# Or specify manually
GITLAB_CONTAINER_NAME=gitlab-production ./scripts/backup.sh
```

### Multiple Instances Conflict

Each profile must use unique:
- Container name ✓ (automatic)
- Ports ✓ (configured)
- Domain ✓ (in .env)
- Volumes ✓ (automatic per profile)

## Best Practices

### 1. Use Descriptive Container Names
```bash
# Instead of: gitlab
# Use: gitlab-prod-company
container_name: gitlab-prod-acme
```

### 2. Set Environment Variable in Profile
```bash
# ~/.bashrc or ~/.zshrc
export GITLAB_CONTAINER_NAME=gitlab-production
```

### 3. Document Your Installation
Create `INSTALLATION.md`:
```markdown
# Installation Details
- Location: /opt/gitlab-server
- Container: gitlab-production
- Domain: gitlab.example.com
- Profile: production
```

### 4. Use Consistent Naming
```bash
# Repository: gitlab-server
# Container: gitlab-production  
# Domain: gitlab.company.com
# All related and clear
```

## Summary

✅ **No hard-coded paths** - Works from any directory  
✅ **Auto-detecting container names** - Smart defaults  
✅ **Environment variable overrides** - Full control  
✅ **Profile-specific defaults** - No conflicts  
✅ **Multi-instance support** - Run multiple GitLabs  
✅ **Portable backups** - Move between servers easily  

The template is designed to be flexible while maintaining security and simplicity!
