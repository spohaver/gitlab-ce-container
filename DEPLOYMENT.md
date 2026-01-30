# GitLab CE Docker Deployment Guide

This document provides advanced deployment topics and configuration details for GitLab CE Docker deployments.

> 📚 **Quick Start Guides Available:**
> - New to GitLab? Start with [QUICKSTART-SANDBOX.md](QUICKSTART-SANDBOX.md) for local testing
> - Ready for production? See [QUICKSTART-PRODUCTION.md](QUICKSTART-PRODUCTION.md)
> - This guide covers advanced topics and customizations

## Deployment Profiles Overview

This repository provides three pre-configured deployment profiles:

### Profile Selection Guide

| Scenario | Recommended Profile | Configuration File |
|----------|-------------------|-------------------|
| Local development/testing | Sandbox | `docker-compose.sandbox.yml` |
| Team testing environment | Staging | `docker-compose.staging.yml` |
| Live production server | Production | `docker-compose.production.yml` |

### Using Deployment Profiles

**Interactive Setup (Recommended):**
```bash
./setup-wizard.sh
# Select your deployment type
# Wizard generates appropriate configuration
```

**Manual Deployment:**
```bash
# Sandbox
docker-compose -f docker-compose.sandbox.yml up -d

# Staging
docker-compose -f docker-compose.staging.yml up -d

# Production
docker-compose -f docker-compose.production.yml up -d
```

## Pre-Deployment Planning

### System Requirements Assessment

1. **Hardware Requirements by Deployment Type**:

   **Sandbox:**
   - CPU: 2+ cores
   - RAM: 4GB+
   - Storage: 20GB+

   **Staging:**
   - CPU: 4+ cores
   - RAM: 8GB+
   - Storage: 50GB+ SSD

   **Production:**
   - CPU: 8+ cores (for 100+ users)
   - RAM: 16GB+ (more for CI/CD workloads)
   - Storage: 100GB+ SSD (scales with usage)
   - Network: 100Mbps+ connection

2. **Software Requirements**:
   - Docker Engine 20.10+
   - Docker Compose v2+
   - Host OS: Linux (Ubuntu 22.04 LTS recommended)
   - For production: `ufw`, `fail2ban`

3. **Domain Planning** (Staging/Production):
   - Dedicated domain or subdomain (e.g., gitlab.example.com)
   - Valid SSL certificate for the domain
   - DNS A record pointing to server IP

### Network Planning

1. **Firewall Configuration**:
   
   **Sandbox:** No firewall needed (localhost only)
   
   **Staging/Production:**
   - TCP port 80 (HTTP, redirects to HTTPS)
   - TCP port 443 (HTTPS)
   - TCP port 2222 (SSH for Git operations)

2. **DNS Configuration** (Staging/Production):
   ```bash
   # Create A record
   gitlab.yourdomain.com  →  YOUR_SERVER_IP
   ```

## Deployment Procedures

### Method 1: Interactive Setup Wizard (Recommended)

```bash
./setup-wizard.sh
```

The wizard guides you through:
1. Deployment type selection
2. Domain and port configuration
3. SSL certificate setup
4. SMTP/email configuration
5. Security settings
6. Configuration validation

### Method 2: Manual Deployment

See profile-specific guides:
- **Sandbox**: [QUICKSTART-SANDBOX.md](QUICKSTART-SANDBOX.md)
- **Production**: [QUICKSTART-PRODUCTION.md](QUICKSTART-PRODUCTION.md)

## Deployment Procedure (Legacy/Manual)

> **Note**: For new deployments, use `./setup-wizard.sh` instead of following these manual steps.

### 1. Server Preparation

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required dependencies
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.17.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Add your user to the docker group
sudo usermod -aG docker $USER
# Log out and log back in for this to take effect
```

### 2. GitLab Server Setup

```bash
# Clone the GitLab server repository
git clone https://github.com/yourusername/gitlab-server.git
cd gitlab-server

# Create configuration directories
mkdir -p config/ssl data logs backups

# Create environment file from template
cp .env.example .env

# Edit the environment file with your settings
nano .env
```

### 3. SSL Certificate Setup

#### Option A: Using Let's Encrypt (Recommended for Production)

```bash
# Install certbot
sudo apt install -y certbot

# Obtain certificates
sudo certbot certonly --standalone -d gitlab.example.com

# Copy certificates to GitLab config directory
sudo cp /etc/letsencrypt/live/gitlab.example.com/fullchain.pem config/ssl/gitlab.crt
sudo cp /etc/letsencrypt/live/gitlab.example.com/privkey.pem config/ssl/gitlab.key

