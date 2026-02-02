# Security and Operations Guide

This document provides security best practices and operational procedures for deploying GitLab CE in production.

## Table of Contents

1. [Secrets Management](#secrets-management)
2. [Backup and Disaster Recovery Testing](#backup-and-disaster-recovery-testing)
3. [Security Hardening Checklist](#security-hardening-checklist)
4. [Monitoring and Alerting](#monitoring-and-alerting)
5. [Incident Response](#incident-response)

---

## Secrets Management

### Environment Variables (.env file)

The `.env` file contains sensitive configuration including SMTP passwords, API keys, and other credentials.

**CRITICAL: Never commit the `.env` file to version control.**

#### Initial Setup

1. Copy the example file:
   ```bash
   cp .env.example .env
   ```

2. Set restrictive permissions:
   ```bash
   chmod 600 .env
   chown $(whoami):$(whoami) .env
   ```

3. Uncomment the `.env` entry in `.gitignore` to prevent accidental commits:
   ```bash
   # In .gitignore, uncomment:
   .env
   ```

#### Best Practices for Secrets

**Option 1: Docker Secrets (Recommended for Docker Swarm)**

1. Create secrets:
   ```bash
   echo "your-smtp-password" | docker secret create gitlab_smtp_password -
   ```

2. Modify `docker-compose.yml` to use secrets:
   ```yaml
   secrets:
     - gitlab_smtp_password
   ```

**Option 2: Environment Variables with Encryption**

1. Encrypt the `.env` file when not in use:
   ```bash
   gpg --symmetric --cipher-algo AES256 .env
   rm .env  # Remove unencrypted version
   ```

2. Decrypt when needed:
   ```bash
   gpg --decrypt .env.gpg > .env
   ```

**Option 3: HashiCorp Vault (Enterprise)**

For larger deployments, integrate with HashiCorp Vault:

```bash
# Install Vault
# Configure Vault to store GitLab secrets
# Modify scripts to fetch secrets from Vault at runtime
```

**Option 4: AWS Secrets Manager / Azure Key Vault**

For cloud deployments, use cloud-native secret management:

```bash
# Example: AWS Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id gitlab/smtp-password \
  --query SecretString --output text
```

### SSL Certificate Management

**Private Key Security:**

1. Store private keys with restrictive permissions:
   ```bash
   chmod 600 config/ssl/*.key
   ```

2. Uncomment in `.gitignore`:
   ```
   config/ssl/*.key
   *.key
   *.pem
   ```

**Let's Encrypt Auto-Renewal:**

1. Set up certbot with auto-renewal:
   ```bash
   # Install certbot
   sudo apt install certbot

   # Obtain certificate
   sudo certbot certonly --standalone -d gitlab.example.com

   # Set up auto-renewal cron job
   sudo crontab -e
   # Add: 0 3 * * * certbot renew --quiet --post-hook "docker exec gitlab gitlab-ctl restart nginx"
   ```

2. Monitor certificate expiration:
   ```bash
   # Check expiration date
   openssl x509 -in config/ssl/gitlab.crt -noout -enddate
   ```

---

## Backup and Disaster Recovery Testing

### Why Test Backups?

**Untested backups are not backups.** Regular restore testing ensures:
- Backups are not corrupted
- Restore procedures work correctly
- Recovery Time Objective (RTO) is achievable
- Team knows the recovery process

### Backup Testing Schedule

**Recommended Schedule:**
- **Weekly**: Verify backup files exist and are not corrupted
- **Monthly**: Full restore test to a separate test environment
- **Quarterly**: Complete disaster recovery drill

### Backup Verification Script

Create a weekly backup verification job:

```bash
#!/bin/bash
# verify-backups.sh

BACKUP_DIR="./backups"
LATEST_BACKUP=$(ls -t $BACKUP_DIR/*_gitlab_backup.tar 2>/dev/null | head -1)

if [ -z "$LATEST_BACKUP" ]; then
  echo "ERROR: No backup files found!"
  # Send alert
  exit 1
fi

# Check if backup is recent (less than 36 hours old)
if [ $(find "$LATEST_BACKUP" -mtime +1.5 | wc -l) -gt 0 ]; then
  echo "WARNING: Latest backup is older than 36 hours"
  # Send alert
fi

# Verify backup file integrity
if tar -tzf "$LATEST_BACKUP" > /dev/null 2>&1; then
  echo "SUCCESS: Backup file is valid: $LATEST_BACKUP"
else
  echo "ERROR: Backup file is corrupted: $LATEST_BACKUP"
  # Send critical alert
  exit 1
fi
```

Add to crontab:
```bash
# Run every Monday at 9 AM
0 9 * * 1 /path/to/gitlab-server/verify-backups.sh
```

### Monthly Restore Test Procedure

**1. Set up a test environment:**

```bash
# Use docker-compose.local.yml or a separate test server
docker-compose -f docker-compose.local.yml up -d
```

**2. Restore latest backup to test environment:**

```bash
# Copy backup to test environment
LATEST_BACKUP=$(ls -t backups/*_gitlab_backup.tar | head -1)
./scripts/restore.sh $(basename $LATEST_BACKUP)
```

**3. Verify restoration:**

- [ ] GitLab web interface loads
- [ ] Can log in with test credentials
- [ ] Repositories are accessible
- [ ] Issues and merge requests are present
- [ ] CI/CD pipelines are visible
- [ ] User accounts and permissions are correct

**4. Document Results:**

Create a restore test log:

```bash
# restore-test-log.md
## Restore Test - [DATE]

- **Backup File**: [filename]
- **Backup Date**: [date]
- **Restore Duration**: [time]
- **Status**: PASS/FAIL
- **Issues Found**: [list any issues]
- **Action Items**: [improvements needed]
```

**5. Clean up test environment:**

```bash
docker-compose -f docker-compose.sandbox.yml down -v
rm -rf gitlab-local/
```

### Recovery Time Objective (RTO) and Recovery Point Objective (RPO)

**Define your targets:**

- **RPO (Data Loss)**: Maximum acceptable data loss
  - Example: 24 hours (daily backups)
  - Recommendation: 4-6 hours (backup 4x daily)

- **RTO (Downtime)**: Maximum acceptable downtime
  - Example: 4 hours from detection to full restoration
  - Factors: Backup size, network speed, database size

**Measure and improve:**

```bash
# Time your restore process
time ./scripts/restore.sh backup_file.tar

# Optimize based on results:
# - Faster storage (SSD)
# - Incremental backups
# - Database optimization
```

---

## Security Hardening Checklist

### Pre-Production Checklist

Before deploying to production, complete this checklist:

- [ ] **Secrets Management**
  - [ ] `.env` file is not committed to git
  - [ ] `.env` has restrictive permissions (600)
  - [ ] SMTP passwords are strong and unique
  - [ ] Consider using Docker secrets or vault

- [ ] **SSL/TLS**
  - [ ] Valid SSL certificate installed (not self-signed)
  - [ ] Certificate auto-renewal configured
  - [ ] HTTP to HTTPS redirect enabled
  - [ ] TLS 1.2+ enforced (disable older versions)

- [ ] **Access Control**
  - [ ] Initial root password changed
  - [ ] 2FA enabled for all admin accounts
  - [ ] SSH key authentication enforced
  - [ ] Unnecessary user accounts removed

- [ ] **Network Security**
  - [ ] Firewall configured (ufw/iptables)
  - [ ] Only necessary ports exposed (80, 443, 22)
  - [ ] Consider non-standard SSH port (not 22)
  - [ ] fail2ban installed and configured
  - [ ] Rate limiting enabled

- [ ] **Backup & Recovery**
  - [ ] Automated backups enabled (cron job)
  - [ ] Offsite backup configured
  - [ ] Backup encryption enabled (if using untrusted storage)
  - [ ] Restore procedure tested
  - [ ] Backup verification automated

- [ ] **Monitoring**
  - [ ] Prometheus metrics enabled
  - [ ] Alerting configured (PagerDuty/email/Slack)
  - [ ] Disk space monitoring active
  - [ ] Log aggregation configured
  - [ ] Certificate expiration monitoring

- [ ] **Updates**
  - [ ] Update schedule defined
  - [ ] Rollback procedure documented
  - [ ] Test environment for update testing

- [ ] **Compliance**
  - [ ] Data retention policy defined
  - [ ] Audit logging enabled
  - [ ] Access logs reviewed regularly
  - [ ] GDPR/compliance requirements met (if applicable)

### Firewall Configuration

**Example using ufw (Ubuntu):**

```bash
# Reset firewall
sudo ufw --force reset

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (change port if using non-standard)
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

### fail2ban Configuration

**Install and configure fail2ban:**

```bash
# Install
sudo apt install fail2ban

# Create GitLab jail
sudo tee /etc/fail2ban/jail.d/gitlab.conf <<EOF
[gitlab]
enabled = true
port = 80,443
filter = gitlab
logpath = /var/log/gitlab/gitlab-rails/production.log
maxretry = 5
bantime = 3600
EOF

# Create filter
sudo tee /etc/fail2ban/filter.d/gitlab.conf <<EOF
[Definition]
failregex = Failed Login:.*IP:<HOST>
ignoreregex =
EOF

# Restart fail2ban
sudo systemctl restart fail2ban
```

---

## Monitoring and Alerting

### Prometheus Metrics

With monitoring enabled in `gitlab.rb.template`, access metrics at:

- GitLab metrics: `http://localhost:9168/metrics`
- System metrics: `http://localhost:9100/metrics`
- PostgreSQL metrics: `http://localhost:9187/metrics`
- Redis metrics: `http://localhost:9121/metrics`

### Key Metrics to Monitor

**System Health:**
- CPU usage > 80% for 5 minutes
- Memory usage > 90%
- Disk usage > 85%
- Disk I/O wait > 50%

**Application Health:**
- GitLab response time > 5 seconds
- Failed requests > 1% of total
- Sidekiq queue depth > 1000 jobs
- GitLab service health check failures

**Backup Health:**
- Last backup age > 36 hours
- Backup failures
- Backup size anomalies (too small/large)

### Setting Up Alerts

**Example: Prometheus Alertmanager Configuration**

```yaml
# alertmanager.yml
global:
  resolve_timeout: 5m

route:
  receiver: 'default'
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h

receivers:
  - name: 'default'
    email_configs:
      - to: 'admin@example.com'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.example.com:587'
        auth_username: 'alertmanager@example.com'
        auth_password: 'password'
```

**Example Alert Rules:**

```yaml
# alerts.yml
groups:
  - name: gitlab
    interval: 30s
    rules:
      - alert: GitLabDown
        expr: up{job="gitlab"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "GitLab is down"

      - alert: HighDiskUsage
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) < 0.15
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disk usage above 85%"
```

---

## Incident Response

### Backup Failure Response

**If automated backup fails:**

1. **Immediate Actions:**
   ```bash
   # Check disk space
   df -h

   # Check GitLab status
   docker ps
   docker logs gitlab

   # Attempt manual backup
   ./scripts/backup.sh
   ```

2. **Investigation:**
   - Review backup logs in `logs/`
   - Check for disk space issues
   - Verify Docker container health
   - Check network connectivity (for remote backups)

3. **Resolution:**
   - Address root cause
   - Test backup creation
   - Verify backup integrity
   - Update monitoring if needed

### Data Corruption Response

**If data corruption is detected:**

1. **Stop GitLab immediately:**
   ```bash
   docker-compose down
   ```

2. **Assess damage:**
   - Identify affected components
   - Determine last known good state
   - Check backup availability

3. **Restore from last known good backup:**
   ```bash
   ./scripts/restore.sh <backup_file>
   ```

4. **Post-incident:**
   - Document incident
   - Update backup frequency if needed
   - Implement additional monitoring

### Security Incident Response

**If unauthorized access is suspected:**

1. **Immediate actions:**
   - Reset all admin passwords
   - Enable 2FA for all users
   - Review access logs
   - Check for unauthorized changes

2. **Investigation:**
   ```bash
   # Review GitLab access logs
   docker exec gitlab tail -100 /var/log/gitlab/nginx/gitlab_access.log

   # Check for suspicious admin actions
   docker exec gitlab gitlab-rake gitlab:check
   ```

3. **Containment:**
   - Block suspicious IP addresses
   - Disable compromised accounts
   - Rotate all secrets and tokens

4. **Recovery:**
   - Restore from backup if needed
   - Patch vulnerabilities
   - Update security measures

---

## Additional Resources

- [GitLab Security Best Practices](https://docs.gitlab.com/ee/security/)
- [GitLab Backup and Restore](https://docs.gitlab.com/ee/raketasks/backup_restore.html)
- [GitLab Monitoring](https://docs.gitlab.com/ee/administration/monitoring/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

---

## Revision History

- **2024**: Initial security guide created
- Update this document as security practices evolve
