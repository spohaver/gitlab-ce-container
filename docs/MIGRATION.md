# Migration Guide

This guide helps you migrate from the previous GitLab CE Docker setup to the new multi-profile architecture introduced in version 18.8.2.

## What Changed

### Breaking Changes

1. **Container Names**
   - Old: `gitlab`
   - New: `gitlab-production`, `gitlab-staging`, or `gitlab-sandbox`

2. **Docker Compose Files**
   - Old: Single `docker-compose.yml` or `docker-compose.local.yml`
   - New: Three profiles:
     - `docker-compose.production.yml` - Production deployments
     - `docker-compose.staging.yml` - Pre-production testing
     - `docker-compose.sandbox.yml` - Local development

3. **GitLab Version Pinning**
   - Old: `gitlab/gitlab-ce:latest` (unpredictable)
   - New: `gitlab/gitlab-ce:18.8.2-ce.0` (production/staging) or `:latest` (sandbox)

4. **Environment Configuration**
   - Old: Manual editing or no .env file
   - New: Structured .env file with deployment-specific settings

5. **Scripts Removed**
   - `setup-local-gitlab.sh` → replaced by `setup-wizard.py`
   - `cleanup-local-gitlab.sh` → replaced by compose down commands
   - `check-local-gitlab.sh` → replaced by `validate-deployment.py`

6. **Security Hardening**
   - Production now includes rate limiting, brute-force protection, HSTS
   - Public signup disabled by default
   - Enhanced SSL/TLS configuration

## Migration Paths

Choose the migration path that matches your current setup:

### Path A: Production Migration (Named Volumes)

If you're running a production GitLab with named volumes:

#### Step 1: Backup Current Installation

```bash
# Using the old container name
docker exec gitlab gitlab-backup create SKIP=registry STRATEGY=copy

# Copy the backup file to a safe location
docker cp gitlab:/var/opt/gitlab/backups/. ./backups/
cp -r ./backups /path/to/safe/location/
```

#### Step 2: Export Current Configuration

```bash
# Backup GitLab configuration
docker exec gitlab tar czf /tmp/gitlab-config.tar.gz -C /etc/gitlab .
docker cp gitlab:/tmp/gitlab-config.tar.gz ./gitlab-config-backup.tar.gz

# Backup environment settings if using .env
cp .env .env.backup 2>/dev/null || echo "No .env file to backup"
```

#### Step 3: Document Current Settings

```bash
# Record your current external URL
docker exec gitlab grep external_url /etc/gitlab/gitlab.rb

# Record exposed ports
docker port gitlab

# Check current volumes
docker inspect gitlab | grep -A 10 Mounts
```

#### Step 4: Stop Old Container (DON'T REMOVE VOLUMES YET)

```bash
# Stop but don't remove (preserves volumes)
docker stop gitlab

# Optional: Keep old container for emergency rollback
docker rename gitlab gitlab-old
```

#### Step 5: Set Up New Configuration

```bash
# Run setup wizard for production
./setup-wizard.py --deployment-type production \
                  --domain your-domain.com \
                  --ssh-port 2222

# Review generated .env file
cat .env
```

#### Step 6: Migrate Data to New Container

Since named volumes have the same names, the new container will use existing data:

```bash
# Start with new production profile
docker-compose -f docker-compose.production.yml up -d

# Monitor startup (takes 5-10 minutes)
docker logs -f gitlab-production
```

#### Step 7: Verify Migration

```bash
# Check health
docker exec gitlab-production gitlab-healthcheck --fail --max-time 10

# Verify version
docker exec gitlab-production gitlab-rake gitlab:env:info

# Check web interface
curl -I https://your-domain.com
```

#### Step 8: Clean Up (After Confirming Everything Works)

```bash
# Remove old container (data is in volumes, safe to remove)
docker rm gitlab-old
```

### Path B: Sandbox/Development Migration (Bind Mounts)

If you're running a local development instance with bind mounts to `gitlab-local/`:

#### Step 1: Backup Local Data

```bash
# Stop current instance
docker-compose -f docker-compose.local.yml down

# Backup the entire local directory
cp -r gitlab-local gitlab-local-backup-$(date +%Y%m%d)
```

#### Step 2: Use New Sandbox Setup

```bash
# Run setup wizard in non-interactive mode
./setup-wizard.py --deployment-type sandbox --non-interactive

# Start new sandbox instance
docker-compose -f docker-compose.sandbox.yml up -d
```

The new sandbox will:
- Use different ports (8080, 8443, 2224) to avoid conflicts
- Create fresh `gitlab-local/` directory
- Have reduced resource requirements

#### Step 3: Migrate Repositories (Optional)

If you want to preserve repositories:

```bash
# Stop new container
docker-compose -f docker-compose.sandbox.yml down

# Copy repositories from backup
cp -r gitlab-local-backup-*/data/git-data/* gitlab-local/data/git-data/

# Restart and reconfigure
docker-compose -f docker-compose.sandbox.yml up -d
docker exec gitlab-sandbox gitlab-ctl reconfigure
```

### Path C: Fresh Installation

If you want to start fresh with the new setup:

#### For Production:

```bash
# Run setup wizard
./setup-wizard.py --deployment-type production

# Validate configuration
./validate-deployment.py --deployment-type production

# Deploy
docker-compose -f docker-compose.production.yml up -d
```

#### For Sandbox:

```bash
# Quick setup
./setup-wizard.py --deployment-type sandbox --non-interactive

# Deploy
docker-compose -f docker-compose.sandbox.yml up -d
```

## Rollback Procedures

### If Migration Fails

#### Option 1: Restore Old Container (Quick)