# Set proper permissions
sudo chmod 644 config/ssl/gitlab.crt
sudo chmod 600 config/ssl/gitlab.key
```

#### Option B: Using Self-Signed Certificates (Testing Only)

```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout config/ssl/gitlab.key -out config/ssl/gitlab.crt
```

### 4. Docker Compose Configuration

Edit the `docker-compose.yml` file to match your environment:

```bash
nano docker-compose.yml
```

Key configurations to update:
- `hostname`: Set to your GitLab domain
- `external_url`: Set to your GitLab domain with https://
- Resource limits (if needed)

### 5. GitLab Deployment

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Start GitLab
docker-compose up -d

# Monitor the startup process
docker logs -f gitlab
```

The initial startup may take 5-10 minutes depending on your system.

### 6. Post-Deployment Configuration

#### Retrieve Initial Root Password

```bash
docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

#### Access GitLab Web Interface

1. Open a browser and navigate to `https://gitlab.example.com`
2. Log in with username `root` and the password retrieved above
3. Change the root password immediately

#### Basic Configuration

Through the GitLab web interface:

1. **User Settings**:
   - Create admin users
   - Set up 2FA for admins

2. **Instance Settings**:
   - Configure email notifications
   - Set visibility and access controls
   - Configure sign-up restrictions

3. **CI/CD Settings**:
   - Register GitLab Runners (if needed)
   - Configure CI/CD variables

### 7. Setup Automated Maintenance

#### Configure Backup Schedule

Add to crontab:

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /path/to/gitlab-server/scripts/backup.sh >> /path/to/gitlab-server/logs/cron-backup.log 2>&1
```

#### Configure Update Reminders

Add to crontab:

```bash
# Check for GitLab updates weekly and notify admin
0 3 * * 0 docker exec gitlab apt-get update && docker exec gitlab apt-get -s upgrade | grep gitlab | mail -s "GitLab Updates Available" admin@example.com
```

## Production Hardening

1. **Security Hardening**:
   - Enable SSH key authentication only
   - Configure fail2ban
   - Set up a proper firewall (ufw or iptables)

2. **Performance Optimization**:
   - Tune PostgreSQL settings in gitlab.rb
   - Adjust worker counts based on system resources

3. **Monitoring Setup**:
   - Enable Prometheus metrics
   - Set up Grafana dashboards (optional)
   - Configure alert notifications

## Troubleshooting Common Issues

### Startup Issues

**Problem**: GitLab container exits shortly after starting
**Solution**: Check logs with `docker logs gitlab` and verify system meets minimum requirements

### Connection Issues

**Problem**: Cannot connect to GitLab web interface
**Solution**: 
- Verify domain DNS is correctly configured
- Check firewall allows ports 80/443
- Verify SSL certificates are properly installed

### Performance Issues

**Problem**: GitLab is slow or unresponsive
**Solution**:
- Increase server resources
- Tune PostgreSQL and Redis settings
- Check `docker stats gitlab` for resource usage

### Backup/Restore Issues

**Problem**: Backup script fails
**Solution**:
- Check disk space
- Verify permissions on backup directory
- Review logs in the `logs/` directory

## Scaling Guidelines

### Vertical Scaling

1. Increase server resources:
   - Add more CPU cores
   - Increase RAM
   - Use faster SSDs

2. Update Docker Compose resource limits

### Horizontal Scaling

For larger deployments, consider:
1. Separating PostgreSQL to a dedicated server
2. Setting up Redis sentinel for HA
3. Implementing load balancing for multiple GitLab application servers

## Maintenance Procedures

### Regular Updates

```bash
./scripts/update.sh
```

### Database Maintenance

```bash
# Connect to GitLab container
docker exec -it gitlab bash

# Run GitLab database maintenance tasks
gitlab-rake gitlab:db:clean
gitlab-rake gitlab:artifacts:clean
gitlab-rake gitlab:lfs:clean
gitlab-rake gitlab:uploads:clean
```

### Log Management

```bash
# Configure log rotation
sudo nano /etc/logrotate.d/gitlab
```

## Migration Guidelines

### Migrating from Another GitLab Instance

1. Create a backup on the old instance
2. Copy backup file to the new server's `backups` directory
3. Use restore script:
   ```bash
   ./scripts/restore.sh <backup_filename>
   ```

### Migrating from Non-Docker GitLab

1. Create a backup on the old instance
2. Copy backup file to the new server's `backups` directory
3. Adjust backup file format if needed
4. Use restore script with appropriate options
