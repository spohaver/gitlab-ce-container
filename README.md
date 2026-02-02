# GitLab CE Docker Server

This repository contains configuration and setup files for deploying GitLab Community Edition using Docker.

> **📋 Template Repository**: This is a flexible template supporting multiple deployment types:
> - **Sandbox**: Quick local testing and development (5 minutes to start)
> - **Staging**: Pre-production environment with production-like security
> - **Production**: Fully hardened deployment for live use
>
> ⚠️ **Security Notice**: This repository has security controls enabled by default. The `.gitignore` file protects sensitive data like `.env` files, SSL keys, and backups from being committed.
>
> 🚀 **Deployment Flexible**: Works from any directory, supports custom container names, and can run multiple instances simultaneously. See [DEPLOYMENT-FLEXIBILITY.md](DEPLOYMENT-FLEXIBILITY.md) for details.

## Features

- **Multiple Deployment Profiles**: Sandbox, staging, and production configurations
- **Interactive Setup Wizard**: Guided configuration for any deployment type
- **Automated Validation**: Pre-deployment checks catch common misconfigurations
- **Security Hardened**: Production-ready security defaults
- **Persistent Data**: Docker volumes for reliable data storage
- **Automated Backups**: Scripts for backup, restore, and offsite sync
- **HTTPS/SSL**: Full SSL/TLS support with modern protocols
- **Update Automation**: Safe update procedures with rollback support
- **Comprehensive Documentation**: Quickstart guides for each deployment type
- **Security Scanning**: Automated SAST and secret detection tools included

## Quick Start

### Choose Your Path

**🏖️ Sandbox/Development** (Local testing in 5 minutes)
```bash
# Interactive mode
./setup-wizard.py
# Select option 1: Sandbox

# Or non-interactive
./setup-wizard.py --deployment-type sandbox --non-interactive

# Start GitLab
docker-compose -f docker-compose.sandbox.yml up -d
# Access at http://localhost:8080
```
📖 **Full Guide**: [QUICKSTART-SANDBOX.md](QUICKSTART-SANDBOX.md)

**🚀 Production** (Complete deployment guide)
```bash
# Interactive mode
./setup-wizard.py
# Select option 3: Production

# Or automated (CI/CD)
./setup-wizard.py --deployment-type production --domain gitlab.example.com --non-interactive

# Validate before deployment
./validate-deployment.py --non-interactive

# Deploy
docker-compose -f docker-compose.production.yml up -d
```
📖 **Full Guides**: [QUICKSTART-PRODUCTION.md](QUICKSTART-PRODUCTION.md) | [AUTOMATION.md](AUTOMATION.md)

### Prerequisites

**Minimum Requirements:**
- Docker Engine 20.10+
- Docker Compose v2+
- 4GB+ RAM (8GB+ for production)
- 20GB+ storage (50GB+ for production)

