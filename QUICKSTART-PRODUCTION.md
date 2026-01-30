# Quick Start Guide - Production Deployment

Complete guide for deploying GitLab CE in production with security hardening.

⚠️ **Production deployment is serious business!** Follow all steps carefully.

## Prerequisites

### System Requirements

- **OS**: Ubuntu 20.04+ / Debian 11+ / RHEL 8+ / CentOS 8+
- **CPU**: 4+ cores (8+ recommended)
- **RAM**: 8GB minimum (16GB+ recommended)
- **Disk**: 50GB+ free space (SSD strongly recommended)
- **Network**: Static IP, domain name with DNS configured

### Required Software

- Docker Engine 20.10+
- Docker Compose v2+
- `ufw` (firewall)
- `fail2ban` (brute-force protection)
- `openssl` (certificate management)

### Before You Begin

- [ ] Domain name registered and DNS configured
- [ ] SSL certificate obtained (Let's Encrypt or commercial CA)
- [ ] Backup strategy planned
- [ ] Maintenance window scheduled
- [ ] Team notified of deployment

## Step-by-Step Deployment

### Step 1: System Preparation

#### Update System
```bash
sudo apt update && sudo apt upgrade -y
# or for RHEL/CentOS:
# sudo yum update -y
```

#### Install Docker
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Log out and back in for group changes to take effect
```

#### Install fail2ban
```bash
sudo apt install fail2ban -y
# or: sudo yum install fail2ban -y

sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

#### Configure Firewall
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 2222/tcp  # GitLab SSH (adjust if using different port)
sudo ufw enable
```

### Step 2: Obtain SSL Certificate

#### Option A: Let's Encrypt (Recommended)

```bash
# Install certbot
sudo apt install certbot -y

# Obtain certificate (ensure ports 80/443 are open and domain points to server)
sudo certbot certonly --standalone -d gitlab.yourdomain.com

# Certificates will be in: /etc/letsencrypt/live/gitlab.yourdomain.com/
```

#### Option B: Commercial Certificate

Place your certificate files:
- Certificate: `config/ssl/gitlab.yourdomain.com.crt`
- Private key: `config/ssl/gitlab.yourdomain.com.key`
- Certificate chain (if applicable): `config/ssl/gitlab.yourdomain.com-chain.crt`

### Step 3: Configure GitLab

#### Clone Repository
```bash
cd /opt
git clone https://github.com/yourusername/gitlab-server.git
cd gitlab-server
```

#### Run Setup Wizard
```bash
./setup-wizard.sh
```

Select **3) Production** and provide:
- Your domain name
- SMTP credentials (for email notifications)
- Review all security settings

The wizard will:
- Generate secure `.env` file
- Configure production-hardened settings
- Create necessary directories
- Generate secure passwords

#### Verify .env Configuration

```bash
# Set secure permissions
chmod 600 .env

# Review and customize
nano .env
```

Ensure all values are properly set:
- `GITLAB_DOMAIN` - Your actual domain
- `GITLAB_SMTP_*` - Valid SMTP credentials
- No placeholder or example values remain

### Step 4: SSL Certificate Setup

#### Copy Certificates to Config Directory

```bash
# From Let's Encrypt
sudo cp /etc/letsencrypt/live/gitlab.yourdomain.com/fullchain.pem \
  config/ssl/gitlab.yourdomain.com.crt
sudo cp /etc/letsencrypt/live/gitlab.yourdomain.com/privkey.pem \
  config/ssl/gitlab.yourdomain.com.key

# Set proper ownership and permissions
sudo chown $USER:$USER config/ssl/*
chmod 644 config/ssl/*.crt
chmod 600 config/ssl/*.key
```

#### Configure Auto-Renewal (Let's Encrypt)

```bash
# Add renewal hook to copy updated certificates
sudo nano /etc/letsencrypt/renewal-hooks/deploy/gitlab-cert-renewal.sh
```

Add:
```bash
#!/bin/bash
cp /etc/letsencrypt/live/gitlab.yourdomain.com/fullchain.pem \
  /opt/gitlab-server/config/ssl/gitlab.yourdomain.com.crt
cp /etc/letsencrypt/live/gitlab.yourdomain.com/privkey.pem \
  /opt/gitlab-server/config/ssl/gitlab.yourdomain.com.key
docker-compose -f /opt/gitlab-server/docker-compose.production.yml restart
```

```bash
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/gitlab-cert-renewal.sh
```

### Step 5: Validate Configuration

```bash
./validate-deployment.sh production
```

Review all checks. Fix any errors before proceeding.

**Critical checks:**
- ✅ .env file exists with secure permissions
- ✅ SSL certificates valid and not expired
- ✅ Required ports available
- ✅ .gitignore properly configured
- ✅ Sufficient system resources

### Step 6: Deploy GitLab

#### Start GitLab
```bash
docker-compose -f docker-compose.production.yml up -d
```

#### Monitor Startup (First boot: 5-10 minutes)
```bash
docker-compose -f docker-compose.production.yml logs -f
```

Watch for:
```
gitlab Reconfigured!
gitlab The latest version of GitLab is already running!
```

Press `Ctrl+C` to exit log view (GitLab continues running).

#### Verify Container Health
```bash
docker ps
docker-compose -f docker-compose.production.yml ps
```

Status should show `healthy` after startup period.

### Step 7: Initial Security Configuration

#### Access GitLab
Open browser: `https://gitlab.yourdomain.com`

#### First Login

**Username**: `root`

**Password**: From setup wizard output, or:
```bash
grep GITLAB_ROOT_PASSWORD .env
# or
docker exec gitlab-production grep 'Password:' /etc/gitlab/initial_root_password
```

#### Immediate Security Actions

1. **Change Root Password**
   - Click avatar (top right) → **Edit profile**
   - Select **Password** → Set strong password (20+ characters)
   - Save changes

2. **Enable 2FA for Root Account**
   - **Edit profile** → **Account** → **Enable Two-Factor Authentication**
   - Scan QR code with authenticator app
   - Save recovery codes in secure location

3. **Disable Initial Root Password File**
   ```bash
   docker exec gitlab-production rm /etc/gitlab/initial_root_password
   ```

4. **Review Admin Settings**
   - Go to **Admin Area** (wrench icon)
   - **Settings** → **General**
   - **Sign-up restrictions**: Verify signup is disabled
   - **Sign-in restrictions**: Configure session duration, 2FA enforcement
   - **Account and limit**: Set project/group limits

### Step 8: Configure Automated Backups

#### Test Backup
```bash
./scripts/backup.sh
```

Verify backup created in `backups/` directory.

#### Configure Offsite Backup

Edit `scripts/backup.sh` and uncomment/configure one backup destination:
- AWS S3
- rclone (Google Drive, Dropbox, etc.)
- rsync to remote server
- SFTP

#### Set Up Cron Job
```bash
crontab -e
```

Add (daily backup at 2 AM):
```cron
0 2 * * * /opt/gitlab-server/scripts/backup.sh >> /var/log/gitlab-backup.log 2>&1
```

#### Test Backup Restoration
```bash
# Create test backup
./scripts/backup.sh

# Test restore (in non-production environment!)
# ./scripts/restore.sh backups/your-backup-file.tar
```

### Step 9: Monitoring and Alerting

#### Access Prometheus Metrics

Metrics available at: `http://localhost:9090` (from server)

To access remotely, set up SSH tunnel:
```bash
ssh -L 9090:localhost:9090 user@gitlab.yourdomain.com
```

Then access: `http://localhost:9090`

#### Set Up External Monitoring (Recommended)

Configure external service to monitor:
- HTTPS endpoint availability
- SSL certificate expiration
- Disk space
- Container health

Recommended services:
- UptimeRobot (free)
- Pingdom
- Datadog
- Prometheus + Grafana (self-hosted)

### Step 10: Create Admin Documentation

Document your deployment:
- [ ] Server IP and access credentials
- [ ] Domain and DNS configuration
- [ ] SSL certificate renewal process
- [ ] Backup location and restoration procedure
- [ ] Monitoring and alert contacts
- [ ] Emergency contacts and procedures

## Post-Deployment Configuration

### Create First Regular User

1. **Admin Area** → **Users** → **New user**
2. Fill in details, assign role
3. User receives email with setup link
4. User sets password and enables 2FA

### Create First Group/Project

1. **Groups** → **New group**
2. Set visibility and permissions
3. **New project** within group
4. Configure project settings

### Configure Runner (CI/CD)

See: [GitLab Runner Documentation](https://docs.gitlab.com/runner/)

```bash
# Install GitLab Runner on separate machine or same server
docker run -d --name gitlab-runner --restart always \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest

# Register runner
docker exec -it gitlab-runner gitlab-runner register
```

### Configure Email Notifications

Test email:
```bash
docker exec -it gitlab-production gitlab-rails console

# In Rails console:
Notify.test_email('your-email@example.com', 'Test Subject', 'Test Body').deliver_now
```

### Configure Backup Retention

Edit `.env`:
```bash
# Keep backups for 7 days
GITLAB_BACKUP_KEEP_TIME=604800
```

Restart GitLab:
```bash
docker-compose -f docker-compose.production.yml restart
```

## Maintenance

### Update GitLab

**Always test updates in staging first!**

```bash
# 1. Backup current installation
./scripts/backup.sh

# 2. Update image version in docker-compose.production.yml
nano docker-compose.production.yml
# Change: gitlab/gitlab-ce:18.4.0 to gitlab/gitlab-ce:18.5.0

# 3. Pull new image
docker-compose -f docker-compose.production.yml pull

# 4. Stop, update, and restart
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml up -d

# 5. Monitor logs
docker-compose -f docker-compose.production.yml logs -f
```

### Regular Maintenance Tasks

**Daily:**
- [ ] Check automated backup completed
- [ ] Review error logs

**Weekly:**
- [ ] Review user activity
- [ ] Check disk space
- [ ] Verify backup integrity

**Monthly:**
- [ ] Test disaster recovery procedure
- [ ] Review security settings
- [ ] Check for GitLab updates
- [ ] Review and rotate credentials

**Quarterly:**
- [ ] Security audit
- [ ] Performance review
- [ ] Update documentation

## Security Hardening Checklist

- [x] SSL/TLS with modern protocols only
- [ ] 2FA enabled for all admin accounts
- [ ] 2FA enforced for all users (optional but recommended)
- [ ] IP whitelisting for admin panel (if applicable)
- [ ] Rate limiting configured
- [ ] Signup disabled or restricted
- [ ] Strong password policy enforced
- [ ] Session timeout configured
- [ ] Audit logging enabled
- [ ] Regular security updates applied
- [ ] Backup encryption enabled
- [ ] fail2ban configured and active
- [ ] Firewall rules restrictive
- [ ] Minimal exposed ports
- [ ] Regular vulnerability scans
- [ ] Incident response plan documented

## Troubleshooting

### GitLab Not Starting

```bash
# Check container status
docker-compose -f docker-compose.production.yml ps

# Check logs
docker-compose -f docker-compose.production.yml logs gitlab

# Check system resources
df -h
free -h
```

### SSL Certificate Issues

```bash
# Verify certificate
openssl x509 -in config/ssl/gitlab.yourdomain.com.crt -text -noout

# Check expiration
openssl x509 -enddate -noout -in config/ssl/gitlab.yourdomain.com.crt

# Verify private key matches certificate
openssl x509 -noout -modulus -in config/ssl/gitlab.yourdomain.com.crt | openssl md5
openssl rsa -noout -modulus -in config/ssl/gitlab.yourdomain.com.key | openssl md5
# Hashes should match
```

### Email Not Working

```bash
# Test SMTP connection
docker exec -it gitlab-production gitlab-rails console

# In console:
ActionMailer::Base.delivery_method
ActionMailer::Base.smtp_settings
Notify.test_email('test@example.com', 'Subject', 'Body').deliver_now
```

### Performance Issues

```bash
# Check resource usage
docker stats gitlab-production

# Review GitLab performance
# Access: Admin Area → Monitoring → System Info
```

### Backup Failures

```bash
# Check backup logs
tail -100 /var/log/gitlab-backup.log

# Verify permissions
ls -la backups/

# Check disk space
df -h
```

## Emergency Procedures

### Complete System Failure

1. **Notify stakeholders**
2. **Assess damage**
3. **Retrieve latest backup** (offsite)
4. **Provision new server** (if hardware failure)
5. **Follow restoration procedure**:
   ```bash
   # Copy backup to new server
   # Run setup
   ./setup-wizard.sh  # Use same configuration
   
   # Start GitLab
   docker-compose -f docker-compose.production.yml up -d
   
   # Wait for startup, then restore
   ./scripts/restore.sh backups/latest-backup.tar
   ```
6. **Verify restoration**
7. **Update DNS** (if IP changed)
8. **Notify users of service restoration**

### Security Breach

1. **Isolate system** - Stop GitLab
2. **Preserve evidence** - Don't delete logs
3. **Assess impact** - What was accessed/modified?
4. **Notify affected parties**
5. **Change all credentials**
6. **Review and restore from clean backup if needed**
7. **Apply security patches**
8. **Document incident**
9. **Implement additional security measures**

## Resources

- **GitLab Documentation**: https://docs.gitlab.com/ee/
- **Security Best Practices**: [SECURITY.md](SECURITY.md)
- **Backup Guide**: [scripts/backup.sh](scripts/backup.sh)
- **Repository Issues**: [Report Issue](../../issues/new)
- **GitLab Community**: https://forum.gitlab.com/

## Support

For production issues:
1. Check logs first
2. Review [DEPLOYMENT.md](DEPLOYMENT.md)
3. Consult GitLab documentation
4. GitLab Community Forum
5. Consider GitLab Premium support for mission-critical deployments

---

**Congratulations on your production deployment!** Remember:
- Keep backups tested and accessible
- Apply security updates promptly  
- Monitor system health regularly
- Document changes and procedures
