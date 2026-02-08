# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains configuration and automation scripts for deploying GitLab Community Edition (CE) using Docker. It supports both production deployments with persistent volumes and local testing environments with reduced resource requirements.

## Architecture

The deployment uses the official `gitlab/gitlab-ce` Docker image, which is an omnibus package containing all GitLab components:

- **GitLab Application**: Main Rails application
- **PostgreSQL**: Database (built into container)
- **Redis**: Caching and job queues (built into container)
- **Nginx**: Web server and reverse proxy (built into container)
- **Sidekiq**: Background job processor (built into container)
- **Gitaly**: Git repository storage service (built into container)

Four deployment profiles are provided:
1. **Production** (`docker-compose.production.yml`): Pinned image version, named volumes, standard ports (80, 443, SSH on 2222), full security hardening
2. **Staging** (`docker-compose.staging.yml`): Mirrors production config for pre-release validation
3. **Sandbox** (`docker-compose.sandbox.yml`): Local development with alternate ports (8080, 8443, 2224), reduced resources (4GB RAM, 2 CPUs)

## Common Commands

### Production Environment

Start GitLab:
```bash
docker-compose -f docker-compose.production.yml up -d
```

Stop GitLab:
```bash
docker-compose -f docker-compose.production.yml down
```

View logs:
```bash
docker logs -f gitlab-production
```

Get initial root password:
```bash
docker exec -it gitlab-production grep 'Password:' /etc/gitlab/initial_root_password
```

Create backup:
```bash
GITLAB_CONTAINER_NAME=gitlab-production ./scripts/backup.sh
```

Restore from backup:
```bash
GITLAB_CONTAINER_NAME=gitlab-production ./scripts/restore.sh <backup_filename>
```

Update GitLab (creates backup first):
```bash
GITLAB_CONTAINER_NAME=gitlab-production ./scripts/update.sh docker-compose.production.yml
```

### Local Testing Environment

Setup and start local GitLab:
```bash
./setup-wizard.py --deployment-type sandbox --non-interactive
docker-compose -f docker-compose.sandbox.yml up -d
```

Check status and get root password:
```bash
docker-compose -f docker-compose.sandbox.yml ps
docker exec -it gitlab-sandbox grep 'Password:' /etc/gitlab/initial_root_password
```

Cleanup:
```bash
docker-compose -f docker-compose.sandbox.yml down -v
rm -rf gitlab-local/
```

Stop sandbox GitLab:
```bash
docker-compose -f docker-compose.sandbox.yml down
```

View sandbox logs:
```bash
docker logs -f gitlab-sandbox
```

### GitLab Maintenance Commands

Run inside GitLab container (use gitlab-production, gitlab-staging, or gitlab-sandbox):
```bash
docker exec -it gitlab-production bash
# or for sandbox:
docker exec -it gitlab-sandbox bash
```

Database cleanup:
```bash
docker exec gitlab gitlab-rake gitlab:db:clean
```

Clean artifacts:
```bash
docker exec gitlab gitlab-rake gitlab:artifacts:clean
```

Clean LFS objects:
```bash
docker exec gitlab gitlab-rake gitlab:lfs:clean
```

Reconfigure GitLab (after config changes):
```bash
docker exec gitlab gitlab-ctl reconfigure
```

Restart GitLab services:
```bash
docker exec gitlab gitlab-ctl restart
```

Check GitLab health:
```bash
docker exec gitlab gitlab-healthcheck --fail --max-time 10
```

## Key Configuration Files

- **docker-compose.production.yml**: Production deployment with named volumes and full security hardening
- **docker-compose.staging.yml**: Staging deployment mirroring production
- **docker-compose.sandbox.yml**: Sandbox/development with reduced resources
- **.env.example**: Template for environment variables (copy to `.env` and customize)
- **setup-wizard.py**: Interactive and automated setup wizard
- **validate-deployment.py**: Pre-deployment validation checks
- **SECURITY.md**: Comprehensive security guide including secrets management, backup testing, monitoring
- **config/gitlab.rb.template**: GitLab configuration template with Prometheus monitoring
- **scripts/backup.sh**: Automated backup with offsite sync examples
- **scripts/restore.sh**: Restore from backup with pre-restore backup and health checks
- **scripts/update.sh**: Safe update procedure (backup → pull → restart → health check)

## Template Repository Context

This is a **template repository** designed to be forked and customized. When working with this repo:

1. **Scripts use relative paths** - All scripts dynamically determine their location, making them portable
2. **Example configurations** - All `.env` values and configurations are examples meant to be customized
3. **Security entries commented** - `.gitignore` contains commented security entries that users should uncomment when forking
4. **Monitoring enabled by default** - Production configuration includes Prometheus monitoring
5. **Backup options provided** - `backup.sh` includes multiple offsite backup examples (S3, rclone, rsync, SFTP)

## Security Best Practices

**Before making changes to production configurations:**

1. Review [SECURITY.md](docs/SECURITY.md) for comprehensive security guidance
2. Ensure `.gitignore` security entries are uncommented in production forks
3. Never commit `.env` files, SSL private keys, or backup files
4. Use Prometheus monitoring in production (already enabled in `gitlab.rb.template`)
5. Implement offsite backups using one of the methods in `scripts/backup.sh`
6. Test restore procedures regularly (see SECURITY.md for testing procedures)

## Important Notes

### Container Names
- Production: `gitlab-production`
- Staging: `gitlab-staging`
- Sandbox: `gitlab-sandbox`

All scripts accept `GITLAB_CONTAINER_NAME` as an environment variable to override the default.

### Backup/Restore Process
- Backups are created using GitLab's native `gitlab-backup` command
- The restore script automatically creates a backup before restoring
- Both scripts include health checks and wait for GitLab to become fully operational
- Logs are stored in `logs/` directory with timestamps

### Sandbox Configuration
- Hostname: `localhost` or your local IP
- HTTP: http://localhost:8080
- HTTPS: https://localhost:8443 (self-signed certificate)
- SSH: Port 2224 (e.g., `git@localhost:2224`)
- Data stored in: `gitlab-local/data`, `gitlab-local/config`, `gitlab-local/logs`
- Self-signed SSL certificates: `gitlab-local/ssl`

### GitLab Startup Time
GitLab can take 5-10 minutes to fully initialize after starting the container. Use `docker logs -f <container_name>` to monitor progress.

### Initial Root Password
The initial root password is stored in `/etc/gitlab/initial_root_password` inside the container and expires 24 hours after installation. Always retrieve and change this password immediately after first startup.
