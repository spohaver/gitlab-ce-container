# Quick Start Guide - Sandbox/Development

Get GitLab running locally in under 10 minutes for development and testing.

## Prerequisites

- Docker 20.10+
- Docker Compose v2+
- 4GB+ RAM available
- 20GB+ free disk space

## Step 1: Run Setup Wizard

```bash
./setup-wizard.py
```

Select **1) Sandbox/Development** when prompted. The wizard will:
- Generate `.env` with sandbox defaults
- Create necessary directories
- Set up local configuration

**Or run non-interactively:**
```bash
./setup-wizard.py --deployment-type sandbox --non-interactive
```

## Step 2: Start GitLab

```bash
docker-compose -f docker-compose.sandbox.yml up -d
```

## Step 3: Wait for GitLab to Start

First startup takes 5-10 minutes. Monitor progress:

```bash
docker-compose -f docker-compose.sandbox.yml logs -f
```

Watch for: `gitlab Reconfigured!` - GitLab is ready when you see this.

## Step 4: Access GitLab

Open your browser to: **http://localhost:8080**

### First Login

- **Username**: `root`
- **Password**: Shown in terminal on first access, or retrieve with:
  ```bash
  docker exec gitlab-sandbox grep 'Password:' /etc/gitlab/initial_root_password
  ```

**Important**: Change the root password immediately after first login!

## Step 5: Configure Admin Account

1. Login as root with initial password
2. Go to **User Settings** (top-right avatar)
3. Select **Password** from left menu
4. Set a new secure password
5. (Optional) Enable 2FA for additional security

## Common Sandbox Tasks

### Stop GitLab
```bash
docker-compose -f docker-compose.sandbox.yml stop
```

### Restart GitLab
```bash
docker-compose -f docker-compose.sandbox.yml restart
```

### View Logs
```bash
docker-compose -f docker-compose.sandbox.yml logs -f gitlab
```

### Access GitLab Shell
```bash
docker exec -it gitlab-sandbox bash
```

### Create Backup
```bash
docker exec -t gitlab-sandbox gitlab-backup create
```

### Complete Reset (Delete All Data)
```bash
docker-compose -f docker-compose.sandbox.yml down
rm -rf gitlab-local/
docker volume prune -f
```

## Git SSH Access

For sandbox mode, SSH runs on port **2224**:

```bash
# Clone with SSH
git clone ssh://git@localhost:2224/username/repository.git

# Add remote
git remote add origin ssh://git@localhost:2224/username/repository.git
```

## Accessing from Other Devices

To access GitLab from other devices on your network:

1. Find your local IP:
   ```bash
   hostname -I | awk '{print $1}'
   ```

2. Access from other devices:
   ```
   http://YOUR_LOCAL_IP:8080
   ```

3. For SSH clone URLs, use your local IP instead of localhost

## Data Locations

All sandbox data is stored locally in `gitlab-local/`:

- **Configuration**: `gitlab-local/config/`
- **Repositories**: `gitlab-local/data/git-data/repositories/`
- **Logs**: `gitlab-local/logs/`
- **Backups**: `backups/`

## Troubleshooting

### Port Already in Use

If port 8080 is in use, edit `docker-compose.sandbox.yml`:

```yaml
ports:
  - '8081:80'      # Change 8080 to 8081
  - '8444:443'     # Change 8443 to 8444
```

### GitLab Won't Start / Container Keeps Restarting

Check logs:
```bash
docker-compose -f docker-compose.sandbox.yml logs gitlab
```

Common issues:
- **Insufficient memory**: Ensure 4GB+ RAM available
- **Disk full**: Check `df -h`
- **Port conflicts**: Use `netstat -tuln | grep -E '(8080|8443|2224)'`

### Forgot Root Password

Reset root password:
```bash
docker exec -it gitlab-sandbox gitlab-rake "gitlab:password:reset[root]"
```

### Performance Issues

Reduce resource usage in sandbox mode:

1. Edit `gitlab-local/config/gitlab.rb`
2. Add:
   ```ruby
   puma['worker_processes'] = 1
   sidekiq['max_concurrency'] = 5
   postgresql['shared_buffers'] = "128MB"
   ```
3. Restart GitLab:
   ```bash
   docker-compose -f docker-compose.sandbox.yml restart
   ```

### Clean Slate

To completely remove and reinstall:

```bash
# Stop and remove containers
docker-compose -f docker-compose.sandbox.yml down -v

# Delete all data
rm -rf gitlab-local/

# Start fresh
./setup-wizard.py
docker-compose -f docker-compose.sandbox.yml up -d
```

## What's Different in Sandbox Mode?

Sandbox mode has relaxed security for ease of development:

- ❌ **No SSL required** (HTTP only)
- ❌ **No email** (SMTP disabled)
- ❌ **Public signup enabled** (anyone can create account)
- ❌ **No rate limiting** (unlimited API requests)
- ❌ **Debug logging** (verbose output)
- ❌ **Weak session security** (longer timeouts)

**Never use sandbox configuration for production!**

## Next Steps

### Create Your First Project

1. Click **New project** on main dashboard
2. Choose **Create blank project**
3. Name your project
4. Choose visibility (Private/Internal/Public)
5. Click **Create project**

### Create Additional Users

1. As root, go to **Admin Area** (wrench icon)
2. Select **Users** → **New user**
3. Fill in user details
4. User receives email with setup instructions (if SMTP configured)

### Enable Features

Sandbox includes all GitLab CE features:
- Git repository management
- Issue tracking
- Merge requests
- CI/CD pipelines
- Wiki
- Container registry (requires additional configuration)
- Package registry

### Migrate to Staging/Production

When ready to deploy for real use:

1. Export your data:
   ```bash
   docker exec -t gitlab-sandbox gitlab-backup create
   ```

2. Run setup wizard for production:
   ```bash
   ./setup-wizard.py
   ```
   Select **3) Production**

3. Follow [QUICKSTART-PRODUCTION.md](QUICKSTART-PRODUCTION.md)

## Resources

- [GitLab CE Documentation](https://docs.gitlab.com/ee/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Repository SECURITY.md](SECURITY.md) - Security best practices
- [Repository DEPLOYMENT.md](DEPLOYMENT.md) - Advanced deployment guide

## Getting Help

- Check logs: `docker-compose -f docker-compose.sandbox.yml logs -f`
- Validate setup: `./validate-deployment.py sandbox`
- GitLab Community Forum: https://forum.gitlab.com/
- Repository Issues: [Create an issue](../../issues/new)

---

**Remember**: Sandbox mode is for development only. See [QUICKSTART-PRODUCTION.md](QUICKSTART-PRODUCTION.md) for production deployment.