**Production Additional Requirements:**
- Domain name with DNS configured
- Valid SSL certificate (Let's Encrypt or commercial)
- Static IP address
- Firewall (ufw) and fail2ban

## Deployment Profiles

This template provides three deployment configurations:

| Profile | Use Case | Security | Setup Time |
|---------|----------|----------|------------|
| **Sandbox** | Local development, testing | Minimal | 5 minutes |
| **Staging** | Pre-production, testing | High | 30 minutes |
| **Production** | Live deployment | Maximum | 1-2 hours |

### Profile Comparison

| Feature | Sandbox | Staging | Production |
|---------|---------|---------|------------|
| SSL/TLS | Optional | Required | Required |
| Email | Disabled | Optional | Required |
| Ports | 8080, 8443, 2224 | 80, 443, 2222 | 80, 443, 2222 |
| Version | :latest | Pinned | Pinned |
| Resources | 4GB RAM, 2 CPU | 8GB RAM, 4 CPU | 16GB RAM, 8 CPU |
| Signup | Enabled | Disabled | Disabled |
| 2FA | Optional | Recommended | Required |
| Backups | Local | Offsite recommended | Offsite required |
| Monitoring | Optional | Recommended | Required |

## Setup Methods

### Method 1: Interactive Wizard (Recommended)

The setup wizard guides you through configuration:

```bash
./setup-wizard.py
```

The wizard will:
- Detect your deployment type
- Generate secure `.env` configuration
- Create necessary directories
- Run validation checks
- Provide next steps

### Method 2: Non-Interactive (CI/CD & Automation)

For automated deployments, use the Python scripts with command-line arguments:

```bash
# Configure for production non-interactively
./setup-wizard.py \
  --deployment-type production \
  --domain gitlab.example.com \
  --smtp-address smtp.gmail.com \
  --smtp-user gitlab@example.com \
  --smtp-password "${SMTP_PASSWORD}" \
  --root-password "${ROOT_PASSWORD}" \
  --non-interactive \
  --force

# Validate configuration
./validate-deployment.py --non-interactive

# Deploy if validation passes
if [ $? -eq 0 ]; then
  docker-compose -f docker-compose.production.yml up -d
fi
```

📖 **Full Automation Guide**: [AUTOMATION.md](AUTOMATION.md) - CI/CD examples, GitHub Actions, GitLab CI, Jenkins, Ansible, Terraform

### Method 3: Manual Configuration

For advanced users or custom scenarios:

1. **Copy environment template:**
   ```bash
   cp .env.example .env
   chmod 600 .env
   ```

2. **Edit configuration:**
   ```bash
   nano .env
   # Set GITLAB_DOMAIN, SMTP credentials, etc.
   ```

3. **Validate configuration:**
   ```bash
   ./validate-deployment.py production
   ```

4. **Deploy:**
   ```bash
   docker-compose -f docker-compose.production.yml up -d
   ```

## Initial Login

The initial root password depends on your deployment type:

**Sandbox:**
```bash
docker exec -it gitlab-sandbox grep 'Password:' /etc/gitlab/initial_root_password
```

**Production:**
```bash
# Password was shown during setup wizard, or:
grep GITLAB_ROOT_PASSWORD .env
# or from GitLab:
docker exec -it gitlab-production grep 'Password:' /etc/gitlab/initial_root_password
```

**⚠️ Change this password immediately after first login!**

## Directory Structure

```
gitlab-server/
├── docker-compose.yml              # Base configuration (reference)
├── docker-compose.sandbox.yml      # Sandbox/development profile
├── docker-compose.staging.yml      # Staging profile
├── docker-compose.production.yml   # Production profile
├── docker-compose.local.yml        # Local testing (legacy)
│
├── setup-wizard.py                 # Interactive & automated setup wizard
├── validate-deployment.py          # Pre-deployment validation
│
├── .env.example                    # Environment variable template
├── .env                            # Your configuration (generated, not in Git)
├── .gitignore                      # Security-enabled by default
│
├── config/
│   ├── gitlab.rb.template          # GitLab configuration template
│   └── ssl/                        # SSL certificates (not in Git)
│
├── scripts/
│   ├── backup.sh                   # Automated backup with offsite sync
│   ├── restore.sh                  # Restore from backup
│   └── update.sh                   # Safe update procedure
│
├── gitlab-local/                   # Sandbox runtime data (not in Git)
│   ├── data/                       # GitLab data
│   ├── config/                     # GitLab config
│   ├── logs/                       # Log files
│   └── ssl/                        # Self-signed certs for sandbox
│
├── backups/                        # Backup files (not in Git)
├── logs/                           # Script logs (not in Git)
│
├── QUICKSTART-SANDBOX.md           # 5-minute sandbox setup guide
├── QUICKSTART-PRODUCTION.md        # Complete production guide
├── DEPLOYMENT.md                   # Advanced deployment topics
├── SECURITY.md                     # Security best practices
├── ARCHITECTURE.md                 # System architecture
└── README.md                       # This file
```

## Common Tasks

### Checking Status

```bash
# Sandbox
docker-compose -f docker-compose.sandbox.yml ps

# Production
docker-compose -f docker-compose.production.yml ps
```

### Viewing Logs

```bash
# Sandbox
docker-compose -f docker-compose.sandbox.yml logs -f

# Production
docker-compose -f docker-compose.production.yml logs -f gitlab
```

### Restarting GitLab

```bash
# Sandbox
docker-compose -f docker-compose.sandbox.yml restart

# Production
docker-compose -f docker-compose.production.yml restart
```

### Creating Backups

```bash
./scripts/backup.sh
# Backups saved to: backups/
```

### Restoring from Backup

```bash
./scripts/restore.sh backups/your-backup-file.tar
```

### Updating GitLab

```bash
# 1. Update image version in docker-compose file
nano docker-compose.production.yml
# Change: gitlab/gitlab-ce:18.8.2-ce.0 to the target version (e.g., 18.9.0-ce.0)

# 2. Run update (creates backup automatically, pulls new image, restarts, health checks)
GITLAB_CONTAINER_NAME=gitlab-production ./scripts/update.sh docker-compose.production.yml
```

### Validating Configuration

```bash
# Check for issues before deployment
./validate-deployment.py production
```

## Troubleshooting

### Setup Wizard Issues

**Problem**: Wizard fails or asks unexpected questions

**Solution**:
```bash
# Remove partial configuration and start fresh
rm .env docker-compose.override.yml
./setup-wizard.sh
```

### Port Conflicts

**Problem**: "Port already in use" error

**Solution**:
```bash
# Find what's using the port
sudo netstat -tulpn | grep :8080

# Either stop the conflicting service or change GitLab ports
# Edit the compose file to use different ports
```

### SSL Certificate Issues

**Problem**: SSL certificate not found or invalid

**Solution**:
```bash
# Verify certificates exist
ls -l config/ssl/

# Check certificate validity
openssl x509 -in config/ssl/yourdomain.crt -text -noout

# Ensure correct permissions
chmod 644 config/ssl/*.crt
chmod 600 config/ssl/*.key
```

### Container Won't Start

**Problem**: GitLab container keeps restarting

**Solution**:
```bash
# Check logs for errors
docker-compose -f docker-compose.production.yml logs gitlab

# Common issues:
# - Insufficient memory (need 4GB+ available)
# - Disk full (check: df -h)
# - Port conflicts (check: netstat -tuln)
# - Invalid configuration (run: ./validate-deployment.py)
```

### Forgot Root Password

**Solution**:
```bash
# Reset root password
docker exec -it gitlab-production gitlab-rake "gitlab:password:reset[root]"
```

### More Help

- Check deployment-specific guides: [QUICKSTART-SANDBOX.md](QUICKSTART-SANDBOX.md) or [QUICKSTART-PRODUCTION.md](QUICKSTART-PRODUCTION.md)
- Review logs: `docker-compose -f <profile> logs -f`
- Run validation: `./validate-deployment.py`
- See [DEPLOYMENT.md](DEPLOYMENT.md) for advanced topics

## Security Best Practices

**CRITICAL**: Read [SECURITY.md](SECURITY.md) before production deployment!

Quick security checklist:

### For All Deployments
- ✅ `.env` file has secure permissions (600)
- ✅ Never commit `.env`, SSL keys, or backups to Git
- ✅ Change initial root password immediately
- ✅ Use strong passwords (20+ characters)

### For Production Only
- ✅ Valid SSL certificate (not self-signed)
- ✅ Enable 2FA for all admin accounts
- ✅ Configure automated backups with offsite storage
- ✅ Enable firewall (ufw) and fail2ban
- ✅ Use pinned GitLab version (not :latest)
- ✅ Test disaster recovery procedures
- ✅ Set up monitoring and alerting
- ✅ Keep GitLab updated with security patches
4. **Backups**: Set up automated backups with offsite storage (see [SECURITY.md](SECURITY.md))
5. **Monitoring**: Enable Prometheus metrics for production deployments
6. **Firewall**: Configure firewall to allow only necessary ports (80, 443, 22)
7. **Updates**: Regularly update GitLab to the latest version

See [SECURITY.md](SECURITY.md) for detailed security hardening procedures, backup testing, and incident response guidelines.

## Customization

To customize GitLab configuration, edit the `.env` file and restart GitLab:

### Advanced Configuration

For advanced customization, see [DEPLOYMENT.md](DEPLOYMENT.md) for topics including:
- Custom GitLab configuration (gitlab.rb)
- LDAP/OAuth integration
- Container registry setup
- Custom runners
- High availability
- Performance tuning

## Documentation

### Quick Start Guides
- **[QUICKSTART-SANDBOX.md](QUICKSTART-SANDBOX.md)** - Get started with local testing in 5 minutes
- **[QUICKSTART-PRODUCTION.md](QUICKSTART-PRODUCTION.md)** - Complete production deployment guide
- **[AUTOMATION.md](AUTOMATION.md)** - CI/CD integration, non-interactive mode, automation examples

### Comprehensive Guides
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Advanced deployment topics and configurations
- **[DEPLOYMENT-FLEXIBILITY.md](DEPLOYMENT-FLEXIBILITY.md)** - Installation location and container name flexibility
- **[SECURITY.md](SECURITY.md)** - Security best practices and hardening checklist
- **[SECURITY-AUDIT.md](SECURITY-AUDIT.md)** - Security audit report and SAST findings
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and design decisions

### Scripts

**Setup & Validation:**
- **[setup-wizard.py](setup-wizard.py)** - Interactive configuration wizard (interactive & automated)
- **[validate-deployment.py](validate-deployment.py)** - Pre-deployment validation checks- **[security-scan.sh](security-scan.sh)** - SAST and vulnerability scanner
**Maintenance:**
- **[scripts/backup.sh](scripts/backup.sh)** - Automated backup with offsite sync options
- **[scripts/restore.sh](scripts/restore.sh)** - Restore from backup
- **[scripts/update.sh](scripts/update.sh)** - Safe update procedure

💡 **Tip**: Python scripts support both interactive and non-interactive modes. See [AUTOMATION.md](AUTOMATION.md) for details.

## Support and Contributing

### Getting Help

1. **Check the documentation** - Most questions are answered in the guides above
2. **Run validation** - `./validate-deployment.py` catches common issues
3. **Check logs** - `docker-compose -f <profile> logs -f`
4. **Search issues** - Someone may have encountered the same problem
5. **Ask the community** - [GitLab Community Forum](https://forum.gitlab.com/)

### Contributing

Contributions are welcome! Please:
1. Fork this repository
2. Create a feature branch
3. Make your changes
4. Test with all three deployment profiles
5. Submit a pull request

### Reporting Issues

When reporting issues, please include:
- Deployment type (sandbox/staging/production)
- Output from `./validate-deployment.py`
- Relevant log excerpts
- Steps to reproduce

## Resources

- **[GitLab Official Documentation](https://docs.gitlab.com/ee/)**
- **[GitLab Docker Documentation](https://docs.gitlab.com/omnibus/docker/)**
- **[GitLab Configuration Options](https://docs.gitlab.com/omnibus/settings/configuration.html)**
- **[GitLab Backup/Restore](https://docs.gitlab.com/ee/raketasks/backup_restore.html)**
- **[GitLab Community Forum](https://forum.gitlab.com/)**
- **[GitLab Security Releases](https://about.gitlab.com/releases/categories/releases/)**

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

This template was created to simplify GitLab CE deployment while maintaining security best practices. It supports use cases from quick local testing to production-grade deployments.

---

**Ready to get started?**
- **Quick testing**: Run `./setup-wizard.py` and select Sandbox
- **Production deployment**: Read [QUICKSTART-PRODUCTION.md](QUICKSTART-PRODUCTION.md) first