```bash
# Stop new container
docker-compose -f docker-compose.production.yml down

# Start old container
docker start gitlab
# or
docker rename gitlab-old gitlab
docker start gitlab
```

#### Option 2: Full Restore from Backup

```bash
# Stop new container and remove volumes (if corrupted)
docker-compose -f docker-compose.production.yml down -v

# Restore old container
docker rename gitlab-old gitlab
docker start gitlab

# Restore backup
GITLAB_CONTAINER_NAME=gitlab ./scripts/restore.sh <backup_filename>
```

## Post-Migration Tasks

### 1. Update Bookmarks and Documentation

- Update team documentation with new container name
- Update monitoring/alerting systems
- Update backup scripts that reference container name

### 2. Update SSH Remote URLs (If Port Changed)

If you changed SSH from port 22 to 2222:

```bash
# Update existing repository remotes
git remote set-url origin ssh://git@your-domain.com:2222/group/project.git
```

### 3. Configure Automation

Set up the new automation scripts:

```bash
# Test backup script
GITLAB_CONTAINER_NAME=gitlab-production ./scripts/backup.sh

# Configure cron job for automated backups
crontab -e
# Add: 0 2 * * * cd /path/to/gitlab && GITLAB_CONTAINER_NAME=gitlab-production ./scripts/backup.sh
```

### 4. Enable Security Features

For production deployments:

```bash
# Review security settings in docker-compose.production.yml
grep -A 20 "Security Settings" docker-compose.production.yml

# Configure fail2ban (see SECURITY.md)
# Set up monitoring alerts (see SECURITY.md)
```

### 5. Test Backup and Restore

```bash
# Create test backup
GITLAB_CONTAINER_NAME=gitlab-production ./scripts/backup.sh

# Test restore in sandbox (if available)
# See SECURITY.md for detailed testing procedures
```

## Common Migration Issues

### Issue: Port Conflicts

**Symptom:** Container fails to start with "port already allocated" error

**Solution:**
```bash
# Check what's using the port
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Option 1: Stop the conflicting service
sudo systemctl stop apache2  # or nginx

# Option 2: Use alternate ports (staging/sandbox)
# Edit docker-compose file or use sandbox profile (8080, 8443)
```

### Issue: Volume Permission Errors

**Symptom:** GitLab fails to start with permission denied errors

**Solution:**
```bash
# Check volume ownership
docker exec gitlab-production ls -la /var/opt/gitlab

# Fix permissions (if needed)
docker exec gitlab-production chown -R git:git /var/opt/gitlab
```

### Issue: SSL Certificate Errors

**Symptom:** Nginx fails to start, certificate not found

**Solution:**
```bash
# Verify certificates exist
ls -la config/ssl/

# Check certificate matches domain
./validate-deployment.py --deployment-type production

# Use self-signed for testing (STAGING ONLY)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout config/ssl/gitlab.staging.com.key \
  -out config/ssl/gitlab.staging.com.crt \
  -subj "/CN=gitlab.staging.com"
chmod 600 config/ssl/*.key
```

### Issue: Old Container Still Running

**Symptom:** Port conflicts or confusion about which GitLab is running

**Solution:**
```bash
# List all GitLab containers
docker ps -a | grep gitlab

# Stop and rename old container
docker stop gitlab
docker rename gitlab gitlab-old

# Verify only new container is running
docker ps --filter "name=gitlab"
```

### Issue: Data Not Migrating

**Symptom:** New container starts fresh without old data

**Solution:**
```bash
# Check if volumes are correctly named
docker volume ls | grep gitlab

# Verify new container uses existing volumes
docker inspect gitlab-production | grep -A 5 Mounts

# If using bind mounts, verify paths in docker-compose file
```

## Container Name Reference

Update any scripts, documentation, or automation that references container names:

| Old Name | New Name (Production) | New Name (Staging) | New Name (Sandbox) |
|----------|----------------------|-------------------|-------------------|
| `gitlab` | `gitlab-production` | `gitlab-staging` | `gitlab-sandbox` |

Examples of where to update:

- Backup scripts: `docker exec gitlab` → `docker exec gitlab-production`
- Monitoring: Container name filters
- CI/CD pipelines: Health checks, deployment scripts
- Documentation: Team runbooks, SOPs

## Getting Help

If you encounter issues during migration:

1. Check logs: `docker logs gitlab-production`
2. Review [DEPLOYMENT.md](DEPLOYMENT.md) for deployment-specific guidance
3. See [SECURITY.md](SECURITY.md) for security-related issues
4. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) if available
5. File an issue at: https://github.com/spohaver/gitlab-ce-container/issues

## Migration Checklist

Use this checklist to track your migration progress:

- [ ] Backup current GitLab data and configuration
- [ ] Document current settings (domain, ports, volumes)
- [ ] Choose migration path (A, B, or C)
- [ ] Stop old container (but keep for rollback)
- [ ] Run setup wizard for new deployment type
- [ ] Validate configuration with `validate-deployment.py`
- [ ] Start new container with appropriate compose file
- [ ] Verify GitLab is healthy and accessible
- [ ] Test login and basic functionality
- [ ] Update SSH remotes if port changed
- [ ] Configure automated backups
- [ ] Update documentation and monitoring
- [ ] Test backup and restore procedures
- [ ] Clean up old container (after confirmation)
- [ ] Notify team of changes (container name, ports, etc.)

## Timeline Recommendations

- **Sandbox/Development**: 30-60 minutes
- **Staging**: 1-2 hours (including testing)
- **Production**: 2-4 hours (including validation and testing)

Schedule production migrations during maintenance windows with adequate rollback time.
