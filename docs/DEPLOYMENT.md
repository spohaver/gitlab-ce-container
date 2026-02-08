# GitLab CE Advanced Deployment Guide

This document covers advanced deployment topics, custom configurations, and enterprise features.

> 📚 **Start with the basics first:**
> - New users: [QUICKSTART-SANDBOX.md](QUICKSTART-SANDBOX.md) - Get started in 5 minutes
> - Production: [QUICKSTART-PRODUCTION.md](QUICKSTART-PRODUCTION.md) - Complete production guide
> - Automation: [AUTOMATION.md](AUTOMATION.md) - CI/CD integration and scripting
>
> This guide is for advanced customizations beyond standard deployment.

## Table of Contents

- [Deployment Flexibility](#deployment-flexibility)
- [Advanced Topics](#advanced-topics)
- [Custom GitLab Configuration](#custom-gitlab-configuration)
- [High Availability](#high-availability-configuration)
- [Performance Tuning](#performance-tuning)
- [Custom Runners](#custom-runners)

## Deployment Flexibility

This template supports flexible deployment locations and configurations.

### Installation Location Flexibility

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

### Container Name Flexibility

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

#### Profile-Specific Container Names

Each deployment profile uses a unique container name by default:

| Profile | Default Container Name | Override Variable |
|---------|----------------------|-------------------|
| Sandbox | `gitlab-sandbox` | `GITLAB_CONTAINER_NAME` |
| Staging | `gitlab-staging` | `GITLAB_CONTAINER_NAME` |
| Production | `gitlab-production` | `GITLAB_CONTAINER_NAME` |

This allows running multiple GitLab instances on the same server.

#### Setting Custom Container Name

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

### Multi-Instance Setup

You can run multiple GitLab profiles simultaneously:

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

Profiles use different ports to avoid conflicts:

```
Sandbox:    HTTP=8080, HTTPS=8443, SSH=2224
Staging:    HTTP=80,   HTTPS=443,  SSH=2222
Production: HTTP=80,   HTTPS=443,  SSH=2222
```

### Docker Volume Flexibility

**Named Volumes (Production/Staging)**

Data stored in Docker volumes (portable across hosts):

```yaml
volumes:
  gitlab-data:
    driver: local
```

**Local Directories (Sandbox)**

Data stored in `./gitlab-local/` for easy inspection:

```bash
gitlab-local/
├── data/       # GitLab data
├── config/     # Configuration
├── logs/       # Log files
└── ssl/        # Certificates
```

### Common Customizations

**Custom Ports**

```yaml
# docker-compose.override.yml
services:
  gitlab:
    ports:
      - '8888:80'
      - '8889:443'
      - '2223:22'
```

**Custom Domain**

```bash
# .env
GITLAB_DOMAIN=git.mycompany.com
```

**Custom Data Location**

```yaml
# docker-compose.override.yml
services:
  gitlab:
    volumes:
      - /mnt/storage/gitlab-data:/var/opt/gitlab
```

## Advanced Topics

### Custom GitLab Configuration

For advanced customization beyond environment variables, create a custom `gitlab.rb`:

```bash
# Copy template
cp config/gitlab.rb.template config/gitlab.rb

# Edit configuration
nano config/gitlab.rb
```

Common customizations:
- LDAP/Active Directory integration
- OAuth provider configuration
- Object storage (S3) integration
- Custom email templates
- Webhook rate limiting
- Git LFS settings

Mount the custom configuration:

```yaml
# docker-compose.override.yml
services:
  gitlab:
    volumes:
      - ./config/gitlab.rb:/etc/gitlab/gitlab.rb:ro
```

### LDAP/Active Directory Integration

Add to `config/gitlab.rb`:

```ruby
gitlab_rails['ldap_enabled'] = true
gitlab_rails['ldap_servers'] = YAML.load <<-EOS
  main:
    label: 'LDAP'
    host: 'ldap.example.com'
    port: 389
    uid: 'sAMAccountName'
    bind_dn: 'CN=GitLab,OU=Service Accounts,DC=example,DC=com'
    password: 'your_password'
    encryption: 'start_tls'
    base: 'DC=example,DC=com'
    user_filter: '(memberOf=CN=GitLab Users,OU=Groups,DC=example,DC=com)'
EOS
```

### OAuth Provider Integration

#### GitHub OAuth

Add to `config/gitlab.rb`:

```ruby
gitlab_rails['omniauth_enabled'] = true
gitlab_rails['omniauth_allow_single_sign_on'] = ['github']
gitlab_rails['omniauth_block_auto_created_users'] = false
gitlab_rails['omniauth_providers'] = [
  {
    "name" => "github",
    "app_id" => "YOUR_APP_ID",
    "app_secret" => "YOUR_APP_SECRET",
    "args" => { "scope" => "user:email" }
  }
]
```

#### Google OAuth

```ruby
gitlab_rails['omniauth_providers'] = [
  {
    "name" => "google_oauth2",
    "app_id" => "YOUR_APP_ID",
    "app_secret" => "YOUR_APP_SECRET",
    "args" => { 
      "access_type" => "offline", 
      "approval_prompt" => "" 
    }
  }
]
```

### Container Registry

Enable Docker container registry:

```ruby
# In config/gitlab.rb
registry_external_url 'https://registry.gitlab.example.com'
gitlab_rails['registry_enabled'] = true
registry['enable'] = true
```

Add registry domain to compose file:

```yaml
services:
  gitlab:
    ports:
      - '5050:5050'
```

### GitLab Pages

Enable static site hosting:

```ruby
# In config/gitlab.rb
pages_external_url "https://pages.gitlab.example.com"
gitlab_pages['enable'] = true
gitlab_pages['inplace_chroot'] = true
```

### High Availability Configuration

For enterprise deployments requiring HA:

#### External PostgreSQL

```yaml
# docker-compose.yml
services:
  gitlab:
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        postgresql['enable'] = false
        gitlab_rails['db_adapter'] = 'postgresql'
        gitlab_rails['db_encoding'] = 'utf8'
        gitlab_rails['db_host'] = 'postgres.example.com'
        gitlab_rails['db_port'] = 5432
        gitlab_rails['db_database'] = 'gitlabhq_production'
        gitlab_rails['db_username'] = 'gitlab'
        gitlab_rails['db_password'] = 'secure_password'
```

#### External Redis

```yaml
environment:
  GITLAB_OMNIBUS_CONFIG: |
    redis['enable'] = false
    gitlab_rails['redis_host'] = 'redis.example.com'
    gitlab_rails['redis_port'] = 6379
    gitlab_rails['redis_password'] = 'secure_password'
```

#### Object Storage (S3)

```ruby
# In config/gitlab.rb
gitlab_rails['object_store']['enabled'] = true
gitlab_rails['object_store']['connection'] = {
  'provider' => 'AWS',
  'region' => 'us-east-1',
  'aws_access_key_id' => 'YOUR_ACCESS_KEY',
  'aws_secret_access_key' => 'YOUR_SECRET_KEY'
}
gitlab_rails['object_store']['objects']['artifacts']['bucket'] = 'gitlab-artifacts'
gitlab_rails['object_store']['objects']['lfs']['bucket'] = 'gitlab-lfs'
gitlab_rails['object_store']['objects']['uploads']['bucket'] = 'gitlab-uploads'
```

### Performance Tuning

#### Optimize for Your Workload

```ruby
# In config/gitlab.rb

# For small teams (< 100 users)
puma['worker_processes'] = 2
sidekiq['max_concurrency'] = 10

# For medium teams (100-500 users)
puma['worker_processes'] = 4
sidekiq['max_concurrency'] = 25

# For large teams (500+ users)
puma['worker_processes'] = 8
sidekiq['max_concurrency'] = 50

# PostgreSQL tuning
postgresql['shared_buffers'] = "4GB"
postgresql['work_mem'] = "64MB"
postgresql['maintenance_work_mem'] = "1GB"
postgresql['effective_cache_size'] = "12GB"
```

#### Resource Limits

```yaml
# docker-compose.override.yml
services:
  gitlab:
    deploy:
      resources:
        limits:
          cpus: '8'
          memory: 16G
        reservations:
          cpus: '4'
          memory: 8G
```

### Custom Runners

#### Shell Executor (Simple)

```bash
# Register runner
docker run --rm -it -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  gitlab/gitlab-runner register \
  --url https://gitlab.example.com \
  --token YOUR_REGISTRATION_TOKEN \
  --executor shell
```

#### Docker Executor (Recommended)

```bash
docker run --rm -it -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  gitlab/gitlab-runner register \
  --url https://gitlab.example.com \
  --token YOUR_REGISTRATION_TOKEN \
  --executor docker \
  --docker-image alpine:latest \
  --docker-volumes /var/run/docker.sock:/var/run/docker.sock
```

#### Kubernetes Executor (Enterprise)

```bash
docker run --rm -it -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  gitlab/gitlab-runner register \
  --url https://gitlab.example.com \
  --token YOUR_REGISTRATION_TOKEN \
  --executor kubernetes
```

### Email Templates Customization

```ruby
# In config/gitlab.rb
gitlab_rails['gitlab_email_from'] = 'gitlab@example.com'
gitlab_rails['gitlab_email_display_name'] = 'GitLab'
gitlab_rails['gitlab_email_reply_to'] = 'noreply@example.com'
gitlab_rails['gitlab_email_subject_suffix'] = '[GitLab]'
```

### Webhook Rate Limiting

```ruby
# In config/gitlab.rb
gitlab_rails['webhook_timeout'] = 10
gitlab_rails['max_request_duration_seconds'] = 57
```

### Git Configuration

```ruby
# In config/gitlab.rb
gitlab_rails['gitlab_default_branch'] = 'main'
gitlab_rails['max_attachment_size'] = 100  # MB
gitlab_rails['git_timeout'] = 30
```

### Backup Encryption

```ruby
# In config/gitlab.rb
gitlab_rails['backup_encryption'] = 'AES256'
gitlab_rails['backup_encryption_key'] = 'YOUR_ENCRYPTION_KEY'
```
